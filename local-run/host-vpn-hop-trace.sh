#!/usr/bin/env bash
# Traceroute-style ICMP debug: one ping burst, capture in+out at each hop.
# Start vpn.sf captures BEFORE VPN (nft blocks SSH once connected).
#
#   cd 6/nym-vpn-client/local-run
#   bash host-vpn-hop-trace.sh
#
# Report: log/host-hop-trace-report.txt
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
OCEAN="${ROOT}/../../../onidel-cloud/scripts"
LOG_DIR="${ROOT}/log/hop-trace"
REPORT="${ROOT}/log/host-hop-trace-report.txt"
ENTRY_IP="${ENTRY_IP:-104.250.122.199}"
PROBE_IP="${NYM_VPN_LAB_PROBE_IP:-1.1.1.1}"
UPLINK="${UPLINK_DEV:-wlp0s20f3}"
SSH_IDENTITY="${SSH_IDENTITY_FILE:-${HOME}/.ssh/id_rsa}"
SSH_OPTS=(-o BatchMode=yes -o ConnectTimeout=10)
[[ -f "${SSH_IDENTITY}" ]] && SSH_OPTS+=(-i "${SSH_IDENTITY}")
MNEMONIC="${MNEMONIC:-dash hungry rate famous lesson march suit refuse excite soul faith bid buddy tortoise melody advice dirt coffee fluid sure air decrease cargo work}"

mkdir -p "${LOG_DIR}"
cleanup() {
  sudo bash "${OCEAN}/nym-vpn-local-cleanup.sh" >/dev/null 2>&1 || true
}
trap cleanup EXIT INT TERM

count_pkts() {
  local f="$1"
  [[ -f "${f}" ]] || { echo 0; return; }
  grep -cE '^[0-9]{2}:' "${f}" 2>/dev/null || echo 0
}

count_icmp_req() {
  local f="$1" n
  [[ -f "${f}" ]] || { echo 0; return; }
  n="$(grep -cE 'ICMP echo request' "${f}" 2>/dev/null)" || n=0
  echo "${n}"
}

count_icmp_rep() {
  local f="$1" n
  [[ -f "${f}" ]] || { echo 0; return; }
  n="$(grep -cE 'ICMP echo reply' "${f}" 2>/dev/null)" || n=0
  echo "${n}"
}

hop_line() {
  local hop="$1" dir="$2" result="$3" detail="$4"
  printf "  %-28s %-6s %-8s %s\n" "${hop}" "${dir}" "${result}" "${detail}"
}

: >"${REPORT}"
exec > >(tee -a "${REPORT}") 2>&1

echo "======== host VPN hop trace $(date -Is) ========"
echo "probe_ip=${PROBE_IP} entry=${ENTRY_IP}"

sudo bash "${OCEAN}/nym-vpn-local-cleanup.sh" >/dev/null 2>&1 || true
bash "${OCEAN}/vpn-sf-enable-colocated-wg-forward.sh" >/dev/null 2>&1 || true

# --- vpn.sf captures (before VPN) ---
echo "[setup] starting vpn.sf captures (45s max each)..."
ssh "${SSH_OPTS[@]}" "root@${ENTRY_IP}" bash -s <<REMOTE >"${LOG_DIR}/vpn-sf-all.log" 2>&1 &
set -euo pipefail
T=45
timeout "\$T" tcpdump -ni nymwg51822 icmp -l -c 15 > /tmp/hop-51822.txt 2>&1 &
timeout "\$T" tcpdump -ni nymwg51823 icmp -l -c 15 > /tmp/hop-51823.txt 2>&1 &
timeout "\$T" tcpdump -ni eth0 "icmp and (host ${PROBE_IP} or net 10.1.0.0/16)" -l -c 15 > /tmp/hop-eth0.txt 2>&1 &
wait
cat /tmp/hop-51822.txt /tmp/hop-51823.txt /tmp/hop-eth0.txt
REMOTE
SF_PID=$!
sleep 2
kill -0 "${SF_PID}" 2>/dev/null || {
  echo "WARN: vpn.sf capture failed to start"
  head -5 "${LOG_DIR}/vpn-sf-all.log" || true
  SF_PID=""
}

# --- host VPN up ---
export PATH="${ROOT}/bin:${PATH}"
export NYM_VPND_CONFIG_DIR="${ROOT}/config/nym"
export NYM_VPND_DATA_DIR="${ROOT}/data"
export NYM_VPN_LAB_PHYSICAL_DEFAULT=1
export NYM_VPN_LAB_ROUTE_CIDRS="10.1.0.0/16 ${PROBE_IP}/32"
export NYM_VPN_LAB_SKIP_CONNECTION_PROBE=1
VPND_LOG="${LOG_DIR}/vpnd.log"
: >"${VPND_LOG}"

