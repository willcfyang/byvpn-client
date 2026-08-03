# Account + connect (private cluster)

`nym-vpnc status` showing **`Error state: DeviceLoggedOut`** means **no VPN account is stored** on the client (`AccountControllerState::LoggedOut`). Discovery `credentialMode: false` does not skip this — you must **`account set`** (or lab username/password login on Android) and the mock API must answer account routes.

## Lab Android (username / password)

**NymVPN Lab** (`labmock` APK) hides the 24-word UI. Auth is against the mock API:

| Endpoint | Method | Body |
|----------|--------|------|
| `/api/public/v1/lab/auth/register` | POST | `{"username":"alice","password":"secret123"}` |
| `/api/public/v1/lab/auth/login` | POST | same → returns `{"username","mnemonic"}` |

- User DB: SQLite at `/var/lib/nym-mock-api/lab_auth.db` on vpn.sf (created by `nym-mock-api`).
- Password min 8 chars; username 3–32 chars `[A-Za-z0-9_]`.
- App still calls `storeMnemonic` internally after login (users never see the phrase).

Deploy mock API after pulling `internal/labauth/`:

```bash
cd 6/nym-vpn-mock && bash scripts/deploy-vpn-sf.sh
```

Build lab APK:

```bash
source /mnt/win/D/android-build/env.sh
cd 6/nym-vpn-client/nym-vpn-android && ./gradlew assembleLabmockDebug
```

## 1. Mock API (vpn.sf)

Deploy updated `nym-vpn-mock` (includes `/public/v1/health` and `/public/v1/account/...` stubs):

```bash
cd 6/nym-vpn-mock && bash scripts/deploy-vpn-sf.sh
curl -s http://104.250.122.199:8088/api/public/v1/health
```

## 2. Client VM (test-any.sf) — use console if SSH is down

```bash
export PATH=/opt/nym-vpn/bin:$PATH
nym-vpnc disconnect 2>/dev/null || true
killall nym-vpnd nym-vpnc 2>/dev/null || true
ip link del nymwg 2>/dev/null; ip link del nymtun0 2>/dev/null

nym-vpnd -v &   # or systemd if configured
sleep 2
nym-vpnc network set mainnet
nym-vpnc tunnel set --two-hop on
nym-vpnc gateway set \
  --entry-id 3yJCWPL4X8KXNH86gYpP5LmN165Rru2jAEyxiWr9vQyP \
  --exit-id D5p6S6wiPvGYfJme5dkGvPgvcMo7Jq7FPQga3Dhhn2Vf

# Test mnemonic (same as nym-vpn-account-controller integration tests)
nym-vpnc account set "dash hungry rate famous lesson march suit refuse excite soul faith bid buddy tortoise melody advice dirt coffee fluid sure air decrease cargo work"
nym-vpnc account get    # expect account_state: ReadyToConnect (after sync)

nym-vpnc lan set allow   # keep SSH on LAN while testing full tunnel
nym-vpnc connect
nym-vpnc status          # expect Connected, not DeviceLoggedOut
```

## 3. SOCKS (optional, after account works)

```bash
nym-vpnc socks5 enable --socks5-address=127.0.0.1:10800
curl -v --proxy socks5h://127.0.0.1:10800 https://ifconfig.me -m 30
```

Do **not** run `connect` on **vpn.sf** (cluster host).
