# 查看最新构建报错 - 操作指南

## 🚨 快速查看方法

### 方法 1: GitHub 网页查看（推荐）

**直接访问 Actions 页面:**
```
https://github.com/changsongyang/rustdesk/actions/workflows/flutter-build.yml
```

**步骤:**
1. 打开上述链接
2. 点击最新的失败构建（红色标记）
3. 查看失败的步骤
4. 点击展开查看详细错误日志

---

### 方法 2: 安装 GitHub CLI 后使用脚本

#### 安装 GitHub CLI

**Windows:**
```powershell
winget install --id GitHub.cli
```

**macOS:**
```bash
brew install gh
```

**Linux:**
```bash
sudo apt install gh
```

#### 登录 GitHub CLI
```bash
gh auth login
```

#### 使用脚本查看构建状态
```bash
./scripts/view-build-status.sh
```

---

### 方法 3: 手动使用 GitHub CLI 命令

#### 查看最近构建
```bash
gh run list --repo changsongyang/rustdesk --workflow=flutter-build.yml --limit 5
```

#### 查看最新构建详情
```bash
gh run view --repo changsongyang/rustdesk
```

#### 查看失败步骤日志
```bash
gh run view --repo changsongyang/rustdesk --log-failed
```

#### 下载完整日志
```bash
gh run view --repo changsongyang/rustdesk --log > build.log
```

---

## 🔍 常见构建错误位置

### Windows 构建
- **步骤**: `Build rustdesk`
- **常见错误**: vcpkg 依赖、LLVM 配置、链接器错误

### macOS 构建
- **步骤**: `Build rustdesk`
- **常见错误**: 代码签名、依赖版本、编译错误

### Linux 构建
- **步骤**: `Build rustdesk`
- **常见错误**: 系统库依赖、FFmpeg、编译错误

### Android 构建
- **步骤**: `Build rustdesk`
- **常见错误**: NDK 配置、Gradle 依赖、编译错误

---

## 📊 分析构建错误

### 1. 下载日志后使用分析脚本

```bash
# 下载日志
gh run view <run-id> --repo changsongyang/rustdesk --log > build.log

# 分析错误
./scripts/analyze-build-errors.sh --log build.log --output report.txt

# 查看报告
cat report.txt
```

### 2. 根因分析

```bash
./scripts/root-cause-analysis.sh build.log
```

### 3. 验证工具链

```bash
./scripts/verify-toolchain.sh
./scripts/check-dependencies.sh
```

---

## 🛠️ 快速修复流程

### 步骤 1: 识别错误类型

| 错误类型 | 关键词 | 快速修复 |
|----------|--------|----------|
| **编译错误** | `error[E0` | 检查 Rust 版本和代码 |
| **链接错误** | `linker`, `undefined reference` | 检查库依赖 |
| **依赖错误** | `find_package`, `could not find` | 检查 vcpkg 配置 |
| **网络错误** | `failed to download`, `timeout` | 重试或检查网络 |
| **缓存错误** | `cache`, `inconsistent` | 清理缓存后重试 |

### 步骤 2: 实施修复

根据错误类型选择对应的修复方案，详见:
- **快速修复指南**: `CI_CD_QUICK_FIX.md`
- **完整分析**: `CI_CD_ANALYSIS_AND_OPTIMIZATION.md`

### 步骤 3: 验证修复

```bash
# 本地验证
./scripts/run-checks.sh

# 提交并推送
git commit -m "fix(build): 修复构建错误"
git push origin fix/issue
```

---

## 📞 获取帮助

### 自动工具
```bash
# 错误分析
./scripts/analyze-build-errors.sh --help

# 根因分析
./scripts/root-cause-analysis.sh --help
```

### 文档
- **快速修复**: `CI_CD_QUICK_FIX.md`
- **完整分析**: `CI_CD_ANALYSIS_AND_OPTIMIZATION.md`
- **资源汇总**: `CI_CD_RESOURCES.md`

---

## 🔗 快速链接

| 资源 | 链接 |
|------|------|
| **Actions 页面** | https://github.com/changsongyang/rustdesk/actions |
| **Flutter Build 工作流** | https://github.com/changsongyang/rustdesk/actions/workflows/flutter-build.yml |
| **Issues** | https://github.com/changsongyang/rustdesk/issues |
| **Pull Requests** | https://github.com/changsongyang/rustdesk/pulls |

---

**最后更新**: 2026-05-17
