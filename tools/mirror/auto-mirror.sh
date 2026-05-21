#!/bin/bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

show_banner() {
    cat << EOF

${CYAN}╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║   ██████╗  ██████╗ ██████╗ ██╗   ██╗██╗  ██╗                 ║
║   ██╔══██╗██╔═══██╗██╔══██╗██║   ██║╚██╗██╔╝                 ║
║   ██████╔╝██║   ██║██████╔╝██║   ██║ ╚███╔╝                  ║
║   ██╔═══╝ ██║   ██║██╔══██╗██║   ██║ ██╔██╗                  ║
║   ██║     ╚██████╔╝██║  ██║╚██████╔╝██╔╝ ██╗                 ║
║   ╚═╝      ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═╝                 ║
║                                                               ║
║   ${NC}RustDesk 镜像加速一键配置工具${CYAN}                              ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝${NC}

EOF
}

show_help() {
    show_banner
    cat << EOF
${BLUE}用法:${NC} $0 [选项]

${BLUE}选项:${NC}
    --all           配置所有镜像源（Rust/Cargo, Docker, GitHub）
    --cargo         只配置 Rust/Cargo 镜像
    --docker        只配置 Docker 镜像加速
    --github        只配置 GitHub 镜像加速
    --flutter       配置 Flutter/Dart 镜像
    --test          运行镜像测速测试
    --show          显示当前镜像配置
    --reset         重置所有镜像配置
    --auto          自动选择最优镜像源
    --mirror <name> 指定使用的镜像源

${BLUE}可用镜像源:${NC}
    Rust/Cargo:  rsproxy (默认), ustc, tuna, aliyun
    Docker:      aliyun, daocloud, ustc, rainbond
    GitHub:      fastgit (默认), ghproxy, gitclone

${BLUE}示例:${NC}
    $0 --all              # 配置所有镜像
    $0 --cargo            # 只配置 Rust/Cargo
    $0 --docker           # 只配置 Docker
    $0 --github           # 只配置 GitHub
    $0 --test             # 测试所有镜像
    $0 --auto             # 自动选择最优镜像
    $0 --all --mirror rsproxy  # 使用 rsproxy 配置所有镜像

${BLUE}提示:${NC}
    - 需要 root/sudo 权限来修改系统配置
    - 配置完成后会自动验证
    - 可以使用 --show 查看当前配置

EOF
}

check_root() {
    if [ "$EUID" -ne 0 ] && [ "$1" = "docker" ]; then
        echo -e "${YELLOW}警告: 修改 Docker 配置需要管理员权限${NC}"
        echo -e "${YELLOW}将尝试使用 sudo...${NC}"
        return 1
    fi
    return 0
}

check_dependencies() {
    echo -e "${BLUE}检查依赖...${NC}"
    
    local missing_deps=()
    
    if [ "$1" = "cargo" ] || [ "$1" = "all" ]; then
        if ! command -v cargo &> /dev/null && ! command -v rustup &> /dev/null; then
            missing_deps+=("Rust/Cargo")
        fi
    fi
    
    if [ "$1" = "docker" ] || [ "$1" = "all" ]; then
        if ! command -v docker &> /dev/null; then
            missing_deps+=("Docker")
        fi
    fi
    
    if [ "$1" = "github" ] || [ "$1" = "all" ]; then
        if ! command -v git &> /dev/null; then
            missing_deps+=("Git")
        fi
    fi
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo -e "${YELLOW}警告: 以下工具未安装: ${missing_deps[*]}${NC}"
        echo -e "${YELLOW}相关镜像配置将被跳过${NC}"
    fi
    
    echo -e "${GREEN}依赖检查完成${NC}"
}

run_speed_test() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}运行镜像测速...${NC}"
    echo -e "${BLUE}========================================${NC}"
    
    if [ -f "${SCRIPT_DIR}/test-mirror-speed.sh" ]; then
        chmod +x "${SCRIPT_DIR}/test-mirror-speed.sh"
        "${SCRIPT_DIR}/test-mirror-speed.sh" --all
    else
        echo -e "${RED}测速脚本不存在${NC}"
        return 1
    fi
}

configure_cargo() {
    local mirror="${1:-rsproxy}"
    
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}配置 Rust/Cargo 镜像: ${mirror}${NC}"
    echo -e "${BLUE}========================================${NC}"
    
    if [ -f "${SCRIPT_DIR}/set-rust-mirror.sh" ]; then
        chmod +x "${SCRIPT_DIR}/set-rust-mirror.sh"
        
        if [ "$EUID" -eq 0 ]; then
            sudo -u "$SUDO_USER" "${SCRIPT_DIR}/set-rust-mirror.sh" "$mirror" 2>/dev/null || \
            "${SCRIPT_DIR}/set-rust-mirror.sh" "$mirror"
        else
            "${SCRIPT_DIR}/set-rust-mirror.sh" "$mirror"
        fi
        
        echo -e "${GREEN}✓ Rust/Cargo 镜像配置完成${NC}"
    else
        echo -e "${RED}Rust/Cargo 配置脚本不存在${NC}"
        return 1
    fi
}

