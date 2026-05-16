# verify.ps1
Set-Location "C:\Users\ycsit\Downloads\rustdesk\rustdesk"

Write-Host "=== 1. 版本号检查 ===" -ForegroundColor Cyan
Write-Host "Cargo.toml:"
Select-String -Path "Cargo.toml" -Pattern "^version"
Write-Host "`nsrc/version.rs:"
Get-Content "src/version.rs"
Write-Host "`nflutter/pubspec.yaml:"
Select-String -Path "flutter/pubspec.yaml" -Pattern "^version"

Write-Host "`n=== 2. 编译 hbb_common ===" -ForegroundColor Cyan
cargo build -p hbb_common
if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ 编译成功" -ForegroundColor Green
} else {
    Write-Host "❌ 编译失败" -ForegroundColor Red
}

Write-Host "`n=== 3. Clippy 检查 ===" -ForegroundColor Cyan
cargo clippy -p hbb_common -- -D warnings
if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Clippy 检查通过" -ForegroundColor Green
} else {
    Write-Host "❌ Clippy 检查失败" -ForegroundColor Red
}