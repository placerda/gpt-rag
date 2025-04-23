# requires PowerShell 5.1+
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Ensure at least 9 arguments were provided
if ($args.Count -lt 9) {
    Write-Host "Usage: .\setup.ps1 <subscription-id> <resource-group> <container-app-name> `"
    Write-Host "                  <search-service> <search-api-version> <search-index> `"
    Write-Host "                  <apim-service> <openai-path> <openai-version>"
    exit 1
}

# Positional args
$SubscriptionId    = $args[0]
$ResourceGroup     = $args[1]
$ContainerApp      = $args[2]
$SearchSvc         = $args[3]
$SearchApiVer      = $args[4]
$SearchIndex       = $args[5]
$ApimSvc           = $args[6]
$OpenaiPath        = $args[7]
$OpenaiVer         = $args[8]

Write-Host "📦 Creating temporary venv…"
python -m venv .venv_temp

Write-Host "🟢 Activating venv…"
# On Windows PowerShell:
& ".\.venv_temp\Scripts\Activate.ps1"

Write-Host "⬇️  Installing requirements…"
pip install --upgrade pip
pip install -r requirements.txt

Write-Host "🚀 Running setup.py…"
python setup.py `
    --subscription-id    $SubscriptionId `
    --resource-group     $ResourceGroup `
    --container-app-name $ContainerApp `
    --search-service     $SearchSvc `
    --search-api-version $SearchApiVer `
    --search-index       $SearchIndex `
    --apim-service       $ApimSvc `
    --openai-path        $OpenaiPath `
    --openai-version     $OpenaiVer

Write-Host "🧹 Cleaning up…"
# Deactivate the venv (Deactivate function is defined by Activate.ps1)
if (Get-Command Deactivate -ErrorAction SilentlyContinue) {
    Deactivate
}

# Remove the temporary virtual environment folder
Remove-Item -Recurse -Force .venv_temp

Write-Host "✅ Search setup complete."
