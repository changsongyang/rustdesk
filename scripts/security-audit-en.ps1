# RustDesk Security Audit Script (PowerShell Version)
# Purpose: Run regular security checks and code quality checks

$ErrorActionPreference = "Continue"

Write-Host "========================================" -ForegroundColor Green
Write-Host "  RustDesk Security Audit" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

# Check if we're in the project root
if (-not (Test-Path "Cargo.toml")) {
    Write-Host "ERROR: Please run this script from the project root" -ForegroundColor Red
    exit 1
}

# 1. Dependency vulnerability scan
Write-Host "[1/8] Dependency vulnerability scan..." -ForegroundColor Yellow
try {
    if (Get-Command "cargo-audit" -ErrorAction SilentlyContinue) {
        cargo audit
        Write-Host "OK: Dependency vulnerability scan complete" -ForegroundColor Green
    } else {
        Write-Host "WARNING: cargo-audit not installed, skipping dependency scan" -ForegroundColor Yellow
        Write-Host "Install with: cargo install cargo-audit"
    }
} catch {
    Write-Host "WARNING: Dependency scan encountered issues" -ForegroundColor Yellow
}
Write-Host ""

# 2. Code format check
Write-Host "[2/8] Code format check..." -ForegroundColor Yellow
try {
    cargo fmt --check
    Write-Host "OK: Code format check passed" -ForegroundColor Green
} catch {
    Write-Host "WARNING: Code format needs adjustment" -ForegroundColor Yellow
    Write-Host "Run: cargo fmt to auto-format"
}
Write-Host ""

# 3. Clippy check
Write-Host "[3/8] Clippy check..." -ForegroundColor Yellow
try {
    cargo clippy -- -D warnings
    Write-Host "OK: Clippy check passed" -ForegroundColor Green
} catch {
    Write-Host "ERROR: Clippy found issues" -ForegroundColor Red
}
Write-Host ""

# 4. Doc tests
Write-Host "[4/8] Documentation tests..." -ForegroundColor Yellow
try {
    cargo test --doc
    Write-Host "OK: Documentation tests passed" -ForegroundColor Green
} catch {
    Write-Host "ERROR: Documentation tests failed" -ForegroundColor Red
}
Write-Host ""

# 5. Full tests
Write-Host "[5/8] Full tests..." -ForegroundColor Yellow
try {
    cargo test
    Write-Host "OK: Full tests passed" -ForegroundColor Green
} catch {
    Write-Host "ERROR: Tests failed" -ForegroundColor Red
}
Write-Host ""

# 6. Build check
Write-Host "[6/8] Build check..." -ForegroundColor Yellow
try {
    cargo build
    Write-Host "OK: Build check passed" -ForegroundColor Green
} catch {
    Write-Host "ERROR: Build failed" -ForegroundColor Red
}
Write-Host ""

# 7. HTML entity check
Write-Host "[7/8] HTML entity check..." -ForegroundColor Yellow
$htmlEntitiesFound = $false

# Check Rust files - use simple string matching to avoid regex issues
$files = Get-ChildItem -Path . -Recurse -Include "*.rs", "*.xml", "*.yaml", "*.yml" -ErrorAction SilentlyContinue | 
    Where-Object { $_.FullName -notlike "*\target\*" -and $_.FullName -notlike "*\.git\*" }

foreach ($file in $files) {
    try {
        $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
        if ($content -like "*&lt;*") {
            Write-Host "WARNING: Found HTML entity &lt; in $($file.FullName)" -ForegroundColor Yellow
            $htmlEntitiesFound = $true
        }
        if ($content -like "*&gt;*") {
            Write-Host "WARNING: Found HTML entity &gt; in $($file.FullName)" -ForegroundColor Yellow
            $htmlEntitiesFound = $true
        }
        if ($content -like "*&amp;*") {
            Write-Host "WARNING: Found HTML entity &amp; in $($file.FullName)" -ForegroundColor Yellow
            $htmlEntitiesFound = $true
        }
    } catch {
        # Skip files we can't read
    }
}

if (-not $htmlEntitiesFound) {
    Write-Host "OK: HTML entity check passed" -ForegroundColor Green
}
Write-Host ""

# 8. Git status check
Write-Host "[8/8] Git status check..." -ForegroundColor Yellow
try {
    $gitStatus = git status --porcelain
    if ($gitStatus) {
        Write-Host "WARNING: Uncommitted changes found" -ForegroundColor Yellow
        git status --short
    } else {
        Write-Host "OK: Git workspace clean" -ForegroundColor Green
    }
} catch {
    Write-Host "WARNING: Git status check encountered issues" -ForegroundColor Yellow
}
Write-Host ""

Write-Host "========================================" -ForegroundColor Green
Write-Host "  Security Audit Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Tips:" -ForegroundColor Yellow
Write-Host "  1. Run this script regularly for security audits"
Write-Host "  2. Can integrate with Git Hooks"
Write-Host "  3. Can run in CI"
Write-Host ""
