#!/usr/bin/env bash

##############################################################################
# RustDesk 版本号批量更新脚本
# 
# 用途：
#   在发布新版本时，自动更新项目中所有配置文件的版本号
# 
# 功能：
#   1. 更新 Cargo.toml（主项目版本）
#   2. 更新 flutter/pubspec.yaml（Flutter 项目版本，支持 x.y.z+build 格式）
#   3. 更新 libs/portable/Cargo.toml（便携版子项目版本）
#   4. 更新 src/version.rs（Rust 版本常量）
#   5. 更新 res/*.spec（RPM 打包配置）
#   6. 更新 res/PKGBUILD（Arch Linux 打包配置）
#   7. 更新 appimage/*.yml（AppImage 打包配置）
#   8. 更新 .github/workflows/*.yml（CI/CD 工作流配置）
#   9. 更新 flatpak/*.json（Flatpak 打包配置）
#  10. 更新 Cargo.lock（通过 cargo check）
# 
# 使用方法：
#   ./res/bump.sh <旧版本号> <新版本号> [构建号]
# 
# 示例：
#   ./res/bump.sh 1.5.1 3.0.0           # 从 1.5.1 升级到 3.0.0
#   ./res/bump.sh 1.5.1 3.0.0 1         # 从 1.5.1 升级到 3.0.0+1
#   ./res/bump.sh 2.0.0 2.1.0 5         # 从 2.0.0 升级到 2.1.0+5
# 
# 注意事项：
#   1. 请确保在项目根目录下运行此脚本
#   2. 旧版本号必须与当前项目中的版本号完全匹配
#   3. 新版本号格式应为 x.y.z（语义化版本号）
#   4. 可选构建号用于 Flutter pubspec.yaml（如 3.0.0+1）
#   5. 需要安装 cargo 以自动更新 Cargo.lock
#   6. 脚本会自动处理 macOS 和 Linux 的 sed 差异
# 
# 版本历史：
#   v1.0 - 基础版本号替换功能
#   v2.0 - 添加详细日志、错误处理和跨平台支持
#   v2.1 - 添加 src/version.rs 支持和 Flutter 构建号处理
##############################################################################

set -euo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_info "=================================================="
log_info "          RustDesk 版本号批量更新脚本"
log_info "=================================================="

# 显示帮助信息
usage() {
    echo ""
    echo "用法: $0 <旧版本号> <新版本号> [构建号]"
    echo ""
    echo "参数:"
    echo "  <旧版本号>    当前项目中使用的版本号（如 1.5.1）"
    echo "  <新版本号>    要升级到的版本号（如 3.0.0）"
    echo "  [构建号]      可选，Flutter 构建号（如 1, 5, 59）"
    echo ""
    echo "示例:"
    echo "  $0 1.5.1 3.0.0        # 从 1.5.1 升级到 3.0.0"
    echo "  $0 1.5.1 3.0.0 1      # 从 1.5.1 升级到 3.0.0+1"
    echo "  $0 2.0.0 2.1.0 5      # 从 2.0.0 升级到 2.1.0+5"
    echo ""
    echo "更新的文件列表:"
    echo "  - Cargo.toml                          # Rust 主项目版本"
    echo "  - flutter/pubspec.yaml                # Flutter 项目版本"
    echo "  - libs/portable/Cargo.toml            # 便携版子项目版本"
    echo "  - src/version.rs                      # Rust 版本常量"
    echo "  - res/*.spec                          # RPM 打包配置"
    echo "  - res/PKGBUILD                        # Arch Linux 打包配置"
    echo "  - appimage/*.yml                      # AppImage 打包配置"
    echo "  - .github/workflows/*.yml             # CI/CD 工作流"
    echo "  - flatpak/*.json                      # Flatpak 打包配置"
    echo "  - Cargo.lock                          # Cargo 依赖锁文件"
    echo ""
    exit 1
}

