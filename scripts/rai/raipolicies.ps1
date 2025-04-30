#!/usr/bin/env pwsh
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# 1) Create temporary venv
Write-Host "📦 Creating temporary venv…"
python -m venv "scripts/rai/.venv_temp"

# 2) Activate it
Write-Host "🔓 Activating venv…"
. "scripts/rai/.venv_temp/Scripts/Activate.ps1"

# 3) Install requirements
Write-Host "⬇️  Installing requirements…"
python -m pip install --upgrade pip
python -m pip install -r "scripts/rai/requirements.txt"

# 4) Run the Python policy applier
Write-Host "🚀 Running raipolicies.py…"
python -m scripts.rai.raipolicies

# 5) Deactivate & cleanup
Write-Host "🧹 Deactivating venv…"
deactivate

Write-Host "🧹 Removing temporary venv…"
Remove-Item -Recurse -Force "scripts/rai/.venv_temp"

Write-Host "✅ RAI script finished."
