#!/usr/bin/env bash
# One script: clean slate -> vpnd (split lab: Wi-Fi default, vpnd routes test CIDRs) -> connect.
# Split script only adds Wi-Fi bypass + nft; it does NOT replace vpnd multihop routes.
# On FAILURE or interrupt: automatic cleanup (restore Wi-Fi / Cursor).
# On SUCCESS: VPN stays up unless CLEANUP_ON_SUCCESS=1 (recommended while using Cursor).
#
#   cd 6/nym-vpn-client/local-run
#   bash host-vpn-lab-connect.sh
#
# Env (optional):
#   WIPE_MAINNET_DATA=1
#   PHYSICAL_TEST_URL=http://104.250.122.199:8088/healthz  (default; reachable on Wi-Fi)
#   ACCOUNT_SETTLE_SEC=15   sleep after ReadyToConnect before connect
#   CLEANUP_ON_SUCCESS=1  tear down even when valid (default: leave VPN connected)
#   NYM_VPN_LAB_EGRESS_URL=https://api.ipify.org  HTTPS check via exit tun (--interface tun1)
#   MAX_CONNECT_ATTEMPTS=5  MONITOR_INTERVAL=5  MAX_POLLS=48
set -uo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
BIN="${ROOT}/bin"
export PATH="${BIN}:${PATH}"
export NYM_VPND_CONFIG_DIR="${ROOT}/config/nym"
export NYM_VPND_DATA_DIR="${ROOT}/data"
export NYM_VPND_LOG_DIR="${ROOT}/log"

LOG="${ROOT}/log/host-vpn-lab-connect.log"
NET_SNAPSHOT="${ROOT}/log/host-vpn-lab-connect-net.log"
OCEAN_SCRIPTS="${ROOT}/../../../onidel-cloud/scripts"
LAB_SPLIT="${OCEAN_SCRIPTS}/nym-vpn-lab-split-routing.sh"
LAB_WATCH="${OCEAN_SCRIPTS}/nym-vpn-lab-split-routing-watch.sh"
LAB_CLEANUP="${OCEAN_SCRIPTS}/nym-vpn-local-cleanup.sh"
VPN_SF_PREFLIGHT="${OCEAN_SCRIPTS}/vpn-sf-preflight.sh"
VPN_SF_FORWARD="${OCEAN_SCRIPTS}/vpn-sf-enable-colocated-wg-forward.sh"

MNEMONIC="${MNEMONIC:-dash hungry rate famous lesson march suit refuse excite soul faith bid buddy tortoise melody advice dirt coffee fluid sure air decrease cargo work}"
# Public path check via Wi-Fi only — mock healthz (Google IPs often blocked on CN networks).
PHYSICAL_TEST_URL="${PHYSICAL_TEST_URL:-http://104.250.122.199:8088/healthz}"
ACCOUNT_SETTLE_SEC="${ACCOUNT_SETTLE_SEC:-15}"

export NYM_VPN_LAB_PHYSICAL_DEFAULT="${NYM_VPN_LAB_PHYSICAL_DEFAULT:-1}"
export NYM_VPN_LAB_ROUTE_CIDRS="${NYM_VPN_LAB_ROUTE_CIDRS:-10.1.0.0/16 1.1.1.1/32}"
export NYM_VPN_LAB_PROBE_IP="${NYM_VPN_LAB_PROBE_IP:-1.1.1.1}"
export NYM_VPN_LAB_SKIP_CONNECTION_PROBE="${NYM_VPN_LAB_SKIP_CONNECTION_PROBE:-0}"

MAX_CONNECT_ATTEMPTS="${MAX_CONNECT_ATTEMPTS:-5}"
MONITOR_INTERVAL="${MONITOR_INTERVAL:-5}"
MAX_POLLS="${MAX_POLLS:-48}"

HOST_VPN_CLEANUP_RAN=0
HOST_VPN_SUCCESS=0
SCRIPT_EXIT=0

