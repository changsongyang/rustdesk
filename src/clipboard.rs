#[cfg(not(target_os = "android"))]
use arboard::Clipboard;
use hbb_common::{log, message_proto::*, ResultType};
use std::{
    sync::{Arc, Mutex},
    time::Duration,
};

pub const CLIPBOARD_NAME: &'static str = "clipboard";
#[cfg(feature = "unix-file-copy-paste")]
pub const FILE_CLIPBOARD_NAME: &'static str = "file-clipboard";
pub const CLIPBOARD_INTERVAL: u64 = 333;

// This format is used to store the flag in the clipboard.
const RUSTDESK_CLIPBOARD_OWNER_FORMAT: &'static str = "dyn.com.rustdesk.owner";

// Add special format for Excel XML Spreadsheet
const CLIPBOARD_FORMAT_EXCEL_XML_SPREADSHEET: &'static str = "XML Spreadsheet";

#[cfg(not(target_os = "android"))]
lazy_static::lazy_static! {
    static ref ARBOARD_MTX: Arc<Mutex<()>> = Arc::new(Mutex::new(()));  
    // cache the clipboard msg
    static ref LAST_MULTI_CLIPBOARDS: Arc<Mutex<MultiClipboards>> = Arc::new(Mutex::new(MultiClipboards::new()));
    // For updating in server and getting content in cm.
    // Clipboard on Linux is "server--clients" mode.
    // The clipboard content is owned by the server and passed to the clients when requested.
    // Plain text is the only exception, it does not require the server to be present.
    static ref CLIPBOARD_CTX: Arc<Mutex<Option<ClipboardContext>>> = Arc::new(Mutex::new(None));
}

#[cfg(not(target_os = "android"))]
const CLIPBOARD_GET_MAX_RETRY: usize = 3;
#[cfg(not(target_os = "android"))]
const CLIPBOARD_GET_RETRY_INTERVAL_DUR: Duration = Duration::from_millis(33);

#[cfg(not(target_os = "android"))]
pub fn check_clipboard(
    ctx: &mut Option<ClipboardContext>,
    side: ClipboardSide,
    force: bool,
) -> Option<Message> {
    if ctx.is_none() {
        *ctx = ClipboardContext::new().ok();
    }
    let ctx2 = ctx.as_mut()?;
    match ctx2.get(side, force) {
        Ok(content) => {
            if !content.is_empty() {
                let mut msg = Message::new();
                let clipboards = proto::create_multi_clipboards(content);
                msg.set_multi_clipboards(clipboards.clone());
                *LAST_MULTI_CLIPBOARDS.lock().unwrap() = clipboards;    
                return Some(msg);
            }
        }
        Err(e) => {
            log::error!("Failed to get clipboard content. {}", e);      
        }
    }
    None
}

#[cfg(all(feature = "unix-file-copy-paste", target_os = "macos"))]      
pub fn is_file_url_set_by_rustdesk(url: &Vec<String>) -> bool {
    if url.len() != 1 {
        return false;
    }
    url.iter()
        .next()
        .map(|s| {
            for prefix in &["file:///tmp/.rustdesk_", "//tmp/.rustdesk_"] {
                if s.starts_with(prefix) {
                    return s[prefix.len()..].parse::<uuid::Uuid>().is_ok();
                }
            }
            false
        })
        .unwrap_or(false)
}

#[cfg(feature = "unix-file-copy-paste")]
pub fn check_clipboard_files(
    ctx: &mut Option<ClipboardContext>,
    side: ClipboardSide,
    force: bool,
) -> Option<Vec<String>> {
    if ctx.is_none() {
        *ctx = ClipboardContext::new().ok();
    }
    let ctx2 = ctx.as_mut()?;
    match ctx2.get_files(side, force) {
        Ok(Some(urls)) => {
            if !urls.is_empty() {
                return Some(urls);
            }
        }
        Err(e) => {
            log::error!("Failed to get clipboard file urls. {}", e);
        }
        _ => {}
    }
    None
}

