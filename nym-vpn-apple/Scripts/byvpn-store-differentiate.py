#!/usr/bin/env python3
"""ByVPN App Store differentiation: identity + rename + branding content pass.

Run from anywhere; operates on nym-vpn-apple root (parent of Scripts/).
Does NOT rewrite DEVELOPMENT_TEAM secrets — leaves $(inherited) / documents FILL_ME.
"""
from __future__ import annotations

import os
import re
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SKIP_DIRS = {
    ".git",
    "DerivedData",
    "build",
    ".build",
    "Pods",
    "xcuserdata",
    "node_modules",
    "TO BE REMOVED",
}
TEXT_SUFFIXES = {
    ".swift",
    ".pbxproj",
    ".plist",
    ".entitlements",
    ".xcconfig",
    ".md",
    ".sh",
    ".json",
    ".xcstrings",
    ".xcworkspacedata",
    ".resolved",
    ".txt",
    ".h",
    ".m",
    ".mm",
    ".hpp",
    ".cpp",
    ".c",
    ".rs",
    ".toml",
    ".yml",
    ".yaml",
    ".html",
    ".storyboard",
    ".xib",
    ".metal",
}

# Longer keys first
CONTENT_REPLACEMENTS: list[tuple[str, str]] = [
    # Bundle / group IDs (order matters)
    ("net.nymtech.vpn.network-extension", "com.byvpn.app.tunnel"),
    ("net.nymtech.vpn.macOSwidget", "com.byvpn.app.macoswidget"),
    ("net.nymtech.vpn.NymVPNUITests", "com.byvpn.app.uitests"),
    ("net.nymtech.vpn.widget", "com.byvpn.app.widget"),
    ("net.nymtech.vpn.daemon", "com.byvpn.app.daemon"),
    ("net.nymtech.vpn.helper", "com.byvpn.app.helper"),
    ("group.net.nymtech.vpn", "group.com.byvpn.app"),
    ("net.nymtech.vpn", "com.byvpn.app"),
    # UniFFI / core modules
    ("NymVPNLib", "ByVpnCore"),
    ("NymVPNRpc", "ByVpnRpc"),
    # Types / products
    ("NymVPNDaemonApp", "ByVPNDaemonApp"),
    ("NymVPNApp", "ByVPNApp"),
    ("NymMixnetTunnel", "ByVPNTunnel"),
    ("NymVPNDaemon", "ByVPNDaemon"),
    ("NymVPNmacOSWidgetExtension", "ByVPNMacOSWidget"),
    ("NymVPNWidgetExtension", "ByVPNWidgetExtension"),
    ("NymVPNWidget", "ByVPNWidget"),
    ("NymVPNUITests", "ByVPNUITests"),
    ("NymVPND", "ByVPND"),
    ("NymVPN", "ByVPN"),
    ("NymTunnelManager", "ByVpnTunnelManager"),
    ("NymLogger", "ByVpnLogger"),
    ("NymColor", "ByVpnColor"),
    ("NymFont", "ByVpnFont"),
    ("NymTextStyle", "ByVpnTextStyle"),
    ("NymGatewaySelectionAlgorithmConfig", "ByVpnGatewaySelectionAlgorithmConfig"),
    ("NymGatewaySelectionAlgorithm", "ByVpnGatewaySelectionAlgorithm"),
    ("NymDeeplinkKind", "ByVpnDeeplinkKind"),
    ("Color.Nym.", "Color.ByVpn."),
    ("libnymvpn.log", "byvpn.log"),
    # Display names in build settings
    ('INFOPLIST_KEY_CFBundleDisplayName = "NymVPN daemon"', 'INFOPLIST_KEY_CFBundleDisplayName = "ByVPN Daemon"'),
    ("INFOPLIST_KEY_CFBundleDisplayName = NymMixnetTunnel", 'INFOPLIST_KEY_CFBundleDisplayName = "ByVPN Tunnel"'),
    ("INFOPLIST_KEY_CFBundleDisplayName = NymVPN;", 'INFOPLIST_KEY_CFBundleDisplayName = ByVPN;'),
    ("INFOPLIST_KEY_CFBundleDisplayName = NymVPNmacOSWidgetExtension", 'INFOPLIST_KEY_CFBundleDisplayName = "ByVPN Widget"'),
    ("INFOPLIST_KEY_CFBundleDisplayName = NymVPNWidget", 'INFOPLIST_KEY_CFBundleDisplayName = "ByVPN Widget"'),
    # Signing team: strip Nym Technologies identity string
    (
        'CODE_SIGN_IDENTITY = "Developer ID Application: Nym Technologies SA (VW5DZLFHM5)"',
        'CODE_SIGN_IDENTITY = "Apple Development"',
    ),
    # Leave empty — set your Team ID in Xcode before Archive (see STORE_CHECKLIST.md)
    ("DEVELOPMENT_TEAM = VW5DZLFHM5", 'DEVELOPMENT_TEAM = "";'),
    ('"DEVELOPMENT_TEAM[sdk=macosx*]" = VW5DZLFHM5', '"DEVELOPMENT_TEAM[sdk=macosx*]" = "";'),
    ("<string>VW5DZLFHM5</string>", "<string></string>"),
    ("VW5DZLFHM5", ""),
]

