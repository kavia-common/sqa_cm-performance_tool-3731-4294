#!/usr/bin/env bash
set -euo pipefail
# Idempotent scaffold for minimal Flask package using canonical workspace
# Uses /etc/profile.d/metricsstore.sh to read METRICSSTORE_WORKSPACE if present
source /etc/profile.d/metricsstore.sh >/dev/null 2>&1 || true
: "${METRICSSTORE_WORKSPACE:=/home/kavia/workspace/code-generation/sqa_cm-performance_tool-3731-4294/MetricsStore}"
WORKSPACE="${METRICSSTORE_WORKSPACE}"
mkdir -p "$WORKSPACE/src" "$WORKSPACE/tests" "$WORKSPACE/logs"
# src/__init__.py
[ -f "$WORKSPACE/src/__init__.py" ] || cat > "$WORKSPACE/src/__init__.py" <<'PY'
"""MetricsStore package."""
PY
# src/app.py (idempotent)
[ -f "$WORKSPACE/src/app.py" ] || cat > "$WORKSPACE/src/app.py" <<'PY'
"""Minimal Flask app for MetricsStore. Run with: python3 -m src.app"""
from flask import Flask, jsonify
from dotenv import load_dotenv
import os, sqlite3
load_dotenv()
# Default DB under workspace (fallback to parent of package)
default_db = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'metrics.db'))
DB_PATH = os.path.abspath(os.getenv('METRICS_DB', default_db))
app = Flask(__name__)

def init_db():
    parent = os.path.dirname(DB_PATH)
    if not parent:
        parent = os.getcwd()
    os.makedirs(parent, exist_ok=True)
    conn = sqlite3.connect(DB_PATH)
    c = conn.cursor()
    c.execute('CREATE TABLE IF NOT EXISTS metrics (id INTEGER PRIMARY KEY, name TEXT, value REAL)')
    conn.commit()
    conn.close()

@app.route('/')
def index():
    return jsonify({'status': 'ok'})

@app.route('/health')
def health():
    return jsonify({'db_path': DB_PATH, 'exists': os.path.exists(DB_PATH)})

if __name__ == '__main__':
    init_db()
    app.run(host='127.0.0.1', port=5000)
PY
# start_dev.sh: initialize DB and run via module form to avoid package import issues
[ -f "$WORKSPACE/start_dev.sh" ] || cat > "$WORKSPACE/start_dev.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
source /etc/profile.d/metricsstore.sh >/dev/null 2>&1 || true
WORKSPACE="${METRICSSTORE_WORKSPACE}"
cd "$WORKSPACE"
export FLASK_ENV=development
# Initialize DB
python3 - <<'PY'
import importlib
m = importlib.import_module('src.app')
if hasattr(m, 'init_db'):
    m.init_db()
PY
# Run app as module to preserve package imports
python3 -m src.app
SH
chmod +x "$WORKSPACE/start_dev.sh"
# .env creation with absolute path (idempotent)
[ -f "$WORKSPACE/.env" ] || cat > "$WORKSPACE/.env" <<EOF
# XENA connection settings (replace placeholders)
XENA_ENDPOINT=https://xena.example/api
XENA_USER=replace-me
XENA_PASSWORD=replace-me
# Local SQLite DB path (absolute)
METRICS_DB=${WORKSPACE}/metrics.db
EOF
chmod 600 "$WORKSPACE/.env"
# requirements.txt minimal (create only if missing)
[ -f "$WORKSPACE/requirements.txt" ] || cat > "$WORKSPACE/requirements.txt" <<'REQ'
requests
python-dotenv
sqlalchemy
pytest
REQ
# README
[ -f "$WORKSPACE/README.md" ] || cat > "$WORKSPACE/README.md" <<'MD'
Minimal Flask metrics store scaffold. Use ./start_dev.sh to run the dev server. .env contains placeholders and METRICS_DB is absolute. Files are created only if missing.
MD
# Persist minimal canonical environment file for workspace and PYTHONUNBUFFERED if missing
if [ ! -f /etc/profile.d/metricsstore.sh ]; then
  sudo bash -c 'cat > /etc/profile.d/metricsstore.sh <<"ENV"\n# Canonical workspace for MetricsStore container\nexport METRICSSTORE_WORKSPACE="'"${WORKSPACE}"'"\nexport PYTHONUNBUFFERED=1\nENV'
  sudo chmod 644 /etc/profile.d/metricsstore.sh
fi
# Final validation: list created files (quiet)
ls -ld "$WORKSPACE"/* | sed -n '1,200p' >/dev/null 2>&1 || true
