# scripts/hooks/postprovisioning.ps1
#!/usr/bin/env pwsh
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Write-Host "🔧 Running post-provision steps…"

# Base “scripts” folder (one level up from hooks)
$baseDir = Split-Path -Parent $PSScriptRoot

# 1) RAI policies
if ($Env:AZURE_REUSE_AOAI -and $Env:AZURE_REUSE_AOAI.ToLower() -ne 'true') {
    Write-Host "📑 Applying RAI policies…"
    try {
        & "$baseDir\rai\raipolicies.ps1" -Verbose
    }
    catch {
        Write-Host "❗️ Error applying RAI policies:"
        Write-Host "  Message: $($_.Exception.Message)"
        Write-Host "  Stack:   $($_.Exception.StackTrace)"
        Write-Warning "Continuing post-provisioning despite RAI errors…"
    }
}
else {
    Write-Host "⚠️  Skipping RAI policies (AZURE_REUSE_AOAI is either unset or 'true')."
}

# 2) App Configuration
if ($Env:CONFIGURE_RBAC -and $Env:CONFIGURE_RBAC.ToLower() -eq 'true') {
    Write-Host ""
    Write-Host "📑 Seeding App Configuration…"
    try {
        & "$baseDir\appconfig\appconfig.ps1" -Verbose
    }
    catch {
        Write-Host "❗️ Error seeding App Configuration:"
        Write-Host "  Message: $($_.Exception.Message)"
        Write-Host "  Stack:   $($_.Exception.StackTrace)"
        Write-Warning "Continuing post-provisioning despite AppConfig errors…"
    }
}
else {
    Write-Host ""
    Write-Host "⚠️  Skipping App Configuration (CONFIGURE_RBAC is not 'true')."
}

# 3) AI Search Setup
Write-Host ""
Write-Host "🔍 AI Search setup…"
try {
    & "$baseDir\search\setup.ps1" -Verbose
}
catch {
    Write-Host "❗️ Error setting up AI Search:"
    Write-Host "  Message: $($_.Exception.Message)"
    Write-Host "  Stack:   $($_.Exception.StackTrace)"
    Write-Warning "Continuing post-provisioning despite Search setup errors…"
}

# 4) Zero Trust bastion info
if ($Env:NETWORK_ISOLATION -and $Env:NETWORK_ISOLATION.ToLower() -eq 'true') {
    Write-Host ""
    Write-Host "🔒 Access the Zero Trust bastion:"
    Write-Host "  VM:          $($Env:AZURE_VM_NAME)"
    Write-Host "  User:        $($Env:AZURE_VM_USER_NAME)"
    Write-Host "  Credentials: $($Env:AZURE_BASTION_KV_NAME)/$($Env:AZURE_VM_KV_SEC_NAME)"
}
else {
    Write-Host ""
    Write-Host "🚧 Zero Trust not enabled; provisioning Standard architecture."
}

Write-Host ""
Write-Host "✅ postProvisioning completed."
