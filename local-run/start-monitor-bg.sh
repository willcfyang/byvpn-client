#!/usr/bin/env bash
# Start status/log monitor in background (vpnd may already be running).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
chmod +x "${ROOT}/monitor.sh"
nohup "${ROOT}/monitor.sh" >> "${ROOT}/log/monitor.log" 2>&1 &
echo $! > "${ROOT}/monitor.pid"
echo "monitor pid $(cat "${ROOT}/monitor.pid"), log: ${ROOT}/log/monitor.log"
