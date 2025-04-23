#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 9 ]; then
  echo "Usage: $0 <subscription-id> <resource-group> <container-app-name> \\"
  echo "          <search-service> <search-api-version> <search-index> \\"
  echo "          <apim-service> <openai-path> <openai-version>"
  exit 1
fi

# Positional args
SUBSCRIPTION_ID=$1
RESOURCE_GROUP=$2
CONTAINER_APP=$3
SEARCH_SVC=$4
SEARCH_API_VER=$5
SEARCH_INDEX=$6
APIM_SVC=$7
OPENAI_PATH=$8
OPENAI_VER=$9

echo "📦 Creating temporary venv…"
python3 -m venv .venv_temp
source .venv_temp/bin/activate

echo "⬇️  Installing requirements…"
pip install --upgrade pip
pip install -r requirements.txt

echo "🚀 Running setup.py…"
python setup.py \
  --subscription-id    "$SUBSCRIPTION_ID" \
  --resource-group     "$RESOURCE_GROUP" \
  --container-app-name "$CONTAINER_APP" \
  --search-service     "$SEARCH_SVC" \
  --search-api-version "$SEARCH_API_VER" \
  --search-index       "$SEARCH_INDEX" \
  --apim-service       "$APIM_SVC" \
  --openai-path        "$OPENAI_PATH" \
  --openai-version     "$OPENAI_VER" 
  
echo "🧹 Cleaning up…"
deactivate
rm -rf .venv_temp

echo "✅ Search setup complete."
