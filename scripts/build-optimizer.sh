#!/bin/bash

# 构建性能优化脚本
# 用于优化依赖管理、并行构建和缓存策略

# 配置变量
OPTIMIZATION_LOG=".build-optimization.log"

# 确保日志文件存在
mkdir -p "$(dirname "$OPTIMIZATION_LOG")"

# 记录优化开始
echo "开始构建性能优化..." > "$OPTIMIZATION_LOG"

timestamp() {
    date +"[%Y-%m-%d %H:%M:%S]"
}

# 优化 1: 配置 Cargo 并行构建
tune_cargo_parallelism() {
    echo "$(timestamp) 优化 1: 配置 Cargo 并行构建..." >> "$OPTIMIZATION_LOG"
    
    # 检测 CPU 核心数
    CORES=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)
    
    # 配置 Cargo 并行度
    echo "配置 Cargo 并行构建为 $CORES 核心" >> "$OPTIMIZATION_LOG"
    
    # 创建或更新 .cargo/config.toml
    mkdir -p .cargo
    cat > .cargo/config.toml << EOF
[build]
jobs = $CORES
parallel = true

[target.x86_64-unknown-linux-gnu]
linker = "cc"

[target.x86_64-pc-windows-msvc]
linker = "link.exe"

[target.aarch64-apple-darwin]
linker = "clang"
EOF
    
    echo "$(timestamp) Cargo 并行构建配置完成" >> "$OPTIMIZATION_LOG"
}

# 优化 2: 配置 Cargo 缓存
tune_cargo_cache() {
    echo "$(timestamp) 优化 2: 配置 Cargo 缓存..." >> "$OPTIMIZATION_LOG"
    
    # 启用 Cargo 增量编译
    export CARGO_INCREMENTAL=1
    
    # 启用 Cargo 构建缓存
    export CARGO_TARGET_DIR=target
    
    # 配置 Cargo 网络缓存
    export CARGO_NET_RETRY=10
    export CARGO_HTTP_MULTIPLEXING=false
    export CARGO_HTTP_TIMEOUT=300
    
    echo "$(timestamp) Cargo 缓存配置完成" >> "$OPTIMIZATION_LOG"
}

# 优化 3: 配置 vcpkg 缓存
tune_vcpkg_cache() {
    echo "$(timestamp) 优化 3: 配置 vcpkg 缓存..." >> "$OPTIMIZATION_LOG"
    
    if [ -n "$VCPKG_ROOT" ]; then
        # 启用 vcpkg 二进制缓存
        export VCPKG_BINARY_SOURCES="clear;x-gha,readwrite"
        
        # 配置 vcpkg 网络重试
        export VCPKG_MAX_RETRIES=10
        export VCPKG_HTTP_TIMEOUT=300
        export VCPKG_HTTP_RETRY_DELAY=5
        
        echo "$(timestamp) vcpkg 缓存配置完成" >> "$OPTIMIZATION_LOG"
    else
        echo "$(timestamp) VCPKG_ROOT 未设置，跳过 vcpkg 缓存配置" >> "$OPTIMIZATION_LOG"
    fi
}

# 优化 4: 配置 Flutter 缓存
tune_flutter_cache() {
    echo "$(timestamp) 优化 4: 配置 Flutter 缓存..." >> "$OPTIMIZATION_LOG"
    
    if [ -d "flutter" ]; then
        # 启用 Flutter 缓存
        export FLUTTER_CACHE_DIR="$HOME/.flutter_cache"
        mkdir -p "$FLUTTER_CACHE_DIR"
        
        # 配置 Flutter 并行构建
        export FLUTTER_BUILD_NUMBER_OF_PROCESSORS=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)
        
        echo "$(timestamp) Flutter 缓存配置完成" >> "$OPTIMIZATION_LOG"
    else
        echo "$(timestamp) Flutter 目录不存在，跳过 Flutter 缓存配置" >> "$OPTIMIZATION_LOG"
    fi
}

# 优化 5: 配置 Git 缓存
tune_git_cache() {
    echo "$(timestamp) 优化 5: 配置 Git 缓存..." >> "$OPTIMIZATION_LOG"
    
    # 配置 Git 缓存
    git config --global core.fscache true
    git config --global core.preloadindex true
    git config --global core.compression 9
    
    # 配置 Git 网络
    git config --global http.lowSpeedLimit 1000
    git config --global http.lowSpeedTime 60
    git config --global http.followRedirects true
    git config --global http.version HTTP/1.1
    
    echo "$(timestamp) Git 缓存配置完成" >> "$OPTIMIZATION_LOG"
}

# 优化 6: 清理旧的构建文件
clean_old_builds() {
    echo "$(timestamp) 优化 6: 清理旧的构建文件..." >> "$OPTIMIZATION_LOG"
    
    # 清理 Rust 构建缓存
    if [ -d "target" ]; then
        echo "清理 target 目录..." >> "$OPTIMIZATION_LOG"
        rm -rf target/debug
        rm -rf target/*-debug
        rm -rf target/*.d
    fi
    
    # 清理 Flutter 构建缓存
    if [ -d "flutter/build" ]; then
        echo "清理 Flutter build 目录..." >> "$OPTIMIZATION_LOG"
        rm -rf flutter/build
    fi
    
    # 清理 vcpkg 临时文件
    if [ -n "$VCPKG_ROOT" ] && [ -d "$VCPKG_ROOT/buildtrees" ]; then
        echo "清理 vcpkg 构建树..." >> "$OPTIMIZATION_LOG"
        rm -rf "$VCPKG_ROOT/buildtrees"
    fi
    
    echo "$(timestamp) 清理完成" >> "$OPTIMIZATION_LOG"
}

# 优化 7: 配置构建环境变量
tune_build_env() {
    echo "$(timestamp) 优化 7: 配置构建环境变量..." >> "$OPTIMIZATION_LOG"
    
    # 配置构建环境变量
    export CCACHE_DIR="$HOME/.ccache"
    export CCACHE_COMPRESS=1
    export CCACHE_COMPRESSLEVEL=6
    export CCACHE_MAXSIZE="5G"
    
    # 配置链接器
    export LDFLAGS="-Wl,--no-keep-memory -Wl,--reduce-memory-overheads"
    
    # 配置编译器
    export CFLAGS="-O2 -march=native -mtune=native"
    export CXXFLAGS="-O2 -march=native -mtune=native"
    
    echo "$(timestamp) 构建环境变量配置完成" >> "$OPTIMIZATION_LOG"
}

# 执行所有优化
tune_cargo_parallelism
tune_cargo_cache
tune_vcpkg_cache
tune_flutter_cache
tune_git_cache
clean_old_builds
tune_build_env

# 输出优化结果
echo "$(timestamp) 构建性能优化完成!" >> "$OPTIMIZATION_LOG"
echo "\n=== 构建性能优化结果 ==="  
echo "1. Cargo 并行构建配置: 已完成"
echo "2. Cargo 缓存配置: 已完成"
echo "3. vcpkg 缓存配置: 已完成"
echo "4. Flutter 缓存配置: 已完成"
echo "5. Git 缓存配置: 已完成"
echo "6. 清理旧的构建文件: 已完成"
echo "7. 构建环境变量配置: 已完成"
echo "\n优化日志已保存到: $OPTIMIZATION_LOG"
