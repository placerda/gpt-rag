#!/usr/bin/env bash
set -euo pipefail

echo "🔧 Running post-provision steps…"

# Only apply RAI policies & seed App Configuration if CONFIGURE_RBAC is "true"

# 1) RAI policies
if [[ "${AZURE_REUSE_AOAI,,}" != "true" ]]; then
  echo "📑 Applying RAI policies…"
  "$PWD/scripts/rai/raipolicies.sh" \
    "$AZURE_TENANT_ID" \
    "$AZURE_SUBSCRIPTION_ID" \
    "$AZURE_RESOURCE_GROUP_NAME" \
    "$AZURE_AI_SERVICES_NAME" \
    "$AZURE_CHAT_DEPLOYMENT_NAME" \
    "MainRAIpolicy" \
    "MainBlockListPolicy"
else
  echo "⚠️  Skipping RAI policies (AZURE_REUSE_AOAI is 'true')."
fi

# 2) App Configuration
if [[ "${CONFIGURE_RBAC,,}" == "true" ]]; then
  echo "📑 Seeding App Configuration…"
  "$PWD/scripts/appconfig/appconfig.sh" \
    "$AZURE_RESOURCE_GROUP_NAME" \
    "$AZURE_ENVIRONMENT_NAME" \
    "$AZURE_APP_CONFIG_NAME"
else
  echo "⚠️  Skipping App Configuration (CONFIGURE_RBAC is not 'true')."
fi
# 3) AI Search Setup
echo "AI Search setup…"
"$PWD/scripts/search/setup.sh" \
  "$AZURE_SUBSCRIPTION_ID" \
  "$AZURE_RESOURCE_GROUP_NAME" \
  "$AZURE_DATA_INGEST_CONTAINER_APP_NAME" \
  "$AZURE_SEARCH_SERVICE_NAME" \
  "$AZURE_SEARCH_API_VERSION" \
  "$AZURE_SEARCH_INDEX_NAME" \
  "$AZURE_APIM_SERVICE_NAME" \
  "$AZURE_APIM_OPENAI_API_PATH" \
  "$AZURE_OPENAI_API_VERSION"

# 4) Zero Trust bastion
if [[ "${NETWORK_ISOLATION,,}" == "true" ]]; then
  echo
  echo "🔒 Access the Zero Trust bastion:"
  echo "  VM: $AZURE_VM_NAME"
  echo "  User: $AZURE_VM_USER_NAME"
  echo "  Credentials: $AZURE_BASTION_KV_NAME/$AZURE_VM_KV_SEC_NAME"
fi

echo "✅ postProvisioning completed."
