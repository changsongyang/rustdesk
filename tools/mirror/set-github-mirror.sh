#!/bin/bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

show_help() {
    cat << EOF
RustDesk GitHub 镜像加速配置脚本

用法: $0 [镜像源] [选项]

可用镜像源:
    fastgit         FastGit 镜像（推荐）
    ghproxy         Ghproxy 代理
    gitclone        GitClone 镜像
    ghpig           GHPig 代理
    custom          自定义镜像地址

Git 协议转换:
    - https         使用 HTTPS 协议（默认）
    - ssh           使用 SSH 协议（需要 SSH key）

选项:
    -a, --address     设置自定义镜像地址
    -p, --protocol    设置协议类型 (https/ssh)
    -s, --show        显示当前配置
    -r, --reset       重置为原始 GitHub 地址
    -t, --test        测试镜像源可用性
    -g, --global      仅修改全局 Git 配置
    -l, --local       仅修改当前仓库配置
    -h, --help        显示帮助信息

示例:
    $0 fastgit              # 使用 FastGit 镜像
    $0 ghproxy               # 使用 Ghproxy 代理
    $0 -p ssh               # 配置 SSH 协议
    $0 --show               # 显示当前配置
    $0 --reset              # 重置为原始地址

配置文件位置:
    全局配置: ~/.gitconfig
    系统配置: /etc/gitconfig
    仓库配置: .git/config

SSH 配置:
    SSH 配置: ~/.ssh/config
    支持配置代理和端口转发

EOF
}

get_gitconfig_path() {
    echo "$HOME/.gitconfig"
}

get_sshconfig_path() {
    echo "$HOME/.ssh/config"
}

show_current_config() {
    local gitconfig=$(get_gitconfig_path)
    local sshconfig=$(get_sshconfig_path)
    
    echo -e "${BLUE}GitHub 镜像加速配置信息${NC}"
    echo -e "${YELLOW}========================================${NC}"
    
    if [ -f "$gitconfig" ]; then
        echo -e "\n${BLUE}Git 全局配置 (.gitconfig):${NC}"
        grep -A 5 "url\." "$gitconfig" 2>/dev/null || echo "未配置镜像"
    fi
    
    if [ -f "$sshconfig" ]; then
        echo -e "\n${BLUE}SSH 配置 (.ssh/config):${NC}"
        grep -A 10 "Host github.com" "$sshconfig" 2>/dev/null || echo "未配置 GitHub SSH"
    fi
    
    echo -e "\n${BLUE}测试 GitHub 连接:${NC}"
    if curl -I --connect-timeout 5 -m 10 https://github.com > /dev/null 2>&1; then
        echo -e "${GREEN}✓ GitHub: 可访问${NC}"
    else
        echo -e "${RED}✗ GitHub: 不可访问${NC}"
    fi
    
    echo -e "${YELLOW}========================================${NC}"
}

test_github_mirror() {
    local url=$1
    local name=$2
    
    echo -n "Testing ${name} (${url})... "
    
    if curl -I --connect-timeout 5 -m 10 "$url" > /dev/null 2>&1; then
        echo -e "${GREEN}OK${NC}"
        return 0
    else
        echo -e "${RED}Failed${NC}"
        return 1
    fi
}

test_all_github_mirrors() {
    echo -e "${BLUE}测试 GitHub 镜像源可用性:${NC}"
    echo -e "${YELLOW}========================================${NC}"
    
    test_github_mirror "https://hub.fastgit.xyz/" "FastGit"
    test_github_mirror "https://ghproxy.com/" "Ghproxy"
    test_github_mirror "https://gitclone.com/" "GitClone"
    test_github_mirror "https://ghproxy.cn/" "Ghproxy CN"
    
    echo ""
    
    echo -e "${BLUE}测试 GitHub API:${NC}"
    if curl -I --connect-timeout 5 -m 10 https://api.github.com > /dev/null 2>&1; then
        echo -e "${GREEN}✓ GitHub API: 可访问${NC}"
    else
        echo -e "${RED}✗ GitHub API: 不可访问${NC}"
    fi
    
    echo -e "${YELLOW}========================================${NC}"
}

