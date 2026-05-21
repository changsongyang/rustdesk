# RustDesk 开发手册

## 目录

1. [概述](#1-概述)
2. [架构设计](#2-架构设计)
3. [技术栈选型](#3-技术栈选型)
4. [编码规范](#4-编码规范)
5. [开发环境搭建](#5-开发环境搭建)
6. [API 接口文档](#6-api-接口文档)
7. [数据库设计](#7-数据库设计)
8. [模块划分](#8-模块划分)
9. [开发流程](#9-开发流程)

---

## 1. 概述

### 1.1 项目简介

RustDesk 是一款开源远程桌面软件，支持多种平台，提供安全、高效的远程访问能力。

### 1.2 项目定位

- **目标用户**: 个人用户、企业用户、开发者
- **核心价值**: 安全、高效、跨平台的远程桌面解决方案
- **竞争优势**: 开源免费、端到端加密、高性能

### 1.3 文档目的

本手册旨在帮助开发团队成员快速理解项目架构、技术栈和开发流程，确保开发工作遵循统一标准。

---

## 2. 架构设计

### 2.1 整体架构

```
┌─────────────────────────────────────────────────────────────────┐
│                        架构层次                                │
├─────────────────────────────────────────────────────────────────┤
│  UI 层 (Flutter)                                              │
│  ├── 桌面端 UI (Linux/macOS/Windows)                          │
│  └── 移动端 UI (iOS/Android)                                  │
├─────────────────────────────────────────────────────────────────┤
│  业务逻辑层 (Rust)                                            │
│  ├── 连接管理                                                 │
│  ├── 屏幕捕获                                                 │
│  ├── 输入控制                                                 │
│  ├── 音频处理                                                 │
│  └── 文件传输                                                 │
├─────────────────────────────────────────────────────────────────┤
│  网络层 (Rust)                                                │
│  ├── 自定义协议实现                                           │
│  ├── 加密通信                                                 │
│  ├── P2P 连接                                                 │
│  └── 中继服务器支持                                           │
├─────────────────────────────────────────────────────────────────┤
│  平台适配层                                                   │
│  ├── Linux 平台                                               │
│  ├── macOS 平台                                               │
│  ├── Windows 平台                                             │
│  ├── Android 平台                                             │
│  └── iOS 平台                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 2.2 核心组件

| 组件 | 职责 | 技术实现 |
|------|------|----------|
| rendezvous_mediator | 中继服务器协议 | Rust |
| scrap | 屏幕捕获 | Rust + 平台特定代码 |
| enigo | 输入控制 | Rust |
| clipboard | 剪贴板管理 | Rust |
| hwcodec | 硬件编解码 | C++/Rust |

### 2.3 数据流

```
客户端连接请求 → 中继服务器 → 目标端响应 → P2P 建立 → 数据传输
```

---

## 3. 技术栈选型

### 3.1 语言

| 语言 | 用途 | 版本 |
|------|------|------|
| Rust | 核心业务逻辑、网络层 | 1.81.0 |
| Dart | Flutter UI | 3.24.5 |
| C++ | 硬件编解码 | C++17 |

### 3.2 框架

| 框架 | 用途 | 版本 |
|------|------|------|
| Flutter | 跨平台 UI | 3.24.5 |
| Tokio | Rust 异步运行时 | 1.x |
| gRPC | 远程过程调用 | 1.x |

### 3.3 工具

| 工具 | 用途 |
|------|------|
| Cargo | Rust 包管理 |
| vcpkg | C++ 依赖管理 |
| CMake | C++ 构建系统 |
| Git | 版本控制 |

---

## 4. 编码规范

### 4.1 Rust 编码规范

#### 4.1.1 命名规范

- **模块/文件**: 蛇形命名 (`snake_case`)
- **结构体/枚举**: 驼峰命名 (`CamelCase`)
- **函数/方法**: 蛇形命名 (`snake_case`)
- **常量**: 大写下划线 (`UPPER_CASE`)

#### 4.1.2 错误处理

- 避免使用 `unwrap()` / `expect()` 在生产代码中
- 优先使用 `Result` + `?` 或显式处理
- 不要忽略错误

#### 4.1.3 内存管理

- 避免不必要的 `.clone()`
- 优先使用借用

#### 4.1.4 Tokio 规则

- 假设 Tokio 运行时已存在
- 不要创建嵌套运行时
- 不要在 async 代码中调用 `Runtime::block_on()`
- 不要在 `.await` 期间持有锁

### 4.2 Dart/Flutter 编码规范

#### 4.2.1 命名规范

- **文件**: 蛇形命名 (`snake_case`)
- **类/枚举**: 帕斯卡命名 (`PascalCase`)
- **函数/变量**: 驼峰命名 (`camelCase`)
- **常量**: 大写下划线 (`UPPER_CASE`)

#### 4.2.2 代码风格

- 使用 `const` 代替 `final` 用于编译时常量
- 优先使用不可变变量
- Widget 构建方法中避免复杂逻辑

### 4.3 Git 提交规范

采用 Conventional Commits 格式：

```
<type>(<scope>): <description>

[optional body]

[optional footer(s)]
```

**类型**:
- `feat`: 新功能
- `fix`: 修复 bug
- `docs`: 文档更新
- `style`: 代码格式
- `refactor`: 重构
- `test`: 测试
- `chore`: 构建/工具

---

## 5. 开发环境搭建

### 5.1 环境要求

| 依赖 | 最低版本 | 说明 |
|------|----------|------|
| Rust | 1.81.0 | 核心语言 |
| Cargo | 1.81.0 | 包管理器 |
| Flutter | 3.24.5 | UI 框架 |
| Git | 2.0+ | 版本控制 |
| Python | 3.8+ | 构建脚本 |

### 5.2 安装步骤

#### 5.2.1 安装 Rust

```bash
# Linux/macOS
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source "$HOME/.cargo/env"

# Windows
# 从 https://www.rust-lang.org/tools/install 下载安装程序
```

#### 5.2.2 安装 Flutter

```bash
# Linux/macOS
git clone https://github.com/flutter/flutter.git
export PATH="$PATH:`pwd`/flutter/bin"

# Windows
# 从 https://flutter.dev/docs/get-started/install 下载
```

#### 5.2.3 安装其他依赖

```bash
# Linux (Ubuntu/Debian)
sudo apt-get install build-essential libssl-dev libgtk-3-dev

# macOS
brew install nasm yasm

# Windows
# 安装 Visual Studio Build Tools
```

#### 5.2.4 克隆仓库

```bash
git clone https://github.com/rustdesk/rustdesk.git
cd rustdesk
git submodule update --init --recursive
```

### 5.3 验证环境

```bash
# 检查 Rust 版本
rustc --version

# 检查 Flutter 版本
flutter --version

# 检查依赖
./scripts/build/check-deps.sh
```

---

## 6. API 接口文档

### 6.1 接口分类

| 类别 | 说明 |
|------|------|
| 核心协议 | 自定义远程桌面协议 |
| gRPC | 服务端通信 |
| REST | Web API |

### 6.2 核心协议

#### 6.2.1 协议结构

```
+----------------+----------------+----------------+
| Header (16B)  | Body Length    | Body           |
| Magic (4B)    | (4B, BE)      | (N bytes)      |
| Version (2B)  |                |                |
| Type (2B)     |                |                |
| Flags (4B)    |                |                |
| Reserved (2B) |                |                |
+----------------+----------------+----------------+
```

#### 6.2.2 消息类型

| 类型 | 说明 |
|------|------|
| 0x01 | 连接请求 |
| 0x02 | 连接响应 |
| 0x03 | 屏幕数据 |
| 0x04 | 输入事件 |
| 0x05 | 音频数据 |
| 0x06 | 文件传输 |

### 6.3 gRPC 接口

#### 6.3.1 Rendezvous Service

```protobuf
service Rendezvous {
  rpc Register(RegisterRequest) returns (RegisterResponse);
  rpc FindPeer(FindPeerRequest) returns (FindPeerResponse);
  rpc Connect(ConnectRequest) returns (stream ConnectResponse);
}
```

---

## 7. 数据库设计

### 7.1 数据库类型

| 数据库 | 用途 |
|--------|------|
| SQLite | 客户端本地存储 |
| PostgreSQL | 服务端存储（可选） |

### 7.2 客户端数据表

#### 7.2.1 peers（远程设备列表）

| 字段 | 类型 | 说明 |
|------|------|------|
| id | INTEGER | 主键 |
| name | TEXT | 设备名称 |
| id_hash | TEXT | 设备 ID 哈希 |
| ip | TEXT | IP 地址 |
| port | INTEGER | 端口 |
| last_seen | TIMESTAMP | 最后访问时间 |
| created_at | TIMESTAMP | 创建时间 |

#### 7.2.2 settings（设置）

| 字段 | 类型 | 说明 |
|------|------|------|
| key | TEXT | 设置键 |
| value | TEXT | 设置值 |
| updated_at | TIMESTAMP | 更新时间 |

---

## 8. 模块划分

### 8.1 目录结构

```
rustdesk/
├── src/                    # Rust 核心代码
│   ├── server/             # 服务端代码
│   │   ├── audio/          # 音频处理
│   │   ├── clipboard/      # 剪贴板
│   │   ├── input/          # 输入控制
│   │   ├── video/          # 视频处理
│   │   └── network/        # 网络通信
│   ├── platform/           # 平台适配
│   └── ui/                 # Legacy UI (deprecated)
├── flutter/                # Flutter UI
│   ├── lib/
│   │   ├── desktop/        # 桌面端 UI
│   │   ├── mobile/         # 移动端 UI
│   │   └── common/         # 共享代码
├── libs/                   # 共享库
│   ├── hbb_common/         # 通用工具
│   ├── scrap/              # 屏幕捕获
│   ├── enigo/              # 输入控制
│   └── clipboard/          # 剪贴板
└── scripts/                # 脚本
    ├── build/              # 构建脚本
    └── ci/                 # CI/CD 脚本
```

### 8.2 模块职责

| 模块 | 职责 |
|------|------|
| hbb_common | 配置、协议、共享工具 |
| scrap | 跨平台屏幕捕获 |
| enigo | 跨平台输入控制 |
| clipboard | 跨平台剪贴板 |
| hwcodec | 硬件编解码 |

---

## 9. 开发流程

### 9.1 分支管理

采用 Git Flow 工作流：

```
main          # 主分支
├── develop   # 开发分支
│   ├── feature/*  # 功能分支
│   └── bugfix/*   # Bug 修复分支
└── release/* # 发布分支
```

### 9.2 开发流程

#### 9.2.1 创建功能分支

```bash
git checkout develop
git pull origin develop
git checkout -b feature/my-new-feature
```

#### 9.2.2 开发并提交

```bash
# 编写代码
git add .
git commit -m "feat(module): add new feature"
```

#### 9.2.3 推送并创建 PR

```bash
git push origin feature/my-new-feature
# 在 GitHub 创建 Pull Request
```

#### 9.2.4 代码审查

- PR 需要至少 1 个审核通过
- 所有测试必须通过
- 代码风格检查通过

#### 9.2.5 合并到 develop

```bash
git checkout develop
git merge --no-ff feature/my-new-feature
git push origin develop
```

### 9.3 代码审查标准

1. **正确性**: 代码是否正确实现功能
2. **可读性**: 代码是否易于理解
3. **性能**: 是否存在性能问题
4. **安全性**: 是否存在安全隐患
5. **测试**: 是否有足够的测试覆盖

### 9.4 测试流程

```bash
# 运行单元测试
cargo test

# 运行集成测试
cargo test --features integration

# Flutter 测试
flutter test
```

---

## 更新日志

### v1.0.0 (2024-01-01)
- 初始版本发布
- 包含架构设计、技术栈、编码规范、开发环境、API文档、数据库设计、模块划分、开发流程