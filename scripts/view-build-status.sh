#!/bin/bash

# RustDesk CI/CD 构建状态查看脚本
# 使用 GitHub API 查看最新构建状态

set -e

# 配置
REPO_OWNER="changsongyang"
REPO_NAME="rustdesk"
WORKFLOW="flutter-build.yml"
GITHUB_TOKEN="${GITHUB_TOKEN:-}"

echo "=========================================="
echo "RustDesk CI/CD 构建状态查看"
echo "=========================================="
echo ""

# 检查 GitHub CLI
if command -v gh &> /dev/null; then
    echo "✅ 使用 GitHub CLI 查看构建状态"
    echo ""
    
    # 查看最近的构建
    echo "📋 最近 5 次构建:"
    gh run list --repo ${REPO_OWNER}/${REPO_NAME} --workflow=${WORKFLOW} --limit 5
    
    echo ""
    echo "📊 查看最新构建详情:"
    LATEST_RUN=$(gh run list --repo ${REPO_OWNER}/${REPO_NAME} --workflow=${WORKFLOW} --limit 1 --json databaseId --jq '.[0].databaseId')
    
    if [ -n "$LATEST_RUN" ]; then
        gh run view $LATEST_RUN --repo ${REPO_OWNER}/${REPO_NAME}
        
        echo ""
        echo "🔍 查看失败步骤日志:"
        gh run view $LATEST_RUN --repo ${REPO_OWNER}/${REPO_NAME} --log-failed
    fi
    
elif [ -n "$GITHUB_TOKEN" ]; then
    echo "✅ 使用 GitHub API 查看构建状态"
    echo ""
    
    # 使用 curl 调用 GitHub API
    API_URL="https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/actions/workflows/${WORKFLOW}/runs"
    
    echo "📋 最近构建:"
    curl -s -H "Authorization: token ${GITHUB_TOKEN}" \
        "${API_URL}?per_page=5" | \
        jq -r '.workflow_runs[] | "\(.id)\t\(.status)\t\(.conclusion // "running")\t\(.head_branch)\t\(.created_at)"'
    
else
    echo "⚠️  GitHub CLI 未安装且未设置 GITHUB_TOKEN"
    echo ""
    echo "请使用以下方法之一查看构建状态:"
    echo ""
    echo "方法 1: 安装 GitHub CLI"
    echo "  Windows: winget install --id GitHub.cli"
    echo "  macOS: brew install gh"
    echo "  Linux: sudo apt install gh"
    echo ""
    echo "方法 2: 在浏览器中查看"
    echo "  https://github.com/${REPO_OWNER}/${REPO_NAME}/actions/workflows/${WORKFLOW}"
    echo ""
    echo "方法 3: 设置 GITHUB_TOKEN 环境变量"
    echo "  export GITHUB_TOKEN=your_token_here"
fi

echo ""
echo "=========================================="
echo "查看完成"
echo "=========================================="