detect_exit_tun() {
  ip -o link show 2>/dev/null | awk -F': ' '/ tun[0-9]+:/ {print $2}' | sort -V | tail -1 | tr -d ' '
}

detect_uplink_dev() {
  ip route show default 0.0.0.0/0 2>/dev/null | awk '/dev/ {
    for (i = 1; i <= NF; i++) if ($i == "dev") { print $(i + 1); exit }
  }'
}

detect_uplink_ip() {
  local dev="$1"
  dev="${dev:-$(detect_uplink_dev)}"
  [[ -n "${dev}" ]] || return 1
  ip -4 addr show dev "${dev}" 2>/dev/null | awk '/inet / {print $2}' | head -1 | cut -d/ -f1
}

record_network_snapshot() {
  local label="$1"
  local uplink exit_tun mock_route
  uplink="$(detect_uplink_dev)"
  exit_tun="$(detect_exit_tun)"
  mock_route="$(ip route get 104.250.122.199 2>/dev/null || true)"

  {
    echo "======== $(date -Is) — ${label} ========"
    echo "physical_test_url=${PHYSICAL_TEST_URL}"
    echo "uplink_dev=${uplink:-?} uplink_ip=$(detect_uplink_ip "${uplink}" 2>/dev/null || echo '?') exit_tun=${exit_tun:-none}"
    echo "route_get_mock=${mock_route}"
    echo "--- ip -br link (all interfaces) ---"
    ip -br link show 2>/dev/null || true
    echo "--- ip -br addr (all interfaces) ---"
    ip -br addr show 2>/dev/null || true
    echo "--- ip link show (up/down flags) ---"
    ip link show 2>/dev/null | awk '/^[0-9]+:/ {print}' || true
    echo "--- ip route (main table) ---"
    ip route show 2>/dev/null || true
    echo "--- ip route table ${NYM_TABLE_ID:-333} ---"
    ip route show table 333 2>/dev/null || echo "(empty)"
    echo "--- ip rule ---"
    ip rule list 2>/dev/null || true
    echo "--- routes via tun/nym ---"
    ip route show 2>/dev/null | grep -E ' dev tun| dev nym' || echo "(none)"
    if [[ -n "${exit_tun}" ]]; then
      echo "--- ip addr show dev ${exit_tun} ---"
      ip -4 addr show dev "${exit_tun}" 2>/dev/null || true
      echo "--- ip route get ${NYM_VPN_LAB_PROBE_IP} ---"
      ip route get "${NYM_VPN_LAB_PROBE_IP}" 2>/dev/null || true
    fi
    echo "--- ip rule pref 45 (Wi-Fi bypass) ---"
    ip rule list 2>/dev/null | grep '^45:' || echo "(none)"
    echo "--- nft inet nym (first 60 lines) ---"
    if sudo nft list table inet nym &>/dev/null; then
      sudo nft list table inet nym 2>/dev/null | head -60
    else
      echo "(no inet nym table)"
    fi
    echo "--- resolvectl (first 30 lines) ---"
    resolvectl status 2>/dev/null | head -30 || true
    echo "--- nym processes ---"
    pgrep -a nym 2>/dev/null || echo "(none)"
    echo ""
  } | tee -a "${NET_SNAPSHOT}"
}

do_cleanup() {
  [[ "${HOST_VPN_CLEANUP_RAN}" == "1" ]] && return 0
  HOST_VPN_CLEANUP_RAN=1
  record_network_snapshot "before-cleanup"
  echo ""
  echo "=== host-vpn-lab-connect: cleanup (restore network / Cursor) ==="
  if [[ -x "${LAB_CLEANUP}" ]]; then
    sudo bash "${LAB_CLEANUP}" || true
  else
    echo "[WARN] missing ${LAB_CLEANUP}"
    sudo killall -9 nym-vpnd nym-vpnc 2>/dev/null || true
  fi
  record_network_snapshot "after-cleanup"
}

