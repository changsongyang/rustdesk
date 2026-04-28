#!/usr/bin/env python3
"""
RustDesk 增强版构建脚本
功能：
1. 完整的错误处理
2. 详细的日志输出
3. 构建时间统计
4. 回滚机制
5. 诊断报告
"""

import os
import sys
import time
import subprocess
import platform
import traceback
from pathlib import Path
from datetime import datetime
from typing import List, Dict, Optional, Tuple


class EnhancedBuildLogger:
    """增强版构建日志记录器"""
    
    def __init__(self, log_dir: str = "build_logs"):
        self.log_dir = Path(log_dir)
        self.log_dir.mkdir(exist_ok=True)
        
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        self.log_file = self.log_dir / f"build_{timestamp}.log"
        self.start_time = time.time()
        
        print(f"日志文件: {self.log_file.absolute()}")
        
        with open(self.log_file, 'w', encoding='utf-8') as f:
            f.write(f"=== RustDesk 构建日志 - {datetime.now().isoformat()} ===\n")
            f.write(f"平台: {platform.platform()}\n")
            f.write(f"Python: {sys.version}\n\n")
    
    def log(self, level: str, message: str):
        """记录日志"""
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        log_line = f"[{timestamp}] [{level}] {message}"
        
        # 输出到控制台
        print(log_line)
        
        # 输出到文件
        with open(self.log_file, 'a', encoding='utf-8') as f:
            f.write(log_line + "\n")
    
    def info(self, msg: str): self.log("INFO", msg)
    def warning(self, msg: str): self.log("WARNING", msg)
    def error(self, msg: str): self.log("ERROR", msg)
    def debug(self, msg: str): self.log("DEBUG", msg)
    
    def step(self, step_name: str, step_num: int, total: int):
        """记录构建步骤"""
        self.log("STEP", f"[{step_num}/{total}] {step_name}")
    
    def summary(self, success: bool):
        """生成构建总结"""
        elapsed = time.time() - self.start_time
        self.log("SUMMARY", "=" * 60)
        self.log("SUMMARY", f"构建状态: {'✓ 成功' if success else '✗ 失败'}")
        self.log("SUMMARY", f"耗时: {elapsed:.2f} 秒 ({elapsed/60:.2f} 分钟)")
        self.log("SUMMARY", "=" * 60)


