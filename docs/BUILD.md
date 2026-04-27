# RustDesk 构建流程文档

## 目录
1. [概述](#概述)
2. [环境要求](#环境要求)
3. [本地开发环境配置](#本地开发环境配置)
4. [依赖安装](#依赖安装)
5. [构建流程](#构建流程)
6. [CI/CD 流程](#cicd-流程)
7. [常见问题](#常见问题)

## 概述

本文档详细描述了 RustDesk 项目的构建流程，包括本地开发环境配置、依赖安装、构建步骤以及 CI/CD 流程。

### 项目结构

```
rustdesk/
├── .github/
│   └── workflows/
│       └── playground.yml    # CI/CD 工作流配置
├── scripts/
│   ├── setup-local-env.sh   # 本地环境配置脚本
│   ├── check-env-consistency.sh  # 环境一致性检查脚本
│   └── local-build.sh       # 本地构建脚本
├── res/
│   └── vcpkg/               # vcpkg overlay 配置
│       ├── aom/
│       └── libvpx/
├── flutter/                  # Flutter UI 代码
├── libs/                     # Rust 库
├── src/                      # Rust 源代码
├── vcpkg.json               # vcpkg 依赖配置
├── Cargo.toml               # Cargo 依赖配置
├── build.py                 # 主构建脚本
└── Cargo.lock               # Cargo 锁定文件
```

## 环境要求

### 必需工具

| 工具 | 版本 | 说明 |
|------|------|------|
| Rust | 1.95 | Rust 编程语言工具链 |
| Flutter | 3.24.5 | Flutter UI 框架 |
| Python | 3.8+ | Python 解释器 |
| vcpkg | 120deac3062162151622ca4860575a33844ba10b | C++ 依赖管理器 |

### 操作系统支持

- **macOS**: 13+ (x86_64 和 ARM64)
- **Linux**: Ubuntu 22.04+ (x86_64)
- **Windows**: Windows 10+ (x86_64)

## 本地开发环境配置

### 自动配置（推荐）

使用项目提供的自动化脚本配置本地环境：

```bash
# 1. 克隆项目
git clone https://github.com/rustdesk/rustdesk.git
cd rustdesk

# 2. 运行环境配置脚本
bash scripts/setup-local-env.sh

# 3. 加载环境变量
source ~/.cargo/env  # Linux/macOS
# 或重新打开终端

# 4. 验证环境配置
bash scripts/check-env-consistency.sh
```

### 手动配置

#### Rust 安装

```bash
# 安装 Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

# 切换到指定版本
rustup install 1.95
rustup default 1.95
```

#### Flutter 安装

```bash
# macOS
brew install flutter

# Linux
git clone https://github.com/flutter/flutter.git -b stable $HOME/flutter
export PATH="$HOME/flutter/bin:$PATH"
```

#### vcpkg 安装

```bash
# 克隆 vcpkg
git clone https://github.com/microsoft/vcpkg.git $HOME/vcpkg
cd $HOME/vcpkg

# 切换到指定版本
git checkout 120deac3062162151622ca4860575a33844ba10b

# 初始化（Windows）
./bootstrap-vcpkg.bat

# 初始化（Linux/macOS）
./bootstrap-vcpkg.sh

# 设置环境变量
export VCPKG_ROOT="$HOME/vcpkg"
export VCPKG_INSTALL_ROOT="$HOME/vcpkg/installed"
```

## 依赖安装

### vcpkg 依赖

项目使用 vcpkg 管理 C++ 依赖，配置文件为 `vcpkg.json`。

```bash
# 安装所有依赖
$VCPKG_ROOT/vcpkg install

# 或使用 manifest 模式
$VCPKG_ROOT/vcpkg install --manifest
```

### 关键依赖

| 依赖 | 版本 | 说明 |
|------|------|------|
| aom | 3.12.1 | AV1 视频编码器 |
| libvpx | 1.15.2 | VP8/VP9 视频编码器 |
| libyuv | 1916 | YUV 图像处理 |
| opus | 1.5.2 | 音频编解码器 |

### Rust 依赖

```bash
# 下载 Rust 依赖
cargo fetch
```

### Flutter 依赖

```bash
cd flutter
flutter pub get
```

## 构建流程

### 使用构建脚本（推荐）

```bash
# 构建 Flutter UI（默认）
python3 build.py --flutter

# 构建 debug 版本
python3 build.py --flutter --debug

# 使用本地构建脚本（与 CI 一致）
bash scripts/local-build.sh
```

### 分步构建

#### 1. 生成内联资源

```bash
python3 res/inline-sciter.py
```

#### 2. 编译 Rust 代码

```bash
cargo build --release
```

#### 3. 编译 Flutter UI

```bash
cd flutter
flutter build macos --release  # macOS
flutter build apk --release    # Android
```

### 构建产物

| 平台 | 产物路径 |
|------|----------|
| macOS | `flutter/build/macos/Build/Products/Release/RustDesk.app` |
| macOS DMG | `rustdesk-VERSION-x86_64.dmg` |
| Android APK | `flutter/build/app/outputs/flutter-apk/app-release.apk` |
| Windows EXE | `target/release/rustdesk.exe` |

## CI/CD 流程

### GitHub Actions 工作流

项目使用 `.github/workflows/playground.yml` 定义 CI/CD 流程。

#### 工作流配置

```yaml
env:
  RUST_VERSION: "1.95"
  FLUTTER_VERSION: "3.24.5"
  VCPKG_COMMIT_ID: "120deac3062162151622ca4860575a33844ba10b"
  CARGO_NET_RETRY: "10"
```

#### 构建矩阵

| 平台 | 架构 | Flutter 版本 | 状态 |
|------|------|--------------|------|
| macOS 13 | x86_64 | 3.13.9 | ✅ 支持 |
| macOS 13 | x86_64 | 3.10.6 | ✅ 支持 |
| Android | aarch64 | 3.24.5 | 🔧 开发中 |

#### 缓存策略

1. **Rust 依赖缓存**: 使用 `Swatinem/rust-cache@v2`
2. **Flutter 依赖缓存**: 使用 `actions/cache@v5`
3. **vcpkg 二进制缓存**: 使用 GitHub Actions 缓存

### 本地验证 CI 配置

使用工作流配置在本地验证构建：

```bash
# 检查环境一致性
bash scripts/check-env-consistency.sh

# 模拟 CI 构建
bash scripts/local-build.sh --skip-deps
```

## 常见问题

### 1. vcpkg 依赖下载失败

**问题**: 网络问题导致 vcpkg 依赖下载失败

**解决方案**:
```bash
# 配置网络代理（如果需要）
export HTTP_PROXY=http://proxy.example.com:8080
export HTTPS_PROXY=http://proxy.example.com:8080

# 增加重试次数
export VCPKG_MAX_RETRIES=10
export VCPKG_HTTP_TIMEOUT=300

# 重新安装依赖
$VCPKG_ROOT/vcpkg install
```

### 2. Rust 版本不匹配

**问题**: 本地 Rust 版本与 CI 配置不一致

**解决方案**:
```bash
# 切换到正确版本
rustup install 1.95
rustup default 1.95

# 验证版本
rustc --version
```

### 3. Flutter 依赖问题

**问题**: Flutter 依赖无法下载

**解决方案**:
```bash
# 清理缓存
flutter clean

# 重新获取依赖
flutter pub get

# 更新依赖
flutter pub upgrade
```

### 4. 构建失败诊断

**问题**: 构建过程中出现错误

**解决方案**:
```bash
# 1. 检查磁盘空间
df -h

# 2. 清理构建缓存
cargo clean
flutter clean

# 3. 重新安装依赖
cargo fetch
flutter pub get

# 4. 重新构建
cargo build --release 2>&1 | tee build.log
```

### 5. 网络超时

**问题**: Cargo 或 Flutter 下载超时

**解决方案**:
```bash
# 增加 Cargo 网络超时
export CARGO_NET_RETRY=10
export CARGO_HTTP_TIMEOUT=300

# 使用代理（如果需要）
export CARGO_HTTP_PROXY=http://proxy.example.com:8080
```

## 附录

### A. 环境变量参考

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `RUST_VERSION` | 1.95 | Rust 工具链版本 |
| `FLUTTER_VERSION` | 3.24.5 | Flutter SDK 版本 |
| `VCPKG_ROOT` | ~/vcpkg | vcpkg 安装目录 |
| `VCPKG_INSTALL_ROOT` | ~/vcpkg/installed | vcpkg 安装根目录 |
| `CARGO_NET_RETRY` | 10 | Cargo 网络重试次数 |
| `CARGO_HTTP_TIMEOUT` | 300 | Cargo HTTP 超时（秒） |

### B. 构建时间参考

| 构建类型 | 首次构建 | 增量构建 |
|----------|----------|----------|
| macOS | ~30-45 分钟 | ~10-15 分钟 |
| Android | ~40-60 分钟 | ~15-20 分钟 |
| Linux | ~25-35 分钟 | ~8-12 分钟 |

### C. 联系方式

- **问题反馈**: [GitHub Issues](https://github.com/rustdesk/rustdesk/issues)
- **讨论群组**: [RustDesk Discord](https://discord.gg/rustdesk)
