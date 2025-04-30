# scripts/search/setup.ps1
# requires PowerShell 5.1+
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Write-Host "📦 Creating temporary venv…"
python -m venv "scripts/search/.venv_temp"

Write-Host "🟢 Activating venv…"
& ".\scripts\search\.venv_temp\Scripts\Activate.ps1"

Write-Host "⬇️  Installing requirements…"
pip install --upgrade pip
pip install -r ".\scripts/search/requirements.txt"

Write-Host "🚀 Running setup.py…"
# capture stdout+stderr as an array of lines
$output = & python -m scripts.search.setup 2>&1

# emit each line so newlines are preserved
foreach ($line in $output) {
    Write-Host $line
}

if ($LASTEXITCODE -ne 0) {
    throw "❗️ [Search Setup] 'setup.py' exited with code $LASTEXITCODE"
}

Write-Host "🧹 Cleaning up…"
if (Get-Command Deactivate -ErrorAction SilentlyContinue) {
    Deactivate
}
Remove-Item -Recurse -Force .\scripts\search\.venv_temp

Write-Host "✅ Search setup script finished."
