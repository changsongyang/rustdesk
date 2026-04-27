#!/bin/bash
"""
RustDesk 本地环境设置脚本
功能：
1. 自动安装必需工具
2. 配置环境变量
3. 验证环境一致性
"""

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

PROJECT_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

# 检测操作系统
detect_os() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "osx"
    elif [[ "$OSTYPE" == "cygwin" || "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
        echo "windows"
    else
        echo "linux"
    fi
}

OS=$(detect_os)
log_info "检测到操作系统: $OS"

# 检查 Rust
check_rust() {
    if command -v rustc &> /dev/null; then
        RUST_VERSION=$(rustc --version)
        log_info "Rust 已安装: $RUST_VERSION"
        return 0
    fi
    return 1
}

# 安装 Rust
install_rust() {
    if ! check_rust; then
        log_info "安装 Rust..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        
        # 加载 rustup 环境
        if [ -f "$HOME/.cargo/env" ]; then
            source "$HOME/.cargo/env"
        fi
        
        # 安装指定版本
        log_info "安装 Rust 1.95..."
        rustup install 1.95
        rustup default 1.95
        
        log_info "Rust 安装完成"
    fi
}

# 检查 Flutter
check_flutter() {
    if command -v flutter &> /dev/null; then
        FLUTTER_VERSION=$(flutter --version | head -1)
        log_info "Flutter 已安装: $FLUTTER_VERSION"
        return 0
    fi
    return 1
}

# 检查 vcpkg
check_vcpkg() {
    if [ -n "$VCPKG_ROOT" ] && [ -d "$VCPKG_ROOT" ]; then
        log_info "vcpkg 已配置: $VCPKG_ROOT"
        return 0
    fi
    return 1
}

# 设置环境变量
setup_env_vars() {
    log_info "设置环境变量..."
    
    CARGO_BIN="$HOME/.cargo/bin"
    if [ -d "$CARGO_BIN" ]; then
        export PATH="$CARGO_BIN:$PATH"
        log_info "已添加到 PATH: $CARGO_BIN"
    fi
    
    # 如果 vcpkg 不存在，提示用户
    if [ -z "$VCPKG_ROOT" ]; then
        log_warning "VCPKG_ROOT 未设置，请运行 vcpkg 安装后设置此环境变量"
        log_warning "推荐: export VCPKG_ROOT=$PROJECT_ROOT/vcpkg"
    fi
}

# 验证环境
validate_env() {
    log_info "验证环境..."
    
    local all_ok=true
    
    # 验证 Rust
    if ! check_rust; then
        log_error "Rust 不可用"
        all_ok=false
    fi
    
    # 验证 Cargo
    if ! command -v cargo &> /dev/null; then
        log_error "Cargo 不可用"
        all_ok=false
    else
        log_info "Cargo 可用: $(cargo --version)"
    fi
    
    # 验证 Python
    if ! command -v python3 &> /dev/null; then
        log_error "Python3 不可用"
        all_ok=false
    else
        log_info "Python3 可用: $(python3 --version)"
    fi
    
    if [ "$all_ok" = true ]; then
        log_info "环境验证通过 ✓"
    else
        log_error "环境验证失败 ✗"
        return 1
    fi
}

# 显示帮助
show_help() {
    echo "RustDesk 本地环境设置脚本"
    echo ""
    echo "使用方法:"
    echo "  $0 [选项]"
    echo ""
    echo "选项:"
    echo "  --install-rust    安装 Rust"
    echo "  --check-only      仅检查环境，不安装"
    echo "  --help            显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  $0                    # 检查并设置环境"
    echo "  $0 --install-rust     # 安装 Rust 并设置环境"
    echo "  $0 --check-only       # 仅检查环境"
}

# 主函数
main() {
    cd "$PROJECT_ROOT"
    
    local install_rust_flag=false
    local check_only=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --install-rust)
                install_rust_flag=true
                shift
                ;;
            --check-only)
                check_only=true
                shift
                ;;
            --help)
                show_help
                return 0
                ;;
            *)
                log_error "未知选项: $1"
                show_help
                return 1
                ;;
        esac
    done
    
    log_info "RustDesk 本地环境设置脚本"
    log_info "项目根目录: $PROJECT_ROOT"
    echo ""
    
    # 检查 Rust
    if [ "$install_rust_flag" = true ]; then
        install_rust
    else
        if ! check_rust; then
            log_warning "Rust 未安装，使用 --install-rust 安装"
        fi
    fi
    
    # 设置环境变量
    setup_env_vars
    
    # 如果不是仅检查模式，继续验证
    if [ "$check_only" = false ]; then
        validate_env
    fi
    
    echo ""
    log_info "完成！请运行以下命令以加载环境变量:"
    echo "  source ~/.cargo/env  # Linux/macOS"
    echo ""
    log_info "运行构建辅助脚本以进行诊断:"
    echo "  python3 scripts/build_helper.py --diagnose"
}

main "$@"
