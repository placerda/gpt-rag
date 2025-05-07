<#
.SYNOPSIS
    Post-provision steps for Azure environment (PowerShell version)
#>

# Stop on errors and enforce strict mode
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# -------------
#  Default environment variable values
# -------------
$defaults = @{
    'RUN_AOAI_RAI_POLICIES'   = 'false'
    'RUN_SEARCH_SETUP'        = 'false'
    'AZURE_NETWORK_ISOLATION' = 'false'
}
foreach ($key in $defaults.Keys) {
    if (-not (Test-Path env:$key)) {
        [System.Environment]::SetEnvironmentVariable($key, $defaults[$key])
    }
}

Write-Host "🔧 Running post-provision steps…"

# -------------
#  Print current environment variables
# -------------
Write-Host "📋 Current environment variables:"
$varsToPrint = 'RUN_AOAI_RAI_POLICIES','RUN_SEARCH_SETUP','AZURE_APP_CONFIG_ENDPOINT','AZURE_NETWORK_ISOLATION'
foreach ($v in $varsToPrint) {
    $val = (Get-Item env:$v -ErrorAction SilentlyContinue).Value
    if (-not $val) { $val = '<unset>' }
    Write-Host "  $v=$val"
}

# -------------
#  1) App Configuration
# -------------
Write-Host "`n📑 Seeding App Configuration…"
try {
    Write-Host "📦 Creating temporary venv…"
    python -m venv scripts/appconfig/.venv_temp
    & "scripts/appconfig/.venv_temp/Scripts/Activate.ps1"

    Write-Host "⬇️  Installing requirements…"
    pip install --upgrade pip
    pip install -r scripts/appconfig/requirements.txt

    Write-Host "🚀 Running seedconfig.py…"
    python -m scripts.appconfig.seedconfig

    Write-Host "🧹 Cleaning up…"
    & deactivate
    Remove-Item -Recurse -Force scripts/appconfig/.venv_temp

    Write-Host "✅ App Configuration script finished."
} catch {
    Write-Warning "❗️ Error during App Configuration. Skipping to RAI policies."
}

# -------------
#  2) RAI policies
# -------------
if ($env:RUN_AOAI_RAI_POLICIES.ToLower() -eq 'true') {
    Write-Host "`n📑 Applying RAI policies…"
    try {
        Write-Host "📦 Creating temporary venv…"
        python -m venv scripts/rai/.venv_temp
        & "scripts/rai/.venv_temp/Scripts/Activate.ps1"

        Write-Host "⬇️  Installing requirements…"
        pip install --upgrade pip
        pip install -r scripts/rai/requirements.txt

        Write-Host "🚀 Running raipolicies.py…"
        python -m scripts.rai.raipolicies

        Write-Host "🧹 Cleaning up…"
        & deactivate
        Remove-Item -Recurse -Force scripts/rai/.venv_temp

        Write-Host "✅ RAI policies script finished."
    } catch {
        Write-Warning "❗️ Error during RAI policies. Skipping to AI Search setup."
    }
} else {
    Write-Host "⚠️  Skipping RAI policies (RUN_AOAI_RAI_POLICIES is not 'true')."
}

# -------------
#  3) AI Search Setup
# -------------
if ($env:RUN_SEARCH_SETUP.ToLower() -eq 'true') {
    Write-Host "`n🔍 AI Search setup…"
    try {
        Write-Host "📦 Creating temporary venv…"
        python -m venv scripts/search/.venv_temp
        & "scripts/search/.venv_temp/Scripts/Activate.ps1"

        Write-Host "⬇️  Installing requirements…"
        pip install --upgrade pip
        pip install -r scripts/search/requirements.txt

        Write-Host "🚀 Running setup.py…"
        python -m scripts.search.setup

        Write-Host "🧹 Cleaning up…"
        & deactivate
        Remove-Item -Recurse -Force scripts/search/.venv_temp

        Write-Host "✅ Search setup script finished."
    } catch {
        Write-Warning "❗️ Error during Search setup."
    }
} else {
    Write-Host "⚠️  Skipping AI Search setup (RUN_SEARCH_SETUP is not 'true')."
}

