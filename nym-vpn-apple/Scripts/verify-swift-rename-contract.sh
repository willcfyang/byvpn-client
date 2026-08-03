#!/usr/bin/env bash
# Static rename-contract checks (seconds, no Rust/Xcode).
# Catches the class of CI failures we burned macOS minutes on:
#   - leftover Nym* UI symbols after ByVpn rename
#   - BuildCore/FetchIOSCore sed too broad / too narrow vs app usage
#   - duplicate String enum raw values in Constants.swift
#
# Works with ripgrep OR plain grep (macOS runners often lack rg).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
fail=0

ok() { echo "OK   $*"; }
bad() { echo "FAIL $*"; fail=1; }

# search PATTERN [path...]  — exit 0 if match
# Prefer rg; fall back to grep -R. Avoid \\b (BSD grep on macOS lacks it).
search() {
  local pattern="$1"
  shift
  if command -v rg >/dev/null 2>&1; then
    rg -q --glob '*.swift' --glob '*.sh' --glob 'Package.swift' "$pattern" "$@" 2>/dev/null
  else
    # Escape for basic ERE; callers pass literal-ish names or simple alternation
    grep -REq --include='*.swift' --include='*.sh' --include='Package.swift' "$pattern" "$@" 2>/dev/null
  fi
}

# search_hits PATTERN [path...] — print matches (best effort)
search_hits() {
  local pattern="$1"
  shift
  if command -v rg >/dev/null 2>&1; then
    rg -n --glob '*.swift' --glob '*.sh' "$pattern" "$@" 2>/dev/null || true
  else
    grep -REn --include='*.swift' --include='*.sh' "$pattern" "$@" 2>/dev/null || true
  fi
}

echo "ROOT=$ROOT"
if command -v rg >/dev/null 2>&1; then
  echo "search=rg"
else
  echo "search=grep (rg not installed)"
fi

# --- 1) Leftover UI types (definitions live under ByVpn*) ---
# Exclude Scripts/ so this checker's own messages do not self-match.
UI_LEFTOVER='Nym(Spacing|Button|Color|TextStyle|Font|Snackbar|Divider|BackButton|TunnelManager)'
if command -v rg >/dev/null 2>&1; then
  hits="$(rg -n --glob '*.swift' "${UI_LEFTOVER}" . 2>/dev/null || true)"
else
  hits="$(grep -REn --include='*.swift' -E "${UI_LEFTOVER}" . 2>/dev/null || true)"
fi
if [[ -n "$hits" ]]; then
  bad "leftover Nym* UI symbols (rename to ByVpn*)"
  echo "$hits" | head -30
else
  ok "no leftover Nym* UI symbols in Swift"
fi

# --- 2) UniFFI keepers: app still uses these; sed must NOT rename them ---
missing_keeper=0
for t in NymGatewayCache NymEnvironment; do
  if ! search "${t}" .; then
    bad "app missing expected UniFFI keeper ${t}"
    missing_keeper=1
  fi
done
[[ "$missing_keeper" -eq 0 ]] && ok "app still references UniFFI keepers (NymGateway*/NymEnvironment/…)"

# --- 3) Sed contract in BuildCore / FetchIOSCore ---
for s in Scripts/BuildCore.sh Scripts/FetchIOSCore.sh; do
  [[ -f "$s" ]] || { bad "missing $s"; continue; }
  if ! search 's/NymVpn/ByVpn/' "$s"; then
    bad "$s must rename NymVpn→ByVpn (ByVpnSubscription/ByVpnService/…)"
  else
    ok "$s renames NymVpn→ByVpn"
  fi
  if search 's/NymGateway/ByVpnGateway/|s/NymDeeplink/ByVpnDeeplink/' "$s"; then
    bad "$s must NOT rename NymGateway*/NymDeeplink* (app keepers)"
  else
    ok "$s leaves NymGateway*/NymDeeplink* alone"
  fi
done

# --- 4) App expects ByVpn* for NymVpn* UniFFI types (spot-check) ---
for t in ByVpnAccountStorage ByVpnService ByVpnSubscription; do
  if search "${t}" .; then
    ok "app uses ${t}"
  else
    bad "app missing expected ${t} (UniFFI NymVpn*→ByVpn* contract)"
  fi
done

# --- 5) Duplicate Constants.swift raw values ---
CONST="ServicesMutual/Sources/Constants/Constants.swift"
if [[ -f "$CONST" ]]; then
  if command -v rg >/dev/null 2>&1; then
    dups="$(rg -o '=\s*"([^"]+)"' -r '$1' "$CONST" 2>/dev/null | sort | uniq -d || true)"
  else
    dups="$(grep -oE '=\s*"[^"]+"' "$CONST" 2>/dev/null | sed 's/.*=\s*"//;s/"$//' | sort | uniq -d || true)"
  fi
  if [[ -n "$dups" ]]; then
    bad "duplicate Constants.swift raw values"
    echo "$dups"
  else
    ok "Constants.swift raw values unique"
  fi
else
  bad "missing $CONST"
fi

# --- 6) If ByVpnCore already present, spot-check generated names ---
if [[ -d ByVpnCore ]]; then
  if search 'NymVpn(Subscription|Service|AccountStorage)' ByVpnCore; then
    bad "ByVpnCore still has NymVpn* types — normalize (NymVpn→ByVpn) not applied"
  else
    ok "ByVpnCore has no leftover NymVpnSubscription/Service/…"
  fi
  if search 'ByVpnGatewayCache' ByVpnCore; then
    bad "ByVpnCore wrongly renamed NymGatewayCache→ByVpnGatewayCache"
  elif search 'NymGatewayCache' ByVpnCore; then
    ok "ByVpnCore keeps NymGatewayCache"
  else
    ok "ByVpnCore present (GatewayCache not in scanned sources — skip)"
  fi
else
  ok "ByVpnCore not checked out yet (skipped generated-name spot-check)"
fi

# Note: Scripts/verify-store-identity.sh needs ByVpnCore on disk — run that
# after Fetch/BuildCore, not in this preflight.

if [[ "$fail" -ne 0 ]]; then
  echo "verify-swift-rename-contract: FAILED (fix before burning macOS UniFFI minutes)"
  exit 1
fi
echo "verify-swift-rename-contract: PASSED"
exit 0
