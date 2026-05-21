#!/bin/bash

# RustDesk 构建错误日志提取与分析脚本
# 用于从 CI 构建日志中提取和分类错误

set -e

# 默认参数
LOG_FILE=""
OUTPUT_FILE=""

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        --log)
            LOG_FILE="$2"
            shift 2
            ;;
        --output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        *)
            echo "未知参数: $1"
            exit 1
            ;;
    esac
done

echo "=========================================="
echo "RustDesk 构建错误日志提取与分析"
echo "=========================================="
echo ""

# 检查日志文件
if [ -z "$LOG_FILE" ]; then
    echo "❌ 未指定日志文件"
    echo "用法: $0 --log <日志文件> [--output <输出文件>]"
    exit 1
fi

if [ ! -f "$LOG_FILE" ]; then
    echo "❌ 日志文件不存在: $LOG_FILE"
    exit 1
fi

echo "📄 分析日志文件: $LOG_FILE"
echo ""

# 初始化错误统计
declare -A ERROR_TYPES
ERROR_TYPES[compilation]="编译错误"
ERROR_TYPES[linking]="链接错误"
ERROR_TYPES[dependency]="依赖错误"
ERROR_TYPES[configuration]="配置错误"
ERROR_TYPES[permission]="权限错误"
ERROR_TYPES[network]="网络错误"
ERROR_TYPES[unknown]="未知错误"

declare -A ERROR_COUNTS
for key in "${!ERROR_TYPES[@]}"; do
    ERROR_COUNTS[$key]=0
done

# 创建临时文件
TEMP_ERRORS=$(mktemp)

# 提取错误行
echo "🔍 提取错误信息..."
grep -E "(error|Error|ERROR|failed|Failed|FAILED)" "$LOG_FILE" > "$TEMP_ERRORS"

# 统计错误数量
TOTAL_ERRORS=$(wc -l < "$TEMP_ERRORS")
echo "📊 发现 $TOTAL_ERRORS 个错误/警告"
echo ""

# 分类错误
echo "📋 错误分类:"

# 编译错误
COMPILATION_ERRORS=$(grep -c -E "(error\[E[0-9]+\]|compilation terminated|build failed)" "$TEMP_ERRORS" || echo "0")
ERROR_COUNTS[compilation]=$COMPILATION_ERRORS
if [ "$COMPILATION_ERRORS" -gt 0 ]; then
    echo "  编译错误: $COMPILATION_ERRORS"
fi

# 链接错误
LINKING_ERRORS=$(grep -c -E "(linker|linking|undefined reference|ld returned| cannot find -l)" "$TEMP_ERRORS" || echo "0")
ERROR_COUNTS[linking]=$LINKING_ERRORS
if [ "$LINKING_ERRORS" -gt 0 ]; then
    echo "  链接错误: $LINKING_ERRORS"
fi

# 依赖错误
DEPENDENCY_ERRORS=$(grep -c -E "(could not find|could not compile|failed to fetch|dependency)" "$TEMP_ERRORS" || echo "0")
ERROR_COUNTS[dependency]=$DEPENDENCY_ERRORS
if [ "$DEPENDENCY_ERRORS" -gt 0 ]; then
    echo "  依赖错误: $DEPENDENCY_ERRORS"
fi

# 配置错误
CONFIG_ERRORS=$(grep -c -E "(invalid|no such file|permission denied|config)" "$TEMP_ERRORS" || echo "0")
ERROR_COUNTS[configuration]=$CONFIG_ERRORS
if [ "$CONFIG_ERRORS" -gt 0 ]; then
    echo "  配置错误: $CONFIG_ERRORS"
fi

# 网络错误
NETWORK_ERRORS=$(grep -c -E "(network|timeout|connection|download)" "$TEMP_ERRORS" || echo "0")
ERROR_COUNTS[network]=$NETWORK_ERRORS
if [ "$NETWORK_ERRORS" -gt 0 ]; then
    echo "  网络错误: $NETWORK_ERRORS"
fi

# 生成详细报告
echo ""
echo "=========================================="
echo "详细错误报告"
echo "=========================================="

# 提取关键错误信息
echo ""
echo "### 编译错误详情"
grep -E "error\[E[0-9]+\]" "$TEMP_ERRORS" | head -20 || echo "无编译错误"

echo ""
echo "### 链接错误详情"
grep -E "(undefined reference| cannot find -l|linker)" "$TEMP_ERRORS" | head -20 || echo "无链接错误"

echo ""
echo "### 依赖错误详情"
grep -E "(could not find|could not compile)" "$TEMP_ERRORS" | head -20 || echo "无依赖错误"

# 生成建议
echo ""
echo "=========================================="
echo "修复建议"
echo "=========================================="

# 根据错误类型提供建议
if [ "$COMPILATION_ERRORS" -gt 0 ]; then
    echo ""
    echo "🔧 编译错误修复建议:"
    echo "  1. 检查代码语法错误"
    echo "  2. 确保所有依赖正确导入"
    echo "  3. 检查 Rust 版本兼容性"
fi

if [ "$LINKING_ERRORS" -gt 0 ]; then
    echo ""
    echo "🔧 链接错误修复建议:"
    echo "  1. 检查库文件路径配置"
    echo "  2. 确保所有系统库已安装"
    echo "  3. 检查 vcpkg 配置"
fi

if [ "$DEPENDENCY_ERRORS" -gt 0 ]; then
    echo ""
    echo "🔧 依赖错误修复建议:"
    echo "  1. 运行 'cargo update' 更新依赖"
    echo "  2. 检查 Cargo.lock 是否最新"
    echo "  3. 清理缓存: 'cargo clean'"
fi

# 保存报告
if [ -n "$OUTPUT_FILE" ]; then
    {
        echo "=========================================="
        echo "RustDesk 构建错误分析报告"
        echo "生成时间: $(date)"
        echo "=========================================="
        echo ""
        echo "日志文件: $LOG_FILE"
        echo "总错误数: $TOTAL_ERRORS"
        echo ""
        echo "错误分类统计:"
        for key in "${!ERROR_TYPES[@]}"; do
            count=${ERROR_COUNTS[$key]}
            if [ "$count" -gt 0 ]; then
                echo "  ${ERROR_TYPES[$key]}: $count"
            fi
        done
        echo ""
        echo "详细错误:"
        cat "$TEMP_ERRORS"
    } > "$OUTPUT_FILE"
    echo ""
    echo "📄 报告已保存到: $OUTPUT_FILE"
fi

# 清理
rm -f "$TEMP_ERRORS"

echo ""
echo "✅ 分析完成"
exit 0
