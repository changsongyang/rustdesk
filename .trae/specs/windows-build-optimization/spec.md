# Windows 多架构打包构建优化 - 产品需求文档

## Overview
- **Summary**: 优化 RustDesk Windows 平台的多架构打包构建流程，支持 Flutter 和 Sciter 两个 UI 版本，确保构建合规性和稳定性。
- **Purpose**: 解决当前 CI/CD 构建中存在的 LLVM 架构匹配问题、代码重复问题，提升构建可靠性和可维护性。
- **Target Users**: 开发团队、CI/CD 维护人员

## Goals
- 确保 Windows i686 和 x86_64 架构的 Flutter 构建稳定通过
- 确保 Windows i686 和 x86_64 架构的 Sciter 构建稳定通过
- 消除代码重复，提升工作流可维护性
- 确保所有构建步骤符合合规要求

## Non-Goals (Out of Scope)
- 不涉及 macOS、Linux、Android、iOS 平台的构建优化
- 不涉及功能代码的修改，仅优化构建流程
- 不改变构建产物的功能特性

## Background & Context
- 当前构建存在 LLVM 架构不匹配问题，导致 `libclang.dll` 无法正确加载
- 构建工作流中存在大量重复代码，难以维护
- 需要确保 Flutter 和 Sciter 两个版本都能正常构建

## Functional Requirements
- **FR-1**: 支持 Windows i686 架构的 Flutter 构建
- **FR-2**: 支持 Windows x86_64 架构的 Flutter 构建
- **FR-3**: 支持 Windows i686 架构的 Sciter 构建
- **FR-4**: 支持 Windows x86_64 架构的 Sciter 构建
- **FR-5**: 提取公共构建步骤为可复用的 Action
- **FR-6**: 确保 LLVM 安装和路径配置正确

## Non-Functional Requirements
- **NFR-1**: 构建成功率 ≥ 95%
- **NFR-2**: 代码重复率 ≤ 10%
- **NFR-3**: 构建日志清晰，便于问题排查
- **NFR-4**: 符合 GitHub Actions 最佳实践

## Constraints
- **Technical**: 必须使用 GitHub Actions，保持现有技术栈
- **Dependencies**: 依赖 `KyleMayes/install-llvm-action`、`dtolnay/rust-toolchain` 等第三方 Action

## Assumptions
- GitHub Actions 运行器环境配置正确
- 网络连接稳定，能够下载所需依赖
- 代码仓库结构保持不变

## Acceptance Criteria

### AC-1: Flutter i686 构建成功
- **Given**: 触发构建工作流
- **When**: 构建 Windows i686 Flutter 版本
- **Then**: 构建成功完成，生成 `rustdesk-*.exe` 和 `rustdesk-*.msi`
- **Verification**: `programmatic`
- **Notes**: 需要正确配置 LLVM 32位版本

### AC-2: Flutter x86_64 构建成功
- **Given**: 触发构建工作流
- **When**: 构建 Windows x86_64 Flutter 版本
- **Then**: 构建成功完成，生成 `rustdesk-*.exe` 和 `rustdesk-*.msi`
- **Verification**: `programmatic`
- **Notes**: 需要正确配置 LLVM 64位版本

### AC-3: Sciter i686 构建成功
- **Given**: 触发构建工作流
- **When**: 构建 Windows i686 Sciter 版本
- **Then**: 构建成功完成，生成 `rustdesk-*-sciter.exe`
- **Verification**: `programmatic`

### AC-4: Sciter x86_64 构建成功
- **Given**: 触发构建工作流
- **When**: 构建 Windows x86_64 Sciter 版本
- **Then**: 构建成功完成，生成 `rustdesk-*-sciter.exe`
- **Verification**: `programmatic`

### AC-5: 代码重复消除
- **Given**: 审查工作流代码
- **When**: 检查 Flutter 和 Sciter 构建步骤
- **Then**: 公共步骤提取为可复用 Action，代码重复率 ≤ 10%
- **Verification**: `human-judgment`

### AC-6: LLVM 配置正确
- **Given**: 运行构建工作流
- **When**: LLVM 安装和路径配置步骤执行
- **Then**: `LIBCLANG_PATH` 正确设置，`libclang.dll` 能够被找到
- **Verification**: `programmatic`

## Open Questions
- [ ] 是否需要支持 ARM64 架构？
- [ ] 是否需要添加更多的构建验证步骤？