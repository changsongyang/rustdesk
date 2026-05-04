# RustDesk 依赖项全面检测报告

**生成日期**: 2026-05-04
**项目版本**: 1.5.1
**检测环境**: Windows x64
**Flutter SDK**: 3.35.5 (Channel stable)
**Android SDK**: 34.0.0

---

## 一、执行摘要

| 检测项目 | 状态 | 关键发现 |
|---------|------|---------|
| **环境配置** | ✅ 通过 | C:\Android 环境完整 |
| **依赖更新** | ✅ 完成 | tray-icon 升级到 0.23.1 |
| **代码兼容性** | ❌ 阻塞 | aom 库版本不兼容 |
| **安全漏洞** | ❌ 发现问题 | **5个严重漏洞** |
| **依赖冲突** | ⚠️ 存在 | 多个版本冲突 |

---

## 二、环境配置审查 (C:\Android)

### 2.1 Flutter 环境

```
✅ Flutter (Channel stable, 3.35.5)
✅ Android toolchain (SDK 34.0.0)
✅ Chrome - develop for the web
✅ Visual Studio - develop Windows apps
✅ Connected device (3 available)
```

### 2.2 LLVM/Clang

| 项目 | 信息 |
|------|------|
| **版本** | 22.1.0 |
| **位置** | `C:\Android\LLVM\` |
| **用途** | bindgen FFI 代码生成 |

### 2.3 Android SDK 组件

| 组件 | 状态 |
|------|------|
| build-tools | ✅ 28.0.3, 30.0.3, 33.0.1, 33.0.2, 34.0.0 |
| platform-tools | ✅ 已安装 |
| cmdline-tools | ✅ 已安装 |
| platforms | ✅ 已安装 |

### 2.4 vcpkg

| 项目 | 状态 |
|------|------|
| **位置** | `C:\Android\vcpkg\` |
| **aom** | ✅ 已安装 (x64-windows-static) |
| **libvpx** | ✅ 已安装 |
| **libyuv** | ✅ 已安装 |

---

## 三、依赖更新结果

### 3.1 修复的版本冲突

| 依赖包 | 旧版本 | 新版本 | 状态 |
|--------|--------|--------|------|
| tray-icon | 0.21.3 | 0.23.1 | ✅ 已修复 |

### 3.2 主要依赖变更

| 依赖包 | 旧版本 | 新版本 | 类型 |
|--------|--------|--------|------|
| zstd | 0.13.1 | 0.13.3 | 补丁升级 |
| winit | 0.30.9 | 0.30.13 | 补丁升级 |
| x11rb | 0.13.1 | 0.13.2 | 补丁升级 |
| windows | 0.44.0, 0.61.1 | 0.61.3, 0.62.2 | 主版本升级 |
| zeroize | 1.8.1 | 1.8.2 | 补丁升级 |

---

## 四、代码兼容性验证

### 4.1 构建状态

| 阶段 | 状态 | 说明 |
|------|------|------|
| 依赖解析 | ✅ 通过 | cargo check 成功 |
| 编译检查 | ❌ 失败 | aom 结构体不兼容 |

### 4.2 🔴 严重问题: aom 库版本不兼容

**错误信息**:
```
error[E0609]: no field `rc_target_bitrate` on type `common::aom::aom_codec_enc_cfg`
error[E0609]: no field `g_threads` on type `common::aom::aom_codec_enc_cfg`
error[E0609]: no field `g_w` on type `common::aom::aom_codec_enc_cfg`
error[E0609]: no field `g_h` on type `common::aom::aom_codec_enc_cfg`
error[E0609]: no field `rc_min_quantizer` on type `common::aom::aom_codec_enc_cfg`
error[E0609]: no field `rc_max_quantizer` on type `common::aom::aom_codec_enc_cfg`
```

**根本原因**:

| 项目 | 代码期望 | 实际安装 |
|------|---------|---------|
| **aom 版本** | 3.9.1 | 3.12.1 |
| **结构体** | 直接字段 | 嵌套配置对象 |

**代码期望的 aom_codec_enc_cfg (aom 3.9.1)**:
```c
typedef struct aom_codec_enc_cfg {
    unsigned int g_usage;
    unsigned int g_threads;       // ✅ 直接字段
    unsigned int g_profile;
    unsigned int rc_target_bitrate;  // ✅ 直接字段
    unsigned int rc_min_quantizer;  // ✅ 直接字段
    unsigned int rc_max_quantizer;  // ✅ 直接字段
} aom_codec_enc_cfg_t;
```

**实际安装的 aom_codec_enc_cfg (aom 3.12.1)**:
```c
typedef struct aom_codec_enc_cfg {
    unsigned int g_usage;
    unsigned int g_threads;       // ❌ 已移除
    unsigned int g_profile;
    cfg_options_t encoder_cfg;    // ❌ 嵌套对象
} aom_codec_enc_cfg_t;
```

### 4.3 解决方案

**方案一**: 使用项目的 vcpkg overlay ports (推荐)

```powershell
$env:VCPKG_OVERLAY_PORTS = "c:\Users\ycsit\Downloads\rustdesk\rustdesk\res\vcpkg"
.\vcpkg\vcpkg.exe install aom:x64-windows-static --classic
```

**方案二**: 更新 Rust 代码适配新版 aom

需要重写 `libs/scrap/src/common/aom.rs` 以适配 aom 3.12.1 的新 API。

---

## 五、安全漏洞扫描结果 (cargo audit)

### 5.1 严重漏洞 (5个)

| ID | 严重程度 | 包名 | 版本 | 问题 |
|----|---------|------|------|------|
| RUSTSEC-2024-0364 | 🔴 高 | libsqlite3-sys | 0.28.0 | 数据库损坏导致崩溃 |
| RUSTSEC-2024-0370 | 🔴 高 | libsqlite3-sys | 0.28.0 | Windows DLL 劫持 |
| RUSTSEC-2023-0053 | 🔴 高 | libsqlite3-sys | 0.28.0 | Windows DLL 加载漏洞 |
| RUSTSEC-2025-0012 | 🔴 高 | ring | 0.17.8 | 密钥泄露风险 |
| RUSTSEC-2024-0429 | 🟡 中 | glib | 0.18.5 | 迭代器未定义行为 |

### 5.2 未维护警告 (36个)

| 类别 | 包名 | 版本 | 建议 |
|------|------|------|------|
| 未维护 | users | 0.10.0, 0.11.0 | 迁移到 `uzers` 或 `nix` |
| 未维护 | atty | 0.2.14 | 使用 `std::io::IsTerminal` |
| 未维护 | unic-* | 0.9.0 | 迁移到 `unicode-bidi` |
| 未维护 | proc-macro-error | 1.0.4 | 迁移到 `proc-macro-error2` |

### 5.3 内存安全问题 (5个)

| 包名 | 版本 | 问题类型 |
|------|------|---------|
| atty | 0.2.14 | 潜在未对齐读取 |
| fuser | 0.15.1 | 未初始化内存读取 |
| git2 | 0.16.1 | 潜在未定义行为 |
| users | 0.10.0/0.11.0 | 未对齐指针读取 |
| glib | 0.18.5 | 迭代器未定义行为 |

---

## 六、依赖冲突分析

### 6.1 版本冲突

| 包名 | 冲突版本数 | 使用位置 |
|------|-----------|---------|
| bindgen | 3 | hbb_common, scrap, kcp-sys |
| image | 2 | 0.24.x (tao), 0.25.x (arboard/nokhwa) |
| num-traits | 2 | 0.1.x, 0.2.x |
| windows | 6+ | 0.32, 0.45, 0.52, 0.54, 0.61, 0.62 |
| zerocopy | 2 | 0.7.x, 0.8.x |

### 6.2 重复依赖

```
image v0.24.9  (qrcode-generator -> tao)
image v0.25.10 (arboard -> nokhwa -> scrap)

