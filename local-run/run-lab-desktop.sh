#!/usr/bin/env bash
# Start lab vpnd (vpn.sf mock discovery) + Ubuntu NymVPN app with lab username/password UI.
# Aligns with Android labmock APK (mock discovery + lab auth).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
CLIENT_ROOT="$(cd "${ROOT}/.." && pwd)"
APP_DIR="${CLIENT_ROOT}/nym-vpn-app"
DESKTOP_OUT="${DESKTOP_OUT:-/mnt/win/D/android-build/desktop}"

# Prefer ByVPN labmock rebuild; fall back to older nym-vpn-app paths.
APP_BIN="${APP_BIN:-}"
if [[ -z "${APP_BIN}" ]]; then
  if [[ -x "${DESKTOP_OUT}/ByVPN-labmock" ]]; then
    APP_BIN="${DESKTOP_OUT}/ByVPN-labmock"
  elif [[ -x "/mnt/win/D/android-build/desktop-target/release/nym-vpn-app" ]]; then
    APP_BIN="/mnt/win/D/android-build/desktop-target/release/nym-vpn-app"
  elif [[ -x "${APP_DIR}/src-tauri/target/release/nym-vpn-app" ]]; then
    APP_BIN="${APP_DIR}/src-tauri/target/release/nym-vpn-app"
  elif [[ -x "${DESKTOP_OUT}/nym-vpn-app" ]]; then
    APP_BIN="${DESKTOP_OUT}/nym-vpn-app"
  else
    echo "ByVPN / nym-vpn-app not found. Build with:" >&2
    echo "  cd ${APP_DIR} && LAB_MOCK=1 npm run tauri build -- --bundles deb" >&2
    exit 1
  fi
fi

# vpnd: mock config + skip viability probe (same as Android LabMockBootstrap)
export NYM_VPN_LAB_SKIP_CONNECTION_PROBE="${NYM_VPN_LAB_SKIP_CONNECTION_PROBE:-1}"
export NYM_VPN_LAB_PROBE_IP="${NYM_VPN_LAB_PROBE_IP:-104.250.122.199}"
export NYM_VPN_CONNECT="${NYM_VPN_CONNECT:-0}"
export NYM_VPN_SKIP_ACCOUNT_SET=1

echo "[lab-desktop] starting vpnd (mock discovery)..."
bash "${ROOT}/run-vpn.sh"

echo "[lab-desktop] launching app: ${APP_BIN}"
export NYM_VPN_APP_LAB_MOCK="${NYM_VPN_APP_LAB_MOCK:-1}"
export NYM_VPN_APP_LAB_AUTH_BASE_URL="${NYM_VPN_APP_LAB_AUTH_BASE_URL:-http://104.250.122.199:8088/api/public/v1/lab/auth}"

exec "${APP_BIN}" "$@"
