# RustDesk 项目文档

---

## 目录

1. [项目概述](#1-项目概述)
   - 1.1 项目背景
   - 1.2 项目目标
   - 1.3 主要功能
   - 1.4 技术架构概述

2. [环境搭建指南](#2-环境搭建指南)
   - 2.1 开发环境配置
   - 2.2 依赖安装说明
   - 2.3 兼容性要求
   - 2.4 验证方法

3. [核心功能说明](#3-核心功能说明)
   - 3.1 远程桌面连接
   - 3.2 屏幕捕获
   - 3.3 输入控制
   - 3.4 音频传输
   - 3.5 文件传输
   - 3.6 剪贴板同步

4. [API接口文档](#4-API接口文档)
   - 4.1 通信协议概述
   - 4.2 核心消息类型
   - 4.3 接口示例

5. [数据模型设计](#5-数据模型设计)
   - 5.1 配置结构
   - 5.2 数据流转

6. [开发规范](#6-开发规范)
   - 6.1 代码规范
   - 6.2 命名约定
   - 6.3 提交规范
   - 6.4 分支管理策略
   - 6.5 代码审查流程

7. [常见问题解决方案](#7-常见问题解决方案)

8. [二次开发指南](#8-二次开发指南)

9. [项目部署](#9-项目部署)

---

## 1. 项目概述

### 1.1 项目背景

RustDesk 是一款开源的远程桌面软件，旨在提供安全、高效的远程控制解决方案。与传统远程桌面软件相比，RustDesk 具有以下特点：

- **隐私优先**: 用户完全掌控数据，无需依赖第三方云服务
- **开箱即用**: 无需复杂配置，安装即可使用
- **跨平台支持**: 支持 Windows、macOS、Linux、Android、iOS
- **高性能**: 基于 Rust 语言开发，性能优异

### 1.2 项目目标

1. 提供安全可靠的远程桌面体验
2. 支持多种网络环境下的连接（直连、中继）
3. 提供丰富的功能集（屏幕共享、文件传输、音频传输等）
4. 保持代码质量和可维护性
5. 支持自托管部署

### 1.3 主要功能

| 功能模块 | 描述 | 状态 |
|---------|------|------|
| 远程桌面 | 实时屏幕共享和远程控制 | ✅ |
| 文件传输 | 双向文件传输 | ✅ |
| 音频传输 | 双向音频流 | ✅ |
| 剪贴板同步 | 跨设备剪贴板共享 | ✅ |
| NAT穿透 | 自动处理网络地址转换 | ✅ |
| 中继服务器 | 支持自建中继 | ✅ |
| 多显示器支持 | 支持多显示器切换 | ✅ |
| 虚拟显示器 | Windows 虚拟显示器支持 | ✅ |

### 1.4 技术架构概述

#### 1.4.1 架构分层

```
┌─────────────────────────────────────────────────────────────────┐
│                      UI Layer                                   │
│  ┌─────────────────┐  ┌─────────────────┐                      │
│  │   Flutter UI    │  │   Sciter UI     │                      │
│  │  (推荐)         │  │  (已弃用)       │                      │
│  └────────┬────────┘  └─────────────────┘                      │
└───────────┼─────────────────────────────────────────────────────┘
            │
            ▼
┌─────────────────────────────────────────────────────────────────┐
│                     Business Layer                              │
│  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐   │
│  │ Client  │ │ Server  │ │ Rendezvous│ │  IPC    │ │Plugin   │   │
│  │         │ │         │ │ Mediator │ │         │ │Framework│   │
│  └─────────┘ └─────────┘ └─────────┘ └─────────┘ └─────────┘   │
└───────────────────────────┬─────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│                     Core Libraries                              │
│  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐   │
│  │ scrap   │ │hbb_common│ │ enigo   │ │clipboard│ │virtual  │   │
│  │(截图)   │ │(工具库)  │ │(输入)   │ │(剪贴板) │ │display  │   │
│  └─────────┘ └─────────┘ └─────────┘ └─────────┘ └─────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

#### 1.4.2 目录结构

```
rustdesk/
├── src/                    # 主应用代码
│   ├── client.rs           # 客户端连接逻辑
│   ├── server.rs           # 服务端管理
│   ├── rendezvous_mediator.rs # 中继/打洞协调
│   ├── server/             # 服务模块
│   │   ├── video_service.rs
│   │   ├── audio_service.rs
│   │   ├── input_service.rs
│   │   └── clipboard_service.rs
│   ├── platform/           # 平台特定代码
│   └── plugin/             # 插件框架
├── libs/                   # 核心库
│   ├── scrap/              # 屏幕捕获
│   ├── hbb_common/         # 通用工具
│   ├── enigo/              # 输入控制
│   └── clipboard/          # 剪贴板
├── flutter/                # Flutter UI
└── vcpkg/                  # C++依赖管理
```

#### 1.4.3 技术栈

| 层 | 技术 | 说明 |
|---|------|------|
| 语言 | Rust | 系统级编程语言，高性能、内存安全 |
| UI | Flutter | 跨平台UI框架 |
| 通信 | TCP/UDP/KCP | 多种传输协议支持 |
| 加密 | Sodiumoxide | 现代加密库 |
| 编解码 | libvpx/aom | 视频编解码 |
| 构建 | Cargo | Rust包管理器 |

---

## 2. 环境搭建指南

### 2.1 开发环境配置

#### 2.1.1 Rust 环境

**安装 Rust:**

```bash
# Linux/macOS
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source $HOME/.cargo/env

# 验证安装
rustc --version
cargo --version
```

**要求版本**: Rust 1.95 或更高

#### 2.1.2 Flutter 环境（可选）

如需开发 Flutter UI，需安装 Flutter SDK：

```bash
# 下载 Flutter
git clone https://github.com/flutter/flutter.git -b stable
export PATH="$PATH:`pwd`/flutter/bin"

# 验证
flutter doctor
```

#### 2.1.3 系统依赖

**Ubuntu/Debian:**

```bash
sudo apt install -y zip g++ gcc git curl wget nasm yasm libgtk-3-dev clang \
    libxcb-randr0-dev libxdo-dev libxfixes-dev libxcb-shape0-dev \
    libxcb-xfixes0-dev libasound2-dev libpulse-dev cmake make \
    libclang-dev ninja-build libgstreamer1.0-dev \
    libgstreamer-plugins-base1.0-dev libpam0g-dev
```

**Fedora/CentOS:**

```bash
sudo yum install -y gcc-c++ git curl wget nasm yasm gcc gtk3-devel clang \
    libxcb-devel libxdo-devel libXfixes-devel pulseaudio-libs-devel \
    cmake alsa-lib-devel gstreamer1-devel gstreamer1-plugins-base-devel pam-devel
```

**macOS:**

```bash
brew install nasm yasm pkg-config cmake
```

**Windows:**

推荐使用 Chocolatey 安装依赖：
```powershell
choco install nasm yasm cmake
```

### 2.2 依赖安装说明

#### 2.2.1 vcpkg 依赖

项目使用 vcpkg 管理 C++ 依赖：

```bash
# 克隆 vcpkg
git clone https://github.com/microsoft/vcpkg
cd vcpkg
git checkout 2023.04.15
cd ..

# 初始化
vcpkg/bootstrap-vcpkg.sh   # Linux/macOS
vcpkg/bootstrap-vcpkg.bat  # Windows

# 设置环境变量
export VCPKG_ROOT=/path/to/vcpkg  # Linux/macOS
set VCPKG_ROOT=C:\path\to\vcpkg   # Windows
```

**安装依赖包:**

```bash
# Windows
vcpkg install libvpx:x64-windows-static libyuv:x64-windows-static opus:x64-windows-static aom:x64-windows-static

# Linux/macOS
vcpkg install libvpx libyuv opus aom
```

#### 2.2.2 Sciter 库（已弃用，仅用于旧UI）

```bash
# Windows
wget https://raw.githubusercontent.com/c-smile/sciter-sdk/master/bin.win/x64/sciter.dll -O target/debug/sciter.dll

# Linux
wget https://raw.githubusercontent.com/c-smile/sciter-sdk/master/bin.lnx/x64/libsciter-gtk.so -O target/debug/libsciter-gtk.so

# macOS
wget https://raw.githubusercontent.com/c-smile/sciter-sdk/master/bin.osx/libsciter.dylib -O target/debug/libsciter.dylib
```

### 2.3 兼容性要求

| 平台 | 最低版本 | 推荐版本 |
|------|---------|---------|
| Windows | Windows 10 | Windows 11 |
| macOS | macOS 10.14 | macOS 13+ |
| Linux | Ubuntu 18.04 | Ubuntu 22.04 |
| Android | Android 8.0 | Android 11+ |
| iOS | iOS 14 | iOS 16+ |

### 2.4 验证方法

```bash
# 克隆项目
git clone https://github.com/rustdesk/rustdesk.git
cd rustdesk
git submodule update --init --recursive

# 构建验证
cargo build --release

# 运行测试
cargo test
```

**验证成功标志:**
- 编译无错误
- 测试全部通过
- 可执行文件生成在 `target/release/rustdesk`

---

## 3. 核心功能说明

### 3.1 远程桌面连接

#### 3.1.1 连接流程

```
┌──────────────┐      ┌──────────────────┐      ┌──────────────┐
│   Client     │      │ Rendezvous Server│      │   Server     │
│  (发起端)    │      │    (中继服务器)   │      │  (被控端)    │
└──────┬───────┘      └────────┬─────────┘      └──────┬───────┘
       │                       │                       │
       │ 1. 查询在线状态         │                       │
       │───────────────────────>│                       │
       │                       │                       │
       │                       │ 2. 注册设备信息         │
       │                       │<───────────────────────│
       │                       │                       │
       │ 3. 请求打洞/中继        │                       │
       │───────────────────────>│                       │
       │                       │                       │
       │                       │ 4. 通知被控端          │
       │                       │───────────────────────>│
       │                       │                       │
       │ 5. 返回连接信息         │                       │
       │<───────────────────────│                       │
       │                       │                       │
       │ 6. 尝试直连(打洞)       │<──────────────────────│
       │───────────────────────>│                       │
       │                       │                       │
       │ 7. 直连失败则中继        │                       │
       │───────────────────────>│───────────────────────>│
       │                       │                       │
       │ 8. 建立加密通道          │<──────────────────────│
       │<───────────────────────│<───────────────────────│
       │                       │                       │
```

#### 3.1.2 核心实现

**NAT 穿透策略:**

```rust
// src/client.rs
async fn _start_inner(
    peer: String,
    key: String,
    token: String,
    conn_type: ConnType,
    interface: impl Interface,
    udp: (Option<Arc<UdpSocket>>, Option<Arc<Mutex<u16>>>),
    stop_udp_tx: Option<oneshot::Sender<()>>,
    rendezvous_server: String,
    servers: Vec<String>,
    contained: bool,
) -> ResultType<...> {
    // 1. 连接 Rendezvous 服务器
    let mut socket = connect_tcp(&*rendezvous_server, CONNECT_TIMEOUT).await?;
    
    // 2. 发送打洞请求
    let mut msg_out = RendezvousMessage::new();
    msg_out.set_punch_hole_request(PunchHoleRequest {
        id: peer.to_owned(),
        token: token.to_owned(),
        nat_type: nat_type.into(),
        ..Default::default()
    });
    
    // 3. 尝试多种连接方式
    let mut connect_futures = Vec::new();
    connect_futures.push(connect_tcp_local(peer, ...).boxed());
    connect_futures.push(udp_nat_connect(udp_socket_nat, ...).boxed());
    connect_futures.push(udp_nat_connect(udp_socket_v6, ...).boxed());
    
    // 4. 选择第一个成功的连接
    match select_ok(connect_futures).await {
        Ok(conn) => conn,
        Err(e) => bail!(e),
    }
}
```

**连接类型优先级:**
1. **IPv6 直连** - 优先尝试 IPv6 直接连接
2. **UDP 打洞** - 使用 UDP NAT 穿透
3. **TCP 打洞** - 使用 TCP NAT 穿透
4. **中继连接** - 通过中继服务器转发

### 3.2 屏幕捕获

#### 3.2.1 架构设计

```
┌─────────────────────────────────────────────────────────────┐
│                    Display Service                          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │    Linux     │  │    Windows   │  │    macOS     │     │
│  │  X11/Wayland │  │   GDI/DXGI   │  │  CGDisplay   │     │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘     │
│         │                 │                 │               │
│         ▼                 ▼                 ▼               │
│  ┌──────────────────────────────────────────────┐           │
│  │            scrap Library                    │           │
│  │  - 帧捕获  - 编码  - 颜色转换               │           │
│  └──────────────────────────────────────────────┘           │
└─────────────────────────────────────────────────────────────┘
```

#### 3.2.2 核心组件

**Display Service (`src/server/display_service.rs`):**

| 方法 | 功能 |
|------|------|
| `new()` | 创建显示服务实例 |
| `start_capture()` | 开始屏幕捕获 |
| `stop_capture()` | 停止屏幕捕获 |
| `set_option()` | 设置捕获参数（分辨率、帧率等） |

**视频编码选项:**

| 编码格式 | 说明 | 平台支持 |
|---------|------|---------|
| VP8 | 开源编码，兼容性好 | 全平台 |
| VP9 | 更高压缩率 | 全平台 |
| AV1 | 最新标准，最佳压缩 | 需要硬件支持 |

### 3.3 输入控制

#### 3.3.1 输入服务架构

```
┌─────────────────────────────────────────────────────────────┐
│                    Input Service                            │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Input Types:                                        │   │
│  │  • Mouse (位置、按钮、滚轮)                           │   │
│  │  • Keyboard (按键、组合键)                            │   │
│  │  • Touch (多点触控)                                   │   │
│  └──────────────────────────────────────────────────────┘   │
│                           │                                 │
│         ┌─────────────────┼─────────────────┐               │
│         ▼                 ▼                 ▼               │
│  ┌──────────┐      ┌──────────┐      ┌──────────┐          │
│  │   Linux  │      │  Windows │      │   macOS  │          │
│  │  uinput  │      │  SendInput│      │  CGEvent │          │
│  └──────────┘      └──────────┘      └──────────┘          │
└─────────────────────────────────────────────────────────────┘
```

#### 3.3.2 核心实现

**输入事件处理 (`src/server/input_service.rs`):**

```rust
pub struct InputService {
    cursor_sender: Option<UnboundedSender<CursorMessage>>,
    pos_sender: Option<UnboundedSender<PosMessage>>,
    window_focus_sender: Option<UnboundedSender<WindowFocusMessage>>,
}

impl Service for InputService {
    fn name(&self) -> String { ... }
    
    fn on_message(&self, msg: &Message) {
        match msg.union {
            Some(message::Union::Cursor(cursor)) => {
                self.handle_cursor(cursor);
            }
            Some(message::Union::Mouse(mouse)) => {
                self.handle_mouse(mouse);
            }
            Some(message::Union::Keyboard(keyboard)) => {
                self.handle_keyboard(keyboard);
            }
            _ => {}
        }
    }
}
```

**鼠标事件类型:**

| 事件类型 | 值 | 说明 |
|---------|-----|------|
| MOUSE_TYPE_DOWN | 0 | 鼠标按下 |
| MOUSE_TYPE_UP | 1 | 鼠标释放 |
| MOUSE_TYPE_MOVE | 2 | 鼠标移动 |
| MOUSE_TYPE_SCROLL | 3 | 滚轮滚动 |

### 3.4 音频传输

#### 3.4.1 架构设计

```
┌─────────────────────────────────────────────────────────────┐
│                    Audio Service                           │
│                                                             │
│  录制端                    传输                    播放端   │
│  ┌─────────┐            ┌─────────┐            ┌─────────┐ │
│  │ capture │── opus ──>│ stream  │── opus ──>│ play    │ │
│  │         │ 编码       │         │ 解码       │         │ │
│  └─────────┘            └─────────┘            └─────────┘ │
│                                                             │
│  平台实现:                                                  │
│  • Linux: PulseAudio                                       │
│  • Windows: WASAPI                                         │
│  • macOS: CoreAudio                                        │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

#### 3.4.2 核心配置

**音频参数:**

| 参数 | 默认值 | 说明 |
|------|-------|------|
| 采样率 | 48000 Hz | 音频采样频率 |
| 通道数 | 2 | 立体声 |
| 位深度 | 16 bit | 采样精度 |
| 编码 | Opus | 低延迟编码 |
| 缓冲区 | 3000 ms | 音频缓冲时间 |

### 3.5 文件传输

#### 3.5.1 传输流程

```
┌──────────────┐      ┌──────────────┐
│   Sender     │      │   Receiver   │
└──────┬───────┘      └──────┬───────┘
       │                      │
       │ 1. 请求发送文件列表    │
       │─────────────────────>│
       │                      │
       │ 2. 接收确认          │
       │<─────────────────────│
       │                      │
       │ 3. 发送文件数据       │
       │─────────────────────>│
       │                      │
       │ 4. 发送完成/错误      │
       │─────────────────────>│
       │                      │
```

#### 3.5.2 核心实现

**文件管理器 (`src/client/file_trait.rs`):**

```rust
pub trait FileManager: Send + Sync {
    fn send_files(&self, files: Vec<String>) -> ResultType<()>;
    fn receive_files(&self, info: FileTransferInfo) -> ResultType<()>;
    fn cancel(&self) -> ResultType<()>;
    fn set_progress_callback(&self, callback: ProgressCallback);
}
```

**文件传输状态:**

| 状态 | 说明 |
|------|------|
| PENDING | 等待传输 |
| TRANSFERRING | 传输中 |
| COMPLETED | 完成 |
| FAILED | 失败 |
| CANCELLED | 取消 |

### 3.6 剪贴板同步

#### 3.6.1 同步机制

```
┌─────────────────────────────────────────────────────────────┐
│                  Clipboard Service                         │
│                                                             │
│  本地剪贴板          监听                  远程剪贴板       │
│  ┌─────────┐      ┌─────────┐      ┌─────────┐            │
│  │ 变化检测 │─────>│ 同步传输 │─────>│ 更新内容 │            │
│  └─────────┘      └─────────┘      └─────────┘            │
│       ^                                    │               │
│       │                                    │               │
│       └────────────────────────────────────┘               │
│                    双向同步                                 │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

#### 3.6.2 支持格式

| 格式 | 支持 | 说明 |
|------|------|------|
| 纯文本 | ✅ | 基础文本数据 |
| HTML | ✅ | 富文本内容 |
| 图像 | ✅ | 位图数据 |
| 文件 | ⚠️ | 仅 Linux/macOS |

---

## 4. API接口文档

### 4.1 通信协议概述

RustDesk 使用 **Protobuf** 作为主要通信协议，定义了两类核心消息：

1. **Rendezvous 协议** - 用于 NAT 穿透和中继协调
2. **Message 协议** - 用于客户端与服务端的实时通信

### 4.2 核心消息类型

#### 4.2.1 Rendezvous 消息

**PunchHoleRequest (打洞请求)**

```protobuf
message PunchHoleRequest {
  string id = 1;              // 目标设备ID
  string token = 2;           // 连接令牌
  NatType nat_type = 3;       // NAT类型
  string licence_key = 4;     // 许可证密钥
  ConnType conn_type = 5;     // 连接类型
  string version = 6;         // 客户端版本
  int32 udp_port = 7;         // UDP端口
  bool force_relay = 8;       // 是否强制中继
  bytes socket_addr_v6 = 9;   // IPv6地址
}
```

**PunchHoleResponse (打洞响应)**

```protobuf
message PunchHoleResponse {
  bytes socket_addr = 1;      // 对端地址
  bytes pk = 2;               // 公钥
  string relay_server = 3;    // 中继服务器
  Failure failure = 4;        // 失败原因
  string other_failure = 5;   // 其他失败信息
  bool is_local = 6;          // 是否局域网连接
  int32 feedback = 7;         // 反馈值
  bytes socket_addr_v6 = 8;   // IPv6地址
}
```

**RequestRelay (中继请求)**

```protobuf
message RequestRelay {
  string id = 1;              // 目标设备ID
  string token = 2;           // 连接令牌
  string uuid = 3;            // 请求UUID
  string relay_server = 4;    // 中继服务器地址
  bool secure = 5;            // 是否安全连接
  ControlPermissions control_permissions = 6;  // 控制权限
}
```

**RelayResponse (中继响应)**

```protobuf
message RelayResponse {
  bytes socket_addr = 1;      // 对端地址
  string uuid = 2;            // 请求UUID
  string relay_server = 3;    // 中继服务器
  string refuse_reason = 4;   // 拒绝原因
  bytes pk = 5;               // 公钥
  int32 feedback = 6;         // 反馈值
  bytes socket_addr_v6 = 7;   // IPv6地址
}
```

#### 4.2.2 Message 消息

**SignedId (签名ID)**

```protobuf
message SignedId {
  bytes id = 1;               // 签名的ID和公钥
}
```

**PublicKey (公钥交换)**

```protobuf
message PublicKey {
  bytes asymmetric_value = 1; // 非对称加密值
  bytes symmetric_value = 2;  // 对称加密值
}
```

**Cursor (鼠标光标)**

```protobuf
message Cursor {
  bytes image = 1;            // 光标图像数据
  int32 width = 2;            // 宽度
  int32 height = 3;           // 高度
  int32 hot_x = 4;            // 热点X
  int32 hot_y = 5;            // 热点Y
}
```

**Mouse (鼠标事件)**

```protobuf
message Mouse {
  int32 x = 1;                // X坐标
  int32 y = 2;                // Y坐标
  int32 button = 3;           // 按钮类型
  int32 action = 4;           // 动作类型
  int32 wheel = 5;            // 滚轮值
}
```

**Keyboard (键盘事件)**

```protobuf
message Keyboard {
  int32 key = 1;              // 按键码
  bool is_pressed = 2;        // 是否按下
  bool is_extended = 3;       // 是否扩展键
}
```

**Clipboard (剪贴板)**

```protobuf
message Clipboard {
  string text = 1;            // 文本内容
  bytes image = 2;            // 图像数据
  string html = 3;            // HTML内容
  repeated string files = 4;  // 文件列表
}
```

**VideoFrame (视频帧)**

```protobuf
message VideoFrame {
  bytes data = 1;             // 帧数据
  int32 width = 2;            // 宽度
  int32 height = 3;           // 高度
  CodecFormat codec = 4;      // 编码格式
  int32 flags = 5;            // 标志位
  int64 timestamp = 6;        // 时间戳
}
```

**AudioFrame (音频帧)**

```protobuf
message AudioFrame {
  bytes data = 1;             // 音频数据
  int32 sample_rate = 2;      // 采样率
  int32 channels = 3;         // 通道数
  int32 bits_per_sample = 4;  // 位深度
}
```

#### 4.2.3 枚举类型

**NatType (NAT类型)**

| 值 | 名称 | 说明 |
|-----|------|------|
| 0 | UNKNOWN_NAT | 未知 |
| 1 | SYMMETRIC | 对称NAT |
| 2 | ASYMMETRIC | 非对称NAT |
| 3 | PORT_RESTRICTED | 端口受限 |
| 4 | ADDRESS_RESTRICTED | 地址受限 |

**ConnType (连接类型)**

| 值 | 名称 | 说明 |
|-----|------|------|
| 0 | DEFAULT_CONN | 默认连接 |
| 1 | FILE_CONN | 文件传输 |
| 2 | CAMERA_CONN | 摄像头 |
| 3 | AUDIO_ONLY_CONN | 仅音频 |

### 4.3 接口示例

#### 4.3.1 建立连接流程

**Step 1: 发送打洞请求**

```rust
use hbb_common::rendezvous_proto::{RendezvousMessage, PunchHoleRequest};

let mut msg_out = RendezvousMessage::new();
msg_out.set_punch_hole_request(PunchHoleRequest {
    id: "123456".to_owned(),
    token: "abc123".to_owned(),
    nat_type: NatType::ASYMMETRIC.into(),
    licence_key: "".to_owned(),
    conn_type: ConnType::DEFAULT_CONN.into(),
    version: "2.0.0".to_owned(),
    udp_port: 0,
    force_relay: false,
    socket_addr_v6: vec![],
});

socket.send(&msg_out).await?;
```

**Step 2: 处理打洞响应**

```rust
match msg_in.union {
    Some(rendezvous_message::Union::PunchHoleResponse(ph)) => {
        if ph.socket_addr.is_empty() {
            // 处理失败
            bail!("Failed: {:?}", ph.failure);
        } else {
            // 成功获取连接信息
            let peer_addr = AddrMangle::decode(&ph.socket_addr);
            let relay_server = ph.relay_server;
            // 尝试建立连接
        }
    }
    _ => {}
}
```

**Step 3: 发送鼠标事件**

```rust
use hbb_common::message_proto::{Message, Mouse};

let mut msg = Message::new();
msg.set_mouse(Mouse {
    x: 100,
    y: 200,
    button: MOUSE_BUTTON_LEFT,
    action: MOUSE_TYPE_DOWN,
    wheel: 0,
});

conn.send(&msg).await?;
```

#### 4.3.2 消息序列化

**Protobuf 编码/解码:**

```rust
// 编码
let msg = Message::new();
let bytes = msg.write_to_bytes()?;

// 解码
let msg = Message::parse_from_bytes(&bytes)?;
```

**加密传输:**

```rust
// 设置加密密钥
conn.set_key(encryption_key);

// 发送加密消息
conn.send(&msg).await?;
```

---

## 5. 数据模型设计

### 5.1 配置结构

RustDesk 使用分层配置管理，主要包含以下配置类型：

```
┌─────────────────────────────────────────────────────────────┐
│                      Config System                         │
│                                                             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │   Config    │  │   Config2   │  │ LocalConfig │        │
│  │ (设备配置)   │  │ (运行配置)   │  │ (本地配置)   │        │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘        │
│         │                │                │                 │
│         ▼                ▼                ▼                 │
│  ┌──────────────────────────────────────────────┐          │
│  │              PeerConfig                      │          │
│  │        (会话级别配置)                         │          │
│  └──────────────────────────────────────────────┘          │
└─────────────────────────────────────────────────────────────┘
```

#### 5.1.1 Config（设备配置）

**核心字段:**

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | String | 设备唯一标识 |
| `enc_id` | String | 加密后的ID |
| `password` | String | 访问密码（哈希存储） |
| `salt` | String | 密码盐值 |
| `key_pair` | KeyPair | Ed25519 密钥对 |
| `key_confirmed` | bool | 密钥是否已确认 |
| `keys_confirmed` | HashMap | 已确认的主机密钥 |

**数据结构:**

```rust
#[derive(Debug, Default, PartialEq, Serialize, Deserialize, Clone)]
pub struct Config {
    pub id: String,                     // 设备ID
    enc_id: String,                     // 加密ID（存储用）
    password: String,                   // 密码哈希
    salt: String,                       // 盐值
    key_pair: KeyPair,                  // (私钥, 公钥)
    key_confirmed: bool,                // 密钥确认状态
    keys_confirmed: HashMap<String, bool>, // 主机密钥确认列表
}
```

#### 5.1.2 Config2（运行配置）

**核心字段:**

| 字段 | 类型 | 说明 |
|------|------|------|
| `rendezvous_server` | String | 默认中继服务器 |
| `nat_type` | i32 | NAT类型 |
| `serial` | i32 | 配置版本号 |
| `unlock_pin` | String | 解锁PIN |
| `trusted_devices` | String | 可信设备列表 |
| `socks` | Option\<Socks5Server\> | SOCKS5代理配置 |
| `options` | HashMap | 自定义选项 |

**数据结构:**

```rust
#[derive(Debug, Default, Serialize, Deserialize, Clone, PartialEq)]
pub struct Config2 {
    rendezvous_server: String,
    nat_type: i32,
    serial: i32,
    unlock_pin: String,
    trusted_devices: String,
    socks: Option<Socks5Server>,
    pub options: HashMap<String, String>,
}
```

#### 5.1.3 PeerConfig（会话配置）

**核心字段:**

| 字段 | 类型 | 说明 |
|------|------|------|
| `password` | Vec\<u8\> | 会话密码 |
| `size` | Size | 窗口尺寸 |
| `view_style` | String | 显示风格 |
| `scroll_style` | String | 滚动风格 |
| `image_quality` | String | 图像质量 |
| `show_remote_cursor` | bool | 显示远程光标 |
| `privacy_mode` | bool | 隐私模式 |
| `disable_audio` | bool | 禁用音频 |
| `disable_clipboard` | bool | 禁用剪贴板 |

**数据结构:**

```rust
#[derive(Debug, Serialize, Deserialize, Clone, PartialEq)]
pub struct PeerConfig {
    pub password: Vec<u8>,
    pub size: Size,
    pub view_style: String,
    pub scroll_style: String,
    pub image_quality: String,
    pub show_remote_cursor: ShowRemoteCursor,
    pub privacy_mode: PrivacyMode,
    // ... 更多字段
}
```

#### 5.1.4 Socks5Server（代理配置）

```rust
#[derive(Debug, Default, PartialEq, Serialize, Deserialize, Clone)]
pub struct Socks5Server {
    pub proxy: String,        // 代理地址
    pub username: String,     // 用户名
    pub password: String,     // 密码
}
```

### 5.2 数据流转

#### 5.2.1 配置加载流程

```
┌─────────────────────────────────────────────────────────────┐
│                    Config Loading                          │
│                                                             │
│  1. 程序启动                                                │
│       │                                                     │
│       ▼                                                     │
│  2. 加载 Config (设备标识、密钥)                             │
│       │                                                     │
│       ▼                                                     │
│  3. 加载 Config2 (运行参数、代理)                           │
│       │                                                     │
│       ▼                                                     │
│  4. 加载 LocalConfig (本地缓存)                            │
│       │                                                     │
│       ▼                                                     │
│  5. 应用默认值和覆盖设置                                    │
│       │                                                     │
│       ▼                                                     │
│  6. 运行时使用                                              │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**配置加载代码示例:**

```rust
// libs/hbb_common/src/config.rs
lazy_static::lazy_static! {
    static ref CONFIG: RwLock<Config> = RwLock::new(Config::load());
    static ref CONFIG2: RwLock<Config2> = RwLock::new(Config2::load());
    static ref LOCAL_CONFIG: RwLock<LocalConfig> = RwLock::new(LocalConfig::load());
}

impl Config {
    pub fn get() -> Config {
        CONFIG.read().unwrap().clone()
    }
    
    pub fn set(cfg: Config) -> bool {
        let mut lock = CONFIG.write().unwrap();
        if *lock == cfg {
            return false;
        }
        *lock = cfg;
        lock.store();
        true
    }
}
```

#### 5.2.2 密钥管理

**密钥生成流程:**

```
┌─────────────────────────────────────────────────────────────┐
│                   Key Pair Management                      │
│                                                             │
│  1. 首次启动                                                │
│       │                                                     │
│       ▼                                                     │
│  2. 检查是否存在密钥对                                       │
│       │                                                     │
│       ├── 存在 ──> 使用现有密钥                              │
│       │                                                     │
│       └── 不存在 ──> 生成新密钥对                           │
│                          │                                 │
│                          ▼                                 │
│                   保存到配置文件                            │
│                                                             │
│  3. 连接时使用公钥进行身份验证                                │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**密钥生成实现:**

```rust
pub fn get_key_pair() -> KeyPair {
    let mut lock = KEY_PAIR.lock().unwrap();
    if let Some(p) = lock.as_ref() {
        return p.clone();
    }
    
    let mut config = Config::load_::<Config>("");
    if config.key_pair.0.is_empty() {
        // 生成新密钥对
        let (pk, sk) = sign::gen_keypair();
        let key_pair = (sk.0.to_vec(), pk.0.into());
        config.key_pair = key_pair.clone();
        // 异步保存
        std::thread::spawn(|| {
            let mut config = CONFIG.write().unwrap();
            config.key_pair = key_pair;
            config.store();
        });
    }
    
    *lock = Some(config.key_pair.clone());
    config.key_pair
}
```

#### 5.2.3 密码安全

**密码存储机制:**

```rust
// 密码哈希计算
pub fn compute_permanent_password_h1(
    password: &str,
    salt: &str,
) -> [u8; PERMANENT_PASSWORD_H1_LEN] {
    let mut hasher = Sha256::new();
    hasher.update(password.as_bytes());
    hasher.update(salt.as_bytes());
    let out = hasher.finalize();
    let mut h1 = [0u8; PERMANENT_PASSWORD_H1_LEN];
    h1.copy_from_slice(&out[..PERMANENT_PASSWORD_H1_LEN]);
    h1
}

// 编码存储格式
fn encode_permanent_password_storage_from_h1(h1: &[u8; 32]) -> String {
    PERMANENT_PASSWORD_HASH_PREFIX.to_owned() + &base64::encode(h1, base64::Variant::Original)
}
```

**密码验证流程:**

```
┌─────────────────────────────────────────────────────────────┐
│                    Password Verification                   │
│                                                             │
│  1. 用户输入密码                                            │
│       │                                                     │
│       ▼                                                     │
│  2. 获取存储的盐值和哈希                                     │
│       │                                                     │
│       ▼                                                     │
│  3. 使用相同盐值计算输入密码的哈希                            │
│       │                                                     │
│       ▼                                                     │
│  4. 常量时间比较两个哈希值                                   │
│       │                                                     │
│       ├── 匹配 ──> 验证成功                                 │
│       │                                                     │
│       └── 不匹配 ──> 验证失败                               │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

#### 5.2.4 配置文件位置

**平台特定路径:**

| 平台 | 配置目录 |
|------|---------|
| Windows | `%APPDATA%\RustDesk` |
| macOS | `~/Library/Application Support/RustDesk` |
| Linux | `~/.config/RustDesk` |
| Android | `data/data/com.carriez.flutter_hbb/files` |

---

## 6. 开发规范

### 6.1 代码规范

#### 6.1.1 Rust 代码规范

**核心原则:**

1. **错误处理**: 禁止使用 `unwrap()` 和 `expect()`，必须显式处理错误
   - 允许在测试中使用 `unwrap()` 以保持测试简洁
   - 允许在锁获取时使用 `unwrap()`（处理poison情况）

2. **代码格式化**: 使用 `rustfmt` 自动格式化
   ```bash
   cargo fmt
   ```

3. **静态检查**: 使用 `clippy` 进行代码检查
   ```bash
   cargo clippy -- -D warnings
   ```

**错误处理示例:**

```rust
// 推荐
fn connect() -> Result<TcpStream, Error> {
    let stream = TcpStream::connect("127.0.0.1:8080")?;
    Ok(stream)
}

// 不推荐
fn connect() -> TcpStream {
    TcpStream::connect("127.0.0.1:8080").unwrap()  // ❌ 禁止
}
```

**锁获取例外:**

```rust
// 允许：锁获取使用 unwrap()
let data = data.lock().unwrap();
```

#### 6.1.2 Flutter 代码规范

**核心原则:**

1. **代码风格**: 遵循 Dart 官方风格指南
2. **格式化**: 使用 `dartfmt`
   ```bash
   dart format .
   ```
3. **分析**: 使用 `dart analyze`

**Flutter 最佳实践:**

| 规范 | 说明 |
|------|------|
| Widget 结构 | 拆分复杂组件，保持单一职责 |
| 状态管理 | 使用 Provider/BLoC/StateNotifier |
| 代码组织 | 按功能模块组织文件 |

### 6.2 命名约定

#### 6.2.1 Rust 命名规则

| 类型 | 规则 | 示例 |
|------|------|------|
| 模块 | 蛇形命名 | `video_service.rs` |
| 文件 | 蛇形命名 | `rendezvous_mediator.rs` |
| 结构体 | 帕斯卡命名 | `struct InputService` |
| 枚举 | 帕斯卡命名 | `enum ConnType` |
| 函数 | 蛇形命名 | `fn connect_tcp()` |
| 方法 | 蛇形命名 | `fn start_capture()` |
| 变量 | 蛇形命名 | `let peer_addr` |
| 常量 | 大写蛇形 | `const MAX_RETRY = 3` |
| 泛型参数 | 单字母大写 | `T`, `U` |

**示例:**

```rust
// 结构体
pub struct VideoFrame {
    width: usize,
    height: usize,
}

// 方法
impl VideoFrame {
    pub fn new(width: usize, height: usize) -> Self {
        VideoFrame { width, height }
    }
    
    pub fn get_size(&self) -> (usize, usize) {
        (self.width, self.height)
    }
}
```

#### 6.2.2 Flutter/Dart 命名规则

| 类型 | 规则 | 示例 |
|------|------|------|
| 文件 | 蛇形命名 | `video_player.dart` |
| 类 | 帕斯卡命名 | `class RemoteDesktop` |
| 方法 | 小驼峰命名 | `void connectToServer()` |
| 变量 | 小驼峰命名 | `var peerId` |
| 常量 | 大写蛇形 | `const MAX_RETRY = 3` |
| Widget | 帕斯卡命名 | `class CustomButton` |

### 6.3 提交规范

#### 6.3.1 提交消息格式

**格式:**
```
<type>(<scope>): <subject>

<body>

<footer>
```

**类型说明:**

| 类型 | 说明 |
|------|------|
| `feat` | 新功能 |
| `fix` | 修复bug |
| `docs` | 文档更新 |
| `style` | 代码格式（不影响功能） |
| `refactor` | 重构（既不是新增功能也不是修复bug） |
| `perf` | 性能优化 |
| `test` | 测试相关 |
| `chore` | 构建/工具/依赖更新 |

**示例:**

```
feat(video): 添加硬件编码支持

- 新增 VP9 硬件编码选项
- 添加编码器配置接口
- 更新编码参数验证

BREAKING CHANGE: VideoConfig 结构变更
```

#### 6.3.2 提交规则

1. **原子提交**: 每个提交只包含一个逻辑变更
2. **清晰描述**: 使用英文描述，简洁明了
3. **关联Issue**: 在footer中引用Issue编号

### 6.4 分支管理策略

#### 6.4.1 分支结构

```
┌─────────────────────────────────────────────────────────────┐
│                    Branch Structure                        │
│                                                             │
│  main                    # 主分支，稳定版本                 │
│     │                                                       │
│     ├── develop          # 开发分支，整合功能               │
│     │     │                                                 │
│     │     ├── feature/xxx   # 功能特性分支                 │
│     │     ├── bugfix/xxx    # bug修复分支                  │
│     │     └── hotfix/xxx    # 紧急修复分支                 │
│     │                                                       │
│     └── release/xxx      # 发布分支                       │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

#### 6.4.2 分支命名规范

| 分支类型 | 命名格式 | 示例 |
|---------|---------|------|
| 功能分支 | `feature/xxx` | `feature/hwcodec-support` |
| Bug修复 | `bugfix/xxx` | `bugfix/connection-timeout` |
| 紧急修复 | `hotfix/xxx` | `hotfix/crash-on-startup` |
| 发布分支 | `release/xxx` | `release/v2.0.0` |

#### 6.4.3 开发流程

**功能开发:**
```
1. 从 develop 创建 feature 分支
2. 在 feature 分支开发
3. 推送至远程仓库
4. 创建 Pull Request
5. 代码审查通过后合并到 develop
```

**发布流程:**
```
1. 从 develop 创建 release 分支
2. 进行发布准备（版本号更新、文档更新）
3. 测试验证
4. 合并到 main 分支
5. 创建 Tag
6. 合并回 develop
```

**紧急修复:**
```
1. 从 main 创建 hotfix 分支
2. 修复问题
3. 合并到 main 和 develop
4. 创建 Tag
```

### 6.5 代码审查流程

#### 6.5.1 PR 提交要求

1. **必须通过 CI**: 所有测试必须通过
2. **代码覆盖率**: 新增代码需有测试覆盖
3. **审查人**: 至少需要 1 位审查人批准
4. **描述清晰**: PR 描述需说明变更内容和原因

#### 6.5.2 审查要点

| 检查项 | 说明 |
|--------|------|
| 代码质量 | 结构清晰、注释适当 |
| 错误处理 | 是否正确处理错误 |
| 性能影响 | 是否有性能问题 |
| 兼容性 | 是否破坏向后兼容 |
| 测试覆盖 | 测试是否充分 |

---

## 7. 常见问题解决方案

### 7.1 开发环境问题

#### 7.1.1 vcpkg 依赖安装失败

**问题描述:**
```
error: failed to build `libvpx-sys v1.14.0`
Caused by: process didn't exit successfully: ...
```

**解决方案:**

1. **检查 vcpkg 版本**
```bash
cd vcpkg
git checkout 2023.04.15
```

2. **清理缓存并重新安装**
```bash
vcpkg remove libvpx libyuv opus aom
vcpkg install libvpx:x64-windows-static libyuv:x64-windows-static opus:x64-windows-static aom:x64-windows-static
```

3. **设置环境变量**
```bash
export VCPKG_ROOT=/path/to/vcpkg
export VCPKG_DEFAULT_TRIPLET=x64-windows-static
```

#### 7.1.2 Rust 编译错误：找不到系统库

**问题描述:**
```
error: could not find native static library `vpx`, perhaps an -L flag is missing?
```

**解决方案:**

1. **检查 vcpkg 集成**
```bash
vcpkg integrate install
```

2. **验证依赖安装**
```bash
vcpkg list | grep libvpx
```

3. **手动设置链接路径**
```bash
# Windows
set VCPKG_ROOT=C:\path\to\vcpkg
cargo build

# Linux/macOS
export VCPKG_ROOT=/path/to/vcpkg
cargo build
```

#### 7.1.3 Flutter 编译失败

**问题描述:**
```
Error: Cannot run with sound null safety, because the following dependencies don't support null safety:
```

**解决方案:**

1. **更新 Flutter 版本**
```bash
flutter channel stable
flutter upgrade
```

2. **检查依赖版本**
```bash
cd flutter
flutter pub outdated
flutter pub upgrade
```

3. **强制启用空安全**
```bash
flutter run --no-sound-null-safety  # 临时方案
```

### 7.2 连接问题

#### 7.2.1 NAT 穿透失败

**问题描述:**
```
Connection failed: Punch hole failed, using relay
```

**诊断步骤:**

1. **检查网络类型**
```bash
# 查看 NAT 类型
rustdesk --diagnose
```

2. **检查防火墙设置**
   - 确保 UDP 端口开放（默认 21115-21119）
   - 检查路由器端口转发规则

3. **尝试强制中继**
```bash
rustdesk --force-relay
```

**解决方案:**

| NAT类型 | 解决方案 |
|---------|---------|
| 对称NAT | 使用中继服务器 |
| 端口受限 | 检查防火墙规则 |
| 地址受限 | 配置端口转发 |

#### 7.2.2 连接超时

**问题描述:**
```
Timeout connecting to peer
```

**诊断步骤:**

1. **检查网络连通性**
```bash
ping relay.rustdesk.com
telnet relay.rustdesk.com 21117
```

2. **检查代理设置**
```bash
echo $http_proxy
echo $https_proxy
```

3. **检查服务器状态**
```bash
curl https://status.rustdesk.com
```

**解决方案:**

1. **增加超时时间**
```rust
// 在连接配置中增加超时
let conn = connect_tcp(&addr, Duration::from_secs(30)).await?;
```

2. **配置代理**
```bash
export http_proxy=http://proxy:8080
export https_proxy=http://proxy:8080
```

#### 7.2.3 认证失败

**问题描述:**
```
Authentication failed: Invalid password
```

**诊断步骤:**

1. **验证密码正确性**
   - 确认两端密码一致
   - 检查密码是否包含特殊字符

2. **检查密钥状态**
```bash
cat ~/.config/RustDesk/config.json | grep key_pair
```

**解决方案:**

1. **重置密码**
```bash
rustdesk --reset-password
```

2. **重新生成密钥**
```bash
rustdesk --regenerate-key
```

### 7.3 屏幕捕获问题

#### 7.3.1 黑屏或显示不全

**问题描述:**
- 远程屏幕显示黑屏
- 屏幕显示不全或卡顿

**诊断步骤:**

1. **检查权限**
```bash
# Linux
ls -la /dev/video*
groups | grep video

# macOS
security find-certificate -a -p /Library/Keychains/System.keychain
```

2. **检查显示设置**
```bash
xrandr  # Linux
system_profiler SPDisplaysDataType  # macOS
```

**解决方案:**

1. **Linux: 添加权限**
```bash
sudo usermod -aG video $USER
sudo usermod -aG input $USER
```

2. **macOS: 授予屏幕录制权限**
   - 系统设置 > 隐私与安全性 > 屏幕录制
   - 勾选 RustDesk

3. **Windows: 检查虚拟显示器**
```bash
rustdesk --enable-virtual-display
```

#### 7.3.2 帧率过低

**问题描述:**
```
Frame rate: 5 FPS (expected: 30 FPS)
```

**诊断步骤:**

1. **检查系统资源**
```bash
top  # Linux/macOS
tasklist  # Windows
```

2. **检查网络带宽**
```bash
speedtest-cli
```

3. **检查编码设置**
```bash
rustdesk --get-encoder
```

**解决方案:**

1. **降低分辨率**
```bash
rustdesk --resolution 1280x720
```

2. **调整编码参数**
```bash
rustdesk --encoder vp8 --quality balanced
```

3. **升级硬件编码**
```bash
cargo build --features hwcodec
```

### 7.4 音频问题

#### 7.4.1 音频无法传输

**问题描述:**
- 无法听到远程声音
- 麦克风无法传输

**诊断步骤:**

1. **检查音频设备**
```bash
# Linux
arecord -l
aplay -l

# macOS
system_profiler SPAudioDataType

# Windows
control mmsys.cpl
```

2. **检查权限**
```bash
# Linux
groups | grep audio
```

**解决方案:**

1. **Linux: 添加音频组**
```bash
sudo usermod -aG audio $USER
```

2. **macOS: 授予麦克风权限**
   - 系统设置 > 隐私与安全性 > 麦克风
   - 勾选 RustDesk

3. **检查音频服务**
```bash
rustdesk --restart-audio-service
```

### 7.5 部署问题

#### 7.5.1 中继服务器启动失败

**问题描述:**
```
Error: Failed to bind to port 21117
```

**诊断步骤:**

1. **检查端口占用**
```bash
netstat -tlnp | grep 21117
ss -tlnp | grep 21117
```

2. **检查权限**
```bash
# 检查是否以 root 运行（需要绑定 1024 以下端口）
id
```

**解决方案:**

1. **释放端口**
```bash
kill -9 $(lsof -ti:21117)
```

2. **使用其他端口**
```bash
rustdesk-server --port 21120
```

3. **使用非 root 用户**
```bash
sudo setcap 'cap_net_bind_service=+ep' /path/to/rustdesk-server
```

#### 7.5.2 SSL 证书问题

**问题描述:**
```
SSL handshake failed: certificate verify failed
```

**诊断步骤:**

1. **检查证书有效期**
```bash
openssl x509 -in cert.pem -text -noout | grep Not
```

2. **检查证书链**
```bash
openssl verify cert.pem
```

**解决方案:**

1. **更新证书**
```bash
openssl req -new -x509 -days 365 -key server.key -out server.crt
```

2. **配置完整证书链**
```bash
cat cert.pem chain.pem > fullchain.pem
```

### 7.6 性能问题

#### 7.6.1 高 CPU 占用

**问题描述:**
```
CPU usage: 95% (rustdesk)
```

**诊断步骤:**

1. **分析进程**
```bash
top -p $(pidof rustdesk)
htop
```

2. **检查线程**
```bash
ps -T -p $(pidof rustdesk)
```

**解决方案:**

1. **降低帧率**
```bash
rustdesk --fps 15
```

2. **禁用硬件加速**
```bash
rustdesk --no-hardware-acceleration
```

3. **更新驱动**
```bash
# Linux
sudo apt update && sudo apt upgrade

# Windows
# 通过设备管理器更新显卡驱动
```

#### 7.6.2 内存泄漏

**问题描述:**
```
Memory usage: 2GB (increasing over time)
```

**诊断步骤:**

1. **监控内存**
```bash
# Linux
watch -n 1 free -m

# macOS
vm_stat
```

2. **使用工具分析**
```bash
valgrind --leak-check=full ./rustdesk
```

**解决方案:**

1. **升级版本**
```bash
git pull
cargo build --release
```

2. **报告问题**
```bash
rustdesk --report-issue
```

---

## 8. 二次开发指南

### 8.1 扩展机制说明

RustDesk 提供了灵活的插件框架，允许开发者扩展功能而不修改核心代码。

#### 8.1.1 插件架构

```
┌─────────────────────────────────────────────────────────────┐
│                    Plugin Framework                        │
│                                                             │
│  ┌─────────────────┐      ┌─────────────────┐             │
│  │   Core System   │◄─────│  Plugin Manager │             │
│  │   (核心系统)    │      │   (插件管理器)   │             │
│  └────────┬────────┘      └────────┬────────┘             │
│           │                        │                      │
│           │  Service API           │  Plugin Registry     │
│           │                        │                      │
│           ▼                        ▼                      │
│  ┌──────────────────────────────────────────────────────┐  │
│  │                   Plugins                            │  │
│  │  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐    │  │
│  │  │  Video  │ │  Audio  │ │  Input  │ │ Custom  │    │  │
│  │  │ Plugin  │ │ Plugin  │ │ Plugin  │ │ Plugin  │    │  │
│  │  └─────────┘ └─────────┘ └─────────┘ └─────────┘    │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

#### 8.1.2 扩展点

| 扩展点 | 说明 | 接口 |
|--------|------|------|
| 视频编码 | 自定义视频编码器 | `VideoEncoder trait` |
| 音频处理 | 自定义音频处理器 | `AudioProcessor trait` |
| 输入处理 | 自定义输入事件处理 | `InputHandler trait` |
| UI 组件 | 自定义 UI 组件 | `Widget trait` |
| 协议扩展 | 自定义协议消息 | `MessageHandler trait` |

### 8.2 插件开发流程

#### 8.2.1 创建插件项目

**步骤 1: 创建新的 Rust 库**

```bash
cargo new rustdesk-plugin-example --lib
cd rustdesk-plugin-example
```

**步骤 2: 添加依赖**

```toml
# Cargo.toml
[package]
name = "rustdesk-plugin-example"
version = "0.1.0"
edition = "2021"

[dependencies]
rustdesk-plugin = { path = "../libs/plugin" }
hbb_common = { path = "../libs/hbb_common" }
```

**步骤 3: 实现插件**

```rust
// src/lib.rs
use rustdesk_plugin::{Plugin, PluginContext, Result};

struct ExamplePlugin;

impl Plugin for ExamplePlugin {
    fn name(&self) -> &str {
        "example"
    }
    
    fn init(&mut self, context: &mut PluginContext) -> Result<()> {
        println!("Example plugin initialized");
        Ok(())
    }
    
    fn start(&mut self) -> Result<()> {
        println!("Example plugin started");
        Ok(())
    }
    
    fn stop(&mut self) -> Result<()> {
        println!("Example plugin stopped");
        Ok(())
    }
}

#[no_mangle]
pub extern "C" fn rustdesk_plugin_create() -> *mut dyn Plugin {
    Box::into_raw(Box::new(ExamplePlugin))
}
```

**步骤 4: 编译插件**

```bash
cargo build --release
```

**步骤 5: 安装插件**

```bash
cp target/release/librustdesk_plugin_example.so ~/.rustdesk/plugins/
```

#### 8.2.2 视频编码器插件示例

```rust
use rustdesk_plugin::{VideoEncoder, VideoFrame, EncoderConfig};

struct CustomEncoder;

impl VideoEncoder for CustomEncoder {
    fn configure(&mut self, config: EncoderConfig) -> Result<()> {
        // 配置编码器参数
        Ok(())
    }
    
    fn encode(&mut self, frame: &VideoFrame) -> Result<Vec<u8>> {
        // 自定义编码逻辑
        Ok(vec![])
    }
    
    fn get_configuration(&self) -> EncoderConfig {
        EncoderConfig {
            codec: "custom".to_string(),
            width: 1920,
            height: 1080,
            fps: 30,
            bitrate: 2000000,
        }
    }
}
```

### 8.3 接口扩展规范

#### 8.3.1 消息协议扩展

**定义新消息类型:**

```protobuf
// plugin_example.proto
syntax = "proto3";

package rustdesk.plugin.example;

message CustomMessage {
  string action = 1;
  bytes data = 2;
}
```

**实现消息处理:**

```rust
use rustdesk_plugin::{MessageHandler, Message};

impl MessageHandler for ExamplePlugin {
    fn handle_message(&mut self, msg: &Message) -> Result<Option<Message>> {
        match msg.union {
            Some(message::Union::Custom(custom)) => {
                // 处理自定义消息
                Ok(None)
            }
            _ => Ok(None),
        }
    }
}
```

#### 8.3.2 UI 组件扩展

**实现自定义 Widget:**

```rust
use rustdesk_plugin::{Widget, WidgetContext};

struct CustomWidget;

impl Widget for CustomWidget {
    fn name(&self) -> &str {
        "custom_widget"
    }
    
    fn render(&self, context: &mut WidgetContext) -> Result<()> {
        // 渲染逻辑
        Ok(())
    }
    
    fn handle_event(&mut self, event: &WidgetEvent) -> Result<()> {
        // 事件处理
        Ok(())
    }
}
```

---

## 9. 项目部署

### 9.1 部署架构

#### 9.1.1 服务端架构

```
┌─────────────────────────────────────────────────────────────┐
│                    Deployment Architecture                 │
│                                                             │
│  ┌─────────────────┐                                        │
│  │   Load Balancer │                                        │
│  └────────┬────────┘                                        │
│           │                                                 │
│           ▼                                                 │
│  ┌──────────────────────────────────────────────────────┐   │
│  │               Rendezvous Servers                     │   │
│  │  ┌─────────┐ ┌─────────┐ ┌─────────┐                │   │
│  │  │ Server1 │ │ Server2 │ │ Server3 │                │   │
│  │  └─────────┘ └─────────┘ └─────────┘                │   │
│  └───────────────────┬──────────────────────────────────┘   │
│                      │                                      │
│                      ▼                                      │
│  ┌──────────────────────────────────────────────────────┐   │
│  │                Relay Servers                         │   │
│  │  ┌─────────┐ ┌─────────┐ ┌─────────┐                │   │
│  │  │ Relay1  │ │ Relay2  │ │ Relay3  │                │   │
│  │  └─────────┘ └─────────┘ └─────────┘                │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐   │
│  │                   Database                           │   │
│  │         PostgreSQL / SQLite                          │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

#### 9.1.2 端口规划

| 服务 | 端口 | 协议 | 说明 |
|------|------|------|------|
