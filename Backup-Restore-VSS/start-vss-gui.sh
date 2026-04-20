#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# start-vss-gui.sh  —  Launch the VSS Backup & Restore web console.
#
# Usage (from anywhere on ryzen9):
#   ./SQLDBA-SSMS-Solution/Backup-Restore-VSS/start-vss-gui.sh [--port PORT]
#
# Default port: 8765
# Open browser at http://<hypervisor-ip>:8765
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(realpath "$0")")" && pwd)"
PORT="${PORT:-8765}"

# Allow --port N override
while [[ $# -gt 0 ]]; do
  case $1 in
    --port) PORT="$2"; shift 2 ;;
    *) echo "Unknown arg: $1"; exit 1 ;;
  esac
done

cd "$SCRIPT_DIR"

# ── Activate venv if present ──────────────────────────────────────────────────
if [[ -f ".venv/vssenv/bin/activate" ]]; then
  # shellcheck disable=SC1091
  source ".venv/vssenv/bin/activate"
  echo "[start-vss-gui] Using venv: .venv/vssenv"
elif command -v conda &>/dev/null && conda info --envs 2>/dev/null | grep -q base; then
  echo "[start-vss-gui] Using conda base Python"
else
  echo "[start-vss-gui] Using system Python: $(which python3)"
fi

# ── Install FastAPI + Uvicorn if not already present ─────────────────────────
if ! python3 -c "import fastapi, uvicorn" &>/dev/null; then
  echo "[start-vss-gui] Installing fastapi and uvicorn[standard] ..."
  pip3 install --quiet fastapi "uvicorn[standard]"
fi

# ── Install mssql-python + prometheus deps if not already present ─────────────
if ! python3 -c "import mssql_python" &>/dev/null; then
  echo "[start-vss-gui] Installing mssql-python (Microsoft's official driver) ..."
  pip3 install --quiet mssql-python
fi
if ! python3 -c "import prometheus_client, prometheus_fastapi_instrumentator" &>/dev/null; then
  echo "[start-vss-gui] Installing prometheus-client + prometheus-fastapi-instrumentator ..."
  pip3 install --quiet prometheus-client prometheus-fastapi-instrumentator
fi

# ── Derive local IP for convenience ──────────────────────────────────────────
LOCAL_IP=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "localhost")

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║   VSS Backup & Restore Web Console                  ║"
echo "║                                                      ║"
echo "║   http://${LOCAL_IP}:${PORT}"
printf   "║   http://localhost:%-35s║\n" "${PORT}"
echo "╚══════════════════════════════════════════════════════╝"
echo ""
echo "  Press Ctrl+C to stop."
echo ""

# ── Start Uvicorn ─────────────────────────────────────────────────────────────
exec python3 -m uvicorn vss_api.server:app \
  --host 0.0.0.0 \
  --port "$PORT" \
  --log-level info
