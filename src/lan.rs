#[cfg(not(target_os = "ios"))]
use hbb_common::whoami;
use hbb_common::{
    allow_err,
    anyhow::bail,
    config::Config,
    config::{self, RENDEZVOUS_PORT},
    log,
    protobuf::Message as _,
    rendezvous_proto::*,
    tokio::{
        self,
        sync::mpsc::{unbounded_channel, UnboundedReceiver, UnboundedSender},
    },
    ResultType,
};

use std::{
    collections::{HashMap, HashSet},
    net::{IpAddr, Ipv4Addr, SocketAddr, ToSocketAddrs, UdpSocket},
    sync::{
        atomic::{AtomicU64, Ordering},
        Mutex, OnceLock,
    },
    time::Instant,
};

type Message = RendezvousMessage;

// 网络发现配置常量
const DEFAULT_DISCOVERY_TIMEOUT_MS: u64 = 3000;
const DEFAULT_DISCOVERY_INTERVAL_SECS: u64 = 30;
const SIGNATURE_VERSION: &str = "v2";
// 签名有效期（秒），防止重放攻击
const SIGNATURE_VALIDITY_SECS: u64 = 60;
// 时间戳有效期容差（秒），考虑时钟漂移
const SIGNATURE_TOLERANCE_SECS: u64 = 10;

// 签名有效期缓存，避免重复处理同一时间戳的请求
// 使用 OnceLock 延迟初始化，避免常量初始化问题
static SEEN_SIGNATURES: OnceLock<Mutex<HashSet<String>>> = OnceLock::new();
fn get_seen_signatures() -> &'static Mutex<HashSet<String>> {
    SEEN_SIGNATURES.get_or_init(|| Mutex::new(HashSet::new()))
}

static LAST_DISCOVERY_TIME: AtomicU64 = AtomicU64::new(0);

/// 生成带时间戳的安全签名
/// 格式: v2:timestamp:random:hash(device_id:timestamp:random)
fn get_discovery_signature() -> String {
    let id = Config::get_id();
    let timestamp = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or(0);
    let random: u64 = rand_simple(timestamp);

    // 使用 SHA256 生成签名
    use hbb_common::sha2::{Sha256, Digest};
    let mut hasher = Sha256::new();
    hasher.update(format!("{}:{}:{}", id, timestamp, random).as_bytes());
    let hash = hex::encode(hasher.finalize());

    // 将 random 包含在签名中，以便验证时可以重新计算 hash
    format!("{}:{}:{}:{}", SIGNATURE_VERSION, timestamp, random, hash)
}

/// 简单的伪随机数生成器（基于时间戳种子）
fn rand_simple(seed: u64) -> u64 {
    use std::collections::hash_map::DefaultHasher;
    use std::hash::{Hash, Hasher};
    let mut hasher = DefaultHasher::new();
    seed.hash(&mut hasher);
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_nanos().hash(&mut hasher))
        .ok();
    hasher.finish()
}