sudo bash "${OCEAN}/nym-vpn-lab-split-routing-watch.sh" stop 2>/dev/null || true
LAB_SPLIT_WATCH_INTERVAL=1 sudo bash "${OCEAN}/nym-vpn-lab-split-routing-watch.sh" start >/dev/null 2>&1 || true

sudo env \
  NYM_VPND_CONFIG_DIR="${NYM_VPND_CONFIG_DIR}" \
  NYM_VPND_DATA_DIR="${NYM_VPND_DATA_DIR}" \
  NYM_VPN_LAB_PHYSICAL_DEFAULT=1 \
  NYM_VPN_LAB_ROUTE_CIDRS="${NYM_VPN_LAB_ROUTE_CIDRS}" \
  NYM_VPN_LAB_SKIP_CONNECTION_PROBE=1 \
  "${ROOT}/bin/nym-vpnd" -vv run-with-args --disable-client-verification >>"${VPND_LOG}" 2>&1 &

for i in $(seq 1 30); do [[ -S /var/run/nym-vpn.sock ]] && break; sleep 1; done
for i in $(seq 1 45); do grep -q "Gateway cache" "${VPND_LOG}" && break; sleep 1; done
nym-vpnc account set "${MNEMONIC}" >/dev/null 2>&1 || true
for i in $(seq 1 30); do nym-vpnc account get 2>&1 | grep -q ReadyToConnect && break; sleep 2; done
sudo bash "${OCEAN}/nym-vpn-lab-split-routing.sh" apply-physical >/dev/null 2>&1 || true
nym-vpnc connect >/dev/null 2>&1 || true
for i in $(seq 1 30); do
  sudo bash "${OCEAN}/nym-vpn-lab-split-routing.sh" apply >/dev/null 2>&1 || true
  ip link show tun1 &>/dev/null && grep -q S9_register_wireguard_ok "${VPND_LOG}" && break
  sleep 2
done

TUN0=tun0
TUN1=tun1
ip link show "${TUN1}" &>/dev/null || { echo "FAIL: no tun1"; exit 1; }

echo "[host] tun0=$(ip -4 addr show dev ${TUN0} 2>/dev/null | awk '/inet /{print $2}' | head -1)"
echo "[host] tun1=$(ip -4 addr show dev ${TUN1} 2>/dev/null | awk '/inet /{print $2}' | head -1)"
echo "[host] route get ${PROBE_IP}: $(ip route get "${PROBE_IP}" 2>/dev/null || echo '?')"

# --- host captures + ping ---
echo "[ping] sudo ping -I ${TUN1} -c 3 -W 2 ${PROBE_IP}"
sudo timeout 12 tcpdump -ni "${TUN0}" icmp -l -c 10 >"${LOG_DIR}/host-tun0.txt" 2>&1 &
H0=$!
sudo timeout 12 tcpdump -ni "${TUN1}" icmp -l -c 10 >"${LOG_DIR}/host-tun1.txt" 2>&1 &
H1=$!
sudo timeout 12 tcpdump -ni "${UPLINK}" '(udp port 51822 or udp port 51823) or icmp' -l -c 20 \
  >"${LOG_DIR}/host-wlp0.txt" 2>&1 &
HW=$!
sleep 0.5
PING_OUT=$(sudo ping -c 3 -W 2 -I "${TUN1}" "${PROBE_IP}" 2>&1) || true
echo "${PING_OUT}"
wait "${H0}" 2>/dev/null || true
wait "${H1}" 2>/dev/null || true
wait "${HW}" 2>/dev/null || true

sleep 3
[[ -n "${SF_PID}" ]] && wait "${SF_PID}" 2>/dev/null || true

# Split vpn.sf log into sections if present
if [[ -f "${LOG_DIR}/vpn-sf-all.log" ]]; then
  awk '/listening on nymwg51822/{f="'"${LOG_DIR}/vpn-sf-51822.txt"'"} 
       /listening on nymwg51823/{f="'"${LOG_DIR}/vpn-sf-51823.txt"'"} 
       /listening on eth0/{f="'"${LOG_DIR}/vpn-sf-eth0.txt"'"} 
       f{print > f}' "${LOG_DIR}/vpn-sf-all.log" 2>/dev/null || cp "${LOG_DIR}/vpn-sf-all.log" "${LOG_DIR}/vpn-sf-raw.txt"
fi

echo ""
echo "======== HOP MATRIX (ICMP echo request / reply) ========"
printf "  %-28s %-6s %-8s %s\n" "HOP" "DIR" "RESULT" "DETAIL"
echo "  ---------------------------------------------------------------------------"

