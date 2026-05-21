# RustDesk CI/CD 构建报错快速修复指南

## 🚨 常见错误及解决方案

### 1. vcpkg 依赖安装失败

**错误信息**:
```
error: building [package] failed: find_package() could not find any configuration file
```

**快速修复**:
```bash
# 方法 1: 清理缓存后重试
Remove-Item -Recurse -Force $env:VCPKG_ROOT/installed
Remove-Item -Recurse -Force $env:VCPKG_ROOT/buildtrees

# 方法 2: 触发重新安装
gh workflow run flutter-build.yml --ref main --force
```

---

### 2. FFmpeg 版本不兼容

**错误信息**:
```
error: ['ffmpeg::avcodec'] requested library object file not found
error: undefined reference to 'avcodec_send_frame'
```

**快速修复**:
```bash
# 1. 检查 FFmpeg 版本
$ grep "ffmpeg" vcpkg.json

# 2. 确保锁定版本
# 在 vcpkg.json 中:
{
  "name": "ffmpeg",
  "version": "6.5.0"
}

# 3. 清理并重新安装
Remove-Item -Recurse -Force $env:VCPKG_ROOT/installed/x64-windows-static
gh workflow run flutter-build.yml --ref fix/ffmpeg-version --force
```

---

### 3. Rust 版本不匹配

**错误信息**:
```
error[E0554]: #![feature] may not be used outside of standard library
```

**快速修复**:
```bash
# 1. 检查当前版本
rustc --version

# 2. 确保使用正确版本
rustup show

# 3. 锁定版本（如果未锁定）
rustup default 1.81

# 4. 或使用 rust-toolchain.toml
# 文件内容:
# [toolchain]
# channel = "1.81"
```

---

### 4. 链接器错误

**错误信息**:
```
linker link failed with exit code 1181
error: could not start linker
```

**快速修复**:
```bash
# 1. 检查 LLVM 安装
llvm-config --version

# 2. 重新安装 LLVM
# 在 CI 配置中:
- name: Install LLVM and Clang
  uses: KyleMayes/install-llvm-action@v1
  with:
    version: 15.0.6

# 3. 清理并重试
cargo clean
gh workflow run flutter-build.yml --ref main --force
```

---

### 5. 缓存污染

**错误信息**:
```
Cache is in an inconsistent state
warning: build succeeded with warnings
```

**快速修复**:
```bash
# 方法 1: 手动清理 GitHub Actions 缓存
gh cache delete --all

# 方法 2: 触发新构建（使用不同的缓存 key）
git commit --allow-empty -m "chore: clear cache"
git push origin main

# 方法 3: 使用缓存清理工作流
gh workflow run clear-cache.yml --ref main
```

---

### 6. 网络问题导致下载失败

**错误信息**:
```
error: failed to download from external source
curl: (7) Failed to connect to proxy
```

**快速修复**:
```bash
# 1. 重试下载
# CI 会自动重试 3 次

# 2. 检查代理设置
# 如果使用了代理，取消设置
unset http_proxy
unset https_proxy

# 3. 手动下载缺失文件
Invoke-WebRequest -Uri "https://example.com/file.zip" -OutFile "file.zip"
```

---

## 🔍 错误诊断流程

### 诊断步骤 1: 提取错误信息

```bash
# 在本地运行错误分析
./scripts/analyze-build-errors.sh --log build.log --output report.txt

# 查看报告
cat report.txt
```

### 诊断步骤 2: 分析根因

```bash
# 运行根因分析
./scripts/root-cause-analysis.sh build.log

# 或使用交互式模式
./scripts/root-cause-analysis.sh
```

### 诊断步骤 3: 验证工具链

```bash
# 检查工具链完整性
./scripts/verify-toolchain.sh

# 检查依赖
./scripts/check-dependencies.sh

# 检查版本
./scripts/verify-rust-version.sh
```

### 诊断步骤 4: 实施修复

```bash
# 根据分析结果修复

# 修复后验证
./scripts/run-checks.sh
```

---

## 🛠️ 快速修复命令

### 清理所有缓存

```bash
# GitHub Actions 缓存
gh cache delete --all

# 本地缓存
cargo clean
Remove-Item -Recurse -Force ~/.cargo/registry/cache
Remove-Item -Recurse -Force $env:VCPKG_ROOT/installed
Remove-Item -Recurse -Force $env:VCPKG_ROOT/buildtrees
```

### 重试构建

```bash
# 重试失败的作业
gh run view <run-id> --log-failed | head -50

# 重新运行工作流
gh workflow run flutter-build.yml --ref main --force

# 使用特定参数重试
gh workflow run flutter-build.yml \
  --field upload-artifact=false \
  --field upload-tag="nightly-test"
```

### 查看构建日志

```bash
# 下载完整日志
gh run view <run-id> --log > build.log

# 查看特定步骤日志
gh api repos/{owner}/{repo}/actions/runs/{run_id}/jobs | jq '.jobs[] | {name, status, logs_url}'

# 查看失败步骤
gh run view <run-id> --log-failed
```

---

## 📊 构建健康检查

### 检查清单

构建前检查：
- [ ] Rust 版本正确 (1.81)
- [ ] Flutter 版本正确 (3.24.5)
- [ ] vcpkg 缓存有效
- [ ] 网络连接正常
- [ ] 磁盘空间充足 (>10GB)

构建后检查：
- [ ] 编译成功（无 E* 错误）
- [ ] 链接成功（无 linker 错误）
- [ ] 测试通过（如配置）
- [ ] 产物生成

---

## 📞 获取帮助

### 自动分析工具

```bash
# 综合分析
./scripts/analyze-build-errors.sh --log <log-file> --output <report-file>

# 根因分析
./scripts/root-cause-analysis.sh <log-file>

# 工具链验证
./scripts/verify-toolchain.sh

# 版本检测
./scripts/verify-rust-version.sh
./scripts/detect-version-changes.sh
```

### 常用命令

```bash
# 查看工作流状态
gh run list --workflow=flutter-build.yml --limit 10

# 查看最近的失败
gh run list --workflow=flutter-build.yml --status=failure --limit 5

# 查看构建详情
gh run view <run-id>

# 下载构建产物
gh run download <run-id>
```

---

## 🎯 最佳实践

### 1. 提交前检查

```bash
# 本地运行检查
./scripts/run-checks.sh

# 确保所有测试通过
cargo test --all

# 确保格式正确
cargo fmt --all --check
```

### 2. 使用特性分支

```bash
# 创建修复分支
git checkout -b fix/issue-description

# 提交修复
git commit -m "fix(build): 修复构建问题"

# 测试后推送
git push origin fix/issue-description
```

### 3. CI 失败时

1. **不要立即重试** - 先分析错误
2. **查看完整日志** - 使用 `gh run view --log-failed`
3. **修复根本原因** - 不要只清理缓存
4. **验证修复** - 本地测试后再推送

---

## 📚 更多资源

- **完整分析文档**: `CI_CD_ANALYSIS_AND_OPTIMIZATION.md`
- **快速开始**: `QUICKSTART.md`
- **分支管理**: `BRANCHING.md`
- **回滚指南**: `ROLLBACK.md`

---

**最后更新**: 2026-05-17
