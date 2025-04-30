#!/usr/bin/env pwsh
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Write-Host "🔧 Running post-provision steps…"

# Temporarily exit to avoid running the script
exit 0

# 1) RAI policies (only if AZURE_REUSE_AOAI is not "true" and AZURE_CONFIGURE_RAI_POLICIES is "true")
if ((-not ($Env:AZURE_REUSE_AOAI -and $Env:AZURE_REUSE_AOAI.ToLower() -eq 'true')) -and 
    ($Env:AZURE_CONFIGURE_RAI_POLICIES -and $Env:AZURE_CONFIGURE_RAI_POLICIES.ToLower() -eq 'true')) {
    Write-Host "📑 Applying RAI policies…"
    & "$PSScriptRoot\scripts\rai\raipolicies.ps1" 
}
else {
    Write-Host "⚠️  Skipping RAI policies (AZURE_REUSE_AOAI is 'true' or AZURE_CONFIGURE_RAI_POLICIES is not 'true')."
}

# 2) App Configuration (only if CONFIGURE_RBAC is "true")
if ($Env:CONFIGURE_RBAC -and $Env:CONFIGURE_RBAC.ToLower() -eq 'true') {
    Write-Host "📑 Seeding App Configuration…"
    & "$PSScriptRoot\scripts\appconfig\appconfig.ps1"
}
else {
    Write-Host "⚠️  Skipping App Configuration (CONFIGURE_RBAC is not 'true')."
}

# 3) AI Search Setup (always run)
Write-Host "AI Search setup…"
& "$PSScriptRoot\scripts\search\setup.ps1" 

# 4) Zero Trust bastion info (if NETWORK_ISOLATION is "true")
if ($Env:NETWORK_ISOLATION -and $Env:NETWORK_ISOLATION.ToLower() -eq 'true') {
    Write-Host ''
    Write-Host "🔒 Access the Zero Trust bastion:"
    Write-Host "  VM:          $($Env:AZURE_VM_NAME)"
    Write-Host "  User:        $($Env:AZURE_VM_USER_NAME)"
    Write-Host "  Credentials: $($Env:AZURE_BASTION_KV_NAME)/$($Env:AZURE_VM_KV_SEC_NAME)"
}

Write-Host "✅ postProvisioning completed."