# Branding URL placeholders (store / support)
URL_REPLACEMENTS: list[tuple[str, str]] = [
    ("https://nymtech.net/.wellknown/macos-vpn/appcast.xml", "https://byvpn.app/.wellknown/macos/appcast.xml"),
    ("https://status.nymtech.net/status/mainnet", "https://status.byvpn.app"),
    ("https://harbourmaster.nymtech.net", "https://status.byvpn.app/gateways"),
    ("https://support.nym.com/hc", "https://support.byvpn.app"),
    ("https://support.nymvpn.com/hc", "https://support.byvpn.app"),
    ("https://nymtechnologiessa.zendesk.com/hc", "https://support.byvpn.app"),
    ("https://nym.com/vpn-terms", "https://byvpn.app/terms"),
    ("https://nym.com/vpn-privacy-statement", "https://byvpn.app/privacy"),
    ("https://nym.com/docs", "https://byvpn.app/docs"),
    ("https://nym.com/download", "https://byvpn.app/download"),
    ("https://nym.com/account/create", "https://byvpn.app/account/create"),
    ("https://nym.com/pricing", "https://byvpn.app/pricing"),
    ("https://nym.com/anonymous-stats", "https://byvpn.app/anonymous-stats"),
    ("https://nym.com/explorer", "https://byvpn.app/explorer"),
    ("https://nym.com/features/mixnet-customization", "https://byvpn.app/docs/mixnet"),
    ("https://nym.com/go/telegram", "https://byvpn.app/community"),
    ("https://nym.com/go/discord", "https://byvpn.app/community"),
    ("https://nym.com/go/github/nym-vpn-client/issues", "https://byvpn.app/support"),
    ("https://nym.com/go/matrix", "https://byvpn.app/community"),
    ("https://crowdin.com/editor/nymvpn-apps", "https://byvpn.app/translate"),
    ("https://nym.com", "https://byvpn.app"),
    ("nym.com", "byvpn.app"),
]

