#!/bin/bash
# RustDesk 安全审计脚本
# 用途：定期运行安全检查和代码质量检查

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  RustDesk 安全审计脚本${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# 检查是否在项目根目录
if [ ! -f "Cargo.toml" ]; then
    echo -e "${RED}错误: 请在项目根目录运行此脚本${NC}"
    exit 1
fi

# 1. 依赖漏洞扫描
echo -e "${YELLOW}[1/8] 依赖漏洞扫描...${NC}"
if command -v cargo-audit &> /dev/null; then
    cargo audit
    echo -e "${GREEN}✓ 依赖漏洞扫描完成${NC}"
else
    echo -e "${YELLOW}警告: cargo-audit 未安装，跳过依赖漏洞扫描${NC}"
    echo "安装命令: cargo install cargo-audit"
fi
echo ""

# 2. 代码格式检查
echo -e "${YELLOW}[2/8] 代码格式检查...${NC}"
if cargo fmt --check; then
    echo -e "${GREEN}✓ 代码格式检查通过${NC}"
else
    echo -e "${YELLOW}警告: 代码格式需要调整${NC}"
    echo "运行: cargo fmt 来自动格式化"
fi
echo ""

# 3. Clippy 检查
echo -e "${YELLOW}[3/8] Clippy 代码检查...${NC}"
if cargo clippy -- -D warnings; then
    echo -e "${GREEN}✓ Clippy 检查通过${NC}"
else
    echo -e "${RED}错误: Clippy 发现问题${NC}"
fi
echo ""

# 4. 文档测试
echo -e "${YELLOW}[4/8] 文档测试...${NC}"
if cargo test --doc; then
    echo -e "${GREEN}✓ 文档测试通过${NC}"
else
    echo -e "${RED}错误: 文档测试失败${NC}"
fi
echo ""

# 5. 完整测试
echo -e "${YELLOW}[5/8] 完整测试...${NC}"
if cargo test; then
    echo -e "${GREEN}✓ 完整测试通过${NC}"
else
    echo -e "${RED}错误: 测试失败${NC}"
fi
echo ""

# 6. 编译检查
echo -e "${YELLOW}[6/8] 编译检查...${NC}"
if cargo build; then
    echo -e "${GREEN}✓ 编译检查通过${NC}"
else
    echo -e "${RED}错误: 编译失败${NC}"
fi
echo ""

# 7. HTML 实体检查
echo -e "${YELLOW}[7/8] HTML 实体检查...${NC}"
HTML_ENTITIES_FOUND=0

# 检查 Rust 文件
if grep -r "&lt;" --include="*.rs" --include="*.xml" --include="*.yaml" --include="*.yml" . 2>/dev/null | grep -v "target/" | grep -v ".git/"; then
    echo -e "${YELLOW}警告: 发现 HTML 实体编码 &lt;${NC}"
    HTML_ENTITIES_FOUND=1
else
    echo -e "${GREEN}✓ 未发现 &lt; HTML 实体${NC}"
fi

if grep -r "&gt;" --include="*.rs" --include="*.xml" --include="*.yaml" --include="*.yml" . 2>/dev/null | grep -v "target/" | grep -v ".git/"; then
    echo -e "${YELLOW}警告: 发现 HTML 实体编码 &gt;${NC}"
    HTML_ENTITIES_FOUND=1
else
    echo -e "${GREEN}✓ 未发现 &gt; HTML 实体${NC}"
fi

if grep -r "&amp;" --include="*.rs" --include="*.xml" --include="*.yaml" --include="*.yml" . 2>/dev/null | grep -v "target/" | grep -v ".git/"; then
    echo -e "${YELLOW}警告: 发现 HTML 实体编码 &amp;${NC}"
    HTML_ENTITIES_FOUND=1
else
    echo -e "${GREEN}✓ 未发现 &amp; HTML 实体${NC}"
fi

if [ $HTML_ENTITIES_FOUND -eq 0 ]; then
    echo -e "${GREEN}✓ HTML 实体检查通过${NC}"
fi
echo ""

# 8. Git 状态检查
echo -e "${YELLOW}[8/8] Git 状态检查...${NC}"
if git status --porcelain | grep -q .; then
    echo -e "${YELLOW}警告: 有未提交的变更${NC}"
    git status --short
else
    echo -e "${GREEN}✓ Git 工作区干净${NC}"
fi
echo ""

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  安全审计完成！${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}提示:${NC}"
echo "  1. 定期运行此脚本进行安全审计"
echo "  2. 可以将此脚本集成到 Git Hooks"
echo "  3. 可以在 CI 中运行此脚本"
echo ""
