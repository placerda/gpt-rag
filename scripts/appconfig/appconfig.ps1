# scripts/appconfig/appconfig.ps1
#!/usr/bin/env pwsh
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$venvPath = Join-Path $PSScriptRoot '.venv_temp'

# 0) Clean up any existing venv
if (Test-Path $venvPath) {
    Write-Host "🧹 Removing leftover AppConfig venv…"
    Remove-Item -Recurse -Force $venvPath
}

# 1) Create temporary venv
Write-Host "📦 Creating temporary venv…"
& python -m venv $venvPath 2>&1 | ForEach-Object { Write-Host $_ }
if ($LASTEXITCODE -ne 0) {
    Write-Warning "'python -m venv' failed, retrying with 'py -3 -m venv'…"
    & py -3 -m venv $venvPath 2>&1 | ForEach-Object { Write-Host $_ }
    if ($LASTEXITCODE -ne 0) {
        throw "❗️ Could not create AppConfig virtual environment (exit code $LASTEXITCODE)"
    }
}

# 2) Activate the venv
Write-Host "🔓 Activating venv…"
& "$venvPath\Scripts\Activate.ps1"

# 3) Install dependencies
Write-Host "⬇️  Installing requirements…"
& python -m pip install --upgrade pip 2>&1 | ForEach-Object { Write-Host $_ }
& python -m pip install -r "$PSScriptRoot\requirements.txt" 2>&1 | ForEach-Object { Write-Host $_ }

# 4) Run the Python seeder
Write-Host "🚀 Running appconfig.py…"
$raw = & python -m scripts.appconfig.appconfig 2>&1
$raw -split "`r?`n" | ForEach-Object { if ($_ -match '\S') { Write-Host $_ } }

if ($LASTEXITCODE -ne 0) {
    throw "❗️ [AppConfig] 'appconfig.py' exited with code $LASTEXITCODE"
}

# 5) Deactivate & cleanup
Write-Host "🧹 Deactivating venv…"
if (Get-Command Deactivate -ErrorAction SilentlyContinue) { Deactivate }

Write-Host "🧹 Removing temporary venv…"
Remove-Item -Recurse -Force $venvPath

Write-Host "✅ App Configuration script finished."
