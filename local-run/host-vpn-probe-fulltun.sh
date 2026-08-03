#!/usr/bin/env bash
# Short full-tunnel probe (no split lab). Always cleans up (EXIT trap).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
export PATH="${ROOT}/bin:${PATH}"
export NYM_VPND_CONFIG_DIR="${ROOT}/config/nym"
export NYM_VPND_DATA_DIR="${ROOT}/data"
LOG="${ROOT}/log/host-probe-fulltun.log"
OCEAN="${ROOT}/../../../onidel-cloud/scripts"
MNEMONIC="${MNEMONIC:-dash hungry rate famous lesson march suit refuse excite soul faith bid buddy tortoise melody advice dirt coffee fluid sure air decrease cargo work}"

unset NYM_VPN_LAB_PHYSICAL_DEFAULT
export NYM_VPN_LAB_SKIP_CONNECTION_PROBE=0
export NYM_VPN_LAB_PROBE_IP="${NYM_VPN_LAB_PROBE_IP:-1.1.1.1}"

PROBE_CLEANUP_RAN=0
probe_cleanup() {
  [[ "${PROBE_CLEANUP_RAN}" == "1" ]] && return 0
  PROBE_CLEANUP_RAN=1
  echo "=== fulltun probe cleanup (restore Wi-Fi / Cursor) ==="
  sudo bash "${OCEAN}/nym-vpn-local-cleanup.sh" || true
}
trap probe_cleanup EXIT INT TERM HUP

sudo bash "${OCEAN}/nym-vpn-local-cleanup.sh" >/dev/null 2>&1 || true
PROBE_CLEANUP_RAN=0
: >"${LOG}"

sudo bash "${OCEAN}/vpn-sf-enable-colocated-wg-forward.sh" >/dev/null 2>&1 || true

sudo env \
  NYM_VPND_CONFIG_DIR="${NYM_VPND_CONFIG_DIR}" \
  NYM_VPND_DATA_DIR="${NYM_VPND_DATA_DIR}" \
  NYM_VPN_LAB_SKIP_CONNECTION_PROBE=0 \
  NYM_VPN_LAB_PROBE_IP="${NYM_VPN_LAB_PROBE_IP}" \
  RUST_LOG=nym_vpn_lib=info \
  "${ROOT}/bin/nym-vpnd" -vv run-with-args --disable-client-verification >>"${LOG}" 2>&1 &

for i in $(seq 1 30); do [[ -S /var/run/nym-vpn.sock ]] && break; sleep 1; done
nym-vpnc account set "${MNEMONIC}" >/dev/null 2>&1 || true
for i in $(seq 1 40); do nym-vpnc account get 2>&1 | grep -q ReadyToConnect && break; sleep 2; done
nym-vpnc connect 2>/dev/null || true

for i in $(seq 1 60); do
  if grep -q "Tunnel connection is viable" "${LOG}"; then echo "PASS: viable"; break; fi
  if grep -q "Tunnel connection is failing (retry: 3)" "${LOG}" && ! grep -q "S9_register_wireguard_ok" "${LOG}"; then
    sleep 2
  fi
  sleep 3
done

exit_tun="$(ip -o link show 2>/dev/null | awk -F': ' '/ tun[0-9]+:/ {print $2}' | sort -V | tail -1 | tr -d ' ')"
echo "exit_tun=${exit_tun:-none} route_get=$(ip route get 1.1.1.1 2>/dev/null || true)"
[[ -n "${exit_tun}" ]] && ping -c 2 -W 3 -I "${exit_tun}" 1.1.1.1 || true
grep -iE 'viable|failing|S9_register|PHYSICAL' "${LOG}" | tail -8
nym-vpnc status 2>&1 | head -3
probe_cleanup
trap - EXIT INT TERM HUP
echo "=== done ==="
