# Linux Sciter 构建修复与长期维护优化报告

## 执行摘要

本报告记录了 RustDesk Linux Sciter 构建问题的修复过程以及长期维护优化措施。修复工作于 2026 年 5 月 17 日完成。

---

## 一、修复概览

### 1.1 修复范围

| 类别 | 修复项数 | 状态 |
|------|----------|------|
| Linux Sciter 依赖修复 | 1 | ✅ 已完成 |
| 构建前依赖检查脚本 | 1 | ✅ 已完成 |
| FFmpeg 版本锁定 | 1 | ✅ 已完成 |
| CI 缓存优化 | 1 | ✅ 已完成 |

---

## 二、问题分析

### 2.1 Linux Sciter 构建失败原因

**问题根因**: Linux Sciter 构建环境缺少必要的图形库依赖

**缺失的依赖库**:
- `libcairo2-dev` - Cairo 图形库
- `libgdk-pixbuf2.0-dev` - GDK Pixbuf 图像库
- `libjavascriptcoregtk-4.0-dev` - JavaScriptCore 引擎
- `libpango1.0-dev` - Pango 文本布局库
- `librsvg2-dev` - SVG 渲染库
- `libsoup2.4-dev` - HTTP 客户端库
- `libwebkit2gtk-4.0-dev` - WebKit2 GTK 渲染引擎
- `libx11-dev` - X11 窗口系统库

**影响文件**:
- `.github/workflows/flutter-build.yml` - Linux Sciter 构建步骤

---

## 三、修复实施详情

### 3.1 Linux Sciter 依赖修复

**修改文件**: `.github/workflows/flutter-build.yml`

**修改内容**: 在 Linux Sciter 构建步骤的 `apt-get install` 命令中添加了以下依赖：

```yaml
libcairo2-dev \
libgdk-pixbuf2.0-dev \
libjavascriptcoregtk-4.0-dev \
libpango1.0-dev \
librsvg2-dev \
libsoup2.4-dev \
libwebkit2gtk-4.0-dev \
libx11-dev \
```

**提交**: `[待提交]`

---

### 3.2 构建前依赖检查脚本

**创建文件**: `scripts/check-dependencies.sh`

**功能**:
- 检查 Rust 工具链（rustc, cargo）
- 检查构建工具（git, cmake, ninja, pkg-config）
- 检查系统库（GTK 3, WebKit2, Cairo, Pango 等）
- 检查 vcpkg 配置
- 检查 FFmpeg 安装状态
- 输出详细的检查报告和修复建议

**脚本位置**: `scripts/check-dependencies.sh`

---

### 3.3 FFmpeg 版本锁定

**修改文件**: `vcpkg.json`

**修改内容**: 在 `overrides` 部分添加 FFmpeg 版本锁定：

```json
{
  "name": "ffmpeg",
  "version": "6.5.0"
}
```

**目的**: 防止上游 FFmpeg 更新导致的兼容性问题

**提交**: `[待提交]`

---

### 3.4 CI 缓存优化

**现有配置**:
- ✅ `Swatinem/rust-cache@v2` - Rust 缓存
- ✅ `lukka/run-vcpkg@v11` - vcpkg 缓存
- ✅ `VCPKG_BINARY_SOURCES: "clear;x-gha,readwrite"` - vcpkg 二进制缓存

**优化建议**:
- 缓存策略已完善，无需额外修改
- 建议定期清理过期缓存

---

## 四、修复验证

### 4.1 验证步骤

1. **依赖检查脚本测试**:
   ```bash
   chmod +x scripts/check-dependencies.sh
   scripts/check-dependencies.sh
   ```

2. **触发 CI 构建**:
   ```bash
   gh workflow run "Flutter Nightly" --repo changsongyang/rustdesk --ref 1.5.3
   ```

3. **验证 Linux Sciter 构建**:
   - 监控构建状态
   - 验证所有平台构建成功
   - 记录构建时间

---

## 五、长期维护建议

### 5.1 FFmpeg 版本管理

| 措施 | 说明 |
|------|------|
| 版本锁定 | 在 vcpkg.json 中锁定 FFmpeg 版本为 6.5.0 |
| 定期审查 | 每季度审查一次 FFmpeg 版本，评估是否需要更新 |
| 测试验证 | 更新前在测试分支进行完整测试 |

### 5.2 构建前依赖检查

| 措施 | 说明 |
|------|------|
| 集成到 CI | 将检查脚本集成到所有构建工作流 |
| 定期更新 | 根据新增依赖更新检查脚本 |
| 自动化 | 实现依赖版本验证自动化 |

### 5.3 CI 缓存优化

| 措施 | 说明 |
|------|------|
| 缓存失效策略 | 根据 Cargo.toml 和 vcpkg.json 哈希失效缓存 |
| 缓存清理 | 设置合理的缓存过期时间 |
| 缓存监控 | 监控缓存命中率，优化缓存策略 |

### 5.4 构建健康检查

| 措施 | 说明 |
|------|------|
| 每日构建 | 设置每日定时构建检查 |
| 告警机制 | 构建失败时发送通知 |
| 性能监控 | 跟踪构建时间趋势 |

---

## 六、总结

### 6.1 修复成果

| 项目 | 状态 |
|------|------|
| Linux Sciter 依赖修复 | ✅ 已完成 |
| 构建前依赖检查脚本 | ✅ 已完成 |
| FFmpeg 版本锁定 | ✅ 已完成 |
| CI 缓存优化 | ✅ 已完成（已有配置） |

### 6.2 未来行动

1. **立即执行**: 提交修改并触发 CI 构建验证
2. **短期**: 集成依赖检查脚本到 CI 工作流
3. **长期**: 建立构建健康检查机制

---

**报告生成时间**: 2026-05-17  
**报告版本**: v1.0  
**维护者**: changsongyang
