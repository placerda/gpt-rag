# scripts/search/setup.ps1
# requires PowerShell 5.1+
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$venvPath = Join-Path $PSScriptRoot '.venv_temp'

# 0) Clean up any half-baked venv
if (Test-Path $venvPath) {
    Write-Host "🧹 Removing leftover venv…"
    Remove-Item -Recurse -Force $venvPath
}

Write-Host "📦 Creating temporary venv…"
& python -m venv $venvPath 2>&1 | ForEach-Object { Write-Host $_ }
if ($LASTEXITCODE -ne 0) {
    Write-Warning "'python -m venv' failed, retrying with 'py -3 -m venv'…"
    & py -3 -m venv $venvPath 2>&1 | ForEach-Object { Write-Host $_ }
    if ($LASTEXITCODE -ne 0) {
        throw "❗️ Could not create virtual environment (exit code $LASTEXITCODE)"
    }
}

Write-Host "🟢 Activating venv…"
& "$venvPath\Scripts\Activate.ps1"

Write-Host "⬇️  Installing requirements…"
# Use python -m pip so pip upgrades/install inside the venv correctly
& python -m pip install --upgrade pip 2>&1 | ForEach-Object { Write-Host $_ }
& python -m pip install -r "$PSScriptRoot\requirements.txt" 2>&1 | ForEach-Object { Write-Host $_ }

Write-Host "🚀 Running setup.py…"
$raw = & python -m scripts.search.setup 2>&1
$raw -split "`r?`n" | ForEach-Object { if ($_ -match '\S') { Write-Host $_ } }

if ($LASTEXITCODE -ne 0) {
    throw "❗️ [Search Setup] 'setup.py' exited with code $LASTEXITCODE"
}

Write-Host "🧹 Cleaning up…"
if (Get-Command Deactivate -ErrorAction SilentlyContinue) { Deactivate }
Remove-Item -Recurse -Force $venvPath

Write-Host "✅ Search setup script finished."
