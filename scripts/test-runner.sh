#!/bin/bash

# 自动化测试运行器
# 用于运行单元测试、集成测试和端到端测试

# 配置变量
TEST_DIR=".tests"
UNIT_TEST_DIR="tests/unit"
INTEGRATION_TEST_DIR="tests/integration"
E2E_TEST_DIR="tests/e2e"
TEST_LOG_FILE="$TEST_DIR/test.log"
TEST_REPORT_FILE="$TEST_DIR/test-report.json"

# 确保测试目录存在
mkdir -p "$TEST_DIR"
mkdir -p "$UNIT_TEST_DIR"
mkdir -p "$INTEGRATION_TEST_DIR"
mkdir -p "$E2E_TEST_DIR"

# 初始化测试报告文件
if [ ! -f "$TEST_REPORT_FILE" ]; then
    echo '{"tests": [], "total_tests": 0, "passed_tests": 0, "failed_tests": 0, "test_coverage": 0}' > "$TEST_REPORT_FILE"
fi

# 记录测试开始时间
test_start_time=$(date +%s)
test_date=$(date +"%Y-%m-%d %H:%M:%S")
test_run_id=$(date +"%Y%m%d%H%M%S")

# 执行测试
echo "[$test_date] 开始测试 (ID: $test_run_id)" >> "$TEST_LOG_FILE"

# 运行单元测试
run_unit_tests() {
    echo "\n=== 运行单元测试 ===" >> "$TEST_LOG_FILE"
    
    # 运行 Rust 单元测试
    if [ -f "Cargo.toml" ]; then
        echo "运行 Rust 单元测试..." >> "$TEST_LOG_FILE"
        CARGO_OUTPUT=$(cargo test --lib --all-targets 2>&1)
        CARGO_STATUS=$?
        
        if [ $CARGO_STATUS -eq 0 ]; then
            echo "Rust 单元测试通过" >> "$TEST_LOG_FILE"
        else
            echo "Rust 单元测试失败" >> "$TEST_LOG_FILE"
            echo "错误信息: $CARGO_OUTPUT" >> "$TEST_LOG_FILE"
        fi
    else
        echo "未找到 Cargo.toml，跳过 Rust 单元测试" >> "$TEST_LOG_FILE"
    fi
    
    # 运行 Flutter 单元测试
    if [ -d "flutter" ]; then
        echo "运行 Flutter 单元测试..." >> "$TEST_LOG_FILE"
        cd flutter
        FLUTTER_OUTPUT=$(flutter test 2>&1)
        FLUTTER_STATUS=$?
        cd ..
        
        if [ $FLUTTER_STATUS -eq 0 ]; then
            echo "Flutter 单元测试通过" >> "$TEST_LOG_FILE"
        else
            echo "Flutter 单元测试失败" >> "$TEST_LOG_FILE"
            echo "错误信息: $FLUTTER_OUTPUT" >> "$TEST_LOG_FILE"
        fi
    else
        echo "未找到 flutter 目录，跳过 Flutter 单元测试" >> "$TEST_LOG_FILE"
    fi
}

# 运行集成测试
run_integration_tests() {
    echo "\n=== 运行集成测试 ===" >> "$TEST_LOG_FILE"
    
    # 检查集成测试文件是否存在
    if [ -f "$INTEGRATION_TEST_DIR/test_integration.sh" ]; then
        echo "运行集成测试..." >> "$TEST_LOG_FILE"
        INTEGRATION_OUTPUT=$(bash "$INTEGRATION_TEST_DIR/test_integration.sh" 2>&1)
        INTEGRATION_STATUS=$?
        
        if [ $INTEGRATION_STATUS -eq 0 ]; then
            echo "集成测试通过" >> "$TEST_LOG_FILE"
        else
            echo "集成测试失败" >> "$TEST_LOG_FILE"
            echo "错误信息: $INTEGRATION_OUTPUT" >> "$TEST_LOG_FILE"
        fi
    else
        echo "未找到集成测试脚本，跳过集成测试" >> "$TEST_LOG_FILE"
    fi
}

# 运行端到端测试
run_e2e_tests() {
    echo "\n=== 运行端到端测试 ===" >> "$TEST_LOG_FILE"
    
    # 检查端到端测试文件是否存在
    if [ -f "$E2E_TEST_DIR/test_e2e.sh" ]; then
        echo "运行端到端测试..." >> "$TEST_LOG_FILE"
        E2E_OUTPUT=$(bash "$E2E_TEST_DIR/test_e2e.sh" 2>&1)
        E2E_STATUS=$?
        
        if [ $E2E_STATUS -eq 0 ]; then
            echo "端到端测试通过" >> "$TEST_LOG_FILE"
        else
            echo "端到端测试失败" >> "$TEST_LOG_FILE"
            echo "错误信息: $E2E_OUTPUT" >> "$TEST_LOG_FILE"
        fi
    else
        echo "未找到端到端测试脚本，跳过端到端测试" >> "$TEST_LOG_FILE"
    fi
}

# 执行测试
test_results=()

run_unit_tests
test_results+=("$CARGO_STATUS" "$FLUTTER_STATUS")

run_integration_tests
test_results+=("$INTEGRATION_STATUS")

run_e2e_tests
test_results+=("$E2E_STATUS")

# 记录测试结束时间
test_end_time=$(date +%s)
test_duration=$((test_end_time - test_start_time))

# 分析测试结果
passed_tests=0
failed_tests=0

for status in "${test_results[@]}"; do
    if [ -n "$status" ]; then
        if [ "$status" -eq 0 ]; then
            passed_tests=$((passed_tests + 1))
        else
            failed_tests=$((failed_tests + 1))
        fi
    fi
done

total_tests=$((passed_tests + failed_tests))

if [ $total_tests -gt 0 ]; then
    test_coverage=$(echo "scale=2; $passed_tests / $total_tests * 100" | bc)
else
    test_coverage=0
fi

# 更新测试报告
jq --arg test_run_id "$test_run_id" --arg test_duration "$test_duration" --arg passed_tests "$passed_tests" --arg failed_tests "$failed_tests" --arg total_tests "$total_tests" --arg test_coverage "$test_coverage" --arg test_date "$test_date" \
    ' 
    .tests += [{"test_run_id": $test_run_id, "duration": $test_duration, "passed": $passed_tests, "failed": $failed_tests, "total": $total_tests, "coverage": $test_coverage, "date": $test_date}],
    .total_tests += ($total_tests | tonumber),
    .passed_tests += ($passed_tests | tonumber),
    .failed_tests += ($failed_tests | tonumber),
    .test_coverage = ((.passed_tests * 100 / .total_tests) | tonumber)
    ' \
    "$TEST_REPORT_FILE" > "$TEST_REPORT_FILE.tmp" && mv "$TEST_REPORT_FILE.tmp" "$TEST_REPORT_FILE"

# 生成测试报告
echo "\n=== 测试报告 ==="  
echo "测试运行ID: $test_run_id"
echo "测试时间: ${test_duration}s"
echo "测试日期: $test_date"
echo "总测试数: $total_tests"
echo "通过测试: $passed_tests"
echo "失败测试: $failed_tests"
echo "测试覆盖率: ${test_coverage}%"

# 检查是否有测试失败
if [ $failed_tests -gt 0 ]; then
    echo "\n警告: 有 $failed_tests 个测试失败"  
    exit 1
else
    echo "\n所有测试通过!"  
    exit 0
fi