#[cfg(all(target_os = "linux", feature = "unix-file-copy-paste"))]
pub fn update_clipboard_files(files: Vec<String>, side: ClipboardSide) {
    if !files.is_empty() {
        std::thread::spawn(move || {
            do_update_clipboard_files(files, side);
        });
    }
}

#[cfg(feature = "unix-file-copy-paste")]
pub fn try_empty_clipboard_files(_side: ClipboardSide, _conn_id: i32) {
    std::thread::spawn(move || {
        let mut ctx = CLIPBOARD_CTX.lock().unwrap();
        if ctx.is_none() {
            match ClipboardContext::new() {
                Ok(x) => {
                    *ctx = Some(x);
                }
                Err(e) => {
                    log::error!("Failed to create clipboard context: {}", e);
                    return;
                }
            }
        }
        #[allow(unused_mut)]
        if let Some(mut ctx) = ctx.as_mut() {
            #[cfg(target_os = "linux")]
            {
                use clipboard::platform::unix;
                if unix::fuse::empty_local_files(_side == ClipboardSide::Client, _conn_id) {
                    ctx.try_empty_clipboard_files(_side);
                }
            }
            #[cfg(target_os = "macos")]
            {
                ctx.try_empty_clipboard_files(_side);
                // No need to make sure the context is enabled.
                clipboard::ContextSend::proc(|context| -> ResultType<()> {
                    context.empty_clipboard(_conn_id).ok();
                    Ok(())
                })
                .ok();
            }
        }
    });
}

#[cfg(target_os = "windows")]
pub fn try_empty_clipboard_files(side: ClipboardSide, conn_id: i32) {
    log::debug!("try to empty {} cliprdr for conn_id {}", side, conn_id);
    let _ = clipboard::ContextSend::proc(|context| -> ResultType<()> {
        context.empty_clipboard(conn_id)?;
        Ok(())
    });
}

#[cfg(target_os = "windows")]
pub fn check_clipboard_cm() -> ResultType<MultiClipboards> {
    let mut ctx = CLIPBOARD_CTX.lock().unwrap();
    if ctx.is_none() {
        match ClipboardContext::new() {
            Ok(x) => {
                *ctx = Some(x);
            }
            Err(e) => {
                hbb_common::bail!("Failed to create clipboard context: {}", e);
            }
        }
    }
    if let Some(ctx) = ctx.as_mut() {
        let content = ctx.get(ClipboardSide::Host, false)?;
        let clipboards = proto::create_multi_clipboards(content);
        Ok(clipboards)
    } else {
        hbb_common::bail!("Failed to create clipboard context");
    }
}

#[cfg(not(target_os = "android"))]
fn update_clipboard_(multi_clipboards: Vec<hbb_common::message_proto::Clipboard>, side: ClipboardSide) {
    let to_update_data = proto::from_multi_clipboards(multi_clipboards);
    if to_update_data.is_empty() {
        return;
    }
    do_update_clipboard_(to_update_data, side);
}

#[cfg(not(target_os = "android"))]
fn do_update_clipboard_(to_update_data: Vec<proto::ClipboardData>, side: ClipboardSide) {
    let mut ctx = CLIPBOARD_CTX.lock().unwrap();
    if ctx.is_none() {
        match ClipboardContext::new() {
            Ok(x) => {
                *ctx = Some(x);
            }
            Err(e) => {
                log::error!("Failed to create clipboard context: {}", e);
                return;
            }
        }
    }
    if let Some(ctx) = ctx.as_mut() {
        if let Err(e) = ctx.set(&to_update_data, side) {
            log::debug!("Failed to set clipboard: {}", e);
        } else {
            log::debug!("{} updated on {}", CLIPBOARD_NAME, side);
        }
    }
}

