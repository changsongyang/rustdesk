# 多平台条件编译打包逻辑与 CI/CD 构建体系审查报告

## 一、项目概述

RustDesk 是一个跨平台远程桌面应用，支持 Windows、macOS、Linux、iOS 和 Android 平台。本报告对其多平台条件编译打包逻辑和 CI/CD 构建体系进行全面审查。

---

## 二、条件编译体系分析

### 2.1 Cargo.toml 特性配置

| 特性名称 | 用途描述 | 平台限制 | 状态 |
|---------|---------|---------|------|
| `flutter` | Flutter UI 框架支持 | 跨平台 | ✅ |
| `hwcodec` | 硬件编解码加速 | 跨平台 | ✅ |
| `screencapturekit` | macOS 屏幕捕获框架 | **仅 macOS** | ⚠️ |
| `unix-file-copy-paste` | Unix 剪贴板文件操作 | Linux/macOS | ✅ |
| `use_dasp` | dasp 音频重采样 | 跨平台 | ✅ |
| `use_rubato` | rubato 音频重采样 | 跨平台 | ✅ |
| `use_samplerate` | samplerate 音频重采样 | 跨平台 | ✅ |
| `cli` | 命令行接口 | 跨平台 | ✅ |
| `inline` | 内嵌资源打包 | 跨平台 | ✅ |
| `vram` | VRAM 渲染优化 | 跨平台 | ✅ |
| `mediacodec` | Android MediaCodec | Android | ✅ |

### 2.2 目标平台依赖配置

```toml
# 非 Linux 平台的音频库
[target.'cfg(not(target_os = "linux"))'.dependencies]
cpal = { git = "https://github.com/rustdesk-org/cpal", branch = "osx-screencapturekit" }

# 非移动平台的桌面功能
[target.'cfg(not(any(target_os = "android", target_os = "ios")))'.dependencies]
clipboard = { path = "libs/clipboard" }
enigo = { path = "libs/enigo", features = ["with_serde"] }

# Windows 特有依赖
[target.'cfg(target_os = "windows")'.dependencies]
winapi = { version = "0.3", features = [...] }
windows = { version = "0.61", features = [...] }

# macOS 特有依赖
[target.'cfg(target_os = "macos")'.dependencies]
objc = "0.2"
cocoa = "0.24"
```

### 2.3 条件编译使用模式

**正确模式：**
```rust
#[cfg(all(feature = "screencapturekit", target_os = "macos"))]
pub fn is_screen_capture_kit_available() -> bool {
    cpal::available_hosts()
        .iter()
        .any(|host| *host == cpal::HostId::ScreenCaptureKit)
}
```

**需要修复的模式：**
```rust
// ❌ 缺少平台限制，可能导致非 macOS 平台编译失败
#[cfg(feature = "screencapturekit")]  // 应改为 #[cfg(all(feature = "screencapturekit", target_os = "macos"))]
```

---

## 三、CI/CD 多平台构建矩阵

### 3.1 支持的构建平台

| 平台 | 架构 | 构建类型 | Rust 版本 | 特殊配置 |
|------|------|----------|-----------|----------|
| Windows | x86_64 | Flutter | 1.75 | vcpkg x64-windows-static |
| Windows | i686 | Sciter | Nightly-2023-10-13 | vcpkg x86-windows-static |
| macOS | x86_64 | Flutter | 1.81 | vcpkg x64-osx |
| macOS | aarch64 | Flutter | 1.81 | vcpkg arm64-osx, ScreencaptureKit |
| iOS | aarch64 | Flutter | 1.75 | vcpkg arm64-ios |
| Android | aarch64 | Flutter | 1.75 | NDK r28c |
| Android | armv7 | Flutter | 1.75 | NDK r28c |
| Android | x86_64 | Flutter | 1.75 | NDK r28c |
| Linux | x86_64 | Flutter | 1.75 | Ubuntu 24.04 |

### 3.2 工作流依赖关系