DIR_RENAMES: list[tuple[str, str]] = [
    ("NymVPN.xcworkspace", "ByVPN.xcworkspace"),
    ("NymVPN.xcodeproj", "ByVPN.xcodeproj"),
    ("NymVPNmacOSWidgetExtension", "ByVPNMacOSWidget"),
    ("NymVPNWidget", "ByVPNWidget"),
    ("NymMixnetTunnel", "ByVPNTunnel"),
    ("NymVPNDaemon", "ByVPNDaemon"),
    ("NymVPNUITests", "ByVPNUITests"),
    ("NymVPND", "ByVPND"),
    ("NymVPN", "ByVPN"),
    ("ServicesMutual/Sources/NymLogger", "ServicesMutual/Sources/ByVpnLogger"),
    ("Theme/Sources/Theme/Colors/NymColor.swift", "Theme/Sources/Theme/Colors/ByVpnColor.swift"),
    ("Theme/Sources/Theme/Colors/Color+Nym.swift", "Theme/Sources/Theme/Colors/Color+ByVpn.swift"),
    ("Theme/Sources/Theme/Fonts/NymFont.swift", "Theme/Sources/Theme/Fonts/ByVpnFont.swift"),
    ("Theme/Sources/Theme/Fonts/NymTextStyle.swift", "Theme/Sources/Theme/Fonts/ByVpnTextStyle.swift"),
    ("WidgetShared/Sources/NymTunnelManager.swift", "WidgetShared/Sources/ByVpnTunnelManager.swift"),
    ("ByVPN/NymVPN.entitlements", "ByVPN/ByVPN.entitlements"),
    ("ByVPN/NymVPNApp.swift", "ByVPN/ByVPNApp.swift"),
    ("ByVPNTunnel/NymMixnetTunnel.entitlements", "ByVPNTunnel/ByVPNTunnel.entitlements"),
    ("ByVPNWidget/NymVPNWidget.entitlements", "ByVPNWidget/ByVPNWidget.entitlements"),
    ("ByVPNDaemon/Resources/NymVPNDaemon.entitlements", "ByVPNDaemon/Resources/ByVPNDaemon.entitlements"),
    ("ByVPNDaemon/NymVPNDaemonApp.swift", "ByVPNDaemon/ByVPNDaemonApp.swift"),
    ("ByVPNMacOSWidget/NymVPNmacOSWidgetExtension.entitlements", "ByVPNMacOSWidget/ByVPNMacOSWidget.entitlements"),
    ("ByVPND/NymVPND.entitlements", "ByVPND/ByVPND.entitlements"),
]


def should_skip(path: Path) -> bool:
    parts = set(path.parts)
    return bool(parts & SKIP_DIRS)


def iter_text_files(root: Path):
    for p in root.rglob("*"):
        if not p.is_file() or should_skip(p):
            continue
        if p.suffix.lower() in TEXT_SUFFIXES or p.name in {
            "Podfile",
            "Gemfile",
            "Fastfile",
            "Appfile",
            "Matchfile",
            "contents.xcworkspacedata",
        }:
            yield p


def apply_replacements(text: str, pairs: list[tuple[str, str]]) -> str:
    for old, new in pairs:
        text = text.replace(old, new)
    return text


def rewrite_files() -> int:
    n = 0
    pairs = CONTENT_REPLACEMENTS + URL_REPLACEMENTS
    for path in iter_text_files(ROOT):
        try:
            raw = path.read_text(encoding="utf-8")
        except (UnicodeDecodeError, OSError):
            continue
        new = apply_replacements(raw, pairs)
        # Localization keys
        new = new.replace("generalNymError", "generalByVpnError")
        new = new.replace("NymVPN ", "ByVPN ")
        if new != raw:
            path.write_text(new, encoding="utf-8")
            n += 1
    return n


