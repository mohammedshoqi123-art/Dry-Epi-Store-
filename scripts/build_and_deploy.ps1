#!/usr/bin/env pwsh
# ============================================================
# EPI Supervisor Platform — Build & Deploy Script (PowerShell)
# ============================================================
# Usage: .\scripts\build_and_deploy.ps1 [--apk] [--web] [--all]
# ============================================================

param(
    [switch]$apk,
    [switch]$web,
    [switch]$all,
    [switch]$clean,
    [string]$supabaseUrl = $env:SUPABASE_URL,
    [string]$supabaseAnonKey = $env:SUPABASE_ANON_KEY,
    [string]$geminiApiKey = $env:GEMINI_API_KEY,
    [string]$sentryDsn = $env:SENTRY_DSN
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$mobileDir = Join-Path $projectRoot "apps\mobile"
$webDir = Join-Path $projectRoot "apps\web"
$outputDir = Join-Path $projectRoot "build\outputs"

# Colors
function Write-Step($msg) { Write-Host "`n▶ $msg" -ForegroundColor Cyan }
function Write-OK($msg)   { Write-Host "  ✔ $msg" -ForegroundColor Green }
function Write-ERR($msg)  { Write-Host "  ✘ $msg" -ForegroundColor Red }
function Write-Warn($msg) { Write-Host "  ⚠ $msg" -ForegroundColor Yellow }

Write-Host @"

╔══════════════════════════════════════════════════════════╗
║        EPI Supervisor Platform — Build System            ║
║        Version: 1.0.0 | $(Get-Date -Format 'yyyy-MM-dd HH:mm')             ║
╚══════════════════════════════════════════════════════════╝
"@ -ForegroundColor Teal

# Validate environment
Write-Step "Validating environment..."
if (-not $supabaseUrl -or $supabaseUrl -eq "https://your-project.supabase.co") {
    Write-ERR "SUPABASE_URL is not set. Please set the environment variable or pass --supabaseUrl"
    exit 1
}
if (-not $supabaseAnonKey -or $supabaseAnonKey -eq "your-anon-key") {
    Write-ERR "SUPABASE_ANON_KEY is not set."
    exit 1
}
Write-OK "Environment variables validated"

# Create output directory
New-Item -ItemType Directory -Force -Path $outputDir | Out-Null

# Dart defines for build
$dartDefines = @(
    "--dart-define=SUPABASE_URL=$supabaseUrl",
    "--dart-define=SUPABASE_ANON_KEY=$supabaseAnonKey"
)
if ($geminiApiKey) { $dartDefines += "--dart-define=GEMINI_API_KEY=$geminiApiKey" }
if ($sentryDsn)    { $dartDefines += "--dart-define=SENTRY_DSN=$sentryDsn" }

# ─── Get dependencies ─────────────────────────────────────────────────────────
Write-Step "Getting Flutter dependencies..."

foreach ($pkg in @("packages\core", "packages\shared", "apps\mobile")) {
    $pkgPath = Join-Path $projectRoot $pkg
    Write-Host "  → $pkg" -ForegroundColor Gray
    Push-Location $pkgPath
    flutter pub get --no-example 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { Write-ERR "pub get failed for $pkg"; exit 1 }
    Pop-Location
}
Write-OK "Dependencies resolved"

# ─── Clean ────────────────────────────────────────────────────────────────────
if ($clean) {
    Write-Step "Cleaning build artifacts..."
    Push-Location $mobileDir
    flutter clean 2>&1 | Out-Null
    Pop-Location
    Write-OK "Clean complete"
}

# ─── Build APK ────────────────────────────────────────────────────────────────
if ($apk -or $all) {
    Write-Step "Building Android APK (Release)..."
    Push-Location $mobileDir

    $buildCmd = @("flutter", "build", "apk", "--release", "--no-shrink") + $dartDefines
    & $buildCmd[0] $buildCmd[1..($buildCmd.Length-1)]

    if ($LASTEXITCODE -ne 0) {
        Write-ERR "APK build failed!"
        Pop-Location
        exit 1
    }

    # Copy APK to output
    $apkSrc = Join-Path $mobileDir "build\app\outputs\flutter-apk\app-release.apk"
    $apkDst = Join-Path $outputDir "epi-supervisor-v1.0.0.apk"
    Copy-Item -Path $apkSrc -Destination $apkDst -Force
    Pop-Location

    Write-OK "APK built: $apkDst"
    $apkSize = [math]::Round((Get-Item $apkDst).Length / 1MB, 1)
    Write-Host "  Size: ${apkSize}MB" -ForegroundColor Gray
}

# ─── Build Web ────────────────────────────────────────────────────────────────
if ($web -or $all) {
    Write-Step "Building Flutter Web (Release)..."
    Push-Location $mobileDir

    $webBuildCmd = @("flutter", "build", "web", "--release", "--base-href=/") + $dartDefines
    & $webBuildCmd[0] $webBuildCmd[1..($webBuildCmd.Length-1)]

    if ($LASTEXITCODE -ne 0) {
        Write-ERR "Web build failed!"
        Pop-Location
        exit 1
    }

    # Copy web output
    $webSrc = Join-Path $mobileDir "build\web"
    $webDst = Join-Path $outputDir "web"
    if (Test-Path $webDst) { Remove-Item $webDst -Recurse -Force }
    Copy-Item -Path $webSrc -Destination $webDst -Recurse
    Pop-Location

    Write-OK "Web build complete: $webDst"
}

# ─── Summary ──────────────────────────────────────────────────────────────────
Write-Host "`n" -NoNewline
Write-Host "═══════════════════════════════════════════" -ForegroundColor Green
Write-Host "  BUILD COMPLETE ✔" -ForegroundColor Green
Write-Host "═══════════════════════════════════════════" -ForegroundColor Green
Write-Host "  Outputs: $outputDir" -ForegroundColor White

if ($apk -or $all) {
    Write-Host "  APK:  epi-supervisor-v1.0.0.apk" -ForegroundColor White
}
if ($web -or $all) {
    Write-Host "  Web:  web\" -ForegroundColor White
    Write-Host ""
    Write-Host "  To deploy web to Vercel:" -ForegroundColor Yellow
    Write-Host "    vercel deploy $outputDir\web --prod" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  To serve locally:" -ForegroundColor Yellow
    Write-Host "    cd $outputDir\web && python -m http.server 8080" -ForegroundColor Gray
}
