#!/bin/bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

CARGO_MIRRORS=(
    "rsproxy|https://rsproxy.cn/index/|Rsproxy"
    "ustc|https://mirrors.ustc.edu.cn/crates.io-index/|中科大"
    "tuna|https://mirrors.tuna.tsinghua.edu.cn/crates.io-index/|清华大学"
    "aliyun|https://mirrors.aliyun.com/crates.io-index/|阿里云"
)

DOCKER_MIRRORS=(
    "aliyun|https://docker.rainbond.cc|阿里云"
    "daocloud|https://docker.m.daocloud.io|DaoCloud"
    "ustc|https://docker.mirrors.ustc.edu.cn|中科大"
)

GITHUB_MIRRORS=(
    "fastgit|https://hub.fastgit.xyz|GitHub"
    "ghproxy|https://ghproxy.com|Ghproxy"
    "gitclone|https://gitclone.com|Gitclone"
)

test_url_speed() {
    local url=$1
    local name=$2
    
    local start_time=$(date +%s%3N)
    local http_code=$(curl -o /dev/null -s -w "%{http_code}" --connect-timeout 5 -m 10 "$url" 2>/dev/null || echo "000")
    local end_time=$(date +%s%3N)
    
    if [ "$http_code" = "200" ] || [ "$http_code" = "301" ] || [ "$http_code" = "302" ]; then
        local elapsed=$((end_time - start_time))
        echo "$elapsed"
        return 0
    else
        echo "999999"
        return 1
    fi
}

test_mirror() {
    local mirror=$1
    local url=$2
    local name=$3
    local type=$4
    
    printf "${BLUE}Testing ${type} mirror: ${name} (${mirror})${NC}\n"
    
    local speed=$(test_url_speed "$url" "$name")
    
    if [ "$speed" -lt 1000 ]; then
        printf "${GREEN}  ✓ ${name}: ${speed}ms${NC}\n"
        echo "${mirror}|${speed}|${name}" >> /tmp/mirror_test_results.txt
    elif [ "$speed" -lt 5000 ]; then
        printf "${YELLOW}  ⚠ ${name}: ${speed}ms${NC}\n"
        echo "${mirror}|${speed}|${name}" >> /tmp/mirror_test_results.txt
    else
        printf "${RED}  ✗ ${name}: ${speed}ms (timeout)${NC}\n"
    fi
}

test_cargo_mirrors() {
    echo -e "\n${YELLOW}========================================${NC}"
    echo -e "${YELLOW}Testing Rust/Cargo 镜像源${NC}"
    echo -e "${YELLOW}========================================${NC}"
    
    > /tmp/mirror_test_results.txt
    
    for mirror_info in "${CARGO_MIRRORS[@]}"; do
        IFS='|' read -r mirror url name <<< "$mirror_info"
        test_mirror "$mirror" "$url" "$name" "Cargo"
    done
    
    echo -e "\n${BLUE}Cargo 镜像测速结果：${NC}"
    sort -t'|' -k2 -n /tmp/mirror_test_results.txt | while IFS='|' read -r mirror speed name; do
        if [ "$speed" -lt 100 ]; then
            printf "${GREEN}  ✓ ${name} (${mirror}): ${speed}ms - 推荐${NC}\n"
        elif [ "$speed" -lt 500 ]; then
            printf "${YELLOW}  ⚠ ${name} (${mirror}): ${speed}ms${NC}\n"
        else
            printf "${RED}  ✗ ${name} (${mirror}): ${speed}ms${NC}\n"
        fi
    done
    
    local best_mirror=$(sort -t'|' -k2 -n /tmp/mirror_test_results.txt | head -n 1 | cut -d'|' -f1)
    if [ -n "$best_mirror" ]; then
        echo -e "\n${GREEN}推荐 Cargo 镜像源: ${best_mirror}${NC}"
    fi
}

test_docker_mirrors() {
    echo -e "\n${YELLOW}========================================${NC}"
    echo -e "${YELLOW}Testing Docker 镜像源${NC}"
    echo -e "${YELLOW}========================================${NC}"
    
    > /tmp/mirror_test_results.txt
    
    for mirror_info in "${DOCKER_MIRRORS[@]}"; do
        IFS='|' read -r mirror url name <<< "$mirror_info"
        test_mirror "$mirror" "$url" "$name" "Docker"
    done
    
    echo -e "\n${BLUE}Docker 镜像测速结果：${NC}"
    sort -t'|' -k2 -n /tmp/mirror_test_results.txt | while IFS='|' read -r mirror speed name; do
        if [ "$speed" -lt 100 ]; then
            printf "${GREEN}  ✓ ${name} (${mirror}): ${speed}ms - 推荐${NC}\n"
        elif [ "$speed" -lt 500 ]; then
            printf "${YELLOW}  ⚠ ${name} (${mirror}): ${speed}ms${NC}\n"
        else
            printf "${RED}  ✗ ${name} (${mirror}): ${speed}ms${NC}\n"
        fi
    done
    
    local best_mirror=$(sort -t'|' -k2 -n /tmp/mirror_test_results.txt | head -n 1 | cut -d'|' -f1)
    if [ -n "$best_mirror" ]; then
        echo -e "\n${GREEN}推荐 Docker 镜像源: ${best_mirror}${NC}"
    fi
}

