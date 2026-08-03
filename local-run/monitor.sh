#!/usr/bin/env bash
# Poll vpnc status and vpnd log until Connected, hard error, or connect try limit.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
BIN="${ROOT}/bin"
export PATH="${BIN}:${PATH}"

# At most this many connect attempts (try #0 .. try #(N-1)); then disconnect and exit.
MAX_CONNECT_ATTEMPTS="${MAX_CONNECT_ATTEMPTS:-3}"
MONITOR_INTERVAL="${MONITOR_INTERVAL:-5}"
# Safety cap: polls × interval (default ~3 min).
MAX_POLLS="${MAX_POLLS:-36}"

VPND_LOG="${VPND_LOG:-${ROOT}/log/vpnd-foreground.log}"
VPND_LOG_ALT="${ROOT}/log/vpnd-no-sudo.log}"

vpnd_log() {
  if [[ -f "${VPND_LOG}" ]]; then
    tail -20 "${VPND_LOG}"
  elif [[ -f "${VPND_LOG_ALT}" ]]; then
    tail -20 "${VPND_LOG_ALT}"
  else
    echo "(no vpnd log — start vpnd first)"
  fi
}

stop_connect() {
  echo "=== monitor: nym-vpnc disconnect (stop vpnd retry loop) ==="
  nym-vpnc disconnect 2>&1 || true
}

connect_try_from_status() {
  local st="$1"
  if echo "${st}" | grep -q "try #"; then
    echo "${st}" | sed -n 's/.*try #\([0-9][0-9]*\).*/\1/p' | head -1
    return
  fi
  echo "0"
}

connect_try_from_log() {
  local log="$1"
  [[ -f "${log}" ]] || { echo "0"; return; }
  # "Reconnecting, attempt 17" — take the highest attempt in the tail window.
  sed -n 's/.*Reconnecting, attempt \([0-9][0-9]*\).*/\1/p' "${log}" | tail -1
}

echo "=== monitor started $(date -Is) (max ${MAX_CONNECT_ATTEMPTS} connect tries, poll every ${MONITOR_INTERVAL}s) ==="

for i in $(seq 1 "${MAX_POLLS}"); do
  echo "--- poll ${i} $(date -Is) ---"
  st="$(nym-vpnc status 2>&1 || true)"
  if [[ -z "${st}" ]] || echo "${st}" | grep -qi "Failed to create RPC client"; then
    echo "${st:-"(empty status)"}"
    echo "(vpnd RPC unavailable)"
  else
    echo "${st}"
    nym-vpnc account get 2>&1 | head -6 || true
  fi

  echo "--- vpnd log (last 20 lines) ---"
  vpnd_log

  if echo "${st}" | grep -q "State: Connected"; then
    echo "=== monitor: Connected ==="
    exit 0
  fi

  if echo "${st}" | grep -qiE "DeviceLoggedOut|InactiveAccount|BandwidthExceeded|Error state|ZK_NYM_STATE"; then
    echo "=== monitor: terminal error state ==="
    stop_connect
    exit 1
  fi
  acct="$(nym-vpnc account get 2>&1 || true)"
  if echo "${acct}" | grep -qE "Account state: Error"; then
    echo "=== monitor: account error ==="
    echo "${acct}" | head -8
    stop_connect
    exit 1
  fi

  try="$(connect_try_from_status "${st}")"
  [[ -z "${try}" ]] && try=0
  log_try="$(connect_try_from_log "${VPND_LOG}")"
  [[ -z "${log_try}" ]] && log_try="$(connect_try_from_log "${VPND_LOG_ALT}")"
  [[ -z "${log_try}" ]] && log_try=0
  if [[ "${log_try}" -gt "${try}" ]]; then
    try="${log_try}"
  fi

  if echo "${st}" | grep -q "State: Connecting" && [[ "${try}" -ge "${MAX_CONNECT_ATTEMPTS}" ]]; then
    echo "=== monitor: connect try #${try} >= max ${MAX_CONNECT_ATTEMPTS} — giving up ==="
    stop_connect
    exit 1
  fi

  sleep "${MONITOR_INTERVAL}"
done

echo "=== monitor: timeout after ${MAX_POLLS} polls ==="
stop_connect
exit 2
