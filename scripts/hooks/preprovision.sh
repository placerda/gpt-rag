#!/bin/sh

## Displays a warning to the user if AZURE_NETWORK_ISOLATION is set

YELLOW='\033[0;33m'
BLUE='\033[0;34m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

###############################################################################
# 1) Load Environment Variables from Previous Deployment (if available)
###############################################################################
echo
echo "📑 Loading environment variables from previous deployment (if available)…"

if [ -z "$AZURE_APP_CONFIG_ENDPOINT" ]; then
  echo "⚠️  Skipping: AZURE_APP_CONFIG_ENDPOINT is not set."
else
  echo "📦 Creating temporary virtual environment…"
  python -m venv scripts/appconfig/.venv_temp
  . scripts/appconfig/.venv_temp/bin/activate

  echo "⬇️  Installing requirements…"
  pip install --upgrade pip
  pip install -r scripts/appconfig/requirements.txt

  echo "🚀 Running loadconfig.py…"
  python -m scripts.appconfig.loadconfig

  echo "🧹 Cleaning up…"
  deactivate
  rm -rf scripts/appconfig/.venv_temp

  echo "✅ Environment variables loaded from App Configuration."
fi

###############################################################################
# 2) Network Isolation Warning
###############################################################################

# Skip warning if AZURE_SKIP_NETWORK_ISOLATION_WARNING is set
if [ "$AZURE_SKIP_NETWORK_ISOLATION_WARNING" -ge 1 ] 2>/dev/null || [ "$AZURE_SKIP_NETWORK_ISOLATION_WARNING" = "true" ] || [ "$AZURE_SKIP_NETWORK_ISOLATION_WARNING" = "t" ]; then
    exit 0
fi

# Show warning if AZURE_NETWORK_ISOLATION is enabled
if [ "$AZURE_NETWORK_ISOLATION" -ge 1 ] 2>/dev/null || [ "$AZURE_NETWORK_ISOLATION" = "true" ] || [ "$AZURE_NETWORK_ISOLATION" = "t" ]; then
    
    echo "${YELLOW}Warning!${NC} AZURE_NETWORK_ISOLATION is enabled."
    echo " - After provisioning, you must switch to the ${GREEN}Virtual Machine & Bastion${NC} to continue deploying components."
    echo " - Infrastructure will only be reachable from within the Bastion host."

    echo -n "${BLUE}?${NC} Continue with Zero Trust provisioning? [Y/n]: "
    read confirmation

    if [ "$confirmation" != "Y" ] && [ "$confirmation" != "y" ] && [ -n "$confirmation" ]; then
        exit 1
    fi
fi

exit 0
