#!/usr/bin/env bash
set -euo pipefail
# Run pytest smoke test that starts the app as a module, captures logs and fails fast on port conflicts
source /etc/profile.d/metricsstore.sh >/dev/null 2>&1 || true
WORKSPACE="${METRICSSTORE_WORKSPACE:-/home/kavia/workspace/code-generation/sqa_cm-performance_tool-3731-4294/MetricsStore}"
cd "$WORKSPACE"
mkdir -p logs tests
# write pytest smoke test (idempotent)
[ -f "$WORKSPACE/tests/test_smoke.py" ] || cat > "$WORKSPACE/tests/test_smoke.py" <<'PY'
import subprocess, time, requests, os, sys, socket

def is_port_free(port=5000):
    s = socket.socket()
    try:
        s.bind(('127.0.0.1', port))
        return True
    except Exception:
        return False
    finally:
        try: s.close()
        except Exception: pass

def start_server(workdir):
    logpath = os.path.join(workdir, 'logs', 'test_server.log')
    logf = open(logpath, 'ab')
    # run as module to preserve package imports
    p = subprocess.Popen([sys.executable, '-m', 'src.app'], cwd=workdir, stdout=logf, stderr=logf)
    return p

def test_health_endpoint():
    workdir = os.path.dirname(os.path.dirname(__file__))
    if not is_port_free(5000):
        raise AssertionError('Port 5000 already in use')
    p = start_server(workdir)
    try:
        r = None
        for _ in range(200):
            try:
                r = requests.get('http://127.0.0.1:5000/health', timeout=1)
                if r.status_code == 200:
                    break
            except Exception:
                time.sleep(0.1)
        else:
            p.terminate(); p.wait(); raise AssertionError('server did not respond in time; see logs/test_server.log')
        assert r.json().get('db_path') is not None
    finally:
        p.terminate(); p.wait()
PY
# run pytest (quiet)
pytest -q || { echo 'Tests failed' >&2; exit 5; }
