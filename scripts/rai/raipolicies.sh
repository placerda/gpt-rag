# scripts/rai/raipolicies.sh
#!/usr/bin/env bash
set -euo pipefail

echo "📦 Creating temporary venv…"
python -m venv scripts/rai/.venv_temp
source scripts/rai/.venv_temp/bin/activate

echo "⬇️  Installing requirements…"
pip install --upgrade pip
pip install -r scripts/rai/requirements.txt

echo "🚀 Running raipolicies.py…"
python -m scripts.rai.raipolicies

echo "🧹 Cleaning up…"
deactivate
rm -rf scripts/rai/.venv_temp

echo "✅ RAI policies applied."