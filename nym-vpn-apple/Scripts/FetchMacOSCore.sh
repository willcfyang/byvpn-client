#!/bin/bash
#
# Fetches macOS core artifacts (daemon binaries + ByVpnRpc UniFFI when present).
# Source defaults to upstream CI unless BYVPN_CORE_BASE_URL is set.
#
# Must be run from nym-vpn-apple/Scripts (usually via FetchCore.sh).

set -euo pipefail
set -E

error_handler() {
  echo "Error occurred in script at line: ${1}. Exiting."
  exit 1
}
trap 'error_handler $LINENO' ERR

BASE_URL="${BYVPN_CORE_BASE_URL:-https://builds.ci.nymte.ch/nym-vpn-client/nym-vpn-core}"

current_branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
if [[ "$current_branch" =~ ^release/ ]]; then
  TAG="$current_branch"
else
  TAG="develop"
fi

OVERRIDDEN="0"
if [[ -n "${FETCHCORE_TAG:-}" && -n "${FETCHCORE_FOLDER:-}" ]]; then
  TAG="${FETCHCORE_TAG}"
  latest_folder="${FETCHCORE_FOLDER}"
  OVERRIDDEN="1"
  echo "Override: Using TAG=${TAG}, FOLDER=${latest_folder} from FetchCore.sh"
fi

TAG_URL="${BASE_URL}/${TAG}"

if [[ "$TAG" =~ ^release/ ]]; then
  macos_pattern='nym-vpn-core-v[0-9]+\.[0-9]+\.[0-9]+(-(?:dev|beta)\.[0-9]{12})?_macos_universal\.tar\.gz'
else
  macos_pattern='nym-vpn-core-v[0-9]+\.[0-9]+\.[0-9]+-(?:dev|beta)\.[0-9]{12}_macos_universal\.tar\.gz'
fi

echo "Using build tag: ${TAG}"
echo "Base folder: ${TAG_URL}"

if [[ "$OVERRIDDEN" != "1" ]]; then
  echo "Fetching folder listing from: ${TAG_URL}"
  folder_listing="$(curl -Ls "$TAG_URL")"
  latest_folder="$(echo "$folder_listing" | grep -Eo '[0-9]{12}/' | tr -d '/' | sort | tail -n 1)"
  if [[ -z "${latest_folder}" ]]; then
    echo "❌ Error: Could not determine the latest timestamp folder from ${TAG_URL}"
    exit 1
  fi
fi

echo "Latest timestamp folder: ${latest_folder}"
RELEASE_URL="${TAG_URL}/${latest_folder}"

echo "Fetching release page content from: ${RELEASE_URL}"
release_page_content="$(curl -Ls "$RELEASE_URL")"
if [[ -z "$release_page_content" ]]; then
  echo "❌ Error: Release page content is empty at ${RELEASE_URL}"
  exit 1
fi

macos_asset="$(echo "$release_page_content" | grep -Eo "$macos_pattern" | head -n 1)"
if [[ -z "$macos_asset" ]]; then
  echo "❌ Error: Could not find macOS asset filename in the release page."
  echo "Pattern used: $macos_pattern"
  exit 1
fi

MACOS_ASSET_URL="${RELEASE_URL}/${macos_asset}"
macos_tar_name="$(basename "$MACOS_ASSET_URL")"

echo "macOS download link: ${MACOS_ASSET_URL}"
rm -f "$macos_tar_name"
curl -fL -o "$macos_tar_name" "$MACOS_ASSET_URL"
echo "✅ macOS tar downloaded: $macos_tar_name"

tar -xzf "$macos_tar_name"
extracted_folder="$(tar -tzf "$macos_tar_name" | head -n 1 | cut -d/ -f1)"
echo "Extracted folder: $extracted_folder"

# Daemon binaries → ByVPND
DEST_DAEMON="../ByVPND"
mkdir -p "$DEST_DAEMON"
for f in nym-vpnd nym-socks5-proxy nym-setup; do
  if [[ -f "${extracted_folder}/${f}" ]]; then
    cp -f "${extracted_folder}/${f}" "${DEST_DAEMON}/${f}"
    chmod +x "${DEST_DAEMON}/${f}"
    echo "✅ Copied ${f} → ${DEST_DAEMON}"
  else
    echo "⚠️  ${f} not in archive (optional for some builds)"
  fi
done

# UniFFI RPC package if present in archive
normalize_rpc() {
  local src="$1"
  find "$src" -type f \( -name '*.swift' -o -name 'Package.swift' -o -name '*.h' -o -name '*.modulemap' \) -print0 \
    | xargs -0 sed -i 's/NymVPNRpc/ByVpnRpc/g' 2>/dev/null || true
  if [[ -d "$src/NymVPNRpcUniffi.xcframework" && ! -d "$src/ByVpnRpcUniffi.xcframework" ]]; then
    mv "$src/NymVPNRpcUniffi.xcframework" "$src/ByVpnRpcUniffi.xcframework"
  fi
}

if [[ -d "${extracted_folder}/ByVpnRpc" ]]; then
  rm -rf ../ByVpnRpc
  cp -a "${extracted_folder}/ByVpnRpc" ../ByVpnRpc
  normalize_rpc ../ByVpnRpc
  echo "✅ ByVpnRpc copied"
elif [[ -d "${extracted_folder}/NymVPNRpc" ]]; then
  rm -rf ../ByVpnRpc
  cp -a "${extracted_folder}/NymVPNRpc" ../ByVpnRpc
  normalize_rpc ../ByVpnRpc
  echo "✅ NymVPNRpc → ByVpnRpc copied"
else
  echo "ℹ️  No UniFFI RPC package in macOS archive (use Scripts/BuildCore.sh for local RPC)."
fi

rm -f "$macos_tar_name"
rm -rf "$extracted_folder"
echo "🎉 Done. macOS core artifacts updated."
