# RustDesk 构建手册

## 目录

1. [概述](#1-概述)
2. [依赖管理](#2-依赖管理)
3. [构建工具配置](#3-构建工具配置)
4. [编译步骤](#4-编译步骤)
5. [打包策略](#5-打包策略)
6. [版本控制规范](#6-版本控制规范)
7. [构建环境要求](#7-构建环境要求)
8. [常见问题解决方案](#8-常见问题解决方案)

---

## 1. 概述

### 1.1 文档目的

本手册详细描述 RustDesk 项目的构建流程，帮助开发人员和运维人员正确、高效地构建项目。

### 1.2 构建流程概览

```
依赖检测 → 环境配置 → 编译 Rust 组件 → 编译 Flutter 组件 → 打包 → 验证
```

### 1.3 支持平台

| 平台 | 架构 | 状态 |
|------|------|------|
| Linux | x86_64, aarch64 | ✅ 支持 |
| macOS | x86_64, aarch64 | ✅ 支持 |
| Windows | x86, x86_64 | ✅ 支持 |
| Android | armv7, aarch64 | ✅ 支持 |
| iOS | aarch64 | ✅ 支持 |

---

## 2. 依赖管理

### 2.1 Rust 依赖

Rust 依赖通过 Cargo 管理，配置文件为 `Cargo.toml`：

```toml
[workspace]
members = [
    ".",
    "libs/hbb_common",
    "libs/scrap",
    "libs/enigo",
    "libs/clipboard",
]

[dependencies]
tokio = { version = "1", features = ["full"] }
protobuf = "3"
openssl = "0.10"
```

### 2.2 C++ 依赖

C++ 依赖通过 vcpkg 管理，配置文件为 `vcpkg.json`：

```json
{
  "name": "rustdesk",
  "dependencies": [
    "ffmpeg",
    "libvpx",
    "opus",
    "libsodium"
  ]
}
```

### 2.3 Flutter 依赖

Flutter 依赖通过 `pubspec.yaml` 管理：

```yaml
dependencies:
  flutter:
    sdk: flutter
  provider: ^6.0.0
  flutter_bloc: ^8.0.0
```

### 2.4 依赖安装命令

```bash
# Rust 依赖
cargo fetch

# vcpkg 依赖
vcpkg install --triplet x64-windows-static

# Flutter 依赖
flutter pub get
```

---

## 3. 构建工具配置

### 3.1 Cargo 配置

**文件**: `~/.cargo/config.toml`

```toml
[build]
target-dir = "target"
jobs = 4

[env]
RUSTFLAGS = "-C link-arg=-fuse-ld=lld"
```

### 3.2 vcpkg 配置

**文件**: `vcpkg.json`

```json
{
  "name": "rustdesk",
  "version-string": "1.5.0",
  "dependencies": [
    {
      "name": "ffmpeg",
      "version>=": "5.0.0"
    },
    "libvpx",
    "opus",
    "libsodium"
  ]
}
```

### 3.3 CMake 配置

**文件**: `CMakeLists.txt`

```cmake
cmake_minimum_required(VERSION 3.16)
project(rustdesk)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
```

### 3.4 GitHub Actions 配置

**文件**: `.github/workflows/flutter-build.yml`

```yaml
name: Flutter Build

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  build-linux:
    runs-on: ubuntu-22.04
    steps:
      - uses: actions/checkout@v4
      - uses: actions-rust-lang/setup-rust-toolchain@v1
      - run: ./scripts/build/build.sh -r
```

---

## 4. 编译步骤

### 4.1 环境准备

```bash
# 克隆仓库
git clone https://github.com/rustdesk/rustdesk.git
cd rustdesk
git submodule update --init --recursive

# 检查依赖
./scripts/build/check-deps.sh
```

### 4.2 Linux 编译

```bash
# Debug 构建
cargo build

# Release 构建
cargo build --release

# 指定目标架构
cargo build --release --target aarch64-unknown-linux-gnu

# 构建 Flutter
flutter build linux
```

### 4.3 macOS 编译

```bash
# 安装依赖
brew install nasm yasm

# Release 构建
cargo build --release

# 构建 Flutter
flutter build macos
```

### 4.4 Windows 编译

```powershell
# 使用 Visual Studio Developer Command Prompt
# 或设置环境变量
.\scripts\build\build.sh -r
```

### 4.5 Android 编译

```bash
# 设置环境变量
export ANDROID_NDK_HOME=/path/to/ndk
export ANDROID_HOME=/path/to/android-sdk

# 构建
cargo ndk --target aarch64-linux-android build --release

# Flutter 构建
flutter build apk
```

### 4.6 iOS 编译

```bash
# 设置环境变量
export IOS_SDK_PATH=$(xcrun --show-sdk-path --sdk iphoneos)

# 构建
cargo build --target aarch64-apple-ios --release

# Flutter 构建
flutter build ios
```

---

## 5. 打包策略

### 5.1 Linux 打包

```bash
# 创建 AppImage
./scripts/build/package-appimage.sh

# 创建 DEB 包
./scripts/build/package-deb.sh

# 创建 RPM 包
./scripts/build/package-rpm.sh
```

### 5.2 macOS 打包

```bash
# 创建 DMG
flutter build macos
./scripts/build/package-dmg.sh

# 签名
codesign --force --deep --sign "Developer ID Application" build/macos/Build/Products/Release/rustdesk.app
```

### 5.3 Windows 打包

```powershell
# 创建安装程序
flutter build windows
./scripts/build/package-installer.ps1

# 签名
signtool sign /f certificate.pfx /p password target/release/rustdesk.exe
```

### 5.4 Android 打包

```bash
# 构建 APK
flutter build apk --release

# 构建 App Bundle
flutter build appbundle

# 签名
apksigner sign --ks keystore.jks --ks-key-alias alias app-release.apk
```

---

## 6. 版本控制规范

### 6.1 版本号格式

采用 Semantic Versioning：

```
MAJOR.MINOR.PATCH
```

- **MAJOR**: 重大功能变更，不兼容的 API 变更
- **MINOR**: 新功能，向后兼容
- **PATCH**: Bug 修复，向后兼容

### 6.2 版本管理流程

```bash
# 更新版本号
sed -i 's/version = "1.4.0"/version = "1.5.0"/' Cargo.toml

# 创建标签
git tag -a v1.5.0 -m "Release v1.5.0"

# 推送标签
git push origin v1.5.0
```

### 6.3 分支策略

| 分支 | 用途 |
|------|------|
| main | 稳定版本 |
| develop | 开发分支 |
| feature/* | 功能开发 |
| hotfix/* | 紧急修复 |

---

## 7. 构建环境要求

### 7.1 硬件要求

| 配置 | 最低 | 推荐 |
|------|------|------|
| CPU | 4核 | 8核 |
| 内存 | 8GB | 16GB |
| 存储 | 50GB | 100GB |

### 7.2 软件要求

| 软件 | 最低版本 | 说明 |
|------|----------|------|
| Rust | 1.81.0 | 核心语言 |
| Flutter | 3.24.5 | UI 框架 |
| vcpkg | 2023.11.15 | C++ 依赖 |
| CMake | 3.16 | 构建系统 |
| Git | 2.0 | 版本控制 |

### 7.3 CI/CD 环境

**GitHub Actions 运行器**:

| 运行器 | 操作系统 | 规格 |
|--------|----------|------|
| ubuntu-22.04 | Ubuntu 22.04 | 2核, 7GB |
| windows-2022 | Windows Server 2022 | 2核, 7GB |
| macos-12 | macOS 12 | 3核, 14GB |

---

## 8. 常见问题解决方案

### 8.1 依赖缺失

**错误**:
```
error: failed to run custom build command for `hwcodec`
```

**解决方案**:
```bash
# 确保 vcpkg 依赖已安装
vcpkg install --triplet x64-windows-static

# 清理缓存
cargo clean
```

### 8.2 LLVM 版本问题

**错误**:
```
Unable to find libclang
```

**解决方案**:
```bash
# 设置 LIBCLANG_PATH
export LIBCLANG_PATH=/usr/lib/llvm-15/lib
```

### 8.3 内存不足

**错误**:
```
signal: 9, SIGKILL: kill
```

**解决方案**:
```bash
# 减少并行编译
cargo build --jobs 1

# 增加交换空间
sudo fallocate -l 4G /swapfile
sudo swapon /swapfile
```

### 8.4 链接错误

**错误**:
```
error: linking with `cc` failed
```

**解决方案**:
```bash
# 安装必要的库
sudo apt-get install build-essential libssl-dev
```

### 8.5 Flutter 构建失败

**错误**:
```
Error: No pubspec.yaml file found
```

**解决方案**:
```bash
# 确保在正确目录
cd rustdesk/flutter
flutter pub get
```

---

## 更新日志

### v1.0.0 (2024-01-01)
- 初始版本发布
- 包含依赖管理、构建工具配置、编译步骤、打包策略、版本控制规范、构建环境要求、常见问题解决方案