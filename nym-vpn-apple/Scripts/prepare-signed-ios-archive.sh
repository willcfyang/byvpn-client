#!/usr/bin/env bash
# Prepare ByVPN iOS project for a Manual / App Store archive on CI.
#
# - Strip Associated Domains from app entitlements (current App Store profile
#   does not include com.apple.developer.associated-domains).
# - Drop ByVPNWidgetExtension from the iOS app embed + dependencies (no widget
#   profile yet).
# - Force Manual signing + Apple Distribution + profile names for ByVPN /
#   ByVPNTunnel Release configs.
#
# Env:
#   APPLE_TEAM_ID              required
#   BYVPN_APP_PROFILE          default: byvpn
#   BYVPN_TUNNEL_PROFILE       default: byvpntunnel
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PBX="$ROOT/ByVPN.xcodeproj/project.pbxproj"
APP_ENT="$ROOT/ByVPN/ByVPN.entitlements"

TEAM="${APPLE_TEAM_ID:?APPLE_TEAM_ID is required}"
APP_PROFILE="${BYVPN_APP_PROFILE:-byvpn}"
TUNNEL_PROFILE="${BYVPN_TUNNEL_PROFILE:-byvpntunnel}"

python3 - "$PBX" "$APP_ENT" "$TEAM" "$APP_PROFILE" "$TUNNEL_PROFILE" <<'PY'
import plistlib, re, sys
from pathlib import Path

pbx_path, ent_path, team, app_profile, tunnel_profile = sys.argv[1:6]

# 1) Entitlements: drop associated-domains (profile mismatch).
ent = Path(ent_path)
data = plistlib.loads(ent.read_bytes())
if "com.apple.developer.associated-domains" in data:
    del data["com.apple.developer.associated-domains"]
    ent.write_bytes(plistlib.dumps(data, fmt=plistlib.FMT_XML))
    print(f"stripped associated-domains from {ent}")
else:
    print(f"no associated-domains in {ent}")

# 2) pbxproj: remove widget embed + ByVPN target deps on widget.
text = Path(pbx_path).read_text()
text2, n_embed = re.subn(
    r"\t\t\t\tD9D9549F2F7BCDAF0040753C /\* ByVPNWidgetExtension\.appex in Embed Foundation Extensions \*/,\n",
    "",
    text,
)
n_deps = 0
for dep_id in (
    "D9D9549E2F7BCDAF0040753C",
    "D9D954B52F7BCDBD0040753C",
    "D9CA7A8F2F7D2A460036DEDF",
):
    text2, n = re.subn(rf"\t\t\t\t{dep_id} /\* PBXTargetDependency \*/,\n", "", text2)
    n_deps += n
print(f"removed widget embed lines={n_embed} dependency refs={n_deps}")
if n_embed == 0 or n_deps == 0:
    print("warning: expected to remove widget embed and deps; check pbxproj IDs")
text = text2

# 3) Patch Release buildSettings identified by CODE_SIGN_ENTITLEMENTS path.
def patch_release_by_entitlements(src: str, entitlements: str, profile: str, label: str) -> str:
    needle = f"CODE_SIGN_ENTITLEMENTS = {entitlements};"
    for m in re.finditer(re.escape(needle), src):
        start = src.rfind("buildSettings = {", 0, m.start())
        if start < 0:
            continue
        end = src.find("\n\t\t\tname = ", m.end())
        if end < 0:
            continue
        name_snip = src[end : end + 80]
        if "name = Release;" not in name_snip:
            continue
        block = src[start:end]

        def set_key(block: str, key: str, value: str) -> str:
            repl = f"{key} = {value};"
            if re.search(rf"{re.escape(key)} = [^;]+;", block):
                return re.sub(rf"{re.escape(key)} = [^;]+;", repl, block, count=1)
            return block.replace(
                "buildSettings = {",
                f"buildSettings = {{\n\t\t\t\t{repl}",
                1,
            )

        new_block = block
        new_block = set_key(new_block, "CODE_SIGN_STYLE", "Manual")
        new_block = set_key(new_block, "CODE_SIGN_IDENTITY", '"Apple Distribution"')
        new_block = set_key(new_block, "DEVELOPMENT_TEAM", f'"{team}"')
        new_block = set_key(new_block, "PROVISIONING_PROFILE_SPECIFIER", f'"{profile}"')
        print(f"patched Release signing for {label} -> profile {profile}")
        return src[:start] + new_block + src[end:]
    raise SystemExit(f"could not find Release buildSettings for entitlements={entitlements}")

text = patch_release_by_entitlements(
    text, "ByVPN/ByVPN.entitlements", app_profile, "ByVPN"
)
text = patch_release_by_entitlements(
    text, "ByVPNTunnel/ByVPNTunnel.entitlements", tunnel_profile, "ByVPNTunnel"
)

Path(pbx_path).write_text(text)
print(f"wrote {pbx_path}")
PY

echo "prepare-signed-ios-archive: done (team=$TEAM app=$APP_PROFILE tunnel=$TUNNEL_PROFILE)"
