#!/usr/bin/env bash
# Download patched nym-vpn-client tree from vpn.sf into this repo directory.
set -euo pipefail

HOST="${VPN_SF_HOST:-root@104.250.122.199}"
KEY="${SSH_KEY:-$HOME/.ssh/id_ed25519_gitlab_migrate_drill}"
DEST="$(cd "$(dirname "$0")/.." && pwd)"

echo "==> Pack on vpn.sf"
ssh -i "$KEY" -o BatchMode=yes "$HOST" \
  'tar -czf /opt/nym-vpn-client-src.tar.gz -C /opt nym-vpn-client-src'

echo "==> Download to ${DEST}"
scp -i "$KEY" -o BatchMode=yes "${HOST}:/opt/nym-vpn-client-src.tar.gz" /tmp/nym-vpn-client-src.tar.gz

echo "==> Extract (keeps .git)"
tar -xzf /tmp/nym-vpn-client-src.tar.gz -C "$DEST" --strip-components=1

echo "Done. See onidel-patches/SOCKS-TEST.md"
