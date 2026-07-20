# build_release.ps1 — Clean build + zip with version from pubspec.yaml
# Usage: .\scripts\build_release.ps1 [-c]
#   -c  Run flutter clean before build (not default)
# Output: dist/sublator-v0.0.1-20250115-1430.zip

param(
    [switch]$c
)

$ErrorActionPreference = "Stop"

# Read version from pubspec.yaml
$pubspec = Get-Content "pubspec.yaml" -Raw
if ($pubspec -match 'version:\s+(\d+\.\d+\.\d+)\+(\d+)') {
    $version = $Matches[1]
    $build = $Matches[2]
} else {
    Write-Error "Could not parse version from pubspec.yaml"
    exit 1
}

$name = "sublator-v$version"
$distDir = "dist"
$timestamp = (Get-Date).ToUniversalTime().AddHours(7).ToString("yyyyMMdd-HHmm")

Write-Host "Building $name (build $build)..." -ForegroundColor Cyan

# Cleanup build artifacts
Remove-Item $distDir -Recurse -Force -ErrorAction SilentlyContinue

# Optional flutter clean
if ($c) {
    Write-Host "Running flutter clean..." -ForegroundColor Yellow
    flutter clean 2>&1 | Out-Null
}

flutter pub get 2>&1 | Out-Null

# Build
flutter build windows --release 2>&1
if ($LASTEXITCODE -ne 0) { exit 1 }

# Bundle
$releaseDir = "build\windows\x64\runner\Release"
New-Item -ItemType Directory -Path $distDir -Force | Out-Null

Compress-Archive -Path "$releaseDir\*" -DestinationPath "$distDir\$name-windows-$timestamp.zip" -Force

$zip = Get-Item "$distDir\$name-windows-$timestamp.zip"
$sizeMB = [math]::Round($zip.Length / 1MB, 1)
Write-Host "`nDone: $($zip.FullName) ($sizeMB MB)" -ForegroundColor Green
