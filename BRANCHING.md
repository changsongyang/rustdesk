# RustDesk 分支管理规范

## 概述

本文档定义 RustDesk 项目的分支管理策略和命名规范，确保代码版本控制的一致性和可追溯性。

## 分支类型

### 1. 主分支 (Main Branches)

#### 1.1 main 分支
- **用途**: 生产环境代码，始终保持稳定可发布状态
- **保护**: 强制代码审查和 CI 通过
- **命名**: `main`

#### 1.2 develop 分支（可选）
- **用途**: 开发集成分支
- **命名**: `develop`

### 2. 功能分支 (Feature Branches)

- **用途**: 开发新功能
- **命名**: `feature/[功能名称]-[简短描述]`
- **示例**:
  - `feature/hwcodec-support`
  - `feature/encryption-improvement`
  - `feature/ui-redesign`

### 3. Bug 修复分支 (Bugfix Branches)

- **用途**: 修复生产环境或开发环境的 bug
- **命名**: `bugfix/[问题描述]`
- **示例**:
  - `bugfix/ffmpeg-build-failure`
  - `bugfix/android-crash`
  - `bugfix/network-timeout`

### 4. 热修复分支 (Hotfix Branches)

- **用途**: 紧急修复生产环境的严重问题
- **命名**: `hotfix/[问题描述]`
- **示例**:
  - `hotfix/security-vulnerability`
  - `hotfix/critical-crash`

### 5. 发布分支 (Release Branches)

- **用途**: 准备发布新版本
- **命名**: `release/[版本号]`
- **示例**:
  - `release/1.5.0`
  - `release/1.5.3`

### 6. 测试分支 (Test Branches)

- **用途**: 测试特定功能或修复
- **命名**: `test/[测试内容]`
- **示例**:
  - `test/hwcodec-performance`
  - `test/android-compatibility`

## 分支生命周期

### 创建分支
1. 从 `main` 或 `develop` 分支创建
2. 使用清晰的分支名称
3. 添加适当的描述

### 开发流程
1. 在本地分支上进行开发
2. 定期推送分支到远程仓库
3. 保持分支同步更新

### 代码审查
1. 创建 Pull Request
2. 指定至少一位审查者
3. 解决所有审查意见

### 合并流程
1. 确保所有 CI 检查通过
2. 使用 Squash Merge 或 Rebase Merge
3. 删除已合并的分支

## 分支保护规则

### main 分支保护
- ✅ 要求 pull request 审查
- ✅ 要求状态检查通过
- ✅ 启用强制推送保护
- ✅ 启用删除保护

### develop 分支保护（如存在）
- ✅ 要求 pull request 审查
- ✅ 要求状态检查通过

## 提交消息规范

提交消息应遵循 [Conventional Commits](https://www.conventionalcommits.org/) 规范：

```
<type>(<scope>): <description>

[optional body]

[optional footer(s)]
```

### 类型 (Type)
- **feat**: 新功能
- **fix**: 修复 bug
- **docs**: 文档更新
- **style**: 代码格式（不影响代码逻辑）
- **refactor**: 重构（既不添加功能也不修复 bug）
- **perf**: 性能优化
- **test**: 添加或更新测试
- **chore**: 构建过程或辅助工具的变动

### 示例
```
feat(hwcodec): 添加 FFmpeg 7.x 兼容性支持

- 使用条件编译处理 AVFrame.key_frame 变更
- 添加版本检测逻辑
- 支持 FFmpeg 6.x 和 7.x

Closes #1234
```

## 工作流程示例

### 功能开发流程
1. `git checkout main`
2. `git pull origin main`
3. `git checkout -b feature/new-feature`
4. 开发代码
5. `git push origin feature/new-feature`
6. 创建 Pull Request
7. 代码审查
8. CI 通过
9. 合并到 main
10. 删除分支

### Bug 修复流程
1. `git checkout main`
2. `git pull origin main`
3. `git checkout -b bugfix/issue-description`
4. 修复代码
5. `git push origin bugfix/issue-description`
6. 创建 Pull Request
7. 代码审查
8. CI 通过
9. 合并到 main
10. 删除分支

### 热修复流程
1. `git checkout main`
2. `git pull origin main`
3. `git checkout -b hotfix/critical-issue`
4. 修复代码
5. `git push origin hotfix/critical-issue`
6. 创建 Pull Request
7. 快速审查
8. CI 通过
9. 合并到 main 和 develop
10. 删除分支

## 最佳实践

1. **保持分支小型化**: 每个分支专注于一个功能或修复
2. **频繁推送**: 定期推送分支，防止工作丢失
3. **及时清理**: 合并后及时删除分支
4. **写清晰的提交消息**: 使用 Conventional Commits 格式
5. **同步更新**: 定期从上游分支拉取更新
6. **运行本地检查**: 提交前运行代码质量检查

## 工具支持

### pre-commit 钩子
项目配置了 pre-commit 钩子，提交前会自动检查：
- rustfmt: 代码格式
- clippy: 代码质量
- cargo-audit: 安全漏洞
- cargo-check: 编译检查

### CI/CD
- 推送代码自动触发 GitHub Actions
- 所有检查通过才能合并
- 自动构建和测试验证

---

**版本**: v1.0  
**最后更新**: 2026-05-17  
**适用项目**: RustDesk
