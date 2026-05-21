#!/bin/bash

# RustDesk 构建错误根因分析与解决方案建议脚本
# 基于常见错误模式提供智能诊断和修复建议

set -e

echo "=========================================="
echo "RustDesk 构建错误根因分析"
echo "=========================================="
echo ""

# 接收日志文件作为参数
LOG_FILE="$1"

if [ -z "$LOG_FILE" ]; then
    echo "❌ 未指定日志文件"
    echo "用法: $0 <日志文件>"
    exit 1
fi

if [ ! -f "$LOG_FILE" ]; then
    echo "❌ 日志文件不存在: $LOG_FILE"
    exit 1
fi

echo "📄 分析日志文件: $LOG_FILE"
echo ""

# 创建临时文件
TEMP_LOG=$(mktemp)
grep -E "(error|Error|ERROR|failed|Failed|FAILED)" "$LOG_FILE" > "$TEMP_LOG"

# 定义错误模式和建议解决方案
declare -A ERROR_PATTERNS
declare -A ERROR_SOLUTIONS

# FFmpeg 相关错误
ERROR_PATTERNS["swresample"]="FFmpeg swresample 库链接错误"
ERROR_SOLUTIONS["swresample"]="1. 检查 FFmpeg 是否正确安装
2. 确保 vcpkg 中 FFmpeg 已正确配置
3. 添加 swresample 到库链接配置"

ERROR_PATTERNS["libmfx"]="Intel Media SDK (libmfx) 链接错误"
ERROR_SOLUTIONS["libmfx"]="1. 安装 Intel Media SDK
2. 通过 vcpkg 安装: vcpkg install mfx-dispatch:x64-windows-static
3. 或者在 build.rs 中移除 libmfx 链接"

ERROR_PATTERNS["vdpau"]="VDPAU 库链接错误"
ERROR_SOLUTIONS["vdpau"]="1. VDPAU 是可选的硬件加速功能
2. 从 build.rs 中移除 vdpau 链接
3. 或安装 libvdpau-dev 包"

ERROR_PATTERNS["AVFrame.key_frame"]="FFmpeg API 兼容性问题"
ERROR_SOLUTIONS["AVFrame.key_frame"]="1. FFmpeg 7.x 移除了 key_frame 字段
2. 使用条件编译: #if LIBAVUTIL_VERSION_MAJOR >= 7
3. 改用: frame->flags & AV_FRAME_FLAG_KEY"

ERROR_PATTERNS["FF_PROFILE_"]="FFmpeg 配置文件常量变更"
ERROR_SOLUTIONS["FF_PROFILE_"]="1. FFmpeg 6.2+ 重命名了常量
2. 将 FF_PROFILE_* 改为 AV_PROFILE_*
3. 示例: FF_PROFILE_H264_HIGH -> AV_PROFILE_H264_HIGH"

# Rust 编译错误
ERROR_PATTERNS["cannot borrow"]="Rust 借用错误"
ERROR_SOLUTIONS["cannot borrow"]="1. 变量需要可变访问但未声明 mut
2. 示例: let map -> let mut map
3. 或: event_loop -> mut event_loop"

ERROR_PATTERNS["E0596"]="Rust 可变借用错误 (E0596)"
ERROR_SOLUTIONS["E0596"]="1. 在变量声明前添加 mut 关键字
2. 例如: let mut map = ...
3. 或者使用不可变方法"

ERROR_PATTERNS["unwrap()"]="Rust unwrap/expect 使用"
ERROR_SOLUTIONS["unwrap()"]="1. 避免在生产代码中使用 unwrap()
2. 使用 ? 操作符或 match 处理 Result
3. 或者使用 unwrap_or() 提供默认值"

# 链接错误
ERROR_PATTERNS["could not find native static library"]="找不到原生静态库"
ERROR_SOLUTIONS["could not find native static library"]="1. 检查库是否已安装
2. 检查库路径是否在 LD_LIBRARY_PATH 中
3. 使用 pkg-config 或 cmake 查找库"

