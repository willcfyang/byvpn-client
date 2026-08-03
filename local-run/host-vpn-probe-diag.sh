#!/usr/bin/env bash
# Quick probe diagnostic: after WG up, test ICMP via exit tun + vpn.sf tcpdump snippet.
# Always cleans up on exit (including SIGTERM) so Wi-Fi / Cursor stay usable.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
MAX_TUN_WAIT="${MAX_TUN_WAIT:-45}"
WALL_CLOCK_SEC="${WALL_CLOCK_SEC:-150}"
export PATH="${ROOT}/bin:${PATH}"
export NYM_VPND_CONFIG_DIR="${ROOT}/config/nym"
export NYM_VPND_DATA_DIR="${ROOT}/data"
LOG="${ROOT}/log/host-probe-diag.log"
OCEAN="${ROOT}/../../../onidel-cloud/scripts"
ENTRY_IP="${ENTRY_IP:-104.250.122.199}"
SSH_OPTS=(-o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10)
[[ -n "${SSH_IDENTITY_FILE:-}" ]] && SSH_OPTS+=(-i "${SSH_IDENTITY_FILE}")
MNEMONIC="${MNEMONIC:-dash hungry rate famous lesson march suit refuse excite soul faith bid buddy tortoise melody advice dirt coffee fluid sure air decrease cargo work}"

export NYM_VPN_LAB_PHYSICAL_DEFAULT=1
export NYM_VPN_LAB_ROUTE_CIDRS="${NYM_VPN_LAB_ROUTE_CIDRS:-10.1.0.0/16 1.1.1.1/32}"
export NYM_VPN_LAB_PROBE_IP="${NYM_VPN_LAB_PROBE_IP:-1.1.1.1}"
export NYM_VPN_LAB_SKIP_CONNECTION_PROBE=0

PROBE_TARGETS="${PROBE_TARGETS:-1.1.1.1 8.8.8.8 160.22.79.198}"

PROBE_CLEANUP_RAN=0
probe_cleanup() {
  [[ "${PROBE_CLEANUP_RAN}" == "1" ]] && return 0
  PROBE_CLEANUP_RAN=1
  echo "=== probe cleanup (restore Wi-Fi / Cursor) ==="
  sudo bash "${OCEAN}/nym-vpn-local-cleanup.sh" || true
}
trap probe_cleanup EXIT INT TERM HUP

sudo bash "${OCEAN}/nym-vpn-local-cleanup.sh" >/dev/null 2>&1 || true
PROBE_CLEANUP_RAN=0
sudo killall -9 nym-vpnd nym-vpnc 2>/dev/null || true
sleep 2
: >"${LOG}"

sudo bash "${OCEAN}/nym-vpn-lab-split-routing-watch.sh" stop 2>/dev/null || true
LAB_SPLIT_WATCH_INTERVAL=1 sudo bash "${OCEAN}/nym-vpn-lab-split-routing-watch.sh" start || true
sudo bash "${OCEAN}/vpn-sf-enable-colocated-wg-forward.sh" >/dev/null 2>&1 || true

echo "=== vpn.sf tcpdump (start before VPN — SSH blocked once nft output policy active) ==="
: >"${ROOT}/log/host-probe-tcpdump.txt"
ssh "${SSH_OPTS[@]}" "root@${ENTRY_IP}" \
  "timeout ${WALL_CLOCK_SEC} tcpdump -ni any -l '(udp port 51822 or udp port 51823 or icmp) and (host 160.22.79.198 or host 104.250.122.199 or net 10.1.0.0/16)' 2>/dev/null" \
  >>"${ROOT}/log/host-probe-tcpdump.txt" 2>&1 &
TCPDUMP_PID=$!
tcpdump_pid="${TCPDUMP_PID}"
sleep 1
if ! kill -0 "${tcpdump_pid}" 2>/dev/null; then
  echo "WARN: tcpdump failed to start (see ${ROOT}/log/host-probe-tcpdump.txt)"
  head -5 "${ROOT}/log/host-probe-tcpdump.txt" 2>/dev/null || true
  tcpdump_pid=
fi

echo "=== host probe diag: starting vpnd ==="
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

sudo bash "${OCEAN}/nym-vpn-lab-split-routing.sh" apply-physical >/dev/null 2>&1 || true
nym-vpnc connect 2>/dev/null || true

echo "=== waiting for tun1 + S9_register_wireguard_ok (max ${MAX_TUN_WAIT} polls) ==="
for i in $(seq 1 "${MAX_TUN_WAIT}"); do
  sudo bash "${OCEAN}/nym-vpn-lab-split-routing.sh" apply >/dev/null 2>&1 || \
    sudo bash "${OCEAN}/nym-vpn-lab-split-routing.sh" apply-physical >/dev/null 2>&1 || true
  if ip link show tun1 &>/dev/null && grep -q S9_register_wireguard_ok "${LOG}"; then
    break
  fi
  sleep 2
done

exit_tun="$(ip -o link show 2>/dev/null | awk -F': ' '/ tun[0-9]+:/ {print $2}' | sort -V | tail -1 | tr -d ' ')"
echo "exit_tun=${exit_tun:-none}"
ip route get 1.1.1.1 2>/dev/null || true

if [[ -z "${exit_tun}" ]]; then
  echo "FAIL: no exit tun"
  tail -30 "${LOG}"
  exit 1
fi

echo "=== nft tunnel rules (expect lab-tunnel-egress on ${exit_tun}) ==="
sudo nft list chain inet nym output 2>/dev/null | grep -E 'lab-tunnel|policy drop' | head -20 || echo "(no inet nym)"

echo "=== manual ICMP from host (vpn.sf tcpdump pid ${tcpdump_pid:-none}) ==="
tun_ip="$(ip -4 addr show dev "${exit_tun}" 2>/dev/null | awk '/inet / {print $2}' | head -1 | cut -d/ -f1)"
echo "exit_tun_ip=${tun_ip:-?}"
ip -br link | grep -E 'tun|wg' || true
for target in ${PROBE_TARGETS}; do
  echo -n "ping -I ${exit_tun} ${target}: "
  sudo timeout 8 tcpdump -ni "${UPLINK_DEV:-wlp0s20f3}" 'udp port 51822 or udp port 51823' -c 6 2>/dev/null &
  wlp_cap=$!
  sleep 0.5
  if ping -c 3 -W 3 -I "${exit_tun}" "${target}" 2>&1 | tail -2; then
    echo "  -> OK"
  else
    echo "  -> FAIL"
  fi
  ip route get "${target}" 2>/dev/null || true
  wait "${wlp_cap}" 2>/dev/null || true
done
if [[ -n "${tcpdump_pid:-}" ]]; then
  sleep 2
  kill "${tcpdump_pid}" 2>/dev/null || true
  wait "${tcpdump_pid}" 2>/dev/null || true
fi
echo "=== vpn.sf tcpdump (during ping) ==="
head -40 "${ROOT}/log/host-probe-tcpdump.txt" 2>/dev/null || echo "(no capture)"

echo "=== vpnd probe / viable lines ==="
grep -iE 'viable|failing|connection_probe|S9_register' "${LOG}" | tail -15

nym-vpnc status 2>&1 | head -5
echo "=== done (cleanup via EXIT trap) ==="
