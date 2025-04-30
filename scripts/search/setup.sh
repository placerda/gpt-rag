#!/usr/bin/env bash
set -euo pipefail

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