ERROR_PATTERNS["undefined reference"]="未定义的符号引用"
ERROR_SOLUTIONS["undefined reference"]="1. 缺少库链接
2. 检查库链接顺序
3. 确保所有依赖库都已链接"

ERROR_PATTERNS["ld returned 1 exit status"]="链接器返回错误"
ERROR_SOLUTIONS["ld returned 1 exit status"]="1. 查找具体的 undefined reference
2. 添加缺失的库
3. 检查库版本兼容性"

# 依赖错误
ERROR_PATTERNS["could not find"]="找不到依赖"
ERROR_SOLUTIONS["could not find"]="1. 运行 cargo update 更新依赖
2. 检查 Cargo.toml 配置
3. 清理并重新构建: cargo clean && cargo build"

ERROR_PATTERNS["failed to run custom build command"]="自定义构建命令失败"
ERROR_SOLUTIONS["failed to run custom build command"]="1. 检查 build.rs 脚本
2. 查看具体的构建错误
3. 确保所有构建依赖已安装"

# 网络错误
ERROR_PATTERNS["timeout"]="网络超时"
ERROR_SOLUTIONS["timeout"]="1. 检查网络连接
2. 增加超时时间
3. 使用代理或镜像源"

ERROR_PATTERNS["connection refused"]="连接被拒绝"
ERROR_SOLUTIONS["connection refused"]="1. 检查服务是否运行
2. 检查防火墙配置
3. 验证网络设置"

# 工具链错误
ERROR_PATTERNS["nasm"]="NASM 汇编器问题"
ERROR_SOLUTIONS["nasm"]="1. 安装 NASM: sudo apt-get install nasm
2. 检查 NASM 版本
3. 设置 PATH 环境变量"

ERROR_PATTERNS["NASM"]="NASM 版本或安装问题"
ERROR_SOLUTIONS["NASM"]="1. 下载并安装正确版本的 NASM
2. 从 https://www.nasm.us 获取
3. 确保 nasm 在系统 PATH 中"

# 分析日志并匹配错误模式
echo "🔍 开始分析错误..."
echo ""

FOUND_PATTERNS=0

for pattern in "${!ERROR_PATTERNS[@]}"; do
    if grep -q "$pattern" "$TEMP_LOG"; then
        FOUND_PATTERNS=$((FOUND_PATTERNS + 1))
        echo "=========================================="
        echo "🔴 错误 #$FOUND_PATTERNS: ${ERROR_PATTERNS[$pattern]}"
        echo "=========================================="
        echo "模式: $pattern"
        echo ""
        echo "🔧 解决方案:"
        echo "${ERROR_SOLUTIONS[$pattern]}"
        echo ""
        echo "相关日志:"
        grep -B 2 -A 2 "$pattern" "$TEMP_LOG" | head -10
        echo ""
    fi
done

# 如果没有找到已知模式
if [ $FOUND_PATTERNS -eq 0 ]; then
    echo "⚠️  未识别到已知错误模式"
    echo ""
    echo "请手动检查以下常见问题:"
    echo "1. 依赖是否正确安装"
    echo "2. 环境变量是否正确配置"
    echo "3. 工具链版本是否兼容"
    echo ""
    echo "建议运行完整的依赖检查:"
    echo "  ./scripts/check-dependencies.sh"
fi

# 生成总结报告
echo ""
echo "=========================================="
echo "分析总结"
echo "=========================================="
echo "识别的错误类型: $FOUND_PATTERNS"
echo ""

if [ $FOUND_PATTERNS -gt 0 ]; then
    echo "✅ 建议按以下顺序修复:"
    echo ""
    echo "1. 首先修复编译错误（语法、类型等）"
    echo "2. 然后修复依赖错误（库缺失、版本不匹配）"
    echo "3. 最后修复链接错误（库链接、符号引用）"
    echo ""
    echo "修复后请重新运行构建验证:"
    echo "  gh workflow run 'Flutter Nightly' --repo changsongyang/rustdesk --ref 1.5.3"
fi

# 清理
rm -f "$TEMP_LOG"

echo ""
echo "✅ 分析完成"
exit 0
