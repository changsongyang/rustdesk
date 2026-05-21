#!/usr/bin/env bash
#
# Script Name: validate-build.sh
# Description: Validate build artifacts and verify build integrity
# Version: 1.0.0
# Author: Build Team
# Usage: ./validate-build.sh [options] <build_directory>

set -euo pipefail

# --------------------------
# Configuration
# --------------------------
readonly SCRIPT_NAME="validate-build.sh"
readonly BUILD_DIR_DEFAULT="./target"

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
# Validation Functions
# --------------------------
validate_build_dir() {
    local build_dir="$1"
    
    log_info "Validating build directory: $build_dir"
    
    if [[ ! -d "$build_dir" ]]; then
        error_exit "Build directory not found: $build_dir" 5
    fi
    
    if [[ ! -r "$build_dir" ]]; then
        error_exit "Build directory not readable: $build_dir" 7
    fi
    
    log_success "Build directory validation passed"
}

check_artifact_exists() {
    local artifact_path="$1"
    local artifact_name="$2"
    
    log_debug "Checking for $artifact_name: $artifact_path"
    
    if [[ -f "$artifact_path" ]]; then
        log_info "Found $artifact_name: $artifact_path"
        return 0
    else
        log_warn "$artifact_name not found: $artifact_path"
        return 1
    fi
}

check_executable() {
    local exec_path="$1"
    local exec_name="$2"
    
    log_info "Checking executable: $exec_name"
    
    if [[ ! -f "$exec_path" ]]; then
        log_warn "Executable not found: $exec_path"
        return 1
    fi
    
    if [[ ! -x "$exec_path" ]]; then
        log_warn "Executable not marked as executable: $exec_path"
        return 1
    fi
    
    log_success "$exec_name is executable"
    return 0
}

check_file_size() {
    local file_path="$1"
    local min_size_mb="$2"
    local file_name="$3"
    
    log_info "Checking $file_name size..."
    
    local file_size_bytes
    file_size_bytes=$(stat -f%z "$file_path" 2>/dev/null || stat -c%s "$file_path" 2>/dev/null || echo "0")
    
    local min_size_bytes=$((min_size_mb * 1024 * 1024))
    
    if [[ "$file_size_bytes" -lt "$min_size_bytes" ]]; then
        log_warn "$file_name is smaller than expected: $((file_size_bytes / 1024 / 1024)) MB < $min_size_mb MB"
        return 1
    fi
    
    log_info "$file_name size: $((file_size_bytes / 1024 / 1024)) MB"
    return 0
}

validate_rust_binaries() {
    local build_dir="$1"
    local target="$2"
    
    log_info "Validating Rust binaries for target: $target"
    
    local bin_dir="${build_dir}/${target}/release"
    
    if [[ ! -d "$bin_dir" ]]; then
        log_warn "Binary directory not found: $bin_dir"
        return 0
    fi
    
    local required_bins=("rustdesk" "libscrap")
    
    for bin_name in "${required_bins[@]}"; do
        local bin_path="${bin_dir}/${bin_name}"
        local bin_path_so="${bin_dir}/lib${bin_name}.so"
        local bin_path_dylib="${bin_dir}/lib${bin_name}.dylib"
        local bin_path_dll="${bin_dir}/${bin_name}.dll"
        
        if check_artifact_exists "$bin_path" "${bin_name} (executable)"; then
            check_executable "$bin_path" "$bin_name"
        elif check_artifact_exists "$bin_path_so" "${bin_name} (shared library)"; then
            check_file_size "$bin_path_so" 1 "$bin_name"
        elif check_artifact_exists "$bin_path_dylib" "${bin_name} (dylib)"; then
            check_file_size "$bin_path_dylib" 1 "$bin_name"
        elif check_artifact_exists "$bin_path_dll" "${bin_name} (DLL)"; then
            check_file_size "$bin_path_dll" 1 "$bin_name"
        else
            log_warn "No binary found for: $bin_name"
        fi
    done
    
    log_success "Rust binaries validation completed"
}

