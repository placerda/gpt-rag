#!/usr/bin/env pwsh
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ── Default environment variables ────────────────────────────────────────────
if (-not $env:AZURE_INSTALL_AOAI)            { $env:AZURE_INSTALL_AOAI            = 'false' }
if (-not $env:AZURE_INSTALL_SEARCH_SERVICE)  { $env:AZURE_INSTALL_SEARCH_SERVICE  = 'false' }
if (-not $env:AZURE_INSTALL_AI_FOUNDRY)      { $env:AZURE_INSTALL_AI_FOUNDRY      = 'false' }
if (-not $env:AZURE_CONFIGURE_RBAC)         { $env:AZURE_CONFIGURE_RBAC         = 'false' }
if (-not $env:AZURE_NETWORK_ISOLATION)      { $env:AZURE_NETWORK_ISOLATION      = 'false' }
if (-not $env:AZURE_INSTALL_CONTAINER_APPS) { $env:AZURE_INSTALL_CONTAINER_APPS = 'false' }

Write-Host "🔧 Running post-provision steps…`n"

# ── Show current flags ───────────────────────────────────────────────────────
Write-Host "📋 Current environment variables:"
foreach ($v in 'AZURE_INSTALL_AOAI','AZURE_INSTALL_SEARCH_SERVICE','AZURE_INSTALL_AI_FOUNDRY','AZURE_CONFIGURE_RBAC','AZURE_NETWORK_ISOLATION','AZURE_INSTALL_CONTAINER_APPS') {
    $val = [Environment]::GetEnvironmentVariable($v)
    if (-not $val) { $val = '<unset>' }
    Write-Host "  $v=$val"
}

# ── Setup Python virtual environment ─────────────────────────────────────────
Write-Host "`n📦 Creating temporary venv…"
python -m venv config/.venv_temp

# Activate the venv (cross-platform)
$activateScript = if (Test-Path 'config/.venv_temp/Scripts/Activate.ps1') {
    'config/.venv_temp/Scripts/Activate.ps1'
} elseif (Test-Path 'config/.venv_temp/bin/activate') {
    'config/.venv_temp/bin/activate'
} else {
    $null
}
if ($activateScript) {
    . $activateScript
} else {
    Write-Warning "Could not find venv activation script."
}

Write-Host "⬇️  Installing requirements…"
pip install --upgrade pip
pip install -r config/requirements.txt

# ── 1) App Configuration Setup ───────────────────────────────────────────────
Write-Host "`n📑 Seeding App Configuration…"
try {
    Write-Host "🚀 Running config.appconfig.seed_config…"
    python -m config.appconfig.seed_config
    Write-Host "✅ App Configuration script finished."
} catch {
    Write-Warning "❗️ Error during App Configuration Setup. Skipping it."
}

# ── 2) RBAC Setup ────────────────────────────────────────────────────────────
Write-Host ""
if ($env:AZURE_CONFIGURE_RBAC.ToLower() -eq 'true') {
    Write-Host "📑 RBAC Setup…"
    try {
        Write-Host "🚀 Running config.rbac.rbac_setup…"
        python -m config.rbac.rbac_setup
        Write-Host "✅ RBAC setup script finished."
    } catch {
        Write-Warning "❗️ Error during RBAC setup. Skipping it."
    }
} else {
    Write-Warning "⚠️  Skipping RBAC setup (AZURE_CONFIGURE_RBAC is not 'true')."
}

# ── 3) AOAI Setup ────────────────────────────────────────────────────────────
Write-Host ""
if ($env:AZURE_INSTALL_AOAI.ToLower() -eq 'true') {
    Write-Host "📑 AOAI Setup…"
    try {
        Write-Host "🚀 Running config.aoai.raipolicies…"
        python -m config.aoai.raipolicies
        Write-Host "✅ AOAI setup script finished."
    } catch {
        Write-Warning "❗️ Error during AOAI setup. Skipping it."
    }
} else {
    Write-Warning "⚠️  Skipping AOAI setup (AZURE_INSTALL_AOAI is not 'true')."
}

# ── 4) AI Foundry Setup ───────────────────────────────────────────────────────
Write-Host ""
if ($env:AZURE_INSTALL_AI_FOUNDRY.ToLower() -eq 'true') {
    Write-Host "📑 AI Foundry Setup…"
    try {
        Write-Host "🚀 Running config.aifoundry.aifoundry_setup…"
        python -m config.aifoundry.aifoundry_setup
        Write-Host "✅ AI Foundry setup script finished."
    } catch {
        Write-Warning "❗️ Error during AI Foundry setup. Skipping it."
    }
} else {
    Write-Warning "⚠️  Skipping AI Foundry setup (AZURE_INSTALL_AI_FOUNDRY is not 'true')."
}

# ── 5) AI Search Setup ────────────────────────────────────────────────────────
Write-Host ""
if ($env:AZURE_INSTALL_SEARCH_SERVICE.ToLower() -eq 'true') {
    Write-Host "🔍 AI Search setup…"
    try {
        Write-Host "🚀 Running config.search.search_setup…"
        python -m config.search.search_setup
        Write-Host "✅ Search setup script finished."
    } catch {
        Write-Warning "❗️ Error during Search setup. Skipping it."
    }
} else {
    Write-Warning "⚠️  Skipping AI Search setup (AZURE_INSTALL_SEARCH_SERVICE is not 'true')."
}

# ── 6) Container Apps Setup ──────────────────────────────────────────────────
Write-Host ""
if ($env:AZURE_INSTALL_CONTAINER_APPS.ToLower() -eq 'true') {
    Write-Host "🔍 Container Apps setup…"
    try {
        Write-Host "🚀 Running config.containerapps.capp_setup…"
        python -m config.containerapps.capp_setup
        Write-Host "✅ Container Apps setup script finished."
    } catch {
        Write-Warning "❗️ Error during Container Apps setup. Skipping it."
    }
} else {
    Write-Warning "⚠️  Skipping Container Apps setup (AZURE_INSTALL_CONTAINER_APPS is not 'true')."
}

# ── 7) Zero Trust Information ─────────────────────────────────────────────────
Write-Host ""
if ($env:AZURE_NETWORK_ISOLATION.ToLower() -eq 'true') {
    Write-Host "🔒 Access the Zero Trust bastion:"
    Write-Host "  VM: $env:AZURE_VM_NAME"
    Write-Host "  User: $env:AZURE_VM_USER_NAME"
    Write-Host "  Credentials: $env:AZURE_BASTION_KV_NAME/$env:AZURE_VM_KV_SEC_NAME"
} else {
    Write-Host "🚧 Zero Trust not enabled; provisioning Standard architecture."
}

Write-Host "`n✅ postProvisioning completed.`n"

# ── Cleaning up ───────────────────────────────────────────────────────────────
Write-Host "🧹 Cleaning Python environment up…"
try { deactivate } catch {}
Remove-Item -Recurse -Force config/.venv_temp
