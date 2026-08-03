#!/usr/bin/env bash
# Start nym-vpnd for lab (vpn.sf mock API). Does NOT connect by default — avoids breaking host network.
# To connect on this machine: NYM_VPN_CONNECT=1 bash run-vpn.sh  (or bash run-vpn-connect-lab.sh)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
BIN="${ROOT}/bin"
export PATH="${BIN}:${PATH}"

export NYM_VPND_CONFIG_DIR="${ROOT}/config/nym"
export NYM_VPND_DATA_DIR="${ROOT}/data"
export NYM_VPND_LOG_DIR="${ROOT}/log"

# Extra tracing beyond -v / -vv (vpnd: -v=DEBUG, -vv=TRACE)
export RUST_LOG="${RUST_LOG:-nym_vpn_lib=debug,nym_vpn_account_controller=debug,nym_vpn_api_client=debug,nym_vpn_network_config=debug,nym_vpnd=debug}"

python3 "${ROOT}/seed-cache.py"

mkdir -p "${NYM_VPND_DATA_DIR}/mainnet" "${NYM_VPND_LOG_DIR}"

VPND_LOG="${ROOT}/log/vpnd-foreground.log"
MONITOR_LOG="${ROOT}/log/monitor.log"

if ! sudo -n true 2>/dev/null; then
  echo "[run-vpn] sudo needs a password. Run this script in your terminal (not headless CI), or add NOPASSWD for nym-vpnd."
  echo "  cd ${ROOT} && bash run-vpn.sh"
  exit 1
fi

echo "[run-vpn] stopping old processes..."
sudo killall nym-vpnd 2>/dev/null || true
sleep 1
sudo rm -f /var/run/nym-vpn.sock

# Lab: physical default + only NYM_VPN_LAB_ROUTE_CIDRS via tun (requires vpnd built with route_handler patch)
export NYM_VPN_LAB_PHYSICAL_DEFAULT="${NYM_VPN_LAB_PHYSICAL_DEFAULT:-1}"
export NYM_VPN_LAB_ROUTE_CIDRS="${NYM_VPN_LAB_ROUTE_CIDRS:-10.1.0.0/16}"

LAB_SPLIT="${ROOT}/../../onidel-cloud/scripts/nym-vpn-lab-split-routing.sh"
LAB_WATCH="${ROOT}/../../onidel-cloud/scripts/nym-vpn-lab-split-routing-watch.sh"
# Watchdog only when explicitly connecting (full tunnel fight + nft fixes)
if [[ "${NYM_VPN_CONNECT:-}" == "1" && "${NYM_VPN_LAB_PHYSICAL_DEFAULT}" == "1" && -x "${LAB_WATCH}" ]]; then
  echo "[run-vpn] starting lab split routing watchdog..."
  sudo bash "${LAB_WATCH}" stop 2>/dev/null || true
  sudo bash "${LAB_WATCH}" start || true
fi

echo "[run-vpn] starting nym-vpnd (-vv = TRACE, run-with-args for CLI client)..."
# Lab helpers (Android labmock parity). Override via env; default leave unset.
export NYM_VPN_LAB_SKIP_CONNECTION_PROBE="${NYM_VPN_LAB_SKIP_CONNECTION_PROBE:-}"
export NYM_VPN_LAB_PROBE_IP="${NYM_VPN_LAB_PROBE_IP:-}"

sudo env \
  NYM_VPN_LAB_PHYSICAL_DEFAULT="${NYM_VPN_LAB_PHYSICAL_DEFAULT}" \
  NYM_VPN_LAB_ROUTE_CIDRS="${NYM_VPN_LAB_ROUTE_CIDRS}" \
  NYM_VPN_LAB_SKIP_CONNECTION_PROBE="${NYM_VPN_LAB_SKIP_CONNECTION_PROBE}" \
  NYM_VPN_LAB_PROBE_IP="${NYM_VPN_LAB_PROBE_IP}" \
  NYM_VPND_CONFIG_DIR="${NYM_VPND_CONFIG_DIR}" \
  NYM_VPND_DATA_DIR="${NYM_VPND_DATA_DIR}" \
  NYM_VPND_LOG_DIR="${NYM_VPND_LOG_DIR}" \
  RUST_LOG="${RUST_LOG}" \
  "${BIN}/nym-vpnd" -vv run-with-args --disable-client-verification \
  >> "${VPND_LOG}" 2>&1 &
VPND_PID=$!
echo "${VPND_PID}" > "${ROOT}/vpnd.pid"

for i in $(seq 1 30); do
  if [[ -S /var/run/nym-vpn.sock ]]; then
    echo "[run-vpn] RPC socket ready"
    break
  fi
  if ! kill -0 "${VPND_PID}" 2>/dev/null; then
    echo "[run-vpn] vpnd exited early; tail ${VPND_LOG}:"
    tail -30 "${VPND_LOG}" || true
    exit 1
  fi
  sleep 1
done

if [[ ! -S /var/run/nym-vpn.sock ]]; then
  echo "[run-vpn] socket not created; see ${VPND_LOG}"
  exit 1
fi

echo "[run-vpn] configuring client..."
nym-vpnc network set mainnet
nym-vpnc tunnel set --two-hop on
nym-vpnc gateway set \
  --entry-id 3yJCWPL4X8KXNH86gYpP5LmN165Rru2jAEyxiWr9vQyP \
  --exit-id D5p6S6wiPvGYfJme5dkGvPgvcMo7Jq7FPQga3Dhhn2Vf

if [[ "${NYM_VPN_SKIP_ACCOUNT_SET:-}" == "1" ]]; then
  echo "[run-vpn] skipping account set (desktop lab UI will login)"
else
  echo "[run-vpn] account set (integration-test mnemonic)..."
  nym-vpnc account set "dash hungry rate famous lesson march suit refuse excite soul faith bid buddy tortoise melody advice dirt coffee fluid sure air decrease cargo work" || true
  nym-vpnc account get || true
fi

if [[ "${NYM_VPN_CONNECT:-}" == "1" ]]; then
  echo "[run-vpn] connect (NYM_VPN_CONNECT=1)..."
  nym-vpnc connect 2>&1 | tee -a "${ROOT}/log/connect.log" || true
  if [[ -x "${LAB_SPLIT:-}" ]]; then
    sleep 2
    sudo bash "${LAB_SPLIT}" apply || echo "[run-vpn] warn: lab split apply failed"
  fi
  echo "[run-vpn] starting monitor (background)..."
  nohup "${ROOT}/monitor.sh" >> "${MONITOR_LOG}" 2>&1 &
  echo $! > "${ROOT}/monitor.pid"
else
  echo "[run-vpn] vpnd ready — NOT connecting (safe for Cursor on this host)."
  echo "  Full tunnel test: NYM_VPN_CONNECT=1 bash run-vpn.sh"
  echo "  Or use KVM guest: onidel-cloud/scripts/kvm-guest-connect-test.sh"
fi

nym-vpnc status || true
echo "[run-vpn] logs: ${VPND_LOG} and ${MONITOR_LOG}"
