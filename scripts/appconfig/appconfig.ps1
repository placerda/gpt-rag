#!/usr/bin/env pwsh
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory=$true)]
    [string]$DeploymentName,

    [Parameter(Mandatory=$true)]
    [string]$StoreName
)

Write-Host "⏳ Waiting for RBAC on '$StoreName'…"
while (-not (az appconfig kv list `
    --name $StoreName `
    --resource-group $ResourceGroupName `
    --top 1 2>$null)) {
    Write-Host "   …waiting 10s"
    Start-Sleep -Seconds 10
}
Write-Host "✅ RBAC effective."

Write-Host "📥 Fetching key/value map from deployment '$DeploymentName'…"
$kvsJson = az deployment group show `
    --resource-group $ResourceGroupName `
    --name $DeploymentName `
    --query "properties.outputs.appConfigKVs.value" `
    -o json

# Parse into a PSCustomObject
$kvs = $kvsJson | ConvertFrom-Json
$entryCount = ($kvs.PSObject.Properties).Count
Write-Host "➕ Seeding $entryCount entries…"

foreach ($prop in $kvs.PSObject.Properties) {
    $key   = $prop.Name
    $value = $prop.Value
    Write-Host "  • $key = $value"
    az appconfig kv set `
        --name $StoreName `
        --resource-group $ResourceGroupName `
        --key $key `
        --value $value `
        --yes
}

Write-Host "🎉 App Configuration seeded."
