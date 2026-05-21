# Linux Sciter 构建修复与长期维护优化计划

## 概述

本规格文档针对以下问题制定修复和优化计划：

1. **Linux Sciter 构建失败** - 需要检查并修复 Sciter 渲染引擎的依赖库问题
2. **长期维护优化** - 实施 FFmpeg 版本锁定、构建前依赖检查和 CI 缓存优化

---

## 目标

### 短期目标（立即执行）
- 修复 Linux Sciter 构建问题，确保所有平台构建成功
- 添加构建前依赖检查脚本，提前发现潜在问题

### 长期目标（持续改进）
- 建立稳定的 FFmpeg 版本管理机制
- 优化 CI 缓存策略，减少构建时间
- 建立自动化的构建健康检查机制

---

## 非目标

- 不修改核心功能逻辑
- 不升级 Rust 版本（保持 1.81）
- 不进行大规模重构

---

## 背景与上下文

### Linux Sciter 构建问题
- **问题描述**: Linux x86_64 Sciter 版本构建失败
- **可能原因**: 
  - Sciter 渲染引擎在 CI 环境中缺少依赖库
  - 缺少 GTK、webkit 等图形库
  - 环境变量配置问题

### 长期维护挑战
- **FFmpeg 版本碎片化**: 上游 FFmpeg 更新可能导致兼容性问题
- **构建时间长**: 缺乏有效的缓存策略
- **依赖管理**: 缺少预构建依赖检查

---

## 功能需求

### FR-1: Linux Sciter 依赖检查
系统应能够在构建前检查所有必要的 Sciter 依赖库是否存在

#### AC-1.1: 依赖检查脚本
- **Given**: 构建开始前
- **When**: 执行依赖检查脚本
- **Then**: 如果缺少依赖，输出清晰的错误信息并建议安装命令
- **Verification**: programmatic

#### AC-1.2: CI 环境配置
- **Given**: GitHub Actions 运行构建
- **When**: 进入 Linux 构建步骤
- **Then**: 自动安装所有必要的 Sciter 依赖库
- **Verification**: programmatic

---

### FR-2: FFmpeg 版本锁定
系统应锁定特定版本的 FFmpeg，避免上游更新影响构建

#### AC-2.1: vcpkg 版本锁定
- **Given**: CI 环境初始化
- **When**: 安装 vcpkg 依赖
- **Then**: 使用锁定版本的 FFmpeg
- **Verification**: programmatic

#### AC-2.2: 版本验证
- **Given**: 构建开始前
- **When**: 执行构建脚本
- **Then**: 验证 FFmpeg 版本是否符合要求
- **Verification**: programmatic

---

### FR-3: 构建前依赖检查
系统应在实际构建前验证所有依赖是否满足要求

#### AC-3.1: 工具链检查
- **Given**: 构建开始前
- **When**: 执行检查脚本
- **Then**: 验证 Rust、Cargo、vcpkg 等工具版本
- **Verification**: programmatic

#### AC-3.2: 库依赖检查
- **Given**: 构建开始前
- **When**: 执行检查脚本
- **Then**: 验证 FFmpeg、libva、vdpau 等库是否存在
- **Verification**: programmatic

---

### FR-4: CI 缓存优化
系统应优化缓存策略，减少不必要的重复构建

#### AC-4.1: Cargo 缓存
- **Given**: CI 工作流执行
- **When**: 构建 Rust 代码
- **Then**: 使用 GitHub Actions 缓存 Cargo 依赖
- **Verification**: programmatic

#### AC-4.2: vcpkg 缓存
- **Given**: CI 工作流执行
- **When**: 安装 vcpkg 依赖
- **Then**: 缓存 vcpkg 安装目录
- **Verification**: programmatic

#### AC-4.3: 缓存失效策略
- **Given**: Cargo.toml 或 vcpkg.json 变更
- **When**: 触发新构建
- **Then**: 自动失效相关缓存
- **Verification**: programmatic

---

## 非功能需求

### NFR-1: 构建时间优化
- 构建时间应不超过当前的 80%
- 缓存命中率应达到 90% 以上

### NFR-2: 稳定性
- 构建成功率应达到 95% 以上
- 依赖检查应在 30 秒内完成

### NFR-3: 可观测性
- 应输出详细的构建日志
- 应记录缓存命中/失效情况
- 应提供性能统计信息

---

## 约束

### 技术约束
- 保持 Rust 版本为 1.81
- 保持现有项目结构和代码规范
- 兼容现有 CI/CD 工作流

### 业务约束
- 最小化对现有工作流的影响
- 确保向后兼容性

---

## 假设

- GitHub Actions 环境具有必要的网络访问权限
- vcpkg 可以正确安装指定版本的依赖
- 缓存机制不会导致构建不一致

---

## 开放问题

- [ ] Sciter 构建失败的具体错误信息是什么？
- [ ] 当前 CI 环境中缺少哪些 Sciter 依赖库？
- [ ] 是否需要为不同 Linux 发行版配置不同的依赖安装命令？

---

## 依赖关系

```
FR-1 (Sciter 依赖检查)
    ↓
FR-2 (FFmpeg 版本锁定)
    ↓
FR-3 (构建前依赖检查)
    ↓
FR-4 (CI 缓存优化)
```
