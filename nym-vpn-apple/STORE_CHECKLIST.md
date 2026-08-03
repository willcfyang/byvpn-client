# ByVPN iOS / macOS App Store checklist

## Identity (done in tree)

| Item | Value |
|------|--------|
| App Bundle ID | `com.byvpn.app` |
| Packet Tunnel | `com.byvpn.app.tunnel` |
| Widget | `com.byvpn.app.widget` |
| App Group | `group.com.byvpn.app` |
| Display name | ByVPN |
| Workspace | `ByVPN.xcworkspace` |
| UniFFI module | `ByVpnCore` / `ByVpnRpc` |

## Before Archive (Mac + Xcode)

1. Set `DEVELOPMENT_TEAM` in `ByVPN.xcodeproj` (currently empty placeholder).
2. Apple Developer: App IDs + App Group `group.com.byvpn.app` + Network Extension.
3. **Release** scheme (store):
   - `LabMock` = `false` (already in Info.plist)
   - `LabAuthBaseURL` empty
   - `NSAllowsArbitraryLoads` = `false`
4. Populate real core: `Scripts/BuildCore.sh --debug` (preferred for store policy) or `BYVPN_CORE_BASE_URL=… Scripts/FetchIOSCore.sh` so `ByVpnCore` is not the placeholder.
5. Open `ByVPN.xcworkspace`, resolve packages, Archive iOS.

## Device verification

- [ ] Fresh install / onboarding
- [ ] Account login
- [ ] Connect / disconnect tunnel
- [ ] Widget + App Group state
- [ ] Log export `byvpn.log`
- [ ] No Lab auth UI on Release

## Residual scan (local)

```bash
cd nym-vpn-apple
Scripts/verify-store-identity.sh
# After Archive on Mac:
# strings ByVPN.app/ByVPN | rg -i 'nymtech|nymvpn|nym\.com'
```

Open-source dependency license metadata (`LibLicences.json`) may still list upstream authors — that is expected attribution, not product branding.

## Review notes (suggested)

- Independent ByVPN product; not affiliated with Nym Technologies.
- Own branding, bundle IDs, support URLs under byvpn.app.
- Lab / mock builds use a separate internal flow (`BYVPN_APP_LAB_MOCK=1`); not App Store Release.

## Pending fill-ins

- Production Apple Team ID
- Final byvpn.app DNS / support / terms pages
- Private core artifact URL (`BYVPN_CORE_BASE_URL`) if not shipping from public CI
