# RustDesk 安全审计指南

## 概述

本指南提供 RustDesk 项目的安全审计最佳实践，包括定期安全检查、Git Hooks 集成和 CI 配置。

---

## 快速开始

### 运行完整安全审计

#### Windows (PowerShell)
```powershell
.\scripts\security-audit.ps1
```

#### Linux/Mac (Bash)
```bash
chmod +x scripts/security-audit.sh
./scripts/security-audit.sh
```

### 安装 Git Hooks

```bash
chmod +x scripts/install-git-hooks.sh
./scripts/install-git-hooks.sh
```

---

## 安全审计脚本

### 功能说明

`security-audit.sh` / `security-audit.ps1` 包含以下检查：

| 检查项 | 说明 | 命令 |
|--------|------|------|
| 1. 依赖漏洞扫描 | 检查依赖安全漏洞 | `cargo audit` |
| 2. 代码格式检查 | 检查代码格式 | `cargo fmt --check` |
| 3. Clippy 检查 | 代码质量检查 | `cargo clippy` |
| 4. 文档测试 | 运行文档测试 | `cargo test --doc` |
| 5. 完整测试 | 运行所有测试 | `cargo test` |
| 6. 编译检查 | 验证编译通过 | `cargo build` |
| 7. HTML 实体检查 | 检查 HTML 编码问题 | 自定义检查 |
| 8. Git 状态检查 | 检查工作区状态 | `git status` |

### 前置依赖

安装 cargo-audit（依赖漏洞扫描）：
```bash
cargo install cargo-audit
```

---

## Git Hooks

### 可用的 Hooks

| Hook | 触发时机 | 说明 |
|------|----------|------|
| pre-commit | 提交前 | 快速格式、Clippy 和编译检查 |

### 安装 Hooks

```bash
./scripts/install-git-hooks.sh
```

### 跳过 Hook 检查

如需临时跳过检查：
```bash
git commit --no-verify -m "your message"
```

---

## 定期审计计划

### 建议的审计频率

| 审计类型 | 频率 | 执行者 |
|----------|------|--------|
| 快速检查 (pre-commit) | 每次提交 | 开发者 |
| 完整安全审计 | 每周 | 团队 |
| 依赖漏洞扫描 | 每周 | 团队 |
| 完整代码审查 | 每次 PR | 团队 |

---

## CI 集成建议

### 在 CI 中添加安全检查

在 `.github/workflows/ci.yml` 中添加：

```yaml
- name: Security Audit
  run: |
    cargo audit
    cargo fmt --check
    cargo clippy -- -D warnings
    cargo test --doc
```

---

## 历史问题记录

### 2026-05-13: 1.5.1 分支合并问题

**问题**: 从 1.5.1 分支合并到 main 时引入了多个问题：

| 文件 | 问题 | 解决方案 |
|------|------|----------|
| `verifier.rs` | HTML 实体编码 | 解码 HTML 实体 |
| `verifier.rs` | 缺少 bail 导入 | 添加 `use crate::bail;` |
| `compress.rs` | 文档测试失败 | 删除问题文档测试 |
| `terminal_helper.rs` | 文档测试格式 | 使用 `text` 标记 |
| `AndroidManifest.xml` | HTML 实体编码 | 解码 HTML 实体 |

**经验教训**:
1. 合并分支前必须运行完整测试
2. 特别注意文档测试 (`cargo test --doc`)
3. 检查文件编码问题（HTML 实体）
4. 加强合并前的代码审查

---

## 依赖漏洞管理

### 当前已知漏洞

参考最新的 `cargo audit` 输出。

### 漏洞处理优先级

| 严重程度 | 响应时间 | 处理方式 |
|----------|----------|----------|
| 🔴 严重 | 24 小时内 | 立即升级 |
| 🟡 中等 | 1 周内 | 计划升级 |
| 🟢 低 | 下次发布 | 随版本升级 |

---

## 最佳实践检查清单

### 合并前检查

- [ ] 运行 `cargo build`
- [ ] 运行 `cargo test`
- [ ] 运行 `cargo test --doc`
- [ ] 运行 `cargo clippy`
- [ ] 运行 `cargo fmt --check`
- [ ] 检查 HTML 实体编码
- [ ] 检查敏感信息
- [ ] 查看 git diff
- [ ] 自我审查代码

### 定期检查

- [ ] 每周运行 `cargo audit`
- [ ] 每周运行完整安全审计
- [ ] 每月审查依赖更新
- [ ] 每季度完整安全审计

---

## 相关资源

- [RustSec Advisory Database](https://rustsec.org/)
- [cargo-audit](https://github.com/rustsec/cargo-audit)
- [Rust API Guidelines](https://rust-lang.github.io/api-guidelines/)
- [AGENTS.md](./AGENTS.md) - 项目开发规范

---

## 附录

### 脚本权限设置

```bash
# Linux/Mac
chmod +x scripts/security-audit.sh
chmod +x scripts/pre-commit.sh
chmod +x scripts/install-git-hooks.sh

# Windows (PowerShell)
# 不需要权限设置
```

### 手动运行单项检查

```bash
# 仅依赖漏洞扫描
cargo audit

# 仅文档测试
cargo test --doc

# 仅 Clippy 检查
cargo clippy -- -D warnings
```
