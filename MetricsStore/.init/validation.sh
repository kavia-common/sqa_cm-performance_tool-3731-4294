#!/usr/bin/env bash
set -euo pipefail
source /etc/profile.d/metricsstore.sh >/dev/null 2>&1 || true
WORKSPACE="${METRICSSTORE_WORKSPACE:-/home/kavia/workspace/code-generation/sqa_cm-performance_tool-3731-4294/MetricsStore}"
cd "$WORKSPACE"
mkdir -p logs .init
# Port check
if command -v nc >/dev/null 2>&1; then
  if nc -z 127.0.0.1 5000 >/dev/null 2>&1; then
    echo "ERROR: port 5000 already in use" >&2; exit 6
  fi
else
  if ss -ltn sport = :5000 >/dev/null 2>&1; then
    echo "ERROR: port 5000 already in use" >&2; exit 6
  fi
fi
# Start server capturing logs
python3 -m src.app > logs/validation_server.log 2>&1 &
PID=$!
echo "$PID" > .init/server.pid
_cleanup() {
  if [ -n "${PID:-}" ] && kill -0 "$PID" 2>/dev/null; then
    kill "$PID" >/dev/null 2>&1 || true
    SECONDS_WAIT=0
    while kill -0 "$PID" 2>/dev/null && [ $SECONDS_WAIT -lt 25 ]; do sleep 0.2; SECONDS_WAIT=$((SECONDS_WAIT+1)); done
    if kill -0 "$PID" 2>/dev/null; then kill -9 "$PID" >/dev/null 2>&1 || true; fi
  fi
}
trap '_cleanup' EXIT
# Wait for readiness (up to ~10s)
TRIES=0
until curl -sSf http://127.0.0.1:5000/ >/dev/null 2>&1; do
  TRIES=$((TRIES+1))
  if [ $TRIES -gt 50 ]; then
    echo "ERROR: server did not start; see logs/validation_server.log" >&2
    cat logs/validation_server.log 2>/dev/null || true
    exit 7
  fi
  sleep 0.2
done
# Evidence - print responses
echo "EVIDENCE: / responded:"
curl -sS http://127.0.0.1:5000/ || true
echo "\nEVIDENCE: /health responded:"
curl -sS http://127.0.0.1:5000/health || true
# Ensure graceful shutdown
_cleanup
echo "Validation completed"
