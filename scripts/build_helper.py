#!/usr/bin/env python3
"""
RustDesk 构建辅助脚本
功能：
1. 环境检查和验证
2. 依赖诊断
3. 构建优化配置
4. 详细日志输出
"""

import os
import sys
import subprocess
import platform
import json
import hashlib
from pathlib import Path
from datetime import datetime


class BuildLogger:
    """构建日志管理器"""
    
    LEVELS = {
        'DEBUG': 0,
        'INFO': 1,
        'WARNING': 2,
        'ERROR': 3,
        'CRITICAL': 4
    }
    
    def __init__(self, log_file=None, level='INFO'):
        self.level = self.LEVELS.get(level, 1)
        self.log_file = log_file
        if log_file:
            os.makedirs(os.path.dirname(log_file), exist_ok=True)
        
    def _log(self, level, message):
        timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        log_msg = f"[{timestamp}] [{level}] {message}"
        
        # 输出到控制台
        print(log_msg, file=sys.stderr if level in ['ERROR', 'CRITICAL'] else sys.stdout)
        
        # 输出到文件
        if self.log_file:
            with open(self.log_file, 'a', encoding='utf-8') as f:
                f.write(log_msg + '\n')
    
    def debug(self, msg): self._log('DEBUG', msg)
    def info(self, msg): self._log('INFO', msg)
    def warning(self, msg): self._log('WARNING', msg)
    def error(self, msg): self._log('ERROR', msg)
    def critical(self, msg): self._log('CRITICAL', msg)


