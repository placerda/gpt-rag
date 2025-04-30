#!/usr/bin/env bash
set -euo pipefail

echo "📦 Creating temporary venv…"
python -m venv scripts/appconfig/.venv_temp
source scripts/appconfig/.venv_temp/bin/activate

echo "⬇️  Installing requirements…"
pip install --upgrade pip
pip install -r scripts/appconfig/requirements.txt

echo "🚀 Running appconfig.py…"
python -m scripts.appconfig.appconfig

echo "🧹 Cleaning up…"
deactivate
rm -rf scripts/appconfig/.venv_temp

echo "✅ App Configuration script finished."
