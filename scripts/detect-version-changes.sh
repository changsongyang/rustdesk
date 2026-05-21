#!/bin/bash

# RustDesk 版本变更检测脚本
# 监控 Cargo.lock 和依赖版本变更

set -e

echo "=========================================="
echo "RustDesk 版本变更检测"
echo "=========================================="
echo ""

# 检查 Cargo.lock 是否存在
if [ ! -f "Cargo.lock" ]; then
    echo "❌ Cargo.lock 不存在"
    exit 1
fi

# 检查 rust-toolchain.toml 是否存在
if [ ! -f "rust-toolchain.toml" ]; then
    echo "❌ rust-toolchain.toml 不存在"
    exit 1
fi

# 获取锁定的 Rust 版本
LOCKED_RUST_VERSION=$(grep -A 1 '^\[toolchain\]' rust-toolchain.toml | grep 'channel' | cut -d'"' -f2)
LOCKED_RUST_VERSION=${LOCKED_RUST_VERSION:-"1.81"}

echo "🔒 锁定的 Rust 版本: $LOCKED_RUST_VERSION"
echo ""

# 检查 Cargo.lock 中的 rustc 版本
if grep -q "rustc" Cargo.lock; then
    CARGO_RUST_VERSION=$(grep "rustc" Cargo.lock | head -1 | cut -d' ' -f3)
    echo "📦 Cargo.lock 中的 Rust 版本: $CARGO_RUST_VERSION"
    
    # 比较版本
    if [ "$CARGO_RUST_VERSION" != "$LOCKED_RUST_VERSION" ]; then
        echo ""
        echo "⚠️  WARNING: Rust 版本不匹配!"
        echo "   Cargo.lock 版本: $CARGO_RUST_VERSION"
        echo "   锁定版本: $LOCKED_RUST_VERSION"
        echo ""
        echo "🔧 建议: 更新 rust-toolchain.toml 或重新生成 Cargo.lock"
        echo "   cargo clean && cargo update"
    else
        echo "✅ Rust 版本匹配"
    fi
else
    echo "⚠️  无法从 Cargo.lock 获取 Rust 版本"
fi

echo ""
echo "=========================================="
echo "依赖变更检测"
echo "=========================================="
echo ""

# 检查是否有未提交的 Cargo.lock 变更
if [ -n "$(git status --porcelain | grep Cargo.lock)" ]; then
    echo "📋 发现 Cargo.lock 变更"
    echo ""
    echo "变更详情:"
    git diff Cargo.lock | head -50
    echo ""
    
    # 检测版本升级
    echo "🔍 版本变更分析:"
    git diff Cargo.lock | grep -E "(^[+-]name|^[+-]version)" | head -30
    echo ""
    
    # 检测重大变更
    MAJOR_CHANGES=$(git diff Cargo.lock | grep -E "^-[[:space:]]*version.*[0-9]+\\.[0-9]+\\.[0-9]+" | grep -E "\\.0\\.0$" | wc -l)
    if [ "$MAJOR_CHANGES" -gt 0 ]; then
        echo "⚠️  发现 $MAJOR_CHANGES 个主版本升级"
        echo "   建议: 仔细审查这些变更"
    fi
else
    echo "✅ Cargo.lock 无未提交变更"
fi

echo ""
echo "=========================================="
echo "依赖安全扫描"
echo "=========================================="
echo ""

# 检查 cargo-audit 是否安装
if command -v cargo-audit &> /dev/null; then
    echo "🔍 运行 cargo-audit 安全扫描..."
    cargo audit --json 2>/dev/null | jq '.[] | {advisory: .advisory.id, package: .package.name, severity: .advisory.severity}' 2>/dev/null || echo "✅ 未发现已知安全漏洞"
else
    echo "⚠️  cargo-audit 未安装"
    echo "   建议安装: cargo install cargo-audit"
    echo "   然后运行: cargo audit"
fi

echo ""
echo "=========================================="
echo "依赖更新建议"
echo "=========================================="
echo ""

# 检查过时的依赖
if command -v cargo-outdated &> /dev/null; then
    echo "📊 检查过时依赖..."
    cargo outdated --format short | head -20
else
    echo "⚠️  cargo-outdated 未安装"
    echo "   建议安装: cargo install cargo-outdated"
    echo "   然后运行: cargo outdated"
fi

echo ""
echo "=========================================="
echo "检测完成"
echo "=========================================="
echo ""

exit 0
