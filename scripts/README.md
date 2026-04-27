# RustDesk 构建优化工具

本目录包含 RustDesk 项目的构建优化工具和脚本，用于解决当前 CI/CD 和本地构建中的问题。

## 问题分析

### 已发现的问题

1. **vcpkg 依赖版本问题**
   - `libjpeg-turbo` 版本在 vcpkg 数据库中不存在
   - 解决方案：将版本从 `3.1.4.1` 降级到 `3.1.0`

2. **Cargo.lock 版本兼容性**
   - Cargo.lock 使用了需要 Rust 2024 的版本 4 格式
   - 解决方案：删除 Cargo.lock，让 CI 自动重新生成

3. **run-on-arch-action 中 cargo 未找到**
   - 问题：install 和 run 阶段是独立的 shell 会话
   - 解决方案：在每个 run 阶段开始时添加 `export PATH="$HOME/.cargo/bin:$PATH"`

4. **错误处理不完善**
   - 缺少详细的日志输出
   - 缺少环境诊断工具
   - 缺少回滚机制

## 工具介绍

### 1. build_helper.py - 构建辅助工具

功能：
- 环境检查（Rust、vcpkg、Flutter、网络）
- 构建诊断报告生成
- Cargo 配置优化

使用方法：
```bash
# 完整诊断
python3 scripts/build_helper.py --diagnose

# 单独检查
python3 scripts/build_helper.py --check-rust
python3 scripts/build_helper.py --check-vcpkg
python3 scripts/build_helper.py --check-flutter
python3 scripts/build_helper.py --check-network

# 优化配置
python3 scripts/build_helper.py --optimize
```

### 2. setup-local-env.sh - 本地环境设置脚本

功能：
- 自动安装 Rust
- 配置环境变量
- 验证环境一致性

使用方法：
```bash
# 检查环境
bash scripts/setup-local-env.sh --check-only

# 检查并安装 Rust
bash scripts/setup-local-env.sh --install-rust

# 显示帮助
bash scripts/setup-local-env.sh --help
```

### 3. enhanced_build.py - 增强版构建脚本

功能：
- 完整的错误处理
- 详细的日志输出
- 构建时间统计
- 环境预检查

使用方法：
```bash
# 检查环境
python3 scripts/enhanced_build.py --check

# 构建
python3 scripts/enhanced_build.py --features hwcodec,flutter

# 查看帮助
python3 scripts/enhanced_build.py --help
```

## CI/CD 优化

### playground.yml 优化要点

1. **工具链版本**：确保使用 Rust 1.95
2. **缓存策略**：优化 Cargo、Flutter、vcpkg 缓存
3. **错误处理**：添加详细的失败诊断输出

### flutter-build.yml 优化要点

1. **PATH 一致性**：在每个 run 阶段显式设置 PATH
2. **资源限制**：aarch64 构建时减少并行度和内存使用
3. **工具链安装**：使用 rustup 而不是直接下载，提高兼容性

## 使用流程

### 本地开发

1. **环境设置**
```bash
bash scripts/setup-local-env.sh --install-rust
source ~/.cargo/env
```

2. **环境诊断**
```bash
python3 scripts/build_helper.py --diagnose
```

3. **构建项目**
```bash
# 使用增强工具
python3 scripts/enhanced_build.py --release

# 或使用原始脚本
python3 build.py --flutter --hwcodec
```

### CI/CD 工作流

所有优化已应用到 `.github/workflows/` 下的工作流文件：

1. `playground.yml` - 主要开发 CI
2. `flutter-build.yml` - 跨平台 Flutter 构建

主要修复：
- ✅ libjpeg-turbo 版本（3.1.0）
- ✅ 删除 Cargo.lock（自动重新生成）
- ✅ run-on-arch-action PATH 设置
- ✅ rustup 工具链安装优化
- ✅ aarch64 内存使用优化

## 常见问题

### Q: 构建时提示 "cargo: command not found"
**A:** 确保在每个新的 shell 会话中运行 `source ~/.cargo/env`，或在脚本中添加 `export PATH="$HOME/.cargo/bin:$PATH"`。

### Q: vcpkg 依赖找不到版本
**A:** 检查 `vcpkg.json` 中的版本是否与 vcpkg 数据库中的可用版本匹配。使用 `vcpkg search <package>` 查看可用版本。

### Q: Cargo.lock 版本冲突
**A:** 删除 Cargo.lock 并重新运行 `cargo build` 让它自动重新生成。

## 文件结构

```
scripts/
├── README.md              # 本文档
├── build_helper.py        # 构建辅助工具
├── setup-local-env.sh     # 本地环境设置
└── enhanced_build.py      # 增强版构建脚本

.github/workflows/
├── playground.yml         # 主要 CI 工作流
└── flutter-build.yml      # Flutter 构建工作流
```

## 维护说明

### 更新依赖版本

如果需要更新 vcpkg 依赖：
1. 使用 `vcpkg search <package>` 查看可用版本
2. 更新 `vcpkg.json`
3. 测试构建

### 更新 Rust 版本

1. 更新 `.github/workflows/*.yml` 中的 `RUST_VERSION`
2. 确保本地开发环境同步更新
3. 测试兼容性

## 贡献

遇到问题或有改进建议：
1. 运行诊断工具 `python3 scripts/build_helper.py --diagnose`
2. 检查日志文件
3. 提交 Issue 或 Pull Request

---

## 版本历史

### v1.0 (2024-04-28)
- 初始版本
- 修复 libjpeg-turbo 版本问题
- 修复 Cargo.lock 版本兼容性
- 修复 run-on-arch-action PATH 问题
- 添加构建辅助工具
- 添加环境诊断脚本
