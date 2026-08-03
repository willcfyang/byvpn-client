#!/usr/bin/env bash
# Static rename-contract checks (seconds, no Rust/Xcode).
# Catches the class of CI failures we burned macOS minutes on:
#   - leftover Nym* UI symbols after ByVpn rename
#   - BuildCore/FetchIOSCore sed too broad / too narrow vs app usage
#   - duplicate String enum raw values in Constants.swift
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO="$(cd "${ROOT}/.." && pwd)"
cd "$ROOT"
fail=0

ok() { echo "OK   $*"; }
bad() { echo "FAIL $*"; fail=1; }

echo "ROOT=$ROOT"

# --- 1) Leftover UI types (definitions live under ByVpn*) ---
UI_LEFTOVER='Nym(Spacing|Button|Color|TextStyle|Font|Snackbar|Divider|BackButton|TunnelManager)'
if hits="$(rg -n --glob '*.swift' "\\b${UI_LEFTOVER}\\b" . 2>/dev/null || true)" && [[ -n "$hits" ]]; then
  bad "leftover Nym* UI symbols (use ByVpn*)"
  echo "$hits" | head -30
else
  ok "no leftover NymSpacing/NymButton/…"
fi

# --- 2) UniFFI keepers: app still uses these; sed must NOT rename them ---
KEEPERS=(NymGatewayCache NymDeeplinks NymDeeplinkMnemonic NymEnvironment NymOfflineMonitor)
missing_keeper=0
for t in "${KEEPERS[@]}"; do
  if ! rg -q --glob '*.swift' "\\b${t}\\b" . 2>/dev/null; then
    # Not every keeper must appear; warn only if GatewayCache missing (always used on iOS)
    if [[ "$t" == "NymGatewayCache" || "$t" == "NymEnvironment" ]]; then
      bad "app missing expected UniFFI keeper ${t}"
      missing_keeper=1
    fi
  fi
done
[[ "$missing_keeper" -eq 0 ]] && ok "app still references UniFFI keepers (NymGateway*/NymEnvironment/…)"

# --- 3) Sed contract in BuildCore / FetchIOSCore ---
SCRIPTS=(Scripts/BuildCore.sh Scripts/FetchIOSCore.sh)
for s in "${SCRIPTS[@]}"; do
  [[ -f "$s" ]] || { bad "missing $s"; continue; }
  if ! rg -q "s/NymVpn/ByVpn/" "$s"; then
    bad "$s must rename NymVpn→ByVpn (ByVpnSubscription/ByVpnService/…)"
  else
    ok "$s renames NymVpn→ByVpn"
  fi
  if rg -q "s/NymGateway/ByVpnGateway/|s/NymDeeplink/ByVpnDeeplink/" "$s"; then
    bad "$s must NOT rename NymGateway*/NymDeeplink* (app keepers)"
  else
    ok "$s leaves NymGateway*/NymDeeplink* alone"
  fi
done

# --- 4) App expects ByVpn* for NymVpn* UniFFI types (spot-check) ---
NEED_BYVPN=(ByVpnAccountStorage ByVpnService ByVpnSubscription)
for t in "${NEED_BYVPN[@]}"; do
  if rg -q --glob '*.swift' "\\b${t}\\b" . 2>/dev/null; then
    ok "app uses ${t}"
  else
    bad "app missing expected ${t} (UniFFI NymVpn*→ByVpn* contract)"
  fi
done

# --- 5) Duplicate Constants.swift raw values ---
CONST="ServicesMutual/Sources/Constants/Constants.swift"
if [[ -f "$CONST" ]]; then
  dups="$(rg -o '=\s*"([^"]+)"' -r '$1' "$CONST" 2>/dev/null | sort | uniq -d || true)"
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
  gen="$(find ByVpnCore -name '*.swift' -type f | head -5 || true)"
  if [[ -n "$gen" ]]; then
    if rg -q '\bNymVpn(Subscription|Service|AccountStorage)\b' ByVpnCore --glob '*.swift' 2>/dev/null; then
      bad "ByVpnCore still has NymVpn* types — normalize (NymVpn→ByVpn) not applied"
    else
      ok "ByVpnCore has no leftover NymVpnSubscription/Service/…"
    fi
    if rg -q '\bByVpnGatewayCache\b' ByVpnCore --glob '*.swift' 2>/dev/null; then
      bad "ByVpnCore wrongly renamed NymGatewayCache→ByVpnGatewayCache"
    elif rg -q '\bNymGatewayCache\b' ByVpnCore --glob '*.swift' 2>/dev/null; then
      ok "ByVpnCore keeps NymGatewayCache"
    else
      ok "ByVpnCore present (GatewayCache not in scanned sources — skip)"
    fi
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
