# 构建脚本规范指南

## 1. 脚本语言选择

### 1.1 首选语言
- **Linux/macOS**: Bash (version 4.0+)
- **Windows**: PowerShell (version 7.0+)

### 1.2 跨平台兼容
- 对于需要跨平台运行的脚本，优先使用 Bash + WSL 或 PowerShell Core
- 避免使用平台特定的命令而不加兼容处理

## 2. 文件命名规范

### 2.1 脚本文件
- 使用小写字母和连字符
- 后缀: `.sh` (Bash), `.ps1` (PowerShell)
- 示例: `build-check-deps.sh`, `validate-environment.ps1`

### 2.2 目录结构
```
scripts/
├── build/          # 构建相关脚本
├── ci/             # CI/CD 专用脚本
├── utils/          # 工具函数库
├── tests/          # 测试脚本
└── README.md       # 脚本说明文档
```

## 3. 编码风格

### 3.1 Bash 脚本规范

#### 3.1.1 头部注释
```bash
#!/usr/bin/env bash
#
# Script Name: build-check-deps.sh
# Description: Check build dependencies and versions
# Version: 1.0.0
# Author: Build Team
# Date: 2024-01-01
# Usage: ./build-check-deps.sh [options]
```

#### 3.1.2 变量命名
- 使用大写字母和下划线
- 局部变量使用小写字母和下划线
```bash
# 全局变量
readonly RUST_VERSION="1.81.0"
readonly FLUTTER_VERSION="3.24.5"

# 局部变量
local dep_version=$(get_version "rustc")
```

#### 3.1.3 函数命名
- 使用小写字母和下划线
- 动词开头
```bash
check_rust_version() {
    # 检查 Rust 版本
}

validate_environment() {
    # 验证环境配置
}
```

#### 3.1.4 错误处理
```bash
set -euo pipefail

error_exit() {
    echo "ERROR: $1" >&2
    exit 1
}

# 使用示例
[[ -z "$RUSTC" ]] && error_exit "rustc not found in PATH"
```

### 3.2 PowerShell 脚本规范

#### 3.2.1 头部注释
```powershell
<#
.SYNOPSIS
    Check build dependencies and versions

.DESCRIPTION
    Validates required tools and their versions for building rustdesk

.PARAMETER verbose
    Enable verbose output

.EXAMPLE
    .\build-check-deps.ps1 -verbose
#>
```

#### 3.2.2 变量命名
- 使用 PascalCase 格式
```powershell
$RustVersion = "1.81.0"
$FlutterVersion = "3.24.5"
```

#### 3.2.3 函数命名
- 使用 PascalCase 格式
```powershell
function Check-RustVersion {
    # 检查 Rust 版本
}

function Validate-Environment {
    # 验证环境配置
}
```

## 4. 日志输出规范

### 4.1 日志级别
```bash
# Bash
log_debug()   { echo "[DEBUG]   $1"; }
log_info()    { echo "[INFO]    $1"; }
log_warn()    { echo "[WARN]    $1" >&2; }
log_error()   { echo "[ERROR]   $1" >&2; }
```

### 4.2 日志格式
```
[LEVEL]    Timestamp - Message
[INFO]     2024-01-01 12:00:00 - Checking Rust version...
[WARN]     2024-01-01 12:00:01 - Old version detected
[ERROR]    2024-01-01 12:00:02 - Version mismatch
```

## 5. 错误处理规范

### 5.1 错误码体系
| 错误码 | 含义 |
|--------|------|
| 0 | 成功 |
| 1 | 通用错误 |
| 2 | 参数错误 |
| 3 | 依赖缺失 |
| 4 | 版本不兼容 |
| 5 | 配置错误 |
| 6 | 网络错误 |
| 7 | 权限错误 |

### 5.2 错误处理模式
```bash
# 检查命令执行结果
if ! cargo build; then
    log_error "Build failed"
    cleanup
    exit 1
fi

# 使用 trap 捕获信号
trap 'cleanup; exit 1' INT TERM ERR
```

## 6. 参数处理规范

### 6.1 参数解析
```bash
# Bash - 使用 getopt
while getopts "hv" opt; do
    case $opt in
        h) show_help; exit 0 ;;
        v) VERBOSE=1 ;;
        \?) error_exit "Invalid option: -$OPTARG" ;;
    esac
done
```

## 7. 安全性规范

### 7.1 路径处理
```bash
# 使用 realpath 确保路径安全
SCRIPT_DIR=$(realpath "$(dirname "${BASH_SOURCE[0]}")")

# 避免路径注入
[[ "$INPUT_PATH" =~ ^/safe/path/ ]] || error_exit "Invalid path"
```

### 7.2 命令注入防护
```bash
# 使用引号保护变量
echo "$USER_INPUT"

# 验证输入
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || error_exit "Invalid version format"
```

## 8. 最佳实践

### 8.1 可维护性
- 脚本长度控制在 500 行以内
- 复杂逻辑拆分为多个函数
- 添加必要的注释说明

### 8.2 可测试性
- 函数设计为可独立测试
- 使用环境变量进行配置
- 提供详细的错误信息

### 8.3 性能优化
- 避免不必要的子进程创建
- 使用管道时注意性能影响
- 缓存重复计算的结果