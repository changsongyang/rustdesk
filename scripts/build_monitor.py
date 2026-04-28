#!/usr/bin/env python3
"""
构建监控脚本 - 用于收集构建时间统计和验证产物

功能：
1. 记录构建开始和结束时间
2. 计算各阶段耗时
3. 验证构建产物
4. 生成构建报告
"""

import os
import sys
import json
import time
import hashlib
from datetime import datetime

class BuildMonitor:
    def __init__(self):
        self.start_time = time.time()
        self.phase_timestamps = []
        self.products = []
        self.errors = []
        self.warnings = []
        
    def start_phase(self, phase_name):
        """记录阶段开始时间"""
        self.phase_timestamps.append({
            "name": phase_name,
            "start": time.time(),
            "end": None,
            "duration": None
        })
        print(f"📌 开始阶段: {phase_name}")
        
    def end_phase(self, phase_name=None):
        """记录阶段结束时间"""
        if phase_name is None:
            phase_name = self.phase_timestamps[-1]["name"]
            
        for phase in self.phase_timestamps:
            if phase["name"] == phase_name and phase["end"] is None:
                phase["end"] = time.time()
                phase["duration"] = phase["end"] - phase["start"]
                duration_str = self.format_duration(phase["duration"])
                print(f"✅ 阶段完成: {phase_name} - 耗时: {duration_str}")
                return phase["duration"]
        
        return None
    
    def format_duration(self, seconds):
        """格式化时间为可读格式"""
        if seconds < 60:
            return f"{seconds:.2f}秒"
        elif seconds < 3600:
            minutes = int(seconds // 60)
            secs = seconds % 60
            return f"{minutes}分{secs:.2f}秒"
        else:
            hours = int(seconds // 3600)
            minutes = int((seconds % 3600) // 60)
            secs = seconds % 60
            return f"{hours}时{minutes}分{secs:.2f}秒"
    
    def add_product(self, path, description=""):
        """添加构建产物"""
        self.products.append({
            "path": path,
            "description": description,
            "exists": os.path.exists(path),
            "size": os.path.getsize(path) if os.path.exists(path) else 0,
            "hash": self.calculate_hash(path) if os.path.exists(path) else None
        })
    
    def calculate_hash(self, file_path):
        """计算文件 SHA256 哈希"""
        sha256_hash = hashlib.sha256()
        try:
            with open(file_path, "rb") as f:
                for chunk in iter(lambda: f.read(8192), b""):
                    sha256_hash.update(chunk)
            return sha256_hash.hexdigest()
        except Exception as e:
            self.add_error(f"无法计算文件哈希 {file_path}: {e}")
            return None
    
    def add_error(self, message):
        """添加错误信息"""
        self.errors.append({
            "timestamp": datetime.now().isoformat(),
            "message": message
        })
        print(f"❌ 错误: {message}")
    
    def add_warning(self, message):
        """添加警告信息"""
        self.warnings.append({
            "timestamp": datetime.now().isoformat(),
            "message": message
        })
        print(f"⚠️  警告: {message}")
    
    def validate_products(self):
        """验证所有构建产物"""
        print("\n🔍 验证构建产物...")
        all_valid = True
        
        for product in self.products:
            if not product["exists"]:
                self.add_error(f"构建产物不存在: {product['path']}")
                all_valid = False
            elif product["size"] == 0:
                self.add_warning(f"构建产物为空: {product['path']}")
            else:
                print(f"✅ 验证通过: {product['path']} ({product['size']:,} bytes)")
        
        return all_valid
    
    def generate_report(self):
        """生成构建报告"""
        total_duration = time.time() - self.start_time
        
        report = {
            "timestamp": datetime.now().isoformat(),
            "total_duration": total_duration,
            "total_duration_formatted": self.format_duration(total_duration),
            "phases": self.phase_timestamps,
            "products": self.products,
            "errors": self.errors,
            "warnings": self.warnings,
            "summary": {
                "total_phases": len(self.phase_timestamps),
                "total_errors": len(self.errors),
                "total_warnings": len(self.warnings),
                "total_products": len(self.products),
                "valid_products": sum(1 for p in self.products if p["exists"]),
                "status": "success" if len(self.errors) == 0 else "failed"
            }
        }
        
        # 保存报告
        report_file = f"build_report_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
        with open(report_file, "w") as f:
            json.dump(report, f, indent=2)
        
        return report, report_file
    
    def print_summary(self):
        """打印构建摘要"""
        print("\n" + "="*60)
        print("              构建监控报告")
        print("="*60)
        
        # 阶段统计
        print("\n📊 阶段耗时统计:")
        for phase in self.phase_timestamps:
            duration_str = self.format_duration(phase["duration"]) if phase["duration"] else "未完成"
            print(f"  • {phase['name']}: {duration_str}")
        
        # 产物统计
        print("\n📦 构建产物:")
        for product in self.products:
            status = "✅" if product["exists"] else "❌"
            size_str = f"({product['size']:,} bytes)" if product["size"] > 0 else ""
            print(f"  {status} {product['path']} {size_str}")
        
        # 错误和警告
        if self.errors:
            print(f"\n❌ 错误 ({len(self.errors)}):")
            for error in self.errors:
                print(f"  • {error['message']}")
        
        if self.warnings:
            print(f"\n⚠️  警告 ({len(self.warnings)}):")
            for warning in self.warnings:
                print(f"  • {warning['message']}")
        
        # 总耗时
        total_duration = time.time() - self.start_time
        print(f"\n⏱ 总耗时: {self.format_duration(total_duration)}")
        
        print("\n" + "="*60)
        if len(self.errors) == 0:
            print("✅ 构建成功！")
            return 0
        else:
            print("❌ 构建失败！")
            return 1

def main():
    """主函数 - 示例用法"""
    monitor = BuildMonitor()
    
    # 示例：监控构建流程
    monitor.start_phase("依赖下载")
    # 模拟耗时操作
    time.sleep(2)
    monitor.end_phase("依赖下载")
    
    monitor.start_phase("编译")
    time.sleep(3)
    monitor.end_phase("编译")
    
    monitor.start_phase("链接")
    time.sleep(1)
    monitor.end_phase("链接")
    
    # 添加示例产物
    monitor.add_product("target/release/rustdesk", "主程序")
    monitor.add_product("target/release/liblibrustdesk.so", "库文件")
    
    # 验证产物
    monitor.validate_products()
    
    # 生成报告
    report, report_file = monitor.generate_report()
    print(f"\n📋 报告已保存到: {report_file}")
    
    # 打印摘要
    return monitor.print_summary()

if __name__ == "__main__":
    sys.exit(main())