t0_req=$(count_icmp_req "${LOG_DIR}/host-tun0.txt")
t0_rep=$(count_icmp_rep "${LOG_DIR}/host-tun0.txt")
hop_line "H1 host tun0 (entry)" "OUT" "$([[ "${t0_req}" -gt 0 ]] && echo YES || echo NO)" "req=${t0_req} reply=${t0_rep}"

t1_req=$(count_icmp_req "${LOG_DIR}/host-tun1.txt")
t1_rep=$(count_icmp_rep "${LOG_DIR}/host-tun1.txt")
hop_line "H2 host tun1 (exit)" "OUT" "$([[ "${t1_req}" -gt 0 ]] && echo YES || echo NO)" "req=${t1_req} reply=${t1_rep}"

wlp_udp=$(grep -cE 'UDP.*(51822|51823)' "${LOG_DIR}/host-wlp0.txt" 2>/dev/null) || wlp_udp=0
wlp_icmp=$(count_icmp_req "${LOG_DIR}/host-wlp0.txt")
hop_line "H3 host ${UPLINK}" "OUT" "$([[ "${wlp_udp}" -gt 0 ]] && echo YES || echo NO)" "WG_UDP=${wlp_udp} plain_icmp=${wlp_icmp}"

e22_req=$(count_icmp_req "${LOG_DIR}/vpn-sf-51822.txt")
e22_rep=$(count_icmp_rep "${LOG_DIR}/vpn-sf-51822.txt")
hop_line "H4 vpn.sf nymwg51822" "IN" "$([[ "${e22_req}" -gt 0 ]] && echo YES || echo NO)" "req=${e22_req} reply=${e22_rep}"

e23_req=$(count_icmp_req "${LOG_DIR}/vpn-sf-51823.txt")
e23_rep=$(count_icmp_rep "${LOG_DIR}/vpn-sf-51823.txt")
hop_line "H5 vpn.sf nymwg51823" "IN" "$([[ "${e23_req}" -gt 0 ]] && echo YES || echo NO)" "req=${e23_req} reply=${e23_rep}"

eth_req=$(count_icmp_req "${LOG_DIR}/vpn-sf-eth0.txt")
eth_rep=$(count_icmp_rep "${LOG_DIR}/vpn-sf-eth0.txt")
hop_line "H6 vpn.sf eth0 WAN" "OUT" "$([[ "${eth_req}" -gt 0 ]] && echo YES || echo NO)" "req=${eth_req} reply=${eth_rep}"

echo ""
echo "======== FIRST BREAK (first OUT without next IN) ========"
if [[ "${t1_req}" -gt 0 && "${e22_req}" -eq 0 && "${e23_req}" -eq 0 ]]; then
  echo "  After H2 (tun1): inner ICMP leaves host exit tun but never decaps on vpn.sf entry OR exit WG."
  echo "  Check: outer WG path (H3 UDP), client may send only on :51823 without entry forwarding path."
elif [[ "${e22_req}" -gt 0 && "${e23_req}" -eq 0 ]]; then
  echo "  After H4 (entry WG): ICMP reaches entry but NOT exit — entry→exit forward (connmark script)."
elif [[ "${e23_req}" -gt 0 && "${eth_req}" -eq 0 ]]; then
  echo "  After H5 (exit WG): ICMP on exit but not on eth0 — exit NAT/forward to WAN."
elif [[ "${eth_req}" -gt 0 && "${eth_rep}" -eq 0 ]]; then
  echo "  After H6 (WAN out): request left vpn.sf but no reply on eth0 — upstream or return path."
elif [[ "${e23_rep}" -gt 0 && "${t1_rep}" -eq 0 ]]; then
  echo "  After H5 (exit WG): vpn.sf gets echo REPLY from 1.1.1.1 but host tun1 sees NO reply."
  echo "  Break = return path exit WG → host tun1 (WG decap, nft input, or policy route on host)."
elif [[ "${t1_rep}" -gt 0 ]]; then
  echo "  Reply seen on host tun1 — data plane OK at ICMP level."
else
  echo "  See per-hop files under ${LOG_DIR}/"
fi

echo ""
echo "======== SAMPLE LINES ========"
for f in host-tun1.txt host-wlp0.txt vpn-sf-51822.txt vpn-sf-51823.txt vpn-sf-eth0.txt; do
  echo "--- ${f} ---"
  grep -E '^[0-9]{2}:|ICMP|listening|Timeout|error' "${LOG_DIR}/${f}" 2>/dev/null | head -8 || echo "(empty or missing)"
done

echo ""
echo "Logs: ${LOG_DIR}/"
echo "Report: ${REPORT}"
trap - EXIT
cleanup
