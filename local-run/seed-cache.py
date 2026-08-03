#!/usr/bin/env python3
"""Seed NYM_VPND_CONFIG_DIR cache so local vpnd uses vpn.sf mock API."""
import json
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent
CONFIG = ROOT / "config" / "nym"
NET = CONFIG / "networks" / "mainnet"
DISCOVERY_SRC = ROOT.parent / "onidel-patches" / "vpn-sf_discovery.json"
API = "http://104.250.122.199:8088/api/v1/network/details"

NET.mkdir(parents=True, exist_ok=True)

now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.%fZ")

discovery = json.loads(DISCOVERY_SRC.read_text())
with open(NET / "mainnet_discovery.json", "w") as f:
    json.dump({"updated_at": now, "value": discovery}, f, indent=2)

with urllib.request.urlopen(API, timeout=15) as r:
    network = json.load(r)["network"]

with open(NET / "mainnet.json", "w") as f:
    json.dump({"updated_at": now, "value": network}, f, indent=2)

print(f"Wrote {NET / 'mainnet_discovery.json'}")
print(f"Wrote {NET / 'mainnet.json'}")
