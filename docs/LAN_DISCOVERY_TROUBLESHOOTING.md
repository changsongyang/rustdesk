# 局域网发现功能故障排查指南

## 目录
1. [问题诊断流程](#问题诊断流程)
2. [常见问题及解决方案](#常见问题及解决方案)
3. [平台限制说明](#平台限制说明)
4. [高级调试方法](#高级调试方法)

---

## 问题诊断流程

### 第一步：确认基础网络连接

#### 1.1 检查设备是否在同一局域网
```bash
# Windows
ipconfig

# Linux/Mac
ifconfig
# 或
ip addr show
```

**验证要点：**
- 所有设备的 IP 地址应在同一网段（如 192.168.1.x）
- 子网掩码应相同（如 255.255.255.0）
- 默认网关应相同

#### 1.2 测试网络连通性
```bash
# 从控制端 ping 被控端
ping <被控端IP地址>

# 示例
ping 192.168.1.100
```

**预期结果：** 能够正常 ping 通，延迟 < 10ms

---

### 第二步：检查 RustDesk 配置

#### 2.1 验证局域网发现功能已启用

**Android 设备：**
1. 打开 RustDesk 应用
2. 进入 "设置" → "共享屏幕"
3. 确认 "允许局域网发现" 开关已开启
4. 检查发现间隔和超时设置是否合理

**桌面设备（Windows/Linux/macOS）：**
1. 打开 RustDesk
2. 进入 "设置" → "网络"
3. 确认 "允许局域网发现" 已勾选

#### 2.2 检查配置文件

**配置文件位置：**
- Windows: `%AppData%\RustDesk\config\`
- Linux: `~/.config/rustdesk/`
- macOS: `~/Library/Application Support/RustDesk/`
- Android: `/data/data/com.carriez.flutter_hbb/`

**关键配置项：**
```toml
# 检查以下配置项
enable-lan-discovery = ""  # 空字符串表示启用（默认）
lan-discovery-interval = "30"  # 发现间隔（秒）
lan-discovery-timeout = "3"    # 发现超时（秒）
```

**注意：** 
- `enable-lan-discovery` 为空字符串或 "Y" 表示启用
- "N" 表示禁用

---

### 第三步：检查防火墙设置

#### 3.1 Windows 防火墙

**方法一：临时关闭防火墙测试**
```powershell
# 以管理员身份运行 PowerShell
# 关闭防火墙（仅用于测试）
netsh advfirewall set allprofiles state off

# 测试完成后重新开启
netsh advfirewall set allprofiles state on
```

**方法二：添加防火墙规则**
```powershell
# 添加入站规则
netsh advfirewall firewall add rule name="RustDesk LAN Discovery" dir=in action=allow protocol=UDP localport=21118

# 添加出站规则
netsh advfirewall firewall add rule name="RustDesk LAN Discovery" dir=out action=allow protocol=UDP localport=21118
```

**端口号说明：**
- LAN Discovery 使用 UDP 端口：`RENDEZVOUS_PORT + 3`（默认 21118）
- `RENDEZVOUS_PORT` 默认为 21115

#### 3.2 Linux 防火墙（iptables/firewalld）

**iptables:**
```bash
# 添加规则
sudo iptables -A INPUT -p udp --dport 21118 -j ACCEPT
sudo iptables -A OUTPUT -p udp --dport 21118 -j ACCEPT

# 保存规则
sudo iptables-save > /etc/iptables/rules.v4
```

**firewalld:**
```bash
# 添加端口
sudo firewall-cmd --permanent --add-port=21118/udp
sudo firewall-cmd --reload
```

#### 3.3 macOS 防火墙

**系统偏好设置 → 安全性与隐私 → 防火墙 → 防火墙选项**
- 允许 RustDesk 接受传入连接

---

### 第四步：检查路由器设置

#### 4.1 AP 隔离（客户端隔离）

**问题：** 路由器启用了 AP 隔离，导致局域网设备无法互相通信

**解决方案：**
1. 登录路由器管理界面
2. 查找 "AP 隔离"、"客户端隔离" 或 "无线隔离" 设置
3. 确保该功能已禁用

#### 4.2 VLAN 划分

**问题：** 设备被划分到不同的 VLAN，无法互相通信

**解决方案：**
1. 检查路由器 VLAN 配置
2. 确保所有设备在同一 VLAN
3. 或配置 VLAN 间路由

#### 4.3 组播/广播限制

**问题：** 路由器限制了广播或组播流量

**解决方案：**
1. 检查路由器的广播/组播设置
2. 确保允许 UDP 广播流量

---

### 第五步：检查网络权限（Android）

#### 5.1 网络权限

**必需权限：**
- `INTERNET`
- `ACCESS_WIFI_STATE`
- `ACCESS_NETWORK_STATE`
- `CHANGE_WIFI_MULTICAST_STATE`（可选，用于组播）

**检查方法：**
```bash
# 使用 adb 检查权限
adb shell dumpsys package com.carriez.flutter_hbb | grep permission
```

#### 5.2 电池优化

**问题：** 电池优化可能限制后台网络活动

**解决方案：**
1. 进入 "设置" → "应用" → "RustDesk"
2. 进入 "电池" 设置
3. 选择 "不限制" 或关闭电池优化

---

## 常见问题及解决方案

### 问题 1：无法发现任何设备

**可能原因：**
1. 局域网发现功能未启用
2. 防火墙阻止 UDP 21118 端口
3. 路由器启用了 AP 隔离
4. 设备不在同一网段

**解决方案：**
1. 确认所有设备的 "允许局域网发现" 已开启
2. 临时关闭防火墙测试
3. 检查路由器 AP 隔离设置
4. 确认所有设备在同一网段

---

### 问题 2：只能发现部分设备

**可能原因：**
1. 部分设备防火墙配置不同
2. 设备发现超时时间过短
3. 网络拥塞导致丢包

**解决方案：**
1. 统一所有设备的防火墙配置
2. 增加发现超时时间（建议 3-5 秒）
3. 检查网络质量

---

### 问题 3：发现设备后无法连接

**可能原因：**
1. 被控端服务未启动
2. 被控端密码未设置
3. 网络连接问题

**解决方案：**
1. 确认被控端 RustDesk 服务正在运行
2. 设置被控端永久密码
3. 使用 IP 地址直连测试

---

### 问题 4：iOS 设备无法发现或被发现

**原因：** iOS 平台不支持局域网发现功能

**解决方案：**
- 使用 IP 地址直连
- 或通过 ID 服务器连接

---

## 平台限制说明

### iOS 平台限制

**不支持的功能：**
- 局域网发现（LAN Discovery）
- 原因：iOS 系统对 UDP 广播和网络接口访问有严格限制

**替代方案：**
- 使用 IP 地址直连
- 通过 ID 服务器连接
- 使用二维码扫描连接

### Android 平台注意事项

**必需权限：**
```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_WIFI_STATE" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
```

**后台运行：**
- 建议关闭电池优化
- 允许后台网络活动

---

## 高级调试方法

### 启用 Debug 日志

**Android:**
1. 进入 RustDesk 设置
2. 找到 "调试" 或 "日志级别" 设置
3. 设置为 "Debug" 或 "Verbose"

**桌面端：**
```bash
# 设置环境变量
export RUST_LOG=debug

# 或在启动时指定
RUST_LOG=debug rustdesk
```

### 查看日志输出

**关键日志信息：**
```
lan discovery listener started          # 监听器已启动
ignored ping with invalid signature     # 签名验证失败
ignored ping from non-whitelisted device # 设备不在白名单
signature hash mismatch                 # 签名不匹配
signature expired or from future        # 签名过期
```

### 网络抓包分析

**使用 Wireshark 抓包：**
1. 过滤器设置：`udp.port == 21118`
2. 查看广播包是否正常发送和接收
3. 检查包内容是否符合 RustDesk 协议

**使用 tcpdump（Linux/Android）：**
```bash
# 抓取 UDP 21118 端口流量
sudo tcpdump -i any udp port 21118 -w lan_discovery.pcap
```

### 手动测试 UDP 连接

**使用 netcat 测试：**
```bash
# 接收端（被控端）
nc -ul 21118

# 发送端（控制端）
echo "test" | nc -u <被控端IP> 21118
```

---

## 快速排查清单

- [ ] 所有设备在同一局域网
- [ ] 所有设备 "允许局域网发现" 已启用
- [ ] 防火墙允许 UDP 21118 端口
- [ ] 路由器未启用 AP 隔离
- [ ] Android 设备已授予网络权限
- [ ] Android 设备已关闭电池优化
- [ ] 被控端 RustDesk 服务正在运行
- [ ] 被控端已设置密码
- [ ] 发现超时时间设置合理（3-5 秒）
- [ ] 非 iOS 设备（iOS 不支持）

---

## 联系支持

如果按照以上步骤仍无法解决问题，请提供以下信息：

1. 所有设备的操作系统版本
2. RustDesk 版本号
3. 网络拓扑结构（路由器型号、网络配置）
4. Debug 日志输出
5. 网络抓包文件（如有）

**GitHub Issues:** https://github.com/rustdesk/rustdesk/issues
