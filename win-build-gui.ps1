$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'
$log = 'D:\vpn-build\gui-build.log'
function Log($m) {
  $line = "[{0}] {1}" -f (Get-Date -Format 'HH:mm:ss'), $m
  Add-Content -Path $log -Value $line
  [Console]::Out.WriteLine($line)
}
New-Item -ItemType Directory -Force -Path 'D:\vpn-build' | Out-Null
'' | Set-Content $log

$proxy = 'http://192.168.1.10:7890'
$env:HTTP_PROXY = $proxy
$env:HTTPS_PROXY = $proxy
$env:http_proxy = $proxy
$env:https_proxy = $proxy
$env:ALL_PROXY = $proxy
$env:NO_PROXY = 'localhost,127.0.0.1,192.168.1.10,192.168.1.30'
$env:LAB_MOCK = '1'
$env:CARGO_TARGET_DIR = 'D:\vpn-build\target-gui'
$env:PROTOC = 'D:\vpn-build\tools\protoc\bin\protoc.exe'
$env:Path = 'D:\vpn-build\tools\protoc\bin;' + $env:Path
$nodeDir = 'D:\vpn-build\tools\node'
$env:Path = "$nodeDir;C:\Users\sshuser.willcfyang-NB3\.cargo\bin;" + $env:Path
$npm = Join-Path $nodeDir 'npm.cmd'

Log 'start'
net use Y: /delete /y 2>$null | Out-Null
net use Y: \\192.168.1.10\nym-vpn-client /user:willcfyang NymVpnShare2026! /persistent:yes | Out-Null
Log ('Y pkg=' + (Test-Path 'Y:\nym-vpn-app\package.json').ToString())