# 参数检查
if [ $# -lt 2 ] || [ $# -gt 3 ]; then
    log_error "参数数量错误"
    usage
fi

OLD_VERSION="$1"
NEW_VERSION="$2"
BUILD_NUMBER="${3:-}"

# 版本号格式验证
if ! [[ "$OLD_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    log_error "旧版本号格式无效: $OLD_VERSION"
    log_error "请使用 x.y.z 格式（如 1.5.1）"
    exit 1
fi

if ! [[ "$NEW_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    log_error "新版本号格式无效: $NEW_VERSION"
    log_error "请使用 x.y.z 格式（如 3.0.0）"
    exit 1
fi

# 构建号格式验证
if [ -n "$BUILD_NUMBER" ] && ! [[ "$BUILD_NUMBER" =~ ^[0-9]+$ ]]; then
    log_error "构建号格式无效: $BUILD_NUMBER"
    log_error "请使用数字格式（如 1, 5, 59）"
    exit 1
fi

# 计算 Flutter 版本号（带构建号）
FLUTTER_VERSION="$NEW_VERSION"
if [ -n "$BUILD_NUMBER" ]; then
    FLUTTER_VERSION="${NEW_VERSION}+${BUILD_NUMBER}"
    log_info "Flutter 版本号: ${BLUE}${FLUTTER_VERSION}${NC}"
else
    log_info "Flutter 版本号: ${BLUE}${NEW_VERSION}${NC}（无构建号）"
fi

# 确认操作
echo ""
log_warn "即将将版本号从 ${BLUE}$OLD_VERSION${NC} 更新为 ${BLUE}$NEW_VERSION${NC}"
if [ -n "$BUILD_NUMBER" ]; then
    log_warn "Flutter 构建号: ${BLUE}${BUILD_NUMBER}${NC}"
fi
read -p "确认继续? [y/N] " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log_info "操作已取消"
    exit 0
fi

log_info ""
log_info "开始更新版本号..."
echo ""

# 获取脚本目录和项目根目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
log_info "项目根目录: $PROJECT_ROOT"
cd "$PROJECT_ROOT"

# 根据操作系统设置 sed 参数
SED_INPLACE=()
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS 下的 sed 需要 -i ''
    SED_INPLACE=("-i" "")
    log_info "检测到 macOS 系统，使用 BSD sed"
else
    # Linux 下的 sed
    SED_INPLACE=("-i")
    log_info "检测到 Linux 系统，使用 GNU sed"
fi

# 需要更新版本号的文件列表
FILES=(
    "res/*.spec"
    "res/PKGBUILD"
    "Cargo.toml"
    ".github/workflows/*.yml"
    "flatpak/*json"
    "appimage/*.yml"
    "libs/portable/Cargo.toml"
)

# 统计变量
UPDATED_COUNT=0
SKIPPED_COUNT=0
MISSING_COUNT=0

# 遍历文件并更新版本号
log_info "--------------------------------------------------"
log_info "开始更新文件..."
echo ""

for file_pattern in "${FILES[@]}"; do
    for file in $file_pattern; do
        if [ -f "$file" ]; then
            if grep -q "$OLD_VERSION" "$file" 2>/dev/null; then
                log_info "正在更新: ${BLUE}$file${NC}"
                sed "${SED_INPLACE[@]}" "s/$OLD_VERSION/$NEW_VERSION/g" "$file"
                UPDATED_COUNT=$((UPDATED_COUNT + 1))
            else
                log_warn "跳过: $file (未找到版本号 $OLD_VERSION)"
                SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
            fi
        else
            log_warn "跳过: $file (文件不存在)"
            MISSING_COUNT=$((MISSING_COUNT + 1))
        fi
    done
done

# 单独处理 Flutter pubspec.yaml（支持构建号格式）
FLUTTER_FILE="flutter/pubspec.yaml"
if [ -f "$FLUTTER_FILE" ]; then
    log_info ""
    log_info "处理 ${BLUE}$FLUTTER_FILE${NC}（Flutter 版本）"
    # 匹配格式: version: x.y.z 或 version: x.y.z+build
    if grep -qE "version:\s*${OLD_VERSION}([+][0-9]+)?$" "$FLUTTER_FILE" 2>/dev/null; then
        sed "${SED_INPLACE[@]}" "s/version:\s*${OLD_VERSION}[+0-9]*/version: ${FLUTTER_VERSION}/g" "$FLUTTER_FILE"
        log_info "  更新成功: ${OLD_VERSION} → ${FLUTTER_VERSION}"
        UPDATED_COUNT=$((UPDATED_COUNT + 1))
    else
        log_warn "  跳过: 未找到匹配的版本号"
        SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
    fi
else
    log_warn "跳过: $FLUTTER_FILE (文件不存在)"
    MISSING_COUNT=$((MISSING_COUNT + 1))
fi

# 单独处理 src/version.rs
VERSION_FILE="src/version.rs"
if [ -f "$VERSION_FILE" ]; then
    log_info ""
    log_info "处理 ${BLUE}$VERSION_FILE${NC}（Rust 版本常量）"
    if grep -q "pub const VERSION: &str = \"${OLD_VERSION}\"" "$VERSION_FILE" 2>/dev/null; then
        sed "${SED_INPLACE[@]}" "s/pub const VERSION: &str = \"${OLD_VERSION}\"/pub const VERSION: &str = \"${NEW_VERSION}\"/g" "$VERSION_FILE"
        log_info "  更新成功: VERSION = \"${OLD_VERSION}\" → \"${NEW_VERSION}\""
        # 更新构建日期
        CURRENT_DATE=$(date "+%Y-%m-%d %H:%M")
        sed "${SED_INPLACE[@]}" "s/pub const BUILD_DATE: &str = \"[0-9\\- :]*\"/pub const BUILD_DATE: &str = \"${CURRENT_DATE}\"/g" "$VERSION_FILE"
        log_info "  更新构建日期: ${CURRENT_DATE}"
        UPDATED_COUNT=$((UPDATED_COUNT + 1))
    else
        log_warn "  跳过: 未找到匹配的版本号"
        SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
    fi
else
    log_warn "跳过: $VERSION_FILE (文件不存在)"
    MISSING_COUNT=$((MISSING_COUNT + 1))
fi

echo ""
log_info "--------------------------------------------------"

# 更新 Cargo.lock
log_info ""
log_info "正在更新 Cargo.lock..."
if command -v cargo &> /dev/null; then
    if cargo check --quiet 2>/dev/null; then
        log_info "Cargo.lock 更新成功"
        UPDATED_COUNT=$((UPDATED_COUNT + 1))
    else
        log_warn "Cargo.lock 更新失败，可能存在编译错误"
        SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
    fi
else
    log_warn "未找到 cargo，跳过 Cargo.lock 更新"
    SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
fi

# 显示统计结果
echo ""
log_info "=================================================="
log_info "                    更新完成"
log_info "=================================================="
echo ""
log_info "版本号: ${BLUE}$OLD_VERSION${NC} → ${BLUE}$NEW_VERSION${NC}"
if [ -n "$BUILD_NUMBER" ]; then
    log_info "构建号: ${BLUE}${BUILD_NUMBER}${NC}"
fi
echo ""
log_info "更新成功: ${GREEN}$UPDATED_COUNT${NC} 个文件"
log_info "跳过: ${YELLOW}$SKIPPED_COUNT${NC} 个文件"
log_info "缺失: ${YELLOW}$MISSING_COUNT${NC} 个文件"
echo ""

# 提示用户验证更改
log_info "建议操作:"
log_info "  1. 运行 'git diff' 查看所有变更"
log_info "  2. 验证版本号是否正确更新"
log_info "  3. 提交更改: git commit -m \"Bump version to $NEW_VERSION\""
echo ""
log_info "${GREEN}版本号更新完成！${NC}"