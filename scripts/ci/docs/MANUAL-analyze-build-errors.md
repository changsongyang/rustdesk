# analyze-build-errors.sh 使用手册

## 概述

`analyze-build-errors.sh` 是一个用于分析 GitHub Actions 构建错误日志的脚本工具，能够自动提取、分类和汇总构建错误信息，帮助用户快速定位和理解构建失败的原因。

## 适用场景

- CI/CD 构建失败后的错误分析
- 批量分析多个构建的错误模式
- 生成构建错误报告
- 自动化错误分类和统计

## 前置条件

### 系统要求
- **操作系统**: Linux / macOS / Windows (WSL2)
- **Shell**: Bash 4.0+

### 依赖工具
| 工具 | 说明 | 是否必需 |
|------|------|----------|
| GitHub CLI (gh) | 获取构建日志 | 推荐 |
| grep | 文本搜索 | 必需 |
| awk | 文本处理 | 必需 |
| sort | 排序 | 必需 |

## 安装步骤

### 1. 获取脚本
```bash
# 克隆仓库
git clone https://github.com/rustdesk/rustdesk.git
cd rustdesk

# 确保脚本可执行
chmod +x scripts/ci/analyze-build-errors.sh
```

## 参数说明

### 命令行参数

| 参数 | 缩写 | 说明 | 默认值 |
|------|------|------|--------|
| `--help` | `-h` | 显示帮助信息 | - |
| `--repo` | `-r` | 指定仓库 | `changsongyang/rustdesk` |
| `--run` | `-R` | 指定构建运行 ID | 最新失败构建 |
| `--output` | `-o` | 输出文件 | 标准输出 |
| `--top` | `-t` | 显示前 N 个错误 | 10 |

## 使用示例

### 示例 1: 分析最新失败构建
```bash
./scripts/ci/analyze-build-errors.sh
```

**输出示例**:
```
========================================
构建错误分析报告
========================================
构建 ID: 25991888570
仓库: changsongyang/rustdesk
分析时间: 2024-01-01 12:00:00

========================================
错误分类统计
========================================
编译错误: 3
链接错误: 2
依赖错误: 1
配置错误: 1

========================================
前 10 个最常见错误
========================================
1. LOG_WARNING 未定义 (出现 2 次)
2. 找不到 libvdpau (出现 1 次)
3. 类型不匹配 (出现 1 次)

========================================
错误详情
========================================
[编译错误] LOG_WARNING 未定义
  - 文件: cpp/common/platform/linux/linux.cpp:127
  - 建议: 将 LOG_WARNING 替换为 LOG_WARN
```

### 示例 2: 分析指定构建
```bash
./scripts/ci/analyze-build-errors.sh -R 25991888570
```

### 示例 3: 输出到文件
```bash
./scripts/ci/analyze-build-errors.sh -o build_errors.txt
```

### 示例 4: 显示更多错误
```bash
./scripts/ci/analyze-build-errors.sh -t 20
```

## 错误分类

### 编译错误
- 语法错误
- 类型不匹配
- 未定义标识符
- 头文件未找到

### 链接错误
- 库未找到
- 符号未定义
- 链接器错误

### 依赖错误
- 依赖缺失
- 版本不兼容
- 下载失败

### 配置错误
- 环境变量未设置
- 路径配置错误
- 权限不足

### 网络错误
- 连接超时
- DNS 解析失败
- 证书错误

## 常见问题

### 问题 1: 无法获取构建日志

**错误信息**:
```
error: Failed to get build logs
```

**解决方案**:
```bash
# 确保已登录 GitHub CLI
gh auth login

# 检查构建 ID 是否正确
gh run list --repo changsongyang/rustdesk
```

### 问题 2: 权限不足

**错误信息**:
```
error: Resource not accessible by integration
```

**解决方案**:
```bash
# 确保令牌有 workflow 权限
gh auth refresh -h
```

## 更新日志

### v1.0.0 (2024-01-01)
- 初始版本发布
- 支持错误分类统计
- 支持生成错误报告