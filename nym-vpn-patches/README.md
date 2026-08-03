# Nym VPN lab patches (ByVPN)

Shallow `nymtech/nym` (`vpn/release/2026.9-venaco`) with lab-only changes used as path deps from `nym-vpn-core/Cargo.toml` (`../../nym-vpn-patches/nym/...`).

On GitHub Actions, `build-byvpn-ios` symlinks this directory beside the checkout so Cargo path resolution matches the ocean monorepo layout (`6/nym-vpn-patches` sibling of `6/nym-vpn-client`).
