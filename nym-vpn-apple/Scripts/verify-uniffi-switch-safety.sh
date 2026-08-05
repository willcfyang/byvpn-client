#!/usr/bin/env bash
# Static guards that catch UniFFI churn / NTFS "fake commit" before macOS archive.
# No Xcode required. Run from nym-vpn-apple/ or via Scripts/…
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
REPO_ROOT="$(cd "$ROOT/.." && pwd)"
fail=0
ok() { echo "OK   $*"; }
bad() { echo "FAIL $*"; fail=1; }

echo "ROOT=$ROOT"

# --- 1) NTFS / index sync: working tree blob must match HEAD for critical files ---
# (We burned a CI cycle when ErrorReason was "fixed" on disk but not in the commit.)
CRITICAL=(
  "ServicesMutual/Sources/ErrorReason/ErrorReason.swift"
  "ServicesIOS/Sources/ErrorHandler/VPNErrorReason.swift"
)
if git -C "$REPO_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  for rel in "${CRITICAL[@]}"; do
    f="$ROOT/$rel"
    [[ -f "$f" ]] || { bad "missing $rel"; continue; }
    wt="$(git -C "$REPO_ROOT" hash-object "$f")"
    # Prefer staged; fall back to HEAD
    if idx="$(git -C "$REPO_ROOT" rev-parse ":nym-vpn-apple/$rel" 2>/dev/null)"; then
      :
    elif idx="$(git -C "$REPO_ROOT" rev-parse "HEAD:nym-vpn-apple/$rel" 2>/dev/null)"; then
      :
    else
      bad "not in git: nym-vpn-apple/$rel"
      continue
    fi
    if [[ "$wt" != "$idx" ]]; then
      bad "nym-vpn-apple/$rel working-tree ≠ git blob (wt=$wt git=$idx) — re-add via hash-object before push"
    else
      ok "git blob synced: $rel"
    fi
  done
else
  ok "skip git blob sync (not a git checkout)"
fi

# --- 2) Forbid brittle UniFFI PascalCase switches in iOS error mappers ---
# develop ByVpnCore renames/drops cases often; map via String(describing:) instead.
BRITTLE_PAT='case (let )?\.(Initialization|InternalError|Storage|VpnApi|RequestZkNym|AccountDoesntExistOnChain|AccountNotDecentralised|AccountDecentralised|InsufficientFunds|ZkNymAcquisitionFailure|NyxdConnectionFailure|NyxdQueryFailure|InvalidSecret|InitLogs|DeeplinkError|FetchEnvironment|LinkPrivyAccount|GetZkNymsAvailableForDownloadEndpointFailure|CreateEcashKeyPair|Timeout|StatusCode)\b'
if command -v rg >/dev/null 2>&1; then
  hits="$(rg -n --glob '*.swift' -e "$BRITTLE_PAT" ServicesIOS/Sources/ErrorHandler 2>/dev/null || true)"
else
  hits="$(grep -REn --include='*.swift' -E "$BRITTLE_PAT" ServicesIOS/Sources/ErrorHandler 2>/dev/null || true)"
fi
if [[ -n "${hits//[$'\n']/}" ]]; then
  bad "ServicesIOS ErrorHandler still switches on UniFFI PascalCase cases (breaks when core churns)"
  echo "$hits" | head -40
else
  ok "ServicesIOS ErrorHandler avoids brittle UniFFI PascalCase switches"
fi

# --- 3) ErrorStateReason iOS mapper must have @unknown default ---
ER="ServicesMutual/Sources/ErrorReason/ErrorReason.swift"
if [[ -f "$ER" ]]; then
  if command -v rg >/dev/null 2>&1; then
    block="$(rg -n -U --multiline '#if os\(iOS\)[\s\S]*?init\(with errorStateReason[\s\S]*?#endif' "$ER" || true)"
  else
    block="$(awk '/#if os\(iOS\)/{p=1} p{print} /#endif/{if(p&&seen){exit} if(p)seen=1}' "$ER")"
  fi
  if echo "$block" | grep -q 'errorStateReason' && ! echo "$block" | grep -q '@unknown default'; then
    bad "ErrorReason iOS ErrorStateReason switch missing @unknown default"
  else
    ok "ErrorReason iOS switch has @unknown default (or no switch)"
  fi
  # identity / FDA cases must not be hard-required on iOS UniFFI switch
  if echo "$block" | grep -E 'case \.(invalidEntryGatewayIdentity|needFullDiskPermissions|splitTunnel)\b' >/dev/null; then
    bad "ErrorReason iOS still hard-switches macOS/missing UniFFI cases"
  else
    ok "ErrorReason iOS does not hard-require missing UniFFI cases"
  fi
else
  bad "missing $ER"
fi

if [[ "$fail" -ne 0 ]]; then
  echo "verify-uniffi-switch-safety: FAILED"
  exit 1
fi
echo "verify-uniffi-switch-safety: PASSED"
exit 0
