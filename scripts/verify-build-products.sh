#!/bin/bash

# RustDesk 构建产物完整性验证脚本
# 生成并验证构建产物的哈希值

set -e

echo "=========================================="
echo "RustDesk 构建产物完整性验证"
echo "=========================================="
echo ""

# 参数解析
ACTION="generate"
OUTPUT_DIR="."
HASH_FILE="build-hashes.txt"

while [[ $# -gt 0 ]]; do
    case $1 in
        --generate)
            ACTION="generate"
            shift
            ;;
        --verify)
            ACTION="verify"
            shift
            ;;
        --output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --hash-file)
            HASH_FILE="$2"
            shift 2
            ;;
        *)
            echo "未知参数: $1"
            exit 1
            ;;
    esac
done

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0;32m' # No Color

# 生成哈希
generate_hashes() {
    echo "📦 生成构建产物哈希..."
    echo ""
    
    # 创建哈希文件
    echo "# RustDesk Build Hashes" > "$HASH_FILE"
    echo "# Generated: $(date)" >> "$HASH_FILE"
    echo "# Platform: $(uname -s)-$(uname -m)" >> "$HASH_FILE"
    echo "" >> "$HASH_FILE"
    
    # 查找构建产物
    echo "🔍 查找构建产物..."
    PRODUCTS=$(find "$OUTPUT_DIR" -type f \( -name "*.exe" -o -name "*.dll" -o -name "*.so" -o -name "*.dylib" -o -name "*.app" -o -name "*.deb" -o -name "*.rpm" -o -name "*.apk" \) 2>/dev/null | head -50)
    
    if [ -z "$PRODUCTS" ]; then
        echo -e "${YELLOW}⚠️  未找到构建产物${NC}"
        echo "请确保在构建输出目录运行此脚本"
        exit 0
    fi
    
    echo "📋 发现 $(echo "$PRODUCTS" | wc -l) 个构建产物"
    echo ""
    
    # 计算哈希
    echo "🧮 计算 SHA256 哈希..."
    echo ""
    
    while IFS= read -r file; do
        if [ -f "$file" ]; then
            hash=$(sha256sum "$file" | awk '{print $1}')
            size=$(du -h "$file" | awk '{print $1}')
            echo "$hash  $file  [$size]"
            echo "$hash|$file" >> "$HASH_FILE"
        fi
    done <<< "$PRODUCTS"
    
    echo ""
    echo -e "${GREEN}✅ 哈希文件已生成: $HASH_FILE${NC}"
    echo ""
    echo "📝 哈希文件内容:"
    cat "$HASH_FILE"
    echo ""
}

# 验证哈希
verify_hashes() {
    echo "🔍 验证构建产物完整性..."
    echo ""
    
    if [ ! -f "$HASH_FILE" ]; then
        echo -e "${RED}❌ 哈希文件不存在: $HASH_FILE${NC}"
        exit 1
    fi
    
    echo "📄 读取哈希文件: $HASH_FILE"
    echo ""
    
    PASSED=0
    FAILED=0
    
    # 跳过注释和空行
    grep -v "^#" "$HASH_FILE" | grep -v "^$" | while IFS='|' read -r expected_hash file; do
        if [ -f "$file" ]; then
            actual_hash=$(sha256sum "$file" | awk '{print $1}')
            if [ "$expected_hash" = "$actual_hash" ]; then
                echo -e "${GREEN}✓ $file${NC}"
                ((PASSED++))
            else
                echo -e "${RED}✗ $file${NC}"
                echo "   期望: $expected_hash"
                echo "   实际: $actual_hash"
                ((FAILED++))
            fi
        else
            echo -e "${YELLOW}⚠️ $file - 文件不存在${NC}"
            ((FAILED++))
        fi
    done
    
    echo ""
    echo "=========================================="
    echo "验证结果"
    echo "=========================================="
    echo "通过: $PASSED"
    echo "失败: $FAILED"
    
    if [ $FAILED -eq 0 ]; then
        echo ""
        echo -e "${GREEN}✅ 所有构建产物完整性验证通过!${NC}"
        exit 0
    else
        echo ""
        echo -e "${RED}❌ 部分构建产物验证失败${NC}"
        exit 1
    fi
}

# 主逻辑
if [ "$ACTION" = "generate" ]; then
    generate_hashes
elif [ "$ACTION" = "verify" ]; then
    verify_hashes
else
    echo "用法:"
    echo "  $0 --generate [--output <目录>] [--hash-file <文件>]"
    echo "  $0 --verify [--hash-file <文件>]"
    exit 1
fi
