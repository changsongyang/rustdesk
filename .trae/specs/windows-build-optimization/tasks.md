# Windows 多架构打包构建优化 - 实现计划

## [x] Task 1: 创建可复用的 LLVM 配置 Action
- **Priority**: P0
- **Depends On**: None
- **Description**: 
  - 创建 `.github/actions/setup-windows-llvm/action.yml`
  - 支持架构参数 (i686/x86_64)
  - 动态检测 LLVM 安装路径
  - 设置正确的 `LIBCLANG_PATH` 环境变量
- **Acceptance Criteria Addressed**: AC-6
- **Test Requirements**:
  - `programmatic` TR-1.1: Action 能够正确安装对应架构的 LLVM
  - `programmatic` TR-1.2: `LIBCLANG_PATH` 环境变量正确设置
  - `human-judgment` TR-1.3: Action 代码结构清晰，注释完善

## [x] Task 2: 更新 Flutter 构建任务使用新 Action
- **Priority**: P0
- **Depends On**: Task 1
- **Description**: 
  - 修改 `build-for-windows-flutter` 任务
  - 移除重复的 LLVM 配置代码
  - 使用新创建的 `setup-windows-llvm` Action
- **Acceptance Criteria Addressed**: AC-1, AC-2, AC-5
- **Test Requirements**:
  - `programmatic` TR-2.1: Flutter i686 构建成功
  - `programmatic` TR-2.2: Flutter x86_64 构建成功
  - `human-judgment` TR-2.3: 代码重复率降低

## [x] Task 3: 更新 Sciter 构建任务使用新 Action
- **Priority**: P0
- **Depends On**: Task 1
- **Description**: 
  - 修改 `build-for-windows-sciter` 任务
  - 移除重复的 LLVM 配置代码
  - 使用新创建的 `setup-windows-llvm` Action
- **Acceptance Criteria Addressed**: AC-3, AC-4, AC-5
- **Test Requirements**:
  - `programmatic` TR-3.1: Sciter i686 构建成功
  - `programmatic` TR-3.2: Sciter x86_64 构建成功
  - `human-judgment` TR-3.3: 代码重复率降低

## [ ] Task 4: 验证构建工作流
- **Priority**: P1
- **Depends On**: Task 2, Task 3
- **Description**: 
  - 触发 GitHub Actions 工作流
  - 验证所有架构的构建都能成功完成
  - 检查构建产物是否正确生成
- **Acceptance Criteria Addressed**: AC-1, AC-2, AC-3, AC-4
- **Test Requirements**:
  - `programmatic` TR-4.1: 所有 4 个构建任务（Flutter i686/x86_64, Sciter i686/x86_64）都成功
  - `programmatic` TR-4.2: 构建产物 `.exe` 和 `.msi` 文件正确生成

## [ ] Task 5: 代码审查和质量检查
- **Priority**: P2
- **Depends On**: Task 4
- **Description**: 
  - 审查工作流代码质量
  - 检查代码重复率
  - 确保符合代码规范
- **Acceptance Criteria Addressed**: AC-5
- **Test Requirements**:
  - `human-judgment` TR-5.1: 代码结构清晰，易于维护
  - `human-judgment` TR-5.2: 代码重复率 ≤ 10%
  - `human-judgment` TR-5.3: 符合 GitHub Actions 最佳实践