#[cfg(not(target_os = "android"))]
pub fn update_clipboard(multi_clipboards: Vec<hbb_common::message_proto::Clipboard>, side: ClipboardSide) {
    std::thread::spawn(move || {
        update_clipboard_(multi_clipboards, side);
    });
}

#[cfg(feature = "unix-file-copy-paste")]
fn do_update_clipboard_files(files: Vec<String>, side: ClipboardSide) {
    let mut ctx = CLIPBOARD_CTX.lock().unwrap();
    if ctx.is_none() {
        match ClipboardContext::new() {
            Ok(x) => {
                *ctx = Some(x);
            }
            Err(e) => {
                log::error!("Failed to create clipboard context: {}", e);
                return;
            }
        }
    }
    if let Some(ctx) = ctx.as_mut() {
        if let Err(e) = ctx.set_file_urls(files, side) {
            log::debug!("Failed to set clipboard files: {}", e);
        } else {
            log::debug!("{} updated on {}", FILE_CLIPBOARD_NAME, side);
        }
    }
}

#[cfg(not(target_os = "android"))]
pub struct ClipboardContext {
    clipboard: Clipboard,
}

#[cfg(not(target_os = "android"))]
#[allow(unreachable_code)]
impl ClipboardContext {
    pub fn new() -> ResultType<ClipboardContext> {
        let clipboard;
        #[cfg(not(target_os = "linux"))]
        {
            clipboard = Clipboard::new()?;
        }
        #[cfg(target_os = "linux")]
        {
            let mut i = 1;
            loop {
                // Try 5 times to create clipboard
                // Arboard::new() connect to X server or Wayland compositor, which should be OK most times
                // But sometimes, the connection may fail, so we retry here.
                match Clipboard::new() {
                    Ok(x) => {
                        clipboard = x;
                        break;
                    }
                    Err(e) => {
                        if i == 5 {
                            return Err(e.into());
                        } else {
                            std::thread::sleep(std::time::Duration::from_millis(30 * i));
                        }
                    }
                }
                i += 1;
            }
        }

        Ok(ClipboardContext { clipboard })
    }

    pub fn get(&mut self, _side: ClipboardSide, _force: bool) -> ResultType<Vec<proto::ClipboardData>> {
        let _lock = ARBOARD_MTX.lock().unwrap();
        let mut result = Vec::new();

        // Try to get text
        if let Ok(text) = self.clipboard.get_text() {
            if !text.is_empty() {
                result.push(proto::ClipboardData::Text(text));
            }
        }

        // Try to get HTML
        if let Ok(html) = self.clipboard.get().html() {
            if !html.is_empty() {
                result.push(proto::ClipboardData::Html(html));
            }
        }

        // Try to get RTF
        if let Ok(rtf) = self.clipboard.get().text() {
            if !rtf.is_empty() {
                result.push(proto::ClipboardData::Rtf(rtf));
            }
        }

        // Try to get image
        if let Ok(image) = self.clipboard.get_image() {
            result.push(proto::ClipboardData::Image(image));
        }

        // Try to get file URLs
        #[cfg(feature = "unix-file-copy-paste")] {
            if let Ok(urls) = self.clipboard.get().file_list() {
                let paths: Vec<String> = urls.iter().filter_map(|p| p.to_str().map(String::from)).collect();
                if !paths.is_empty() {
                    result.push(proto::ClipboardData::FileUrl(paths));
                }
            }
        }

