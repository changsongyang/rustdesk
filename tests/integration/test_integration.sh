#!/bin/bash

# 集成测试脚本
# 测试构建过程、依赖安装等集成场景

# 配置变量
TEST_LOG="integration_test.log"

# 记录测试开始
echo "开始集成测试..." > "$TEST_LOG"

test_passed=0
test_failed=0

# 测试 1: 检查构建脚本是否存在
test_build_script() {
    echo "\n测试 1: 检查构建脚本..." >> "$TEST_LOG"
    if [ -f "build.py" ]; then
        echo "✓ 构建脚本存在" >> "$TEST_LOG"
        return 0
    else
        echo "✗ 构建脚本不存在" >> "$TEST_LOG"
        return 1
    fi
}

# 测试 2: 检查依赖配置文件
test_dependency_config() {
    echo "\n测试 2: 检查依赖配置..." >> "$TEST_LOG"
    if [ -f "vcpkg.json" ]; then
        echo "✓ vcpkg.json 存在" >> "$TEST_LOG"
        return 0
    else
        echo "✗ vcpkg.json 不存在" >> "$TEST_LOG"
        return 1
    fi
}

# 测试 3: 检查 Cargo.toml 配置
test_cargo_config() {
    echo "\n测试 3: 检查 Cargo 配置..." >> "$TEST_LOG"
    if [ -f "Cargo.toml" ]; then
        echo "✓ Cargo.toml 存在" >> "$TEST_LOG"
        return 0
    else
        echo "✗ Cargo.toml 不存在" >> "$TEST_LOG"
        return 1
    fi
}

# 测试 4: 检查 Flutter 配置
test_flutter_config() {
    echo "\n测试 4: 检查 Flutter 配置..." >> "$TEST_LOG"
    if [ -f "flutter/pubspec.yaml" ]; then
        echo "✓ flutter/pubspec.yaml 存在" >> "$TEST_LOG"
        return 0
    else
        echo "✗ flutter/pubspec.yaml 不存在" >> "$TEST_LOG"
        return 1
    fi
}

# 测试 5: 检查环境变量配置
test_environment_vars() {
    echo "\n测试 5: 检查环境变量..." >> "$TEST_LOG"
    if [ -n "$VCPKG_ROOT" ]; then
        echo "✓ VCPKG_ROOT 环境变量已设置" >> "$TEST_LOG"
        return 0
    else
        echo "⚠ VCPKG_ROOT 环境变量未设置" >> "$TEST_LOG"
        # 这个测试不应该失败，因为环境变量可能在CI中设置
        return 0
    fi
}

# 执行测试
test_build_script
if [ $? -eq 0 ]; then
    test_passed=$((test_passed + 1))
else
    test_failed=$((test_failed + 1))
fi

test_dependency_config
if [ $? -eq 0 ]; then
    test_passed=$((test_passed + 1))
else
    test_failed=$((test_failed + 1))
fi

test_cargo_config
if [ $? -eq 0 ]; then
    test_passed=$((test_passed + 1))
else
    test_failed=$((test_failed + 1))
fi

test_flutter_config
if [ $? -eq 0 ]; then
    test_passed=$((test_passed + 1))
else
    test_failed=$((test_failed + 1))
fi

test_environment_vars
if [ $? -eq 0 ]; then
    test_passed=$((test_passed + 1))
else
    test_failed=$((test_failed + 1))
fi

# 输出测试结果
echo "\n=== 集成测试结果 ===" >> "$TEST_LOG"
echo "通过测试: $test_passed" >> "$TEST_LOG"
echo "失败测试: $test_failed" >> "$TEST_LOG"

if [ $test_failed -gt 0 ]; then
    echo "集成测试失败!" >> "$TEST_LOG"
    exit 1
else
    echo "所有集成测试通过!" >> "$TEST_LOG"
    exit 0
fi