#!/bin/bash

# RustDesk 代码质量检查脚本
# 集成 rustfmt、clippy、cargo-audit 和 cargo-check

set -e

echo "=========================================="
echo "RustDesk 代码质量检查"
echo "=========================================="
echo ""

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 检查状态
PASSED=0
FAILED=0
WARNINGS=0

# 检查函数
run_check() {
    local name="$1"
    local command="$2"
    local description="$3"
    
    echo -e "${YELLOW}🔍 运行 ${name}...${NC}"
    echo "   ${description}"
    echo ""
    
    local start_time=$(date +%s)
    
    if eval "$command"; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        echo -e "${GREEN}✅ ${name} 通过${NC} (${duration}s)"
        echo ""
        ((PASSED++))
        return 0
    else
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        echo -e "${RED}❌ ${name} 失败${NC} (${duration}s)"
        echo ""
        ((FAILED++))
        return 1
    fi
}

# 可选检查
run_check_optional() {
    local name="$1"
    local command="$2"
    local description="$3"
    
    echo -e "${YELLOW}🔍 运行 ${name} (可选)...${NC}"
    echo "   ${description}"
    echo ""
    
    local start_time=$(date +%s)
    
    if eval "$command"; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        echo -e "${GREEN}✅ ${name} 通过${NC} (${duration}s)"
        echo ""
        ((PASSED++))
        return 0
    else
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        echo -e "${YELLOW}⚠️ ${name} 有警告${NC} (${duration}s)"
        echo ""
        ((WARNINGS++))
        return 0
    fi
}

# 检查命令是否存在
check_command() {
    if ! command -v "$1" &> /dev/null; then
        echo -e "${RED}❌ 未找到命令: $1${NC}"
        echo "   请安装: $2"
        exit 1
    fi
}

# 预检查
echo "📦 检查必要工具..."
check_command "cargo" "rustup install stable"
check_command "rustfmt" "rustup component add rustfmt"
check_command "cargo-clippy" "rustup component add clippy"
echo -e "${GREEN}✅ 所有工具已安装${NC}"
echo ""

# 运行检查
echo "=========================================="
echo "开始代码质量检查"
echo "=========================================="
echo ""

# 1. rustfmt 格式检查
run_check "rustfmt" "cargo fmt --all --check" "检查 Rust 代码格式"

# 2. cargo check 编译检查
run_check "cargo check" "cargo check --all" "检查编译错误"

# 3. clippy 代码质量检查
run_check "clippy" "cargo clippy --all --all-targets -- -D warnings" "检查代码质量"

# 4. cargo-audit 安全扫描
run_check_optional "cargo-audit" "cargo audit" "检查依赖安全漏洞"

# 输出总结
echo "=========================================="
echo "检查总结"
echo "=========================================="
echo ""
echo "通过: ${PASSED}"
echo "失败: ${FAILED}"
echo "警告: ${WARNINGS}"
echo ""

if [ $FAILED -eq 0 ]; then
    if [ $WARNINGS -eq 0 ]; then
        echo -e "${GREEN}🎉 所有检查通过!${NC}"
        exit 0
    else
        echo -e "${YELLOW}⚠️  检查完成，但有警告${NC}"
        echo "建议查看警告并修复"
        exit 0
    fi
else
    echo -e "${RED}❌ 检查失败，请修复错误后再提交${NC}"
    exit 1
fi
