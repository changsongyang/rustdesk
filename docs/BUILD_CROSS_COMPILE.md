# RustDesk 交叉编译指南

## 目录

1. [概述](#1-概述)
2. [Linux 到 ARM 交叉编译](#2-linux-到-arm-交叉编译)
3. [Linux 到 Windows (MinGW) 交叉编译](#3-linux-到-windows-mingw-交叉编译)
4. [macOS 到 Linux 交叉编译](#4-macos-到-linux-交叉编译)
5. [Windows 到 Linux 交叉编译](#5-windows-到-linux-交叉编译)
6. [Docker 交叉编译方案](#6-docker-交叉编译方案)
7. [性能优化](#7-性能优化)
8. [故障排除](#8-故障排除)

---

## 1. 概述

### 1.1 什么是交叉编译

交叉编译是指在一个平台上（如 x86_64 Linux）编译出能够在另一个不同架构的平台（如 ARM）上运行的二进制文件。

### 1.2 常见场景

- **Linux → ARM**: 为 Raspberry Pi、ARM 服务器等编译
- **Linux → Windows**: 使用 MinGW 在 Linux 上编译 Windows 可执行文件
- **macOS → Linux**: 为 Linux 服务器编译（不常用）
- **Windows → Linux**: 使用 WSL 或交叉编译工具链

### 1.3 交叉编译优势

- **构建效率**: 在强大的 x86_64 机器上编译 ARM 代码，比在树莓派上快 10-20 倍
- **统一构建环境**: 在 CI/CD 流水线中统一构建多个平台
- **资源节省**: 不需要维护多个物理机器

### 1.4 工具链概念

```
┌─────────────────┐         ┌─────────────────┐
│   Build Host    │         │   Target Host   │
│  (编译机器)      │  ───>   │  (运行机器)     │
│                 │         │                 │
│ x86_64 Linux    │         │ ARM64 Linux     │
│                 │         │ (Raspberry Pi)  │
└─────────────────┘         └─────────────────┘
```

---

## 2. Linux 到 ARM 交叉编译

### 2.1 目标平台

- **Raspberry Pi 1/Zero**: ARMv6 (arm-unknown-linux-gnueabihf)
- **Raspberry Pi 2/3/4**: ARMv7 (armv7-unknown-linux-gnueabihf)
- **Raspberry Pi 3/4/5 (64-bit)**: ARM64 (aarch64-unknown-linux-gnu)
- **ARM 服务器**: ARM64 (aarch64-unknown-linux-gnu)

### 2.2 安装交叉编译工具链

#### 2.2.1 ARM64 (aarch64)

**Debian/Ubuntu**:

```bash
sudo apt update
sudo apt install -y gcc-aarch64-linux-gnu g++-aarch64-linux-gnu

# 验证安装
aarch64-linux-gnu-gcc --version
aarch64-linux-gnu-g++ --version
```

**CentOS/RHEL/Rocky Linux**:

```bash
sudo dnf install -y gcc-aarch64-linux-gnu g++-aarch64-linux-gnu

# 或从 EPEL
sudo dnf install -y crosspack-aarch64 TARGET=aarch64-linux-gnu
```

**Fedora**:

```bash
sudo dnf install -y gcc-aarch64-linux-gnu
```

**Arch Linux**:

```bash
sudo pacman -S --needed gcc-aarch64-linux-gnu
```

#### 2.2.2 ARMv7 (armv7l)

**Debian/Ubuntu**:

```bash
sudo apt install -y gcc-arm-linux-gnueabihf g++-arm-linux-gnueabihf

# 验证安装
arm-linux-gnueabihf-gcc --version
```

**其他发行版**:

```bash
sudo dnf install -y gcc-arm-linux-gnueabihf
```

#### 2.2.3 ARMv6

**Debian/Ubuntu**:

```bash
sudo apt install -y gcc-arm-linux-gnueabi g++-arm-linux-gnueabi

# 验证安装
arm-linux-gnueabi-gcc --version
```

### 2.3 配置 Rust 交叉编译

#### 2.3.1 添加 Rust 目标平台

```bash
# 添加 ARM64 目标
rustup target add aarch64-unknown-linux-gnu

# 添加 ARMv7 目标
rustup target add armv7-unknown-linux-gnueabihf

# 添加 ARMv6 目标
rustup target add arm-unknown-linux-gnueabi
```

#### 2.3.2 配置 .cargo/config.toml

创建或编辑 `~/.cargo/config.toml`：

```toml
[build]
# 默认目标（可选）
# target = "aarch64-unknown-linux-gnu"

[target.aarch64-unknown-linux-gnu]
linker = "aarch64-linux-gnu-gcc"

[target.armv7-unknown-linux-gnueabihf]
linker = "arm-linux-gnueabihf-gcc"

[target.arm-unknown-linux-gnueabi]
linker = "arm-linux-gnueabi-gcc"
```

#### 2.3.3 安装目标平台 sysroot

对于需要链接到目标平台特定库的项目：

```bash
# 安装 ARM64 sysroot
sudo apt install -y gcc-aarch64-linux-gnu libc6-dev-arm64-cross

# 安装 ARMv7 sysroot
sudo apt install -y gcc-arm-linux-gnueabihf libc6-dev-armhf-cross
```

### 2.4 编译步骤

#### 2.4.1 编译 RustDesk 服务端

```bash
# 克隆仓库
git clone https://github.com/rustdesk/rustdesk.git
cd rustdesk

# ARM64 编译
cargo build --release --target aarch64-unknown-linux-gnu

# 或 ARMv7 编译
cargo build --release --target armv7-unknown-linux-gnueabihf
```

#### 2.4.2 完整编译（包括 Flutter）

```bash
# 1. 交叉编译 Rust 服务端
cargo build --release --target aarch64-unknown-linux-gnu

# 2. Flutter 交叉编译需要更多配置
# 通常建议使用 Docker 或在目标平台上编译
```

### 2.5 部署到目标设备

#### 2.5.1 使用 scp 传输

```bash
# 复制二进制文件到树莓派
scp target/aarch64-unknown-linux-gnu/release/hbbs user@raspberry-pi:/tmp/
scp target/aarch64-unknown-linux-gnu/release/hbrs user@raspberry-pi:/tmp/

# SSH 到树莓派并安装
ssh user@raspberry-pi
sudo mv /tmp/hbbs /usr/local/bin/
sudo mv /tmp/hbrs /usr/local/bin/
sudo chmod +x /usr/local/bin/hbbs /usr/local/bin/hbrs
```

#### 2.5.2 使用 rsync 同步

```bash
# 安装（如果未安装）
sudo apt install -y rsync

# 同步整个目录
rsync -avz --progress target/aarch64-unknown-linux-gnu/release/ user@raspberry-pi:/tmp/
```

### 2.6 实际案例：Raspberry Pi 4

#### 2.6.1 目标设备信息

```bash
# 查看 Raspberry Pi 架构
ssh user@raspberry-pi uname -m
# 输出应该是 aarch64 (64-bit) 或 armv7l (32-bit)
```

#### 2.6.2 完整编译脚本

创建 `cross-compile-arm64.sh`：

```bash
#!/bin/bash
set -e

echo "=== RustDesk ARM64 交叉编译脚本 ==="

# 设置变量
TARGET="aarch64-unknown-linux-gnu"
BUILD_DIR="$HOME/rustdesk-build"
PROJECT_DIR="$BUILD_DIR/rustdesk"
OUTPUT_DIR="$BUILD_DIR/output-arm64"

# 检查工具链
if ! command -v ${TARGET}-gcc &> /dev/null; then
    echo "错误: 未安装 $TARGET 工具链"
    echo "运行: sudo apt install gcc-aarch64-linux-gnu"
    exit 1
fi

# 检查 Rust 目标
if ! rustup target list --installed | grep -q "$TARGET"; then
    echo "添加 Rust 目标: $TARGET"
    rustup target add "$TARGET"
fi

# 创建输出目录
mkdir -p "$OUTPUT_DIR"

# 进入项目目录
cd "$PROJECT_DIR"

# 清理旧构建（可选）
if [ "$1" == "clean" ]; then
    cargo clean
fi

# 设置优化标志
export RUSTFLAGS="-C lto=fat -C codegen-units=1 -C opt-level=3"

# 编译
echo "开始编译 RustDesk ($TARGET)..."
cargo build --release --target "$TARGET"

# 复制二进制文件
echo "复制二进制文件..."
cp "target/$TARGET/release/hbbs" "$OUTPUT_DIR/"
cp "target/$TARGET/release/hbrs" "$OUTPUT_DIR/"

# 设置可执行权限
chmod +x "$OUTPUT_DIR/hbbs"
chmod +x "$OUTPUT_DIR/hbrs"

# 显示文件信息
echo ""
echo "编译完成！"
echo "输出目录: $OUTPUT_DIR"
ls -lh "$OUTPUT_DIR/"

# 可选：计算哈希
echo ""
echo "文件哈希:"
sha256sum "$OUTPUT_DIR"/*
```

使用方式：

```bash
chmod +x cross-compile-arm64.sh
./cross-compile-arm64.sh

# 清理并重新编译
./cross-compile-arm64.sh clean
```

---

## 3. Linux 到 Windows (MinGW) 交叉编译

### 3.1 目标平台

- **Windows x64**: x86_64-pc-windows-gnu
- **Windows x86 (32-bit)**: i686-pc-windows-gnu

### 3.2 安装 MinGW 交叉编译工具链

#### 3.2.1 Debian/Ubuntu

```bash
sudo apt update
sudo apt install -y mingw-w64

# 安装 Windows 目标
# x86_64 (64-bit)
sudo apt install -y gcc-x86-64-win32 mingw-w64-x86-64-dev

# i686 (32-bit)
sudo apt install -y gcc-i686-win32 mingw-w64-i686-dev
```

#### 3.2.2 Fedora

```bash
sudo dnf install -y mingw64-gcc-c++ mingw64-winpthreads-static

# 启用 MinGW 跨编译支持
sudo dnf install -y mingw32-gcc-c++
```

#### 3.2.3 Arch Linux

```bash
sudo pacman -S --needed mingw-w64-gcc
```

### 3.3 配置 Rust 交叉编译

#### 3.3.1 添加 Rust 目标平台

```bash
# MinGW 目标已经包含在默认安装中
# 但可以确认一下
rustup target add x86_64-pc-windows-gnu
rustup target add i686-pc-windows-gnu
```

#### 3.3.2 配置 .cargo/config.toml

```toml
[target.x86_64-pc-windows-gnu]
linker = "x86_64-w64-mingw32-gcc"
ar = "x86_64-w64-mingw32-ar"

[target.i686-pc-windows-gnu]
linker = "i686-w64-mingw32-gcc"
ar = "i686-w64-mingw32-ar"
```

### 3.4 安装 Windows 依赖库

#### 3.4.1 使用 vcpkg (推荐)

```bash
# 克隆 vcpkg
git clone https://github.com/Microsoft/vcpkg.git /opt/vcpkg
cd /opt/vcpkg

# 安装 MinGW 工具链
./bootstrap-vcpkg.sh -mingw

# 安装 Windows 依赖
./vcpkg install --host-triplet x64-linux \
    ffmpeg:x64-mingw-dynamic \
    libvpx:x64-mingw-dynamic \
    opus:x64-mingw-dynamic \
    libsodium:x64-mingw-dynamic
```

#### 3.4.2 手动安装依赖

```bash
# 下载预编译的 Windows 库
mkdir -p /opt/windows-libs
cd /opt/windows-libs

# FFmpeg
wget https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-win64-gpl-shared.zip
unzip ffmpeg-master-latest-win64-gpl-shared.zip

# 设置环境变量
export PKG_CONFIG_PATH=/opt/windows-libs/ffmpeg-master-latest-win64-gpl-shared/lib/pkgconfig:$PKG_CONFIG_PATH
```

### 3.5 编译步骤

#### 3.5.1 编译 RustDesk 服务端

```bash
# 克隆仓库
git clone https://github.com/rustdesk/rustdesk.git
cd rustdesk

# x86_64 Windows 编译
cargo build --release --target x86_64-pc-windows-gnu

# 或 i686 Windows 编译
cargo build --release --target i686-pc-windows-gnu
```

#### 3.5.2 处理动态链接

MinGW 编译的二进制文件依赖 DLL 文件：

```bash
# 检查依赖
ldd target/x86_64-pc-windows-gnu/release/hbbs.exe

# 复制 DLL 文件
WIN_LIBS=/opt/windows-libs/ffmpeg-master-latest-win64-gpl-shared/bin
mkdir -p target/x86_64-pc-windows-gnu/release/bundle
cp target/x86_64-pc-windows-gnu/release/hbbs.exe target/x86_64-pc-windows-gnu/release/bundle/
cp "$WIN_LIBS"/*.dll target/x86_64-pc-windows-gnu/release/bundle/
```

#### 3.5.3 完整编译脚本

创建 `cross-compile-windows.sh`：

```bash
#!/bin/bash
set -e

echo "=== RustDesk Windows 交叉编译脚本 ==="

# 设置变量
TARGET="${1:-x86_64-pc-windows-gnu}"
BUILD_DIR="$HOME/rustdesk-build"
PROJECT_DIR="$BUILD_DIR/rustdesk"
OUTPUT_DIR="$BUILD_DIR/output-windows-$TARGET"

# 检查工具链
if [ "$TARGET" == "x86_64-pc-windows-gnu" ]; then
    TOOLCHAIN="x86_64-w64-mingw32"
else
    TOOLCHAIN="i686-w64-mingw32"
fi

if ! command -v ${TOOLCHAIN}-gcc &> /dev/null; then
    echo "错误: 未安装 $TOOLCHAIN 工具链"
    echo "运行: sudo apt install mingw-w64"
    exit 1
fi

# 创建输出目录
mkdir -p "$OUTPUT_DIR"

# 进入项目目录
cd "$PROJECT_DIR"

# 清理旧构建（可选）
if [ "$2" == "clean" ]; then
    cargo clean
fi

# 设置编译标志
export CARGO_TARGET_${TARGET//-/_}_LINKER="${TOOLCHAIN}-gcc"
export RUSTFLAGS="-C linker=${TOOLCHAIN}-gcc -C opt-level=3"

# 编译
echo "开始编译 RustDesk ($TARGET)..."
cargo build --release --target "$TARGET"

# 复制二进制文件
echo "复制二进制文件..."
cp "target/$TARGET/release/hbbs.exe" "$OUTPUT_DIR/"
cp "target/$TARGET/release/hbrs.exe" "$OUTPUT_DIR/"

# 显示文件信息
echo ""
echo "编译完成！"
echo "输出目录: $OUTPUT_DIR"
ls -lh "$OUTPUT_DIR/"

# 可选：复制依赖的 DLL
if [ -d "/opt/windows-libs" ]; then
    echo ""
    echo "复制 DLL 依赖..."
    cp /opt/windows-libs/ffmpeg-*/bin/*.dll "$OUTPUT_DIR/" 2>/dev/null || true
    ls -lh "$OUTPUT_DIR/"
fi
```

使用方式：

```bash
chmod +x cross-compile-windows.sh

# 编译 x86_64 Windows
./cross-compile-windows.sh x86_64-pc-windows-gnu

# 编译 i686 Windows
./cross-compile-windows.sh i686-pc-windows-gnu
```

---

## 4. macOS 到 Linux 交叉编译

### 4.1 目标平台

- **Linux x86_64**: x86_64-unknown-linux-gnu
- **Linux ARM64**: aarch64-unknown-linux-gnu

### 4.2 macOS 的限制

macOS 原生不支持 Linux 交叉编译。需要使用以下方法之一：

1. **使用 Homebrew 安装 Linux 工具链**（推荐）
2. **使用 Docker**（见下一节）
3. **使用 macOS 交叉编译工具链**

#### 4.2.1 使用 Homebrew 安装

```bash
brew install FiloSottile/musl-cross/musl-cross
brew install linux-headers-musl

# 安装 Linux x86_64 工具链
brew install FiloSottile/musl-cross/musl-cross --with-x86_64-linux-headers

# 安装 Linux ARM64 工具链
brew install arm-linux-gnueabihf-binutils
```

### 4.3 配置 Rust

#### 4.3.1 添加目标平台

```bash
rustup target add x86_64-unknown-linux-gnu
rustup target add aarch64-unknown-linux-gnu
```

#### 4.3.2 配置链接器

```toml
# ~/.cargo/config.toml
[target.x86_64-unknown-linux-gnu]
linker = "x86_64-linux-musl-gcc"

[target.aarch64-unknown-linux-gnu]
linker = "aarch64-linux-gnu-gcc"
```

### 4.4 编译步骤

由于 macOS 环境配置复杂，建议使用 Docker 方案（见下一节）。

---

## 5. Windows 到 Linux 交叉编译

### 5.1 目标平台

- **Linux x86_64**: x86_64-unknown-linux-gnu
- **Linux ARM64**: aarch64-unknown-linux-gnu

### 5.2 Windows 的限制

Windows 原生交叉编译到 Linux 非常困难。建议使用以下方法：

1. **使用 WSL (Windows Subsystem for Linux)**（推荐）
2. **使用 Docker Desktop**
3. **使用 MinGW-w64 + Linux sysroot**

#### 5.2.1 WSL 方案（推荐）

```powershell
# 1. 启用 WSL
wsl --install

# 2. 安装 Linux 发行版（推荐 Ubuntu）
wsl --install -d Ubuntu-22.04

# 3. 在 WSL 中按照 Linux 编译指南进行编译
```

详细步骤：

```bash
# 在 WSL 终端中
# 安装 Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# 添加目标平台
rustup target add x86_64-unknown-linux-gnu

# 配置链接器
cat >> ~/.cargo/config.toml << 'EOF'
[target.x86_64-unknown-linux-gnu]
linker = "gcc"
EOF

# 克隆并编译
git clone https://github.com/rustdesk/rustdesk.git
cd rustdesk
cargo build --release --target x86_64-unknown-linux-gnu
```

#### 5.2.2 Docker Desktop 方案

```powershell
# 1. 安装 Docker Desktop
# https://www.docker.com/products/docker-desktop

# 2. 启用 WSL2 后端（推荐）
# Docker Settings -> General -> Use WSL 2 instead of Hyper-V

# 3. 运行交叉编译容器
docker run -it --rm \
    -v $PWD:/workspace \
    -w /workspace \
    rustembedded/cross:armv7-unknown-linux-gnueabihf \
    cargo build --release
```

---

## 6. Docker 交叉编译方案

### 6.1 Docker 交叉编译优势

- **环境隔离**: 不污染宿主机
- **一致性**: 所有构建环境相同
- **多平台**: 轻松支持多个目标平台
- **CI/CD 集成**: 与 GitHub Actions 等工具无缝集成

### 6.2 使用 rustembedded/cross

#### 6.2.1 安装 cross

```bash
cargo install cross
```

#### 6.2.2 使用 cross 编译

```bash
# ARM64 编译
cross build --release --target aarch64-unknown-linux-gnu

# ARMv7 编译
cross build --release --target armv7-unknown-linux-gnueabihf

# Windows MinGW 编译
cross build --release --target x86_64-pc-windows-gnu
```

### 6.3 自定义 Dockerfile

创建 `Dockerfile.cross`：

```dockerfile
# 基于 Rust 官方镜像
FROM rust:1.81.0 AS builder

# 安装交叉编译工具链
RUN apt-get update && apt-get install -y \
    gcc-aarch64-linux-gnu \
    gcc-arm-linux-gnueabihf \
    mingw-w64 \
    && rm -rf /var/lib/apt/lists/*

# 复制源代码
WORKDIR /app
COPY . .

# ARM64 编译
RUN rustup target add aarch64-unknown-linux-gnu && \
    cargo build --release --target aarch64-unknown-linux-gnu

# 保存产物
FROM alpine:3.18
COPY --from=builder /app/target/aarch64-unknown-linux-gnu/release/hbbs /usr/local/bin/
COPY --from=builder /app/target/aarch64-unknown-linux-gnu/release/hbrs /usr/local/bin/
CMD ["sh"]
```

构建并运行：

```bash
docker build -t rustdesk-cross -f Dockerfile.cross .
docker run -it --rm rustdesk-cross
```

### 6.4 Docker Compose 配置

创建 `docker-compose.cross-compile.yml`：

```yaml
version: '3.8'

services:
  # ARM64 编译
  build-arm64:
    image: rustembedded/cross:armv7-unknown-linux-gnueabihf
    volumes:
      - .:/workspace
    working_dir: /workspace
    command: cargo build --release --target aarch64-unknown-linux-gnu
    output: ./target/aarch64-unknown-linux-gnu/release

  # ARMv7 编译
  build-armv7:
    image: rustembedded/cross:armv7-unknown-linux-gnueabihf
    volumes:
      - .:/workspace
    working_dir: /workspace
    command: cargo build --release --target armv7-unknown-linux-gnueabihf
    output: ./target/armv7-unknown-linux-gnueabihf/release

  # Windows x64 编译
  build-windows:
    image: rustembedded/cross:x86_64-pc-windows-gnu
    volumes:
      - .:/workspace
    working_dir: /workspace
    command: cargo build --release --target x86_64-pc-windows-gnu
    output: ./target/x86_64-pc-windows-gnu/release
```

使用：

```bash
# ARM64 编译
docker-compose -f docker-compose.cross-compile.yml run build-arm64

# 所有平台编译
docker-compose -f docker-compose.cross-compile.yml run build-arm64
docker-compose -f docker-compose.cross-compile.yml run build-armv7
docker-compose -f docker-compose.cross-compile.yml run build-windows
```

### 6.5 GitHub Actions CI/CD 集成

创建 `.github/workflows/cross-compile.yml`：

```yaml
name: Cross Compile

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
  release:
    types: [published]

jobs:
  build:
    runs-on: ubuntu-latest
    
    strategy:
      matrix:
        target:
          - armv7-unknown-linux-gnueabihf
          - aarch64-unknown-linux-gnu
          - x86_64-unknown-linux-gnu
          - x86_64-pc-windows-gnu
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Install Rust
        uses: dtolnay/rust-toolchain@stable
        
      - name: Add target
        run: rustup target add ${{ matrix.target }}
        
      - name: Build
        run: cargo build --release --target ${{ matrix.target }}
        
      - name: Upload artifacts
        uses: actions/upload-artifact@v4
        with:
          name: rustdesk-${{ matrix.target }}
          path: target/${{ matrix.target }}/release/hbbs
          path: target/${{ matrix.target }}/release/hbrs
```

---

## 7. 性能优化

### 7.1 编译速度优化

#### 7.1.1 启用并行编译

```bash
# 设置 CPU 核心数
export CARGO_BUILD_JOBS=$(nproc)

# 或在 .cargo/config.toml 中
[build]
jobs = 8
```

#### 7.1.2 使用 ccache

```bash
# 安装 ccache
sudo apt install -y ccache

# 配置 Rust 使用 ccache
# 编辑 .cargo/config.toml
[build]
rustc-wrapper = "ccache"

# 设置缓存大小
ccache -M 10G
ccache -o cache_dir=/tmp/ccache
```

#### 7.1.3 sccache

sccache 是 Rust 专用的编译器缓存：

```bash
# 安装 sccache
cargo install sccache

# 配置
export RUSTC_WRAPPER=sccache
export SCCACHE_CACHE_SIZE=50G

# 查看缓存统计
sccache --show-stats
```

### 7.2 二进制文件优化

#### 7.1.2 启用 LTO

```toml
# Cargo.toml 或 .cargo/config.toml
[profile.release]
lto = "fat"
codegen-units = 1
opt-level = 3
```

#### 7.1.3 剥离调试信息

```bash
export RUSTFLAGS="-C strip=symbols -C lto=fat -C codegen-units=1"
cargo build --release --target aarch64-unknown-linux-gnu
```

### 7.3 链接优化

#### 7.3.1 使用 lld 链接器

```bash
# 安装 lld
sudo apt install -y lld

# 配置 Rust 使用 lld
# 编辑 .cargo/config.toml
[target.aarch64-unknown-linux-gnu]
linker = "aarch64-linux-gnu-gcc"

[target.aarch64-unknown-linux-gnu]
rustflags = ["-C", "link-arg=-fuse-ld=lld"]
```

---

## 8. 故障排除

### 8.1 常见错误

**错误 1**: `error: cannot find linker`

```bash
# 确保安装了正确的工具链
# ARM64
sudo apt install -y gcc-aarch64-linux-gnu

# Windows
sudo apt install -y mingw-w64

# 配置 Rust 使用正确的链接器
# 编辑 .cargo/config.toml
[target.aarch64-unknown-linux-gnu]
linker = "aarch64-linux-gnu-gcc"
```

**错误 2**: `error: linking with `cc` failed`

```bash
# 检查链接器路径
which aarch64-linux-gnu-gcc

# 确保工具链已正确安装
aarch64-linux-gnu-gcc --version
```

**错误 3**: `error: target architecture `xxx` not supported`

```bash
# 添加 Rust 目标平台
rustup target add aarch64-unknown-linux-gnu
rustup target add x86_64-pc-windows-gnu
```

**错误 4**: 编译成功但运行失败

```bash
# 检查二进制文件架构
file target/aarch64-unknown-linux-gnu/release/hbbs

# 应该看到
# hbbs: ELF 64-bit LSB executable, ARM aarch64

# 检查依赖
ldd target/aarch64-unknown-linux-gnu/release/hbbs
```

### 8.2 调试技巧

#### 8.2.1 详细编译输出

```bash
# 显示详细的编译命令
cargo build --release --target aarch64-unknown-linux-gnu -vv
```

#### 8.2.2 检查工具链

```bash
# 列出已安装的 Rust 目标
rustup target list --installed

# 列出可用的交叉编译器
ls /usr/bin/*-linux-gnu-gcc
```

#### 8.2.3 手动测试链接器

```bash
# 测试交叉编译器的简单程序
cat > test.c << 'EOF'
#include <stdio.h>
int main() { printf("Hello\n"); return 0; }
EOF

# 编译测试
aarch64-linux-gnu-gcc test.c -o test_aarch64
file test_aarch64
```

### 8.3 工具链验证脚本

创建 `verify-toolchain.sh`：

```bash
#!/bin/bash
set -e

echo "=== 交叉编译工具链验证 ==="

# 检查 Rust
echo "检查 Rust..."
rustc --version
cargo --version
rustup --version

echo ""
echo "检查已安装的 Rust 目标平台..."
rustup target list --installed

echo ""
echo "检查交叉编译器..."
echo "ARM64:"
which aarch64-linux-gnu-gcc 2>/dev/null && aarch64-linux-gnu-gcc --version | head -n 1 || echo "未安装"

echo ""
echo "ARMv7:"
which arm-linux-gnueabihf-gcc 2>/dev/null && arm-linux-gnueabihf-gcc --version | head -n 1 || echo "未安装"

echo ""
echo "Windows MinGW:"
which x86_64-w64-mingw32-gcc 2>/dev/null && x86_64-w64-mingw32-gcc --version | head -n 1 || echo "未安装"

echo ""
echo "=== 验证完成 ==="
```

---

## 附录 A：常用交叉编译目标

| 目标平台 | Rust 目标 | 工具链包 | 用途 |
|---------|-----------|----------|------|
| ARM64 Linux | aarch64-unknown-linux-gnu | gcc-aarch64-linux-gnu | Raspberry Pi 3/4/5, ARM 服务器 |
| ARMv7 Linux | armv7-unknown-linux-gnueabihf | gcc-arm-linux-gnueabihf | Raspberry Pi 2 |
| ARMv6 Linux | arm-unknown-linux-gnueabi | gcc-arm-linux-gnueabi | Raspberry Pi 1/Zero |
| Windows x64 | x86_64-pc-windows-gnu | mingw-w64-x86-64 | Windows 10/11 64-bit |
| Windows x86 | i686-pc-windows-gnu | mingw-w64-i686 | Windows 32-bit |

---

## 附录 B：性能基准测试

### B.1 编译时间对比

| 目标平台 | 硬件 | 编译时间 | 备注 |
|---------|------|----------|------|
| 本机 x86_64 | 8 核 CPU | ~3 分钟 | 最快 |
| ARM64 交叉编译 | 8 核 CPU | ~4 分钟 | 略慢，链接阶段 |
| ARM64 本机 | Raspberry Pi 4 | ~45 分钟 | 非常慢 |
| Windows MinGW | 8 核 CPU | ~5 分钟 | 需要额外配置 |

### B.2 二进制文件大小

| 目标平台 | 优化方式 | hbbs 大小 | hbrs 大小 |
|---------|---------|----------|----------|
| x86_64 Linux | LTO + strip | ~8 MB | ~7 MB |
| ARM64 Linux | LTO + strip | ~8 MB | ~7 MB |
| Windows x64 | LTO + strip | ~10 MB | ~9 MB |

---

## 相关文档

- [BUILD_PREREQUISITES.md](BUILD_PREREQUISITES.md) - 编译依赖清单
- [BUILD_LINUX.md](BUILD_LINUX.md) - Linux 编译指南
- [BUILD_WINDOWS.md](BUILD_WINDOWS.md) - Windows 编译指南
- [BUILD_MACOS.md](BUILD_MACOS.md) - macOS 编译指南
- [DEPLOYMENT.md](DEPLOYMENT.md) - 部署总览
