#!/usr/bin/env bash
#
# Script Name: build.sh
# Description: Main build script for rustdesk project
# Version: 1.0.0
# Author: Build Team
# Usage: ./build.sh [options]

set -euo pipefail

# --------------------------
# Configuration
# --------------------------
readonly SCRIPT_NAME="build.sh"
readonly SCRIPT_DIR=$(realpath "$(dirname "${BASH_SOURCE[0]}")")
readonly PROJECT_ROOT=$(realpath "${SCRIPT_DIR}/../..")

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
    cleanup
    exit "${2:-1}"
}

# --------------------------
# Cleanup Functions
# --------------------------
cleanup() {
    if [[ -n "${BUILD_SNAPSHOT:-}" ]]; then
        log_info "Cleaning up build snapshot..."
        rm -rf "$BUILD_SNAPSHOT" 2>/dev/null || true
    fi
    
    if [[ "${SKIP_CLEANUP:-0}" -eq 0 ]]; then
        log_info "Cleaning up temporary files..."
        # Add cleanup steps here
    fi
}

# --------------------------
# Signal Handling
# --------------------------
trap 'cleanup; exit 1' INT TERM ERR

# --------------------------
# Build Functions
# --------------------------
check_dependencies() {
    log_info "Checking build dependencies..."
    
    if ! "$SCRIPT_DIR/check-deps.sh"; then
        error_exit "Dependency check failed" 3
    fi
    
    log_success "Dependency check passed"
}

setup_build_environment() {
    log_info "Setting up build environment..."
    
    # Create build directory
    mkdir -p "${BUILD_DIR:-${PROJECT_ROOT}/target}"
    
    # Create build snapshot
    BUILD_SNAPSHOT=$(mktemp -d -t rustdesk-build-XXXXXX)
    log_debug "Build snapshot created: $BUILD_SNAPSHOT"
    
    # Record initial state
    date > "$BUILD_SNAPSHOT/build_start.txt"
    
    log_success "Build environment setup completed"
}

build_rust_components() {
    log_info "Building Rust components..."
    
    local cargo_args=("build")
    
    if [[ "${RELEASE:-0}" -eq 1 ]]; then
        cargo_args+=("--release")
    fi
    
    if [[ -n "${TARGET:-}" ]]; then
        cargo_args+=("--target" "$TARGET")
    fi
    
    if ! cargo "${cargo_args[@]}" --manifest-path "${PROJECT_ROOT}/Cargo.toml"; then
        error_exit "Rust build failed" 1
    fi
    
    log_success "Rust components built successfully"
}

build_flutter_components() {
    log_info "Building Flutter components..."
    
    if ! command -v flutter &>/dev/null; then
        log_warn "Flutter not found - skipping Flutter build"
        return 0
    fi
    
    local flutter_args=("build")
    
    if [[ "${RELEASE:-0}" -eq 1 ]]; then
        flutter_args+=("--release")
    fi
    
    # Build for current platform
    case "$(uname | tr '[:upper:]' '[:lower:]')" in
        linux)
            flutter_args+=("linux")
            ;;
        darwin)
            flutter_args+=("macos")
            ;;
        msys|cygwin|mingw*)
            flutter_args+=("windows")
            ;;
        *)
            log_warn "Unknown platform - skipping Flutter build"
            return 0
            ;;
    esac
    
    if ! flutter "${flutter_args[@]}" --no-tree-shake-icons; then
        log_warn "Flutter build failed - continuing with other components"
        return 1
    fi
    
    log_success "Flutter components built successfully"
}

run_build_validation() {
    log_info "Running build validation..."
    
    if ! "$SCRIPT_DIR/validate-build.sh" "${BUILD_DIR:-${PROJECT_ROOT}/target}"; then
        log_warn "Build validation warnings detected"
    fi
    
    log_success "Build validation completed"
}

# --------------------------
# Main Function
# --------------------------
main() {
    log_info "Starting rustdesk build process..."
    echo "====================================================="
    echo "                   Build Configuration"
    echo "====================================================="
    echo "Project Root:     $PROJECT_ROOT"
    echo "Build Directory:  ${BUILD_DIR:-${PROJECT_ROOT}/target}"
    echo "Build Type:       ${RELEASE:-0}"
    echo "Target:           ${TARGET:-default}"
    echo "====================================================="
    
    # Step 1: Check dependencies
    check_dependencies
    
    # Step 2: Setup build environment
    setup_build_environment
    
    # Step 3: Build Rust components
    build_rust_components
    
    # Step 4: Build Flutter components
    build_flutter_components
    
    # Step 5: Run validation
    run_build_validation
    
    echo "====================================================="
    log_success "Build process completed successfully"
    
    # Cleanup
    cleanup
}

# --------------------------
# Usage Help
# --------------------------
show_usage() {
    echo "Usage: $SCRIPT_NAME [options]"
    echo ""
    echo "Main build script for rustdesk project"
    echo ""
    echo "Options:"
    echo "  -h, --help              Show this help message"
    echo "  -v, --verbose           Enable verbose output"
    echo "  -r, --release           Build in release mode"
    echo "  -t, --target <target>   Target platform (e.g., x86_64-unknown-linux-gnu)"
    echo "  -d, --build-dir <dir>   Build directory (default: ./target)"
    echo "  -s, --skip-cleanup      Skip cleanup after build"
    echo ""
    echo "Examples:"
    echo "  $SCRIPT_NAME"
    echo "  $SCRIPT_NAME -r"
    echo "  $SCRIPT_NAME -r -t x86_64-unknown-linux-gnu"
    echo "  $SCRIPT_NAME -v -d ./build"
}

# --------------------------
# Argument Handling
# --------------------------
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            show_usage
            exit 0
            ;;
        -v|--verbose)
            VERBOSE=1
            shift
            ;;
        -r|--release)
            RELEASE=1
            shift
            ;;
        -t|--target)
            TARGET="$2"
            shift 2
            ;;
        -d|--build-dir)
            BUILD_DIR="$2"
            shift 2
            ;;
        -s|--skip-cleanup)
            SKIP_CLEANUP=1
            shift
            ;;
        -*)
            error_exit "Invalid option: $1" 2
            ;;
        *)
            error_exit "Unknown argument: $1" 2
            ;;
    esac
done

# --------------------------
# Run Main
# --------------------------
main