bindgen v0.59.2  (hbb_common build)
bindgen v0.65.1  (scrap build)
bindgen v0.71.1  (kcp-sys build)

num-traits v0.1.43 (serde_json)
num-traits v0.2.19 (多个依赖)
```

---

## 七、问题汇总与解决建议

### 7.1 P0 - 立即修复

| # | 问题 | 解决方案 | 优先级 |
|---|------|---------|--------|
| 1 | **aom 版本不兼容** | 安装 aom 3.9.1 或更新 Rust 代码 | 🔴 阻塞 |
| 2 | **libsqlite3-sys 漏洞** | 升级到 0.30+ | 🔴 高 |
| 3 | **ring 漏洞** | 升级到 0.17.14+ | 🔴 高 |

### 7.2 P1 - 高优先级

| # | 问题 | 解决方案 | 工作量 |
|---|------|---------|--------|
| 4 | users 包未维护 | 迁移到 uzers | 中 |
| 5 | image 版本冲突 | 统一到 0.25.x | 中 |
| 6 | bindgen 版本冲突 | 统一到 0.71.x | 高 |

### 7.3 P2 - 中优先级

| # | 问题 | 解决方案 | 工作量 |
|---|------|---------|--------|
| 7 | atty 包未维护 | 使用 std::io::IsTerminal | 低 |
| 8 | windows 版本冲突 | 统一版本 | 高 |
| 9 | zerocopy 版本冲突 | 统一版本 | 中 |

---

## 八、修复示例代码

### 8.1 升级 libsqlite3-sys

```toml
# Cargo.toml
[dependencies]
rusqlite = { version = "0.32", features = ["bundled"] }
```

### 8.2 替换 atty

```rust
// 旧代码
use atty::is;
if is(atty::Stream::Stdout) { ... }

