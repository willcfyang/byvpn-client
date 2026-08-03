# byvpn-apple (lab)

👋 Hello 👋

Welcome to the home of [ByVPN](https://byvpn.app) iOS + iPadOS + macOS. The Android client application for [ByVPN](https://byvpn.app). For more information about ByVPN, its features, latest announcements, Help Center, or to download the latest stable release, visit [byvpn.app](https://byvpn.app).


## Lab mock (vpn.sf / Android labmock parity)

This tree defaults to **lab mock** auth (username/password → mnemonic), matching the Android `labmock` APK and desktop `LAB_MOCK=1` builds.

- Info.plist: `LabMock=true`, `LabAuthBaseURL=http://104.250.122.199:8088/api/public/v1/lab/auth`
- Welcome drawer uses lab register/login UI (no 24-word passphrase)
- Seeds `networks/mainnet` discovery under the app config cache (iOS) and sets `NYM_VPN_LAB_SKIP_CONNECTION_PROBE=1`
- Cleartext HTTP allowed via ATS for the lab API host

Disable by setting `LabMock` to `false` in Info.plist (or omit it and do not set `BYVPN_APP_LAB_MOCK`).

## Building instructions: 
```
1. Install required dependancies.
```
### Dependancy requirements:
Requires Apple machine - mac + Xcode.
```
brew, go, swiftlint, swift-protobuf, grpc-swift, fastlane
```
## Notices:

- If mac is connected to VPN, Xcode and device connection is not working.

## Lib/daemon core update
### Automatic core update
To update core with new daemon/lib automatically, run script from `Scripts` dir.
```
sh UpdateCore.sh x.x.x
```
Implement any breaking changes. If something does not add up - iOS will not build.
Commit the output and create a PR.

Updates:
- MixnetLibrary Package url + checksum + uniffy swift file
- daemon, generates proto files

### iOS Mixnet lib manual update:
1. `nym-vpn-client/nym-vpn-apple/MixnetLibrary/Package.swift` update the binary target url and checksum.
2. Download the source from releases.
3. Update `nym-vpn-client/nym-vpn-apple/MixnetLibrary/Sources/MixnetLibrary/nym_vpn_lib.swift` with `nym-vpn-client-nym-vpn-core-vx.x.x/nym-vpn-core/nym-vpn-lib/uniffi/nym_vpn_lib.swift`

### macOS GRPC client manual update:
1. Download `nym-vpn-core-vx.x.x_macos_universal.tar.gz`
2. Rename `nym-vpnd` to `com.byvpn.app.helper`
3. Update `nym-vpn-client/nym-vpn-apple/Daemon/com.byvpn.app.helper`
4. Optionally: `brew install swift-protobuf` && `brew install grpc-swift`
5. cd `nym-vpn-client-nym-vpn-core-vx.x.x/proto/nym`
6. `protoc --swift_out=. vpn.proto` && `protoc --grpc-swift_out=. vpn.proto`
7. Update files from `nym-vpn-client-nym-vpn-core-vx.x.x/proto/nym` to `nym-vpn-client/nym-vpn-apple/ServicesMacOS/Sources/GRPCManager/proto/nym`
8. Disable swiftlint `// swiftlint:disable all` for `.proto`, `.grpc` , `.pb` files.

## Debugging daemon with extra logs:
Remove installed daemon from `/Library/LaunchDaemons` and `/Library/PrivilegedHelperTools`. Kill the process in `Activity monitor`. Comment out `isHelperInstalled()` call.

Run daemon with logs:
`chmod +x ./com.byvpn.app.helper`
`sudo RUST_LOG=debug ./com.byvpn.app.helper`


## Sparkle auto updater instructions
### CI job artefacts:
- `ByVPN.dmg` contains app in the `.dmg`. App and `.dmg` are signed with Developer ID cert, Notarized by Apple, signed with Sparkle EdDSA signature for auto-updates. The app and `.dmg` need to be named same - https://sparkle-project.org/documentation/publishing/#publishing-an-update

- `appcast.xml` Sparkle auto updater file, required for the auto updates to work. Replace URL with GH release url. Append content to existing `appcast.xml`.

## Releases
### Versioning
#### Bump version:
Run in `nym-vpn-apple`:
```
fastlane mac bump_version x.x.x
```
#### Bump build:
```
fastlane mac bump_build
```
### iOS
Testflight requires a version or build number increase every single time. See above.
To update integrated core before release - see above `Lib/daemon core update` + `Automatic core update`.

CI:
`nym-vpn-client`:
- Start build
- Update branch
- Select `Target` `iOS_Ship_Testflight`
- Start build.

#### Testflight
After succesfull completion:
- App Store Connect -> Apps -> App -> Testflight
- Update compliance for the new version build
- Add relevant tester groups. This will trigger App Store review(Every Testflight version, targeting external testers need to be approved).

#### Release
After succesfull completion:
- App Store Connect -> Apps -> App -> Distribution
- Add a new version to the App Store
- Select the new release
- Update details if needed
- Submit for review
- Wait for approval

### macOS
CI:
`nym-vpn-client`:
- Start build
- Update branch
- Select `Target` `macOS_Ship_dmg`
- Start build.

#### Sideload release
appcast.xml - required for Sparkle auto update support.
sha256-hash.txt - contains the hash, which is displayed on the website
ByVPN.dmg - dmg file containing App Store/Sparkle signed app. App Store signing required - so we would be treated as identified developer. Sparkle signing - so autoupdater could work.

- Collect artifacts from pipeline. (appcast.xml, sha256-hash.txt, ByVPN.dmg)
- Create a release on GH `ByVPN macOS vx.x.x`, add tag.
- Fill in what's changed.
- Upload `ByVPN.dmg` and `sha256-hash.txt` to release.
- Release.

#### Sparkle autoupdater support
`nym-websites`:
- Checkout repo
- `websites/nym/www/public/.wellknown/macos-vpn/appcast.xml` update the appcast.xml with new content. url - needs to be input from GH release manually.
- Create a PR.