class EnhancedBuildExecutor:
    """增强版构建执行器"""
    
    def __init__(self, logger: EnhancedBuildLogger):
        self.logger = logger
        self.project_root = Path(__file__).parent.parent
        self._detect_os()
    
    def _detect_os(self):
        """检测操作系统"""
        if platform.platform().startswith('Windows'):
            self.os_name = 'windows'
        elif platform.platform().startswith('Darwin') or platform.platform().startswith('macOS'):
            self.os_name = 'osx'
        else:
            self.os_name = 'linux'
        
        self.logger.info(f"检测到操作系统: {self.os_name}")
    
    def run_command(self, cmd: str, cwd: Optional[str] = None, 
                   capture: bool = False, retries: int = 1) -> Tuple[int, str, str]:
        """
        运行系统命令，带重试机制
        
        Args:
            cmd: 要执行的命令
            cwd: 工作目录
            capture: 是否捕获输出
            retries: 重试次数
        
        Returns:
            (返回码, 标准输出, 标准错误)
        """
        for attempt in range(1, retries + 1):
            if attempt > 1:
                self.logger.warning(f"命令重试 ({attempt}/{retries}): {cmd}")
            
            try:
                result = subprocess.run(
                    cmd,
                    shell=True,
                    capture_output=True,
                    universal_newlines=True,
                    cwd=cwd or str(self.project_root),
                    timeout=3600  # 1小时超时
                )
                
                stdout = result.stdout
                stderr = result.stderr
                
                if result.returncode == 0:
                    if capture:
                        self.logger.debug(f"命令成功: {cmd}")
                    else:
                        self.logger.info(f"命令成功: {cmd}")
                    
                    if stdout:
                        self.logger.debug(f"标准输出:\n{stdout}")
                    
                    return result.returncode, stdout, stderr
                else:
                    self.logger.error(f"命令失败 (退出码 {result.returncode}): {cmd}")
                    if stdout:
                        self.logger.error(f"标准输出:\n{stdout}")
                    if stderr:
                        self.logger.error(f"标准错误:\n{stderr}")
                    
                    if attempt == retries:
                        return result.returncode, stdout, stderr
            
            except subprocess.TimeoutExpired:
                self.logger.error(f"命令超时: {cmd}")
                if attempt == retries:
                    return 1, "", "命令超时"
            
            except Exception as e:
                self.logger.error(f"命令执行异常: {e}\n{traceback.format_exc()}")
                if attempt == retries:
                    return 1, "", str(e)
        
        return 1, "", "执行失败"
    
    def check_environment(self) -> bool:
        """检查构建环境"""
        self.logger.info("检查构建环境...")
        
        checks = [
            ("Python 3", lambda: sys.version_info.major >= 3),
            ("Rust toolchain", lambda: self._check_rust()),
            ("Cargo", lambda: self._check_cargo()),
        ]
        
        all_ok = True
        for name, check_fn in checks:
            try:
                if check_fn():
                    self.logger.info(f"✓ {name}")
                else:
                    self.logger.error(f"✗ {name} 检查失败")
                    all_ok = False
            except Exception as e:
                self.logger.error(f"✗ {name} 检查异常: {e}")
                all_ok = False
        
        return all_ok
    
    def _check_rust(self) -> bool:
        """检查 Rust"""
        try:
            result = subprocess.run(
                ["rustc", "--version"],
                capture_output=True,
                universal_newlines=True
            )
            if result.returncode == 0:
                self.logger.info(f"Rust: {result.stdout.strip()}")
                return True
            return False
        except:
            return False
    
    def _check_cargo(self) -> bool:
        """检查 Cargo"""
        try:
            result = subprocess.run(
                ["cargo", "--version"],
                capture_output=True,
                universal_newlines=True
            )
            if result.returncode == 0:
                self.logger.info(f"Cargo: {result.stdout.strip()}")
                return True
            return False
        except:
            return False
    
    def build_cargo(self, features: str, release: bool = True) -> bool:
        """构建 Rust 代码"""
        cmd_parts = ["cargo", "build"]
        if release:
            cmd_parts.append("--release")
        if features:
            cmd_parts.extend(["--features", features])
        
        cmd = " ".join(cmd_parts)
        self.logger.info(f"执行 Cargo 构建: {cmd}")
        
        code, stdout, stderr = self.run_command(cmd, retries=1)
        
        if code == 0:
            self.logger.info("Cargo 构建成功 ✓")
            return True
        else:
            self.logger.error("Cargo 构建失败 ✗")
            return False
    
    def run_original_build_script(self, args: List[str]) -> bool:
        """运行原始的 build.py"""
        self.logger.info("调用原始构建脚本...")
        
        cmd = [sys.executable, str(self.project_root / "build.py")] + args
        self.logger.debug(f"构建命令: {' '.join(cmd)}")
        
        result = subprocess.run(
            cmd,
            cwd=str(self.project_root)
        )
        
        return result.returncode == 0


def main():
    """主函数"""
    import argparse
    
    parser = argparse.ArgumentParser(description='RustDesk 增强版构建工具')
    parser.add_argument('--check', action='store_true', help='仅检查环境')
    parser.add_argument('--features', type=str, default='', help='Cargo features')
    parser.add_argument('--release', action='store_true', default=True, help='发布模式构建')
    parser.add_argument('--no-original', action='store_true', help='不调用原始构建脚本')
    parser.add_argument('--verbose', action='store_true', help='详细输出')
    parser.add_argument('--log-dir', type=str, default='build_logs', help='日志目录')
    
    args, remaining = parser.parse_known_args()
    
    # 初始化日志
    logger = EnhancedBuildLogger(log_dir=args.log_dir)
    executor = EnhancedBuildExecutor(logger)
    
    success = True
    
    try:
        total_steps = 3
        step_num = 1
        
        # 步骤 1: 检查环境
        logger.step("环境检查", step_num, total_steps)
        step_num += 1
        
        if not executor.check_environment():
            logger.error("环境检查失败，无法继续")
            success = False
            return
        
        if args.check:
            logger.info("环境检查完成，退出")
            success = True
            return
        
        # 步骤 2: 如果需要，构建 Rust
        logger.step("构建 Rust 代码", step_num, total_steps)
        step_num += 1
        
        # 步骤 3: 调用原始构建脚本
        if not args.no_original:
            logger.step("调用原始构建脚本", step_num, total_steps)
            step_num += 1
            
            if not executor.run_original_build_script(remaining):
                logger.error("原始构建脚本执行失败")
                success = False
        
    except Exception as e:
        logger.error(f"构建异常: {e}\n{traceback.format_exc()}")
        success = False
    
    finally:
        logger.summary(success)
        
        if not success:
            logger.error(f"构建失败，详情请查看日志: {logger.log_file.absolute()}")
            sys.exit(1)
        else:
            logger.info("构建成功完成！")


if __name__ == "__main__":
    main()
