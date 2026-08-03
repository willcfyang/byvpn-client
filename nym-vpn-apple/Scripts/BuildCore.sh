#!/usr/bin/env bash
set -euo pipefail

# Parse flags
RELEASE="true"
IOS_ONLY="false"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --debug)
      RELEASE="false"
      shift
      ;;
    --ios-only)
      # Skip macOS.mk / ByVpnRpc rebuild / ByVPND binaries (iOS CI / simulator smoke).
      IOS_ONLY="true"
      shift
      ;;
    *)
      echo "[BuildCore] Unknown option: $1"
      echo "Usage: $0 [--debug] [--ios-only]"
      exit 1
      ;;
  esac
done

if [[ "${RELEASE}" == "true" ]]; then
  echo "[BuildCore] 🚀 Release build — requires code signing."
  echo "[BuildCore] For a debug build, run: $0 --debug"
else
  echo "[BuildCore] 🛠  Debug build"
fi
if [[ "${IOS_ONLY}" == "true" ]]; then
  echo "[BuildCore] iOS-only: skip macOS.mk / ByVpnRpc / ByVPND"
fi

# Resolve paths relative to this script
SCRIPT_DIR="$(cd -- "$(dirname "$0")" && pwd)"
APPLE_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
CLIENT_ROOT="$(cd -- "${APPLE_ROOT}/.." && pwd)"
CORE_ROOT="$(cd -- "${CLIENT_ROOT}/nym-vpn-core" && pwd)"

echo "[BuildCore] CORE_ROOT=${CORE_ROOT}"
echo "[BuildCore] APPLE_ROOT=${APPLE_ROOT}"
echo "[BuildCore] CLIENT_ROOT=${CLIENT_ROOT}"

# Configure sccache if available
if command -v sccache &>/dev/null; then
  export RUSTC_WRAPPER="$(which sccache)"
  export SCCACHE_DIR="${HOME}/.cache/sccache"
  export SCCACHE_CACHE_SIZE="50G"
  export SCCACHE_IDLE_TIMEOUT="0"
  echo "[BuildCore] Using sccache at ${RUSTC_WRAPPER}"
else
  echo "[BuildCore] ⚠️ sccache not found, skipping cache setup"
fi

# 1) Build iOS
cd "${CORE_ROOT}"
make -f iOS.mk RELEASE="${RELEASE}"

# 2) Copy UniFFI lib → ByVpnCore (upstream still emits NymVPNLib)
LIB_CRATE="${CORE_ROOT}/crates/nym-vpn-lib-uniffi"
if [[ -d "${LIB_CRATE}/ByVpnCore" ]]; then
  LIB_SRC="${LIB_CRATE}/ByVpnCore"
elif [[ -d "${LIB_CRATE}/NymVPNLib" ]]; then
  LIB_SRC="${LIB_CRATE}/NymVPNLib"
else
  echo "[BuildCore][ERROR] Neither ByVpnCore nor NymVPNLib found under ${LIB_CRATE}"
  exit 1
fi
LIB_DEST="${APPLE_ROOT}/ByVpnCore"
rm -rf "${LIB_DEST}"
cp -R "${LIB_SRC}" "${LIB_DEST}"
# Normalize module name for store differentiation
find "${LIB_DEST}" -type f \( -name '*.swift' -o -name 'Package.swift' -o -name '*.h' -o -name '*.modulemap' \) -print0 \
  | xargs -0 sed -i '' 's/NymVPNLib/ByVpnCore/g' 2>/dev/null \
  || find "${LIB_DEST}" -type f \( -name '*.swift' -o -name 'Package.swift' -o -name '*.h' -o -name '*.modulemap' \) -print0 \
       | xargs -0 sed -i 's/NymVPNLib/ByVpnCore/g'
# Rename xcframework directory if needed
if [[ -d "${LIB_DEST}/NymVPNLibUniffi.xcframework" && ! -d "${LIB_DEST}/ByVpnCoreUniffi.xcframework" ]]; then
  mv "${LIB_DEST}/NymVPNLibUniffi.xcframework" "${LIB_DEST}/ByVpnCoreUniffi.xcframework"
fi
echo "[BuildCore] Copied/normalized ByVpnCore → ${LIB_DEST}"

# iOS CI: stop before xcodebuild/header-flatten (observed SIGABRT exit 134 on runners).
if [[ "${IOS_ONLY}" == "true" ]]; then
  echo "[BuildCore] ✅ Finished (iOS-only; kept existing ByVpnRpc placeholder if present)."
  exit 0
fi