# -------------
#  4) AI Project Connections
# -------------
Write-Host "`n🔍 AI Project Connections setup…"
try {
    Write-Host "📦 Creating temporary venv…"
    python -m venv scripts/aifoundry/.venv_temp
    & "scripts/aifoundry/.venv_temp/Scripts/Activate.ps1"

    Write-Host "⬇️  Installing requirements…"
    pip install --upgrade pip
    pip install -r scripts/aifoundry/requirements.txt

    Write-Host "🚀 Running create_connections.py…"
    python -m scripts.aifoundry.create_connections

    Write-Host "🧹 Cleaning up…"
    & deactivate
    Remove-Item -Recurse -Force scripts/aifoundry/.venv_temp

    Write-Host "✅ AI Project Connections setup script finished."
} catch {
    Write-Warning "❗️ Error during Project Connections setup."
}

# -------------
#  5) Update Container Apps Registry
# -------------
Write-Host "`n🛠️  Updating container apps registry..."

# Helper to read azd env values
$azdValues = azd env get-values
function Get-AzdValue { param($key) 
    ($azdValues | Where-Object { $_ -match "^$key=" } | ForEach-Object { ($_ -split '=',2)[1].Trim('"') })
}
$RG             = Get-AzdValue 'AZURE_RESOURCE_GROUP';                     Write-Host "📦 Resolved AZURE_RESOURCE_GROUP from azd: $RG"
$RegistryHost   = Get-AzdValue 'AZURE_CONTAINER_REGISTRY_ENDPOINT';         Write-Host "📦 Resolved AZURE_CONTAINER_REGISTRY_ENDPOINT from azd: $RegistryHost"
$DataIngestApp  = Get-AzdValue 'AZURE_DATA_INGEST_CONTAINER_APP_NAME';      Write-Host "📦 Resolved AZURE_DATA_INGEST_CONTAINER_APP_NAME from azd: $DataIngestApp"
$FrontendApp    = Get-AzdValue 'AZURE_FRONTEND_CONTAINER_APP_NAME';         Write-Host "📦 Resolved AZURE_FRONTEND_CONTAINER_APP_NAME from azd: $FrontendApp"
$OrchestratorApp= Get-AzdValue 'AZURE_ORCHESTRATOR_CONTAINER_APP_NAME';     Write-Host "📦 Resolved AZURE_ORCHESTRATOR_CONTAINER_APP_NAME from azd: $OrchestratorApp"

Write-Host "🚀 Updating Data Ingest container app registry..."
az containerapp registry set --name $DataIngestApp --resource-group $RG --server $RegistryHost --identity system

Write-Host "🚀 Updating Orchestrator container app registry..."
az containerapp registry set --name $OrchestratorApp --resource-group $RG --server $RegistryHost --identity system

Write-Host "🚀 Updating Frontend container app registry..."
az containerapp registry set --name $FrontendApp --resource-group $RG --server $RegistryHost --identity system

# -------------
#  6) Zero Trust bastion
# -------------
Write-Host ""
if ($env:AZURE_NETWORK_ISOLATION.ToLower() -eq 'true') {
    Write-Host "🔒 Access the Zero Trust bastion:"
    Write-Host "  VM: $env:AZURE_VM_NAME"
    Write-Host "  User: $env:AZURE_VM_USER_NAME"
    Write-Host "  Credentials: $env:AZURE_BASTION_KV_NAME/$env:AZURE_VM_KV_SEC_NAME"
} else {
    Write-Host "🚧 Zero Trust not enabled; provisioning Standard architecture."
}

Write-Host "`n✅ postProvisioning completed."
