# RustDesk 编译依赖清单

## 目录

1. [Rust 环境](#1-rust-环境)
2. [Linux 平台依赖](#2-linux-平台依赖)
3. [Windows 平台依赖](#3-windows-平台依赖)
4. [macOS 平台依赖](#4-macos-平台依赖)
5. [Flutter 依赖](#5-flutter-依赖)
6. [视频编解码依赖](#6-视频编解码依赖)
7. [屏幕捕获依赖](#7-屏幕捕获依赖)
8. [音频依赖](#8-音频依赖)
9. [编译工具链](#9-编译工具链)
10. [可选依赖](#10-可选依赖)

---

## 1. Rust 环境

### 1.1 Rust 安装（所有平台）

**推荐版本**: Rust 1.81.0 或更高

```bash
# 使用 rustup 安装
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Windows 下载安装器
# https://rustup.rs/
```

**国内镜像（可选）**:

```bash
# 设置 Rust 镜像源
export RUSTUP_DIST_SERVER=https://mirrors.ustc.edu.cn/rust-static
export RUSTUP_UPDATE_ROOT=https://mirrors.ustc.edu.cn/rust-static/rustup

# 或使用 rsproxy
export RUSTUP_DIST_SERVER=https://rsproxy.cn
export RUSTUP_UPDATE_ROOT=https://rsproxy.cn/rustup
```

### 1.2 Cargo 配置

**文件**: `~/.cargo/config.toml`

```toml
[source.crates-io]
replace-with = "rsproxy-sparse"

[source.rsproxy]
registry = "https://rsproxy.cn/crates.io-index"

[source.rsproxy-sparse]
registry = "sparse+https://rsproxy.cn/index/"

[registries.rsproxy]
index = "https://rsproxy.cn/crates.io-index"

[net]
git-fetch-with-cli = true
```

### 1.3 验证安装

```bash
rustc --version
cargo --version
rustup --version
```

---

## 2. Linux 平台依赖

### 2.1 Debian/Ubuntu

```bash
# 基础编译工具
sudo apt update
sudo apt install -y build-essential cmake ninja-build pkg-config

# Rust 目标平台
rustup target add x86_64-unknown-linux-gnu
rustup target add aarch64-unknown-linux-gnu

# 系统库
sudo apt install -y \
    libssl-dev \
    libxdo-dev \
    libxcb-shape0-dev \
    libxcb-xfixes0-dev \
    libxkbcommon-dev \
    libxkbcommon-x11-dev \
    libgl1-mesa-dev \
    libasound2-dev \
    libpulse-dev

# 协议缓冲区
sudo apt install -y protobuf-compiler libprotobuf-dev

# 视频编解码（可选）
sudo apt install -y \
    libavcodec-dev \
    libavformat-dev \
    libswscale-dev \
    libopus-dev \
    libvpx-dev

# 屏幕捕获
sudo apt install -y \
    libx11-dev \
    libxext-dev \
    libxdamage-dev \
    libxfixes-dev \
    libxcomposite-dev \
    libxrandr-dev

# Wayland 支持（可选）
sudo apt install -y \
    libwayland-dev \
    libwlroots-dev \
    libpipewire-0.3-dev

# DBus（可选）
sudo apt install -y libdbus-1-dev

# Systemd（用于服务管理）
sudo apt install -y libsystemd-dev

# 性能分析工具（可选）
sudo apt install -y valgrind
```

### 2.2 CentOS/RHEL/Rocky Linux 8+

```bash
# 启用 EPEL 和 PowerTools
sudo dnf install -y epel-release
sudo dnf config-manager --set-enabled powertools

# 基础编译工具
sudo dnf groupinstall -y "Development Tools"
sudo dnf install -y cmake ninja-build pkg-config

# Rust 目标平台
rustup target add x86_64-unknown-linux-gnu
rustup target add aarch64-unknown-linux-gnu

# 系统库
sudo dnf install -y \
    openssl-devel \
    xdotool \
    libxkbcommon-devel \
    libxkbcommon-x11-devel \
    mesa-libGL-devel \
    alsa-lib-devel \
    pulseaudio-libs-devel

# 协议缓冲区
sudo dnf install -y protobuf-compiler protobuf-devel

# 视频编解码
sudo dnf install -y \
    ffmpeg-devel \
    opus-devel \
    libvpx-devel

# 屏幕捕获
sudo dnf install -y \
    libX11-devel \
    libXext-devel \
    libXdamage-devel \
    libXfixes-devel \
    libXcomposite-devel \
    libXrandr-devel

# Systemd
sudo dnf install -y systemd-devel
```

### 2.3 Fedora

```bash
# 基础编译工具
sudo dnf groupinstall -y "Development Tools"
sudo dnf install -y cmake ninja-build pkg-config

# Rust 目标平台
rustup target add x86_64-unknown-linux-gnu
rustup target add aarch64-unknown-linux-gnu

# 系统库
sudo dnf install -y \
    openssl-devel \
    xdotool \
    libxkbcommon-devel \
    libxkbcommon-x11-devel \
    mesa-libGL-devel \
    alsa-lib-devel \
    pulseaudio-libs-devel \
    dbus-devel

# 协议缓冲区
sudo dnf install -y protobuf-compiler protobuf-devel

# 视频编解码
sudo dnf install -y \
    ffmpeg-devel \
    opus-devel \
    libvpx-devel
```

### 2.4 Arch Linux/Manjaro

```bash
# 基础编译工具
sudo pacman -S --needed base-devel cmake ninja pkg-config

# Rust 目标平台
rustup target add x86_64-unknown-linux-gnu
rustup target add aarch64-unknown-linux-gnu

# 系统库
sudo pacman -S --needed \
    openssl \
    xdotool \
    libxkbcommon \
    libxkbcommon-x11 \
    mesa \
    alsa-lib \
    pulseaudio

# 协议缓冲区
sudo pacman -S --needed protobuf

# 视频编解码
sudo pacman -S --needed ffmpeg opus libvpx

# 屏幕捕获
sudo pacman -S --needed \
    libx11 \
    libxext \
    libxdamage \
    libxfixes \
    libxcomposite \
    libxrandr

# Wayland 支持
sudo pacman -S --needed wayland wlroots pipewire
```

### 2.5 openSUSE

```bash
# 基础编译工具
sudo zypper install -y -t pattern devel_basis
sudo zypper install -y cmake ninja pkg-config

# Rust 目标平台
rustup target add x86_64-unknown-linux-gnu
rustup target add aarch64-unknown-linux-gnu

# 系统库
sudo zypper install -y \
    libopenssl-devel \
    xdotool \
    libxkbcommon-devel \
    libxkbcommon-x11-devel \
    Mesa-libGL-devel \
    alsa-devel \
    libpulse-devel

# 协议缓冲区
sudo zypper install -y protobuf-compiler protobuf-devel

# 视频编解码
sudo zypper install -y \
    ffmpeg-devel \
    opus-devel \
    libvpx-devel

# Systemd
sudo zypper install -y libsystemd-devel
```

---

## 3. Windows 平台依赖

### 3.1 Visual Studio 2022 Build Tools

**下载**: https://visualstudio.microsoft.com/downloads/

选择以下工作负载：
- **使用 C++ 的桌面开发**（必需）
- **Windows 11 SDK**（必需）
- **Windows 10 SDK**（可选）

### 3.2 MSVC 工具链配置

```powershell
# 方式一：使用 Visual Studio Developer Command Prompt
# 查找并打开 "Developer Command Prompt for VS 2022"

# 方式二：手动设置环境变量
$msvcPath = "C:\Program Files\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build"
Import-Module "$msvcPath\Microsoft.VisualStudio.DevEnv.dll"
vsdevcmd.bat -arch=x64

# 验证配置
cl.exe
link.exe
```

### 3.3 Rust 目标平台

```powershell
rustup target add x86_64-pc-windows-msvc
rustup target add i686-pc-windows-msvc
rustup target add aarch64-pc-windows-msvc
```

### 3.4 必要工具

**推荐使用 vcpkg 管理依赖**:

```powershell
# 克隆 vcpkg
git clone https://github.com/Microsoft/vcpkg.git C:\vcpkg
cd C:\vcpkg
.\bootstrap-vcpkg.bat

# 设置环境变量（永久）
[Environment]::SetEnvironmentVariable("VCPKG_ROOT", "C:\vcpkg", "User")
[Environment]::SetEnvironmentVariable("VCPKG_DEFAULT_TRIPLET", "x64-windows", "User")
```

### 3.5 vcpkg 依赖安装

```powershell
# 安装必需依赖
vcpkg install `
    ffmpeg:x64-windows `
    libvpx:x64-windows `
    opus:x64-windows `
    libsodium:x64-windows `
    libxcb:x64-windows `
    libxkbcommon:x64-windows `
    mesa:x64-windows `
    alsa:x64-windows `
    pulseaudio:x64-windows `
    --triplet x64-windows

# 如果需要静态链接
vcpkg install ffmpeg:x64-windows-static
```

### 3.6 Git for Windows

**下载**: https://git-scm.com/download/win

配置：

```bash
git config --global core.autocrlf false
git config --global core.longpaths true
```

### 3.7 CMake

**下载**: https://cmake.org/download/

推荐使用 CMake GUI 或添加到 PATH：

```powershell
[Environment]::SetEnvironmentVariable(
    "Path",
    "$env:Path;C:\Program Files\CMake\bin",
    "User"
)
```

### 3.8 NASM（视频编码需要）

**下载**: https://www.nasm.us/

```powershell
# 添加到 PATH
[Environment]::SetEnvironmentVariable(
    "Path",
    "$env:Path;C:\Program Files\NASM",
    "User"
)

# 验证
nasm --version
```

### 3.9 完整安装脚本（PowerShell）

```powershell
# 以管理员身份运行 PowerShell

# 1. 安装 Chocolatey
Set-ExecutionPolicy Bypass -Scope Process -Force
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

# 2. 安装基础工具
choco install -y git cmake ninja visualstudio2022buildtools

# 3. 安装 Rust
choco install -y rustup

# 4. 克隆并配置 vcpkg
git clone https://github.com/Microsoft/vcpkg.git C:\vcpkg
C:\vcpkg\bootstrap-vcpkg.bat
[Environment]::SetEnvironmentVariable("VCPKG_ROOT", "C:\vcpkg", "User")

# 5. 安装 vcpkg 依赖
& 'C:\vcpkg\vcpkg.exe' install ffmpeg:x64-windows libvpx:x64-windows opus:x64-windows libsodium:x64-windows

# 6. 添加 Rust 目标平台
rustup target add x86_64-pc-windows-msvc
```

---

## 4. macOS 平台依赖

### 4.1 Homebrew 安装

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### 4.2 Xcode Command Line Tools

```bash
xcode-select --install
```

### 4.3 Homebrew 依赖

```bash
# 基础工具
brew install cmake ninja pkg-config autoconf automake libtool

# Rust 目标平台
rustup target add x86_64-apple-darwin
rustup target add aarch64-apple-darwin

# 视频编解码
brew install ffmpeg opus libvpx

# 屏幕捕获（macOS 自带 Quartz）
# 如果需要额外库
brew install srtp

# 音频
brew install pulseaudio portaudio  # 用于录音功能

# 协议缓冲区
brew install protobuf

# SQLite（可选）
brew install sqlite3

# 性能分析
brew install valgrind
```

### 4.4 NASM

```bash
brew install nasm
```

### 4.5 Rust 证书（用于 HTTPS）

```bash
# macOS 通常自带证书，但在某些环境可能需要
brew install ca-certificates

# 设置证书路径
export SSL_CERT_FILE=/opt/homebrew/etc/ca-certificates/cert.pem
export SSL_CERT_DIR=/opt/homebrew/etc/ca-certificates/certs
```

### 4.6 验证安装

```bash
# 检查 Xcode
xcode-select -p
xcodebuild -version

# 检查工具链
clang --version
swift --version

# 检查 Rust
rustc --version
cargo --version
```

### 4.7 完整安装脚本

```bash
#!/bin/bash
set -e

echo "安装 RustDesk 编译依赖..."

# 检查并安装 Homebrew
if ! command -v brew &> /dev/null; then
    echo "安装 Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

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
rustup target add x86_64-apple-darwin aarch64-apple-darwin

# 安装视频编解码
echo "安装视频编解码库..."
brew install ffmpeg opus libvpx

# 安装其他依赖
echo "安装其他依赖..."
brew install nasm protobuf sqlite3

echo "依赖安装完成！"
```

---

## 5. Flutter 依赖

### 5.1 Flutter SDK 安装

```bash
# 下载 Flutter SDK
git clone https://github.com/flutter/flutter.git -b stable --depth 1

# 添加到 PATH
export PATH="$PATH:/path/to/flutter/bin"

# 验证
flutter --version
```

### 5.2 Flutter 依赖安装

```bash
cd rustdesk/flutter

# 获取依赖
flutter pub get

# 清理缓存（如需要）
flutter clean
flutter pub get
```

### 5.3 Flutter 平台特定依赖

**Linux**:
```bash
sudo apt install -y \
    clang \
    cmake \
    libgtk-3-dev \
    liblzma-dev \
    libstdc++-12-dev
```

**macOS**:
```bash
# Xcode 自动处理大部分依赖
brew install gtk+3
```

**Windows**:
```powershell
# Flutter Windows 依赖由 Visual Studio 提供
# 确保安装了 "使用 C++ 的桌面开发" 工作负载
```

---

## 6. 视频编解码依赖

### 6.1 FFmpeg

**用途**: 视频解码和编码

**安装**:

Linux:
```bash
# Debian/Ubuntu
sudo apt install -y ffmpeg libavcodec-dev libavformat-dev libswscale-dev

# CentOS/RHEL
sudo dnf install -y ffmpeg-devel

# Arch Linux
sudo pacman -S --needed ffmpeg
```

macOS:
```bash
brew install ffmpeg
```

Windows:
```powershell
vcpkg install ffmpeg:x64-windows
```

### 6.2 libvpx

**用途**: VP8/VP9 视频编解码

**安装**:

Linux:
```bash
sudo apt install -y libvpx-dev
```

macOS:
```bash
brew install libvpx
```

Windows:
```powershell
vcpkg install libvpx:x64-windows
```

### 6.3 opus

**用途**: Opus 音频编解码

**安装**:

Linux:
```bash
sudo apt install -y libopus-dev opus-tools
```

macOS:
```bash
brew install opus
```

Windows:
```powershell
vcpkg install opus:x64-windows
```

### 6.4 libsodium

**用途**: 加密库

**安装**:

Linux:
```bash
sudo apt install -y libsodium-dev
```

macOS:
```bash
brew install sodium
```

Windows:
```powershell
vcpkg install libsodium:x64-windows
```

---

## 7. 屏幕捕获依赖

### 7.1 X11 (Linux)

**用途**: X11 屏幕捕获

```bash
sudo apt install -y \
    libx11-dev \
    libxext-dev \
    libxdamage-dev \
    libxfixes-dev \
    libxcomposite-dev \
    libxrandr-dev \
    libxscrnsaver-dev
```

### 7.2 Wayland (Linux)

**用途**: Wayland 屏幕捕获

```bash
sudo apt install -y \
    libwayland-dev \
    libwlroots-dev \
    libpipewire-0.3-dev
```

### 7.3 macOS Quartz

**用途**: macOS 屏幕捕获

macOS 自带，无需额外安装。确保安装了 Xcode Command Line Tools。

### 7.4 Windows GDI/DXGI

**用途**: Windows 屏幕捕获

由 Windows SDK 提供，随 Visual Studio 安装。

---

## 8. 音频依赖

### 8.1 ALSA (Linux)

**用途**: Linux 音频

```bash
sudo apt install -y libasound2-dev alsa-utils
```

### 8.2 PulseAudio (Linux)

**用途**: Linux 音频服务器

```bash
sudo apt install -y libpulse-dev pulseaudio
```

### 8.3 CoreAudio (macOS)

**用途**: macOS 音频

macOS 自带，无需额外安装。

### 8.4 WASAPI (Windows)

**用途**: Windows 音频

由 Windows SDK 提供。

---

## 9. 编译工具链

### 9.1 基础工具（所有平台）

```bash
# Git
git --version  # >= 2.0

# CMake
cmake --version  # >= 3.16

# Ninja
ninja --version

# pkg-config
pkg-config --version
```

### 9.2 C/C++ 编译器

**Linux**:
```bash
gcc --version  # >= 9.0
g++ --version
```

**macOS**:
```bash
clang --version  # >= 12.0
clang++ --version
```

**Windows**:
```powershell
cl.exe  # MSVC 19.0+
```

### 9.3 链接器

**Linux**:
```bash
ld -v
ldd --version
```

**macOS**:
```bash
ld
```

**Windows**:
```powershell
link.exe
```

---

## 10. 可选依赖

### 10.1 性能分析

**Valgrind** (Linux):
```bash
sudo apt install -y valgrind
```

**Instruments** (macOS):
- 随 Xcode 安装

**Visual Studio Profiler** (Windows):
- 随 Visual Studio 安装

### 10.2 代码格式化

```bash
rustup component add rustfmt
rustup component add clippy
```

### 10.3 测试

```bash
rustup component add rustfmt --toolchain stable
cargo install cargo-nextest  # 可选，更快的测试运行器
```

### 10.4 文档生成

```bash
cargo install cargo-doc
```

### 10.5 安全扫描

```bash
cargo install cargo-audit
cargo install cargo-fuzz
```

---

## 依赖版本检查脚本

### Linux/macOS

```bash
#!/bin/bash
set -e

echo "=== RustDesk 依赖检查 ==="
echo

echo "Rust:"
rustc --version
cargo --version
rustup --version
echo

echo "编译工具:"
gcc --version | head -n 1
cmake --version | head -n 1
echo

echo "Git:"
git --version
echo

echo "pkg-config:"
pkg-config --version
echo

echo "Protocol Buffers:"
protoc --version
echo

echo "可选工具:"
nasm --version 2>/dev/null || echo "NASM: 未安装"
echo

echo "=== 检查完成 ==="
```

### Windows PowerShell

```powershell
Write-Host "=== RustDesk 依赖检查 ===" -ForegroundColor Green
Write-Host ""

Write-Host "Rust:"
rustc --version
cargo --version
rustup --version
Write-Host ""

Write-Host "Visual Studio:"
vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property displayName 2>$null || Write-Host "Visual Studio: 未检测到"
Write-Host ""

Write-Host "CMake:"
cmake --version 2>$null || Write-Host "CMake: 未安装"
Write-Host ""

Write-Host "Git:"
git --version
Write-Host ""

Write-Host "vcpkg:"
if ($env:VCPKG_ROOT) {
    Write-Host "VCPKG_ROOT: $env:VCPKG_ROOT"
} else {
    Write-Host "VCPKG: 未配置"
}
Write-Host ""

Write-Host "=== 检查完成 ===" -ForegroundColor Green
```

---

## 故障排除

### 依赖缺失错误

**错误**: `error: failed to run custom build command`

**解决方案**:
1. 检查所有必需依赖是否已安装
2. 确保依赖库在系统路径中
3. 清理并重新编译:
   ```bash
   cargo clean
   cargo build
   ```

### 版本不匹配

**错误**: `error: unsupported Rust version`

**解决方案**:
```bash
# 更新 Rust
rustup update

# 或指定特定版本
rustup install 1.81.0
rustup default 1.81.0
```

### 库路径问题

**错误**: `error: could not find native library`

**解决方案**:
```bash
# 设置 PKG_CONFIG_PATH
export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig:$PKG_CONFIG_PATH

# 设置 LD_LIBRARY_PATH (Linux)
export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH

# 设置 DYLD_LIBRARY_PATH (macOS)
export DYLD_LIBRARY_PATH=/usr/local/lib:$DYLD_LIBRARY_PATH
```

### 权限问题

**错误**: `permission denied`

**解决方案**:
```bash
# 确保有写权限
chmod +x scripts/*.sh

# 确保 cargo 目录有正确权限
chmod 700 ~/.cargo
```

---

## 下一步

依赖安装完成后，请参考以下文档进行编译：

- [BUILD_LINUX.md](BUILD_LINUX.md) - Linux 编译指南
- [BUILD_WINDOWS.md](BUILD_WINDOWS.md) - Windows 编译指南
- [BUILD_MACOS.md](BUILD_MACOS.md) - macOS 编译指南
- [BUILD_CROSS_COMPILE.md](BUILD_CROSS_COMPILE.md) - 交叉编译指南