$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
if (Test-Path $vswhere) {
  $vsPath = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
  if ($vsPath) {
    $vsDev = Join-Path $vsPath 'Common7\Tools\VsDevCmd.bat'
    Log "VsDevCmd $vsDev"
    cmd /c "`"$vsDev`" -arch=x64 -host_arch=x64 && set" | ForEach-Object {
      if ($_ -match '^(.*?)=(.*)$') {
        [System.Environment]::SetEnvironmentVariable($matches[1], $matches[2])
      }
    }
  }
}

Log ("node=$(node -v) npm=$(cmd /c `"$npm`" -v) rustc=$(rustc -V)")

$src = 'Y:\nym-vpn-app'
$dst = 'D:\vpn-build\nym-vpn-app'
New-Item -ItemType Directory -Force -Path $dst | Out-Null
Log "Sync $src -> $dst"
& robocopy $src $dst /E /XO /R:2 /W:2 /NFL /NDL /NJH /NJS /nc /ns /np /XD node_modules dist target src-tauri\target .git
$rc = $LASTEXITCODE
Log "robocopy=$rc"
if ($rc -ge 8) { throw "robocopy failed: $rc" }


# path deps: ../nym-vpn-core
$coreSrc = 'Y:\nym-vpn-core'
$coreDst = 'D:\vpn-build\nym-vpn-core'
New-Item -ItemType Directory -Force -Path $coreDst | Out-Null
Log "Sync $coreSrc -> $coreDst"
& robocopy $coreSrc $coreDst /E /XO /R:2 /W:2 /NFL /NDL /NJH /NJS /nc /ns /np /XD target .git
$rc2 = $LASTEXITCODE
Log "robocopy-core=$rc2"
if ($rc2 -ge 8) { throw "robocopy core failed: $rc2" }


# workspace path ../../nym-vpn-patches from nym-vpn-core resolves to D:\nym-vpn-patches
$patchSrc = 'Z:\nym-vpn-patches'
if (-not (Test-Path "$patchSrc\nym\common\crypto\Cargo.toml")) {
  net use Z: /delete /y 2>$null | Out-Null
  net use Z: \\192.168.1.10\ocean6 /user:willcfyang NymVpnShare2026! /persistent:yes | Out-Null
}
$patchDst = 'D:\nym-vpn-patches'
New-Item -ItemType Directory -Force -Path $patchDst | Out-Null
Log "Sync $patchSrc -> $patchDst"
& robocopy $patchSrc $patchDst /E /XO /R:2 /W:2 /NFL /NDL /NJH /NJS /nc /ns /np /XD target .git
$rc3 = $LASTEXITCODE
Log "robocopy-patches=$rc3"
if ($rc3 -ge 8) { throw "robocopy patches failed: $rc3" }

$out = 'D:\vpn-build\out'
$tauri = Join-Path $dst 'src-tauri'
foreach ($f in @('nym-vpnd.exe','nym-socks5-proxy.exe','libwg.dll','winfw.dll','wintun.dll')) {
  Copy-Item (Join-Path $out $f) (Join-Path $tauri $f) -Force
  Log "copied $f"
}

# Split-tunnel driver is required by `nym-vpnd.exe install-service` (NSIS bundles these).
$stNames = @('nymvpn-split-tunnel.sys','nymvpn-split-tunnel.inf','nymvpn-split-tunnel.cat')
$stCandidates = @(
  (Join-Path $out ''),
  'D:\vpn-build\nym-core-extract\nym-vpn-core-v2026.13.0-nightly.20260729_windows_x86_64',
  'Y:\nym-vpn-windows\split-tunnel-driver\signed\x64',
  'D:\vpn-build\nym-vpn-windows\split-tunnel-driver\signed\x64'
)
$stSrc = $null
foreach ($dir in $stCandidates) {
  if (-not $dir) { continue }
  $ok = $true
  foreach ($n in $stNames) {
    if (-not (Test-Path (Join-Path $dir $n))) { $ok = $false; break }
  }
  if ($ok) { $stSrc = $dir; break }
}
if (-not $stSrc) {
  throw "Missing split-tunnel driver (.sys/.inf/.cat). Checked: $($stCandidates -join '; ')"
}
foreach ($n in $stNames) {
  Copy-Item (Join-Path $stSrc $n) (Join-Path $tauri $n) -Force
  Copy-Item (Join-Path $stSrc $n) (Join-Path $out $n) -Force
  # NSIS RESPREFIX resolves to CARGO_TARGET_DIR parent (D:\vpn-build when target-gui is used)
  Copy-Item (Join-Path $stSrc $n) (Join-Path 'D:\vpn-build' $n) -Force
  Log "copied $n from $stSrc"
}

# Lab builds: disable Windows code signing
$conf = Join-Path $dst 'src-tauri\tauri.conf.json'
$raw = Get-Content $conf -Raw
$raw2 = [regex]::Replace($raw, '(?s),\s*"signCommand"\s*:\s*\{.*?\}', '')
if ($raw2 -ne $raw) {
  $utf8 = New-Object System.Text.UTF8Encoding $false
  [System.IO.File]::WriteAllText($conf, $raw2, $utf8)
  Log 'removed signCommand from tauri.conf.json'
}

Set-Location $dst
$env:Path = (Join-Path $dst 'node_modules\.bin') + ';' + $env:Path

if (-not (Test-Path 'node_modules\.bin\tsc.cmd')) {
  Log 'npm install...'
  cmd /c "`"$npm`" install > D:\vpn-build\gui-npm.log 2>&1"
  if ($LASTEXITCODE -ne 0) {
    Log "npm install failed: $LASTEXITCODE"
    Get-Content 'D:\vpn-build\gui-npm.log' -Tail 40 | ForEach-Object { Log $_ }
    throw "npm install failed: $LASTEXITCODE"
  }
  Log 'npm install ok'
} else {
  Log 'node_modules present'
}
if (-not (Test-Path 'node_modules\.bin\tsc.cmd')) {
  Log 'missing tsc.cmd'
  throw 'missing tsc.cmd'
}

New-Item -ItemType Directory -Force -Path dist | Out-Null
Log 'npm run build (frontend)...'
cmd /c "`"$npm`" run build > D:\vpn-build\gui-frontend.log 2>&1"
if ($LASTEXITCODE -ne 0) {
  Log "frontend build failed: $LASTEXITCODE"
  throw "frontend build failed: $LASTEXITCODE"
}
Log 'frontend ok'

Log 'tauri build nsis LAB_MOCK=1...'
$env:LAB_MOCK = '1'
cmd /c "`"$npm`" run tauri -- build --bundles nsis > D:\vpn-build\gui-tauri.log 2>&1"
if ($LASTEXITCODE -ne 0) {
  Log "tauri build failed: $LASTEXITCODE"
  throw "tauri build failed: $LASTEXITCODE"
}
Log 'tauri ok'

$guiOut = 'D:\vpn-build\out-gui'
New-Item -ItemType Directory -Force -Path $guiOut | Out-Null
$nsisDir = Join-Path $env:CARGO_TARGET_DIR 'release\bundle\nsis'
$relDir = Join-Path $env:CARGO_TARGET_DIR 'release'
Get-ChildItem $nsisDir -Filter '*.exe' -ErrorAction SilentlyContinue | ForEach-Object {
  Copy-Item $_.FullName $guiOut -Force
  Log "NSIS $($_.FullName)"
}
foreach ($exeName in @('ByVPN.exe','nym-vpn-app.exe')) {
  Get-ChildItem $relDir -Filter $exeName -ErrorAction SilentlyContinue | ForEach-Object {
    Copy-Item $_.FullName $guiOut -Force
    # portable lab name
    Copy-Item $_.FullName (Join-Path $guiOut 'ByVPN-labmock.exe') -Force
    Log "EXE $($_.FullName)"
  }
}
# also copy vpnd/dlls + split-tunnel driver beside portable exe for lab runs
foreach ($f in @('nym-vpnd.exe','nym-socks5-proxy.exe','libwg.dll','winfw.dll','wintun.dll','nymvpn-split-tunnel.sys','nymvpn-split-tunnel.inf','nymvpn-split-tunnel.cat')) {
  $srcF = Join-Path $out $f
  if (Test-Path $srcF) {
    Copy-Item $srcF (Join-Path $guiOut $f) -Force
  }
}
Get-ChildItem $guiOut | ForEach-Object { Log ("out $($_.Name) $($_.Length)") }
Log 'GUI_BUILD_OK'
