# validate-build.sh 使用手册

## 概述

`validate-build.sh` 是一个构建验证脚本，用于验证 rustdesk 项目构建产物的完整性和正确性。该脚本提供了多种验证方式，确保构建产物符合预期标准。

## 适用场景

- 构建完成后的产物验证
- CI/CD 流程中的质量检查
- 发布前的完整性验证
- 构建问题排查

## 前置条件

### 系统要求
- **操作系统**: Linux / macOS / Windows (WSL2)
- **Shell**: Bash 4.0+

### 依赖工具
| 工具 | 说明 |
|------|------|
| stat | 文件信息查看 |
| find | 文件查找 |
| ls | 目录列表 |

## 安装步骤

### 1. 获取脚本
```bash
# 克隆仓库
git clone https://github.com/rustdesk/rustdesk.git
cd rustdesk

# 确保脚本可执行
chmod +x scripts/build/validate-build.sh
```

## 参数说明

### 命令行参数

| 参数 | 缩写 | 说明 | 默认值 |
|------|------|------|--------|
| `--help` | `-h` | 显示帮助信息 | - |
| `--verbose` | `-v` | 启用详细输出模式 | 禁用 |
| `--target` | `-t` | 目标平台 | 当前平台 |

### 位置参数

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `build_directory` | 构建产物目录 | `./target` |

### 环境变量

| 变量 | 说明 | 是否必需 |
|------|------|----------|
| `BUILD_DIR` | 构建目录路径 | 可选 |

## 使用示例

### 示例 1: 基本使用
```bash
./scripts/build/validate-build.sh
```

**输出示例**:
```
[2024-01-01 12:00:00] [INFO]    Starting build validation...
-----------------------------------------------------
[2024-01-01 12:00:01] [INFO]    Validating build directory: ./target
[2024-01-01 12:00:01] [SUCCESS] Build directory validation passed
[2024-01-01 12:00:01] [INFO]    Validating Rust binaries for target: x86_64-unknown-linux-gnu
[2024-01-01 12:00:01] [INFO]    Found rustdesk (executable): ./target/x86_64-unknown-linux-gnu/release/rustdesk
[2024-01-01 12:00:01] [SUCCESS] rustdesk is executable
-----------------------------------------------------
[2024-01-01 12:00:02] [SUCCESS] Build validation completed successfully
```

### 示例 2: 指定构建目录
```bash
./scripts/build/validate-build.sh ./build/output
```

### 示例 3: 指定目标平台
```bash
./scripts/build/validate-build.sh -t aarch64-linux-android
```

### 示例 4: 详细输出模式
```bash
./scripts/build/validate-build.sh -v ./target
```

### 示例 5: 在 CI/CD 中使用
```bash
# GitHub Actions 示例
- name: Validate build
  run: |
    ./scripts/build/validate-build.sh ./target
  env:
    BUILD_DIR: ./target
```

## 验证项说明

### 目录验证

| 验证项 | 说明 |
|--------|------|
| 目录存在 | 验证构建目录是否存在 |
| 目录可读 | 验证构建目录是否可读 |

### 二进制文件验证

| 验证项 | 说明 |
|--------|------|
| 文件存在 | 验证二进制文件是否存在 |
| 可执行权限 | 验证可执行文件权限 |
| 文件大小 | 验证文件大小是否合理 |

### 构建产物类型

| 类型 | 扩展名 | 说明 |
|------|--------|------|
| 可执行文件 | 无扩展名（Linux/macOS） | 主程序 |
| 动态库 | .so（Linux） | 共享库 |
| 动态库 | .dylib（macOS） | 动态库 |
| 动态库 | .dll（Windows） | 动态链接库 |

### 验证报告

脚本会生成验证报告文件 `build_validation_report.txt`，包含以下内容：
- 验证时间和构建目录
- 目录结构列表
- 文件大小信息
- 构建产物摘要

## 常见问题

### 问题 1: 构建目录不存在

**错误信息**:
```
ERROR: Build directory not found: ./target
```

**解决方案**:
```bash
# 先执行构建
./scripts/build/build.sh -r

# 或者指定正确的构建目录
./scripts/build/validate-build.sh /path/to/build
```

### 问题 2: 二进制文件不存在

**警告信息**:
```
WARN: rustdesk not found: ./target/release/rustdesk
```

**解决方案**:
```bash
# 确保构建已完成
./scripts/build/build.sh -r

# 检查构建日志
./scripts/build/build.sh -r 2>&1 | tee build.log
```

### 问题 3: 权限不足

**错误信息**:
```
ERROR: Build directory not readable: ./target
```

**解决方案**:
```bash
# 修改目录权限
chmod -R +r ./target

# 或者使用 sudo
sudo ./scripts/build/validate-build.sh
```

### 问题 4: 二进制文件不可执行

**警告信息**:
```
WARN: Executable not marked as executable: ./target/release/rustdesk
```

**解决方案**:
```bash
# 添加可执行权限
chmod +x ./target/release/rustdesk
```

### 问题 5: 文件大小异常

**警告信息**:
```
WARN: rustdesk is smaller than expected: 0 MB < 1 MB
```

**解决方案**:
```bash
# 检查构建是否成功
./scripts/build/build.sh -r

# 查看文件大小
ls -lh ./target/release/rustdesk
```

## 退出码

| 退出码 | 含义 |
|--------|------|
| 0 | 验证通过 |
| 1 | 验证失败 |
| 5 | 配置错误 |

## 更新日志

### v1.0.0 (2024-01-01)
- 初始版本发布
- 支持构建目录验证
- 支持二进制文件验证
- 支持生成验证报告