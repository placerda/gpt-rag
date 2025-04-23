#!/usr/bin/env bash
set -euo pipefail

# 🎯 RAI Script: Setting up AOAI content filters & blocklist
# Usage: ./raipolicies.sh <Tenant> <Subscription> <ResourceGroup> <AoaiResourceName> <AoaiModelName> <RaiPolicyName> <RaiBlocklistName>

if [ "$#" -lt 7 ]; then
  echo "Usage: $0 <Tenant> <Subscription> <ResourceGroup> \\"
  echo "          <AoaiResourceName> <AoaiModelName> \\"
  echo "          <RaiPolicyName> <RaiBlocklistName>"
  exit 1
fi

Tenant="$1"
Subscription="$2"
ResourceGroup="$3"
AoaiResourceName="$4"
AoaiModelName="$5"
RaiPolicyName="$6"
RaiBlocklistName="$7"

echo "🛠️  RAI Script: Setting up AOAI content filters & blocklist"

# 🔑 Get access token
echo "🔑  Fetching access token for tenant $Tenant..."
token=$(az account get-access-token --tenant "$Tenant" --query accessToken --output tsv)
if [ -z "$token" ]; then
  echo "❗  No access token found. Please log in to Azure."
  az login --use-device-code
  token=$(az account get-access-token --tenant "$Tenant" --query accessToken --output tsv)
fi

# 📝 Prepare headers
headers=(
  "Authorization: Bearer $token"
  "Content-Type: application/json"
)

baseURI="https://management.azure.com/subscriptions/$Subscription/resourceGroups/$ResourceGroup/providers/Microsoft.CognitiveServices/accounts/$AoaiResourceName"

# 📋 Create/update blocklist
echo "📋  Creating/updating blocklist '$RaiBlocklistName'..."
blocklistJson=$(sed "s/{{BlocklistName}}/$RaiBlocklistName/g" "$PWD/raiblocklist.json")
blocklistName=$(echo "$blocklistJson" | awk -F'"' '/blocklistname/ {print $4}')
blocklistBody="{\"properties\": {\"description\":\"$blocklistName blocklist policy\"}}"
curl -s -X PUT -H "${headers[0]}" -H "${headers[1]}" \
     -d "$blocklistBody" \
     "$baseURI/raiBlocklists/$blocklistName?api-version=2023-10-01-preview" > /dev/null

# 🗑️ Clear old items
echo "🗑️  Removing existing blocklist items..."
itemsURI="$baseURI/raiBlocklists/$blocklistName/raiBlocklistItems/${blocklistName}Items?api-version=2023-10-01-preview"
while curl -s -o /dev/null -w "%{http_code}" -X DELETE -H "${headers[0]}" -H "${headers[1]}" "$itemsURI" | grep -q '^2'; do
  echo "   …deleting…"
done

# ➕ Add new items
echo "➕  Adding new blocklist items..."
blocklistItems=$(echo "$blocklistJson" | awk '/"blocklistItems": \[/,/\]/' | sed '1d;$d')
patterns=($(grep -oP '"pattern":\s*"\K[^"]+' <<<"$blocklistItems"))
isRegexes=($(grep -oP '"isRegex":\s*\K[^,]+' <<<"$blocklistItems"))
for i in "${!patterns[@]}"; do
  echo "   • pattern='${patterns[i]}', isRegex=${isRegexes[i]}"
  body="{\"properties\":{\"pattern\":\"${patterns[i]}\",\"isRegex\":${isRegexes[i]}}}"
  curl -s -X PUT -H "${headers[0]}" -H "${headers[1]}" \
       -d "$body" \
       "$itemsURI" > /dev/null
done

# 🛡️ Create policy
echo "🛡️  Creating content filter policy '$RaiPolicyName'..."
policyBody=$(sed -e "s/{{PolicyName}}/$RaiPolicyName/" -e "s/{{BlocklistName}}/$RaiBlocklistName/" "$PWD/raipolicies.json")
curl -s -X PUT -H "${headers[0]}" -H "${headers[1]}" \
     -d "$policyBody" \
     "$baseURI/raiPolicies/$RaiPolicyName?api-version=2023-10-01-preview" > /dev/null

# 🔄 Attach policy to model
echo "🔄  Updating model '$AoaiModelName' with RAI policy..."
modelJson=$(curl -s -H "${headers[0]}" "$baseURI/deployments/$AoaiModelName?api-version=2023-10-01-preview")
skuName=$(jq -r '.sku.name' <<<"$modelJson")
capacity=$(jq -r '.sku.capacity' <<<"$modelJson")
format=$(jq -r '.properties.model.format' <<<"$modelJson")
version=$(jq -r '.properties.model.version' <<<"$modelJson")
vuo=$(jq -r '.properties.versionUpgradeOption' <<<"$modelJson")

updated=$(jq -n \
  --arg name "$AoaiModelName" \
  --arg sku "$skuName" \
  --argjson cap "$capacity" \
  --arg fmt "$format" \
  --arg ver "$version" \
  --arg vuo "$vuo" \
  --arg rpol "$RaiPolicyName" \
  '{displayName:$name,sku:{name:$sku,capacity:$cap},properties:{model:{format:$fmt,name:$name,version:$ver},versionUpgradeOption:$vuo,raiPolicyName:$rpol}}')

curl -s -X PUT -H "${headers[0]}" -H "${headers[1]}" \
     -d "$updated" \
     "$baseURI/deployments/$AoaiModelName?api-version=2023-10-01-preview" > /dev/null

echo "🎉  RAI setup complete!"
