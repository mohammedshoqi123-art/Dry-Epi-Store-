#!/usr/bin/env pwsh
# ============================================================
# EPI Supervisor Platform — Supabase Setup Script
# ============================================================
# Prerequisites:
#   - Supabase CLI installed: npm install -g supabase
#   - supabase login completed
#   - SUPABASE_PROJECT_REF set
# ============================================================

param(
    [string]$projectRef = $env:SUPABASE_PROJECT_REF,
    [string]$serviceRoleKey = $env:SUPABASE_SERVICE_ROLE_KEY,
    [string]$supabaseUrl = $env:SUPABASE_URL,
    [string]$adminEmail = "admin@epi.local",
    [string]$adminPassword = "Admin@123",
    [string]$adminName = "مدير النظام",
    [switch]$skipMigrations,
    [switch]$skipAdmin,
    [switch]$skipFunctions,
    [switch]$skipSeed
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot

function Write-Step($msg) { Write-Host "`n▶ $msg" -ForegroundColor Cyan }
function Write-OK($msg)   { Write-Host "  ✔ $msg" -ForegroundColor Green }
function Write-ERR($msg)  { Write-Host "  ✘ $msg" -ForegroundColor Red }

Write-Host @"

╔══════════════════════════════════════════════════════════╗
║       EPI Supervisor — Supabase Setup                    ║
╚══════════════════════════════════════════════════════════╝
"@ -ForegroundColor Cyan

# ─── 1. Check Supabase CLI ────────────────────────────────────────────────────
Write-Step "Checking Supabase CLI..."
$supabaseVersion = supabase --version 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-ERR "Supabase CLI not found. Install with: npm install -g supabase"
    exit 1
}
Write-OK "Supabase CLI: $supabaseVersion"

# ─── 2. Run Migrations ────────────────────────────────────────────────────────
if (-not $skipMigrations) {
    Write-Step "Running database migrations..."
    
    if ($projectRef) {
        # Remote deployment
        supabase db push --project-ref $projectRef
    } else {
        # Local dev
        supabase db reset
    }
    
    if ($LASTEXITCODE -ne 0) { Write-ERR "Migration failed!"; exit 1 }
    Write-OK "Migrations applied"
}

# ─── 3. Seed Data ─────────────────────────────────────────────────────────────
if (-not $skipSeed) {
    Write-Step "Seeding initial data (governorates + sample form)..."
    
    $seedFile = Join-Path $projectRoot "supabase\migrations\002_seed_data.sql"
    
    if ($projectRef -and $serviceRoleKey) {
        # Use psql via Supabase
        supabase db execute --project-ref $projectRef --file $seedFile 2>&1
    } else {
        supabase db execute --local --file $seedFile 2>&1
    }
    
    Write-OK "Seed data inserted (19 Iraqi governorates)"
}

# ─── 4. Deploy Edge Functions ─────────────────────────────────────────────────
if (-not $skipFunctions) {
    Write-Step "Deploying Edge Functions..."
    $functions = @("create-admin", "submit-form", "get-analytics", "ai-chat", "sync-offline")
    
    foreach ($fn in $functions) {
        Write-Host "  → Deploying $fn..." -ForegroundColor Gray
        if ($projectRef) {
            supabase functions deploy $fn --project-ref $projectRef --no-verify-jwt 2>&1
        } else {
            supabase functions serve $fn 2>&1 | Out-Null
        }
        Write-OK "$fn deployed"
    }
}

# ─── 5. Create Admin User ─────────────────────────────────────────────────────
if (-not $skipAdmin) {
    Write-Step "Creating admin user..."
    Write-Host "  Email: $adminEmail" -ForegroundColor Gray
    Write-Host "  Name:  $adminName" -ForegroundColor Gray

    if (-not $supabaseUrl -or -not $serviceRoleKey) {
        Write-Warn "SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY not set — skipping admin creation"
        Write-Host "  Run manually via Edge Function:" -ForegroundColor Yellow
        Write-Host "  POST $supabaseUrl/functions/v1/create-admin" -ForegroundColor Gray
        Write-Host "  Body: {`"email`": `"$adminEmail`", `"password`": `"$adminPassword`", `"full_name`": `"$adminName`", `"role`": `"admin`"}" -ForegroundColor Gray
    } else {
        $body = @{
            email     = $adminEmail
            password  = $adminPassword
            full_name = $adminName
            role      = "admin"
        } | ConvertTo-Json

        $response = Invoke-RestMethod `
            -Uri "$supabaseUrl/functions/v1/create-admin" `
            -Method POST `
            -Body $body `
            -ContentType "application/json" `
            -Headers @{ "Authorization" = "Bearer $serviceRoleKey" }

        if ($response.success) {
            Write-OK "Admin user created: $adminEmail"
        } else {
            Write-Warn "Admin creation response: $($response | ConvertTo-Json)"
        }
    }
}

# ─── Summary ──────────────────────────────────────────────────────────────────
Write-Host "`n" -NoNewline
Write-Host "═══════════════════════════════════════════════" -ForegroundColor Green
Write-Host "  SUPABASE SETUP COMPLETE ✔" -ForegroundColor Green
Write-Host "═══════════════════════════════════════════════" -ForegroundColor Green
Write-Host ""
Write-Host "  Admin Login:" -ForegroundColor White
Write-Host "    Email:    $adminEmail" -ForegroundColor Yellow
Write-Host "    Password: $adminPassword" -ForegroundColor Yellow
Write-Host ""
Write-Host "  ⚠  Change the admin password after first login!" -ForegroundColor Red
Write-Host ""