cleanup_trap() {
  if [[ "${HOST_VPN_SUCCESS}" == "1" && "${CLEANUP_ON_SUCCESS:-0}" != "1" ]]; then
    return 0
  fi
  do_cleanup
}

on_interrupt() {
  SCRIPT_EXIT=1
  do_cleanup
  exit 130
}

trap cleanup_trap EXIT
trap on_interrupt INT TERM HUP

log() { echo "[host-vpn] $*"; }
pass() { log "PASS: $*"; }
fail() {
  log "FAIL: $*"
  record_network_snapshot "FAIL: $*"
  SCRIPT_EXIT=1
  exit 1
}

success_finish() {
  HOST_VPN_SUCCESS=1
  SCRIPT_EXIT=0
  record_network_snapshot "SUCCESS-final"
  nym-vpnc status 2>&1 | head -8
  log "=== SUCCESS: tunnel valid; VPN left up (no cleanup) ==="
  log "Teardown: sudo bash ${LAB_CLEANUP}"
  log "Network log: ${NET_SNAPSHOT}"
  trap - EXIT
  exit 0
}

physical_uplink_ok() {
  local dev ip route_dev
  dev="${1:-$(detect_uplink_dev)}"
  ip="$(detect_uplink_ip "${dev}")"
  route_dev="$(ip route get 104.250.122.199 2>/dev/null | awk '/ dev / {for (i = 1; i <= NF; i++) if ($i == "dev") { print $(i + 1); exit }}')"
  if [[ -n "${route_dev}" && "${route_dev}" != "${dev}" && "${route_dev}" == tun* ]]; then
    return 1
  fi
  # vpnd nft often allows mock :8088 only for skuid 0; use sudo curl on Wi-Fi source IP.
  if [[ -n "${ip}" ]]; then
    sudo curl -4 -m 8 -sS -o /dev/null --connect-timeout 5 --interface "${ip}" "${PHYSICAL_TEST_URL}" 2>/dev/null \
      && return 0
  fi
  if [[ -n "${dev}" ]]; then
    sudo curl -4 -m 8 -sS -o /dev/null --connect-timeout 5 --interface "${dev}" "${PHYSICAL_TEST_URL}" 2>/dev/null \
      && return 0
  fi
  sudo curl -4 -m 8 -sS -o /dev/null --connect-timeout 5 "${PHYSICAL_TEST_URL}" 2>/dev/null
}

maybe_apply_lab_split() {
  [[ -x "${LAB_SPLIT}" ]] || return 0
  local tun
  tun="$(detect_exit_tun)"
  if [[ -n "${tun}" ]]; then
    sudo bash "${LAB_SPLIT}" apply >/dev/null 2>&1 && return 0
  fi
  sudo bash "${LAB_SPLIT}" apply-physical >/dev/null 2>&1 && return 0
  return 1
}

log_viable_in_log() {
  grep -q "Tunnel connection is viable" "${LOG}" 2>/dev/null
}

log_probe_skipped() {
  grep -q "lab.skip_connection_probe" "${LOG}" 2>/dev/null
}

log_probe_failing_now() {
  tail -80 "${LOG}" 2>/dev/null | grep -q "Tunnel connection is failing"
}

connect_try_from_status() {
  local st="$1"
  if echo "${st}" | grep -q "try #"; then
    echo "${st}" | sed -n 's/.*try #\([0-9][0-9]*\).*/\1/p' | head -1
    return
  fi
  echo "0"
}