```
┌─────────────────────────────────────────────────────────────────┐
│                    generate-bridge (通用桥接生成)                │
│                              │                                  │
├──────────────────────────────┼──────────────────────────────────┤
│                              ▼                                  │
│         ┌───────────────────┼───────────────────┐              │
│         ▼                   ▼                   ▼              │
│  build-RustDeskTempTopMostWindow  build-for-windows-flutter    │
│         │                   │                   │              │
│         ▼                   ▼                   ▼              │
│  build-for-windows-sciter  build-for-macOS    build-rustdesk-ios│
│                                              │                 │
│                                              ▼                 │
│                              build-rustdesk-android             │
│                              (aarch64, armv7, x86_64)          │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 3.3 关键环境变量

| 变量名 | 值 | 用途 |
|--------|-----|------|
| `RUST_VERSION` | 1.75 | 通用 Rust 工具链版本 |
| `MAC_RUST_VERSION` | 1.81 | macOS 专用版本（cidre 需求） |
| `SCITER_RUST_VERSION` | 1.75 | Sciter UI 版本 |
| `FLUTTER_VERSION` | 3.24.5 | Flutter SDK 版本 |
| `NDK_VERSION` | r28c | Android NDK 版本 |
| `VCPKG_COMMIT_ID` | 120deac... | vcpkg 版本锁定 |

---

## 四、问题分析与修复记录

### 4.1 已修复问题

| 问题编号 | 问题描述 | 修复位置 | 修复方式 |
|---------|---------|---------|---------|
| P001 | ScreenCaptureKit 在非 macOS 平台编译失败 | `src/server/audio_service.rs` | 添加 `target_os = "macos"` 条件 |
| P002 | rubato 0.12.0 API 变更导致编译失败 | `src/common.rs` | 更新 `SincFixedIn::new()` 参数 |
| P003 | Flutter Stream 类型不匹配 | `flutter/lib/models/model.dart` | 将 `Stream<EventToUI>` 改为 `Stream<String>` |
| P004 | Linux clipboard 错误实现 | `libs/clipboard/src/platform/mod.rs` | 移除无效的 `create_cliprdr_context` |
| P005 | `bail!` 宏未导入 | `libs/hbb_common/src/verifier.rs` | 添加 `use crate::bail;` |

### 4.2 待改进问题

| 优先级 | 问题描述 | 影响范围 | 建议方案 |
|--------|---------|---------|---------|
| 高 | 32位 Windows 依赖特殊 nightly 工具链 | Windows i686 | 评估迁移到稳定版工具链 |
| 中 | Android 构建配置分散在多个文件 | Android | 统一 NDK 和构建脚本配置 |
| 中 | 特性组合测试覆盖不全 | 全平台 | 添加特性组合矩阵测试 |
| 低 | macOS minimum version 硬编码 | macOS | 提取为环境变量 |

---

## 五、构建脚本体系

### 5.1 主要构建脚本

| 脚本路径 | 用途 | 支持平台 |
|---------|------|---------|
| `build.py` | 主构建入口 | Windows/macOS/Linux |
| `flutter/ndk_arm64.sh` | Android ARM64 构建 | Linux |
| `flutter/ndk_arm.sh` | Android ARMv7 构建 | Linux |
| `flutter/ndk_x86.sh` | Android x86 构建 | Linux |
| `flutter/ndk_x64.sh` | Android x86_64 构建 | Linux |
| `flutter/build_android.sh` | Android APK 打包 | Linux |
| `flutter/build_ios.sh` | iOS IPA 打包 | macOS |
| `flutter/build_fdroid.sh` | F-Droid 构建 | Linux |

### 5.2 典型构建命令

```bash
# Windows Flutter 构建
python3 build.py --portable --hwcodec --flutter --vram

# macOS Flutter 构建（带 ScreencaptureKit）
./build.py --flutter --hwcodec --unix-file-copy-paste --screencapturekit

# Android ARM64 构建
cargo ndk --platform 21 --target aarch64-linux-android build --release --features flutter,hwcodec