        Ok(result)
    }

    #[cfg(feature = "unix-file-copy-paste")]
    pub fn get_files(
        &mut self,
        side: ClipboardSide,
        force: bool,
    ) -> ResultType<Option<Vec<String>>> {
        let _lock = ARBOARD_MTX.lock().unwrap();
        match self.clipboard.get().file_list() {
            Ok(urls) => {
                let paths: Vec<String> = urls.iter().filter_map(|p| p.to_str().map(String::from)).collect();
                Ok(Some(paths))
            }
            Err(e) => {
                log::error!("Failed to get file URLs: {}", e);
                Ok(None)
            }
        }
    }

    fn set(&mut self, data: &[proto::ClipboardData], _side: ClipboardSide) -> ResultType<()> {
        let _lock = ARBOARD_MTX.lock().unwrap();

        for item in data {
            match item {
                proto::ClipboardData::Text(text) => {
                    self.clipboard.set().text(text)?;
                }
                proto::ClipboardData::Html(html) => {
                    self.clipboard.set().html(html, None)?;
                }
                proto::ClipboardData::Rtf(rtf) => {
                    self.clipboard.set().text(rtf)?;
                }
                proto::ClipboardData::Image(image) => {
                    self.clipboard.set().image(image.clone())?;
                }
                proto::ClipboardData::FileUrl(_urls) => {
                    #[cfg(feature = "unix-file-copy-paste")] {
                        self.clipboard.set().file_list(urls.iter().map(PathBuf::from).collect())?;
                    }
                }
            }
        }

        Ok(())
    }

    #[cfg(feature = "unix-file-copy-paste")]
    pub fn set_file_urls(&mut self, files: Vec<String>, side: ClipboardSide) -> ResultType<()> {
        let _lock = ARBOARD_MTX.lock().unwrap();
        self.clipboard.set().file_list(files.iter().map(PathBuf::from).collect())?;
        Ok(())
    }

    #[cfg(feature = "unix-file-copy-paste")]
    fn try_empty_clipboard_files(&mut self, side: ClipboardSide) {
        let _lock = ARBOARD_MTX.lock().unwrap();
        #[cfg(target_os = "linux")] {
            let is_kde_x11 = hbb_common::platform::linux::is_kde_session()
                && crate::platform::linux::is_x11();
            let clear_holder_text = if is_kde_x11 {
                "RustDesk placeholder to clear the file clipboard"
            } else {
                ""
            }
            .to_string();
            self.clipboard
                .set()
                .text(&clear_holder_text)
                .commit()
                .ok();
        }
        #[cfg(target_os = "macos")] {
            self.clipboard
                .set()
                .text("")
                .commit()
                .ok();
        }
    }
}

pub fn is_support_multi_clipboard(peer_version: &str, peer_platform: &str) -> bool {
    use hbb_common::get_version_number;
    if get_version_number(peer_version) < get_version_number("1.3.0") {
        return false;
    }
    if ["", &hbb_common::whoami::Platform::Ios.to_string()].contains(&peer_platform) {
        return false;
    }
    if "Android" == peer_platform && get_version_number(peer_version) < get_version_number("1.3.3")
    {
        return false;
    }
    true
}

#[cfg(not(target_os = "android"))]
pub fn get_current_clipboard_msg(
    peer_version: &str,
    peer_platform: &str,
    side: ClipboardSide,
) -> Option<Message> {
    let mut multi_clipboards = LAST_MULTI_CLIPBOARDS.lock().unwrap();
    if multi_clipboards.clipboards.is_empty() {
        let mut ctx = ClipboardContext::new().ok()?;
        *multi_clipboards = proto::create_multi_clipboards(ctx.get(side, true).ok()?);
    }
    if multi_clipboards.clipboards.is_empty() {
        return None;
    }

    if is_support_multi_clipboard(peer_version, peer_platform) {
        let mut msg = Message::new();
        msg.set_multi_clipboards(multi_clipboards.clone());
        Some(msg)
    } else {
        // Find the first text clipboard and send it.
        multi_clipboards
            .clipboards
            .iter()
            .find(|c| c.format.enum_value() == Ok(hbb_common::message_proto::ClipboardFormat::Text))
            .map(|c| {
                let mut msg = Message::new();
                msg.set_clipboard(c.clone());
                msg
            })
    }
}

#[derive(PartialEq, Eq, Clone, Copy)]
pub enum ClipboardSide {
    Host,
    Client,
}

