# RustDesk 优化计划 - 使用指南

## 📋 目录

1. [快速开始](#快速开始)
2. [pre-commit 钩子使用](#pre-commit-钩子使用)
3. [代码质量检查](#代码质量检查)
4. [分支管理](#分支管理)
5. [提交消息规范](#提交消息规范)
6. [脚本工具使用](#脚本工具使用)
7. [回滚操作](#回滚操作)

---

## 🚀 快速开始

### 1. 安装 pre-commit 钩子

```bash
# 进入项目目录
cd rustdesk

# 安装 pre-commit（如果未安装）
pip install pre-commit

# 安装项目的 pre-commit 钩子
pre-commit install
```

### 2. 配置提交消息模板

```bash
git config --local commit.template .gitmessage
```

---

## 🛠️ pre-commit 钩子使用

### 钩子会自动运行的检查

当您执行 `git commit` 时，pre-commit 会自动运行以下检查：

| 检查项 | 说明 |
|--------|------|
| `trailing-whitespace` | 检查行尾空白 |
| `end-of-file-fixer` | 确保文件以换行结束 |
| `check-yaml` | YAML 格式验证 |
| `check-json` | JSON 格式验证 |
| `check-toml` | TOML 格式验证 |
| `check-merge-conflict` | 检查合并冲突标记 |
| `detect-private-key` | 检测私钥文件 |
| `rustfmt` | Rust 代码格式化检查 |
| `clippy` | Rust 代码质量检查 |
| `cargo-audit` | 依赖安全漏洞扫描 |
| `cargo-check` | 编译错误检查 |
| `shellcheck` | Shell 脚本检查 |

### 手动运行 pre-commit 钩子

```bash
# 运行所有钩子
pre-commit run --all-files

# 只运行特定钩子
pre-commit run rustfmt
```

### 跳过检查（紧急情况）

```bash
git commit --no-verify -m "紧急提交"
```

---

## ✅ 代码质量检查

### 使用脚本运行完整检查

```bash
./scripts/run-checks.sh
```

这会运行：
1. `cargo fmt --all --check` - 格式检查
2. `cargo check --all` - 编译检查
3. `cargo clippy --all --all-targets -- -D warnings` - 代码质量检查
4. `cargo audit` - 安全漏洞扫描（可选）

### 示例输出

```
==========================================
RustDesk 代码质量检查
==========================================

📦 检查必要工具...
✅ 所有工具已安装

🔍 运行 rustfmt...
  检查 Rust 代码格式化
✅ rustfmt 通过 (12s)

🔍 运行 cargo check...
  检查编译错误
✅ cargo check 通过 (45s)

...
```

---

## 🌿 分支管理

### 创建新分支

```bash
# 功能分支
git checkout -b feature/your-feature-name

# Bug 修复分支
git checkout -b bugfix/issue-description

# 热修复分支
git checkout -b hotfix/critical-fix
```

### 分支命名规范

| 前缀 | 用途 | 示例 |
|------|------|------|
| `feature/` | 新功能开发 | `feature/hwcodec-support` |
| `bugfix/` | 修复生产 bug | `bugfix/android-crash` |
| `hotfix/` | 紧急热修复 | `hotfix/security-vulnerability` |
| `release/` | 发布版本准备 | `release/1.5.4` |
| `test/` | 测试专用分支 | `test/performance-benchmark` |

### 工作流程

```bash
# 1. 从主分支创建新分支
git checkout main
git pull origin main
git checkout -b feature/new-feature

# 2. 开发并提交
git add .
git commit -m "feat: 添加新功能"

# 3. 推送并创建 PR
git push origin feature/new-feature
# 在 GitHub 上创建 PR

# 4. 合并后清理
git checkout main
git pull origin main
git branch -d feature/new-feature
git push origin --delete feature/new-feature
```

---

## 📝 提交消息规范

### Conventional Commits 格式

```
type(scope): description

[optional body]

[optional footer]
```

### 类型（type）

| 类型 | 说明 |
|------|------|
| `feat` | 新功能 |
| `fix` | Bug 修复 |
| `docs` | 文档更新 |
| `style` | 代码格式（不影响逻辑） |
| `refactor` | 重构（无功能变更） |
| `perf` | 性能优化 |
| `test` | 测试相关 |
| `chore` | 构建/工具变更 |
| `build` | 构建系统变更 |
| `ci` | CI/CD 配置变更 |
| `revert` | 撤销提交 |

### 示例提交

```bash
# 功能
git commit -m "feat(hwcodec): 添加 FFmpeg 7.x 兼容性支持"

# 修复
git commit -m "fix(build): 修复 Linux Sciter 依赖问题"

# 文档
git commit -m "docs: 更新 BRANCHING.md 添加分支规范"

# 引用 issue
git commit -m "fix(android): 修复崩溃问题

详细说明修复内容

Closes #1234"
```

### 使用消息模板

提交时会自动加载模板：

```bash
git commit
# 编辑器会显示 .gitmessage 模板内容
```

---

## 🔧 脚本工具使用

### 构建错误分析工具

```bash
# 分析构建日志
./scripts/analyze-build-errors.sh --log build.log --output error-report.txt
```

### 版本变更检测

```bash
# 检测版本和依赖变更
./scripts/detect-version-changes.sh
```

### 工具链验证

```bash
# 验证工具链和配置
./scripts/verify-toolchain.sh
```

### Rust 版本验证

```bash
# 验证是否使用正确的 Rust 版本
./scripts/verify-rust-version.sh
```

### 依赖检查

```bash
# 检查构建依赖
./scripts/check-dependencies.sh
```

### 构建产物验证

```bash
# 生成构建产物哈希
./scripts/verify-build-products.sh --generate

# 验证构建产物完整性
./scripts/verify-build-products.sh --verify
```

---

## ↩️ 回滚操作

### 方法 1：使用回滚脚本（推荐）

```bash
# 基本回滚
./scripts/rollback.sh --version <commit-hash>

# 回滚到 tag
./scripts/rollback.sh --version v1.5.2

# 指定分支并验证
./scripts/rollback.sh --version abc123 --branch main --verify

# 强制回滚（跳过确认）
./scripts/rollback.sh --version abc123 --force
```

### 方法 2：手动回滚

```bash
# 查看提交历史
git log --oneline -10

# 使用 git revert（保留历史）
git revert <commit-hash>

# 或使用 git reset（更危险，删除历史）
git reset --hard <target-commit>
git push --force origin <branch>
```

### 回滚后的验证

```bash
# 检查编译
cargo check --all

# 检查格式
cargo fmt --all --check

# 运行完整检查
./scripts/run-checks.sh
```

---

## 📚 更多文档

详细文档请查看：

- [BRANCHING.md](file:///c:\Users\ycsit\Downloads\rustdesk\rustdesk\BRANCHING.md) - 分支管理完整规范
- [ROLLBACK.md](file:///c:\Users\ycsit\Downloads\rustdesk\rustdesk\ROLLBACK.md) - 回滚流程详细指南
- [`.trae/specs/`](file:///c:\Users\ycsit\Downloads\rustdesk\rustdesk\.trae\specs) - 所有计划文档

---

## 💡 常见问题

**Q: pre-commit 钩子阻止了我的提交怎么办？**
A: 请修复检查报告的问题，或使用 `--no-verify` 跳过（仅紧急情况）

**Q: 如何安装 cargo-audit？**
A: `cargo install cargo-audit`

**Q: 如何只运行部分检查？**
A: `pre-commit run rustfmt --all-files`

**Q: 提交被 commit-msg 钩子拒绝？**
A: 请检查提交消息是否符合 Conventional Commits 格式

---

## 📋 快速检查清单

提交前确保：

- [ ] 运行了 `./scripts/run-checks.sh` 并全部通过
- [ ] 提交消息符合 Conventional Commits 格式
- [ ] 分支命名符合规范
- [ ] 代码已编译通过且无警告
- [ ] 必要的测试已通过

---

**最后更新**: 2026-05-17
