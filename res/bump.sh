#! /usr/bin/env bash

# res/bump.sh 是一个开发者手动使用的脚本，主要用于：
# 发布新版本时手动更新项目版本号
# 需要开发者在命令行中手动执行，例如：
# ./res/bump.sh 1.5.1 1.5.2

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

usage() {
    echo "Usage: $0 <old_version> <new_version>"
    echo "Example: $0 1.5.1 1.5.2"
    exit 1
}

if [ $# -ne 2 ]; then
    log_error "Invalid number of arguments"
    usage
fi

OLD_VERSION="$1"
NEW_VERSION="$2"

if [ -z "$OLD_VERSION" ] || [ -z "$NEW_VERSION" ]; then
    log_error "Version arguments cannot be empty"
    usage
fi

log_info "Bumping version from $OLD_VERSION to $NEW_VERSION"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

SED_INPLACE=()
if [[ "$OSTYPE" == "darwin"* ]]; then
    SED_INPLACE=("-i" "")
else
    SED_INPLACE=("-i")
fi

FILES=(
    "res/*spec"
    "res/PKGBUILD"
    "flutter/pubspec.yaml"
    "Cargo.toml"
    ".github/workflows/*yml"
    "flatpak/*json"
    "appimage/*yml"
    "libs/portable/Cargo.toml"
)

for file_pattern in "${FILES[@]}"; do
    for file in $file_pattern; do
        if [ -f "$file" ]; then
            if grep -q "$OLD_VERSION" "$file" 2>/dev/null; then
                log_info "Updating $file"
                sed "${SED_INPLACE[@]}" "s/$OLD_VERSION/$NEW_VERSION/g" "$file"
            else
                log_warn "$file does not contain $OLD_VERSION, skipping"
            fi
        else
            log_warn "$file does not exist, skipping"
        fi
    done
done

log_info "Updating Cargo.lock"
if command -v cargo &> /dev/null; then
    cargo check --quiet
    log_info "Cargo.lock updated successfully"
else
    log_warn "cargo not found, skipping Cargo.lock update"
fi

log_info "Version bump completed successfully from $OLD_VERSION to $NEW_VERSION"