impl ClipboardSide {
    // 01: the clipboard is owned by the host
    // 10: the clipboard is owned by the client
    fn get_owner_data(&self) -> Vec<u8> {
        match self {
            ClipboardSide::Host => vec![0b01],
            ClipboardSide::Client => vec![0b10],
        }
    }

    fn is_owner(&self, data: &[u8]) -> bool {
        if data.len() == 0 {
            return false;
        }
        data[0] & 0b11 != 0
    }
}

impl std::fmt::Display for ClipboardSide {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            ClipboardSide::Host => write!(f, "host"),
            ClipboardSide::Client => write!(f, "client"),
        }
    }
}

pub use proto::get_msg_if_not_support_multi_clip;
mod proto {
    #[cfg(not(target_os = "android"))]
    use arboard::ImageData;
    use hbb_common::{
        compress::{compress as compress_func, decompress},
        message_proto::{Clipboard as ProtoClipboard, ClipboardFormat, Message, MultiClipboards},
    };

    pub enum ClipboardData {
        Text(String),
        Html(String),
        Rtf(String),
        Image(ImageData<'static>),
        FileUrl(Vec<String>),
    }

    fn plain_to_proto(s: String, format: ClipboardFormat) -> ProtoClipboard {
        let compressed = compress_func(s.as_bytes());
        let compress = compressed.len() < s.as_bytes().len();
        let content = if compress {
            compressed
        } else {
            s.bytes().collect::<Vec<u8>>()
        };
        ProtoClipboard {
            compress,
            content: content.into(),
            format: format.into(),
            ..Default::default()
        }
    }

    #[cfg(not(target_os = "android"))]
    fn image_to_proto(a: ImageData<'static>) -> ProtoClipboard {
        let bytes = a.bytes.to_vec();
        let compressed = compress_func(&bytes);
        let compress = compressed.len() < bytes.len();
        let content = if compress {
            compressed
        } else {
            bytes
        };
        ProtoClipboard {
            compress,
            content: content.into(),
            width: a.width as _,
            height: a.height as _,
            format: ClipboardFormat::ImageRgba.into(),
            ..Default::default()
        }
    }

    #[cfg(not(target_os = "android"))]
    fn clipboard_data_to_proto(data: ClipboardData) -> Option<ProtoClipboard> {
        let d = match data {
            ClipboardData::Text(s) => plain_to_proto(s, ClipboardFormat::Text),
            ClipboardData::Rtf(s) => plain_to_proto(s, ClipboardFormat::Rtf),
            ClipboardData::Html(s) => plain_to_proto(s, ClipboardFormat::Html),
            ClipboardData::Image(a) => image_to_proto(a),
            ClipboardData::FileUrl(_) => return None,
        };
        Some(d)
    }

    #[cfg(not(target_os = "android"))]
    pub fn create_multi_clipboards(vec_data: Vec<ClipboardData>) -> MultiClipboards {
        MultiClipboards {
            clipboards: vec_data
                .into_iter()
                .filter_map(clipboard_data_to_proto)
                .collect(),
            ..Default::default()
        }
    }

    #[cfg(not(target_os = "android"))]
    fn from_clipboard(clipboard: ProtoClipboard) -> Option<ClipboardData> {
        let data = if clipboard.compress {
            decompress(&clipboard.content)
        } else {
            clipboard.content.into()
        };
        match clipboard.format.enum_value() {
            Ok(ClipboardFormat::Text) => String::from_utf8(data).ok().map(ClipboardData::Text),
            Ok(ClipboardFormat::Rtf) => String::from_utf8(data).ok().map(ClipboardData::Rtf),
            Ok(ClipboardFormat::Html) => String::from_utf8(data).ok().map(ClipboardData::Html),
            Ok(ClipboardFormat::ImageRgba) => Some(ClipboardData::Image(ImageData {
                width: clipboard.width as _,
                height: clipboard.height as _,
                bytes: data.into(),
            })),
            Ok(ClipboardFormat::ImagePng) | Ok(ClipboardFormat::ImageSvg) => {
                if let Ok(img) = image::load_from_memory(&data) {
                    let rgba = img.to_rgba8();
                    let (width, height) = rgba.dimensions();
                    Some(ClipboardData::Image(ImageData {
                        width: width as usize,
                        height: height as usize,
                        bytes: std::borrow::Cow::Owned(rgba.into_raw()),
                    }))
                } else {
                    None
                }
            }
            _ => None,
        }
    }