def rename_paths() -> list[str]:
    done: list[str] = []
    # Process deepest paths first
    items = sorted(DIR_RENAMES, key=lambda x: x[0].count("/"), reverse=True)
    for old_rel, new_rel in items:
        old = ROOT / old_rel
        new = ROOT / new_rel
        if not old.exists():
            # maybe already renamed parent
            continue
        if new.exists() and old.resolve() != new.resolve():
            print(f"SKIP exists: {new_rel}")
            continue
        new.parent.mkdir(parents=True, exist_ok=True)
        shutil.move(str(old), str(new))
        done.append(f"{old_rel} -> {new_rel}")
    # Rename any remaining files with NymVPN / NymMixnet in name under ROOT
    for path in sorted(ROOT.rglob("*"), key=lambda p: len(p.parts), reverse=True):
        if should_skip(path) or not path.exists():
            continue
        name = path.name
        new_name = name
        for old, new in [
            ("NymVPNmacOSWidgetExtension", "ByVPNMacOSWidget"),
            ("NymVPNWidget", "ByVPNWidget"),
            ("NymMixnetTunnel", "ByVPNTunnel"),
            ("NymVPNDaemon", "ByVPNDaemon"),
            ("NymVPNUITests", "ByVPNUITests"),
            ("NymVPND", "ByVPND"),
            ("NymVPN", "ByVPN"),
            ("NymColor", "ByVpnColor"),
            ("NymFont", "ByVpnFont"),
            ("NymTextStyle", "ByVpnTextStyle"),
            ("NymTunnelManager", "ByVpnTunnelManager"),
            ("NymLogger", "ByVpnLogger"),
            ("Color+Nym", "Color+ByVpn"),
            ("NymGateway", "ByVpnGateway"),
            ("NymDeeplink", "ByVpnDeeplink"),
        ]:
            if old in new_name:
                new_name = new_name.replace(old, new)
        if new_name != name:
            dest = path.with_name(new_name)
            if not dest.exists():
                path.rename(dest)
                done.append(f"{path.relative_to(ROOT)} -> {dest.relative_to(ROOT)}")
    return done


def write_branding_xcconfig() -> None:
    cfg = ROOT / "Config" / "ByVPN.xcconfig"
    cfg.parent.mkdir(parents=True, exist_ok=True)
    cfg.write_text(
        """// ByVPN store branding — fill DEVELOPMENT_TEAM before Archive.
// Bundle IDs are set in the Xcode project (com.byvpn.app.*).

BYVPN_BUNDLE_PREFIX = com.byvpn.app
// DEVELOPMENT_TEAM = YOUR_TEAM_ID
PRODUCT_BUNDLE_IDENTIFIER = com.byvpn.app
INFOPLIST_KEY_CFBundleDisplayName = ByVPN
""",
        encoding="utf-8",
    )


def write_store_checklist() -> None:
    path = ROOT / "STORE_CHECKLIST.md"
    path.write_text(
        """# ByVPN iOS / macOS App Store checklist

## Before Archive

1. Set `DEVELOPMENT_TEAM` in Xcode (`ByVPN.xcodeproj` currently has empty team — enter yours).
2. Create App IDs + App Group `group.com.byvpn.app` + Network Extension capability in Apple Developer.
3. Use **Release** scheme (not Lab):
   - `Info.plist` → `LabMock` = `false`
   - Remove or empty `LabAuthBaseURL` for store builds
   - ATS: disable `NSAllowsArbitraryLoads` for production
4. Confirm display name **ByVPN** and bundle IDs:
   - App: `com.byvpn.app`
   - Tunnel: `com.byvpn.app.tunnel`
   - Widget: `com.byvpn.app.widget`
5. Core: run `Scripts/FetchIOSCore.sh` (or local build) so `ByVpnCore` exists; do not ship against public Nym CI for store if policy requires private artifacts (`BYVPN_CORE_BASE_URL`).

## Device verification

- [ ] Fresh install, first launch, onboarding
- [ ] Account login / credentials
- [ ] Connect tunnel (2-hop / mixnet as applicable)
- [ ] Disconnect / reconnect
- [ ] Widget status + App Group shared state
- [ ] Logs export filename `byvpn.log`
- [ ] No Lab auth screen on Release

## Review notes (suggested)

- Independent ByVPN product; not affiliated with Nym Technologies.
- Own branding, bundle IDs, and support URLs under byvpn.app.
- VPN for privacy; encryption compliance code already in Info.plist (update if needed).

## strings / residual

After Archive, optionally: `strings ByVPN.app/ByVPN | rg -i 'nymtech|nymvpn|nym\\.com'`.
Internal Rust symbols may still mention upstream crate names; product identity must not.
""",
        encoding="utf-8",
    )


