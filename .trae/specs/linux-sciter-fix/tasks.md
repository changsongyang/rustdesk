# Linux Sciter 构建修复与长期维护优化任务清单

## 任务列表

### 第一阶段：问题分析

- [ ] 任务 1：分析 Linux Sciter 构建失败原因
  - **Priority**: P0
  - **Depends On**: None
  - **Description**: 
    - 查看最近失败的 Linux Sciter 构建日志
    - 识别具体的错误信息和缺失的依赖库
    - 分析 CI 环境配置
  - **Acceptance Criteria Addressed**: AC-1.1, AC-1.2
  - **Test Requirements**:
    - `programmatic` TR-1.1: 获取并分析构建失败日志
    - `human-judgment` TR-1.2: 识别根本原因并制定修复方案
  - **Notes**: 需要使用 GitHub CLI 查看失败日志

- [ ] 任务 2：检查现有 CI 工作流配置
  - **Priority**: P1
  - **Depends On**: Task 1
  - **Description**:
    - 分析 `.github/workflows/` 目录下的工作流文件
    - 检查 Linux 构建步骤的依赖安装命令
    - 识别潜在的配置问题
  - **Acceptance Criteria Addressed**: AC-1.2, AC-3.1
  - **Test Requirements**:
    - `programmatic` TR-2.1: 列出所有工作流文件
    - `human-judgment` TR-2.2: 分析依赖安装脚本

---

### 第二阶段：修复实施

- [ ] 任务 3：修复 Linux Sciter 依赖问题
  - **Priority**: P0
  - **Depends On**: Task 1, Task 2
  - **Description**:
    - 在 CI 工作流中添加缺失的依赖安装命令
    - 确保 GTK、webkit 等图形库已安装
    - 添加必要的环境变量配置
  - **Acceptance Criteria Addressed**: AC-1.2
  - **Test Requirements**:
    - `programmatic` TR-3.1: 修改工作流配置文件
    - `programmatic` TR-3.2: 触发构建验证修复
  - **Notes**: 需要修改 `flutter-build.yml` 中的 Linux 构建步骤

- [ ] 任务 4：创建构建前依赖检查脚本
  - **Priority**: P1
  - **Depends On**: Task 2
  - **Description**:
    - 创建 Shell/PowerShell 脚本检查所有必要依赖
    - 添加版本验证逻辑
    - 输出清晰的错误信息和建议修复命令
  - **Acceptance Criteria Addressed**: AC-3.1, AC-3.2
  - **Test Requirements**:
    - `programmatic` TR-4.1: 创建检查脚本
    - `programmatic` TR-4.2: 在 CI 中集成脚本
    - `human-judgment` TR-4.3: 验证脚本输出清晰有用

---

### 第三阶段：长期维护优化

- [ ] 任务 5：实施 FFmpeg 版本锁定
  - **Priority**: P1
  - **Depends On**: None
  - **Description**:
    - 在 vcpkg 配置中锁定特定 FFmpeg 版本
    - 添加版本验证步骤
    - 更新文档说明支持的 FFmpeg 版本
  - **Acceptance Criteria Addressed**: AC-2.1, AC-2.2
  - **Test Requirements**:
    - `programmatic` TR-5.1: 修改 vcpkg 配置锁定版本
    - `programmatic` TR-5.2: 添加版本验证检查
  - **Notes**: 需要检查 vcpkg.json 或 vcpkg-configuration.json

- [ ] 任务 6：优化 CI 缓存策略
  - **Priority**: P1
  - **Depends On**: None
  - **Description**:
    - 添加 Cargo 依赖缓存
    - 添加 vcpkg 缓存
    - 配置合理的缓存失效策略
  - **Acceptance Criteria Addressed**: AC-4.1, AC-4.2, AC-4.3
  - **Test Requirements**:
    - `programmatic` TR-6.1: 添加 GitHub Actions 缓存步骤
    - `programmatic` TR-6.2: 验证缓存命中率提升
    - `human-judgment` TR-6.3: 确认构建时间减少

---

### 第四阶段：验证与文档

- [ ] 任务 7：触发完整 CI 构建验证
  - **Priority**: P0
  - **Depends On**: Task 3, Task 5, Task 6
  - **Description**:
    - 触发新的 CI 构建
    - 验证所有平台构建成功
    - 记录构建时间和缓存命中率
  - **Acceptance Criteria Addressed**: AC-1.2, AC-2.1, AC-4.1
  - **Test Requirements**:
    - `programmatic` TR-7.1: 触发 CI 构建
    - `programmatic` TR-7.2: 验证所有平台构建成功
    - `programmatic` TR-7.3: 测量构建时间

- [ ] 任务 8：编写修复过程文档
  - **Priority**: P2
  - **Depends On**: Task 7
  - **Description**:
    - 记录 Sciter 依赖修复过程
    - 记录 FFmpeg 版本锁定配置
    - 记录 CI 缓存优化配置
    - 提供未来维护建议
  - **Acceptance Criteria Addressed**: 所有验收标准
  - **Test Requirements**:
    - `human-judgment` TR-8.1: 文档完整清晰
    - `human-judgment` TR-8.2: 包含所有关键信息

---

## 任务依赖关系图

```
任务 1 (分析失败原因)
    ↓
任务 2 (检查工作流配置)
    ↓
任务 3 (修复 Sciter 依赖) ←── 任务 4 (创建检查脚本)
    ↓
任务 5 (FFmpeg 版本锁定)
    ↓
任务 6 (CI 缓存优化)
    ↓
任务 7 (完整构建验证)
    ↓
任务 8 (编写文档)
```

## 并行执行建议

以下任务可以并行执行：
- **任务 3 和任务 4**: 分别处理 CI 配置和检查脚本
- **任务 5 和任务 6**: 分别处理版本锁定和缓存优化

## 风险和注意事项

1. **风险**: 修改工作流配置可能影响其他平台构建
   - **缓解**: 先在测试分支验证，再合并到主分支

2. **风险**: 缓存可能导致构建不一致
   - **缓解**: 配置合理的缓存失效策略，基于文件哈希

3. **风险**: FFmpeg 版本锁定可能影响未来功能
   - **缓解**: 定期审查版本锁定策略，必要时更新

4. **注意**: 需要验证所有修改不会破坏现有功能
   - **缓解**: 运行完整的测试套件
