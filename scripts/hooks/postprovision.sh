#!/usr/bin/env bash
set -euo pipefail

# avoid unbound-variable errors by setting defaults
: "${RUN_AOAI_RAI_POLICIES:=false}"
: "${RUN_SEARCH_SETUP:=false}"
: "${AZURE_NETWORK_ISOLATION:=false}"

echo "🔧 Running post-provision steps…"

echo "📋 Current environment variables:"
for v in RUN_AOAI_RAI_POLICIES RUN_SEARCH_SETUP AZURE_APP_CONFIG_ENDPOINT AZURE_NETWORK_ISOLATION; do
  printf "  %s=%s\n" "$v" "${!v:-<unset>}"
done

###############################################################################
# 1) App Configuration
###############################################################################

echo "📑 Seeding App Configuration…"
{
  echo "📦 Creating temporary venv…"
  python -m venv scripts/appconfig/.venv_temp
  source scripts/appconfig/.venv_temp/bin/activate

  echo "⬇️  Installing requirements…"
  pip install --upgrade pip
  pip install -r scripts/appconfig/requirements.txt

  echo "🚀 Running seedconfig.py…"
  python -m scripts.appconfig.seedconfig

  echo "🧹 Cleaning up…"
  deactivate
  rm -rf scripts/appconfig/.venv_temp

  echo "✅ App Configuration script finished."
} || {
  echo "❗️ Error during App Configuration. Skipping to RAI policies."
}

###############################################################################
# 2) RAI policies
###############################################################################
echo 
if [[ "${RUN_AOAI_RAI_POLICIES,,}" == "true" ]]; then
  echo "📑 Applying RAI policies…"
  {
    echo "📦 Creating temporary venv…"
    python -m venv scripts/rai/.venv_temp
    source scripts/rai/.venv_temp/bin/activate

    echo "⬇️  Installing requirements…"
    pip install --upgrade pip
    pip install -r scripts/rai/requirements.txt

    echo "🚀 Running raipolicies.py…"
    python -m scripts.rai.raipolicies

    echo "🧹 Cleaning up…"
    deactivate
    rm -rf scripts/rai/.venv_temp

    echo "✅ RAI policies script finished."
  } || {
    echo "❗️ Error during RAI policies. Skipping to AI Search setup."
  }
else
  echo "⚠️  Skipping RAI policies (RUN_AOAI_RAI_POLICIES is not 'true')."
fi

###############################################################################
# 3) AI Search Setup
###############################################################################
echo 
if [[ "${RUN_SEARCH_SETUP,,}" == "true" ]]; then
  echo "🔍 AI Search setup…"
  {
    echo "📦 Creating temporary venv…"
    python -m venv scripts/search/.venv_temp
    source scripts/search/.venv_temp/bin/activate

    echo "⬇️  Installing requirements…"
    pip install --upgrade pip
    pip install -r scripts/search/requirements.txt

    echo "🚀 Running setup.py…"
    python -m scripts.search.setup

    echo "🧹 Cleaning up…"
    deactivate
    rm -rf scripts/search/.venv_temp

    echo "✅ Search setup script finished."
  } || {
    echo "❗️ Error during Search setup."
  }
else
  echo "⚠️  Skipping AI Search setup (RUN_SEARCH_SETUP is not 'true')."
fi


###############################################################################
# 4) AI Project Connections
###############################################################################
echo 
echo "🔍 AI Project Connections setup…"
{
  echo "📦 Creating temporary venv…"
  python -m venv scripts/aifoundry/.venv_temp
  source scripts/aifoundry/.venv_temp/bin/activate

  echo "⬇️  Installing requirements…"
  pip install --upgrade pip
  pip install -r scripts/aifoundry/requirements.txt

  echo "🚀 Running create_connections.py…"
  python -m scripts.aifoundry.create_connections

  echo "🧹 Cleaning up…"
  deactivate
  rm -rf scripts/aifoundry/.venv_temp

  echo "✅ AI Project Connections setup script finished."
} || {
  echo "❗️ Error during Project Connections setup."
}

###############################################################################
# 5) Zero Trust bastion
###############################################################################
echo 
if [[ "${AZURE_NETWORK_ISOLATION,,}" == "true" ]]; then
  echo "🔒 Access the Zero Trust bastion:"
  echo "  VM: $AZURE_VM_NAME"
  echo "  User: $AZURE_VM_USER_NAME"
  echo "  Credentials: $AZURE_BASTION_KV_NAME/$AZURE_VM_KV_SEC_NAME"
else
  echo "🚧 Zero Trust not enabled; provisioning Standard architecture."
fi

echo 
echo "✅ postProvisioning completed."