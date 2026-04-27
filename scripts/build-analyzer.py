#!/usr/bin/env python3

import json
import os
import matplotlib.pyplot as plt
import pandas as pd
from datetime import datetime

# 构建分析工具
# 用于分析构建监控数据，生成性能报告

class BuildAnalyzer:
    def __init__(self, monitor_dir=".build-monitor"):
        self.monitor_dir = monitor_dir
        self.stats_file = os.path.join(monitor_dir, "build-stats.json")
        self.errors_file = os.path.join(monitor_dir, "errors.json")
        self.log_file = os.path.join(monitor_dir, "build.log")
        
    def load_data(self):
        """加载构建数据"""
        if not os.path.exists(self.stats_file):
            print("错误: 构建统计文件不存在")
            return False
        
        with open(self.stats_file, 'r', encoding='utf-8') as f:
            self.stats = json.load(f)
        
        if os.path.exists(self.errors_file):
            with open(self.errors_file, 'r', encoding='utf-8') as f:
                self.errors = json.load(f)
        else:
            self.errors = {"errors": []}
        
        return True
    
    def generate_report(self, output_dir=".build-reports"):
        """生成构建报告"""
        if not self.load_data():
            return
        
        # 确保输出目录存在
        os.makedirs(output_dir, exist_ok=True)
        
        # 生成HTML报告
        html_report = self._generate_html_report()
        report_file = os.path.join(output_dir, f"build-report-{datetime.now().strftime('%Y%m%d%H%M%S')}.html")
        
        with open(report_file, 'w', encoding='utf-8') as f:
            f.write(html_report)
        
        print(f"构建报告已生成: {report_file}")
        
        # 生成图表
        self._generate_charts(output_dir)
        
    def _generate_html_report(self):
        """生成HTML报告"""
        total_builds = self.stats.get("total_builds", 0)
        successful_builds = self.stats.get("successful_builds", 0)
        failed_builds = self.stats.get("failed_builds", 0)
        avg_build_time = self.stats.get("avg_build_time", 0)
        
        if total_builds > 0:
            success_rate = (successful_builds / total_builds) * 100
        else:
            success_rate = 0
        
        # 最近构建记录
        recent_builds = self.stats.get("builds", [])[-10:]
        recent_builds.reverse()
        
        # 最近错误
        recent_errors = self.errors.get("errors", [])[-5:]
        recent_errors.reverse()
        
        # 错误类型统计
        error_types = {}
        for error in self.errors.get("errors", []):
            error_type = error.get("error_type", "Unknown")
            if error_type:
                error_types[error_type] = error_types.get(error_type, 0) + 1
        
        # 构建时间趋势
        build_times = []
        build_dates = []
        for build in self.stats.get("builds", []):
            build_times.append(int(build.get("time", 0)))
            build_dates.append(build.get("date", ""))
        
        # 生成HTML
        html = f"""
        <!DOCTYPE html>
        <html lang="zh-CN">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>构建分析报告</title>
            <style>
                body {{ font-family: Arial, sans-serif; margin: 20px; }}
                .container {{ max-width: 1200px; margin: 0 auto; }}
                h1, h2 {{ color: #333; }}
                .stats {{ display: flex; gap: 20px; margin: 20px 0; }}
                .stat-card {{ flex: 1; background: #f5f5f5; padding: 20px; border-radius: 8px; }}
                .stat-value {{ font-size: 24px; font-weight: bold; }}
                .success {{ color: #4CAF50; }}
                .failure {{ color: #f44336; }}
                table {{ width: 100%; border-collapse: collapse; margin: 20px 0; }}
                th, td {{ border: 1px solid #ddd; padding: 8px; text-align: left; }}
                th {{ background-color: #f2f2f2; }}
                .chart {{ margin: 20px 0; }}
                .error {{ background-color: #ffebee; padding: 10px; margin: 10px 0; border-left: 4px solid #f44336; }}
            </style>
        </head>
        <body>
            <div class="container">
                <h1>构建分析报告</h1>
                <p>生成时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}</p>
                
                <div class="stats">
                    <div class="stat-card">
                        <h3>总构建次数</h3>
                        <div class="stat-value">{total_builds}</div>
                    </div>
                    <div class="stat-card">
                        <h3>成功构建</h3>
                        <div class="stat-value success">{successful_builds}</div>
                    </div>
                    <div class="stat-card">
                        <h3>失败构建</h3>
                        <div class="stat-value failure">{failed_builds}</div>
                    </div>
                    <div class="stat-card">
                        <h3>平均构建时间</h3>
                        <div class="stat-value">{avg_build_time:.2f}秒</div>
                    </div>
                    <div class="stat-card">
                        <h3>成功率</h3>
                        <div class="stat-value {"success" if success_rate > 90 else ""}">{success_rate:.1f}%</div>
                    </div>
                </div>
                
                <h2>最近构建记录</h2>
                <table>
                    <tr>
                        <th>构建ID</th>
                        <th>状态</th>
                        <th>构建时间</th>
                        <th>日期</th>
                    </tr>
                    {self._generate_build_table(recent_builds)}
                </table>
                
                <h2>最近错误</h2>
                {self._generate_errors_section(recent_errors)}
                
                <h2>错误类型统计</h2>
                <table>
                    <tr>
                        <th>错误类型</th>
                        <th>出现次数</th>
                    </tr>
                    {self._generate_error_types_table(error_types)}
                </table>
                
                <h2>构建时间趋势</h2>
                <div class="chart">
                    <img src="build-time-trend.png" alt="构建时间趋势" style="max-width: 100%;">
                </div>
                
                <h2>构建状态分布</h2>
                <div class="chart">
                    <img src="build-status-distribution.png" alt="构建状态分布" style="max-width: 100%;">
                </div>
            </div>
        </body>
        </html>
        """
        
        return html
    
    def _generate_build_table(self, builds):
        """生成构建记录表格"""
        rows = []
        for build in builds:
            status_class = "success" if build.get("status") == "success" else "failure"
            row = f"""
            <tr>
                <td>{build.get("build_id")}</td>
                <td class="{status_class}">{build.get("status")}</td>
                <td>{build.get("time")}秒</td>
                <td>{build.get("date")}</td>
            </tr>
            """
            rows.append(row)
        return ''.join(rows)
    
    def _generate_errors_section(self, errors):
        """生成错误部分"""
        if not errors:
            return "<p>最近没有错误记录</p>"
        
        error_html = []
        for error in errors:
            error_html.append(f"""
            <div class="error">
                <h4>构建ID: {error.get("build_id")}</h4>
                <p><strong>错误类型:</strong> {error.get("error_type")}</p>
                <p><strong>错误信息:</strong> {error.get("error_message")}</p>
                <p><strong>日期:</strong> {error.get("date")}</p>
            </div>
            """)
        
        return ''.join(error_html)
    
    def _generate_error_types_table(self, error_types):
        """生成错误类型表格"""
        rows = []
        for error_type, count in sorted(error_types.items(), key=lambda x: x[1], reverse=True):
            rows.append(f"""
            <tr>
                <td>{error_type}</td>
                <td>{count}</td>
            </tr>
            """)
        return ''.join(rows)
    
    def _generate_charts(self, output_dir):
        """生成图表"""
        # 构建时间趋势图
        build_times = []
        build_dates = []
        for build in self.stats.get("builds", []):
            build_times.append(int(build.get("time", 0)))
            build_dates.append(build.get("date", ""))
        
        if build_times:
            plt.figure(figsize=(12, 6))
            plt.plot(build_dates, build_times, marker='o')
            plt.title('构建时间趋势')
            plt.xlabel('日期')
            plt.ylabel('构建时间 (秒)')
            plt.xticks(rotation=45)
            plt.tight_layout()
            plt.savefig(os.path.join(output_dir, "build-time-trend.png"))
            plt.close()
        
        # 构建状态分布图
        total_builds = self.stats.get("total_builds", 0)
        successful_builds = self.stats.get("successful_builds", 0)
        failed_builds = self.stats.get("failed_builds", 0)
        
        if total_builds > 0:
            plt.figure(figsize=(8, 6))
            plt.pie([successful_builds, failed_builds], labels=['成功', '失败'], autopct='%1.1f%%', startangle=90)
            plt.title('构建状态分布')
            plt.tight_layout()
            plt.savefig(os.path.join(output_dir, "build-status-distribution.png"))
            plt.close()

if __name__ == "__main__":
    analyzer = BuildAnalyzer()
    analyzer.generate_report()
