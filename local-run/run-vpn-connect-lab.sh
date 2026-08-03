#!/usr/bin/env bash
# Opt-in: connect VPN on the dev host (requires rebuilt nym-vpnd with lab firewall + routing).
# Recovery if network breaks: sudo bash ../../onidel-cloud/scripts/nym-vpn-local-cleanup.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
export NYM_VPN_CONNECT=1
export NYM_VPN_LAB_PHYSICAL_DEFAULT=1
export NYM_VPN_LAB_ROUTE_CIDRS="${NYM_VPN_LAB_ROUTE_CIDRS:-10.1.0.0/16 1.1.1.1/32}"
export NYM_VPN_LAB_PROBE_IP="${NYM_VPN_LAB_PROBE_IP:-1.1.1.1}"
export NYM_VPN_LAB_SKIP_CONNECTION_PROBE="${NYM_VPN_LAB_SKIP_CONNECTION_PROBE:-0}"
echo "WARNING: connects full VPN stack on THIS host. Cleanup: sudo bash ${ROOT}/../../onidel-cloud/scripts/nym-vpn-local-cleanup.sh"
exec bash "${ROOT}/run-vpn.sh"
