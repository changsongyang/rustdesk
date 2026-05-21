# view-build-status.sh 使用手册

## 概述

`view-build-status.sh` 是一个用于查看 GitHub Actions 构建状态的脚本工具，支持通过 GitHub CLI 或 GitHub API 获取构建信息，帮助用户快速了解项目的构建状态和错误详情。

## 适用场景

- 快速查看最近的构建状态
- CI/CD 构建失败时的问题排查
- 定期检查构建健康状况
- 自动化脚本中的构建状态检查

## 前置条件

### 系统要求
- **操作系统**: Linux / macOS / Windows (WSL2)
- **Shell**: Bash 4.0+

### 依赖工具
| 工具 | 说明 | 是否必需 |
|------|------|----------|
| GitHub CLI (gh) | 首选方式 | 推荐 |
| curl | API 调用 | 备选 |
| jq | JSON 解析 | 备选 |

## 安装步骤

### 1. 获取脚本
```bash
# 克隆仓库
git clone https://github.com/rustdesk/rustdesk.git
cd rustdesk

# 确保脚本可执行
chmod +x scripts/ci/view-build-status.sh
```

### 2. 安装 GitHub CLI（推荐）

**Windows**:
```powershell
winget install --id GitHub.cli
```

**macOS**:
```bash
brew install gh
```

**Linux**:
```bash
sudo apt install gh
```

### 3. 登录 GitHub CLI
```bash
gh auth login
```

## 参数说明

### 命令行参数

| 参数 | 缩写 | 说明 | 默认值 |
|------|------|------|--------|
| `--help` | `-h` | 显示帮助信息 | - |
| `--repo` | `-r` | 指定仓库 | `changsongyang/rustdesk` |
| `--workflow` | `-w` | 指定工作流 | `flutter-build.yml` |
| `--limit` | `-l` | 显示构建数量 | 5 |

### 环境变量

| 变量 | 说明 | 是否必需 |
|------|------|----------|
| `REPO_OWNER` | 仓库所有者 | 可选 |
| `REPO_NAME` | 仓库名称 | 可选 |
| `WORKFLOW` | 工作流文件 | 可选 |
| `GITHUB_TOKEN` | GitHub 访问令牌 | 备选 |

## 使用示例

### 示例 1: 基本使用
```bash
./scripts/ci/view-build-status.sh
```

**输出示例**:
```
✅ 使用 GitHub CLI 查看构建状态

📋 最近 5 次构建:
ID          STATUS    CONCLUSION  BRANCH    CREATED AT
25991888570 completed failure     1.5.3     2026-05-17T13:45:26Z
25991245405 completed success     1.5.3     2026-05-17T12:30:15Z
25990610718 completed failure     1.5.3     2026-05-17T11:15:42Z
```

### 示例 2: 指定仓库和工作流
```bash
./scripts/ci/view-build-status.sh -r rustdesk/rustdesk -w ci.yml
```

### 示例 3: 查看更多构建
```bash
./scripts/ci/view-build-status.sh -l 10
```

### 示例 4: 查看失败构建详情
```bash
./scripts/ci/view-build-status.sh | grep -A5 "failure"
```

### 示例 5: 在脚本中使用
```bash
# 检查最近构建是否成功
if ./scripts/ci/view-build-status.sh | grep -q "success"; then
    echo "构建成功"
else
    echo "构建失败"
fi
```

## 功能说明

### 检测方法优先级

1. **GitHub CLI**: 如果安装了 `gh` 命令，优先使用 CLI 获取详细信息
2. **GitHub API**: 如果设置了 `GITHUB_TOKEN`，使用 curl 调用 API
3. **浏览器链接**: 如果以上都不可用，提供手动查看的链接

### 输出信息

| 字段 | 说明 |
|------|------|
| ID | 构建运行 ID |
| STATUS | 构建状态（completed/running/queued） |
| CONCLUSION | 构建结果（success/failure/canceled） |
| BRANCH | 构建分支 |
| CREATED AT | 创建时间 |

## 常见问题

### 问题 1: gh 命令未找到

**错误信息**:
```
⚠️ GitHub CLI 未安装且未设置 GITHUB_TOKEN
```

**解决方案**:
```bash
# 安装 GitHub CLI
# Windows: winget install --id GitHub.cli
# macOS: brew install gh
# Linux: sudo apt install gh

# 或者设置 GITHUB_TOKEN
export GITHUB_TOKEN=your_token_here
```

### 问题 2: 认证失败

**错误信息**:
```
error: authentication required
```

**解决方案**:
```bash
# 登录 GitHub CLI
gh auth login

# 或者使用令牌
gh auth login --with-token < token.txt
```

### 问题 3: 权限不足

**错误信息**:
```
error: Resource not accessible by integration
```

**解决方案**:
```bash
# 确保令牌有足够的权限
# 需要 repo 和 workflow 权限
```

### 问题 4: 工作流不存在

**错误信息**:
```
error: Could not find workflow
```

**解决方案**:
```bash
# 检查工作流文件名是否正确
./scripts/ci/view-build-status.sh -w correct-workflow.yml
```

## 退出码

| 退出码 | 含义 |
|--------|------|
| 0 | 成功获取状态 |
| 1 | 错误 |

## 更新日志

### v1.0.0 (2024-01-01)
- 初始版本发布
- 支持 GitHub CLI 和 API 两种方式
- 提供详细的构建状态信息