test_github_mirrors() {
    echo -e "\n${YELLOW}========================================${NC}"
    echo -e "${YELLOW}Testing GitHub 镜像源${NC}"
    echo -e "${YELLOW}========================================${NC}"
    
    > /tmp/mirror_test_results.txt
    
    for mirror_info in "${GITHUB_MIRRORS[@]}"; do
        IFS='|' read -r mirror url name <<< "$mirror_info"
        test_mirror "$mirror" "$url" "$name" "GitHub"
    done
    
    echo -e "\n${BLUE}GitHub 镜像测速结果：${NC}"
    sort -t'|' -k2 -n /tmp/mirror_test_results.txt | while IFS='|' read -r mirror speed name; do
        if [ "$speed" -lt 200 ]; then
            printf "${GREEN}  ✓ ${name} (${mirror}): ${speed}ms - 推荐${NC}\n"
        elif [ "$speed" -lt 1000 ]; then
            printf "${YELLOW}  ⚠ ${name} (${mirror}): ${speed}ms${NC}\n"
        else
            printf "${RED}  ✗ ${name} (${mirror}): ${speed}ms${NC}\n"
        fi
    done
    
    local best_mirror=$(sort -t'|' -k2 -n /tmp/mirror_test_results.txt | head -n 1 | cut -d'|' -f1)
    if [ -n "$best_mirror" ]; then
        echo -e "\n${GREEN}推荐 GitHub 镜像源: ${best_mirror}${NC}"
    fi
}

test_network() {
    echo -e "\n${YELLOW}========================================${NC}"
    echo -e "${YELLOW}网络连接测试${NC}"
    echo -e "${YELLOW}========================================${NC}"
    
    printf "${BLUE}Testing GitHub connectivity...${NC}\n"
    if curl -I --connect-timeout 5 -m 10 https://github.com > /dev/null 2>&1; then
        printf "${GREEN}  ✓ GitHub: OK${NC}\n"
    else
        printf "${RED}  ✗ GitHub: Failed${NC}\n"
    fi
    
    printf "${BLUE}Testing crates.io connectivity...${NC}\n"
    if curl -I --connect-timeout 5 -m 10 https://crates.io > /dev/null 2>&1; then
        printf "${GREEN}  ✓ crates.io: OK${NC}\n"
    else
        printf "${RED}  ✗ crates.io: Failed${NC}\n"
    fi
    
    printf "${BLUE}Testing Docker Hub connectivity...${NC}\n"
    if curl -I --connect-timeout 5 -m 10 https://registry-1.docker.io > /dev/null 2>&1; then
        printf "${GREEN}  ✓ Docker Hub: OK${NC}\n"
    else
        printf "${RED}  ✗ Docker Hub: Failed${NC}\n"
    fi
}

show_help() {
    cat << EOF
RustDesk 镜像加速测速脚本

用法: $0 [选项]

选项:
    --all           测试所有镜像源（默认）
    --cargo         只测试 Cargo 镜像源
    --docker        只测试 Docker 镜像源
    --github        只测试 GitHub 镜像源
    --network       测试网络连接
    -h, --help      显示帮助信息

示例:
    $0              # 测试所有镜像
    $0 --cargo      # 只测试 Cargo
    $0 --docker     # 只测试 Docker

EOF
}

main() {
    local test_type="${1:-all}"
    
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}RustDesk 镜像加速测速工具${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo -e "${YELLOW}测试时间: $(date '+%Y-%m-%d %H:%M:%S')${NC}\n"
    
    case "$test_type" in
        --all|-a|"")
            test_network
            test_cargo_mirrors
            test_docker_mirrors
            test_github_mirrors
            ;;
        --cargo|-c)
            test_network
            test_cargo_mirrors
            ;;
        --docker|-d)
            test_network
            test_docker_mirrors
            ;;
        --github|-g)
            test_network
            test_github_mirrors
            ;;
        --network|-n)
            test_network
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo -e "${RED}错误: 未知选项 '$test_type'${NC}"
            show_help
            exit 1
            ;;
    esac
    
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}测速完成${NC}"
    echo -e "${BLUE}========================================${NC}\n"
}

main "$@"
