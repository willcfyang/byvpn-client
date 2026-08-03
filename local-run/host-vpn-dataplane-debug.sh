#!/usr/bin/env bash
# Data-plane debug: host connect + optional vpn.sf tcpdump on exit WG.
# Usage:
#   cd 6/nym-vpn-client/local-run
#   bash host-vpn-dataplane-debug.sh
#   SKIP_VPN_SF_TCPDUMP=1 bash host-vpn-dataplane-debug.sh   # host-only
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
OCEAN="${ROOT}/../../../onidel-cloud/scripts"
ENTRY_IP="${ENTRY_IP:-104.250.122.199}"
TCPDUMP_LOG="${ROOT}/log/vpn-sf-exit-icmp.log"
PROBE_LOG="${ROOT}/log/host-dataplane-probe.log"

: >"${PROBE_LOG}"

run_tcpdump() {
  ssh -o BatchMode=yes -o ConnectTimeout=10 "root@${ENTRY_IP}" \
    "timeout 300 tcpdump -ni nymwg51823 icmp -c 40 2>&1" >>"${TCPDUMP_LOG}" 2>&1 || true
}

if [[ "${SKIP_VPN_SF_TCPDUMP:-0}" != "1" ]]; then
  : >"${TCPDUMP_LOG}"
  run_tcpdump &
  TCPDUMP_PID=$!
  echo "[dataplane] vpn.sf tcpdump pid ${TCPDUMP_PID} -> ${TCPDUMP_LOG}"
else
  TCPDUMP_PID=""
fi

cleanup_tcpdump() {
  [[ -n "${TCPDUMP_PID}" ]] && kill "${TCPDUMP_PID}" 2>/dev/null || true
}
trap cleanup_tcpdump EXIT

# Matrix: default 1.1.1.1 (guest parity), optional exit IP
for probe in "${NYM_VPN_LAB_PROBE_IP:-1.1.1.1}"; do
  export NYM_VPN_LAB_PROBE_IP="${probe}"
  export NYM_VPN_LAB_ROUTE_CIDRS="${NYM_VPN_LAB_ROUTE_CIDRS:-10.1.0.0/16 1.1.1.1/32}"
  export MAX_POLLS="${MAX_POLLS:-30}"
  export MAX_CONNECT_ATTEMPTS="${MAX_CONNECT_ATTEMPTS:-3}"
  echo "[dataplane] === probe IP ${probe} ===" | tee -a "${PROBE_LOG}"
  if bash "${ROOT}/host-vpn-lab-connect.sh" 2>&1 | tee -a "${PROBE_LOG}"; then
    echo "[dataplane] SUCCESS with probe ${probe}" | tee -a "${PROBE_LOG}"
    exit 0
  fi
  echo "[dataplane] failed with probe ${probe}" | tee -a "${PROBE_LOG}"
done

echo "[dataplane] all probes failed; see ${PROBE_LOG} and ${TCPDUMP_LOG}"
exit 1
