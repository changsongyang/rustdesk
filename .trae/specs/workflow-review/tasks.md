# RustDesk CI/CD 工作流审查 - 实施计划

## [x] Task 1: 重新启用 macOS vcpkg 缓存
- **Priority**: P0
- **Depends On**: None
- **Description**: 
  - 取消注释 flutter-build.yml 中 macOS 构建任务的 vcpkg 缓存配置
  - 参考 Windows 和 Android 的配置模式，确保配置正确
- **Acceptance Criteria Addressed**: AC-1
- **Test Requirements**:
  - `programmatic`: 检查 flutter-build.yml 中 macOS 任务的 vcpkg 步骤未被注释
  - `human-judgement`: 验证配置与其他平台一致
- **Notes**: 仔细检查被注释的原因，确保没有已知的兼容性问题

## [x] Task 2: 统一所有工作流的 GitHub Actions 缓存环境变量导出
- **Priority**: P1
- **Depends On**: None
- **Description**: 
  - 检查所有工作流中 GitHub Actions 缓存环境变量导出的代码
  - 确保所有工作流都使用 actions/github-script@v7
  - 统一代码格式和位置
- **Acceptance Criteria Addressed**: AC-2, AC-4
- **Test Requirements**:
  - `programmatic`: 所有工作流都使用相同的 actions/github-script 版本
  - `programmatic`: 环境变量导出步骤在所有工作流中的位置一致
- **Notes**: 确保该步骤总是在 checkout 之前或之后立即执行

## [x] Task 3: 统一 rust-cache 配置模式
- **Priority**: P1
- **Depends On**: None
- **Description**: 
  - 检查所有工作流中 Swatinem/rust-cache 的使用
  - 统一配置参数和位置
  - 确保在 Rust 工具链安装之后立即执行
- **Acceptance Criteria Addressed**: AC-2, AC-3
- **Test Requirements**:
  - `programmatic`: 所有 rust-cache 使用相同的版本和配置模式
  - `human-judgement`: 验证步骤顺序合理
- **Notes**: prefix-key 可以根据平台不同而变化

## [x] Task 4: 统一 vcpkg 缓存配置模式
- **Priority**: P1
- **Depends On**: Task 1
- **Description**: 
  - 检查所有平台的 vcpkg 配置
  - 统一使用 lukka/run-vcpkg@v11
  - 统一 doNotCache=false 设置
  - 确保 vcpkgGitCommitId 与环境变量一致
- **Acceptance Criteria Addressed**: AC-2, AC-4
- **Test Requirements**:
  - `programmatic`: 所有 vcpkg 配置使用相同的 Action 版本
  - `programmatic`: 所有平台都启用缓存（doNotCache=false）
- **Notes**: vcpkgDirectory 可以根据平台不同而变化

## [x] Task 5: 检查并优化步骤顺序
- **Priority**: P2
- **Depends On**: None
- **Description**: 
  - 审查所有工作流的步骤执行顺序
  - 确保缓存相关步骤在依赖安装和构建之前
  - 确保逻辑依赖关系正确
- **Acceptance Criteria Addressed**: AC-3
- **Test Requirements**:
  - `human-judgement`: 验证步骤顺序逻辑合理
  - `human-judgement`: 缓存步骤在最前面执行
- **Notes**: 一般顺序应该是：环境变量导出 → checkout → 工具链安装 → 缓存配置 → 依赖安装 → 构建

## [x] Task 6: 验证所有修改并运行最终检查
- **Priority**: P0
- **Depends On**: Task 1, Task 2, Task 3, Task 4, Task 5
- **Description**: 
  - 运行工作流语法检查
  - 验证所有修改符合要求
  - 确保没有引入新问题
- **Acceptance Criteria Addressed**: AC-5
- **Test Requirements**:
  - `programmatic`: YAML 语法检查通过
  - `programmatic`: 所有修改与规范一致
  - `human-judgement`: 代码审查通过
- **Notes**: 可以使用 VS Code 的 YAML 验证功能
