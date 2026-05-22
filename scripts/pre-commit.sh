#!/bin/bash
# RustDesk pre-commit Git Hook
# 用途：在提交前运行快速检查

set -e

echo "========================================"
echo "  RustDesk Pre-Commit Check"
echo "========================================"
echo ""

# 快速格式检查
echo "[1/3] 代码格式检查..."
if cargo fmt --check; then
    echo "✓ 代码格式检查通过"
else
    echo "错误: 代码格式需要调整"
    echo "运行: cargo fmt 来自动格式化"
    exit 1
fi
echo ""

# 快速 Clippy 检查
echo "[2/3] Clippy 检查..."
if cargo clippy -- -D warnings; then
    echo "✓ Clippy 检查通过"
else
    echo "错误: Clippy 发现问题"
    exit 1
fi
echo ""

# 快速编译检查
echo "[3/3] 编译检查..."
if cargo check; then
    echo "✓ 编译检查通过"
else
    echo "错误: 编译失败"
    exit 1
fi
echo ""

echo "========================================"
echo "  Pre-Commit Check 完成！"
echo "========================================"
echo ""
echo "可以安全提交了！"
echo ""