configure_git_https() {
    local mirror=$1
    local custom_address="${2:-}"
    local gitconfig=$(get_gitconfig_path)
    local scope="${3:-global}"
    
    local base_url=""
    
    case "$mirror" in
        fastgit)
            base_url="https://hub.fastgit.xyz/"
            ;;
        ghproxy)
            base_url="https://ghproxy.com/"
            ;;
        gitclone)
            base_url="https://gitclone.com/github.com/"
            ;;
        ghpig)
            base_url="https://ghproxy.cn/"
            ;;
        custom)
            if [ -z "$custom_address" ]; then
                echo -e "${RED}错误: 使用 custom 镜像源时需要提供 --address 参数${NC}"
                return 1
            fi
            base_url="$custom_address"
            ;;
        none)
            base_url=""
            ;;
        *)
            echo -e "${RED}未知的镜像源: ${mirror}${NC}"
            return 1
            ;;
    esac
    
    local git_cmd="git config"
    if [ "$scope" = "global" ]; then
        git_cmd="git config --global"
    fi
    
    if [ -n "$base_url" ]; then
        echo -e "${BLUE}配置 Git HTTPS 镜像: ${mirror}${NC}"
        
        $git_cmd --replace-all url."https://github.com/".insteadOf "https://github.com/"
        $git_cmd --replace-all url."https://github.com/".insteadOf "git@github.com:"
        $git_cmd --replace-all url."${base_url}".insteadOf "https://github.com/"
        $git_cmd --replace-all url."${base_url}".insteadOf "git@github.com:"
        
        $git_cmd http.postBuffer 524288000
        $git_cmd http.timeout 60
        $git_cmd http.lowSpeedLimit 1000
        $git_cmd http.lowSpeedTime 60
        
        if command -v git-lfs &> /dev/null; then
            $git_cmd lfs.concurrenttransfers 8
        fi
        
        echo -e "${GREEN}✓ Git HTTPS 镜像配置完成${NC}"
        echo -e "${GREEN}  镜像地址: ${base_url}${NC}"
    else
        echo -e "${YELLOW}移除 Git 镜像配置${NC}"
        
        $git_cmd --unset-all url."https://hub.fastgit.xyz/".insteadOf 2>/dev/null || true
        $git_cmd --unset-all url."https://ghproxy.com/".insteadOf 2>/dev/null || true
        $git_cmd --unset-all url."https://gitclone.com/github.com/".insteadOf 2>/dev/null || true
        $git_cmd --unset-all url."https://ghproxy.cn/".insteadOf 2>/dev/null || true
        
        echo -e "${GREEN}✓ 已移除 Git 镜像配置${NC}"
    fi
}

configure_git_ssh() {
    local mirror=$1
    local sshconfig=$(get_sshconfig_path)
    local scope="${2:-global}"
    
    local ssh_host_entry=""
    
    case "$mirror" in
        fastgit)
            echo -e "${YELLOW}FastGit 主要用于 HTTPS，不推荐 SSH${NC}"
            return 1
            ;;
        ghproxy)
            ssh_host_entry="Host github.com
    HostName github.com
    User git
    Port 443
    ProxyCommand C:\\Windows\\System32\\connect.exe -H 127.0.0.1:7890 %h %p"
            ;;
        ghpig)
            ssh_host_entry="Host github.com
    HostName github.com
    User git
    ProxyCommand nc -X 5 -x 127.0.0.1:7890 %h %p"
            ;;
        none)
            echo -e "${YELLOW}移除 SSH 代理配置${NC}"
            if [ -f "$sshconfig" ]; then
                cp "$sshconfig" "${sshconfig}.backup.$(date +%Y%m%d_%H%M%S)"
            fi
            return 0
            ;;
        *)
            echo -e "${RED}未知的镜像源: ${mirror}${NC}"
            return 1
            ;;
    esac
    
    mkdir -p "$(dirname "$sshconfig")"
    touch "$sshconfig"
    
    if [ -f "$sshconfig" ]; then
        cp "$sshconfig" "${sshconfig}.backup.$(date +%Y%m%d_%H%M%S)"
    fi
    
    cat > "$sshconfig" << EOF
Host github.com
    HostName github.com
    User git
    Port 443
    ProxyCommand connect -H 127.0.0.1:7890 %h %p

Host ghproxy.com
    HostName ghproxy.com
    User git
    ProxyCommand connect -H 127.0.0.1:7890 %h %p
EOF
    
    chmod 600 "$sshconfig"
    
    echo -e "${GREEN}✓ SSH 代理配置完成${NC}"
    echo -e "${GREEN}  配置文件: ${sshconfig}${NC}"
    echo -e "${YELLOW}  注意: 请将 127.0.0.1:7890 替换为您的代理地址${NC}"
}

reset_git_config() {
    local gitconfig=$(get_gitconfig_path)
    local sshconfig=$(get_sshconfig_path)
    
    echo -e "${BLUE}重置 GitHub 镜像配置${NC}"
    
    if [ -f "$gitconfig" ]; then
        cp "$gitconfig" "${gitconfig}.backup.$(date +%Y%m%d_%H%M%S)"
        
        git config --global --unset-all url."https://hub.fastgit.xyz/".insteadOf 2>/dev/null || true
        git config --global --unset-all url."https://ghproxy.com/".insteadOf 2>/dev/null || true
        git config --global --unset-all url."https://gitclone.com/github.com/".insteadOf 2>/dev/null || true
        git config --global --unset-all url."https://ghproxy.cn/".insteadOf 2>/dev/null || true
        git config --global --unset-all url."https://mirror.ghproxy.com/".insteadOf 2>/dev/null || true
        
        git config --global --unset http.postBuffer 2>/dev/null || true
        git config --global --unset http.timeout 2>/dev/null || true
        
        echo -e "${GREEN}✓ Git 全局配置已重置${NC}"
    else
        echo -e "${YELLOW}Git 全局配置文件不存在${NC}"
    fi
    
    if [ -f "$sshconfig" ]; then
        mv "$sshconfig" "${sshconfig}.backup.$(date +%Y%m%d_%H%M%S)"
        echo -e "${GREEN}✓ SSH 配置已备份${NC}"
    fi
    
    echo -e "${GREEN}✓ 重置完成${NC}"
}

