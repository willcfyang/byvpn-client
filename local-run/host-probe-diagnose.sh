#!/usr/bin/env bash
# Quick check: Connected with probe skip, then ping 1.1.1.1 via exit tun.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
export PATH="${ROOT}/bin:${PATH}"
export NYM_VPND_CONFIG_DIR="${ROOT}/config/nym"
export NYM_VPND_DATA_DIR="${ROOT}/data"
export NYM_VPN_LAB_PHYSICAL_DEFAULT=1
export NYM_VPN_LAB_ROUTE_CIDRS="${NYM_VPN_LAB_ROUTE_CIDRS:-10.1.0.0/16 1.1.1.1/32}"
export NYM_VPN_LAB_SKIP_CONNECTION_PROBE=1
MNEMONIC="${MNEMONIC:-dash hungry rate famous lesson march suit refuse excite soul faith bid buddy tortoise melody advice dirt coffee fluid sure air decrease cargo work}"

sudo killall -9 nym-vpnd nym-vpnc 2>/dev/null || true
sleep 2
sudo env NYM_VPND_CONFIG_DIR="${NYM_VPND_CONFIG_DIR}" NYM_VPND_DATA_DIR="${NYM_VPND_DATA_DIR}" \
  NYM_VPN_LAB_PHYSICAL_DEFAULT=1 NYM_VPN_LAB_ROUTE_CIDRS="${NYM_VPN_LAB_ROUTE_CIDRS}" \
  NYM_VPN_LAB_SKIP_CONNECTION_PROBE=1 \
  "${ROOT}/bin/nym-vpnd" -vv run-with-args --disable-client-verification \
  >>"${ROOT}/log/host-probe-diag.log" 2>&1 &
for i in $(seq 1 30); do [[ -S /var/run/nym-vpn.sock ]] && break; sleep 1; done
nym-vpnc account set "${MNEMONIC}" >/dev/null 2>&1 || true
for i in $(seq 1 40); do
  nym-vpnc account get 2>&1 | grep -q ReadyToConnect && break
  sleep 2
done
nym-vpnc connect
for i in $(seq 1 60); do
  nym-vpnc status 2>&1 | grep -q "State: Connected" && break
  sleep 3
done
nym-vpnc status | head -5
tun="$(ip -o link | awk '/tun1/ {print $2}' | tr -d ':')"
echo "exit tun=${tun}"
ping -c 3 -W 2 -I "${tun}" 1.1.1.1 || echo "PING FAIL"
sudo bash "${ROOT}/../../onidel-cloud/scripts/nym-vpn-local-cleanup.sh" 2>/dev/null || true