validate_connected_tunnel() {
  local exit_tun tun_ip egress_ip uplink
  uplink="$(detect_uplink_dev)"

  if ! log_viable_in_log; then
    fail "log has no 'Tunnel connection is viable' (see ${LOG})"
  fi
  if log_probe_skipped && [[ "${ALLOW_SKIP_PROBE:-0}" != "1" ]]; then
    fail "probe was skipped (NYM_VPN_LAB_SKIP_CONNECTION_PROBE) — set ALLOW_SKIP_PROBE=1 to allow debug only"
  fi
  if log_probe_skipped; then
    log "WARN: probe skipped — data-plane checks still run"
  fi

  record_network_snapshot "validate-connected"

  if physical_uplink_ok "${uplink}"; then
    pass "Wi-Fi uplink OK via ${uplink:-default} (${PHYSICAL_TEST_URL})"
  else
    log "WARN: mock healthz via Wi-Fi failed after Connected (nft may block; not a VPN failure)"
  fi

  exit_tun="$(detect_exit_tun)"
  [[ -n "${exit_tun}" ]] || fail "no exit tun after Connected"

  sudo ping -c 2 -W 3 -I "${exit_tun}" "${NYM_VPN_LAB_PROBE_IP}" >/dev/null \
    && pass "ICMP via ${exit_tun} -> ${NYM_VPN_LAB_PROBE_IP}" \
    || fail "ping via ${exit_tun} failed (vpnd probe was viable — check nft / split routes)"

  tun_ip="$(ip -4 addr show dev "${exit_tun}" 2>/dev/null | awk '/inet / {print $2}' | head -1 | cut -d/ -f1)"
  [[ -n "${tun_ip}" ]] || fail "no IPv4 on ${exit_tun}"
  # Match ping: bind egress device (not inner IP). sudo for parity with physical_uplink_ok / nft.
  probe_https="${NYM_VPN_LAB_PROBE_HTTPS_URL:-https://${NYM_VPN_LAB_PROBE_IP}/}"
  probe_code="$(sudo curl -4 -m 15 --interface "${exit_tun}" -sS -o /dev/null -w '%{http_code}' "${probe_https}" 2>/dev/null || echo "000")"
  if [[ "${probe_code}" != "000" && "${probe_code}" -lt 500 ]]; then
    pass "HTTPS via ${exit_tun} -> ${NYM_VPN_LAB_PROBE_IP} (HTTP ${probe_code})"
  else
    fail "curl --interface ${exit_tun} ${probe_https} failed (HTTP ${probe_code})"
  fi

  egress_url="${NYM_VPN_LAB_EGRESS_URL:-https://api.ipify.org}"
  egress_ip="$(sudo curl -4 -m 15 --interface "${exit_tun}" -sS "${egress_url}" 2>/dev/null || true)"
  [[ -n "${egress_ip}" ]] \
    && pass "HTTPS egress via ${exit_tun} (inner ${tun_ip}): ${egress_ip}" \
    || fail "curl --interface ${exit_tun} failed (${egress_url})"

  if physical_uplink_ok "${uplink}"; then
    pass "Wi-Fi uplink still OK after data test"
  else
    log "WARN: mock healthz via Wi-Fi failed after data test (run cleanup if Cursor stalls)"
  fi
}

