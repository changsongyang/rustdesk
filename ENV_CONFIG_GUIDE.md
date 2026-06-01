# GitHub Actions 环境变量配置说明

## 问题分析

当前实现的问题：
1. `build.rs` 中存在硬编码的默认值 `rustdesk.ycsit.cn`，不符合合规要求
2. 使用 `unwrap_or_else` 会在环境变量未设置时使用默认值，导致敏感信息可能被硬编码

## 合规解决方案

### 1. 修改后的 `build.rs`

已修改为强制要求环境变量：
```rust
let custom_rendezvous = std::env::var("RENDEZVOUS_SERVER").expect("RENDEZVOUS_SERVER environment variable is required");
let custom_pub_key = std::env::var("RS_PUB_KEY").expect("RS_PUB_KEY environment variable is required");
let custom_api_server = std::env::var("API_SERVER").unwrap_or_else(|_| "https://api.rustdesk.com".to_string());

println!("cargo:rustc-env=RENDEZVOUS_SERVER={}", custom_rendezvous);
println!("cargo:rustc-env=RS_PUB_KEY={}", custom_pub_key);
println!("cargo:rustc-env=API_SERVER={}", custom_api_server);
```

### 2. 修改后的 `config.rs`

添加了三个编译期常量：
```rust
pub const RS_PUB_KEY: &str = env!("RS_PUB_KEY");
pub const RENDEZVOUS_SERVER: &str = env!("RENDEZVOUS_SERVER");
pub const API_SERVER: &str = env!("API_SERVER");

pub const RENDEZVOUS_SERVERS: &[&str] = &[RENDEZVOUS_SERVER];
```

### 3. GitHub Actions 配置要求

在 GitHub Repository Settings 中配置：

**Settings > Secrets and variables > Actions > Secrets**

添加以下 Repository secrets：
| Secret 名称 | 必填 | 默认值 | 说明 |
|------------|------|--------|------|
| `RENDEZVOUS_SERVER` | ✅ | - | ID 服务器地址（如：`your-server.com:21116`） |
| `RS_PUB_KEY` | ✅ | - | 公钥 |
| `API_SERVER` | ❌ | `https://api.rustdesk.com` | API 服务器地址 |

### 4. 工作流环境变量配置

所有工作流文件已添加环境变量配置：

```yaml
env:
  RENDEZVOUS_SERVER: "${{ secrets.RENDEZVOUS_SERVER }}"
  RS_PUB_KEY: "${{ secrets.RS_PUB_KEY }}"
  API_SERVER: "${{ secrets.API_SERVER }}"
```

**已配置的工作流文件：**
- `ci.yml` ✅
- `flutter-build.yml` ✅
- `playground.yml` ✅

### 5. 工作原理

```
GitHub Secrets 
    ↓ (注入到工作流环境)
Workflow env 块 
    ↓ (build.rs 读取)
cargo:rustc-env=... 
    ↓ (编译期注入)
config.rs env!() 宏
    ↓ (编译到二进制)
最终可执行文件
```

### 6. 代码使用示例

**src/common.rs** (第1084行)：
```rust
config::API_SERVER.to_owned()
```

**libs/hbb_common/src/lib.rs** (版本检查)：
```rust
const URL: &str = concat!(env!("API_SERVER"), "/version/latest");
```

### 7. 合规性保障

- ✅ 无硬编码敏感信息
- ✅ 使用 GitHub Secrets 安全存储
- ✅ 编译期注入，运行时不可修改
- ✅ RENDEZVOUS_SERVER 和 RS_PUB_KEY 缺失时编译失败
- ✅ API_SERVER 可选，默认值为 `https://api.rustdesk.com`
- ✅ 全程不暴露敏感信息

### 8. 配置验证

运行以下命令验证配置：

```bash
# 设置环境变量
export RENDEZVOUS_SERVER="your-server.com:21116"
export RS_PUB_KEY="your-public-key"
export API_SERVER="https://api.your-server.com"

# 编译并运行测试示例
cargo run --example verify_env -p hbb_common
```

预期输出：
```
=== 环境变量配置验证 ===

1. 编译期常量:
   RENDEZVOUS_SERVER = "your-server.com:21116"
   RS_PUB_KEY = "your-public-key"
   API_SERVER = "https://api.your-server.com"
   RENDEZVOUS_SERVERS = ["your-server.com:21116"]

2. 验证结果:
   ✅ 所有环境变量已成功注入到编译期常量
```