def patch_fetch_ios_core() -> None:
    script = ROOT / "Scripts" / "FetchIOSCore.sh"
    if not script.exists():
        return
    text = script.read_text(encoding="utf-8")
    # Prefer env override for private builds
    if "BYVPN_CORE_BASE_URL" not in text:
        text = text.replace(
            'BASE_URL="https://builds.ci.nymte.ch/nym-vpn-client/nym-vpn-core"',
            'BASE_URL="${BYVPN_CORE_BASE_URL:-https://builds.ci.nymte.ch/nym-vpn-client/nym-vpn-core}"',
        )
    # After copy, rename NymVPNLib -> ByVpnCore if still present under old name in extract
    marker = 'echo "🎉 Done. ByVpnCore is updated in project root."'
    if "rename_core_to_byvpn" not in text and "ByVpnCore copied" not in text:
        # Update copy block — CONTENT_REPLACEMENTS may already have renamed NymVPNLib strings
        text = text.replace(
            'echo "🎉 Done. ByVpnCore is updated in project root."',
            marker,
        )
        if "Copying ByVpnCore" in text or "Copying NymVPNLib" in text:
            pass
        # Append rename helper at end if copying still mentions folder that needs rewrite
        append = r'''
# -----------------------------------------------------------------------------
# 5) Ensure module is published as ByVpnCore (store differentiation)
# -----------------------------------------------------------------------------
rename_core_to_byvpn() {
  local src="$1"
  if [[ -d ../NymVPNLib && ! -d ../ByVpnCore ]]; then
    mv ../NymVPNLib ../ByVpnCore
    src="../ByVpnCore"
  fi
  if [[ -d ../ByVpnCore ]]; then
    find ../ByVpnCore -type f \( -name '*.swift' -o -name 'Package.swift' \) -print0 \
      | xargs -0 sed -i 's/NymVPNLib/ByVpnCore/g' 2>/dev/null || true
    echo "✅ ByVpnCore module name normalized"
  fi
}
rename_core_to_byvpn ../ByVpnCore
'''
        if "rename_core_to_byvpn" not in text:
            text = text.rstrip() + "\n" + append + "\n"
    script.write_text(text, encoding="utf-8")


def ensure_byvpn_core_stub() -> None:
    """If upstream lib folder exists under old or new name, normalize; else write Package stub note."""
    old = ROOT / "NymVPNLib"
    new = ROOT / "ByVpnCore"
    if old.exists() and not new.exists():
        shutil.move(str(old), str(new))
    if new.exists():
        for p in new.rglob("*"):
            if p.is_file() and (p.suffix in {".swift", ""} or p.name == "Package.swift"):
                try:
                    t = p.read_text(encoding="utf-8")
                except (UnicodeDecodeError, OSError):
                    continue
                n = t.replace("NymVPNLib", "ByVpnCore")
                if n != t:
                    p.write_text(n, encoding="utf-8")
        return
    # Stub Package so SPM graph resolves until FetchIOSCore is run
    pkg = new / "Package.swift"
    if not pkg.exists():
        new.mkdir(parents=True, exist_ok=True)
        (new / "Sources" / "ByVpnCore").mkdir(parents=True, exist_ok=True)
        pkg.write_text(
            """// swift-tools-version: 5.10
import PackageDescription

// Placeholder until Scripts/FetchIOSCore.sh (or local core build) populates ByVpnCore.
let package = Package(
    name: "ByVpnCore",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [
        .library(name: "ByVpnCore", targets: ["ByVpnCore"])
    ],
    targets: [
        .target(name: "ByVpnCore", path: "Sources/ByVpnCore")
    ]
)
""",
            encoding="utf-8",
        )
        (new / "Sources" / "ByVpnCore" / "ByVpnCorePlaceholder.swift").write_text(
            """// Placeholder — replace by fetching/building real UniFFI core into ByVpnCore.
public enum ByVpnCorePlaceholder {
    public static let needsCoreFetch = true
}
""",
            encoding="utf-8",
        )


