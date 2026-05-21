#!/bin/bash

# RustDesk 修复-提交-推送-验证自动化流程脚本
# 自动引导用户完成代码修复并触发 CI 验证

set -e

echo "=========================================="
echo "RustDesk 修复验证自动化流程"
echo "=========================================="
echo ""

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 检查是否有未提交的更改
if [ -z "$(git status --porcelain)" ]; then
    echo -e "${GREEN}✅ 暂无未提交的更改${NC}"
    echo ""
    echo "此脚本用于自动化修复-提交-推送-验证流程"
    echo "请先进行代码修复，然后运行此脚本"
    exit 0
fi

echo -e "${YELLOW}📋 发现未提交的更改${NC}"
echo ""

# 显示更改
echo "更改的文件:"
git status --short
echo ""

# 询问用户确认
read -p "是否查看详细的更改内容? (y/n): " view_changes
if [ "$view_changes" == "y" ]; then
    echo ""
    git diff
    echo ""
fi

# 询问提交消息
echo "=========================================="
echo "提交信息"
echo "=========================================="
echo ""

# 读取变更统计
CHANGED_FILES=$(git status --short | wc -l)

# 自动生成提交消息
AUTO_COMMIT_MSG="fix: automated code improvements

Changes:
- $CHANGED_FILES files modified
- Build compatibility improvements
- Code quality enhancements

Automated fix-verify workflow"

echo "自动生成的提交消息:"
echo ""
echo "$AUTO_COMMIT_MSG"
echo ""

# 询问是否使用自动消息
read -p "是否使用自动生成的提交消息? (y/n): " use_auto_msg

if [ "$use_auto_msg" == "y" ]; then
    COMMIT_MSG="$AUTO_COMMIT_MSG"
else
    echo "请输入提交消息 (多行输入，以空行结束):"
    COMMIT_MSG=""
    while read -r line; do
        if [ -z "$line" ]; then
            break
        fi
        COMMIT_MSG="${COMMIT_MSG}${line}"$'\n'
    done
fi

echo ""
echo "=========================================="
echo "执行流程"
echo "=========================================="
echo ""

# 步骤 1: Git 添加
echo -e "${YELLOW}📦 步骤 1: Git 添加${NC}"
git add -A
echo -e "${GREEN}✅ 已添加所有更改${NC}"
echo ""

# 步骤 2: Git 提交
echo -e "${YELLOW}📝 步骤 2: Git 提交${NC}"
git commit -m "$COMMIT_MSG"
echo -e "${GREEN}✅ 已提交更改${NC}"
echo ""

# 步骤 3: Git 推送
echo -e "${YELLOW}🚀 步骤 3: Git 推送${NC}"
read -p "是否推送到远程仓库? (y/n): " do_push
if [ "$do_push" == "y" ]; then
    BRANCH=$(git branch --show-current)
    echo "推送到分支: $BRANCH"
    git push origin "$BRANCH"
    echo -e "${GREEN}✅ 已推送到远程仓库${NC}"
else
    echo -e "${YELLOW}⚠️ 跳过推送步骤${NC}"
    echo "手动推送命令:"
    echo "  git push origin $BRANCH"
fi
echo ""

# 步骤 4: 触发 CI 构建
echo -e "${YELLOW}🔨 步骤 4: 触发 CI 构建${NC}"
read -p "是否触发 CI 构建验证? (y/n): " do_ci
if [ "$do_ci" == "y" ]; then
    echo ""
    echo "触发 Flutter Nightly 构建..."
    
    # 使用 GitHub CLI 触发构建
    if command -v gh &> /dev/null; then
        gh workflow run "Flutter Nightly" --repo changsongyang/rustdesk --ref 1.5.3
        echo -e "${GREEN}✅ CI 构建已触发${NC}"
        echo ""
        echo "构建状态查看:"
        echo "  gh run list --repo changsongyang/rustdesk"
        echo ""
        echo "等待构建完成后，检查结果:"
        echo "  gh run view <run-id> --log-failed"
    else
        echo -e "${RED}❌ GitHub CLI (gh) 未安装${NC}"
        echo ""
        echo "请手动触发构建:"
        echo "1. 访问 https://github.com/changsongyang/rustdesk/actions"
        echo "2. 点击 'Flutter Nightly' 工作流"
        echo "3. 点击 'Run workflow' 按钮"
        echo "4. 选择 '1.5.3' 分支并运行"
    fi
else
    echo -e "${YELLOW}⚠️ 跳过 CI 触发步骤${NC}"
    echo "手动触发命令:"
    echo "  gh workflow run 'Flutter Nightly' --repo changsongyang/rustdesk --ref 1.5.3"
fi
echo ""

# 完成信息
echo "=========================================="
echo "✅ 修复验证流程完成!"
echo "=========================================="
echo ""
echo "后续步骤:"
echo "1. 监控 CI 构建状态"
echo "2. 查看构建日志排查问题"
echo "3. 如有构建失败，使用以下命令分析错误:"
echo "   ./scripts/analyze-build-errors.sh --log <日志文件>"
echo "   ./scripts/root-cause-analysis.sh <日志文件>"
echo ""
echo "相关脚本:"
echo "  - analyze-build-errors.sh: 错误日志分析"
echo "  - root-cause-analysis.sh: 根因分析"
echo "  - verify-rust-version.sh: Rust 版本验证"
echo "  - check-dependencies.sh: 依赖检查"
echo ""

exit 0
