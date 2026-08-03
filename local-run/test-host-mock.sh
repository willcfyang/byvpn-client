#!/usr/bin/env bash
# Validate patched nym-vpn-client on THIS host against vpn.sf mock API.
# Does not SSH to KVM guest. SOCKS is optional; account + mock bootstrap is the gate.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
BIN="${ROOT}/bin"
export PATH="${BIN}:${PATH}"
export NYM_VPND_CONFIG_DIR="${ROOT}/config/nym"
export NYM_VPND_DATA_DIR="${ROOT}/data"
export NYM_VPND_LOG_DIR="${ROOT}/log"
LOG="${ROOT}/log/host-mock-test.log"
OCEAN_SCRIPTS="${ROOT}/../../../onidel-cloud/scripts"
LAB_SPLIT="${OCEAN_SCRIPTS}/nym-vpn-lab-split-routing.sh"
LAB_WATCH="${OCEAN_SCRIPTS}/nym-vpn-lab-split-routing-watch.sh"
LAB_CLEANUP="${OCEAN_SCRIPTS}/nym-vpn-local-cleanup.sh"
VPN_SF_PREFLIGHT="${OCEAN_SCRIPTS}/vpn-sf-preflight.sh"
VPN_SF_FORWARD="${OCEAN_SCRIPTS}/vpn-sf-enable-colocated-wg-forward.sh"

detect_exit_tun() {
  ip -o link show 2>/dev/null | awk -F': ' '/ tun[0-9]+:/ {print $2}' | sort -V | tail -1 | tr -d ' '
}

host_test_cleanup() {
  [[ "${HOST_TEST_CLEANUP_RAN:-0}" == "1" ]] && return 0
  HOST_TEST_CLEANUP_RAN=1
  echo "[host-test] trap cleanup..."
  sudo bash "${LAB_CLEANUP}" 2>/dev/null || true
}
MNEMONIC="${MNEMONIC:-dash hungry rate famous lesson march suit refuse excite soul faith bid buddy tortoise melody advice dirt coffee fluid sure air decrease cargo work}"
EXIT_ID="${EXIT_ID:-D5p6S6wiPvGYfJme5dkGvPgvcMo7Jq7FPQga3Dhhn2Vf}"
ENTRY_ID="${ENTRY_ID:-3yJCWPL4X8KXNH86gYpP5LmN165Rru2jAEyxiWr9vQyP}"

pass() { echo "[PASS] $*"; }
fail() { echo "[FAIL] $*"; exit 1; }

echo "=== Host mock client test ($(hostname)) ==="

curl -fsS --connect-timeout 5 http://104.250.122.199:8088/healthz >/dev/null && pass "mock API reachable" || fail "mock API unreachable"

for h in '104.250.122.199 vpn.sf-entry' '160.22.79.198 vpn.sf-exit' '194.182.169.49 rpc.nymtech.net'; do
  grep -qF "${h#* }" /etc/hosts 2>/dev/null || echo "$h" | sudo tee -a /etc/hosts >/dev/null
done
pass "/etc/hosts pins for gateways"

# Optional: seed-cache rewrites mainnet.json from live API and can destabilize account sync.
# Use bundled config/nym/networks/mainnet/*.json unless discovery is not mock.
if ! grep -q '104.250.122.199' "${ROOT}/config/nym/networks/mainnet/mainnet_discovery.json" 2>/dev/null; then
  python3 "${ROOT}/seed-cache.py" || fail "seed-cache.py failed"
fi

sudo killall -9 nym-vpnd nym-vpnc nym-socks5-proxy 2>/dev/null || true
sudo pkill -9 -f "${BIN}/nym-vpnd" 2>/dev/null || true
sudo fuser -k 1080/tcp 10800/tcp 1081/tcp 2>/dev/null || true
sleep 3
pgrep -x nym-vpnd >/dev/null && fail "nym-vpnd still running after kill"
sudo rm -f /var/run/nym-vpn.sock
# Full data wipe (guest parity). Partial cleanup + account forget leaves unregistered errors.
rm -rf "${NYM_VPND_DATA_DIR}/mainnet" 2>/dev/null || true
mkdir -p "${NYM_VPND_DATA_DIR}/mainnet"

