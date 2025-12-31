#!/usr/bin/env bash
set -euo pipefail
source /etc/profile.d/metricsstore.sh >/dev/null 2>&1 || true
WORKSPACE="${METRICSSTORE_WORKSPACE:-/home/kavia/workspace/code-generation/sqa_cm-performance_tool-3731-4294/MetricsStore}"
cd "$WORKSPACE"
mkdir -p logs
# Port conflict detection
if command -v nc >/dev/null 2>&1; then
  if nc -z 127.0.0.1 5000 >/dev/null 2>&1; then
    echo "ERROR: port 5000 already in use" >&2; exit 6
  fi
else
  # fallback using ss
  if ss -ltn sport = :5000 >/dev/null 2>&1; then
    echo "ERROR: port 5000 already in use" >&2; exit 6
  fi
fi
# Start server as module, capture logs
python3 -m src.app > logs/validation_server.log 2>&1 &
PID=$!
echo "$PID" > .init/server.pid
sleep 0.05
# verify process started
if ! kill -0 "$PID" 2>/dev/null; then
  echo "ERROR: server process failed to start; see logs/validation_server.log" >&2; exit 7
fi
# report PID
echo "$PID" > logs/validation_server.pid
