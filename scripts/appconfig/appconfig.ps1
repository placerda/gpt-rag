#!/usr/bin/env pwsh
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# 1) Create and activate venv
Write-Host "📦 Creating temporary venv…"
python -m venv .venv_temp

Write-Host "🔓 Activating venv…"
. "scripts/appconfig/.venv_temp/Scripts/Activate.ps1"

# 2) Install dependencies
Write-Host "⬇️  Installing requirements…"
python -m pip install --upgrade pip
python -m pip install -r "scripts/appconfig/requirements.txt"

# 3) Run the Python seeder
Write-Host "🚀 Running appconfig.py…"
python -m scripts.appconfig.appconfig

# 4) Deactivate and clean up
Write-Host "🧹 Deactivating venv…"
deactivate

Write-Host "🧹 Removing temporary venv…"
Remove-Item -Recurse -Force "scripts/appconfig/.venv_temp"

Write-Host "✅ App Configuration setup complete."
