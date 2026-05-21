#!/bin/bash

# RustDesk 代码回滚脚本
# 支持快速回滚到指定版本并验证

set -e

echo "=========================================="
echo "RustDesk 代码回滚工具"
echo "=========================================="
echo ""

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 参数
TARGET_VERSION=""
BRANCH=""
VERIFY=false
FORCE=false

# 解析参数
while [[ $# -gt 0 ]]; do
    case $1 in
        --version|-v)
            TARGET_VERSION="$2"
            shift 2
            ;;
        --branch|-b)
            BRANCH="$2"
            shift 2
            ;;
        --verify|-f)
            VERIFY=true
            shift
            ;;
        --force)
            FORCE=true
            shift
            ;;
        --help|-h)
            echo "用法:"
            echo "  $0 --version <版本> [--branch <分支>] [--verify] [--force]"
            echo ""
            echo "选项:"
            echo "  --version, -v   指定要回滚到的版本（commit hash 或 tag）"
            echo "  --branch, -b    指定目标分支（默认当前分支）"
            echo "  --verify, -f    回滚后执行验证检查"
            echo "  --force         强制回滚（跳过确认）"
            echo "  --help, -h      显示此帮助信息"
            echo ""
            echo "示例:"
            echo "  $0 --version abc123 --branch main --verify"
            echo "  $0 --version v1.5.2 --verify"
            exit 0
            ;;
        *)
            echo "未知参数: $1"
            exit 1
            ;;
    esac
done

# 检查参数
if [ -z "$TARGET_VERSION" ]; then
    echo -e "${RED}❌ 必须指定目标版本${NC}"
    echo "使用 --help 查看用法"
    exit 1
fi

# 获取当前分支
if [ -z "$BRANCH" ]; then
    BRANCH=$(git branch --show-current)
    echo -e "${YELLOW}⚠️  未指定分支，使用当前分支: ${BRANCH}${NC}"
    echo ""
fi

# 确认操作
if [ "$FORCE" = false ]; then
    echo "确认回滚操作:"
    echo "  目标分支: $BRANCH"
    echo "  目标版本: $TARGET_VERSION"
    echo "  验证回滚: $VERIFY"
    echo ""
    read -p "是否确认执行回滚? (y/N): " confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        echo "❌ 操作已取消"
        exit 0
    fi
    echo ""
fi

# 执行回滚
echo -e "${YELLOW}🔄 开始回滚到版本: ${TARGET_VERSION}${NC}"
echo ""

# 确保分支正确
git checkout "$BRANCH"

# 创建回滚提交
if git revert --no-edit "$TARGET_VERSION"..HEAD; then
    echo -e "${GREEN}✅ 回滚成功${NC}"
    echo ""
else
    echo -e "${RED}❌ 回滚失败${NC}"
    echo "可能存在冲突，请手动处理"
    exit 1
fi

# 验证回滚
if [ "$VERIFY" = true ]; then
    echo -e "${YELLOW}🔍 验证回滚...${NC}"
    echo ""
    
    # 检查编译
    if cargo check --all; then
        echo -e "${GREEN}✅ 编译检查通过${NC}"
    else
        echo -e "${RED}❌ 编译检查失败${NC}"
        echo "请检查代码问题"
        exit 1
    fi
    
    # 检查代码格式
    if cargo fmt --all --check; then
        echo -e "${GREEN}✅ 代码格式检查通过${NC}"
    else
        echo -e "${YELLOW}⚠️  代码格式有问题${NC}"
        echo "建议运行: cargo fmt --all"
    fi
    
    echo ""
    echo -e "${GREEN}🎉 回滚验证完成${NC}"
fi

# 输出结果
echo ""
echo "=========================================="
echo "回滚完成"
echo "=========================================="
echo "目标分支: $BRANCH"
echo "目标版本: $TARGET_VERSION"
echo "验证状态: $(if [ "$VERIFY" = true ]; then echo "已验证"; else echo "未验证"; fi)"
echo ""
echo "下一步操作:"
echo "  1. 查看回滚内容: git log --oneline -5"
echo "  2. 推送回滚: git push origin $BRANCH"
echo "  3. 触发 CI 验证"
echo ""

exit 0
