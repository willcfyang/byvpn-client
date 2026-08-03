# ByVPN iOS CI

Private repo: https://github.com/willcfyang/byvpn-client

Hosted runner: GitHub Actions `macos-15` via `.github/workflows/build-byvpn-ios.yml`  
(manual `workflow_dispatch` only — does not run on every push).

Upstream Nym workflows (self-hosted `AppleSilicon`, Nym bundle IDs) live under `.github/workflows.upstream/` for reference only.

## Bundle IDs

| Item | Value |
|------|--------|
| App | `com.byvpn.app` |
| Packet Tunnel | `com.byvpn.app.tunnel` |
| Widget | `com.byvpn.app.widget` |
| App Group | `group.com.byvpn.app` |
| Workspace / scheme | `ByVPN.xcworkspace` / `ByVPN` |

## How to run

1. Open **Actions → build-byvpn-ios → Run workflow**
2. `core_source`:
   - **fetch** (default): download prebuilt UniFFI core (`Scripts/FetchIOSCore.sh`)
   - **build**: compile Rust core on the Mac runner (`Scripts/BuildCore.sh --debug`) — slower, burns more minutes. Needs repo-root `nym-vpn-patches/` (lab nym path deps); the workflow symlinks it to `../../nym-vpn-patches` relative to `nym-vpn-core`.
3. `signed`:
   - **false** (default): iOS Simulator smoke build with `CODE_SIGNING_ALLOWED=NO`
   - **true**: ad-hoc Archive + IPA (needs secrets below)

Optional secret `BYVPN_CORE_BASE_URL` points `FetchIOSCore.sh` at a private core mirror; if unset, the script uses its default upstream CI base URL.

## Secrets (signed / device install)

Required when `signed=true`:

| Secret | Contents |
|--------|----------|
| `APPLE_TEAM_ID` | 10-char Team ID |
| `BUILD_CERTIFICATE_BASE64` | Distribution (or Ad Hoc) `.p12`, base64 |
| `BUILD_CERTIFICATE_PASSWORD` | `.p12` password |
| `BUILD_PROVISION_PROFILE_BASE64` | App profile for `com.byvpn.app` |
| `BUILD_PROVISION_PROFILE_TUNNEL_BASE64` | Tunnel profile for `com.byvpn.app.tunnel` |

Optional later (TestFlight / ASC automation):

| Secret | Purpose |
|--------|---------|
| `APP_STORE_CONNECT_API_KEY` | Key ID |
| `APP_STORE_CONNECT_API_ISSUER_ID` | Issuer UUID |
| `APP_STORE_CONNECT_API_PRIVATE_KEY` | `.p8` PEM body |

Encode profiles/certs:

```bash
base64 -i YourApp.mobileprovision | tr -d '\n' > app.b64
base64 -i YourTunnel.mobileprovision | tr -d '\n' > tunnel.b64
base64 -i cert.p12 | tr -d '\n' > cert.b64
```

## Apple Developer checklist (before signed builds work)

1. Enroll in **Apple Developer Program** (~$99/yr) — required for Network Extension VPN.
2. Create App IDs: `com.byvpn.app`, `com.byvpn.app.tunnel` (+ widget if needed).
3. Enable **Network Extensions** + **App Groups** (`group.com.byvpn.app`) on those IDs.
4. Create Ad Hoc (lab) or App Store distribution cert + provisioning profiles that include your test devices.
5. Set `DEVELOPMENT_TEAM` in Xcode / secrets (`APPLE_TEAM_ID`).
6. Add the secrets above, then run workflow with `signed=true`.

Without Apple materials, use `signed=false` to validate that the project still compiles on a hosted Mac.

## Cost note

Private repos have limited free Actions minutes; **macOS minutes cost more** than Linux. Prefer `fetch` + simulator smoke until signing is ready. Do not enable push/PR triggers until you accept the burn rate.

## Local Mac (alternative to Actions)

See `nym-vpn-apple/STORE_CHECKLIST.md`. Same bundle IDs; build with Xcode Archive after `Scripts/BuildCore.sh --debug` or `FetchIOSCore.sh`.

## Core mirror (vpn.sf)

Secret `BYVPN_CORE_BASE_URL` → `http://104.250.122.199/core/nym-vpn-core`

Layout matches `FetchIOSCore.sh`:

```
/core/nym-vpn-core/develop/<YYYYMMDDHHMM>/nym-vpn-core-v*-dev.<ts>_ios_universal.zip
```

Current seed: Nym `nym-vpn-core-v1.16.0` iOS universal (renamed for develop pattern). Replace with a newer ByVPN-built core when available.

