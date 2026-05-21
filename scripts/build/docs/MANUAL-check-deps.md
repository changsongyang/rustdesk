# check-deps.sh 使用手册

## 概述

`check-deps.sh` 是一个依赖检测脚本，用于检查 rustdesk 项目构建所需的所有依赖工具及其版本是否满足要求。该脚本提供了详细的依赖状态报告，帮助用户快速定位缺失或版本不兼容的依赖。

## 适用场景

- 构建前的依赖检查
- CI/CD 环境验证
- 新开发环境配置验证
- 构建失败时的问题排查

## 前置条件

### 系统要求
- **操作系统**: Linux / macOS / Windows (WSL2)
- **Shell**: Bash 4.0+

### 无需额外依赖
该脚本本身不依赖任何外部工具，可直接运行。

## 安装步骤

### 1. 获取脚本
```bash
# 克隆仓库
git clone https://github.com/rustdesk/rustdesk.git
cd rustdesk

# 确保脚本可执行
chmod +x scripts/build/check-deps.sh
```

## 参数说明

### 命令行参数

| 参数 | 缩写 | 说明 | 默认值 |
|------|------|------|--------|
| `--help` | `-h` | 显示帮助信息 | - |
| `--verbose` | `-v` | 启用详细输出模式 | 禁用 |

### 环境变量

| 变量 | 说明 | 是否必需 |
|------|------|----------|
| `VERBOSE` | 设置为 1 启用详细输出 | 可选 |

## 使用示例

### 示例 1: 基本使用
```bash
./scripts/build/check-deps.sh
```

**输出示例**:
```
[2024-01-01 12:00:00] [INFO]    Starting build dependency check...
-----------------------------------------------------
[2024-01-01 12:00:01] [INFO]    Checking Git...
[2024-01-01 12:00:01] [INFO]    Found Git version: 2.38.0
[2024-01-01 12:00:01] [SUCCESS] Git check passed
[2024-01-01 12:00:01] [INFO]    Checking Rust version...
[2024-01-01 12:00:01] [INFO]    Found Rust version: 1.81.0
[2024-01-01 12:00:01] [INFO]    Required Rust version: 1.81.0
[2024-01-01 12:00:01] [SUCCESS] Rust version check passed
-----------------------------------------------------
[2024-01-01 12:00:02] [SUCCESS] All dependency checks completed successfully
```

### 示例 2: 详细输出模式
```bash
./scripts/build/check-deps.sh -v
```

### 示例 3: 在 CI/CD 中使用
```bash
# GitHub Actions 示例
- name: Check dependencies
  run: |
    ./scripts/build/check-deps.sh
  continue-on-error: false
```

### 示例 4: 结合构建脚本使用
```bash
# 检查依赖后执行构建
if ./scripts/build/check-deps.sh; then
    ./scripts/build/build.sh -r
else
    echo "Dependency check failed"
    exit 1
fi
```

## 检测项说明

### 必需依赖

| 依赖 | 最低版本 | 说明 |
|------|----------|------|
| Git | 2.0+ | 版本控制 |
| Rust (rustc) | 1.81.0 | 编程语言 |
| Cargo | 1.81.0 | Rust 包管理器 |

### 推荐依赖

| 依赖 | 版本要求 | 说明 |
|------|----------|------|
| Flutter | 3.24.5+ | UI 框架 |
| LLVM/clang | 15.0.6+ | 编译器 |
| vcpkg | - | C++ 依赖管理器 |
| NASM | 2.16+ | 汇编器 |
| YASM | - | 汇编器 |

### 环境变量检测

| 变量 | 说明 |
|------|------|
| `VCPKG_ROOT` | vcpkg 安装路径 |
| `LIBCLANG_PATH` | LLVM 库路径 |

### 网络连接检测

| 主机 | 说明 |
|------|------|
| github.com | GitHub 服务 |
| crates.io | Rust 包仓库 |
| pub.dev | Dart/Flutter 包仓库 |

## 常见问题

### 问题 1: Rust 未安装

**错误信息**:
```
ERROR: Rust compiler not found. Please install Rust from https://www.rust-lang.org/tools/install
```

**解决方案**:
```bash
# 安装 Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# 重启终端或执行
source "$HOME/.cargo/env"
```

### 问题 2: Rust 版本过旧

**错误信息**:
```
ERROR: Rust version 1.70.0 is too old. Required: 1.81.0
```

**解决方案**:
```bash
rustup update
rustup default 1.81.0
```

### 问题 3: Flutter 未安装

**警告信息**:
```
WARN: Flutter not found - skipping Flutter version check
```

**解决方案**:
```bash
# 参考官方安装指南
# https://docs.flutter.dev/get-started/install
```

### 问题 4: LIBCLANG_PATH 未设置

**警告信息**:
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

### 问题 5: 网络连接失败

**警告信息**:
```
WARN: Network access issues detected for: github.com
```

**解决方案**:
```bash
# 检查网络连接
ping github.com

# 如果需要，设置代理
export http_proxy=http://proxy:port
export https_proxy=http://proxy:port
```

## 退出码

| 退出码 | 含义 |
|--------|------|
| 0 | 所有依赖检查通过 |
| 3 | 必需依赖缺失 |
| 4 | 依赖版本不兼容 |

## 更新日志

### v1.0.0 (2024-01-01)
- 初始版本发布
- 支持 Rust、Cargo、Flutter 版本检测
- 支持环境变量检测
- 支持网络连接检测
- 提供详细的检测报告