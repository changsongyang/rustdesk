#!/usr/bin/env python3
"""
环境验证脚本 - 用于验证 RustDesk 构建环境是否符合要求

功能：
1. 检查 Rust 版本是否满足要求
2. 检查 Cargo 版本
3. 检查 vcpkg 配置
4. 验证系统依赖
5. 输出诊断报告
"""

import os
import subprocess
import sys
import json
from datetime import datetime

REQUIRED_RUST_VERSION = "1.95"
REQUIRED_TOOLS = ["git", "curl", "python3", "cmake", "ninja"]

def run_command(cmd, capture_output=True):
    """执行命令并返回结果"""
    try:
        result = subprocess.run(
            cmd,
            shell=True,
            capture_output=capture_output,
            universal_newlines=True,
            timeout=60
        )
        return result.returncode, result.stdout.strip(), result.stderr.strip()
    except subprocess.TimeoutExpired:
        return -1, "", "Command timed out"
    except Exception as e:
        return -1, "", str(e)

def check_rust_version():
    """检查 Rust 版本"""
    print("🔧 检查 Rust 版本...")
    code, stdout, stderr = run_command("rustc --version")
    
    if code != 0:
        return {
            "status": "error",
            "message": f"Rust 未安装或无法执行: {stderr}"
        }
    
    version = stdout.split()[1]
    print(f"   当前 Rust 版本: {version}")
    
    if version.startswith(REQUIRED_RUST_VERSION):
        return {
            "status": "ok",
            "version": version,
            "message": f"Rust 版本符合要求 ({REQUIRED_RUST_VERSION}+)"
        }
    else:
        return {
            "status": "warning",
            "version": version,
            "message": f"Rust 版本 {version} 可能不满足要求，建议使用 {REQUIRED_RUST_VERSION}"
        }

def check_cargo_version():
    """检查 Cargo 版本"""
    print("🔧 检查 Cargo 版本...")
    code, stdout, stderr = run_command("cargo --version")
    
    if code != 0:
        return {
            "status": "error",
            "message": f"Cargo 未安装或无法执行: {stderr}"
        }
    
    version = stdout.split()[1]
    print(f"   当前 Cargo 版本: {version}")
    
    return {
        "status": "ok",
        "version": version,
        "message": "Cargo 已安装"
    }

def check_vcpkg():
    """检查 vcpkg 配置"""
    print("🔧 检查 vcpkg 配置...")
    
    vcpkg_root = os.environ.get("VCPKG_ROOT")
    if not vcpkg_root:
        return {
            "status": "warning",
            "message": "VCPKG_ROOT 环境变量未设置"
        }
    
    print(f"   VCPKG_ROOT: {vcpkg_root}")
    
    if os.path.isdir(vcpkg_root):
        return {
            "status": "ok",
            "vcpkg_root": vcpkg_root,
            "message": "vcpkg 目录存在"
        }
    else:
        return {
            "status": "error",
            "vcpkg_root": vcpkg_root,
            "message": f"vcpkg 目录不存在: {vcpkg_root}"
        }

def check_system_tools():
    """检查系统工具"""
    print("🔧 检查系统工具...")
    results = []
    
    for tool in REQUIRED_TOOLS:
        code, stdout, stderr = run_command(f"which {tool}" if sys.platform != "win32" else f"where {tool}")
        
        if code == 0:
            path = stdout.split("\n")[0] if "\n" in stdout else stdout
            results.append({
                "tool": tool,
                "status": "ok",
                "path": path,
                "message": f"{tool} 已安装"
            })
            print(f"   ✓ {tool}: {path}")
        else:
            results.append({
                "tool": tool,
                "status": "missing",
                "message": f"{tool} 未安装"
            })
            print(f"   ✗ {tool}: 未安装")
    
    return results

def check_flutter():
    """检查 Flutter 安装"""
    print("🔧 检查 Flutter 版本...")
    code, stdout, stderr = run_command("flutter --version")
    
    if code != 0:
        return {
            "status": "warning",
            "message": f"Flutter 未安装或无法执行: {stderr}"
        }
    
    lines = stdout.split("\n")
    version = ""
    channel = ""
    
    for line in lines:
        if line.startswith("Flutter"):
            version = line.split()[1]
        elif line.startswith("Channel"):
            channel = line.split()[1]
    
    print(f"   Flutter 版本: {version} ({channel})")
    
    return {
        "status": "ok",
        "version": version,
        "channel": channel,
        "message": "Flutter 已安装"
    }

def check_disk_space():
    """检查磁盘空间"""
    print("🔧 检查磁盘空间...")
    
    if sys.platform == "win32":
        code, stdout, stderr = run_command("wmic logicaldisk get size,freespace,caption")
    else:
        code, stdout, stderr = run_command("df -h /")
    
    if code == 0:
        print(f"   磁盘信息:\n{stdout}")
        return {
            "status": "ok",
            "message": "磁盘空间检查完成"
        }
    else:
        return {
            "status": "warning",
            "message": f"无法检查磁盘空间: {stderr}"
        }

def generate_report(results):
    """生成诊断报告"""
    report = {
        "timestamp": datetime.now().isoformat(),
        "os": sys.platform,
        "python_version": sys.version,
        "rust": results["rust"],
        "cargo": results["cargo"],
        "vcpkg": results["vcpkg"],
        "flutter": results["flutter"],
        "system_tools": results["system_tools"],
        "disk_space": results["disk_space"]
    }
    
    # 计算整体状态
    errors = []
    warnings = []
    
    for key, result in report.items():
        if isinstance(result, dict) and "status" in result:
            if result["status"] == "error":
                errors.append(f"{key}: {result['message']}")
            elif result["status"] == "warning":
                warnings.append(f"{key}: {result['message']}")
    
    report["summary"] = {
        "errors": len(errors),
        "warnings": len(warnings),
        "status": "ok" if len(errors) == 0 else "error"
    }
    
    # 保存报告
    report_file = "env_validation_report.json"
    with open(report_file, "w") as f:
        json.dump(report, f, indent=2)
    
    print(f"\n📋 诊断报告已保存到: {report_file}")
    
    return report

def main():
    """主函数"""
    print("="*60)
    print("    RustDesk 构建环境验证脚本")
    print("="*60)
    print()
    
    results = {}
    
    # 执行所有检查
    results["rust"] = check_rust_version()
    print()
    
    results["cargo"] = check_cargo_version()
    print()
    
    results["vcpkg"] = check_vcpkg()
    print()
    
    results["flutter"] = check_flutter()
    print()
    
    results["system_tools"] = check_system_tools()
    print()
    
    results["disk_space"] = check_disk_space()
    print()
    
    # 生成报告
    report = generate_report(results)
    
    print("="*60)
    print("                        验证结果")
    print("="*60)
    
    if report["summary"]["status"] == "ok":
        print("✅ 所有检查通过！构建环境已就绪。")
        if report["summary"]["warnings"] > 0:
            print(f"   ⚠️  发现 {report['summary']['warnings']} 个警告，建议检查")
        sys.exit(0)
    else:
        print("❌ 发现错误，构建环境未就绪:")
        for key, result in report.items():
            if isinstance(result, dict) and result.get("status") == "error":
                print(f"   - {result['message']}")
        sys.exit(1)

if __name__ == "__main__":
    main()