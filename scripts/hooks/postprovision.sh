#!/usr/bin/env bash
set -euo pipefail

# avoid unbound-variable errors by setting defaults
: "${AZURE_REUSE_AOAI:=false}"
: "${CONFIGURE_RBAC:=false}"
: "${NETWORK_ISOLATION:=false}"

echo "🔧 Running post-provision steps…"

# 1) RAI policies
if [[ -n "${AZURE_REUSE_AOAI}" && "${AZURE_REUSE_AOAI,,}" != "true" ]]; then
  echo "📑 Applying RAI policies…"
  if ! "$PWD/scripts/rai/raipolicies.sh"; then
    echo "❗️ Error applying RAI policies. Continuing anyway…"
  fi
else
  echo "⚠️  Skipping RAI policies (AZURE_REUSE_AOAI is either empty or 'true')."
fi

# 2) App Configuration
echo ""
if [[ "${CONFIGURE_RBAC,,}" == "true" ]]; then
  echo "📑 Seeding App Configuration…"
  if ! "$PWD/scripts/appconfig/appconfig.sh"; then
    echo "❗️ Error seeding App Configuration. Continuing anyway…"
  fi
else
  echo "⚠️  Skipping App Configuration (CONFIGURE_RBAC is not 'true')."
fi

# 3) AI Search Setup
echo ""
echo "🔍 AI Search setup…"
if ! "$PWD/scripts/search/setup.sh"; then
  echo "❗️ Error setting up AI Search. Continuing anyway…"
fi

# 4) Zero Trust bastion
if [[ "${NETWORK_ISOLATION,,}" == "true" ]]; then
  echo
  echo "🔒 Access the Zero Trust bastion:"
  echo "  VM: $AZURE_VM_NAME"
  echo "  User: $AZURE_VM_USER_NAME"
  echo "  Credentials: $AZURE_BASTION_KV_NAME/$AZURE_VM_KV_SEC_NAME"
else
  echo
  echo "🚧 Zero Trust not enabled; provisioning Standard architecture."
fi

echo ""
echo "✅ postProvisioning completed."