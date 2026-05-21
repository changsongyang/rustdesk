# RustDesk macOS 平台编译指南

## 目录

1. [环境准备](#1-环境准备)
2. [源码获取](#2-源码获取)
3. [编译步骤](#3-编译步骤)
4. [服务配置](#4-服务配置)
5. [防火墙配置](#5-防火墙配置)
6. [性能优化](#6-性能优化)
7. [故障排除](#7-故障排除)
8. [验证部署](#8-验证部署)

---

## 1. 环境准备

### 1.1 系统要求

| 项目 | 最低要求 | 推荐配置 |
|------|----------|----------|
| macOS 版本 | macOS 11 (Big Sur) | macOS 13 (Ventura) 或更新 |
| CPU | Apple Silicon 或 Intel | Apple Silicon M1/M2/M3 |
| 内存 | 4 GB | 8 GB 或更多 |
| 磁盘空间 | 15 GB | 30 GB 或更多 |

### 1.2 Xcode Command Line Tools

#### 1.2.1 安装

```bash
xcode-select --install
```

或下载 Xcode 从 Mac App Store。

#### 1.2.2 验证

```bash
xcode-select -p
xcodebuild -version
```

### 1.3 Homebrew 安装

如果未安装 Homebrew，执行以下命令：

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### 1.4 Rust 安装

#### 1.4.1 使用 rustup 安装

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
```

#### 1.4.2 添加目标平台

```bash
# Apple Silicon (M1/M2/M3)
rustup target add aarch64-apple-darwin

# Intel Mac
rustup target add x86_64-apple-darwin

# 通用二进制（可选，需要 macOS 11+）
rustup target add aarch64-apple-darwin x86_64-apple-darwin
```

#### 1.4.3 验证安装

```bash
rustc --version
cargo --version
rustup --version
```

### 1.5 安装编译依赖

#### 1.5.1 基础工具

```bash
brew install cmake ninja pkg-config autoconf automake libtool
```

#### 1.5.2 视频编解码库

```bash
brew install ffmpeg opus libvpx
```

#### 1.5.3 其他依赖

```bash
brew install nasm protobuf sqlite3
```

#### 1.5.4 可选依赖

```bash
# 用于录音功能
brew install portaudio

# 性能分析
brew install valgrind
```

### 1.6 依赖验证

```bash
# 检查所有依赖
brew list cmake ninja pkg-config autoconf automake libtool ffmpeg opus libvpx nasm protobuf sqlite3

# 验证工具版本
cmake --version
ninja --version
pkg-config --version
protoc --version
nasm --version
```

### 1.7 自动化安装脚本

创建 `install-deps.sh`：

```bash
#!/bin/bash
set -e

echo "=== RustDesk macOS 编译环境安装 ==="

# 检查 Xcode Command Line Tools
if ! command -v xcode-select &> /dev/null; then
    echo "错误: Xcode Command Line Tools 未安装"
    exit 1
fi

# 检查并安装 Homebrew
if ! command -v brew &> /dev/null; then
    echo "安装 Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# 更新 Homebrew
brew update

# 安装基础工具
echo "安装基础工具..."
brew install cmake ninja pkg-config autoconf automake libtool

# 安装 Rust
if ! command -v rustup &> /dev/null; then
    echo "安装 Rust..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
fi

# 添加 Rust 目标平台
echo "添加 Rust 目标平台..."
rustup target add aarch64-apple-darwin x86_64-apple-darwin

# 安装视频编解码库
echo "安装视频编解码库..."
brew install ffmpeg opus libvpx

# 安装其他依赖
echo "安装其他依赖..."
brew install nasm protobuf sqlite3

# 验证安装
echo ""
echo "=== 验证安装 ==="
echo "Rust:"
rustc --version
cargo --version
echo ""
echo "编译工具:"
cmake --version | head -n 1
ninja --version
pkg-config --version
echo ""
echo "依赖库:"
pkg-config --list-all | grep -E "(opus|vpx|avcodec)"
echo ""
echo "=== 安装完成 ==="
```

使用方式：

```bash
chmod +x install-deps.sh
./install-deps.sh
```

---

## 2. 源码获取

### 2.1 克隆仓库

```bash
# 创建工作目录
mkdir -p ~/rustdesk-build
cd ~/rustdesk-build

# 克隆主仓库
git clone https://github.com/rustdesk/rustdesk.git
cd rustdesk

# 初始化子模块
git submodule update --init --recursive
```

### 2.2 选择版本

```bash
# 查看可用标签
git tag

# 切换到最新稳定版本（以 v1.2.0 为例）
git checkout v1.2.0
```

### 2.3 目录结构

```
rustdesk/
├── src/                      # Rust 服务端代码
│   ├── server/              # 服务器核心
│   ├── platform/           # 平台特定代码
│   └── rendezvous_mediator.rs
├── libs/                    # 共享库
│   ├── hbb_common/         # 通用工具
│   ├── scrap/              # 屏幕捕获
│   ├── enigo/              # 输入控制
│   └── clipboard/          # 剪贴板
├── flutter/                # Flutter UI
└── docs/                   # 文档
```

---

## 3. 编译步骤

### 3.1 环境变量配置

```bash
# 设置编译优化标志
export RUSTFLAGS="-C opt-level=3"

# 设置并行编译数量
export CARGO_BUILD_JOBS=$(sysctl -n hw.ncpu)

# 启用 LTO（链接时优化，提升性能）
export RUSTFLAGS="-C lto=fat -C codegen-units=1"

# 可选：设置日志级别
export RUST_LOG=info

# 设置库搜索路径（如果需要）
export LIBRARY_PATH=/usr/local/lib:$LIBRARY_PATH
export DYLD_LIBRARY_PATH=/usr/local/lib:$DYLD_LIBRARY_PATH
```

### 3.2 纯 Rust 编译（仅服务端）

如果你只需要编译服务端（hbbs 和 hbrs），无需 Flutter：

```bash
# 进入项目目录
cd rustdesk

# 编译 Release 版本
cargo build --release

# 或编译 Debug 版本（更快但性能较差）
cargo build

# 编译后的二进制文件位于：
# target/release/hbbs   - RustDesk ID/HBBS 服务器
# target/release/hbrs   - RustDesk 中继服务器
```

### 3.3 完整编译（包括 Flutter UI）

```bash
# 1. 编译 Rust 服务端
cargo build --release

# 2. 安装 Flutter 依赖
cd flutter

# 确保启用了 macOS 桌面支持
flutter config --enable-macos-desktop

# 获取依赖
flutter pub get

# 3. 编译 macOS 版本
flutter build macos

# 编译产物位于：
# flutter/build/macos/Build/Products/Release/
```

### 3.4 指定目标架构

**Apple Silicon (M1/M2/M3)**:

```bash
cargo build --release --target aarch64-apple-darwin
```

**Intel Mac**:

```bash
cargo build --release --target x86_64-apple-darwin
```

**Universal Binary (两种架构)**:

```bash
# 分别编译两种架构
cargo build --release --target aarch64-apple-darwin
cargo build --release --target x86_64-apple-darwin

# 创建通用二进制
lipo target/aarch64-apple-darwin/release/hbbs \
    target/x86_64-apple-darwin/release/hbbs \
    -create -output target/release-universal/hbbs

lipo target/aarch64-apple-darwin/release/hbrs \
    target/x86_64-apple-darwin/release/hbrs \
    -create -output target/release-universal/hbrs
```

### 3.5 编译选项

**最小化编译（减少二进制大小）**:

```bash
# 设置剥离符号
export RUSTFLAGS="-C strip=symbols -C lto=fat -C codegen-units=1"

cargo build --release
```

**调试编译**:

```bash
cargo build

# 调试符号位于：
# target/debug/hbbs
# target/debug/hbrs
```

### 3.6 编译脚本

创建编译脚本 `build-server.sh`：

```bash
#!/bin/bash
set -e

echo "=== RustDesk 服务端编译脚本 ==="

# 设置变量
BUILD_DIR="$HOME/rustdesk-build"
PROJECT_DIR="$BUILD_DIR/rustdesk"
BUILD_TYPE="${1:-release}"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# 检查 Rust
if ! command -v rustc &> /dev/null; then
    log_error "Rust 未安装，请先安装 Rust"
    exit 1
fi

# 检查 Xcode
if ! command -v xcodebuild &> /dev/null; then
    log_error "Xcode Command Line Tools 未安装"
    exit 1
fi

# 进入项目目录
cd "$PROJECT_DIR"

# 清理旧构建
if [ "$BUILD_TYPE" == "clean" ]; then
    log_info "清理构建目录..."
    cargo clean
fi

# 设置优化标志
export RUSTFLAGS="-C lto=fat -C codegen-units=1 -C opt-level=3"

# 编译
log_info "开始编译 RustDesk 服务端..."
if [ "$BUILD_TYPE" == "release" ]; then
    cargo build --release
elif [ "$BUILD_TYPE" == "universal" ]; then
    log_info "编译通用二进制..."
    
    # 清理并分别编译
    cargo clean
    cargo build --release --target aarch64-apple-darwin
    cargo build --release --target x86_64-apple-darwin
    
    # 创建输出目录
    mkdir -p "$BUILD_DIR/output-universal"
    
    # 创建通用二进制
    lipo target/aarch64-apple-darwin/release/hbbs \
        target/x86_64-apple-darwin/release/hbbs \
        -create -output "$BUILD_DIR/output-universal/hbbs"
    
    lipo target/aarch64-apple-darwin/release/hbrs \
        target/x86_64-apple-darwin/release/hbrs \
        -create -output "$BUILD_DIR/output-universal/hbrs"
    
    # 设置可执行权限
    chmod +x "$BUILD_DIR/output-universal/hbbs"
    chmod +x "$BUILD_DIR/output-universal/hbrs"
    
    log_info "通用二进制编译完成！"
    log_info "二进制文件位于: $BUILD_DIR/output-universal/"
    ls -lh "$BUILD_DIR/output-universal/"
    exit 0
else
    cargo build
fi

# 复制二进制文件
log_info "复制二进制文件到 output 目录..."
mkdir -p "$BUILD_DIR/output"

if [ "$BUILD_TYPE" == "release" ]; then
    cp target/release/hbbs "$BUILD_DIR/output/"
    cp target/release/hbrs "$BUILD_DIR/output/"
else
    cp target/debug/hbbs "$BUILD_DIR/output/"
    cp target/debug/hbrs "$BUILD_DIR/output/"
fi

# 设置可执行权限
chmod +x "$BUILD_DIR/output/hbbs"
chmod +x "$BUILD_DIR/output/hbrs"

log_info "编译完成！"
log_info "二进制文件位于: $BUILD_DIR/output/"
ls -lh "$BUILD_DIR/output/"
```

使用方式：

```bash
chmod +x build-server.sh

# Release 编译
./build-server.sh release

# Debug 编译
./build-server.sh debug

# Universal 二进制编译
./build-server.sh universal

# 清理并重新编译
./build-server.sh release clean
```

---

## 4. 服务配置

### 4.1 创建服务用户

```bash
# 创建专用用户（可选）
sudo dscl . -create /Users/rustdesk
sudo dscl . -create /Users/rustdesk UserShell /bin/false
sudo dscl . -create /Users/rustdesk RealName "RustDesk Service"
sudo dscl . -create /Users/rustdesk PrimaryGroupID 20
sudo dscl . -create /Users/rustdesk NFSHomeDirectory /var/empty

# 创建数据目录
sudo mkdir -p /var/lib/rustdesk
sudo chown rustdesk:rustdesk /var/lib/rustdesk
```

### 4.2 部署二进制文件

```bash
# 创建部署目录
sudo mkdir -p /usr/local/rustdesk
sudo mkdir -p /var/lib/rustdesk/{hbbs,hbrs}

# 复制二进制文件
sudo cp ~/rustdesk-build/output/hbbs /usr/local/rustdesk/
sudo cp ~/rustdesk-build/output/hbrs /usr/local/rustdesk/

# 设置权限
sudo chown root:admin /usr/local/rustdesk/hbbs
sudo chown root:admin /usr/local/rustdesk/hbrs
sudo chmod +x /usr/local/rustdesk/hbbs
sudo chmod +x /usr/local/rustdesk/hbrs
```

### 4.3 LaunchDaemon 配置

macOS 使用 LaunchDaemon 来管理服务，这是系统级服务。

#### 4.3.1 创建 HBBS LaunchDaemon

创建 `/Library/LaunchDaemons/com.rustdesk.hbbs.plist`：

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.rustdesk.hbbs</string>
    
    <key>ProgramArguments</key>
    <array>
        <string>/usr/local/rustdesk/hbbs</string>
    </array>
    
    <key>WorkingDirectory</key>
    <string>/var/lib/rustdesk/hbbs</string>
    
    <key>RunAtLoad</key>
    <true/>
    
    <key>KeepAlive</key>
    <true/>
    
    <key>StandardOutPath</key>
    <string>/var/log/rustdesk/hbbs.log</string>
    
    <key>StandardErrorPath</key>
    <string>/var/log/rustdesk/hbbs-error.log</string>
    
    <key>ProcessType</key>
    <string>Background</string>
    
    <key>LowPriorityIO</key>
    <true/>
    
    <key>UserName</key>
    <string>root</string>
</dict>
</plist>
```

#### 4.3.2 创建 HBRS LaunchDaemon

创建 `/Library/LaunchDaemons/com.rustdesk.hbrs.plist`：

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.rustdesk.hbrs</string>
    
    <key>ProgramArguments</key>
    <array>
        <string>/usr/local/rustdesk/hbrs</string>
    </array>
    
    <key>WorkingDirectory</key>
    <string>/var/lib/rustdesk/hbrs</string>
    
    <key>RunAtLoad</key>
    <true/>
    
    <key>KeepAlive</key>
    <true/>
    
    <key>StandardOutPath</key>
    <string>/var/log/rustdesk/hbrs.log</string>
    
    <key>StandardErrorPath</key>
    <string>/var/log/rustdesk/hbrs-error.log</string>
    
    <key>ProcessType</key>
    <string>Background</string>
    
    <key>LowPriorityIO</key>
    <true/>
    
    <key>UserName</key>
    <string>root</string>
</dict>
</plist>
```

#### 4.3.3 创建日志目录

```bash
sudo mkdir -p /var/log/rustdesk
sudo chown root:admin /var/log/rustdesk
```

#### 4.3.4 设置文件权限

```bash
# 设置 plist 文件权限
sudo chmod 644 /Library/LaunchDaemons/com.rustdesk.hbbs.plist
sudo chmod 644 /Library/LaunchDaemons/com.rustdesk.hbrs.plist

# 设置所有者
sudo chown root:wheel /Library/LaunchDaemons/com.rustdesk.hbbs.plist
sudo chown root:wheel /Library/LaunchDaemons/com.rustdesk.hbrs.plist
```

### 4.4 服务管理命令

```bash
# 加载服务（启动）
sudo launchctl load /Library/LaunchDaemons/com.rustdesk.hbbs.plist
sudo launchctl load /Library/LaunchDaemons/com.rustdesk.hbrs.plist

# 卸载服务（停止）
sudo launchctl unload /Library/LaunchDaemons/com.rustdesk.hbbs.plist
sudo launchctl unload /Library/LaunchDaemons/com.rustdesk.hbrs.plist

# 重启服务
sudo launchctl unload /Library/LaunchDaemons/com.rustdesk.hbbs.plist
sudo launchctl load /Library/LaunchDaemons/com.rustdesk.hbbs.plist

# 检查服务状态
sudo launchctl list | grep rustdesk

# 查看服务详细信息
sudo launchctl print system/com.rustdesk.hbbs
sudo launchctl print system/com.rustdesk.hbrs
```

### 4.5 HBBS/HBRS 配置

#### 4.5.1 命令行参数

```bash
# 查看帮助
/usr/local/rustdesk/hbbs --help
/usr/local/rustdesk/hbrs --help
```

常用参数：
- `-k <file>` - 私钥文件路径（用于加密通信）
- `-r <addr>` - 中继服务器地址
- `-l <port>` - 监听端口
- `--help` - 显示帮助信息

#### 4.5.2 日志配置

日志文件位置：
- HBBS: `/var/log/rustdesk/hbbs.log`
- HBRS: `/var/log/rustdesk/hbrs.log`

#### 4.5.3 日志轮转配置

创建 `/etc/newsyslog.d/rustdesk.conf`：

```
/var/log/rustdesk/hbbs.log root:admin 644 7 100 * J
/var/log/rustdesk/hbbs-error.log root:admin 644 7 100 * J
/var/log/rustdesk/hbrs.log root:admin 644 7 100 * J
/var/log/rustdesk/hbrs-error.log root:admin 644 7 100 * J
```

---

## 5. 防火墙配置

### 5.1 必需端口

| 端口 | 协议 | 用途 | 服务 |
|------|------|------|------|
| 21115 | TCP | ID/HBBS 服务 | hbbs |
| 21116 | TCP/UDP | 中继连接 | hbrs |
| 21117 | TCP | RUDP 中继 | hbrs |
| 21118 | TCP | 测试端口 | - |
| 21119 | TCP | WebSocket | hbbs |

### 5.2 使用 pfctl 防火墙

macOS 默认使用 pf (Packet Filter) 防火墙。

#### 5.2.1 编辑 pf.conf

```bash
sudo nano /etc/pf.conf
```

添加规则：

```
# RustDesk 端口
pass in proto tcp from any to any port 21115
pass in proto tcp from any to any port 21116
pass in proto udp from any to any port 21116
pass in proto tcp from any to any port 21117
pass in proto tcp from any to any port 21118
pass in proto tcp from any to any port 21119
```

#### 5.2.2 重新加载 pf

```bash
sudo pfctl -f /etc/pf.conf
sudo pfctl -e
```

### 5.3 使用 macOS 图形界面

1. 打开 "系统偏好设置" (System Preferences)
2. 点击 "安全性与隐私" (Security & Privacy)
3. 选择 "防火墙" (Firewall) 选项卡
4. 点击 "打开防火墙" (Turn On Firewall)
5. 点击 "防火墙选项" (Firewall Options)
6. 点击 "+" 添加应用程序或端口

### 5.4 使用终端命令

```bash
# 使用/usr/libexec/ApplicationFirewall/socketfilterfw（较旧的方法）
# 推荐使用 GUI 或 pfctl

# 允许应用通过防火墙
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --add "/usr/local/rustdesk/hbbs"
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --add "/usr/local/rustdesk/hbrs"

# 设置为允许
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --unblockapp "/usr/local/rustdesk/hbbs"
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --unblockapp "/usr/local/rustdesk/hbrs"
```

### 5.5 验证防火墙配置

```bash
# 检查端口监听
sudo lsof -i :21115
sudo lsof -i :21116
sudo lsof -i :21117

# 测试端口连接
nc -zv localhost 21115
nc -zv localhost 21116
nc -zv localhost 21117
```

---

## 6. 性能优化

### 6.1 编译优化

**启用 LTO（链接时优化）**:

```bash
export RUSTFLAGS="-C lto=fat -C codegen-units=1"
cargo build --release
```

**Apple Silicon 优化**:

```bash
# 使用 Apple Silicon 原生优化
export RUSTFLAGS="-C lto=fat -C codegen-units=1 -C target-cpu=apple-m1"
cargo build --release --target aarch64-apple-darwin
```

### 6.2 服务优化

#### 6.2.1 调整进程优先级

使用 `nice` 和 `renice`：

```bash
# 以低优先级启动
sudo launchctl config user priority 10

# 或使用renice调整运行中的进程
sudo renice -n 10 -p $(pgrep hbbs)
sudo renice -n 10 -p $(pgrep hbrs)
```

#### 6.2.2 内存限制

在 LaunchDaemon plist 中设置：

```xml
<key>HardResourceLimits</key>
<dict>
    <key>NumberOfFiles</key>
    <integer>1024</integer>
</dict>
```

### 6.3 macOS 系统优化

#### 6.3.1 关闭不必要的服务

减少系统资源占用，专注于 RustDesk 服务。

#### 6.3.2 调整能源设置

如果部署在笔记本上，阻止系统休眠：

```bash
# 防止系统休眠
caffeinate -d -i -m &
```

#### 6.3.3 性能监控

使用 `top` 或 `Activity Monitor` 监控：

```bash
# 监控进程
top -pid $(pgrep hbbs)
htop
```

### 6.4 日志优化

#### 6.4.1 限制日志大小

使用 newsyslog 自动轮转日志：

```bash
# 编辑 /etc/newsyslog.d/rustdesk.conf
sudo nano /etc/newsyslog.d/rustdesk.conf
```

添加：

```
/var/log/rustdesk/*.log root:admin 644 7 1024 * J
```

#### 6.4.2 手动日志清理

```bash
# 删除超过 7 天的日志
find /var/log/rustdesk -name "*.log" -mtime +7 -delete
```

创建定时任务（使用 launchd）：

创建 `/Library/LaunchDaemons/com.rustdesk.logclean.plist`：

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.rustdesk.logclean</string>
    
    <key>ProgramArguments</key>
    <array>
        <string>/usr/bin/find</string>
        <string>/var/log/rustdesk</string>
        <string>-name</string>
        <string>*.log</string>
        <string>-mtime</string>
        <string>+7</string>
        <string>-delete</string>
    </array>
    
    <key>StartCalendarInterval</key>
    <dict>
        <key>Hour</key>
        <integer>3</integer>
        <key>Minute</key>
        <integer>0</integer>
    </dict>
</dict>
</plist>
```

---

## 7. 故障排除

### 7.1 编译错误

**错误 1**: `error: failed to run custom build command for ...`

```bash
# 确保所有依赖已安装
brew install cmake ninja pkg-config autoconf automake libtool ffmpeg opus libvpx

# 清理并重新编译
cargo clean
cargo build --release
```

**错误 2**: `error: unable to find native library`

```bash
# 设置 PKG_CONFIG_PATH
export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig:$PKG_CONFIG_PATH

# 清理并重新编译
cargo clean
cargo build --release
```

**错误 3**: `could not find native library 'libxcb'`

```bash
# macOS 不需要 XCB，这是 Linux 特有的
# 检查是否在错误的平台上编译
```

**错误 4**: 内存不足

```bash
# 减少并行编译数
export CARGO_BUILD_JOBS=2
cargo build --release
```

### 7.2 服务启动失败

**检查日志**:

```bash
# 查看 HBBS 日志
sudo cat /var/log/rustdesk/hbbs.log
sudo cat /var/log/rustdesk/hbbs-error.log

# 查看 HBRS 日志
sudo cat /var/log/rustdesk/hbrs.log
sudo cat /var/log/rustdesk/hbrs-error.log
```

**使用 launchctl 调试**:

```bash
# 查看详细错误
sudo launchctl error com.rustdesk.hbbs
sudo launchctl error com.rustdesk.hbrs

# 手动启动服务（前台模式）
cd /var/lib/rustdesk/hbbs
/usr/local/rustdesk/hbbs
```

**常见问题**:

1. **端口被占用**:
   ```bash
   # 检查端口占用
   sudo lsof -i :21115
   sudo lsof -i :21116
   
   # 停止占用进程或更改端口
   ```

2. **权限不足**:
   ```bash
   # 检查文件权限
   ls -lh /usr/local/rustdesk/
   
   # 修复权限
   sudo chown root:admin /usr/local/rustdesk/*
   sudo chmod +x /usr/local/rustdesk/*
   ```

3. **配置文件错误**:
   ```bash
   # 验证 plist 文件语法
   plutil /Library/LaunchDaemons/com.rustdesk.hbbs.plist
   plutil /Library/LaunchDaemons/com.rustdesk.hbrs.plist
   ```

### 7.3 连接问题

**防火墙阻止**:

```bash
# 临时关闭防火墙测试
sudo pfctl -d

# 测试后重新启用
sudo pfctl -e
```

**端口未监听**:

```bash
# 检查服务是否运行
sudo launchctl list | grep rustdesk

# 检查端口
sudo lsof -i :21115
sudo lsof -i :21116

# 手动测试连接
nc -zv localhost 21115
nc -zv localhost 21116
```

### 7.4 性能问题

**CPU 使用率过高**:

```bash
# 查看进程
ps aux | grep -E 'hbbs|hbrs'

# 使用 Activity Monitor 查看
open -a "Activity Monitor"
```

**内存泄漏**:

```bash
# 检查内存使用
ps aux | grep -E 'hbbs|hbrs' | awk '{print $6/1024 " MB"}'

# 重启服务
sudo launchctl unload /Library/LaunchDaemons/com.rustdesk.hbbs.plist
sudo launchctl load /Library/LaunchDaemons/com.rustdesk.hbbs.plist
```

---

## 8. 验证部署

### 8.1 本地验证

```bash
# 检查进程运行
ps aux | grep -E 'hbbs|hbrs' | grep -v grep

# 检查端口监听
sudo lsof -i :21115
sudo lsof -i :21116
sudo lsof -i :21117
sudo lsof -i :21118
sudo lsof -i :21119

# 检查服务状态
sudo launchctl list | grep rustdesk
```

### 8.2 功能测试

```bash
# 测试 HBBS 连接
nc -zv localhost 21115

# 测试 HBRS 连接
nc -zv localhost 21116
nc -zv localhost 21117

# 查看日志
tail -f /var/log/rustdesk/hbbs.log
tail -f /var/log/rustdesk/hbrs.log
```

### 8.3 远程测试

1. **配置客户端**:
   - 打开 RustDesk 客户端
   - 进入设置 -> 网络
   - 设置 ID 服务器为你的服务器 IP/域名
   - 设置中继服务器为你的服务器 IP/域名

2. **测试连接**:
   - 使用另一台设备尝试连接
   - 检查是否能正常建立连接
   - 测试文件传输功能

3. **验证中继**:
   - 在防火墙后测试
   - 确保 NAT 穿透失败时能走中继
   - 检查中继连接日志

### 8.4 监控设置

创建监控脚本 `check-rustdesk.sh`：

```bash
#!/bin/bash

HBBS_RUNNING=$(sudo launchctl list | grep -c "com.rustdesk.hbbs.*true")
HBRS_RUNNING=$(sudo launchctl list | grep -c "com.rustdesk.hbrs.*true")

if [ "$HBBS_RUNNING" -eq 0 ]; then
    echo "ERROR: rustdesk-hbbs is not running"
    exit 1
fi

if [ "$HBRS_RUNNING" -eq 0 ]; then
    echo "ERROR: rustdesk-hbrs is not running"
    exit 1
fi

echo "OK: All RustDesk services are running"
exit 0
```

添加到 crontab 或 launchd：

创建 `/Library/LaunchDaemons/com.rustdesk.monitor.plist`：

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.rustdesk.monitor</string>
    
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>/usr/local/rustdesk/scripts/check-rustdesk.sh</string>
    </array>
    
    <key>StartInterval</key>
    <integer>300</integer>
    
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
```

---

## 相关文档

- [BUILD_PREREQUISITES.md](BUILD_PREREQUISITES.md) - 编译依赖清单
- [BUILD_LINUX.md](BUILD_LINUX.md) - Linux 编译指南
- [BUILD_WINDOWS.md](BUILD_WINDOWS.md) - Windows 编译指南
- [BUILD_CROSS_COMPILE.md](BUILD_CROSS_COMPILE.md) - 交叉编译指南
- [DEPLOYMENT.md](DEPLOYMENT.md) - 部署总览
