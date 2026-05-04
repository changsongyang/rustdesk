# Flutter-Rust Bridge 代码生成指南

## 概述

本项目使用 `flutter_rust_bridge` 工具实现 Flutter (Dart) 与 Rust 之间的高效跨语言调用。代码生成器会自动生成桥接代码，简化 Dart 和 Rust 之间的数据传递和函数调用。

## 环境要求

### 必需工具

| 工具 | 版本要求 | 用途 |
|------|---------|------|
| **Rust** | >= 1.60 | Rust 编译器 |
| **Cargo** | >= 1.60 | Rust 包管理器 |
| **Flutter** | >= 3.0 | Flutter SDK |
| **Dart** | >= 3.0 | Dart SDK |
| **LLVM** | >= 14.0 | 用于 ffigen 生成 C 绑定 |
| **flutter_rust_bridge_codegen** | 1.80.1 | 桥接代码生成工具 |

### 环境变量配置

```powershell
# Windows PowerShell 配置示例
$env:LLVM_HOME = "C:\Android\LLVM"
$env:Path += ";$env:LLVM_HOME\bin"
```

## 代码生成流程

### 1. 安装代码生成器

```bash
cargo install flutter_rust_bridge_codegen --version 1.80.1 --features uuid
```

### 2. 获取 Flutter 依赖

```bash
cd flutter
flutter pub get
```

### 3. 执行代码生成

```bash
cd flutter
flutter_rust_bridge_codegen ^
  --rust-input ../src/flutter_ffi.rs ^
  --dart-output ./lib/generated_bridge.dart ^
  --c-output ./macos/Runner/bridge_generated.h ^
  --llvm-path "C:\Android\LLVM"
```

### 4. 构建 Rust 代码

```bash
cargo build --features flutter
```

### 5. 运行 Flutter 应用

```bash
flutter run
```

## 命令参数说明

| 参数 | 说明 | 示例 |
|------|------|------|
| `--rust-input` | Rust FFI 接口定义文件路径 | `../src/flutter_ffi.rs` |
| `--dart-output` | 生成的 Dart 桥接文件路径 | `./lib/generated_bridge.dart` |
| `--c-output` | 生成的 C 头文件路径（用于 macOS） | `./macos/Runner/bridge_generated.h` |
| `--llvm-path` | LLVM 安装路径 | `C:\Android\LLVM` |
| `--rust-output` | 生成的 Rust 桥接文件路径 | `../src/bridge_generated.rs` |
| `--class-name` | 生成的 Dart 类名 | `Rustdesk` |
| `--verbose` | 显示详细日志 | - |

## 生成的文件

### Rust 端文件

| 文件 | 路径 | 说明 |
|------|------|------|
| `bridge_generated.rs` | `src/` | 主要桥接代码 |
| `bridge_generated.io.rs` | `src/` | IO 相关桥接代码 |

### Dart 端文件

| 文件 | 路径 | 说明 |
|------|------|------|
| `generated_bridge.dart` | `flutter/lib/` | Dart 桥接类 |
| `generated_bridge.freezed.dart` | `flutter/lib/` | Freezed 序列化代码 |

### C 端文件

| 文件 | 路径 | 说明 |
|------|------|------|
| `bridge_generated.h` | `flutter/macos/Runner/` | macOS 平台头文件 |

## FFI 接口定义规范

### 基本函数定义

```rust
// src/flutter_ffi.rs

/// 获取应用版本
#[ffi_export]
pub fn get_version() -> String {
    env!("CARGO_PKG_VERSION").to_string()
}

/// 加法运算
#[ffi_export]
pub fn add(a: i32, b: i32) -> i32 {
    a + b
}
```

### 异步函数定义

```rust
use tokio;

/// 异步执行耗时操作
#[ffi_export]
pub async fn async_task(input: String) -> Result<String, String> {
    tokio::time::sleep(Duration::from_secs(1)).await;
    Ok(format!("Processed: {}", input))
}
```

### 复杂数据结构

```rust
use serde::{Serialize, Deserialize};

#[derive(Serialize, Deserialize)]
pub struct User {
    pub id: i32,
    pub name: String,
    pub email: String,
}

#[ffi_export]
pub fn get_user(id: i32) -> User {
    User {
        id,
        name: "John Doe".to_string(),
        email: "john@example.com".to_string(),
    }
}
```

## 常见问题及解决方案

### 问题 1: ffigen 找不到 libclang

**错误信息**:
```
[SEVERE] : Couldn't find bin\libclang.dll in specified locations.
```

**解决方案**:
```bash
# 指定 LLVM 路径
flutter_rust_bridge_codegen --llvm-path "C:\Android\LLVM" ...
```

### 问题 2: 生成的代码无法编译

**可能原因**:
- Rust 版本过低
- Flutter 版本不兼容
- 依赖包版本冲突

**解决方案**:
```bash
# 更新 Rust
rustup update

# 更新 Flutter
flutter upgrade

# 清理缓存
flutter clean
cargo clean
```

### 问题 3: 异步函数调用失败

**可能原因**:
- Tokio runtime 未正确初始化
- 缺少 `flutter` 特性

**解决方案**:
确保 Cargo.toml 中启用了 flutter 特性：
```toml
[features]
flutter = ["tokio"]
```

## 开发规范

### 代码生成原则

1. **自动生成**: 桥接代码必须通过工具自动生成，禁止手动修改
2. **接口定义**: 所有 FFI 接口必须在 `src/flutter_ffi.rs` 中定义
3. **类型安全**: 使用 Rust 的类型系统确保类型安全
4. **错误处理**: 使用 `Result<T, E>` 处理错误情况

### 目录结构

```
rustdesk/
├── src/
│   ├── flutter_ffi.rs      # FFI 接口定义（手动编写）
│   ├── bridge_generated.rs # 生成的桥接代码（自动生成）
│   └── bridge_generated.io.rs
└── flutter/
    ├── lib/
    │   ├── generated_bridge.dart        # 生成的 Dart 代码
    │   └── generated_bridge.freezed.dart
    └── macos/Runner/
        └── bridge_generated.h           # 生成的 C 头文件
```

### 修改流程

1. 修改 `src/flutter_ffi.rs` 中的接口定义
2. 重新运行代码生成命令
3. 更新 Dart 端调用代码
4. 测试验证

## 版本管理

### 当前版本

| 组件 | 版本 |
|------|------|
| flutter_rust_bridge | 1.80.1 |
| flutter_rust_bridge_codegen | 1.80.1 |
| ffigen | 8.0.2 |

### 版本升级注意事项

1. 升级前备份现有生成的代码
2. 更新 `flutter_rust_bridge_codegen`
3. 更新 `pubspec.yaml` 中的依赖版本
4. 重新生成代码并测试

## 参考链接

- [flutter_rust_bridge GitHub](https://github.com/fzyzcjy/flutter_rust_bridge)
- [Dart FFI Documentation](https://dart.dev/guides/libraries/c-interop)
- [Rust FFI Documentation](https://doc.rust-lang.org/nomicon/ffi.html)