: >"${LOG}"
VPND_ENV=(
  "NYM_VPND_CONFIG_DIR=${NYM_VPND_CONFIG_DIR}"
  "NYM_VPND_DATA_DIR=${NYM_VPND_DATA_DIR}"
  "RUST_LOG=nym_vpn_lib=info,nym_vpn_account_controller=info,nym_registration_client=info"
)
if [[ "${TEST_CONNECT:-0}" == "1" ]]; then
  export NYM_VPN_LAB_PHYSICAL_DEFAULT="${NYM_VPN_LAB_PHYSICAL_DEFAULT:-1}"
  # Do NOT route 104.250.122.199 (entry WG) via exit tun — breaks handshake/DNS/Cursor.
  # Probe/data via 1.1.1.1 (same as guest C5); route only /32 so WLAN DNS stays default.
  export NYM_VPN_LAB_ROUTE_CIDRS="${NYM_VPN_LAB_ROUTE_CIDRS:-10.1.0.0/16 1.1.1.1/32}"
  export NYM_VPN_LAB_PROBE_IP="${NYM_VPN_LAB_PROBE_IP:-1.1.1.1}"
  export NYM_VPN_LAB_SKIP_CONNECTION_PROBE="${NYM_VPN_LAB_SKIP_CONNECTION_PROBE:-0}"
  trap host_test_cleanup EXIT INT TERM
  VPND_ENV+=(
    "NYM_VPN_LAB_PHYSICAL_DEFAULT=${NYM_VPN_LAB_PHYSICAL_DEFAULT}"
    "NYM_VPN_LAB_ROUTE_CIDRS=${NYM_VPN_LAB_ROUTE_CIDRS}"
    "NYM_VPN_LAB_PROBE_IP=${NYM_VPN_LAB_PROBE_IP}"
    "NYM_VPN_LAB_SKIP_CONNECTION_PROBE=${NYM_VPN_LAB_SKIP_CONNECTION_PROBE}"
  )
  if [[ -x "${LAB_WATCH}" ]]; then
    sudo bash "${LAB_WATCH}" stop 2>/dev/null || true
    LAB_SPLIT_WATCH_INTERVAL=1 sudo bash "${LAB_WATCH}" start || true
  fi
  echo "[host-test] TEST_CONNECT=1 — vpnd with lab split routing env"
else
  echo "[host-test] starting vpnd (no network set — use bundled mock discovery)"
fi
sudo env "${VPND_ENV[@]}" \
  "${BIN}/nym-vpnd" -vv run-with-args --disable-client-verification \
  >>"${LOG}" 2>&1 &

for i in $(seq 1 30); do
  [[ -S /var/run/nym-vpn.sock ]] && break
  sleep 1
done
[[ -S /var/run/nym-vpn.sock ]] && pass "vpnd RPC socket" || fail "vpnd socket missing (see ${LOG})"
for i in $(seq 1 45); do
  grep -q "Gateway cache and topology cache successfully updated" "${LOG}" 2>/dev/null && break
  sleep 1
done
grep -q "Gateway cache and topology cache successfully updated" "${LOG}" \
  || fail "vpnd topology/bootstrap not ready (see ${LOG})"
sleep 3

# Do NOT run: nym-vpnc network set mainnet  (restarts / desyncs vpnd)
# Gateways + two-hop are already in config/nym/nym-vpnd.json. gateway set here races
# discovery refresh (nymvpn.com DNS) and can flip account sync to production → unregistered.
pass "using lab gateways from nym-vpnd.json (entry=${ENTRY_ID:0:8}…)"

# Do not account forget here — it hits production unregister and poisons state.
nym-vpnc account set "${MNEMONIC}" | tail -1
for i in $(seq 1 60); do
  if nym-vpnc account get 2>&1 | grep -q "Account state: ReadyToConnect"; then
    pass "account ReadyToConnect (mock API + zknym path)"
    break
  fi
  if nym-vpnc account get 2>&1 | grep -q "Account state: Error"; then
    sleep 5
    nym-vpnc account get 2>&1 | grep -q "Account state: ReadyToConnect" && break
    nym-vpnc account get
    fail "account error (see ${LOG}; try: rm -rf ${NYM_VPND_DATA_DIR}/mainnet)"
  fi
  sleep 3
done
nym-vpnc account get 2>&1 | grep -q "ReadyToConnect" || fail "account not ReadyToConnect"

if [[ "${TEST_SOCKS:-1}" == "1" ]]; then
  nym-vpnc socks5 disable 2>/dev/null || true
  sleep 1
  nym-vpnc socks5 enable --socks5-address=127.0.0.1:10800 --exit-id "${EXIT_ID}"
  sleep 12
  ip="$(curl -4 -m 90 --socks5-hostname 127.0.0.1:10800 -sS https://api.ipify.org 2>/dev/null || true)"
  if [[ -n "${ip}" ]]; then
    pass "SOCKS egress on host: ${ip}"
  else
    echo "[WARN] SOCKS listen OK but curl timed out (mixnet path); account/mock still validated"
    grep -iE 'mixnet backend|10800|error' "${LOG}" | tail -8 || true
  fi