/// 验证签名有效性并检查重放
/// 返回 (是否有效, 是否是重复请求)
/// sender_id: 发送方的设备 ID，用于验证签名
fn verify_signature(sender_id: &str, misc: &str) -> (bool, bool) {
    if misc.is_empty() {
        // 允许无签名响应（向后兼容 v1）
        return (true, false);
    }

    let parts: Vec<&str> = misc.split(':').collect();
    
    // v2 版本签名格式: v2:timestamp:random:hash
    if parts.len() != 4 || parts[0] != SIGNATURE_VERSION {
        // 版本不匹配，可能是旧版本或伪造请求
        log::debug!("signature version mismatch: expected {}, got {:?}", SIGNATURE_VERSION, parts.get(0));
        return (false, false);
    }

    // 解析时间戳
    let timestamp: u64 = match parts[1].parse() {
        Ok(t) => t,
        Err(_) => {
            log::debug!("invalid timestamp in signature");
            return (false, false);
        }
    };

    // 解析随机数
    let random: u64 = match parts[2].parse() {
        Ok(r) => r,
        Err(_) => {
            log::debug!("invalid random number in signature");
            return (false, false);
        }
    };

    let received_hash = parts[3];

    // 检查时间戳是否在有效期内
    let now = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or(0);

    if timestamp > now + SIGNATURE_TOLERANCE_SECS || now > timestamp + SIGNATURE_VALIDITY_SECS {
        log::debug!("signature expired or from future: timestamp={}, now={}", timestamp, now);
        return (false, false);
    }

    // 验证 hash（核心安全检查）
    // 使用发送方的 ID 来验证签名
    let expected_hash = {
        use hbb_common::sha2::{Sha256, Digest};
        let mut hasher = Sha256::new();
        hasher.update(format!("{}:{}:{}", sender_id, timestamp, random).as_bytes());
        hex::encode(hasher.finalize())
    };

    if received_hash != expected_hash {
        log::debug!("signature hash mismatch: expected={}, received={}", expected_hash, received_hash);
        return (false, false);
    }

    // 检查是否重复（防止重放攻击）
    let signature_key = format!("{}:{}:{}", timestamp, random, received_hash);
    {
        let mut seen = get_seen_signatures().lock().unwrap();
        if seen.contains(&signature_key) {
            log::debug!("replay attack detected: {}", signature_key);
            return (true, true); // 有效但重复
        }
        seen.insert(signature_key);

        // 清理过期的签名记录（保留最近的有效签名）
        if seen.len() > 1000 {
            let retain_count = seen.len() / 2;
            let keys_to_keep: Vec<_> = seen.iter().take(retain_count).cloned().collect();
            *seen = keys_to_keep.into_iter().collect();
        }
    }

    (true, false) // 验证通过
}

fn get_discovery_timeout_ms() -> u64 {
    let timeout = Config::get_option("lan-discovery-timeout");
    if timeout.is_empty() {
        DEFAULT_DISCOVERY_TIMEOUT_MS
    } else {
        timeout.parse().unwrap_or(DEFAULT_DISCOVERY_TIMEOUT_MS)
    }
}

fn get_discovery_interval_secs() -> u64 {
    let interval = Config::get_option("lan-discovery-interval");
    if interval.is_empty() {
        DEFAULT_DISCOVERY_INTERVAL_SECS
    } else {
        interval.parse().unwrap_or(DEFAULT_DISCOVERY_INTERVAL_SECS)
    }
}

/// 检查设备是否在白名单中
/// 如果白名单为空或未启用，则允许所有设备
fn is_device_whitelisted(peer_id: &str) -> bool {
    let whitelist = Config::get_option("lan-discovery-whitelist");
    if whitelist.is_empty() {
        return true; // 白名单为空，允许所有设备
    }
    
    let allowed_ids: Vec<&str> = whitelist.split(',').map(|s| s.trim()).collect();
    allowed_ids.contains(&peer_id)
}

fn can_discover() -> bool {
    let now = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or(0);
    let last = LAST_DISCOVERY_TIME.load(Ordering::Relaxed);
    let interval = get_discovery_interval_secs();
    if now > last && now - last >= interval {
        LAST_DISCOVERY_TIME.store(now, Ordering::Relaxed);
        true
    } else {
        false
    }
}

#[cfg(not(target_os = "ios"))]
pub(super) fn start_listening() -> ResultType<()> {
    let addr = SocketAddr::from(([0, 0, 0, 0], get_broadcast_port()));
    let socket = std::net::UdpSocket::bind(addr)?;
    socket.set_read_timeout(Some(std::time::Duration::from_millis(1000)))?;
    log::info!("lan discovery listener started");
    loop {
        let mut buf = [0; 2048];
        if let Ok((len, addr)) = socket.recv_from(&mut buf) {
            if let Ok(msg_in) = Message::parse_from_bytes(&buf[0..len]) {
                match msg_in.union {
                    Some(rendezvous_message::Union::PeerDiscovery(p)) => {
                        if p.cmd == "ping"
                            && config::option2bool(
                                "enable-lan-discovery",
                                &Config::get_option("enable-lan-discovery"),
                            )
                        {
                            let id = Config::get_id();
                            if p.id == id {
                                continue;
                            }
                            // Verify ping signature for security
                            // 使用发送方的 ID 验证签名
                            let (valid, is_replay) = verify_signature(&p.id, &p.misc);
                            if !valid {
                                log::debug!("ignored ping with invalid signature from {}", addr);
                                continue;
                            }
                            if is_replay {
                                // 静默忽略重复请求，不记录日志以避免日志泛滥
                                continue;
                            }
                            // 检查设备是否在白名单中
                            if !is_device_whitelisted(&p.id) {
                                log::debug!("ignored ping from non-whitelisted device: {}", p.id);
                                continue;
                            }
                            if let Some(self_addr) = get_ipaddr_by_peer(&addr) {
                                let mut msg_out = Message::new();
                                let mut hostname = crate::whoami_hostname();
                                // The default hostname is "localhost" which is a bit confusing
                                if hostname == "localhost" {
                                    hostname = "unknown".to_owned();
                                }
                                let peer = PeerDiscovery {
                                    cmd: "pong".to_owned(),
                                    mac: get_mac(&self_addr),
                                    id,
                                    hostname: hostname.clone(),
                                    username: crate::platform::get_active_username(),
                                    platform: whoami::platform().to_string(),
                                    misc: get_discovery_signature(),
                                    device_type: get_device_type(),
                                    ip_address: self_addr.to_string(),
                                    device_name: hostname,
                                    ..Default::default()
                                };
                                msg_out.set_peer_discovery(peer);
                                socket.send_to(&msg_out.write_to_bytes()?, addr).ok();
                            }
                        }
                    }
                    _ => {}
                }
            }
        }
    }
}