verify_git_config() {
    echo -e "\n${BLUE}验证 Git 配置:${NC}"
    echo -e "${YELLOW}========================================${NC}"
    
    if command -v git &> /dev/null; then
        echo -e "${BLUE}Git 版本:${NC}"
        git --version
        
        echo -e "\n${BLUE}当前镜像配置:${NC}"
        git config --global --get-all url.*.insteadOf 2>/dev/null || echo "未配置镜像"
        
        echo -e "\n${BLUE}测试克隆 (使用镜像):${NC}"
        cd /tmp
        rm -rf git_test 2>/dev/null || true
        if timeout 30 git clone --depth 1 https://github.com/RustDesk/rustdesk.git git_test > /dev/null 2>&1; then
            echo -e "${GREEN}✓ Git 克隆测试成功${NC}"
            rm -rf git_test
        else
            echo -e "${RED}✗ Git 克隆测试失败${NC}"
        fi
    else
        echo -e "${YELLOW}Git 未安装${NC}"
    fi
    
    echo -e "${YELLOW}========================================${NC}"
}

test_git_clone() {
    local mirror=$1
    local repo="${2:-RustDesk/rustdesk}"
    
    echo -e "${BLUE}测试 Git 克隆速度 (${repo}):${NC}"
    
    cd /tmp
    rm -rf git_clone_test 2>/dev/null || true
    
    local start_time=$(date +%s)
    
    if timeout 60 git clone --depth 1 "https://github.com/${repo}" git_clone_test > /dev/null 2>&1; then
        local end_time=$(date +%s)
        local elapsed=$((end_time - start_time))
        echo -e "${GREEN}✓ 克隆成功，耗时: ${elapsed}秒${NC}"
        rm -rf git_clone_test
        return 0
    else
        echo -e "${RED}✗ 克隆失败${NC}"
        rm -rf git_clone_test
        return 1
    fi
}

main() {
    local mirror=""
    local custom_address=""
    local protocol="https"
    local scope="global"
    local show_config=false
    local reset_config=false
    local test_mode=false
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -s|--show)
                show_config=true
                shift
                ;;
            -r|--reset)
                reset_config=true
                shift
                ;;
            -t|--test)
                test_mode=true
                shift
                ;;
            -a|--address)
                custom_address="$2"
                shift 2
                ;;
            -p|--protocol)
                protocol="$2"
                shift 2
                ;;
            -g|--global)
                scope="global"
                shift
                ;;
            -l|--local)
                scope="local"
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            fastgit|ghproxy|gitclone|ghpig|custom|none)
                mirror="$1"
                shift
                ;;
            *)
                echo -e "${RED}错误: 未知选项 '$1'${NC}"
                show_help
                exit 1
                ;;
        esac
    done
    
    if [ "$show_config" = true ]; then
        show_current_config
        exit 0
    fi
    
    if [ "$reset_config" = true ]; then
        reset_git_config
        exit 0
    fi
    
    if [ "$test_mode" = true ]; then
        test_all_github_mirrors
        test_git_clone "$mirror"
        exit 0
    fi
    
    if [ -z "$mirror" ]; then
        echo -e "${RED}错误: 未指定镜像源${NC}"
        show_help
        exit 1
    fi
    
    echo -e "${BLUE}配置 GitHub 镜像加速: ${mirror}${NC}"
    echo -e "${BLUE}使用协议: ${protocol}${NC}"
    echo -e "${BLUE}配置范围: ${scope}${NC}"
    
    case "$protocol" in
        https|HTTPS|https://)
            configure_git_https "$mirror" "$custom_address" "$scope"
            ;;
        ssh|SSH|ssh://)
            configure_git_ssh "$mirror" "$scope"
            ;;
        *)
            echo -e "${RED}未知的协议类型: ${protocol}${NC}"
            echo -e "${YELLOW}支持的协议: https, ssh${NC}"
            exit 1
            ;;
    esac
    
    echo ""
    echo -e "${GREEN}✓ 配置完成！${NC}"
    echo ""
    
    read -p "是否验证配置? (Y/n) " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        verify_git_config
    fi
}

main "$@"
