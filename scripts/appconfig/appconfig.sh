#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 3 ]; then
  echo "Usage: $0 <resource-group> <deployment-name> <appconfig-store-name>"
  exit 1
fi

rg="$1"
deployment="$2"
store="$3"

echo "⏳ Waiting for RBAC on '$store'…"
until az appconfig kv list --name "$store" --resource-group "$rg" --top 1 > /dev/null 2>&1; do
  echo "   …waiting 10s"
  sleep 10
done
echo "✅ RBAC effective."

echo "📥 Fetching key/value map from deployment '$deployment'…"
kvs_json=$(az deployment group show \
  --resource-group "$rg" \
  --name "$deployment" \
  --query "properties.outputs.appConfigKVs.value" \
  -o json)

echo "➕ Seeding $(jq 'length' <<<"$kvs_json") entries…"
echo "$kvs_json" \
  | jq -r 'to_entries[] | "\(.key) \(.value)"' \
  | while read -r key val; do
      echo "  • $key = $val"
      az appconfig kv set \
        --name "$store" \
        --resource-group "$rg" \
        --key "$key" \
        --value "$val" \
        --yes
    done

echo "🎉 App Configuration seeded."