#[tokio::main(flavor = "current_thread")]
pub async fn discover() -> ResultType<()> {
    if !can_discover() {
        log::debug!("discovery skipped due to rate limit");
        return Ok(());
    }
    discover_internal().await
}

pub async fn discover_internal() -> ResultType<()> {
    let sockets = send_query()?;
    let timeout_ms = get_discovery_timeout_ms();
    let rx = spawn_wait_responses(sockets, timeout_ms);
    handle_received_peers(rx).await?;

    log::info!("discover ping done");
    Ok(())
}

pub fn force_discover() {
    std::thread::spawn(move || {
        let runtime = match tokio::runtime::Runtime::new() {
            Ok(r) => r,
            Err(e) => {
                log::error!("failed to create Tokio runtime for LAN discovery: {}", e);
                return;
            }
        };
        if let Err(e) = runtime.block_on(discover_internal()) {
            log::error!("LAN discovery failed: {}", e);
        }
    });
}

pub fn get_discovery_config() -> HashMap<&'static str, String> {
    HashMap::from([
        ("timeout", get_discovery_timeout_ms().to_string()),
        ("interval", get_discovery_interval_secs().to_string()),
        ("enabled", Config::get_option("enable-lan-discovery")),
    ])
}

pub fn send_wol(id: String) {
    let interfaces = default_net::get_interfaces();
    for peer in &config::LanPeers::load().peers {
        if peer.id == id {
            for (_, mac) in peer.ip_mac.iter() {
                if let Ok(mac_addr) = mac.parse() {
                    for interface in &interfaces {
                        for ipv4 in &interface.ipv4 {
                            // remove below mask check to avoid unexpected bug
                            // if (u32::from(ipv4.addr) & u32::from(ipv4.netmask)) == (u32::from(peer_ip) & u32::from(ipv4.netmask))
                            log::info!("Send wol to {mac_addr} of {}", ipv4.addr);
                            allow_err!(wol::send_wol(mac_addr, None, Some(IpAddr::V4(ipv4.addr))));
                        }
                    }
                }
            }
            break;
        }
    }
}

#[inline]
fn get_broadcast_port() -> u16 {
    (RENDEZVOUS_PORT + 3) as _
}

fn get_mac(_ip: &IpAddr) -> String {
    #[cfg(not(target_os = "ios"))]
    if let Ok(mac) = get_mac_by_ip(_ip) {
        mac.to_string()
    } else {
        "".to_owned()
    }
    #[cfg(target_os = "ios")]
    "".to_owned()
}

fn get_device_type() -> String {
    let platform = whoami::platform();
    match platform {
        whoami::Platform::Windows => "computer".to_owned(),
        whoami::Platform::MacOS => "computer".to_owned(),
        whoami::Platform::Linux => {
            // Check if it's a mobile device
            if cfg!(target_os = "android") {
                "mobile".to_owned()
            } else {
                "computer".to_owned()
            }
        }
        whoami::Platform::Android => "mobile".to_owned(),
        whoami::Platform::IOS => "mobile".to_owned(),
        _ => "computer".to_owned(),
    }
}

