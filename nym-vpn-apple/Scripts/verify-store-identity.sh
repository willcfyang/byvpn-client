#!/usr/bin/env bash
# Static checks for ByVPN store differentiation (no device / Archive required).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
fail=0

EXCLUDE=(
  --glob '!STORE_CHECKLIST.md'
  --glob '!Scripts/**'
  --glob '!**/TO BE REMOVED/**'
  --glob '!LICENSE'
  --glob '!CHANGELOG.md'
  --glob '!**/LibLicences.json'
  --glob '!**/*.ttf'
  --glob '!README.md'
)

check() {
  local label="$1" pattern="$2"
  local hits
  hits="$(rg -n "$pattern" "${EXCLUDE[@]}" . 2>/dev/null || true)"
  if [[ -n "$hits" ]]; then
    echo "FAIL $label"
    echo "$hits" | head -20
    fail=1
  else
    echo "OK   $label"
  fi
}

echo "ROOT=$ROOT"
test -f ByVPN.xcworkspace/contents.xcworkspacedata && echo "OK   workspace ByVPN.xcworkspace" || { echo "FAIL workspace"; fail=1; }
test -d ByVpnCore && echo "OK   ByVpnCore present" || { echo "FAIL ByVpnCore missing"; fail=1; }

rg -q 'PRODUCT_BUNDLE_IDENTIFIER = com.byvpn.app;' ByVPN.xcodeproj/project.pbxproj && echo "OK   app bundle id" || { echo "FAIL app bundle id"; fail=1; }
rg -q 'com.byvpn.app.tunnel' ByVPN.xcodeproj/project.pbxproj && echo "OK   tunnel bundle id" || { echo "FAIL tunnel id"; fail=1; }
rg -q 'group.com.byvpn.app' ByVPN/ByVPN.entitlements && echo "OK   app group" || { echo "FAIL app group"; fail=1; }
rg -q '<key>LabMock</key>\s*<false/>' -U ByVPN/Resources/Info.plist && echo "OK   LabMock false" || { echo "FAIL LabMock"; fail=1; }
rg -q 'import ByVpnCore' --glob '*.swift' && echo "OK   import ByVpnCore" || { echo "FAIL no ByVpnCore imports"; fail=1; }
rg -q 'LabGrotesque' --glob '*.swift' Theme UIComponents Home 2>/dev/null && { echo "FAIL LabGrotesque still in Swift"; fail=1; } || echo "OK   no LabGrotesque in app Swift"

check "no net.nymtech product ids" 'net\.nymtech'
check "no NymVPNLib in app sources" 'NymVPNLib'
check "no NymVPN product symbols" 'NymVPN'
check "no Color.Nym namespace" 'Color\.Nym|\.Nym\.(primary|background)'

if [[ "$fail" -ne 0 ]]; then
  echo "verify-store-identity: FAILED"
  exit 1
fi
echo "verify-store-identity: PASSED (device/Archive still required on Mac)"
