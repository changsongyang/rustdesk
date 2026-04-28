# FFI 绑定修补机制

## 背景

由于 `bindgen` 在处理复杂的 C 结构体（特别是包含宏、位域或条件编译的结构体）时存在局限性，生成的 Rust 绑定可能不完整。具体表现为结构体只包含 `_address: u8` 字段，导致无法访问实际的 API 字段。

在 RustDesk 项目中，这影响了以下库的绑定：
- **aom** (3.12.1) - AV1 编解码器
- **libvpx** (1.15.2) - VP8/VP9 编解码器

## 解决方案

在 `build.rs` 中实现自动化的绑定修补机制：

1. **生成绑定**：使用 `bindgen` 生成初始的 FFI 绑定
2. **正则匹配**：使用正则表达式匹配不完整的结构体定义
3. **替换修补**：用完整的结构体定义替换不完整的定义
4. **持久化**：将修补后的绑定写入输出文件

## 修补的结构体

### AOM 结构体

| 结构体名称 | 用途 | 修补的字段 |
|-----------|------|-----------|
| `aom_codec_enc_cfg` | 编码器配置 | `g_w`, `g_h`, `g_threads`, `rc_target_bitrate` 等 |
| `aom_codec_dec_cfg` | 解码器配置 | `threads`, `w`, `h`, `allow_lowbitdepth` 等 |

### VPX 结构体

| 结构体名称 | 用途 | 修补的字段 |
|-----------|------|-----------|
| `vpx_codec_enc_cfg` | 编码器配置 | `g_w`, `g_h`, `g_threads`, `rc_target_bitrate` 等 |
| `vpx_codec_dec_cfg` | 解码器配置 | `threads`, `w`, `h` 等 |

## 实现细节

### 修补流程

```
┌─────────────────────────────────────────────────────────────┐
│  build.rs                                                  │
├─────────────────────────────────────────────────────────────┤
│  1. 运行 bindgen 生成原始绑定                               │
│  2. 读取生成的绑定文件内容                                  │
│  3. 应用 VPX 绑定修补                                      │
│  4. 应用 AOM 绑定修补                                      │
│  5. 将修补后的内容写回文件                                  │
└─────────────────────────────────────────────────────────────┘
```

### 关键代码

```rust
fn patch_vpx_bindings(content: &str) -> String {
    let mut patched = content.to_string();
    
    // 使用正则匹配并替换不完整的结构体
    let enc_cfg_regex = Regex::new(r"pub struct vpx_codec_enc_cfg \{\s*pub _address: u8,\s*\}").unwrap();
    patched = enc_cfg_regex.replace(&patched, FULL_VPX_ENC_CFG_DEFINITION).to_string();
    
    let dec_cfg_regex = Regex::new(r"pub struct vpx_codec_dec_cfg \{\s*pub _address: u8,\s*\}").unwrap();
    patched = dec_cfg_regex.replace(&patched, FULL_VPX_DEC_CFG_DEFINITION).to_string();
    
    patched
}
```

## 版本锁定

在 `vcpkg.json` 中锁定了依赖版本，确保修补机制的兼容性：

```json
"overrides": [
    {
        "name": "aom",
        "version": "3.12.1"
    },
    {
        "name": "libvpx",
        "version": "1.15.2"
    }
]
```

## 测试验证

创建了测试文件 `tests/binding_test.rs` 来验证修补后的绑定是否正确工作：

```rust
#[test]
fn test_aom_bindings_patched() {
    let mut enc_cfg: aom_codec_enc_cfg = unsafe { std::mem::zeroed() };
    enc_cfg.g_w = 1920;
    enc_cfg.g_h = 1080;
    // ... 验证字段访问正常
}
```

运行测试：
```bash
cd libs/scrap && cargo test --target x86_64-pc-windows-msvc --test binding_test
```

## 维护说明

### 当库版本升级时

1. 检查新版本的结构体定义是否发生变化
2. 更新 `vcpkg.json` 中的版本号
3. 更新 `build.rs` 中的结构体定义以匹配新版本
4. 更新测试以验证新的结构体字段

### 常见问题

#### 问题：修补没有生效
**原因**：正则表达式模式与生成的绑定格式不匹配
**解决**：检查 `target/.../out/` 目录中的生成文件，调整正则模式

#### 问题：编译时字段不存在
**原因**：修补的结构体定义与实际 C 库不匹配
**解决**：检查 C 库头文件中的结构体定义，更新修补代码

#### 问题：链接错误
**原因**：vcpkg 没有正确安装依赖或版本不匹配
**解决**：运行 `vcpkg install` 确保依赖正确安装

## 相关文件

| 文件路径 | 说明 |
|---------|------|
| `build.rs` | 绑定生成和修补逻辑 |
| `Cargo.toml` | 添加了 `regex` 构建依赖 |
| `vcpkg.json` | 版本锁定配置 |
| `src/common/aom.rs` | AOM 编解码器实现 |
| `src/common/vpxcodec.rs` | VPX 编解码器实现 |
| `tests/binding_test.rs` | 绑定测试 |
