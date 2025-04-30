#!/usr/bin/env pwsh
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Write-Host "🔧 Running post-provision steps…"

# 1) RAI policies (only if AZURE_REUSE_AOAI is set and not "true")
Write-Host ""
if ($Env:AZURE_REUSE_AOAI -and $Env:AZURE_REUSE_AOAI.ToLower() -ne 'true') {
    Write-Host "📑 Applying RAI policies…"
    try {
        # pass Verbose so any Write-Verbose in raipolicies.ps1 is shown
        & "$PSScriptRoot\scripts\rai\raipolicies.ps1" -Verbose
    }
    catch {
        Write-Error "❗️ Error applying RAI policies:"
        Write-Error "  Message: $($_.Exception.Message)"
        Write-Error "  StackTrace: $($_.Exception.StackTrace)"
        Write-Error "  Full Error Record:`n$($_ | Out-String)"
        Write-Warning "Continuing post-provisioning despite RAI errors…"
    }
}
else {
    Write-Host "⚠️  Skipping RAI policies (AZURE_REUSE_AOAI is either unset or 'true')."
}

# 2) App Configuration (only if CONFIGURE_RBAC is "true")
Write-Host ""
if ($Env:CONFIGURE_RBAC -and $Env:CONFIGURE_RBAC.ToLower() -eq 'true') {
    Write-Host "📑 Seeding App Configuration…"
    try {
        & "$PSScriptRoot\scripts\appconfig\appconfig.ps1" -Verbose
    }
    catch {
        Write-Error "❗️ Error seeding App Configuration:"
        Write-Error "  Message: $($_.Exception.Message)"
        Write-Error "  StackTrace: $($_.Exception.StackTrace)"
        Write-Error "  Full Error Record:`n$($_ | Out-String)"
        Write-Warning "Continuing post-provisioning despite AppConfig errors…"
    }
}
else {
    Write-Host "⚠️  Skipping App Configuration (CONFIGURE_RBAC is not 'true')."
}

# 3) AI Search Setup (always run)
Write-Host ""
Write-Host "🔍 AI Search setup…"
try {
    & "$PSScriptRoot\scripts\search\setup.ps1" -Verbose
}
catch {
    Write-Error "❗️ Error setting up AI Search:"
    Write-Error "  Message: $($_.Exception.Message)"
    Write-Error "  StackTrace: $($_.Exception.StackTrace)"
    Write-Error "  Full Error Record:`n$($_ | Out-String)"
    Write-Warning "Continuing post-provisioning despite Search setup errors…"
}

# 4) Zero Trust bastion info …
Write-Host ""
if ($Env:NETWORK_ISOLATION -and $Env:NETWORK_ISOLATION.ToLower() -eq 'true') {
    Write-Host "🔒 Access the Zero Trust bastion:"
    Write-Host "  VM:          $($Env:AZURE_VM_NAME)"
    Write-Host "  User:        $($Env:AZURE_VM_USER_NAME)"
    Write-Host "  Credentials: $($Env:AZURE_BASTION_KV_NAME)/$($Env:AZURE_VM_KV_SEC_NAME)"
}
else {
    Write-Host "🚧 Zero Trust not enabled; provisioning Standard architecture."
}

Write-Host ""
Write-Host "✅ postProvisioning completed."
