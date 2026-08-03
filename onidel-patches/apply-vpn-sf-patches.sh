#!/usr/bin/env bash
# Apply Onidel vpn.sf patches: point bundled mainnet discovery at mock API.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PATCH_DIR="$(dirname "$0")"
NETCFG="${ROOT}/nym-vpn-core/crates/nym-vpn-network-config"

if [ ! -d "${NETCFG}" ]; then
  echo "Run from nym-vpn-client root (nym-vpn-core missing)" >&2
  exit 1
fi

cp "${PATCH_DIR}/vpn-sf_discovery.json" "${NETCFG}/default/mainnet_discovery.json"

LIB="${NETCFG}/src/lib.rs"
if ! grep -q 'Patching nym_api_urls from discovery' "$LIB"; then
  python3 - "$LIB" <<'PY'
import sys
from pathlib import Path
lib = Path(sys.argv[1])
text = lib.read_text()
old = """        if network_details.nym_vpn_api_urls.is_none()
            || network_details
                .nym_vpn_api_urls
                .as_ref()
                .is_some_and(|v| v.is_empty())
        {
            tracing::debug!(
                "Patching up network details from discovery due to missing network details!"
            );
            network_details.nym_vpn_api_urls = Some(discovery.nym_vpn_api_urls());
        }"""
new = old + """
        if network_details.nym_api_urls.is_none()
            || network_details
                .nym_api_urls
                .as_ref()
                .is_some_and(|v| v.is_empty())
        {
            tracing::debug!("Patching nym_api_urls from discovery");
            network_details.nym_api_urls = Some(discovery.nym_api_urls());
        }"""
if old not in text:
    raise SystemExit('lib.rs patch anchor not found')
lib.write_text(text.replace(old, new, 1))
PY
fi

echo "Applied: mainnet_discovery.json -> mock API (${NETCFG}/default/)"
