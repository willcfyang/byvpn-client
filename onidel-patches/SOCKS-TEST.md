# SOCKS proxy test (vpn.sf private cluster)

Test **without** full-system `connect` first. Run inside a **KVM guest** or on vpn.sf.

## Prerequisites

- Mock API: `curl http://104.250.122.199:8088/healthz`
- Built `nym-vpnd` + `nym-vpnc` with **vpn-sf** patches applied
- Gateways up on vpn.sf

## 1. Start daemon (mainnet + patched discovery → mock API)

```bash
export RUST_LOG=info
nym-vpnd -v
# another terminal:
rm -rf ~/.cache/nym-vpn 2>/dev/null || true
nym-vpnc network set mainnet
nym-vpnc network get   # should show mainnet; APIs hit 104.250.122.199:8088
```

## 2. Pin gateways

```bash
nym-vpnc tunnel set --two-hop on
nym-vpnc gateway set \
  --entry-id 3yJCWPL4X8KXNH86gYpP5LmN165Rru2jAEyxiWr9vQyP \
  --exit-id D5p6S6wiPvGYfJme5dkGvPgvcMo7Jq7FPQga3Dhhn2Vf
nym-vpnc gateway get
```

## 3. Enable SOCKS5

`gateway set` does **not** apply to SOCKS — pass the exit gateway on `socks5 enable`:

```bash
nym-vpnc socks5 enable \
  --socks5-address=127.0.0.1:1080 \
  --exit-id D5p6S6wiPvGYfJme5dkGvPgvcMo7Jq7FPQga3Dhhn2Vf
nym-vpnc socks5 status
```

`nym-socks5-proxy` must sit next to `nym-vpnd` (same directory as the daemon binary).

Account must be **ReadyToConnect** (mock API needs `nym-mock-zknym` on vpn.sf :8089).

## 4. Test traffic (guest only)

```bash
curl -v --socks5-hostname 127.0.0.1:1080 https://ifconfig.me -m 90
curl -v --socks5-hostname 127.0.0.1:1080 https://example.com -m 30
```

Host machine network is unchanged if you did not run `nym-vpnc connect`.

## 5. Stop

```bash
nym-vpnc socks5 disable
```

## Next: full tunnel

Only after SOCKS works:

```bash
nym-vpnc connect
nym-vpnc status
```

Use VM + host-only SSH per [`NYM_VM_TESTING_PLAN.md`](../../../onidel-cloud/NYM_VM_TESTING_PLAN.md).