# Linux 构建
./build.py --flutter --hwcodec
```

---

## 六、最佳实践建议

### 6.1 条件编译规范

**规则 1：平台特定代码必须使用 `target_os` 条件**
```rust
// ✅ 正确
#[cfg(target_os = "windows")]
fn windows_specific_function() { /* ... */ }

// ❌ 错误 - 缺少平台限制
#[cfg(feature = "screencapturekit")]  // 应添加 target_os = "macos"
```

**规则 2：特性与平台条件组合使用**
```rust
#[cfg(all(feature = "screencapturekit", target_os = "macos"))]
fn screen_capture_kit_impl() { /* ... */ }
```

**规则 3：使用 `cfg-if` 宏处理复杂条件**
```rust
cfg_if::cfg_if! {
    if #[cfg(target_os = "windows")] {
        type PlatformClipboard = WindowsClipboard;
    } else if #[cfg(target_os = "macos")] {
        type PlatformClipboard = MacosClipboard;
    } else {
        type PlatformClipboard = LinuxClipboard;
    }
}
```

### 6.2 CI/CD 优化建议

**建议 1：统一版本管理**
```yaml
env:
  RUST_VERSIONS:
    windows: "1.75"
    macos: "1.81"
    linux: "1.75"
  
  FLUTTER_VERSION: "3.24.5"
  NDK_VERSION: "r28c"
```

**建议 2：使用矩阵策略统一平台配置**
```yaml
strategy:
  matrix:
    include:
      - os: windows-2022
        target: x86_64-pc-windows-msvc
        rust-version: "1.75"
        flutter-features: "--flutter --hwcodec --vram"
      
      - os: macos-14
        target: aarch64-apple-darwin
        rust-version: "1.81"
        flutter-features: "--flutter --hwcodec --screencapturekit"
```

**建议 3：增强错误处理和日志**
```bash
# 在构建脚本中添加详细日志
set -x  # 启用命令追踪
exec > >(tee -i build.log) 2>&1  # 输出到日志文件
```

### 6.3 依赖管理建议

**建议 1：使用固定版本而非分支**
```toml
# ✅ 推荐：使用固定 commit
cpal = { git = "https://github.com/rustdesk-org/cpal", rev = "6b374bcaed076750ca8fce6da518ab39b882e14a" }

# ⚠️ 谨慎：使用分支可能引入意外变更
cpal = { git = "https://github.com/rustdesk-org/cpal", branch = "osx-screencapturekit" }
```

**建议 2：定期更新依赖**
- 每季度进行一次依赖版本更新
- 使用 `cargo update` 和 `cargo audit` 检查安全性
- 在 CI 中添加依赖更新提醒

---

## 七、总结

### 7.1 优点

| 维度 | 评价 | 说明 |
|------|------|------|
| 多平台支持 | ✅ 优秀 | 覆盖 5 大平台，10+ 架构 |
| 特性驱动 | ✅ 优秀 | 通过 features 灵活控制功能 |
| CI/CD 完整性 | ✅ 良好 | 自动构建、签名、发布流程 |
| 缓存优化 | ✅ 良好 | rust-cache + vcpkg 二进制缓存 |

### 7.2 改进方向

| 优先级 | 改进项 | 预期收益 |
|--------|-------|---------|
| 高 | 统一条件编译规范 | 减少跨平台编译错误 |
| 高 | 版本配置集中化 | 降低维护成本 |
| 中 | 特性组合测试 | 提高构建稳定性 |
| 中 | 错误日志增强 | 加快问题定位 |
| 低 | 文档完善 | 提升团队协作效率 |

### 7.3 建议后续行动

1. **短期**：修复剩余的条件编译问题，确保所有平台构建通过
2. **中期**：实施版本配置集中化，建立依赖更新流程
3. **长期**：完善文档体系，建立平台适配测试矩阵

---

**审查日期**: 2026-05-13  
**审查范围**: RustDesk 多平台条件编译与 CI/CD 体系  
**版本**: v1.5.2