monitor_until_valid_or_give_up() {
  local i st try log_try acct uplink
  uplink="$(detect_uplink_dev)"

  log "monitor: max ${MAX_CONNECT_ATTEMPTS} connect tries, poll every ${MONITOR_INTERVAL}s"
  for i in $(seq 1 "${MAX_POLLS}"); do
    maybe_apply_lab_split || true

    if ! physical_uplink_ok "${uplink}"; then
      log "WARN: Wi-Fi uplink check failed (poll ${i}, dev=${uplink:-?})"
      maybe_apply_lab_split || true
    fi

    st="$(nym-vpnc status 2>&1 || true)"
    echo "--- poll ${i} $(date -Is) ---"
    echo "${st}" | head -5
    record_network_snapshot "monitor-poll-${i}"

    if echo "${st}" | grep -q "State: Connected"; then
      pass "nym-vpnc status: Connected"
      validate_connected_tunnel
      return 0
    fi

    if echo "${st}" | grep -qiE "DeviceLoggedOut|InactiveAccount|BandwidthExceeded|Error state"; then
      fail "terminal VPN error state (poll ${i})"
    fi

    acct="$(nym-vpnc account get 2>&1 || true)"
    if echo "${acct}" | grep -q "Account state: Error"; then
      fail "account error during connect"
    fi

    if log_probe_failing_now && ! echo "${st}" | grep -q "State: Connected"; then
      log "log: Tunnel connection is failing (still connecting)"
    fi

    try="$(connect_try_from_status "${st}")"
    [[ -z "${try}" ]] && try=0
    log_try="$(sed -n 's/.*Reconnecting, attempt \([0-9][0-9]*\).*/\1/p' "${LOG}" | tail -1)"
    [[ -n "${log_try}" && "${log_try}" -gt "${try}" ]] && try="${log_try}"

    if echo "${st}" | grep -q "State: Connecting" && [[ "${try}" -ge "${MAX_CONNECT_ATTEMPTS}" ]]; then
      nym-vpnc disconnect 2>/dev/null || true
      fail "connect try #${try} >= ${MAX_CONNECT_ATTEMPTS}"
    fi

    sleep "${MONITOR_INTERVAL}"
  done

  nym-vpnc disconnect 2>/dev/null || true
  fail "monitor timeout after ${MAX_POLLS} polls"
}

# --- main ---
: >"${NET_SNAPSHOT}"
log "=== host VPN lab connect ($(hostname)) ==="
log "vpnd log: ${LOG}"
log "network log: ${NET_SNAPSHOT}"
log "physical check (Wi-Fi): ${PHYSICAL_TEST_URL}"

[[ -x "${LAB_CLEANUP}" ]] || fail "missing ${LAB_CLEANUP}"
sudo bash "${LAB_CLEANUP}" || true
HOST_VPN_CLEANUP_RAN=0
record_network_snapshot "after-initial-cleanup"

curl -fsS --connect-timeout 5 http://104.250.122.199:8088/healthz >/dev/null \
  && pass "mock API reachable" || fail "mock API unreachable"

for h in '104.250.122.199 vpn.sf-entry' '160.22.79.198 vpn.sf-exit' '194.182.169.49 rpc.nymtech.net'; do
  grep -qF "${h#* }" /etc/hosts 2>/dev/null || echo "$h" | sudo tee -a /etc/hosts >/dev/null
done

if [[ "${WIPE_MAINNET_DATA:-0}" == "1" ]]; then
  rm -rf "${NYM_VPND_DATA_DIR}/mainnet" 2>/dev/null || true
  mkdir -p "${NYM_VPND_DATA_DIR}/mainnet"
  log "wiped ${NYM_VPND_DATA_DIR}/mainnet"
fi

sudo killall -9 nym-vpnd nym-vpnc nym-socks5-proxy 2>/dev/null || true
sudo pkill -9 -f "${BIN}/nym-vpnd" 2>/dev/null || true
sudo fuser -k 1080/tcp 10800/tcp 1081/tcp 2>/dev/null || true
sleep 2
sudo rm -f /var/run/nym-vpn.sock
record_network_snapshot "after-kill-stale-vpnd"

: >"${LOG}"
if [[ -x "${LAB_SPLIT}" ]]; then
  sudo bash "${LAB_SPLIT}" apply-physical >/dev/null 2>&1 || true
  pass "lab split physical bypass (pre-vpnd, Cursor-safe)"
fi

if [[ -x "${LAB_WATCH}" ]]; then
  sudo bash "${LAB_WATCH}" stop 2>/dev/null || true
  LAB_SPLIT_WATCH_INTERVAL=1 sudo bash "${LAB_WATCH}" start || true
  pass "lab split watchdog started"
fi

