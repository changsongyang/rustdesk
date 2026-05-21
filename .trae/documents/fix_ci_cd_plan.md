# RustDesk CI/CD 构建失败修复计划

## 问题分析

通过分析项目的 GitHub Actions 工作流，发现了以下潜在问题：

### 1. Rust 版本不一致
- `flutter-build.yml`: 使用多个版本 (1.75, 1.81)
- `ci.yml`: 使用 1.78.0
- `bridge.yml`: 使用 1.75
- 不同工作流之间版本不一致可能导致兼容性问题

### 2. 缓存问题
- 多个工作流禁用了 `rust-cache` 和 `vcpkg` 缓存
- 缓存键可能需要优化
- 这会导致构建时间过长

### 3. Action 版本过时
- 使用了 `actions/checkout@v4` (这是好的)
- 但其他一些action可能需要更新
- `subosito/flutter-action` 在某些地方固定版本

### 4. vcpkg 配置
- `vcpkg.json` 中的 baseline 与 CI 中使用的 `VCPKG_COMMIT_ID` 一致
- 但某些依赖版本可能需要更新

### 5. 依赖问题
- `flutter_rust_bridge` 版本固定在 1.80.1
- 一些 git 依赖可能需要更新

## 修复方案

### 阶段 1: 统一 Rust 版本
- **文件**: `.github/workflows/flutter-build.yml`
- **修改**: 统一使用 Rust 1.75 作为主要版本 (与 sciter 兼容)
- **原因**: 注释中提到 1.78+ 存在 ABI 变更导致 sciter 问题

### 阶段 2: 优化缓存策略
- **文件**: `.github/workflows/flutter-build.yml`
- **修改**:
  - 重新启用 `Swatinem/rust-cache@v2`
  - 优化缓存键以提高命中率
  - 重新启用 vcpkg 二进制缓存
- **原因**: 禁用缓存导致构建时间过长，容易超时

### 阶段 3: 更新 GitHub Actions
- **文件**: 所有 `.github/workflows/*.yml`
- **修改**:
  - 检查并更新所有 actions 到最新稳定版本
  - 使用 `actions/cache@v4` 替换旧版本
  - 更新 `lukka/run-vcpkg` 到最新版本
- **原因**: 旧版本可能存在 bug 和兼容性问题

### 阶段 4: 优化 vcpkg 配置
- **文件**: `vcpkg.json`
- **修改**: 检查并验证依赖版本
- **验证**: 确保 baseline 与 CI 中的 VCPKG_COMMIT_ID 一致

### 阶段 5: 修复构建脚本
- **文件**: `build.py`
- **修改**: 添加更好的错误处理和日志
- **改进**: 添加更详细的进度输出

### 阶段 6: 优化超时设置
- **文件**: `.github/workflows/flutter-build.yml`
- **修改**: 
  - Windows 构建超时从 180 分钟保持不变
  - 其他平台根据需要调整
- **原因**: 确保构建有足够时间完成

## 需要修改的文件清单

1. `.github/workflows/flutter-build.yml` - 主要构建工作流
2. `.github/workflows/ci.yml` - 基础 CI 工作流
3. `.github/workflows/bridge.yml` - Bridge 生成工作流
4. `.github/workflows/flutter-ci.yml` - Flutter CI 工作流
5. `vcpkg.json` - vcpkg 依赖配置
6. (可选) `build.py` - 构建脚本优化

## 风险评估

- **低风险**: 更新 action 版本和优化缓存
- **中风险**: 调整 Rust 版本（需要确保兼容性）
- **高风险**: 修改 vcpkg 依赖版本（可能破坏现有构建）

## 验证方法

1. 重新运行 CI/CD 工作流
2. 检查所有平台的构建状态
3. 验证构建产物的完整性
4. 测试基本功能
