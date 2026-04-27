#!/bin/bash

# 构建监控脚本
# 用于收集构建时间、成功率、错误信息等指标

# 配置变量
MONITOR_DIR=".build-monitor"
LOG_FILE="$MONITOR_DIR/build.log"
STATS_FILE="$MONITOR_DIR/build-stats.json"
ERRORS_FILE="$MONITOR_DIR/errors.json"

# 确保监控目录存在
mkdir -p "$MONITOR_DIR"

# 初始化统计文件
if [ ! -f "$STATS_FILE" ]; then
    echo '{"builds": [], "total_builds": 0, "successful_builds": 0, "failed_builds": 0, "avg_build_time": 0}' > "$STATS_FILE"
fi

if [ ! -f "$ERRORS_FILE" ]; then
    echo '{"errors": []}' > "$ERRORS_FILE"
fi

# 记录构建开始时间
start_time=$(date +%s)
build_date=$(date +"%Y-%m-%d %H:%M:%S")
build_id=$(date +"%Y%m%d%H%M%S")

# 执行构建命令
echo "[$build_date] 开始构建 (ID: $build_id)" >> "$LOG_FILE"

# 捕获构建输出和退出码
BUILD_OUTPUT=$(bash -c "$@" 2>&1)
BUILD_STATUS=$?

# 记录构建结束时间
end_time=$(date +%s)
build_time=$((end_time - start_time))

# 分析构建结果
if [ $BUILD_STATUS -eq 0 ]; then
    build_status="success"
    echo "[$build_date] 构建成功 (ID: $build_id, 耗时: ${build_time}s)" >> "$LOG_FILE"
else
    build_status="failure"
    echo "[$build_date] 构建失败 (ID: $build_id, 耗时: ${build_time}s)" >> "$LOG_FILE"
    echo "错误信息: $BUILD_OUTPUT" >> "$LOG_FILE"
    
    # 提取错误信息
    error_message=$(echo "$BUILD_OUTPUT" | tail -n 10)
    error_type=$(echo "$BUILD_OUTPUT" | grep -E "(error|failed|error:|error: failed)" | head -n 1 | cut -d: -f2- | trim)
    
    # 记录错误
    jq --arg build_id "$build_id" --arg error_type "$error_type" --arg error_message "$error_message" --arg build_date "$build_date" \
        '.errors += [{"build_id": $build_id, "error_type": $error_type, "error_message": $error_message, "date": $build_date}]' \
        "$ERRORS_FILE" > "$ERRORS_FILE.tmp" && mv "$ERRORS_FILE.tmp" "$ERRORS_FILE"
fi

# 更新统计信息
jq --arg build_id "$build_id" --arg build_status "$build_status" --arg build_time "$build_time" --arg build_date "$build_date" \
    ' 
    .builds += [{"build_id": $build_id, "status": $build_status, "time": $build_time, "date": $build_date}],
    .total_builds += 1,
    if $build_status == "success" then .successful_builds += 1 else .failed_builds += 1 end,
    .avg_build_time = (.builds | map(.time | tonumber) | add) / .total_builds
    ' \
    "$STATS_FILE" > "$STATS_FILE.tmp" && mv "$STATS_FILE.tmp" "$STATS_FILE"

# 生成构建报告
echo "\n=== 构建报告 ==="  
echo "构建ID: $build_id"
echo "构建状态: $build_status"
echo "构建时间: ${build_time}s"
echo "构建日期: $build_date"
echo "\n=== 历史统计 ==="
jq -r '"总构建次数: \(.total_builds)\n成功构建: \(.successful_builds)\n失败构建: \(.failed_builds)\n平均构建时间: \(.avg_build_time | round)秒\n成功率: \((.successful_builds * 100 / .total_builds) | round)%"' "$STATS_FILE"
echo "\n=== 最近错误 ==="
jq -r '.errors[-5:] | reverse | .[] | "构建ID: \(.build_id)\n错误类型: \(.error_type)\n错误信息: \(.error_message)\n日期: \(.date)\n"' "$ERRORS_FILE"

# 返回构建状态
if [ $BUILD_STATUS -eq 0 ]; then
    exit 0
else
    exit $BUILD_STATUS
fi