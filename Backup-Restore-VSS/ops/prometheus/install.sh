#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# install.sh  —  Append the VSS API scrape config to /etc/prometheus/prometheus.yml
#                and reload the prometheus service.
#
# Idempotent: if a `- job_name: vss_api` entry is already present, does nothing.
# Requires: sudo (password prompt allowed).
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

HERE="$(cd "$(dirname "$(realpath "$0")")" && pwd)"
SNIPPET="$HERE/vss-api.scrape.yml"
TARGET=/etc/prometheus/prometheus.yml
STAMP="$(date +%Y%m%d-%H%M%S)"

if ! sudo test -r "$TARGET"; then
  echo "[install] ERROR: $TARGET not readable. Is prometheus installed?" >&2
  exit 1
fi

if sudo grep -qE '^\s*-\s*job_name:\s*["'\'']?vss_api' "$TARGET"; then
  echo "[install] vss_api job already present in $TARGET — nothing to do."
  exit 0
fi

# 1. Back up the current file
sudo cp "$TARGET" "$TARGET.bak-$STAMP"
echo "[install] backup: $TARGET.bak-$STAMP"

# 2. Append the scrape config
sudo tee -a "$TARGET" >/dev/null <"$SNIPPET"
echo "[install] appended $SNIPPET → $TARGET"

# 3. Validate new config with promtool if available
if command -v promtool >/dev/null 2>&1; then
  if ! sudo promtool check config "$TARGET"; then
    echo "[install] ERROR: promtool rejected the new config — rolling back." >&2
    sudo mv "$TARGET.bak-$STAMP" "$TARGET"
    exit 2
  fi
fi

# 4. Reload prometheus (SIGHUP is safer than restart)
if systemctl is-active --quiet prometheus; then
  sudo systemctl reload prometheus \
    || sudo systemctl restart prometheus
  echo "[install] prometheus reloaded."
else
  echo "[install] WARN: prometheus is not running; skipping reload."
fi

echo "[install] done. Check http://localhost:9091/targets for the new job."
