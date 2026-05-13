# RustDesk 安全审计脚本 (PowerShell 版本)
# 用途：定期运行安全检查和代码质量检查

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Green
Write-Host "  RustDesk 安全审计脚本" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

# 检查是否在项目根目录
if (-not (Test-Path "Cargo.toml")) {
    Write-Host "错误: 请在项目根目录运行此脚本" -ForegroundColor Red
    exit 1
}

# 1. 依赖漏洞扫描
Write-Host "[1/8] 依赖漏洞扫描..." -ForegroundColor Yellow
try {
    if (Get-Command "cargo-audit" -ErrorAction SilentlyContinue) {
        cargo audit
        Write-Host "✓ 依赖漏洞扫描完成" -ForegroundColor Green
    } else {
        Write-Host "警告: cargo-audit 未安装，跳过依赖漏洞扫描" -ForegroundColor Yellow
        Write-Host "安装命令: cargo install cargo-audit"
    }
} catch {
    Write-Host "依赖漏洞扫描遇到问题" -ForegroundColor Yellow
}
Write-Host ""

# 2. 代码格式检查
Write-Host "[2/8] 代码格式检查..." -ForegroundColor Yellow
try {
    cargo fmt --check
    Write-Host "✓ 代码格式检查通过" -ForegroundColor Green
} catch {
    Write-Host "警告: 代码格式需要调整" -ForegroundColor Yellow
    Write-Host "运行: cargo fmt 来自动格式化"
}
Write-Host ""

# 3. Clippy 检查
Write-Host "[3/8] Clippy 代码检查..." -ForegroundColor Yellow
try {
    cargo clippy -- -D warnings
    Write-Host "✓ Clippy 检查通过" -ForegroundColor Green
} catch {
    Write-Host "错误: Clippy 发现问题" -ForegroundColor Red
}
Write-Host ""

# 4. 文档测试
Write-Host "[4/8] 文档测试..." -ForegroundColor Yellow
try {
    cargo test --doc
    Write-Host "✓ 文档测试通过" -ForegroundColor Green
} catch {
    Write-Host "错误: 文档测试失败" -ForegroundColor Red
}
Write-Host ""

# 5. 完整测试
Write-Host "[5/8] 完整测试..." -ForegroundColor Yellow
try {
    cargo test
    Write-Host "✓ 完整测试通过" -ForegroundColor Green
} catch {
    Write-Host "错误: 测试失败" -ForegroundColor Red
}
Write-Host ""

# 6. 编译检查
Write-Host "[6/8] 编译检查..." -ForegroundColor Yellow
try {
    cargo build
    Write-Host "✓ 编译检查通过" -ForegroundColor Green
} catch {
    Write-Host "错误: 编译失败" -ForegroundColor Red
}
Write-Host ""

# 7. HTML 实体检查
Write-Host "[7/8] HTML 实体检查..." -ForegroundColor Yellow
$htmlEntitiesFound = $false

# 检查 Rust 文件
$files = Get-ChildItem -Path . -Recurse -Include "*.rs", "*.xml", "*.yaml", "*.yml" | 
    Where-Object { $_.FullName -notlike "*\target\*" -and $_.FullName -notlike "*\.git\*" }

foreach ($file in $files) {
    $content = Get-Content $file.FullName -Raw
    if ($content -match "&lt;") {
        Write-Host "警告: 在 $($file.FullName) 发现 HTML 实体编码 &lt;" -ForegroundColor Yellow
        $htmlEntitiesFound = $true
    }
    if ($content -match "&gt;") {
        Write-Host "警告: 在 $($file.FullName) 发现 HTML 实体编码 &gt;" -ForegroundColor Yellow
        $htmlEntitiesFound = $true
    }
    if ($content -match "&amp;") {
        Write-Host "警告: 在 $($file.FullName) 发现 HTML 实体编码 &amp;" -ForegroundColor Yellow
        $htmlEntitiesFound = $true
    }
}

if (-not $htmlEntitiesFound) {
    Write-Host "✓ HTML 实体检查通过" -ForegroundColor Green
}
Write-Host ""

# 8. Git 状态检查
Write-Host "[8/8] Git 状态检查..." -ForegroundColor Yellow
try {
    $gitStatus = git status --porcelain
    if ($gitStatus) {
        Write-Host "警告: 有未提交的变更" -ForegroundColor Yellow
        git status --short
    } else {
        Write-Host "✓ Git 工作区干净" -ForegroundColor Green
    }
} catch {
    Write-Host "Git 状态检查遇到问题" -ForegroundColor Yellow
}
Write-Host ""

Write-Host "========================================" -ForegroundColor Green
Write-Host "  安全审计完成！" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "提示:" -ForegroundColor Yellow
Write-Host "  1. 定期运行此脚本进行安全审计"
Write-Host "  2. 可以将此脚本集成到 Git Hooks"
Write-Host "  3. 可以在 CI 中运行此脚本"
Write-Host ""