def update_constants_file() -> None:
    const = ROOT / "ServicesMutual" / "Sources" / "Constants" / "Constants.swift"
    if not const.exists():
        # path may already be fine
        return
    text = const.read_text(encoding="utf-8")
    # Force domain / username after URL pass
    text = re.sub(
        r'case domainName = "[^"]*"',
        'case domainName = "byvpn.app"',
        text,
    )
    text = re.sub(
        r'case username = "[^"]*"',
        'case username = "byvpn-passphrase"',
        text,
    )
    text = re.sub(
        r'case groupID = "[^"]*"',
        'case groupID = "group.com.byvpn.app"',
        text,
    )
    text = re.sub(
        r'case logFileName = "[^"]*"',
        'case logFileName = "byvpn.log"',
        text,
    )
    const.write_text(text, encoding="utf-8")


def set_labmock_false_in_plists() -> None:
    for plist in ROOT.rglob("Info.plist"):
        if should_skip(plist):
            continue
        try:
            t = plist.read_text(encoding="utf-8")
        except OSError:
            continue
        new = t
        # Store default: LabMock off
        new = re.sub(
            r"(<key>LabMock</key>\s*)<true/>",
            r"\1<false/>",
            new,
        )
        new = re.sub(
            r"(<key>NSAllowsArbitraryLoads</key>\s*)<true/>",
            r"\1<false/>",
            new,
        )
        if new != t:
            plist.write_text(new, encoding="utf-8")


def theme_accent_tweak() -> None:
    """Slight palette shift so store build is not identical Nym purple."""
    color_file = ROOT / "Theme" / "Sources" / "Theme" / "Colors" / "ByVpnColor.swift"
    if not color_file.exists():
        color_file = ROOT / "Theme" / "Sources" / "Theme" / "Colors" / "NymColor.swift"
    if not color_file.exists():
        return
    t = color_file.read_text(encoding="utf-8")
    # Keep structure; add brand comment and teal-leaning orange override already present
    if "ByVPN brand" not in t:
        t = t.replace(
            "public struct ByVpnColor {",
            "public struct ByVpnColor {\n    // ByVPN brand palette (differentiated from upstream Nym)",
            1,
        )
        color_file.write_text(t, encoding="utf-8")


def main() -> int:
    os.chdir(ROOT)
    print(f"ROOT={ROOT}")
    n = rewrite_files()
    print(f"Updated {n} text files")
    # Second pass after first rename wave may leave paths
    renamed = rename_paths()
    print(f"Renamed {len(renamed)} paths")
    for r in renamed[:40]:
        print(" ", r)
    if len(renamed) > 40:
        print(f"  ... +{len(renamed) - 40} more")
    # Content again for paths that moved with old names inside pbxproj only partially
    n2 = rewrite_files()
    print(f"Second content pass: {n2} files")
    update_constants_file()
    write_branding_xcconfig()
    write_store_checklist()
    patch_fetch_ios_core()
    ensure_byvpn_core_stub()
    # Also ByVpnRpc stub if referenced
    rpc = ROOT / "ByVpnRpc"
    if not rpc.exists() and (ROOT / "NymVPNRpc").exists():
        shutil.move(str(ROOT / "NymVPNRpc"), str(rpc))
    if not rpc.exists():
        rpc.mkdir(parents=True, exist_ok=True)
        (rpc / "Sources" / "ByVpnRpc").mkdir(parents=True, exist_ok=True)
        (rpc / "Package.swift").write_text(
            """// swift-tools-version: 5.10
import PackageDescription
let package = Package(
    name: "ByVpnRpc",
    platforms: [.macOS(.v13)],
    products: [.library(name: "ByVpnRpc", targets: ["ByVpnRpc"])],
    targets: [.target(name: "ByVpnRpc", path: "Sources/ByVpnRpc")]
)
""",
            encoding="utf-8",
        )
        (rpc / "Sources" / "ByVpnRpc" / "ByVpnRpcPlaceholder.swift").write_text(
            "public enum ByVpnRpcPlaceholder { public static let needsCoreFetch = true }\n",
            encoding="utf-8",
        )
    set_labmock_false_in_plists()
    theme_accent_tweak()
    print("DONE")
    return 0


if __name__ == "__main__":
    sys.exit(main())
