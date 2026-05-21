# 脚本工具索引

## 快速导航

### 🏗️ 构建脚本
| 脚本 | 功能 | 文档 |
|------|------|------|
| `build.sh` | 主构建脚本 | [📖 手册](build/MANUAL-build.md) |
| `check-deps.sh` | 依赖检测脚本 | [📖 手册](build/MANUAL-check-deps.md) |
| `validate-build.sh` | 构建验证脚本 | [📖 手册](build/MANUAL-validate-build.md) |

### 🔧 CI/CD 脚本
| 脚本 | 功能 | 文档 |
|------|------|------|
| `view-build-status.sh` | 查看构建状态 | [📖 手册](ci/MANUAL-view-build-status.md) |
| `analyze-build-errors.sh` | 分析构建错误 | [📖 手册](ci/MANUAL-analyze-build-errors.md) |
| `root-cause-analysis.sh` | 根因分析 | [📖 手册](ci/MANUAL-root-cause-analysis.md) |
| `fix-verify-workflow.sh` | 修复验证流程 | [📖 手册](ci/MANUAL-fix-verify-workflow.md) |

### 🛠️ 工具脚本
| 脚本 | 功能 | 文档 |
|------|------|------|
| `env-check.sh` | 环境检查工具 | [📖 手册](utils/MANUAL-env-check.md) |

---

## 目录结构

```
scripts/
├── INDEX.md                          # 脚本索引（本文件）
├── README.md                         # 脚本体系总览
├── BUILD_SCRIPT_STYLE_GUIDE.md       # 编码风格指南
├── TROUBLESHOOTING.md                # 故障排除指南
├── build/                            # 构建脚本
│   ├── build.sh                      # 主构建脚本
│   ├── check-deps.sh                 # 依赖检测
│   ├── validate-build.sh             # 构建验证
│   └── docs/                         # 构建脚本文档
│       ├── MANUAL-build.md
│       ├── MANUAL-check-deps.md
│       └── MANUAL-validate-build.md
├── ci/                               # CI/CD 脚本
│   ├── view-build-status.sh          # 查看构建状态
│   ├── analyze-build-errors.sh       # 分析错误
│   ├── root-cause-analysis.sh        # 根因分析
│   ├── fix-verify-workflow.sh        # 修复验证
│   └── docs/                         # CI/CD 脚本文档
│       ├── MANUAL-view-build-status.md
│       ├── MANUAL-analyze-build-errors.md
│       ├── MANUAL-root-cause-analysis.md
│       └── MANUAL-fix-verify-workflow.md
└── utils/                            # 工具脚本
    ├── env-check.sh                  # 环境检查
    └── docs/                         # 工具脚本文档
        └── MANUAL-env-check.md
```

---

## 使用流程

### 开发人员工作流

```
1. 检查依赖
   └── ./scripts/build/check-deps.sh

2. 执行构建
   └── ./scripts/build/build.sh -r

3. 验证构建产物
   └── ./scripts/build/validate-build.sh

4. 提交代码
   └── git push

5. 查看构建状态
   └── ./scripts/ci/view-build-status.sh

6. 如果构建失败
   ├── ./scripts/ci/analyze-build-errors.sh
   ├── ./scripts/ci/root-cause-analysis.sh
   └── ./scripts/ci/fix-verify-workflow.sh
```

---

## 文档格式规范

所有脚本使用手册遵循统一的格式：

1. **概述** - 脚本功能简介
2. **适用场景** - 使用场景说明
3. **前置条件** - 使用前需要满足的条件
4. **安装步骤** - 安装和配置方法
5. **参数说明** - 命令行参数详解
6. **使用示例** - 实际使用示例
7. **常见问题** - 常见问题及解决方法
8. **更新日志** - 版本更新记录

---

## 文档维护

### 添加新脚本

1. 将脚本文件放入相应的目录（build/, ci/, utils/）
2. 在 `INDEX.md` 中添加条目
3. 编写对应的使用手册
4. 更新 `README.md`

### 更新文档

1. 保持文档与脚本同步
2. 使用统一的格式风格
3. 更新版本号和更新日志

---

## 版本信息

| 版本 | 日期 | 说明 |
|------|------|------|
| v1.0.0 | 2024-01-01 | 初始版本 |