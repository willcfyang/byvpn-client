# Local client → vpn.sf mock API

Connect from **this machine** to the private cluster at `http://104.250.122.199:8088/api/` (not SSH into vpn.sf).

## One-time setup

Binaries are in `bin/` (copied from vpn.sf). Cache is seeded to `config/nym/networks/mainnet/`.

## Run (needs sudo for `/var/run/nym-vpn.sock` + tunnel)

In a terminal on this host:

```bash
cd 6/nym-vpn-client/local-run
bash run-vpn.sh
```

### Ubuntu desktop (labmock / APK parity)

Username/password UI + mock discovery (same as Android labmock):

```bash
cd 6/nym-vpn-client/local-run
bash run-lab-desktop.sh
```

Starts `nym-vpnd` with mock config + `NYM_VPN_LAB_SKIP_CONNECTION_PROBE=1`, then launches `nym-vpn-app` with lab auth. Binary: `/mnt/win/D/android-build/desktop/nym-vpn-app` (or `src-tauri/target/release` after `LAB_MOCK=1` rebuild).

That starts:

- `nym-vpnd -vv` — **TRACE** logs (also `-v` = DEBUG only)
- `RUST_LOG=nym_vpn_lib=debug,...` for module-level detail
- `nym-vpnc account set` + `connect` to pinned vpn.sf gateways
- background `monitor.sh` → `log/monitor.log`

## Debug / more logs

| Flag / env | Effect |
|------------|--------|
| `nym-vpnd -v` | DEBUG |
| `nym-vpnd -vv` | TRACE |
| `RUST_LOG=nym_vpn_lib=trace,...` | Finer-grained filters |
| `log/vpnd-foreground.log` | vpnd stdout/stderr |
| `log/monitor.log` | status poll every 5s; stops after **3** connect tries (`MAX_CONNECT_ATTEMPTS`) and runs `nym-vpnc disconnect` |

Example:

```bash
export RUST_LOG=nym_vpn_lib=trace,nym_vpn_account_controller=trace
sudo env NYM_VPND_CONFIG_DIR=$PWD/config/nym NYM_VPND_DATA_DIR=$PWD/data \
  ./bin/nym-vpnd -vv run-with-args --disable-client-verification
```

## Monitor only

```bash
bash start-monitor-bg.sh
tail -f log/monitor.log log/vpnd-foreground.log
```

Monitor exits with failure if `try #` reaches **3** (no more than three connect attempts), then disconnects so vpnd does not keep retrying. Override: `MAX_CONNECT_ATTEMPTS=3 MONITOR_INTERVAL=5 bash monitor.sh`.

## Stop

```bash
sudo killall nym-vpnd
kill $(cat monitor.pid) 2>/dev/null
```