    #[cfg(not(target_os = "android"))]
    pub fn from_multi_clipboards(multi_clipboards: Vec<ProtoClipboard>) -> Vec<ClipboardData> {
        multi_clipboards
            .into_iter()
            .filter_map(from_clipboard)
            .collect()
    }

    pub fn get_msg_if_not_support_multi_clip(
        version: &str,
        platform: &str,
        multi_clipboards: &MultiClipboards,
    ) -> Option<Message> {
        if crate::clipboard::is_support_multi_clipboard(version, platform) {
            return None;
        }

        // Find the first text clipboard and send it.
        multi_clipboards
            .clipboards
            .iter()
            .find(|c| c.format.enum_value() == Ok(ClipboardFormat::Text))
            .map(|c| {
                let mut msg = Message::new();
                msg.set_clipboard(c.clone());
                msg
            })
    }
}

#[cfg(target_os = "android")]
pub fn handle_msg_clipboard(mut cb: Clipboard) {
    use hbb_common::protobuf::Message;

    if cb.compress {
        cb.content = bytes::Bytes::from(hbb_common::compress::decompress(&cb.content));
    }
    let multi_clips = MultiClipboards {
        clipboards: vec![cb],
        ..Default::default()
    };
    if let Ok(bytes) = multi_clips.write_to_bytes() {
        let _ = scrap::android::ffi::call_clipboard_manager_update_clipboard(&bytes);
    }
}

#[cfg(target_os = "android")]
pub fn handle_msg_multi_clipboards(mut mcb: MultiClipboards) {
    use hbb_common::protobuf::Message;

    for cb in mcb.clipboards.iter_mut() {
        if cb.compress {
            cb.content = bytes::Bytes::from(hbb_common::compress::decompress(&cb.content));
        }
    }
    if let Ok(bytes) = mcb.write_to_bytes() {
        let _ = scrap::android::ffi::call_clipboard_manager_update_clipboard(&bytes);
    }
}

#[cfg(target_os = "android")]
pub fn get_clipboards_msg(client: bool) -> Option<Message> {
    let mut clipboards = scrap::android::ffi::get_clipboards(client)?;
    let mut msg = Message::new();
    for c in &mut clipboards.clipboards {
        let compressed = hbb_common::compress::compress(&c.content);
        let compress = compressed.len() < c.content.len();
        if compress {
            c.content = compressed.into();
        }
        c.compress = compress;
    }
    msg.set_multi_clipboards(clipboards);
    Some(msg)
}

// We need this mod to notify multiple subscribers when the clipboard changes.
// Because only one clipboard master(listener) can trigger the clipboard change event multiple listeners are created on Linux(x11).
// https://github.com/rustdesk-org/clipboard-master/blob/4fb62e5b62fb6350d82b571ec7ba94b3cd466695/src/master/x11.rs#L226
#[cfg(not(target_os = "android"))]
pub mod clipboard_listener {
    use clipboard_master::{CallbackResult, ClipboardHandler, Master, Shutdown};
    use hbb_common::{bail, log, ResultType};
    use std::{
        collections::HashMap,
        io,
        sync::mpsc::{channel, Sender},
        sync::{Arc, Mutex},
        thread::JoinHandle,
    };

    lazy_static::lazy_static! {
        pub static ref CLIPBOARD_LISTENER: Arc<Mutex<ClipboardListener>> = Default::default();
    }

