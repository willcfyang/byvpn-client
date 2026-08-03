#!/usr/bin/env bash
# Full host split-lab connection test (C5-equivalent on laptop):
#   mock + account + connect + real vpnd probe + ICMP + HTTPS (probe + ipify) via exit tun.
#
#   cd 6/nym-vpn-client/local-run
#   bash host-vpn-full-connection-test.sh
#
# Env: same as host-vpn-lab-connect.sh; forces NYM_VPN_LAB_SKIP_CONNECTION_PROBE=0.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
export PATH="${ROOT}/bin:${PATH}"

export NYM_VPN_LAB_SKIP_CONNECTION_PROBE=0
export NYM_VPN_LAB_PHYSICAL_DEFAULT="${NYM_VPN_LAB_PHYSICAL_DEFAULT:-1}"
export NYM_VPN_LAB_ROUTE_CIDRS="${NYM_VPN_LAB_ROUTE_CIDRS:-10.1.0.0/16 1.1.1.1/32}"
export NYM_VPN_LAB_PROBE_IP="${NYM_VPN_LAB_PROBE_IP:-1.1.1.1}"
export MAX_CONNECT_ATTEMPTS="${MAX_CONNECT_ATTEMPTS:-3}"

LOG="${ROOT}/log/host-full-connection-test.txt"
: >"${LOG}"

echo "=== host full connection test $(date -Is) ===" | tee -a "${LOG}"
echo "log: ${LOG}" | tee -a "${LOG}"
echo "probe skip: ${NYM_VPN_LAB_SKIP_CONNECTION_PROBE} (must be 0)" | tee -a "${LOG}"

exec bash "${ROOT}/host-vpn-lab-connect.sh" 2>&1 | tee -a "${LOG}"
