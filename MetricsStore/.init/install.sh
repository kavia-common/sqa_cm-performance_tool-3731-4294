#!/usr/bin/env bash
set -euo pipefail
# Install missing Python dev dependencies into the container workspace
source /etc/profile.d/metricsstore.sh >/dev/null 2>&1 || true
WORKSPACE="${METRICSSTORE_WORKSPACE:-/home/kavia/workspace/code-generation/sqa_cm-performance_tool-3731-4294/MetricsStore}"
cd "$WORKSPACE"
python3 - <<'PY'
import sys, subprocess
from importlib import util
reqs = {
    'requests': 'requests',
    'python-dotenv': 'dotenv',
    'sqlalchemy': 'sqlalchemy',
    'pytest': 'pytest'
}
missing = []
for pkg, imp in reqs.items():
    if util.find_spec(imp) is None:
        missing.append(pkg)
if missing:
    cmd = [sys.executable, '-m', 'pip', 'install', '--no-cache-dir', '--disable-pip-version-check', '-q'] + missing
    print('Installing:', ' '.join(missing))
    subprocess.check_call(cmd)
# Verify imports and print minimal versions
try:
    import flask, requests, sqlalchemy
    from dotenv import load_dotenv
    print('flask_version=' + getattr(flask, '__version__', 'unknown'))
    try:
        print('requests_version=' + getattr(requests, '__version__', 'unknown'))
    except Exception:
        print('requests_ok')
    print('sqlalchemy_ok')
    print('dotenv_ok')
except Exception as e:
    print('MISSING_DEP', e, file=sys.stderr)
    sys.exit(4)
PY
