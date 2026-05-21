# RustDesk CI/CD 工作流全面审查 - 产品需求文档

## Overview
- **Summary**: 对 RustDesk 项目的 GitHub Actions CI/CD 工作流进行全面审查，修复问题，优化性能，提高构建稳定性
- **Purpose**: 解决当前工作流中存在的缓存配置问题、重复代码、步骤顺序问题、错误处理不足等问题，确保构建系统高效稳定运行
- **Target Users**: RustDesk 开发团队和贡献者

## Goals
- 修复 macOS 构建中被禁用的 vcpkg 缓存
- 统一各工作流的重复代码模式
- 优化工作流步骤顺序和依赖关系
- 改进错误处理和日志输出
- 提高构建速度和成功率
- 确保工作流代码质量和可维护性

## Non-Goals (Out of Scope)
- 不重构整个构建系统架构
- 不修改核心业务逻辑代码
- 不添加新功能或特性
- 不进行大规模的依赖升级

## Background & Context
当前工作流存在以下已知问题：
1. macOS 构建的 vcpkg 缓存被注释禁用（flutter-build.yml:739-743）
2. 大量重复的环境变量导出和缓存配置代码
3. 步骤顺序不合理，有些缓存配置在依赖安装之后
4. 错误处理不够完善，失败时调试困难
5. 部分工作流配置与其他工作流不一致

## Functional Requirements
- **FR-1**: 重新启用 macOS 构建的 vcpkg 缓存
- **FR-2**: 统一所有平台的缓存配置模式
- **FR-3**: 优化步骤执行顺序，确保缓存配置在最前面
- **FR-4**: 改进错误处理，增加更详细的日志输出
- **FR-5**: 统一 GitHub Actions 版本使用
- **FR-6**: 确保各工作流之间的配置一致性

## Non-Functional Requirements
- **NFR-1**: 修复后构建速度至少保持不变或提升
- **NFR-2**: 构建成功率达到 95% 以上
- **NFR-3**: 工作流代码保持良好的可读性和可维护性
- **NFR-4**: 所有修改向后兼容，不破坏现有功能

## Constraints
- **Technical**: 必须保持与现有代码库兼容，使用相同的工具链版本
- **Business**: 需要在不影响当前开发进度的前提下进行修改
- **Dependencies**: 依赖已有的 GitHub Actions 版本，不引入新的外部依赖

## Assumptions
- 现有的工作流逻辑是正确的，只是配置问题
- 缓存机制在 macOS 上应该能正常工作
- 统一后的配置不会引入新的问题
- GitHub Actions 服务正常运行

## Acceptance Criteria

### AC-1: macOS vcpkg 缓存重新启用
- **Given**: flutter-build.yml 工作流文件
- **When**: 检查 macOS 构建任务
- **Then**: vcpkg 缓存配置不再被注释，并且正确启用
- **Verification**: programmatic
- **Notes**: 参考 Windows 和 Android 的配置模式

### AC-2: 所有工作流缓存配置统一
- **Given**: 所有工作流文件
- **When**: 检查缓存相关配置
- **Then**: GitHub Actions 缓存环境变量导出、rust-cache、vcpkg 缓存的配置模式一致
- **Verification**: programmatic

### AC-3: 步骤顺序优化
- **Given**: 每个构建任务
- **When**: 检查步骤执行顺序
- **Then**: 缓存配置步骤在依赖安装和构建之前执行
- **Verification**: human-judgment

### AC-4: GitHub Actions 版本统一
- **Given**: 所有工作流文件
- **When**: 检查使用的 GitHub Actions 版本
- **Then**: 相同的 Action 使用相同的版本号
- **Verification**: programmatic

### AC-5: 工作流可以成功运行
- **Given**: 修改后的工作流
- **When**: 推送到仓库触发构建
- **Then**: 所有平台的构建任务都能成功完成
- **Verification**: human-judgment

## Open Questions
- [ ] macOS 之前禁用 vcpkg 缓存的具体原因是什么？是否有已知问题需要解决？
- [ ] 是否需要对缓存大小和保留策略进行调整？
