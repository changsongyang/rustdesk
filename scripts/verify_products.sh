#!/bin/bash
set -e

# 构建产物验证脚本
# 用于 CI 环境中验证构建产物是否符合要求

ERROR_COUNT=0
WARNING_COUNT=0
PRODUCTS=()

echo "========================================"
echo "    构建产物验证脚本"
echo "========================================"
echo ""

# 添加要验证的产物
add_product() {
    local path="$1"
    local description="${2:-}"
    PRODUCTS+=("$path|$description")
}

# 验证单个产物
verify_product() {
    local path="$1"
    local description="$2"
    
    echo "🔍 验证: $path"
    
    if [ -f "$path" ]; then
        local size=$(stat -f%z "$path" 2>/dev/null || stat -c%s "$path" 2>/dev/null || echo "0")
        local human_size=$(numfmt --to=iec --suffix=B "$size" 2>/dev/null || echo "$size bytes")
        
        if [ "$size" -eq 0 ]; then
            echo "   ⚠️  警告: 产物为空 ($description)"
            WARNING_COUNT=$((WARNING_COUNT + 1))
        else
            echo "   ✅ 验证通过 - 大小: $human_size ($description)"
        fi
        
        # 计算哈希
        local hash=$(sha256sum "$path" 2>/dev/null | awk '{print $1}' || md5sum "$path" 2>/dev/null | awk '{print $1}')
        if [ -n "$hash" ]; then
            echo "   哈希: ${hash:0:16}..."
        fi
        
        return 0
    else
        echo "   ❌ 错误: 产物不存在 ($description)"
        ERROR_COUNT=$((ERROR_COUNT + 1))
        return 1
    fi
}

# 验证目录
verify_directory() {
    local path="$1"
    local description="${2:-}"
    
    echo "🔍 验证目录: $path"
    
    if [ -d "$path" ]; then
        local file_count=$(find "$path" -type f 2>/dev/null | wc -l)
        echo "   ✅ 目录存在 - 文件数: $file_count ($description)"
        return 0
    else
        echo "   ❌ 错误: 目录不存在 ($description)"
        ERROR_COUNT=$((ERROR_COUNT + 1))
        return 1
    fi
}

# 验证符号链接
verify_symlink() {
    local path="$1"
    local description="${2:-}"
    
    echo "🔍 验证符号链接: $path"
    
    if [ -L "$path" ]; then
        local target=$(readlink "$path")
        echo "   ✅ 符号链接存在 - 指向: $target ($description)"
        
        if [ -e "$path" ]; then
            echo "   🔗 目标文件存在"
        else
            echo "   ⚠️  警告: 目标文件不存在"
            WARNING_COUNT=$((WARNING_COUNT + 1))
        fi
        return 0
    else
        echo "   ❌ 错误: 符号链接不存在 ($description)"
        ERROR_COUNT=$((ERROR_COUNT + 1))
        return 1
    fi
}

# 主验证逻辑
main() {
    # 根据目标平台验证不同的产物
    TARGET="${1:-unknown}"
    echo "目标平台: $TARGET"
    echo ""
    
    case "$TARGET" in
        x86_64-pc-windows-msvc)
            # Windows 产物
            add_product "target/x86_64-pc-windows-msvc/release/rustdesk.exe" "主程序"
            add_product "target/x86_64-pc-windows-msvc/release/rustdesk.pdb" "调试符号"
            ;;
        
        aarch64-apple-ios)
            # iOS 产物
            add_product "target/aarch64-apple-ios/release/liblibrustdesk.a" "静态库"
            verify_directory "flutter/build/ios/ipa" "IPA 目录"
            ;;
        
        x86_64-apple-darwin|aarch64-apple-darwin)
            # macOS 产物
            add_product "target/$TARGET/release/librustdesk.dylib" "动态库"
            verify_directory "flutter/build/macos/Build/Products/Release" "应用程序目录"
            ;;
        
        aarch64-linux-android|armv7-linux-androideabi|x86_64-linux-android|i686-linux-android)
            # Android 产物
            add_product "target/$TARGET/release/liblibrustdesk.so" "共享库"
            verify_directory "flutter/build/app/outputs/flutter-apk" "APK 目录"
            ;;
        
        x86_64-unknown-linux-gnu|aarch64-unknown-linux-gnu)
            # Linux 产物
            add_product "target/$TARGET/release/librustdesk.so" "共享库"
            add_product "target/$TARGET/release/rustdesk" "主程序"
            ;;
        
        *)
            echo "⚠️  未知目标平台: $TARGET"
            WARNING_COUNT=$((WARNING_COUNT + 1))
            ;;
    esac
    
    # 验证所有产物
    echo "========================================"
    echo "              开始验证"
    echo "========================================"
    echo ""
    
    for product in "${PRODUCTS[@]}"; do
        IFS="|" read -r path description <<< "$product"
        verify_product "$path" "$description"
    done
    
    # 输出结果
    echo ""
    echo "========================================"
    echo "              验证结果"
    echo "========================================"
    
    if [ "$ERROR_COUNT" -eq 0 ] && [ "$WARNING_COUNT" -eq 0 ]; then
        echo "✅ 所有验证通过！"
        echo ""
        echo "📊 统计: ${#PRODUCTS[@]} 个产物已验证"
        exit 0
    elif [ "$ERROR_COUNT" -eq 0 ] && [ "$WARNING_COUNT" -gt 0 ]; then
        echo "⚠️  验证完成，但有 $WARNING_COUNT 个警告"
        echo ""
        echo "📊 统计: ${#PRODUCTS[@]} 个产物已验证"
        exit 0
    else
        echo "❌ 验证失败，发现 $ERROR_COUNT 个错误"
        echo ""
        echo "📊 统计: ${#PRODUCTS[@]} 个产物已验证"
        exit 1
    fi
}

# 执行主函数
main "$@"