log "starting nym-vpnd (split lab, SKIP_PROBE=${NYM_VPN_LAB_SKIP_CONNECTION_PROBE})"
sudo env \
  NYM_VPND_CONFIG_DIR="${NYM_VPND_CONFIG_DIR}" \
  NYM_VPND_DATA_DIR="${NYM_VPND_DATA_DIR}" \
  NYM_VPN_LAB_PHYSICAL_DEFAULT="${NYM_VPN_LAB_PHYSICAL_DEFAULT}" \
  NYM_VPN_LAB_ROUTE_CIDRS="${NYM_VPN_LAB_ROUTE_CIDRS}" \
  NYM_VPN_LAB_PROBE_IP="${NYM_VPN_LAB_PROBE_IP}" \
  NYM_VPN_LAB_SKIP_CONNECTION_PROBE="${NYM_VPN_LAB_SKIP_CONNECTION_PROBE}" \
  RUST_LOG=nym_vpn_lib=info,nym_vpn_account_controller=info,nym_registration_client=info \
  "${BIN}/nym-vpnd" -vv run-with-args --disable-client-verification \
  >>"${LOG}" 2>&1 &

for i in $(seq 1 30); do
  [[ -S /var/run/nym-vpn.sock ]] && break
  sleep 1
done
[[ -S /var/run/nym-vpn.sock ]] && pass "vpnd socket" || fail "vpnd did not start (see ${LOG})"

for i in $(seq 1 45); do
  grep -q "Gateway cache and topology cache successfully updated" "${LOG}" && break
  sleep 1
done
grep -q "Gateway cache and topology cache successfully updated" "${LOG}" \
  || fail "topology not ready (see ${LOG})"
maybe_apply_lab_split || true
record_network_snapshot "vpnd-ready"

nym-vpnc account set "${MNEMONIC}" >/dev/null 2>&1 || true
for i in $(seq 1 60); do
  maybe_apply_lab_split || true
  nym-vpnc account get 2>&1 | grep -q "Account state: ReadyToConnect" && break
  nym-vpnc account get 2>&1 | grep -q "Account state: Error" && fail "account error (try WIPE_MAINNET_DATA=1)"
  sleep 3
done
nym-vpnc account get 2>&1 | grep -q "ReadyToConnect" || fail "account not ReadyToConnect"
pass "account ReadyToConnect"

if [[ "${ACCOUNT_SETTLE_SEC}" -gt 0 ]]; then
  log "account settle sleep ${ACCOUNT_SETTLE_SEC}s (ticketbooks)"
  sleep "${ACCOUNT_SETTLE_SEC}"
fi
record_network_snapshot "account-ready"

if [[ "${SKIP_VPN_SF_PREFLIGHT:-0}" != "1" && -f "${VPN_SF_PREFLIGHT}" ]]; then
  bash "${VPN_SF_PREFLIGHT}" || fail "vpn.sf preflight failed"
  pass "vpn.sf preflight"
fi
if [[ "${SKIP_VPN_SF_FORWARD:-0}" != "1" && -f "${VPN_SF_FORWARD}" ]]; then
  bash "${VPN_SF_FORWARD}" || fail "vpn.sf colocated forward failed"
  pass "vpn.sf colocated forward"
fi

uplink="$(detect_uplink_dev)"
if physical_uplink_ok "${uplink}"; then
  pass "Wi-Fi uplink OK before connect (dev=${uplink:-?})"
else
  log "WARN: Wi-Fi uplink check failed before connect (dev=${uplink:-?})"
  maybe_apply_lab_split || true
fi

sudo bash "${LAB_SPLIT}" apply-physical >/dev/null 2>&1 || true
nym-vpnc socks5 disable 2>/dev/null || true
log "nym-vpnc connect"
record_network_snapshot "before-connect"
nym-vpnc connect 2>&1 | tee -a "${ROOT}/log/host-vpn-lab-connect-cli.log" || true

for _ in $(seq 1 24); do
  maybe_apply_lab_split && break
  sleep 2
done
maybe_apply_lab_split && pass "lab split routing applied" \
  || log "WARN: lab split apply not ready yet (watchdog will retry)"
record_network_snapshot "after-connect-start"

monitor_until_valid_or_give_up
success_finish