# 2b) Flatten xcframework headers for Xcode 26+ explicit module builds
# Avoid pipefail+head SIGPIPE from `sort | head` under set -euo pipefail.
XCODE_VER="$(xcodebuild -version 2>/dev/null | awk 'NR==1 { print $2; exit }')"
XCODE_MAJOR="${XCODE_VER%%.*}"
XCODE_MINOR="${XCODE_VER#*.}"
XCODE_MINOR="${XCODE_MINOR%%.*}"
if [[ "${XCODE_MAJOR:-0}" -gt 26 || ( "${XCODE_MAJOR:-0}" -eq 26 && "${XCODE_MINOR:-0}" -ge 4 ) ]]; then
  for HEADERS_DIR in "${LIB_DEST}"/ByVpnCoreUniffi.xcframework/*/Headers "${LIB_DEST}"/NymVPNLibUniffi.xcframework/*/Headers; do
    [[ -d "${HEADERS_DIR}" ]] || continue
    for SUBDIR in "${HEADERS_DIR}"/*/; do
      [[ -d "${SUBDIR}" ]] || continue
      cp -n "${SUBDIR}"* "${HEADERS_DIR}/" 2>/dev/null || true
    done
  done
  echo "[BuildCore] Flattened ByVpnCore xcframework headers (Xcode ${XCODE_VER})"
else
  echo "[BuildCore] Skipping header flatten (Xcode ${XCODE_VER:-unknown} < 26.4)"
fi

# 3) Build macOS (produces upload/mac/nym-vpnd if macOS.mk has vpnd targets)
make -f macOS.mk libwg nym-setup nym-vpnd nym-socks5-proxy rpc-swift-package RELEASE="${RELEASE}"

# 4) Copy UniFFI RPC → ByVpnRpc (upstream still emits NymVPNRpc)
RPC_CRATE="${CORE_ROOT}/crates/nym-vpn-rpc-uniffi"
if [[ -d "${RPC_CRATE}/ByVpnRpc" ]]; then
  RPC_SRC="${RPC_CRATE}/ByVpnRpc"
elif [[ -d "${RPC_CRATE}/NymVPNRpc" ]]; then
  RPC_SRC="${RPC_CRATE}/NymVPNRpc"
else
  echo "[BuildCore][ERROR] Neither ByVpnRpc nor NymVPNRpc found under ${RPC_CRATE}"
  exit 1
fi
RPC_DEST="${APPLE_ROOT}/ByVpnRpc"
rm -rf "${RPC_DEST}"
cp -R "${RPC_SRC}" "${RPC_DEST}"
find "${RPC_DEST}" -type f \( -name '*.swift' -o -name 'Package.swift' -o -name '*.h' -o -name '*.modulemap' \) -print0 \
  | xargs -0 sed -i '' 's/NymVPNRpc/ByVpnRpc/g' 2>/dev/null \
  || find "${RPC_DEST}" -type f \( -name '*.swift' -o -name 'Package.swift' -o -name '*.h' -o -name '*.modulemap' \) -print0 \
       | xargs -0 sed -i 's/NymVPNRpc/ByVpnRpc/g'
if [[ -d "${RPC_DEST}/NymVPNRpcUniffi.xcframework" && ! -d "${RPC_DEST}/ByVpnRpcUniffi.xcframework" ]]; then
  mv "${RPC_DEST}/NymVPNRpcUniffi.xcframework" "${RPC_DEST}/ByVpnRpcUniffi.xcframework"
fi
echo "[BuildCore] Copied/normalized ByVpnRpc → ${RPC_DEST}"

# 4b) Flatten xcframework headers for Xcode 26+ explicit module builds
if [[ "${XCODE_MAJOR:-0}" -gt 26 || ( "${XCODE_MAJOR:-0}" -eq 26 && "${XCODE_MINOR:-0}" -ge 4 ) ]]; then
  for HEADERS_DIR in "${RPC_DEST}"/ByVpnRpcUniffi.xcframework/*/Headers "${RPC_DEST}"/NymVPNRpcUniffi.xcframework/*/Headers; do
    [[ -d "${HEADERS_DIR}" ]] || continue
    for SUBDIR in "${HEADERS_DIR}"/*/; do
      [[ -d "${SUBDIR}" ]] || continue
      cp -n "${SUBDIR}"* "${HEADERS_DIR}/" 2>/dev/null || true
    done
  done
  echo "[BuildCore] Flattened ByVpnRpc xcframework headers (Xcode ${XCODE_VER})"
else
  echo "[BuildCore] Skipping header flatten (Xcode ${XCODE_VER:-unknown} < 26.4)"
fi

# 5) Copy binaries to apple Daemon folder
VPND_SRC_DIR="${CORE_ROOT}/upload/mac"
VPND_DEST_DIR="${APPLE_ROOT}/ByVPND"
mkdir -p "${VPND_DEST_DIR}"
for f in nym-vpnd nym-socks5-proxy nym-setup; do
  if [[ ! -f "${VPND_SRC_DIR}/${f}" ]]; then
    echo "[BuildCore][ERROR] ${VPND_SRC_DIR}/${f} not found. Make sure macOS.mk builds vpnd-universal."
    exit 1
  fi
  cp -f "${VPND_SRC_DIR}/${f}" "${VPND_DEST_DIR}"
  chmod +x "${VPND_DEST_DIR}/${f}"
  echo "[BuildCore] Copied ${f} → ${VPND_DEST_DIR}"
done

# Print sccache stats
if command -v sccache &>/dev/null; then
  echo "[BuildCore] 🧱 sccache stats:"
  sccache --show-stats || true
fi

echo "[BuildCore] ✅ Finished."
