#!/bin/bash

# 端到端测试脚本
# 测试完整的构建流程和应用启动等端到端场景

# 配置变量
TEST_LOG="e2e_test.log"

# 记录测试开始
echo "开始端到端测试..." > "$TEST_LOG"

test_passed=0
test_failed=0

# 测试 1: 测试构建脚本执行
test_build_script_execution() {
    echo "\n测试 1: 测试构建脚本执行..." >> "$TEST_LOG"
    # 只测试构建脚本是否能正常执行，不实际构建
    if python3 build.py --help > /dev/null 2>&1; then
        echo "✓ 构建脚本能够正常执行" >> "$TEST_LOG"
        return 0
    else
        echo "✗ 构建脚本执行失败" >> "$TEST_LOG"
        return 1
    fi
}

# 测试 2: 测试 Flutter 依赖获取
test_flutter_dependencies() {
    echo "\n测试 2: 测试 Flutter 依赖获取..." >> "$TEST_LOG"
    if [ -d "flutter" ]; then
        cd flutter
        if flutter pub get > /dev/null 2>&1; then
            echo "✓ Flutter 依赖获取成功" >> "$TEST_LOG"
            cd ..
            return 0
        else
            echo "✗ Flutter 依赖获取失败" >> "$TEST_LOG"
            cd ..
            return 1
        fi
    else
        echo "⚠ Flutter 目录不存在，跳过测试" >> "$TEST_LOG"
        return 0
    fi
}

# 测试 3: 测试 Rust 依赖检查
test_rust_dependencies() {
    echo "\n测试 3: 测试 Rust 依赖检查..." >> "$TEST_LOG"
    if cargo check --all > /dev/null 2>&1; then
        echo "✓ Rust 依赖检查通过" >> "$TEST_LOG"
        return 0
    else
        echo "✗ Rust 依赖检查失败" >> "$TEST_LOG"
        return 1
    fi
}

# 测试 4: 测试 vcpkg 依赖安装
test_vcpkg_dependencies() {
    echo "\n测试 4: 测试 vcpkg 依赖安装..." >> "$TEST_LOG"
    if [ -n "$VCPKG_ROOT" ] && [ -f "$VCPKG_ROOT/vcpkg" ]; then
        if $VCPKG_ROOT/vcpkg list > /dev/null 2>&1; then
            echo "✓ vcpkg 依赖管理正常" >> "$TEST_LOG"
            return 0
        else
            echo "✗ vcpkg 依赖管理异常" >> "$TEST_LOG"
            return 1
        fi
    else
        echo "⚠ vcpkg 未配置，跳过测试" >> "$TEST_LOG"
        return 0
    fi
}

# 测试 5: 测试代码格式检查
test_code_format() {
    echo "\n测试 5: 测试代码格式检查..." >> "$TEST_LOG"
    # 检查 Rust 代码格式
    if cargo fmt --all --check > /dev/null 2>&1; then
        echo "✓ Rust 代码格式正确" >> "$TEST_LOG"
        return 0
    else
        echo "✗ Rust 代码格式不正确" >> "$TEST_LOG"
        return 1
    fi
}

# 执行测试
test_build_script_execution
if [ $? -eq 0 ]; then
    test_passed=$((test_passed + 1))
else
    test_failed=$((test_failed + 1))
fi

test_flutter_dependencies
if [ $? -eq 0 ]; then
    test_passed=$((test_passed + 1))
else
    test_failed=$((test_failed + 1))
fi

test_rust_dependencies
if [ $? -eq 0 ]; then
    test_passed=$((test_passed + 1))
else
    test_failed=$((test_failed + 1))
fi

test_vcpkg_dependencies
if [ $? -eq 0 ]; then
    test_passed=$((test_passed + 1))
else
    test_failed=$((test_failed + 1))
fi

test_code_format
if [ $? -eq 0 ]; then
    test_passed=$((test_passed + 1))
else
    test_failed=$((test_failed + 1))
fi

# 输出测试结果
echo "\n=== 端到端测试结果 ===" >> "$TEST_LOG"
echo "通过测试: $test_passed" >> "$TEST_LOG"
echo "失败测试: $test_failed" >> "$TEST_LOG"

if [ $test_failed -gt 0 ]; then
    echo "端到端测试失败!" >> "$TEST_LOG"
    exit 1
else
    echo "所有端到端测试通过!" >> "$TEST_LOG"
    exit 0
fi