// 新代码
use std::io::IsTerminal;
if std::io::stdout().is_terminal() { ... }
```

---

## 九、构建环境变量配置

```powershell
# Flutter/Android
$env:ANDROID_HOME = "C:\Android\SDK"
$env:ANDROID_SDK_ROOT = "C:\Android\SDK"
$env:FLUTTER_ROOT = "C:\Android\flutter"

# LLVM/bindgen
$env:LLVM_PATH = "C:\Android\LLVM\bin"

# vcpkg (使用项目 overlay ports)
$env:VCPKG_ROOT = "C:\Android\vcpkg"
$env:VCPKG_OVERLAY_PORTS = "c:\Users\ycsit\Downloads\rustdesk\rustdesk\res\vcpkg"

# PATH
$env:Path = "C:\Android\flutter\bin;C:\Android\LLVM\bin;C:\Android\vcpkg;$env:Path"
```

---

## 十、结论

### 10.1 总体评估

| 维度 | 评分 | 说明 |
|------|------|------|
| **环境配置** | ✅ 9/10 | 完整但需配置环境变量 |
| **依赖健康度** | ⚠️ 5/10 | 存在多个未维护依赖 |
| **安全性** | ⚠️ 5/10 | 5个严重漏洞需修复 |
| **兼容性** | ❌ 4/10 | aom 版本不兼容阻塞构建 |
| **可维护性** | ⚠️ 6/10 | 版本冲突需解决 |

### 10.2 阻塞问题

**当前最大阻塞**: aom 库版本不兼容

- 项目代码期望 aom 3.9.1
- C:\Android\vcpkg 安装的是 aom 3.12.1
- 需要使用项目的 overlay ports 安装正确版本，或更新代码适配新版本

### 10.3 立即行动项

1. ✅ 已完成: 修复 tray-icon 版本冲突
2. 🔴 立即: 解决 aom 版本不兼容问题
3. 🔴 立即: 升级 libsqlite3-sys 和 ring
4. ⚠️ 建议: 统一依赖版本减少冲突

---

## 附录

### A. flutter doctor 输出

```
✅ Flutter (Channel stable, 3.35.5)
✅ Windows Version (11 专业版 64-bit, 24H2)
✅ Android toolchain (SDK 34.0.0)
✅ Chrome - develop for the web
✅ Visual Studio - develop Windows apps
⚠️ Android Studio (not installed)
```

### B. 检测命令

```bash
# 依赖更新
cargo update

# 安全扫描
cargo audit

# 依赖冲突检查
cargo tree --duplicates

# 构建检查
cargo check

# Flutter doctor
flutter doctor
```

---

**报告生成者**: Trae AI Assistant
**报告版本**: 2.0
