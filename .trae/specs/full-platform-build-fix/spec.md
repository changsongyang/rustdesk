# 全平台构建失败修复 - Product Requirement Document

## Overview
- **Summary**: 深入排查并修复 RustDesk 项目在 Windows、macOS、Android 平台的 CI/CD 构建失败问题，确保所有平台都能正常构建
- **Purpose**: 解决当前只有 Linux 平台构建成功，而 Windows、macOS、Android 平台构建失败的问题，恢复完整的跨平台构建能力
- **Target Users**: 开发团队、CI/CD 运维、需要各平台构建产物的用户

## Goals
- 修复 Windows (x86_64 & i686) 平台构建失败问题
- 修复 macOS (x86_64 & aarch64) 平台构建失败问题
- 修复 Android (aarch64, armv7, x86_64) 平台构建失败问题
- 确保所有平台都能使用缓存加速构建
- 保持 Linux 平台的成功状态

## Non-Goals (Out of Scope)
- 不修复非构建相关的功能 bug
- 不添加新功能
- 不修改项目核心业务逻辑
- 不升级主要依赖版本（除非是构建问题必需）

## Background & Context
- 当前状态：Linux 平台构建成功，Windows/macOS/Android 构建失败
- 已完成的工作：统一了 CI/CD 缓存配置，恢复了缓存功能
- 失败平台的问题分析：
  - Windows：与 vcpkg/libyuv 构建相关
  - macOS：与 texture_rgba_renderer Swift 头文件相关
  - Android：具体错误信息需要进一步查看
- 相关文件：[flutter-build.yml](file:///c:\Users\ycsit\Downloads\rustdesk\rustdesk\.github\workflows\flutter-build.yml)、[ci.yml](file:///c:\Users\ycsit\Downloads\rustdesk\rustdesk\.github\workflows\ci.yml)

## Functional Requirements
- **FR-1**: Windows x86_64 平台能成功通过完整构建流程
- **FR-2**: Windows i686 平台能成功通过完整构建流程
- **FR-3**: macOS x86_64 平台能成功通过完整构建流程
- **FR-4**: macOS aarch64 平台能成功通过完整构建流程
- **FR-5**: Android aarch64 平台能成功通过完整构建流程
- **FR-6**: Android armv7 平台能成功通过完整构建流程
- **FR-7**: Android x86_64 平台能成功通过完整构建流程
- **FR-8**: 所有平台构建产物能正确生成并上传
- **FR-9**: 清除缓存功能正常工作

## Non-Functional Requirements
- **NFR-1**: 修复后的构建时间不应显著增加（使用缓存情况下）
- **NFR-2**: 修复方案应保持与现有 CI/CD 架构兼容
- **NFR-3**: 修复方案应具有可维护性和可扩展性

## Constraints
- **Technical**:
  - 必须使用现有的 CI/CD 工作流框架
  - 必须保持现有的平台支持范围
  - 必须与已恢复的缓存机制兼容
- **Business**:
  - 需要尽快完成修复以恢复正常的发布流程
- **Dependencies**:
  - GitHub Actions 运行环境
  - vcpkg 依赖管理
  - Flutter SDK
  - Rust 工具链

## Assumptions
- 假设 GitHub Actions 运行环境正常可用
- 假设所有必要的第三方服务（如 vcpkg 镜像）可访问
- 假设现有代码库的核心功能没有被破坏
- 假设问题主要是构建配置问题，而非代码逻辑问题

## Acceptance Criteria

### AC-1: Windows 平台构建成功
- **Given**: GitHub Actions 运行环境正常，缓存已清理
- **When**: 触发完整的 Flutter CI 工作流
- **Then**: Windows x86_64 和 i686 任务都显示绿色成功状态
- **Verification**: `programmatic` (通过 GitHub Actions API 检查构建状态)
- **Notes**: 需检查 vcpkg/libyuv 相关的警告和错误是否解决

### AC-2: macOS 平台构建成功
- **Given**: GitHub Actions 运行环境正常，缓存已清理
- **When**: 触发完整的 Flutter CI 工作流
- **Then**: macOS x86_64 和 aarch64 任务都显示绿色成功状态
- **Verification**: `programmatic` (通过 GitHub Actions API 检查构建状态)
- **Notes**: 需检查 texture_rgba_renderer Swift 头文件相关错误是否解决

### AC-3: Android 平台构建成功
- **Given**: GitHub Actions 运行环境正常，缓存已清理
- **When**: 触发完整的 Flutter CI 工作流
- **Then**: 所有 Android 架构任务都显示绿色成功状态
- **Verification**: `programmatic` (通过 GitHub Actions API 检查构建状态)

### AC-4: Linux 平台继续成功
- **Given**: 完成了其他平台的修复
- **When**: 触发完整的 Flutter CI 工作流
- **Then**: Linux x86_64 和 aarch64 任务仍能成功构建
- **Verification**: `programmatic` (通过 GitHub Actions API 检查构建状态)

### AC-5: 产物正确生成
- **Given**: 所有平台构建成功
- **When**: 查看构建产物
- **Then**: 所有平台的安装包/二进制文件都已正确生成并上传
- **Verification**: `human-judgment` (检查 Actions 页面的 Artifacts)

### AC-6: 缓存正常工作
- **Given**: 有成功构建的缓存
- **When**: 重新触发相同的构建
- **Then**: 构建时间应显著减少（缓存命中）
- **Verification**: `programmatic` (比较两次构建的时间)

## Open Questions
- [ ] Windows 平台 libyuv 构建的完整错误日志是什么？
- [ ] macOS 平台 texture_rgba_renderer Swift 头文件的具体错误是什么？
- [ ] Android 平台构建失败的具体原因是什么？
- [ ] 是否需要清理现有的 GitHub Actions 缓存来测试修复？
