#!/bin/bash
# 安装 Git Hooks 脚本

set -e

echo "========================================"
echo "  安装 RustDesk Git Hooks"
echo "========================================"
echo ""

# 检查是否在 git 仓库中
if [ ! -d ".git" ]; then
    echo "错误: 不在 Git 仓库中"
    exit 1
fi

# 创建 hooks 目录（如果不存在）
HOOKS_DIR=".git/hooks"
mkdir -p "$HOOKS_DIR"

# 安装 pre-commit hook
echo "安装 pre-commit hook..."
cp "scripts/pre-commit.sh" "$HOOKS_DIR/pre-commit"
chmod +x "$HOOKS_DIR/pre-commit"
echo "✓ pre-commit hook 安装完成"
echo ""

echo "========================================"
echo "  Git Hooks 安装完成！"
echo "========================================"
echo ""
echo "安装的 Hooks:"
echo "  - pre-commit: 提交前运行快速检查"
echo ""
echo "使用方法:"
echo "  - 每次 git commit 时会自动运行检查"
echo "  - 如需跳过检查: git commit --no-verify"
echo ""
