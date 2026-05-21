# build.sh 使用手册

## 概述

`build.sh` 是 rustdesk 项目的主构建脚本，负责执行完整的项目构建流程。该脚本提供了统一的构建入口，支持多种构建配置选项。

## 适用场景

- 本地开发构建
- CI/CD 自动化构建
- 跨平台构建
- Release 版本打包

## 前置条件

### 系统要求
- **操作系统**: Linux / macOS / Windows (WSL2)
- **Shell**: Bash 4.0+

### 依赖工具
| 工具 | 最低版本 | 说明 |
|------|----------|------|
| Rust | 1.81.0 | 编程语言 |
| Cargo | 1.81.0 | Rust 包管理器 |
| Flutter | 3.24.5 | UI 框架 |
| Git | 2.0+ | 版本控制 |

### 环境变量
| 变量 | 说明 | 是否必需 |
|------|------|----------|
| `VCPKG_ROOT` | vcpkg 安装路径 | 推荐 |
| `LIBCLANG_PATH` | LLVM 库路径 | 推荐 |

## 安装步骤

### 1. 获取脚本
```bash
# 克隆仓库
git clone https://github.com/rustdesk/rustdesk.git
cd rustdesk

# 确保脚本可执行
chmod +x scripts/build/build.sh
```

### 2. 配置环境
```bash
# 设置 vcpkg 路径（可选）
export VCPKG_ROOT=/path/to/vcpkg

# 设置 LLVM 路径（可选）
export LIBCLANG_PATH=/usr/lib/llvm-15/lib
```

## 参数说明

### 命令行参数

| 参数 | 缩写 | 说明 | 默认值 |
|------|------|------|--------|
| `--help` | `-h` | 显示帮助信息 | - |
| `--verbose` | `-v` | 启用详细输出 | 禁用 |
| `--release` | `-r` | Release 模式构建 | Debug |
| `--target` | `-t` | 目标平台 | 当前平台 |
| `--build-dir` | `-d` | 构建输出目录 | `./target` |
| `--skip-cleanup` | `-s` | 跳过构建后清理 | 启用清理 |

### 目标平台格式

| 平台 | 目标标识 |
|------|----------|
| Linux x64 | `x86_64-unknown-linux-gnu` |
| Linux ARM64 | `aarch64-unknown-linux-gnu` |
| macOS x64 | `x86_64-apple-darwin` |
| macOS ARM64 | `aarch64-apple-darwin` |
| Windows x64 | `x86_64-pc-windows-msvc` |
| Windows x86 | `i686-pc-windows-msvc` |
| Android ARM64 | `aarch64-linux-android` |

## 使用示例

### 示例 1: 基本构建（Debug 模式）
```bash
./scripts/build/build.sh
```

### 示例 2: Release 模式构建
```bash
./scripts/build/build.sh -r
```

### 示例 3: 指定目标平台
```bash
# Linux x64 Release 构建
./scripts/build/build.sh -r -t x86_64-unknown-linux-gnu

# Android ARM64 构建
./scripts/build/build.sh -r -t aarch64-linux-android
```

### 示例 4: 指定构建目录
```bash
./scripts/build/build.sh -r -d ./build/output
```

### 示例 5: 详细输出模式
```bash
./scripts/build/build.sh -v -r
```

### 示例 6: 在 CI/CD 中使用
```bash
# GitHub Actions 示例
- name: Build
  run: |
    ./scripts/build/build.sh -r -t ${{ matrix.target }}
  env:
    VCPKG_ROOT: /opt/vcpkg
    LIBCLANG_PATH: /usr/lib/llvm-15/lib
```

## 常见问题

### 问题 1: 构建失败 - 依赖缺失

**错误信息**:
```
ERROR: Dependency check failed
```

**解决方案**:
```bash
# 运行依赖检测脚本
./scripts/build/check-deps.sh

# 根据提示安装缺失的依赖
```

### 问题 2: Rust 版本不满足要求

**错误信息**:
```
ERROR: Rust version 1.70.0 is too old. Required: 1.81.0
```

**解决方案**:
```bash
rustup update
rustup default 1.81.0
```

### 问题 3: 内存不足

**错误信息**:
```
error: process didn't exit successfully: ... (signal: 9, SIGKILL: kill)
```

**解决方案**:
```bash
# 减少并行编译数量
./scripts/build/build.sh -r --jobs 1

# 或者增加交换空间
sudo fallocate -l 4G /swapfile
sudo swapon /swapfile
```

### 问题 4: 链接错误

**错误信息**:
```
error: linking with `cc` failed: exit code: 1
```

**解决方案**:
```bash
# 确保已安装必要的系统库
sudo apt-get install build-essential libssl-dev
```

### 问题 5: Flutter 构建失败

**错误信息**:
```
Error: No pubspec.yaml file found
```

**解决方案**:
```bash
# 确保在项目根目录运行
cd /path/to/rustdesk
./scripts/build/build.sh
```

## 工作流程

```
┌─────────────────────────────────────────────────────────┐
│                    build.sh 执行流程                     │
├─────────────────────────────────────────────────────────┤
│  1. 依赖检测                                            │
│     └── check-deps.sh                                   │
│                                                         │
│  2. 环境设置                                            │
│     ├── 创建构建目录                                     │
│     └── 创建构建快照                                     │
│                                                         │
│  3. Rust 组件构建                                       │
│     └── cargo build [--release] [--target]              │
│                                                         │
│  4. Flutter 组件构建                                    │
│     └── flutter build [linux|macos|windows]            │
│                                                         │
│  5. 构建验证                                            │
│     └── validate-build.sh                               │
│                                                         │
│  6. 清理                                                 │
│     └── 清理临时文件                                     │
└─────────────────────────────────────────────────────────┘
```

## 退出码

| 退出码 | 含义 |
|--------|------|
| 0 | 构建成功 |
| 1 | 通用错误 |
| 2 | 参数错误 |
| 3 | 依赖缺失 |
| 4 | 版本不兼容 |

## 更新日志

### v1.0.0 (2024-01-01)
- 初始版本发布
- 支持 Debug/Release 模式
- 支持跨平台构建
- 集成依赖检测
- 集成构建验证