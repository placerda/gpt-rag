# loadEnvAndWarn.ps1
# PowerShell version of the shell script for loading env vars and displaying a network isolation warning

<#
.SYNOPSIS
    Load environment variables from App Configuration and warn if network isolation is enabled.
#>

# 1) Load Environment Variables from Previous Deployment (if available)
Write-Host "`n📑 Loading environment variables from previous deployment (if available)…"

if (-not $env:AZURE_APP_CONFIG_ENDPOINT) {
    Write-Host "⚠️  Skipping: AZURE_APP_CONFIG_ENDPOINT is not set."
} else {
    Write-Host "📦 Creating temporary virtual environment…"
    python -m venv scripts/appconfig/.venv_temp
    & "scripts/appconfig/.venv_temp/Scripts/Activate.ps1"

    Write-Host "⬇️  Installing requirements…"
    pip install --upgrade pip
    pip install -r scripts/appconfig/requirements.txt

    Write-Host "🚀 Running loadconfig.py…"
    python -m scripts.appconfig.loadconfig

    Write-Host "🧹 Cleaning up…"
    & "scripts/appconfig/.venv_temp/Scripts/Deactivate.ps1"
    Remove-Item -Recurse -Force scripts/appconfig/.venv_temp

    Write-Host "✅ Environment variables loaded from App Configuration."
}

# 2) Network Isolation Warning
function Test-IsTruthy {
    param([string]$v)
    if ([string]::IsNullOrEmpty($v)) { return $false }
    $intVal = 0
    if ([int]::TryParse($v, [ref]$intVal) -and $intVal -ge 1) { return $true }
    if ($v -match '^(?i)(true|t)$') { return $true }
    return $false
}

# Skip warning if AZURE_SKIP_NETWORK_ISOLATION_WARNING is set
if (Test-IsTruthy $env:AZURE_SKIP_NETWORK_ISOLATION_WARNING) {
    exit 0
}

# Show warning if AZURE_NETWORK_ISOLATION is enabled
if (Test-IsTruthy $env:AZURE_NETWORK_ISOLATION) {
    Write-Host "Warning! AZURE_NETWORK_ISOLATION is enabled." -ForegroundColor Yellow
    Write-Host " - After provisioning, you must switch to the Virtual Machine & Bastion to continue deploying components." -ForegroundColor Green
    Write-Host " - Infrastructure will only be reachable from within the Bastion host."

    $confirmation = Read-Host -Prompt "? Continue with Zero Trust provisioning? [Y/n]"
    if ($confirmation -and $confirmation -notmatch '^(?i)(y)$') {
        exit 1
    }
}

exit 0