#[cfg(not(target_os = "ios"))]
fn get_mac_by_ip(ip: &IpAddr) -> ResultType<String> {
    for interface in default_net::get_interfaces() {
        match ip {
            IpAddr::V4(local_ipv4) => {
                if interface.ipv4.iter().any(|x| x.addr == *local_ipv4) {
                    if let Some(mac_addr) = interface.mac_addr {
                        return Ok(mac_addr.address());
                    }
                }
            }
            IpAddr::V6(local_ipv6) => {
                if interface.ipv6.iter().any(|x| x.addr == *local_ipv6) {
                    if let Some(mac_addr) = interface.mac_addr {
                        return Ok(mac_addr.address());
                    }
                }
            }
        }
    }
    bail!("No interface found for ip: {:?}", ip);
}

// Mainly from https://github.com/shellrow/default-net/blob/cf7ca24e7e6e8e566ed32346c9cfddab3f47e2d6/src/interface/shared.rs#L4
fn get_ipaddr_by_peer<A: ToSocketAddrs>(peer: A) -> Option<IpAddr> {
    let socket = match UdpSocket::bind("0.0.0.0:0") {
        Ok(s) => s,
        Err(_) => return None,
    };

    match socket.connect(peer) {
        Ok(()) => (),
        Err(_) => return None,
    };

    match socket.local_addr() {
        Ok(addr) => return Some(addr.ip()),
        Err(_) => return None,
    };
}

fn create_broadcast_sockets() -> Vec<UdpSocket> {
    let mut ipv4s = Vec::new();
    // TODO: maybe we should use a better way to get ipv4 addresses.
    // But currently, it's ok to use `[Ipv4Addr::UNSPECIFIED]` for discovery.
    // `default_net::get_interfaces()` causes undefined symbols error when `flutter build` on iOS simulator x86_64
    #[cfg(not(any(target_os = "ios")))]
    for interface in default_net::get_interfaces() {
        for ipv4 in &interface.ipv4 {
            ipv4s.push(ipv4.addr.clone());
        }
    }
    ipv4s.push(Ipv4Addr::UNSPECIFIED); // for robustness
    let mut sockets = Vec::new();
    for v4_addr in ipv4s {
        // removing v4_addr.is_private() check, https://github.com/rustdesk/rustdesk/issues/4663
        if let Ok(s) = UdpSocket::bind(SocketAddr::from((v4_addr, 0))) {
            if s.set_broadcast(true).is_ok() {
                sockets.push(s);
            }
        }
    }
    sockets
}

fn send_query() -> ResultType<Vec<UdpSocket>> {
    let sockets = create_broadcast_sockets();
    if sockets.is_empty() {
        bail!("Found no bindable ipv4 addresses");
    }

    let mut msg_out = Message::new();
    // We may not be able to get the mac address on mobile platforms.
    // So we need to use the id to avoid discovering ourselves.
    #[cfg(any(target_os = "android", target_os = "ios"))]
    let id = crate::ui_interface::get_id();
    // `crate::ui_interface::get_id()` will cause error:
    // `get_id()` uses async code with `current_thread`, which is not allowed in this context.
    //
    // No need to get id for desktop platforms.
    // We can use the mac address to identify the device.
    #[cfg(not(any(target_os = "android", target_os = "ios")))]
    let id = "".to_owned();
    let peer = PeerDiscovery {
        cmd: "ping".to_owned(),
        id,
        misc: get_discovery_signature(),
        ..Default::default()
    };
    msg_out.set_peer_discovery(peer);
    let out = msg_out.write_to_bytes()?;
    let maddr = SocketAddr::from(([255, 255, 255, 255], get_broadcast_port()));
    for socket in &sockets {
        allow_err!(socket.send_to(&out, maddr));
    }
    log::info!("discover ping sent");
    Ok(sockets)
}