configure_docker() {
    local mirror="${1:-daocloud}"
    
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}配置 Docker 镜像加速: ${mirror}${NC}"
    echo -e "${BLUE}========================================${NC}"
    
    if [ -f "${SCRIPT_DIR}/set-docker-mirror.sh" ]; then
        chmod +x "${SCRIPT_DIR}/set-docker-mirror.sh"
        
        if [ "$EUID" -eq 0 ]; then
            sudo -u "$SUDO_USER" "${SCRIPT_DIR}/set-docker-mirror.sh" "$mirror" 2>/dev/null || \
            "${SCRIPT_DIR}/set-docker-mirror.sh" "$mirror"
        else
            if ! check_root "docker"; then
                echo -e "${YELLOW}跳过 Docker 配置（需要管理员权限）${NC}"
                return 0
            fi
            "${SCRIPT_DIR}/set-docker-mirror.sh" "$mirror"
        fi
        
        echo -e "${GREEN}✓ Docker 镜像加速配置完成${NC}"
    else
        echo -e "${RED}Docker 配置脚本不存在${NC}"
        return 1
    fi
}

configure_github() {
    local mirror="${1:-fastgit}"
    
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}配置 GitHub 镜像加速: ${mirror}${NC}"
    echo -e "${BLUE}========================================${NC}"
    
    if [ -f "${SCRIPT_DIR}/set-github-mirror.sh" ]; then
        chmod +x "${SCRIPT_DIR}/set-github-mirror.sh"
        
        if [ "$EUID" -eq 0 ]; then
            sudo -u "$SUDO_USER" "${SCRIPT_DIR}/set-github-mirror.sh" "$mirror" 2>/dev/null || \
            "${SCRIPT_DIR}/set-github-mirror.sh" "$mirror"
        else
            "${SCRIPT_DIR}/set-github-mirror.sh" "$mirror"
        fi
        
        echo -e "${GREEN}✓ GitHub 镜像加速配置完成${NC}"
    else
        echo -e "${RED}GitHub 配置脚本不存在${NC}"
        return 1
    fi
}

configure_flutter() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}配置 Flutter/Dart 镜像${NC}"
    echo -e "${BLUE}========================================${NC}"
    
    if command -v flutter &> /dev/null; then
        flutter config --global pub url https://pub.flutter-io.cn
        
        export PUB_HOSTED_URL="https://pub.flutter-io.cn"
        export FLUTTER_STORAGE_BASE_URL="https://storage.flutter-io.cn"
        
        cat >> "$HOME/.bashrc" << 'EOF'

# Flutter 镜像配置
export PUB_HOSTED_URL="https://pub.flutter-io.cn"
export FLUTTER_STORAGE_BASE_URL="https://storage.flutter-io.cn"
EOF
        
        echo -e "${GREEN}✓ Flutter/Dart 镜像配置完成${NC}"
        echo -e "${YELLOW}请运行 'source ~/.bashrc' 或重新打开终端使配置生效${NC}"
    else
        echo -e "${YELLOW}Flutter 未安装，跳过配置${NC}"
    fi
}

reset_all() {
    echo -e "${YELLOW}========================================${NC}"
    echo -e "${YELLOW}重置所有镜像配置${NC}"
    echo -e "${YELLOW}========================================${NC}"
    
    if [ -f "${SCRIPT_DIR}/set-rust-mirror.sh" ]; then
        chmod +x "${SCRIPT_DIR}/set-rust-mirror.sh"
        "${SCRIPT_DIR}/set-rust-mirror.sh" --reset
    fi
    
    if [ -f "${SCRIPT_DIR}/set-docker-mirror.sh" ]; then
        chmod +x "${SCRIPT_DIR}/set-docker-mirror.sh"
        "${SCRIPT_DIR}/set-docker-mirror.sh" --reset
    fi
    
    if [ -f "${SCRIPT_DIR}/set-github-mirror.sh" ]; then
        chmod +x "${SCRIPT_DIR}/set-github-mirror.sh"
        "${SCRIPT_DIR}/set-github-mirror.sh" --reset
    fi
    
    echo -e "${GREEN}✓ 所有镜像配置已重置${NC}"
}

