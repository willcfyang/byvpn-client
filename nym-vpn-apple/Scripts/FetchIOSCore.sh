#!/bin/bash
#
# Updates the iOS UniFFI core for ByVPN.
# Default source remains upstream CI unless BYVPN_CORE_BASE_URL points at a private mirror.
# After download, the SPM module is always published as ByVpnCore (never NymVPNLib).
#
# Must be run from nym-vpn-apple/Scripts.

set -euo pipefail
set -E

error_handler() {
  echo "Error occurred in script at line: ${1}. Exiting."
  exit 1
}
trap 'error_handler $LINENO' ERR

# Prefer private/store artifacts when set, e.g.:
#   export BYVPN_CORE_BASE_URL="https://artifacts.byvpn.app/nym-vpn-core"
BASE_URL="${BYVPN_CORE_BASE_URL:-https://builds.ci.nymte.ch/nym-vpn-client/nym-vpn-core}"

# -----------------------------------------------------------------------------
# 0) Determine build tag (default from git branch)
#    This may be overridden by FETCHCORE_TAG/FETCHCORE_FOLDER from FetchCore.sh
# -----------------------------------------------------------------------------
current_branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
if [[ "$current_branch" =~ ^release/ ]]; then
  TAG="$current_branch"
else
  TAG="develop"
fi

# Orchestrator override
OVERRIDDEN="0"
if [[ -n "${FETCHCORE_TAG:-}" && -n "${FETCHCORE_FOLDER:-}" ]]; then
  TAG="${FETCHCORE_TAG}"
  latest_folder="${FETCHCORE_FOLDER}"
  OVERRIDDEN="1"
  echo "Override: Using TAG=${TAG}, FOLDER=${latest_folder} from FetchCore.sh"
fi

TAG_URL="${BASE_URL}/${TAG}"

# Choose the iOS asset pattern after TAG is finalized
if [[ "$TAG" =~ ^release/ ]]; then
  # Use POSIX ERE (grep -E); avoid PCRE (?:...) which fails on macOS/GNU grep -E.
  ios_pattern='nym-vpn-core-v[0-9]+\.[0-9]+\.[0-9]+(-(dev|beta)\.[0-9]{12})?_ios_universal\.zip'
else
  ios_pattern='nym-vpn-core-v[0-9]+\.[0-9]+\.[0-9]+-(dev|beta)\.[0-9]{12}_ios_universal\.zip'
fi

echo "Using build tag: ${TAG}"
echo "Base folder: ${TAG_URL}"

# -----------------------------------------------------------------------------
# 1) Find latest timestamp folder (unless orchestrator provided it)
# -----------------------------------------------------------------------------
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

# -----------------------------------------------------------------------------
# 2) Discover iOS asset, download, extract
# -----------------------------------------------------------------------------
echo "Fetching release page content from: ${RELEASE_URL}"
release_page_content="$(curl -Ls "$RELEASE_URL")"
if [[ -z "$release_page_content" ]]; then
  echo "❌ Error: Release page content is empty at ${RELEASE_URL}"
  exit 1
fi

ios_asset="$(echo "$release_page_content" | grep -Eo "$ios_pattern" | head -n 1)"
if [[ -z "$ios_asset" ]]; then
  echo "❌ Error: Could not find iOS asset filename in the release page."
  echo "Pattern used: $ios_pattern"
  exit 1
fi

IOS_ASSET_URL="${RELEASE_URL}/${ios_asset}"
ios_zip_name="$(basename "$IOS_ASSET_URL")"

echo "iOS download link: ${IOS_ASSET_URL}"

rm -f "$ios_zip_name"

curl -fL -o "$ios_zip_name" "$IOS_ASSET_URL"
echo "✅ iOS ZIP downloaded: $ios_zip_name"

if ! command -v unzip >/dev/null 2>&1; then
  echo "❌ Error: 'unzip' not found. Please install it (e.g., 'brew install unzip')"
  exit 1
fi

unzip -q -o "$ios_zip_name"
echo "✅ iOS ZIP extracted."

extracted_folder="$(unzip -Z1 "$ios_zip_name" | head -n 1 | cut -d/ -f1)"
echo "Extracted folder: $extracted_folder"

# -----------------------------------------------------------------------------
# 3) Normalize upstream NymVPNLib → ByVpnCore and copy into project root
# -----------------------------------------------------------------------------
normalize_and_copy_core() {
  local extract_root="$1"
  local src=""

  if [[ -d "$extract_root/ByVpnCore" ]]; then
    src="$extract_root/ByVpnCore"
  elif [[ -d "$extract_root/NymVPNLib" ]]; then
    echo "Renaming extracted NymVPNLib → ByVpnCore..."
    mv "$extract_root/NymVPNLib" "$extract_root/ByVpnCore"
    src="$extract_root/ByVpnCore"
  else
    echo "❌ Error: neither ByVpnCore nor NymVPNLib found in $extract_root"
    return 1
  fi

  # Rewrite module + NymVpn* → ByVpn*; keep NymGateway*/NymDeeplink*/NymEnvironment
  find "$src" -type f \( -name '*.swift' -o -name 'Package.swift' -o -name '*.h' -o -name '*.modulemap' \) -print0 \
    | xargs -0 sed -i \
      -e 's/NymVPNLib/ByVpnCore/g' \
      -e 's/NymVpn/ByVpn/g' \
      2>/dev/null || true

  if [[ -f "$src/Package.swift" ]]; then
    sed -i 's/name: "NymVPNLib"/name: "ByVpnCore"/g' "$src/Package.swift" 2>/dev/null || true
  fi

  # SPM expects Sources/<target>; upstream zip uses Sources/NymVPNLib
  if [[ -d "$src/Sources/NymVPNLib" ]]; then
    rm -rf "$src/Sources/ByVpnCore"
    mv "$src/Sources/NymVPNLib" "$src/Sources/ByVpnCore"
  fi
  if [[ -d "$src/NymVPNLibUniffi.xcframework" && ! -d "$src/ByVpnCoreUniffi.xcframework" ]]; then
    mv "$src/NymVPNLibUniffi.xcframework" "$src/ByVpnCoreUniffi.xcframework"
  fi

  echo "Copying ByVpnCore into project root (../).."
  rm -rf ../ByVpnCore
  cp -a "$src" ../ByVpnCore
  echo "✅ ByVpnCore copied to nym-vpn-apple/"
}

normalize_and_copy_core "$extracted_folder"

# -----------------------------------------------------------------------------
# 4) Cleanup extracted folder + ZIP
# -----------------------------------------------------------------------------
rm -f "$ios_zip_name"
rm -rf "$extracted_folder"
echo "✅ Removed ZIP and extracted folder from Scripts."

echo "🎉 Done. ByVpnCore is updated in project root."