validate_flutter_artifacts() {
    local build_dir="$1"
    
    log_info "Validating Flutter artifacts..."
    
    local flutter_dirs=("flutter_app")
    
    for flutter_dir in "${flutter_dirs[@]}"; do
        local app_dir="${build_dir}/${flutter_dir}"
        if [[ -d "$app_dir" ]]; then
            log_info "Found Flutter app directory: $app_dir"
        else
            log_warn "Flutter app directory not found: $app_dir"
        fi
    done
    
    log_success "Flutter artifacts validation completed"
}

validate_packages() {
    local build_dir="$1"
    local target="$2"
    
    log_info "Validating packages for target: $target"
    
    local pkg_dir="${build_dir}/packages"
    
    if [[ -d "$pkg_dir" ]]; then
        log_info "Found packages directory: $pkg_dir"
    else
        log_warn "Packages directory not found: $pkg_dir"
    fi
    
    log_success "Packages validation completed"
}

generate_build_report() {
    local build_dir="$1"
    local report_file="${2:-build_validation_report.txt}"
    
    log_info "Generating build validation report..."
    
    {
        echo "====================================================="
        echo "          Build Validation Report"
        echo "====================================================="
        echo "Generated: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "Build Directory: $build_dir"
        echo ""
        echo "====================================================="
        echo "1. Directory Structure"
        echo "====================================================="
        find "$build_dir" -maxdepth 2 -type f -name "*.so" -o -name "*.dll" -o -name "*.dylib" -o -name "rustdesk" | head -20
        echo ""
        echo "====================================================="
        echo "2. File Sizes"
        echo "====================================================="
        find "$build_dir" -type f \( -name "*.so" -o -name "*.dll" -o -name "*.dylib" -o -name "rustdesk" \) -exec ls -lh {} \; 2>/dev/null | head -20
        echo ""
        echo "====================================================="
        echo "3. Build Artifacts Summary"
        echo "====================================================="
        echo "Total files: $(find "$build_dir" -type f | wc -l)"
        echo "Total size: $(du -sh "$build_dir" 2>/dev/null | awk '{print $1}')"
        echo ""
        echo "====================================================="
    } > "$report_file"
    
    log_info "Build validation report generated: $report_file"
}

# --------------------------
# Main Function
# --------------------------
main() {
    local build_dir="${1:-$BUILD_DIR_DEFAULT}"
    local target="${2:-$(uname -m)-$(uname | tr '[:upper:]' '[:lower:]')}"
    
    log_info "Starting build validation..."
    echo "-----------------------------------------------------"
    
    # Validate build directory
    validate_build_dir "$build_dir"
    
    # Validate Rust binaries
    validate_rust_binaries "$build_dir" "$target"
    
    # Validate Flutter artifacts
    validate_flutter_artifacts "$build_dir"
    
    # Validate packages
    validate_packages "$build_dir" "$target"
    
    # Generate report
    generate_build_report "$build_dir"
    
    echo "-----------------------------------------------------"
    log_success "Build validation completed successfully"
}

# --------------------------
# Usage Help
# --------------------------
show_usage() {
    echo "Usage: $SCRIPT_NAME [options] [build_directory]"
    echo ""
    echo "Validate build artifacts and verify build integrity"
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  -v, --verbose  Enable verbose output"
    echo "  -t, --target   Target platform (default: auto-detect)"
    echo ""
    echo "Arguments:"
    echo "  build_directory   Directory containing build artifacts (default: $BUILD_DIR_DEFAULT)"
    echo ""
    echo "Examples:"
    echo "  $SCRIPT_NAME"
    echo "  $SCRIPT_NAME ./target"
    echo "  $SCRIPT_NAME -v ./target/x86_64-unknown-linux-gnu"
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
        -t|--target)
            TARGET="$2"
            shift 2
            ;;
        -*)
            error_exit "Invalid option: $1" 2
            ;;
        *)
            BUILD_DIR="$1"
            shift
            ;;
    esac
done

# --------------------------
# Run Main
# --------------------------
main "${BUILD_DIR:-$BUILD_DIR_DEFAULT}" "${TARGET:-}"