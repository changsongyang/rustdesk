#!/usr/bin/env bash
#
# Script Name: check-deps.sh
# Description: Check build dependencies and versions for rustdesk
# Version: 1.0.0
# Author: Build Team
# Usage: ./check-deps.sh [options]

set -euo pipefail

# --------------------------
# Configuration
# --------------------------
readonly RUST_VERSION_REQUIRED="1.81.0"
readonly FLUTTER_VERSION_REQUIRED="3.24.5"
readonly LLVM_VERSION_REQUIRED="15.0.6"

# --------------------------
# Logging Functions
# --------------------------
log_debug()   { [[ "${VERBOSE:-0}" -eq 1 ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] [DEBUG]   $1"; }
log_info()    { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO]    $1"; }
log_warn()    { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARN]    $1" >&2; }
log_error()   { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR]   $1" >&2; }
log_success() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [SUCCESS] $1"; }

# --------------------------
# Error Handling
# --------------------------
error_exit() {
    log_error "$1"
    exit "${2:-1}"
}

# --------------------------
# Version Comparison Functions
# --------------------------
version_ge() {
    # Check if version1 >= version2
    local v1="$1"
    local v2="$2"
    [[ "$(printf '%s\n' "$v1" "$v2" | sort -V | head -n1)" == "$v2" ]]
}

version_lt() {
    # Check if version1 < version2
    local v1="$1"
    local v2="$2"
    [[ "$(printf '%s\n' "$v1" "$v2" | sort -V | head -n1)" == "$v1" ]]
}

extract_version() {
    # Extract version string from various formats
    echo "$1" | sed -E 's/[^0-9.]*([0-9]+\.[0-9]+(\.[0-9]+)?).*/\1/'
}

# --------------------------
# Dependency Check Functions
# --------------------------
check_command_exists() {
    local cmd="$1"
    local name="$2"
    
    log_debug "Checking if $name is available..."
    
    if command -v "$cmd" &>/dev/null; then
        log_info "$name found: $(command -v "$cmd")"
        return 0
    else
        log_warn "$name not found in PATH"
        return 1
    fi
}

check_rust_version() {
    log_info "Checking Rust version..."
    
    if ! check_command_exists "rustc" "rustc"; then
        error_exit "Rust compiler not found. Please install Rust from https://www.rust-lang.org/tools/install" 3
    fi
    
    local rust_version
    rust_version=$(rustc --version | extract_version)
    log_info "Found Rust version: $rust_version"
    log_info "Required Rust version: $RUST_VERSION_REQUIRED"
    
    if version_lt "$rust_version" "$RUST_VERSION_REQUIRED"; then
        error_exit "Rust version $rust_version is too old. Required: $RUST_VERSION_REQUIRED" 4
    fi
    
    log_success "Rust version check passed"
}

check_cargo_version() {
    log_info "Checking Cargo version..."
    
    if ! check_command_exists "cargo" "cargo"; then
        error_exit "Cargo not found. Please install Rust from https://www.rust-lang.org/tools/install" 3
    fi
    
    local cargo_version
    cargo_version=$(cargo --version | extract_version)
    log_info "Found Cargo version: $cargo_version"
    
    log_success "Cargo check passed"
}

check_flutter_version() {
    log_info "Checking Flutter version..."
    
    if ! check_command_exists "flutter" "flutter"; then
        log_warn "Flutter not found - skipping Flutter version check"
        return 0
    fi
    
    local flutter_version
    flutter_version=$(flutter --version | grep -i "Flutter" | extract_version)
    log_info "Found Flutter version: $flutter_version"
    log_info "Required Flutter version: $FLUTTER_VERSION_REQUIRED"
    
    if version_lt "$flutter_version" "$FLUTTER_VERSION_REQUIRED"; then
        log_warn "Flutter version $flutter_version is older than recommended $FLUTTER_VERSION_REQUIRED"
    else
        log_success "Flutter version check passed"
    fi
}

check_llvm_version() {
    log_info "Checking LLVM/clang version..."
    
    if ! check_command_exists "clang" "clang"; then
        log_warn "clang not found - skipping LLVM version check"
        return 0
    fi
    
    local clang_version
    clang_version=$(clang --version | extract_version)
    log_info "Found clang version: $clang_version"
    
    log_success "LLVM/clang check passed"
}

check_vcpkg() {
    log_info "Checking vcpkg..."
    
    if check_command_exists "vcpkg" "vcpkg"; then
        local vcpkg_version
        vcpkg_version=$("$VCPKG_ROOT/vcpkg" version 2>/dev/null | extract_version || echo "unknown")
        log_info "Found vcpkg version: $vcpkg_version"
        log_success "vcpkg check passed"
    else
        log_warn "vcpkg not found - will be downloaded during build"
    fi
}

check_git() {
    log_info "Checking Git..."
    
    if check_command_exists "git" "git"; then
        local git_version
        git_version=$(git --version | extract_version)
        log_info "Found Git version: $git_version"
        log_success "Git check passed"
    else
        error_exit "Git not found. Please install Git" 3
    fi
}

check_nasm() {
    log_info "Checking NASM..."
    
    if check_command_exists "nasm" "nasm"; then
        local nasm_version
        nasm_version=$(nasm -v | extract_version)
        log_info "Found NASM version: $nasm_version"
        
        if version_lt "$nasm_version" "2.16"; then
            log_warn "NASM version $nasm_version is older than recommended 2.16.x"
        else
            log_success "NASM check passed"
        fi
    else
        log_warn "NASM not found - required for some builds"
    fi
}

check_yasm() {
    log_info "Checking YASM..."
    
    if check_command_exists "yasm" "yasm"; then
        local yasm_version
        yasm_version=$(yasm --version | extract_version)
        log_info "Found YASM version: $yasm_version"
        log_success "YASM check passed"
    else
        log_warn "YASM not found - may be required for some builds"
    fi
}

# --------------------------
# Environment Check Functions
# --------------------------
check_env_variables() {
    log_info "Checking environment variables..."
    
    local missing_envs=()
    
    # Check optional but commonly used variables
    if [[ -z "${VCPKG_ROOT:-}" ]]; then
        log_warn "VCPKG_ROOT not set - using default location"
    else
        log_info "VCPKG_ROOT: $VCPKG_ROOT"
    fi
    
    if [[ -z "${LIBCLANG_PATH:-}" ]]; then
        log_warn "LIBCLANG_PATH not set - some builds may fail"
    else
        log_info "LIBCLANG_PATH: $LIBCLANG_PATH"
    fi
    
    log_success "Environment variables check completed"
}

check_network() {
    log_info "Checking network connectivity..."
    
    local test_hosts=("github.com" "crates.io" "pub.dev")
    local failed_hosts=()
    
    for host in "${test_hosts[@]}"; do
        if timeout 5 ping -c 1 "$host" &>/dev/null; then
            log_debug "Network OK: $host"
        else
            failed_hosts+=("$host")
        fi
    done
    
    if [[ ${#failed_hosts[@]} -gt 0 ]]; then
        log_warn "Network access issues detected for: ${failed_hosts[*]}"
    else
        log_success "Network connectivity check passed"
    fi
}

# --------------------------
# Main Function
# --------------------------
main() {
    local exit_code=0
    
    log_info "Starting build dependency check..."
    echo "-----------------------------------------------------"
    
    # Check required tools
    check_git || exit_code=3
    check_rust_version || exit_code=4
    check_cargo_version || exit_code=3
    
    # Check optional tools
    check_flutter_version
    check_llvm_version
    check_vcpkg
    check_nasm
    check_yasm
    
    # Check environment
    check_env_variables
    check_network
    
    echo "-----------------------------------------------------"
    
    if [[ $exit_code -eq 0 ]]; then
        log_success "All dependency checks completed successfully"
    else
        log_error "Some dependency checks failed"
    fi
    
    exit "$exit_code"
}

# --------------------------
# Argument Handling
# --------------------------
while getopts "hv" opt; do
    case $opt in
        h)
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  -h  Show this help message"
            echo "  -v  Enable verbose output"
            exit 0
            ;;
        v)
            VERBOSE=1
            ;;
        \?)
            error_exit "Invalid option: -$OPTARG" 2
            ;;
    esac
done

# --------------------------
# Run Main
# --------------------------
main "$@"