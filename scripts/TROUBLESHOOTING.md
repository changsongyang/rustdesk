# 构建故障排除指南

## 概述

本指南提供 rustdesk 项目构建过程中常见问题的解决方案。

## 目录

1. [依赖相关问题](#依赖相关问题)
2. [环境配置问题](#环境配置问题)
3. [编译错误](#编译错误)
4. [链接错误](#链接错误)
5. [缓存问题](#缓存问题)
6. [网络问题](#网络问题)
7. [平台特定问题](#平台特定问题)
8. [其他问题](#其他问题)

---

## 依赖相关问题

### 1.1 Rust 版本不满足要求

**错误信息**:
```
ERROR: Rust version 1.70.0 is too old. Required: 1.81.0
```

**解决方案**:
```bash
# 更新 Rust
rustup update

# 设置指定版本
rustup default 1.81.0

# 验证版本
rustc --version
```

### 1.2 Cargo 命令未找到

**错误信息**:
```
cargo: command not found
```

**解决方案**:
```bash
# Linux/macOS - 添加到 PATH
source "$HOME/.cargo/env"

# 或者添加到 shell 配置文件
echo 'source "$HOME/.cargo/env"' >> ~/.bashrc
```

### 1.3 Flutter 未安装

**错误信息**:
```
WARN: Flutter not found - skipping Flutter version check
```

**解决方案**:
```bash
# 参考官方安装指南
# https://docs.flutter.dev/get-started/install

# 验证安装
flutter --version
```

### 1.4 LLVM/clang 未安装

**错误信息**:
```
clang: command not found
```

**解决方案**:

**Linux (Ubuntu/Debian)**:
```bash
sudo apt-get update
sudo apt-get install clang-15 llvm-15
```

**macOS**:
```bash
brew install llvm@15
```

**Windows**:
```powershell
# 使用 Chocolatey
choco install llvm --version=15.0.6
```

### 1.5 NASM 版本过旧

**错误信息**:
```
WARN: NASM version 2.14 is older than recommended 2.16.x
```

**解决方案**:

**Linux**:
```bash
# 下载并安装指定版本
wget https://www.nasm.us/pub/nasm/releasebuilds/2.16.03/nasm-2.16.03.tar.gz
tar -xzf nasm-2.16.03.tar.gz
cd nasm-2.16.03
./configure && make && sudo make install
```

**macOS**:
```bash
# 使用官方下载而不是 brew（brew 安装的是 3.x）
wget https://www.nasm.us/pub/nasm/releasebuilds/2.16.03/macosx/nasm-2.16.03-macosx.zip
unzip nasm-2.16.03-macosx.zip
sudo cp nasm-2.16.03/nasm /usr/local/bin/nasm
```

---

## 环境配置问题

### 2.1 LIBCLANG_PATH 未设置

**错误信息**:
```
WARN: LIBCLANG_PATH not set - some builds may fail
```

**解决方案**:

**Linux**:
```bash
export LIBCLANG_PATH=/usr/lib/llvm-15/lib
```

**macOS**:
```bash
export LIBCLANG_PATH=/usr/local/opt/llvm@15/lib
```

**Windows**:
```powershell
set LIBCLANG_PATH=C:\Program Files\LLVM\bin
```

### 2.2 VCPKG_ROOT 未设置

**错误信息**:
```
WARN: VCPKG_ROOT not set - using default location
```

**解决方案**:
```bash
export VCPKG_ROOT=/path/to/vcpkg
```

### 2.3 权限不足

**错误信息**:
```
Permission denied
```

**解决方案**:
```bash
# 使用 sudo（Linux/macOS）
sudo ./scripts/build/build.sh

# 或者修改文件权限
chmod +x ./scripts/build/*.sh
```

---

## 编译错误

### 3.1 LOG_WARNING 未定义

**错误信息**:
```
error: use of undeclared identifier 'LOG_WARNING'
```

**解决方案**:
```bash
# 此问题已在 hwcodec 中修复
# 确保使用修复后的版本
# cargo update -p hwcodec
```

### 3.2 头文件未找到

**错误信息**:
```
fatal error: 'some_header.h' file not found
```

**解决方案**:
```bash
# 确保 vcpkg 依赖已安装
vcpkg install --triplet x64-windows-static

# 或者设置正确的包含路径
export CFLAGS="-I/path/to/include"
```

### 3.3 类型不匹配

**错误信息**:
```
error: mismatched types
```

**解决方案**:
```bash
# 检查 Rust 版本是否正确
rustc --version

# 清理并重新构建
cargo clean
cargo build
```

---

## 链接错误

### 4.1 库未找到

**错误信息**:
```
error: linking with `cc` failed: exit code: 1
note: /usr/bin/ld: cannot find -lsome_library
```

**解决方案**:
```bash
# 安装缺失的库
sudo apt-get install libsome-library-dev

# 或者设置 LD_LIBRARY_PATH
export LD_LIBRARY_PATH=/path/to/library:$LD_LIBRARY_PATH
```

### 4.2 vdpau 链接错误

**错误信息**:
```
error: cannot find -lvdpau
```

**解决方案**:
```bash
# 安装 vdpau 开发库
sudo apt-get install libvdpau-dev
```

---

## 缓存问题

### 5.1 Cargo 缓存损坏

**错误信息**:
```
error: failed to load source for a dependency
```

**解决方案**:
```bash
# 清理 cargo 缓存
cargo clean

# 更新索引
cargo update

# 如果问题仍然存在，删除整个缓存目录
rm -rf ~/.cargo/registry
rm -rf ~/.cargo/git
```

### 5.2 vcpkg 缓存问题

**错误信息**:
```
error: vcpkg install failed
```

**解决方案**:
```bash
# 清理 vcpkg 缓存
rm -rf $VCPKG_ROOT/installed

# 重新安装依赖
vcpkg install --triplet x64-windows-static
```

### 5.3 GitHub Actions 缓存问题

**错误信息**:
```
Cache restored successfully but build fails
```

**解决方案**:
```bash
# 在 CI 中禁用缓存（临时解决方案）
# 修改 .github/workflows/flutter-build.yml
# 注释掉缓存相关步骤
```

---

## 网络问题

### 6.1 无法连接到 crates.io

**错误信息**:
```
error: failed to download from `https://crates.io/api/v1/crates/...`
```

**解决方案**:
```bash
# 设置代理（如果需要）
export http_proxy=http://proxy:port
export https_proxy=http://proxy:port

# 或者使用国内镜像
echo 'registry = "https://rsproxy.cn/crates.io-index"' > ~/.cargo/config.toml
```

### 6.2 无法连接到 GitHub

**错误信息**:
```
fatal: unable to access 'https://github.com/...': Could not resolve host
```

**解决方案**:
```bash
# 检查网络连接
ping github.com

# 检查 DNS
nslookup github.com

# 使用 SSH 代替 HTTPS（如果配置了 SSH）
git config --global url."git@github.com:".insteadOf "https://github.com/"
```

---

## 平台特定问题

### 7.1 Windows libclang 32/64 位问题

**错误信息**:
```
invalid DLL (32-bit)
```

**解决方案**:
```powershell
# 确保安装的是 64 位 LLVM
# 从官方下载 64 位版本
# https://github.com/llvm/llvm-project/releases/download/llvmorg-15.0.6/LLVM-15.0.6-win64.exe

# 设置正确的路径
Set-Item -Path Env:LIBCLANG_PATH -Value "C:\Program Files\LLVM\bin"
```

### 7.2 macOS NASM 下载失败

**错误信息**:
```
curl: (7) Failed to connect to www.nasm.us port 443
```

**解决方案**:
```bash
# 使用备用下载源
wget https://ftp.sunet.se/mirror/archive/ftp.sunet.se/pub/PC/Unix/nasm/releasebuilds/2.16.03/macosx/nasm-2.16.03-macosx.zip
unzip nasm-2.16.03-macosx.zip
sudo cp nasm-2.16.03/nasm /usr/local/bin/nasm
```

### 7.3 Linux Sciter 构建问题

**错误信息**:
```
error: failed to run custom build command for `sciter-sys`
```

**解决方案**:
```bash
# 安装 Sciter 依赖
sudo apt-get install libgtk-3-dev libwebkit2gtk-4.0-dev
```

---

## 其他问题

### 8.1 构建超时

**错误信息**:
```
Error: The operation was canceled.
```

**解决方案**:
```bash
# 增加超时时间（如果在 CI 中）
# 在 GitHub Actions 中设置 timeout-minutes

# 或者拆分构建步骤
```

### 8.2 内存不足

**错误信息**:
```
error: process didn't exit successfully: ... (signal: 9, SIGKILL: kill)
```

**解决方案**:
```bash
# 减少并行编译数量
cargo build --jobs 1

# 或者增加交换空间
sudo fallocate -l 4G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
```

### 8.3 编码问题

**错误信息**:
```
error: invalid Unicode in source file
```

**解决方案**:
```bash
# 设置正确的编码
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8

# 检查文件编码
file some_file.rs
```

---

## 获取帮助

如果以上解决方案都无法解决您的问题，请按照以下步骤获取帮助：

1. **运行依赖检测**:
   ```bash
   ./scripts/build/check-deps.sh -v
   ```

2. **查看构建日志**:
   ```bash
   ./scripts/build/build.sh -v 2>&1 | tee build.log
   ```

3. **提交 Issue**:
   - 访问: https://github.com/rustdesk/rustdesk/issues
   - 提供以下信息：
     - 操作系统版本
     - Rust 版本 (`rustc --version`)
     - 完整的错误日志
     - 执行的命令
     - 复现步骤

---

## 日志收集

```bash
# 收集完整的构建日志和系统信息
./scripts/build/check-deps.sh -v > deps.log
./scripts/build/build.sh -v 2>&1 | tee build.log

# 打包日志文件
tar -czf build-logs.tar.gz deps.log build.log
```

---

## 更新日志

### v1.0.0 (2024-01-01)
- 初始版本发布
- 包含常见问题及解决方案