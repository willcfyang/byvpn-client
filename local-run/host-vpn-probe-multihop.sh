#!/usr/bin/env bash
# Probe with multihop-friendly routing: mock on Wi-Fi, exit GW via tun0, probe via tun1.
# No table-333 split (vpnd already installs NYM_VPN_LAB_ROUTE_CIDRS in main).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
export PATH="${ROOT}/bin:${PATH}"
export NYM_VPND_CONFIG_DIR="${ROOT}/config/nym"
export NYM_VPND_DATA_DIR="${ROOT}/data"
LOG="${ROOT}/log/host-probe-multihop.log"
OCEAN="${ROOT}/../../../onidel-cloud/scripts"
ENTRY_IP="${ENTRY_IP:-104.250.122.199}"
EXIT_GW_IP="${EXIT_GW_IP:-160.22.79.198}"
MNEMONIC="${MNEMONIC:-dash hungry rate famous lesson march suit refuse excite soul faith bid buddy tortoise melody advice dirt coffee fluid sure air decrease cargo work}"

export NYM_VPN_LAB_PHYSICAL_DEFAULT=1
export NYM_VPN_LAB_ROUTE_CIDRS="${NYM_VPN_LAB_ROUTE_CIDRS:-10.1.0.0/16 1.1.1.1/32}"
export NYM_VPN_LAB_PROBE_IP="${NYM_VPN_LAB_PROBE_IP:-1.1.1.1}"
export NYM_VPN_LAB_SKIP_CONNECTION_PROBE=0
# Mock only on Wi-Fi — exit WG must use entry tun (multihop).
export PHYSICAL_BYPASS_CIDRS="${PHYSICAL_BYPASS_CIDRS:-104.250.122.199/32 192.168.5.0/24 192.168.122.0/24}"
# Do not bypass 160.22.79.198 — exit GW must route via entry tun for multihop data plane.

PROBE_CLEANUP_RAN=0
probe_cleanup() {
  [[ "${PROBE_CLEANUP_RAN}" == "1" ]] && return 0
  PROBE_CLEANUP_RAN=1
  echo "=== multihop probe cleanup (restore Wi-Fi / Cursor) ==="
  sudo bash "${OCEAN}/nym-vpn-local-cleanup.sh" || true
}
trap probe_cleanup EXIT INT TERM HUP

sudo bash "${OCEAN}/nym-vpn-local-cleanup.sh" >/dev/null 2>&1 || true
PROBE_CLEANUP_RAN=0
sudo killall -9 nym-vpnd nym-vpnc 2>/dev/null || true
sleep 2
: >"${LOG}"

ssh -o BatchMode=yes "root@${ENTRY_IP}" \
  "timeout 200 tcpdump -ni nymwg51822 -ni nymwg51823 icmp -l 2>/dev/null" \
  >"${ROOT}/log/host-probe-multihop-tcpdump.txt" 2>&1 &
TCPDUMP_PID=$!
sleep 1

sudo bash "${OCEAN}/vpn-sf-enable-colocated-wg-forward.sh" >/dev/null 2>&1 || true
sudo bash "${OCEAN}/nym-vpn-lab-split-routing.sh" apply-physical >/dev/null 2>&1 || true

echo "=== multihop probe: vpnd (no table-333 split watch) ==="
sudo env \
  NYM_VPND_CONFIG_DIR="${NYM_VPND_CONFIG_DIR}" \
  NYM_VPND_DATA_DIR="${NYM_VPND_DATA_DIR}" \
  NYM_VPN_LAB_PHYSICAL_DEFAULT=1 \
  NYM_VPN_LAB_ROUTE_CIDRS="${NYM_VPN_LAB_ROUTE_CIDRS}" \
  NYM_VPN_LAB_PROBE_IP="${NYM_VPN_LAB_PROBE_IP}" \
  NYM_VPN_LAB_SKIP_CONNECTION_PROBE=0 \
  RUST_LOG=nym_vpn_lib=info,nym_registration_client=info \
  "${ROOT}/bin/nym-vpnd" -vv run-with-args --disable-client-verification >>"${LOG}" 2>&1 &

for i in $(seq 1 30); do [[ -S /var/run/nym-vpn.sock ]] && break; sleep 1; done
for i in $(seq 1 45); do
  grep -q "Gateway cache and topology cache successfully updated" "${LOG}" && break
  sleep 1
done
nym-vpnc account set "${MNEMONIC}" >/dev/null 2>&1 || true
for i in $(seq 1 40); do
  nym-vpnc account get 2>&1 | grep -q ReadyToConnect && break
  sleep 2
done

nym-vpnc connect 2>/dev/null || true

for i in $(seq 1 90); do
  if ip link show tun0 &>/dev/null && ip link show tun1 &>/dev/null \
    && grep -q S9_register_wireguard_ok "${LOG}"; then
    sudo ip route replace "${EXIT_GW_IP}/32" dev tun0 metric 10 2>/dev/null || true
    break
  fi
  sleep 2
done

echo "--- routes ---"
ip route get "${EXIT_GW_IP}" 2>/dev/null || true
ip route get 1.1.1.1 2>/dev/null || true
ip -br a | grep tun || true

exit_tun=tun1
echo "=== ping -I ${exit_tun} 1.1.1.1 ==="
ping -c 4 -W 3 -I "${exit_tun}" 1.1.1.1 || true

wait "${TCPDUMP_PID}" 2>/dev/null || true
echo "=== tcpdump (first 30 lines) ==="
head -30 "${ROOT}/log/host-probe-multihop-tcpdump.txt" 2>/dev/null || true
echo "=== vpnd probe lines ==="
grep -iE 'viable|failing|S9_register' "${LOG}" | tail -12
nym-vpnc status 2>&1 | head -4

probe_cleanup
trap - EXIT INT TERM HUP
echo "=== done ==="
