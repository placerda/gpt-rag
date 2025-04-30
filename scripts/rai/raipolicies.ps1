# scripts/rai/raipolicies.ps1
#!/usr/bin/env pwsh
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$venvPath = Join-Path $PSScriptRoot '.venv_temp'

# 0) Clean up any existing venv
if (Test-Path $venvPath) {
    Write-Host "🧹 Removing leftover RAI venv…"
    Remove-Item -Recurse -Force $venvPath
}

# 1) Create temporary venv
Write-Host "📦 Creating temporary venv…"
& python -m venv $venvPath 2>&1 | ForEach-Object { Write-Host $_ }
if ($LASTEXITCODE -ne 0) {
    Write-Warning "'python -m venv' failed, retrying with 'py -3 -m venv'…"
    & py -3 -m venv $venvPath 2>&1 | ForEach-Object { Write-Host $_ }
    if ($LASTEXITCODE -ne 0) {
        throw "❗️ Could not create RAI virtual environment (exit code $LASTEXITCODE)"
    }
}

# 2) Activate it
Write-Host "🔓 Activating venv…"
& "$venvPath\Scripts\Activate.ps1"

# 3) Install requirements
Write-Host "⬇️  Installing requirements…"
& python -m pip install --upgrade pip 2>&1 | ForEach-Object { Write-Host $_ }
& python -m pip install -r "$PSScriptRoot\requirements.txt" 2>&1 | ForEach-Object { Write-Host $_ }

# 4) Run the Python policy applier
Write-Host "🚀 Running raipolicies.py…"
$raw = & python -m scripts.rai.raipolicies 2>&1
$raw -split "`r?`n" | ForEach-Object { if ($_ -match '\S') { Write-Host $_ } }

if ($LASTEXITCODE -ne 0) {
    throw "❗️ [RAI Policies] 'raipolicies.py' exited with code $LASTEXITCODE"
}

# 5) Deactivate & cleanup
Write-Host "🧹 Deactivating venv…"
if (Get-Command Deactivate -ErrorAction SilentlyContinue) { Deactivate }

Write-Host "🧹 Removing temporary venv…"
Remove-Item -Recurse -Force $venvPath

Write-Host "✅ RAI policies script finished."
