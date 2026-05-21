# RustDesk 代码回滚流程指南

## 概述

本文档描述 RustDesk 项目的代码回滚流程，确保在出现问题时能够快速、安全地恢复到稳定版本。

## 回滚场景

### 场景 1：生产环境紧急修复
- **触发条件**: 生产环境发现严重 bug 或安全漏洞
- **优先级**: 高
- **回滚目标**: 快速恢复到上一个稳定版本

### 场景 2：CI/CD 构建失败
- **触发条件**: 提交后 CI 构建失败
- **优先级**: 中
- **回滚目标**: 恢复到构建成功的版本

### 场景 3：代码审查发现问题
- **触发条件**: PR 审查发现严重问题
- **优先级**: 中
- **回滚目标**: 撤销有问题的提交

## 回滚流程

### 步骤 1：确认问题

1. **收集信息**
   - 问题描述
   - 受影响的版本
   - 问题严重程度

2. **确认回滚范围**
   - 需要回滚的提交
   - 回滚目标版本
   - 影响的功能

### 步骤 2：执行回滚

#### 方法 A：使用回滚脚本（推荐）

```bash
# 基本用法
./scripts/rollback.sh --version <目标版本>

# 带验证的回滚
./scripts/rollback.sh --version abc123 --branch main --verify

# 强制回滚（跳过确认）
./scripts/rollback.sh --version v1.5.2 --verify --force
```

#### 方法 B：手动回滚

```bash
# 查看提交历史
git log --oneline -10

# 创建回滚提交
git revert --no-edit <问题提交>..HEAD

# 或者使用 reset（危险，会丢失提交）
git reset --hard <目标版本>
git push --force origin <分支>
```

### 步骤 3：验证回滚

1. **编译验证**
   ```bash
   cargo check --all
   ```

2. **代码格式验证**
   ```bash
   cargo fmt --all --check
   ```

3. **运行测试**
   ```bash
   cargo test --all
   ```

4. **CI/CD 验证**
   - 推送代码
   - 监控 CI 状态
   - 确认所有检查通过

### 步骤 4：通知相关人员

- 更新 issue 状态
- 通知团队成员
- 记录回滚原因和结果

## 回滚策略

### 策略 1：Revert（推荐）
- **优点**: 保留完整的提交历史
- **适用场景**: 需要保留历史记录的情况
- **命令**: `git revert`

### 策略 2：Reset
- **优点**: 快速恢复到指定版本
- **适用场景**: 紧急修复，不需要保留问题提交
- **命令**: `git reset --hard`

### 策略 3：Branch Rollback
- **优点**: 在新分支上进行回滚，不影响主分支
- **适用场景**: 需要测试回滚效果的情况
- **步骤**:
  ```bash
  git checkout -b rollback-fix
  git revert --no-edit <问题提交>..HEAD
  # 测试后合并回主分支
  ```

## 注意事项

### 重要提醒

1. **数据安全**
   - 回滚可能影响数据库或配置
   - 确保备份重要数据

2. **强制推送**
   - 使用 `git push --force` 时要非常小心
   - 确保没有其他开发者在同一分支上工作

3. **协作沟通**
   - 回滚前通知团队成员
   - 回滚后更新文档和状态

4. **问题分析**
   - 回滚后分析问题原因
   - 记录问题以便后续修复

## 回滚脚本使用说明

### 基本参数

```bash
./scripts/rollback.sh --help

用法:
  rollback.sh --version <版本> [--branch <分支>] [--verify] [--force]

选项:
  --version, -v   指定要回滚到的版本（commit hash 或 tag）
  --branch, -b    指定目标分支（默认当前分支）
  --verify, -f    回滚后执行验证检查
  --force         强制回滚（跳过确认）
  --help, -h      显示此帮助信息
```

### 示例

```bash
# 回滚到特定 commit
./scripts/rollback.sh --version abc123def --verify

# 回滚到标签版本
./scripts/rollback.sh --version v1.5.2 --branch main --verify

# 强制回滚（不推荐，除非紧急情况）
./scripts/rollback.sh --version abc123 --force
```

## 最佳实践

1. **提前准备**
   - 定期备份代码
   - 熟悉回滚流程
   - 测试回滚脚本

2. **快速响应**
   - 发现问题后及时处理
   - 最小化服务中断时间
   - 保持沟通畅通

3. **事后分析**
   - 分析问题根本原因
   - 制定预防措施
   - 更新文档和流程

## 紧急联系方式

| 角色 | 联系方式 |
|------|----------|
| 技术负责人 | changsongyang |
| CI/CD 负责人 | changsongyang |

---

**版本**: v1.0  
**最后更新**: 2026-05-17  
**适用项目**: RustDesk
