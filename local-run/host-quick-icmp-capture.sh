#!/usr/bin/env bash
# Bring up WG (skip probe), capture ICMP on tun1 + vpn.sf nymwg51823, then cleanup.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
OCEAN="${ROOT}/../../../onidel-cloud/scripts"
export PATH="${ROOT}/bin:${PATH}"
export NYM_VPND_CONFIG_DIR="${ROOT}/config/nym"
export NYM_VPND_DATA_DIR="${ROOT}/data"
export NYM_VPN_LAB_PHYSICAL_DEFAULT=1
export NYM_VPN_LAB_ROUTE_CIDRS="10.1.0.0/16 1.1.1.1/32"
export NYM_VPN_LAB_SKIP_CONNECTION_PROBE=1
MNEMONIC="${MNEMONIC:-dash hungry rate famous lesson march suit refuse excite soul faith bid buddy tortoise melody advice dirt coffee fluid sure air decrease cargo work}"
SSH_IDENTITY="${SSH_IDENTITY_FILE:-${HOME}/.ssh/id_rsa}"
SSH_OPTS=(-o BatchMode=yes -o ConnectTimeout=10)
[[ -f "${SSH_IDENTITY}" ]] && SSH_OPTS+=(-i "${SSH_IDENTITY}")
LOG="${ROOT}/log/host-quick-icmp.log"
OUT="${ROOT}/log/host-quick-icmp-run.txt"

cleanup() {
  sudo bash "${OCEAN}/nym-vpn-local-cleanup.sh" >/dev/null 2>&1 || true
}
trap cleanup EXIT INT TERM

exec > >(tee "${OUT}") 2>&1

sudo bash "${OCEAN}/nym-vpn-local-cleanup.sh" >/dev/null 2>&1 || true
sudo bash "${OCEAN}/nym-vpn-lab-split-routing-watch.sh" stop 2>/dev/null || true
LAB_SPLIT_WATCH_INTERVAL=1 sudo bash "${OCEAN}/nym-vpn-lab-split-routing-watch.sh" start
bash "${OCEAN}/vpn-sf-enable-colocated-wg-forward.sh" >/dev/null

echo "=== vpn.sf icmp on entry+exit WG (start BEFORE VPN — nft blocks SSH) ==="
ssh "${SSH_OPTS[@]}" root@104.250.122.199 \
  "timeout 90 tcpdump -ni any 'icmp and (net 10.1.0.0/16 or host 1.1.1.1)' -c 20 2>&1" \
  >"${ROOT}/log/host-quick-vpn-sf-icmp.log" 2>&1 &
SF=$!
sleep 1
kill -0 "${SF}" 2>/dev/null || { echo "WARN: vpn.sf tcpdump failed"; head -3 "${ROOT}/log/host-quick-vpn-sf-icmp.log" || true; SF=""; }

: >"${LOG}"
sudo env \
  NYM_VPND_CONFIG_DIR="${NYM_VPND_CONFIG_DIR}" \
  NYM_VPND_DATA_DIR="${NYM_VPND_DATA_DIR}" \
  NYM_VPN_LAB_PHYSICAL_DEFAULT=1 \
  NYM_VPN_LAB_ROUTE_CIDRS="${NYM_VPN_LAB_ROUTE_CIDRS}" \
  NYM_VPN_LAB_SKIP_CONNECTION_PROBE=1 \
  "${ROOT}/bin/nym-vpnd" -vv run-with-args --disable-client-verification >>"${LOG}" 2>&1 &

for i in $(seq 1 30); do [[ -S /var/run/nym-vpn.sock ]] && break; sleep 1; done
[[ -S /var/run/nym-vpn.sock ]] || { echo "FAIL: no vpnd socket"; exit 1; }

for i in $(seq 1 45); do grep -q "Gateway cache" "${LOG}" && break; sleep 1; done
nym-vpnc account set "${MNEMONIC}" >/dev/null 2>&1 || true
for i in $(seq 1 30); do nym-vpnc account get 2>&1 | grep -q ReadyToConnect && break; sleep 2; done

sudo bash "${OCEAN}/nym-vpn-lab-split-routing.sh" apply-physical >/dev/null 2>&1 || true
nym-vpnc connect >/dev/null 2>&1 || true

for i in $(seq 1 30); do
  sudo bash "${OCEAN}/nym-vpn-lab-split-routing.sh" apply >/dev/null 2>&1 || true
  ip link show tun1 &>/dev/null && grep -q S9_register_wireguard_ok "${LOG}" && break
  sleep 2
done

echo "=== tun state ==="
ip -br addr show tun0 tun1 2>/dev/null || true
ip route get 1.1.1.1 || true
grep S9_register_wireguard_ok "${LOG}" | tail -1 || echo "WARN: no S9_register"

echo "=== local tun1 icmp (15s) ==="
sudo timeout 15 tcpdump -ni tun1 icmp -c 10 2>&1 &
LT=$!
sleep 1

echo "=== sudo ping -I tun1 1.1.1.1 ==="
sudo ping -c 3 -W 2 -I tun1 1.1.1.1 || true

wait "${LT}" 2>/dev/null || true

echo "=== vpn.sf capture ==="
cat "${ROOT}/log/host-quick-vpn-sf-icmp.log" 2>/dev/null || echo "(empty)"
[[ -n "${SF}" ]] && wait "${SF}" 2>/dev/null || true

echo "=== done ==="
trap - EXIT
cleanup
