# requires PowerShell 5.1+
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Write-Host "📦 Creating temporary venv…"
python -m venv .venv_temp

Write-Host "🟢 Activating venv…"
# On Windows PowerShell:
& ".\.venv_temp\Scripts\Activate.ps1"

Write-Host "⬇️  Installing requirements…"
pip install --upgrade pip
pip install -r ".\scripts\search\requirements.txt" 

Write-Host "🚀 Running setup.py…"
python -m scripts.search.setup

Write-Host "🧹 Cleaning up…"
# Deactivate the venv (Deactivate function is defined by Activate.ps1)
if (Get-Command Deactivate -ErrorAction SilentlyContinue) {
    Deactivate
}

# Remove the temporary virtual environment folder
Remove-Item -Recurse -Force .venv_temp

Write-Host "✅ Search setup complete."