    struct Handler {
        subscribers: Arc<Mutex<HashMap<String, Sender<CallbackResult>>>>,
    }

    impl ClipboardHandler for Handler {
        fn on_clipboard_change(&mut self) -> CallbackResult {
            let sub_lock = self.subscribers.lock().unwrap();
            for tx in sub_lock.values() {
                tx.send(CallbackResult::Next).ok();
            }
            CallbackResult::Next
        }

        fn on_clipboard_error(&mut self, error: io::Error) -> CallbackResult {
            let msg = format!("Clipboard listener error: {}", error);
            let sub_lock = self.subscribers.lock().unwrap();
            for tx in sub_lock.values() {
                tx.send(CallbackResult::StopWithError(io::Error::new(
                    io::ErrorKind::Other,
                    msg.clone(),
                )))
                .ok();
            }
            CallbackResult::Next
        }
    }

    #[derive(Default)]
    pub struct ClipboardListener {
        subscribers: Arc<Mutex<HashMap<String, Sender<CallbackResult>>>>,
        handle: Option<(Shutdown, JoinHandle<()>)>,
    }

    pub fn subscribe(name: String, tx: Sender<CallbackResult>) -> ResultType<()> {
        log::info!("Subscribe clipboard listener: {}", &name);
        let mut listener_lock = CLIPBOARD_LISTENER.lock().unwrap();
        listener_lock
            .subscribers
            .lock()
            .unwrap()
            .insert(name.clone(), tx);

        if listener_lock.handle.is_none() {
            log::info!("Start clipboard listener thread");
            let handler = Handler {
                subscribers: listener_lock.subscribers.clone(),
            };
            let (tx_start_res, rx_start_res) = channel();
            let h = start_clipboard_master_thread(handler, tx_start_res);
            let shutdown = match rx_start_res.recv() {
                Ok((Some(s), _)) => s,
                Ok((None, err)) => {
                    bail!(err);
                }

                Err(e) => {
                    bail!("Failed to create clipboard listener: {}", e);
                }
            };
            listener_lock.handle = Some((shutdown, h));
            log::info!("Clipboard listener thread started");
        }

        log::info!("Clipboard listener subscribed: {}", name);
        Ok(())
    }

    pub fn unsubscribe(name: &str) {
        log::info!("Unsubscribe clipboard listener: {}", name);
        let mut listener_lock = CLIPBOARD_LISTENER.lock().unwrap();
        let is_empty = {
            let mut sub_lock = listener_lock.subscribers.lock().unwrap();
            if let Some(tx) = sub_lock.remove(name) {
                tx.send(CallbackResult::Stop).ok();
            }
            sub_lock.is_empty()
        };
        if is_empty {
            if let Some((shutdown, h)) = listener_lock.handle.take() {
                log::info!("Stop clipboard listener thread");
                shutdown.signal();
                h.join().ok();
                log::info!("Clipboard listener thread stopped");
            }
        }
        log::info!("Clipboard listener unsubscribed: {}", name);
    }

    fn start_clipboard_master_thread(
        handler: impl ClipboardHandler + Send + 'static,
        tx_start_res: Sender<(Option<Shutdown>, String)>,
    ) -> JoinHandle<()> {
        // https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-getmessage#:~:text=The%20window%20must%20belong%20to%20the%20current%20thread.
        let h = std::thread::spawn(move || match Master::new(handler) {
            Ok(mut master) => {
                tx_start_res
                    .send((Some(master.shutdown_channel()), "".to_owned()))
                    .ok();
                log::debug!("Clipboard listener started");
                if let Err(err) = master.run() {
                    log::error!("Failed to run clipboard listener: {}", err);
                } else {
                    log::debug!("Clipboard listener stopped");
                }
            }
            Err(err) => {
                tx_start_res
                    .send((
                        None,
                        format!("Failed to create clipboard listener: {}", err),
                    ))
                    .ok();
            }
        });
        h
    }
}