show_current_config() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}当前镜像配置${NC}"
    echo -e "${BLUE}========================================${NC}"
    
    if [ -f "${SCRIPT_DIR}/set-rust-mirror.sh" ]; then
        chmod +x "${SCRIPT_DIR}/set-rust-mirror.sh"
        "${SCRIPT_DIR}/set-rust-mirror.sh" --show
    fi
    
    if [ -f "${SCRIPT_DIR}/set-docker-mirror.sh" ]; then
        chmod +x "${SCRIPT_DIR}/set-docker-mirror.sh"
        "${SCRIPT_DIR}/set-docker-mirror.sh" --show
    fi
    
    if [ -f "${SCRIPT_DIR}/set-github-mirror.sh" ]; then
        chmod +x "${SCRIPT_DIR}/set-github-mirror.sh"
        "${SCRIPT_DIR}/set-github-mirror.sh" --show
    fi
}

auto_select_mirrors() {
    echo -e "${BLUE}自动选择最优镜像源...${NC}"
    
    run_speed_test
    
    sleep 2
    
    local best_cargo=$(sort -t'|' -k2 -n /tmp/mirror_test_results.txt 2>/dev/null | grep -E "rsproxy|ustc|tuna|aliyun" | head -n 1 | cut -d'|' -f1)
    local best_docker=$(sort -t'|' -k2 -n /tmp/mirror_test_results.txt 2>/dev/null | grep -E "rainbond|daocloud|ustc" | head -n 1 | cut -d'|' -f1)
    local best_github=$(sort -t'|' -k2 -n /tmp/mirror_test_results.txt 2>/dev/null | grep -E "fastgit|ghproxy|gitclone" | head -n 1 | cut -d'|' -f1)
    
    echo -e "${GREEN}最优镜像源选择:${NC}"
    echo -e "  Rust/Cargo: ${best_cargo:-rsproxy}"
    echo -e "  Docker:      ${best_docker:-daocloud}"
    echo -e "  GitHub:      ${best_github:-fastgit}"
    
    echo ""
    read -p "是否使用这些镜像源配置? (Y/n) " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        if command -v cargo &> /dev/null || command -v rustup &> /dev/null; then
            configure_cargo "${best_cargo:-rsproxy}"
        fi
        
        if command -v docker &> /dev/null; then
            configure_docker "${best_docker:-daocloud}"
        fi
        
        if command -v git &> /dev/null; then
            configure_github "${best_github:-fastgit}"
        fi
        
        echo -e "${GREEN}✓ 自动配置完成！${NC}"
    else
        echo -e "${YELLOW}取消自动配置${NC}"
    fi
}

main() {
    local action="all"
    local cargo_mirror="rsproxy"
    local docker_mirror="daocloud"
    local github_mirror="fastgit"
    local auto_mode=false
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --all|-a)
                action="all"
                shift
                ;;
            --cargo|-c)
                action="cargo"
                shift
                ;;
            --docker|-d)
                action="docker"
                shift
                ;;
            --github|-g)
                action="github"
                shift
                ;;
            --flutter|-f)
                action="flutter"
                shift
                ;;
            --test|-t)
                action="test"
                shift
                ;;
            --show|-s)
                action="show"
                shift
                ;;
            --reset|-r)
                action="reset"
                shift
                ;;
            --auto)
                auto_mode=true
                shift
                ;;
            --mirror|-m)
                cargo_mirror="$2"
                docker_mirror="$2"
                github_mirror="$2"
                shift 2
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                echo -e "${RED}错误: 未知选项 '$1'${NC}"
                show_help
                exit 1
                ;;
        esac
    done
    
    show_banner
    
    case "$action" in
        all)
            check_dependencies "all"
            
            if [ "$auto_mode" = true ]; then
                auto_select_mirrors
            else
                configure_cargo "$cargo_mirror"
                configure_docker "$docker_mirror"
                configure_github "$github_mirror"
            fi
            ;;
        cargo)
            check_dependencies "cargo"
            configure_cargo "$cargo_mirror"
            ;;
        docker)
            check_dependencies "docker"
            configure_docker "$docker_mirror"
            ;;
        github)
            check_dependencies "github"
            configure_github "$github_mirror"
            ;;
        flutter)
            configure_flutter
            ;;
        test)
            run_speed_test
            ;;
        show)
            show_current_config
            ;;
        reset)
            reset_all
            ;;
    esac
    
    echo ""
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                                                               ║${NC}"
    echo -e "${CYAN}║  ${NC}✓ 配置完成！${CYAN}                                                 ║${NC}"
    echo -e "${CYAN}║                                                               ║${NC}"
    echo -e "${CYAN}║  ${NC}下一步:${CYAN}                                                       ║${NC}"
    echo -e "${CYAN}║    1. 重启终端或运行 'source ~/.bashrc'                   ║${NC}"
    echo -e "${CYAN}║    2. 运行 '$0 --test' 测试镜像速度                         ║${NC}"
    echo -e "${CYAN}║    3. 查看配置: '$0 --show'                              ║${NC}"
    echo -e "${CYAN}║                                                               ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

main "$@"
