#!/usr/bin/env bash
set -euo pipefail

echo "📦 Creating temporary venv…"
python3 -m venv .venv_temp
source .venv_temp/bin/activate

echo "⬇️  Installing requirements…"
pip install --upgrade pip
pip install -r scripts/search/requirements.txt

echo "🚀 Running setup.py…"
python -m scripts.search.setup

echo "🧹 Cleaning up…"
deactivate
rm -rf .venv_temp

echo "✅ Search setup complete."
