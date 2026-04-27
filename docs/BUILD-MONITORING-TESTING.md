# 构建监控和测试文档

本文档介绍 RustDesk 项目的构建监控系统、自动化测试流程和构建性能优化策略。

## 1. 构建监控系统

### 1.1 系统概述

构建监控系统用于收集和分析构建过程中的各种指标，包括：
- 构建时间
- 构建成功率
- 错误信息分析
- 构建性能趋势

### 1.2 监控工具

#### 1.2.1 构建监控脚本

**文件**: `scripts/build-monitor.sh`

**功能**:
- 记录构建开始和结束时间
- 捕获构建输出和错误信息
- 更新构建统计数据
- 生成构建报告

**使用方法**:

```bash
# 基本用法
./scripts/build-monitor.sh <构建命令>

# 示例：监控 Flutter 构建
./scripts/build-monitor.sh ./build.py --flutter

# 示例：监控 Rust 构建
./scripts/build-monitor.sh cargo build --release
```

#### 1.2.2 构建分析工具

**文件**: `scripts/build-analyzer.py`

**功能**:
- 分析构建监控数据
- 生成详细的 HTML 报告
- 生成构建时间趋势图
- 生成构建状态分布图

**使用方法**:

```bash
# 生成构建报告
python3 scripts/build-analyzer.py

# 查看生成的报告
ls -la .build-reports/
```

#### 1.2.3 监控配置

**文件**: `scripts/build-monitor-config.json`

**配置选项**:
- `monitor_dir`: 监控数据存储目录
- `retention_days`: 数据保留天数
- `thresholds`: 构建时间和成功率阈值
- `notifications`: 通知配置

### 1.3 监控数据

监控系统会在 `.build-monitor` 目录中生成以下文件：
- `build.log`: 构建日志
- `build-stats.json`: 构建统计数据
- `errors.json`: 错误信息

## 2. 自动化测试流程

### 2.1 测试类型

项目支持三种类型的测试：
- **单元测试**: 测试单个组件和功能
- **集成测试**: 测试组件之间的交互
- **端到端测试**: 测试完整的构建流程

### 2.2 测试工具

#### 2.2.1 测试运行器

**文件**: `scripts/test-runner.sh`

**功能**:
- 运行单元测试、集成测试和端到端测试
- 收集测试结果
- 生成测试报告

**使用方法**:

```bash
# 运行所有测试
./scripts/test-runner.sh

# 查看测试报告
cat .tests/test-report.json
```

#### 2.2.2 单元测试

**Rust 单元测试**:
- 文件: `tests/unit/test_rust.rs`
- 运行: `cargo test --lib --all-targets`

**Flutter 单元测试**:
- 文件: `flutter/test/test_flutter.dart`
- 运行: `cd flutter && flutter test`

#### 2.2.3 集成测试

**文件**: `tests/integration/test_integration.sh`

**测试内容**:
- 检查构建脚本是否存在
- 检查依赖配置文件
- 检查 Cargo.toml 配置
- 检查 Flutter 配置
- 检查环境变量配置

#### 2.2.4 端到端测试

**文件**: `tests/e2e/test_e2e.sh`

**测试内容**:
- 测试构建脚本执行
- 测试 Flutter 依赖获取
- 测试 Rust 依赖检查
- 测试 vcpkg 依赖安装
- 测试代码格式检查

## 3. 构建性能优化

### 3.1 优化工具

**文件**: `scripts/build-optimizer.sh`

**功能**:
- 配置 Cargo 并行构建
- 优化 Cargo 缓存
- 配置 vcpkg 缓存
- 优化 Flutter 缓存
- 配置 Git 缓存
- 清理旧的构建文件
- 配置构建环境变量

**使用方法**:

```bash
# 运行构建性能优化
./scripts/build-optimizer.sh

# 查看优化日志
cat .build-optimization.log
```

### 3.2 优化策略

#### 3.2.1 并行构建

- 根据 CPU 核心数配置 Cargo 并行度
- 启用 Flutter 并行构建

#### 3.2.2 缓存策略

- 启用 Cargo 增量编译
- 配置 vcpkg 二进制缓存
- 启用 Flutter 缓存
- 配置 Git 缓存

#### 3.2.3 网络优化

- 配置 Cargo 网络重试
- 配置 vcpkg 网络超时
- 配置 Git 网络参数

#### 3.2.4 构建环境

- 配置编译器优化选项
- 配置链接器内存使用
- 配置 CCACHE 缓存

## 4. CI/CD 集成

### 4.1 GitHub Actions 配置

**文件**: `.github/workflows/playground.yml`

**集成步骤**:
1. 优化构建性能
2. 运行自动化测试
3. 使用构建监控执行构建
4. 生成构建分析报告

### 4.2 CI 构建流程

1. **准备环境**: 安装依赖和工具
2. **优化性能**: 运行构建性能优化脚本
3. **运行测试**: 执行自动化测试流程
4. **执行构建**: 使用构建监控执行构建
5. **生成报告**: 生成构建分析报告
6. **发布产物**: 发布构建产物

## 5. 最佳实践

### 5.1 构建监控最佳实践

- 定期运行构建分析工具，了解构建性能趋势
- 设置构建时间和成功率阈值，及时发现问题
- 分析错误信息，持续改进构建流程

### 5.2 测试最佳实践

- 为关键功能编写单元测试
- 定期运行集成测试，确保组件交互正常
- 在 CI 中执行完整的测试流程
- 保持测试代码与生产代码同步更新

### 5.3 性能优化最佳实践

- 定期运行构建性能优化脚本
- 监控构建时间变化，及时发现性能退化
- 合理配置缓存策略，平衡缓存大小和构建速度
- 根据项目规模和硬件配置调整并行度

## 6. 常见问题和解决方案

### 6.1 构建监控问题

**问题**: 构建监控脚本执行失败
**解决方案**: 检查脚本权限，确保可执行：`chmod +x scripts/build-monitor.sh`

**问题**: 构建分析报告生成失败
**解决方案**: 确保安装了必要的依赖：`pip install matplotlib pandas jq`

### 6.2 测试问题

**问题**: Flutter 测试失败
**解决方案**: 确保 Flutter 依赖已安装：`cd flutter && flutter pub get`

**问题**: Rust 测试失败
**解决方案**: 检查 Rust 依赖：`cargo check --all`

### 6.3 性能优化问题

**问题**: 构建速度没有明显提升
**解决方案**: 检查缓存配置，确保缓存目录有足够空间

**问题**: 并行构建导致内存不足
**解决方案**: 减少并行度，根据系统内存调整 `.cargo/config.toml` 中的 `jobs` 值

## 7. 总结

构建监控和测试系统是保证 RustDesk 项目质量和稳定性的重要组成部分。通过本文档介绍的工具和方法，您可以：

- 实时监控构建过程和性能
- 自动化执行测试流程，确保代码质量
- 优化构建性能，提高开发效率
- 集成监控和测试到 CI/CD 流程中，实现持续集成

定期使用这些工具和方法，将有助于提高项目的可靠性和开发效率。