class BuildHelper:
    """构建辅助类"""
    
    def __init__(self, logger=None):
        self.logger = logger or BuildLogger()
        self.project_root = Path(__file__).parent.parent
        self.os_type = self._detect_os()
        
    def _detect_os(self):
        """检测操作系统类型"""
        if platform.platform().startswith('Windows'):
            return 'windows'
        elif platform.platform().startswith('Darwin') or platform.platform().startswith('macOS'):
            return 'osx'
        return 'linux'
    
    def run_command(self, cmd, check=True, cwd=None, capture_output=False):
        """运行系统命令并返回结果"""
        self.logger.debug(f"执行命令: {cmd}")
        
        try:
            result = subprocess.run(
                cmd,
                shell=True,
                capture_output=capture_output,
                text=capture_output,
                cwd=cwd or self.project_root
            )
            
            if check and result.returncode != 0:
                if capture_output:
                    self.logger.error(f"命令失败 (退出码 {result.returncode}): {result.stderr}")
                raise RuntimeError(f"命令执行失败: {cmd}")
            
            return result
        except Exception as e:
            self.logger.error(f"命令执行异常: {e}")
            if check:
                raise
            return None
    
    def check_rust_env(self):
        """检查 Rust 环境"""
        self.logger.info("检查 Rust 环境...")
        
        checks = {
            'rustc': ['rustc --version', 'rustc'],
            'cargo': ['cargo --version', 'cargo'],
            'rustup': ['rustup --version', 'rustup']
        }
        
        status = {}
        for name, commands in checks.items():
            for cmd in commands:
                try:
                    result = self.run_command(cmd, check=False, capture_output=True)
                    if result and result.returncode == 0:
                        status[name] = {
                            'available': True,
                            'version': result.stdout.strip()
                        }
                        self.logger.info(f"✓ {name} 可用: {result.stdout.strip()}")
                        break
                except:
                    pass
            
            if name not in status:
                status[name] = {'available': False}
                self.logger.warning(f"✗ {name} 未找到")
        
        return status
    
    def check_vcpkg_env(self):
        """检查 vcpkg 环境"""
        self.logger.info("检查 vcpkg 环境...")
        
        status = {}
        vcpkg_root = os.environ.get('VCPKG_ROOT')
        
        if not vcpkg_root:
            self.logger.warning("VCPKG_ROOT 环境变量未设置")
            status['VCPKG_ROOT'] = None
        else:
            status['VCPKG_ROOT'] = vcpkg_root
            self.logger.info(f"VCPKG_ROOT: {vcpkg_root}")
            
            vcpkg_json = self.project_root / 'vcpkg.json'
            if vcpkg_json.exists():
                self.logger.info(f"vcpkg.json 已找到: {vcpkg_json}")
                try:
                    with open(vcpkg_json, 'r', encoding='utf-8') as f:
                        vcpkg_config = json.load(f)
                    status['vcpkg_config'] = vcpkg_config
                    self.logger.debug(f"vcpkg.json 配置: {vcpkg_config}")
                except Exception as e:
                    self.logger.error(f"解析 vcpkg.json 失败: {e}")
        
        return status
    
    def check_flutter_env(self):
        """检查 Flutter 环境"""
        self.logger.info("检查 Flutter 环境...")
        
        status = {}
        try:
            result = self.run_command('flutter --version', check=False, capture_output=True)
            if result and result.returncode == 0:
                status['available'] = True
                status['version'] = result.stdout.strip()
                self.logger.info(f"✓ Flutter 可用: {result.stdout.strip()}")
            else:
                status['available'] = False
                self.logger.warning("✗ Flutter 未找到")
        except Exception as e:
            self.logger.error(f"检查 Flutter 环境失败: {e}")
            status['available'] = False
        
        return status
    
    def check_cargo_deps(self):
        """检查 Cargo 依赖状态"""
        self.logger.info("检查 Cargo 依赖...")
        
        cargo_toml = self.project_root / 'Cargo.toml'
        cargo_lock = self.project_root / 'Cargo.lock'
        
        status = {
            'Cargo.toml': cargo_toml.exists(),
            'Cargo.lock': cargo_lock.exists()
        }
        
        if not status['Cargo.toml']:
            self.logger.error("Cargo.toml 不存在!")
            return status
        
        self.logger.info("✓ Cargo.toml 找到")
        
        if not status['Cargo.lock']:
            self.logger.warning("Cargo.lock 不存在，将在构建时自动生成")
        else:
            self.logger.info("✓ Cargo.lock 找到")
        
        return status
    
    def check_network(self):
        """检查网络连接状态"""
        self.logger.info("检查网络连接...")
        
        test_urls = [
            'https://github.com',
            'https://crates.io',
            'https://microsoft.com'
        ]
        
        status = {}
        for url in test_urls:
            try:
                import urllib.request
                with urllib.request.urlopen(url, timeout=10):
                    status[url] = True
                    self.logger.info(f"✓ 可连接到 {url}")
            except Exception as e:
                status[url] = False
                self.logger.warning(f"✗ 无法连接到 {url}: {e}")
        
        return status
    
    def generate_build_report(self):
        """生成完整的构建诊断报告"""
        self.logger.info("生成构建诊断报告...")
        
        report = {
            'timestamp': datetime.now().isoformat(),
            'os': self.os_type,
            'platform': platform.platform(),
            'python_version': sys.version,
            'rust': self.check_rust_env(),
            'vcpkg': self.check_vcpkg_env(),
            'flutter': self.check_flutter_env(),
            'cargo': self.check_cargo_deps(),
            'network': self.check_network()
        }
        
        report_file = self.project_root / 'build_report.json'
        with open(report_file, 'w', encoding='utf-8') as f:
            json.dump(report, f, indent=2, ensure_ascii=False)
        
        self.logger.info(f"诊断报告已保存到: {report_file}")
        return report
    
    def optimize_cargo_config(self):
        """优化 Cargo 配置"""
        self.logger.info("优化 Cargo 配置...")
        
        config_toml = self.project_root / '.cargo' / 'config.toml'
        config_toml.parent.mkdir(exist_ok=True)
        
        # 基础优化配置
        optimizations = '''
[build]
jobs = 4

[profile.release]
opt-level = 3
lto = true
codegen-units = 1
strip = true
incremental = false
'''
        
        if not config_toml.exists():
            with open(config_toml, 'w', encoding='utf-8') as f:
                f.write(optimizations)
            self.logger.info(f"已创建优化配置: {config_toml}")
        else:
            self.logger.info(f"配置文件已存在，跳过: {config_toml}")
        
        return config_toml


def main():
    """主函数"""
    import argparse
    
    parser = argparse.ArgumentParser(description='RustDesk 构建辅助工具')
    parser.add_argument('--diagnose', action='store_true', help='执行完整诊断')
    parser.add_argument('--check-rust', action='store_true', help='检查 Rust 环境')
    parser.add_argument('--check-vcpkg', action='store_true', help='检查 vcpkg 环境')
    parser.add_argument('--check-flutter', action='store_true', help='检查 Flutter 环境')
    parser.add_argument('--check-network', action='store_true', help='检查网络连接')
    parser.add_argument('--optimize', action='store_true', help='优化构建配置')
    parser.add_argument('--log-level', default='INFO', help='日志级别 (DEBUG, INFO, WARNING, ERROR)')
    parser.add_argument('--log-file', help='日志文件路径')
    
    args = parser.parse_args()
    
    logger = BuildLogger(log_file=args.log_file, level=args.log_level)
    helper = BuildHelper(logger)
    
    if args.diagnose:
        helper.generate_build_report()
    elif args.check_rust:
        helper.check_rust_env()
    elif args.check_vcpkg:
        helper.check_vcpkg_env()
    elif args.check_flutter:
        helper.check_flutter_env()
    elif args.check_network:
        helper.check_network()
    elif args.optimize:
        helper.optimize_cargo_config()
    else:
        parser.print_help()


if __name__ == "__main__":
    main()