fn wait_response(
    socket: UdpSocket,
    timeout: Option<std::time::Duration>,
    discovery_timeout_ms: u64,
    tx: UnboundedSender<config::DiscoveryPeer>,
) -> ResultType<()> {
    let mut last_recv_time = Instant::now();

    let local_addr = socket.local_addr();
    let try_get_ip_by_peer = match local_addr.as_ref() {
        Err(..) => true,
        Ok(addr) => addr.ip().is_unspecified(),
    };
    let mut mac: Option<String> = None;

    socket.set_read_timeout(timeout)?;
    loop {
        let mut buf = [0; 2048];
        if let Ok((len, addr)) = socket.recv_from(&mut buf) {
            if let Ok(msg_in) = Message::parse_from_bytes(&buf[0..len]) {
                match msg_in.union {
                    Some(rendezvous_message::Union::PeerDiscovery(p)) => {
                        last_recv_time = Instant::now();
                        if p.cmd == "pong" {
                            // Verify signature for security
                            // 使用发送方的 ID 验证签名
                            let (valid, is_replay) = verify_signature(&p.id, &p.misc);
                            if !valid {
                                log::debug!("ignored pong with invalid signature from {}", addr);
                                continue;
                            }
                            if is_replay {
                                // 静默忽略重复的 pong 响应
                                continue;
                            }
                            // 检查设备是否在白名单中
                            if !is_device_whitelisted(&p.id) {
                                log::debug!("ignored pong from non-whitelisted device: {}", p.id);
                                continue;
                            }
                            let local_mac = if try_get_ip_by_peer {
                                if let Some(self_addr) = get_ipaddr_by_peer(&addr) {
                                    get_mac(&self_addr)
                                } else {
                                    "".to_owned()
                                }
                            } else {
                                match mac.as_ref() {
                                    Some(m) => m.clone(),
                                    None => {
                                        let m = if let Ok(local_addr) = local_addr {
                                            get_mac(&local_addr.ip())
                                        } else {
                                            "".to_owned()
                                        };
                                        mac = Some(m.clone());
                                        m
                                    }
                                }
                            };

                            if local_mac.is_empty() && p.mac.is_empty() || local_mac != p.mac {
                                allow_err!(tx.send(config::DiscoveryPeer {
                                    id: p.id.clone(),
                                    ip_mac: HashMap::from([
                                        (addr.ip().to_string(), p.mac.clone(),)
                                    ]),
                                    username: p.username.clone(),
                                    hostname: p.hostname.clone(),
                                    platform: p.platform.clone(),
                                    online: true,
                                    device_type: p.device_type.clone(),
                                    device_name: p.device_name.clone(),
                                }));
                            }
                        }
                    }
                    _ => {}
                }
            }
        }
        if last_recv_time.elapsed().as_millis() > discovery_timeout_ms as _ {
            break;
        }
    }
    Ok(())
}

fn spawn_wait_responses(sockets: Vec<UdpSocket>, discovery_timeout_ms: u64) -> UnboundedReceiver<config::DiscoveryPeer> {
    let (tx, rx) = unbounded_channel::<_>();
    for socket in sockets {
        let tx_clone = tx.clone();
        let timeout_ms = discovery_timeout_ms;
        std::thread::spawn(move || {
            allow_err!(wait_response(
                socket,
                Some(std::time::Duration::from_millis(10)),
                timeout_ms,
                tx_clone
            ));
        });
    }
    rx
}

async fn handle_received_peers(mut rx: UnboundedReceiver<config::DiscoveryPeer>) -> ResultType<()> {
    let mut peers = config::LanPeers::load().peers;
    peers.iter_mut().for_each(|peer| {
        peer.online = false;
    });

    let mut response_set = HashSet::new();
    let mut last_write_time: Option<Instant> = None;
    loop {
        tokio::select! {
            data = rx.recv() => match data {
                Some(mut peer) => {
                    let in_response_set = !response_set.insert(peer.id.clone());
                    if let Some(pos) = peers.iter().position(|x| x.is_same_peer(&peer) ) {
                        let peer1 = peers.remove(pos);
                        if in_response_set {
                            peer.ip_mac.extend(peer1.ip_mac);
                            peer.online = true;
                        }
                    }
                    peers.insert(0, peer);
                    if last_write_time.map(|t| t.elapsed().as_millis() > 300).unwrap_or(true)  {
                        config::LanPeers::store(&peers);
                        #[cfg(feature = "flutter")]
                        crate::flutter_ffi::main_load_lan_peers();
                        last_write_time = Some(Instant::now());
                    }
                }
                None => {
                    break
                }
            }
        }
    }

    config::LanPeers::store(&peers);
    #[cfg(feature = "flutter")]
    crate::flutter_ffi::main_load_lan_peers();
    Ok(())
}