fi

if [[ "${TEST_CONNECT:-0}" == "1" ]]; then
  echo "[host-test] TEST_CONNECT=1 — full 2-hop VPN on THIS host"
  if [[ "${SKIP_VPN_SF_PREFLIGHT:-0}" != "1" ]] && [[ -f "${VPN_SF_PREFLIGHT}" ]]; then
    bash "${VPN_SF_PREFLIGHT}" || fail "vpn.sf preflight failed"
    pass "vpn.sf preflight"
  fi
  if [[ "${SKIP_VPN_SF_FORWARD:-0}" != "1" ]] && [[ -f "${VPN_SF_FORWARD}" ]]; then
    bash "${VPN_SF_FORWARD}" || fail "vpn.sf colocated WG forward failed"
    pass "vpn.sf colocated forward"
  fi
  sleep 15
  nym-vpnc socks5 disable 2>/dev/null || true
  nym-vpnc connect 2>&1 | tee -a "${ROOT}/log/host-connect.log" || true
  if [[ -x "${LAB_SPLIT}" ]]; then
    split_ok=0
    for _ in $(seq 1 24); do
      if sudo bash "${LAB_SPLIT}" apply; then
        split_ok=1
        break
      fi
      sleep 5
    done
    [[ "${split_ok}" == "1" ]] || fail "lab split routing apply failed (see ${OCEAN_SCRIPTS}/nym-vpn-lab-split-watch.log)"
    pass "lab split routing applied"
  fi
  # IP-only: 1.1.1.1/32 via tun breaks DNS name resolution until tunnel is viable.
  VPND_LOG="${LOG}" MONITOR_INTERVAL=5 MAX_CONNECT_ATTEMPTS="${MAX_CONNECT_ATTEMPTS:-5}" \
    bash "${ROOT}/monitor.sh" && pass "VPN Connected (2-hop)" || fail "connect did not reach Connected (see ${LOG})"
  curl -4 -m 8 -sS -o /dev/null --connect-timeout 5 http://142.250.191.14/ \
    && pass "physical uplink OK after Connected (WLAN path)" \
    || fail "physical uplink broken after Connected"
  grep -q "lab.connection_probe_ip\|Tunnel connection is viable" "${LOG}" \
    || fail "no real viability in log (probe skip or never viable — see ${LOG})"
  if grep -q "lab.skip_connection_probe" "${LOG}"; then
    fail "connected with NYM_VPN_LAB_SKIP_CONNECTION_PROBE=1 — want real probe (set SKIP=0)"
  fi
  exit_tun="$(detect_exit_tun)"
  if [[ -n "${exit_tun}" ]]; then
    ping -c 2 -W 3 -I "${exit_tun}" "${NYM_VPN_LAB_PROBE_IP}" >/dev/null \
      && pass "ICMP via ${exit_tun} → ${NYM_VPN_LAB_PROBE_IP}" \
      || fail "ping via ${exit_tun} to ${NYM_VPN_LAB_PROBE_IP} failed"
    tun_ip="$(ip -4 addr show dev "${exit_tun}" 2>/dev/null | awk '/inet / {print $2}' | head -1 | cut -d/ -f1)"
    if [[ -n "${tun_ip}" ]]; then
      egress_ip="$(curl -4 -m 15 --interface "${tun_ip}" -sS https://api.ipify.org 2>/dev/null || true)"
      if [[ -n "${egress_ip}" ]]; then
        pass "HTTPS data via ${exit_tun} (${tun_ip}): egress ${egress_ip}"
      else
        fail "curl via ${exit_tun} (${tun_ip}) to api.ipify.org failed"
      fi
    else
      fail "no IPv4 on ${exit_tun} for data-plane curl test"
    fi
  else
    fail "no exit tun for post-connect data probe"
  fi
  curl -4 -m 8 -sS -o /dev/null --connect-timeout 5 http://142.250.191.14/ \
    && pass "physical uplink still OK after data test" \
    || fail "physical uplink broken after data test"
  nym-vpnc status | head -8
  host_test_cleanup
  pass "cleanup done"
fi

echo "=== Done. Log: ${LOG} ==="
echo "Recovery: sudo bash ${LAB_CLEANUP}"
