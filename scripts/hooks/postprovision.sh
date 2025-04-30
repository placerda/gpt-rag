#!/usr/bin/env bash
set -euo pipefail

echo "🔧 Running post-provision steps…"

# 1) RAI policies
if [[ "${AZURE_REUSE_AOAI,,}" != "true"]]; then
  echo "📑 Applying RAI policies…"
  "$PWD/scripts/rai/raipolicies.sh"
else
  echo "⚠️  Skipping RAI policies (AZURE_REUSE_AOAI is 'true')."
fi

# 2) App Configuration
if [[ "${CONFIGURE_RBAC,,}" == "true" ]]; then
  echo "📑 Seeding App Configuration…"
  "$PWD/scripts/appconfig/appconfig.sh"
else
  echo "⚠️  Skipping App Configuration (CONFIGURE_RBAC is not 'true')."
fi

# 3) AI Search Setup
echo "AI Search setup…"
"$PWD/scripts/search/setup.sh"

# 4) Zero Trust bastion
if [[ "${NETWORK_ISOLATION,,}" == "true" ]]; then
  echo
  echo "🔒 Access the Zero Trust bastion:"
  echo "  VM: $AZURE_VM_NAME"
  echo "  User: $AZURE_VM_USER_NAME"
  echo "  Credentials: $AZURE_BASTION_KV_NAME/$AZURE_VM_KV_SEC_NAME"
fi

echo "✅ postProvisioning completed."