# Start nym-vpnd for Windows labmock GUI (APK parity).
# Creates \\.\pipe\nym-vpn so NymVPN-labmock.exe can connect.
$ErrorActionPreference = 'Stop'

$GuiDir = if ($env:NYM_LAB_GUI_DIR) { $env:NYM_LAB_GUI_DIR } else { 'D:\vpn-build\out-gui' }
$LabRoot = if ($env:NYM_LAB_ROOT) { $env:NYM_LAB_ROOT } else { 'D:\vpn-build\lab-vpnd' }
$Vpnd = Join-Path $GuiDir 'nym-vpnd.exe'
$Vpnc = Join-Path $GuiDir 'nym-vpnc.exe'
if (-not (Test-Path $Vpnc)) { $Vpnc = 'D:\vpn-build\out\nym-vpnc.exe' }

if (-not (Test-Path $Vpnd)) { throw "nym-vpnd.exe not found: $Vpnd" }

$configDir = Join-Path $LabRoot 'config'
$dataDir = Join-Path $LabRoot 'data'
$logDir = Join-Path $LabRoot 'log'
$netDir = Join-Path $configDir 'networks\mainnet'
New-Item -ItemType Directory -Force -Path $netDir, $dataDir, $logDir | Out-Null

# Seed mock discovery (from SMB share or already-seeded files)
$discSrcCandidates = @(
  'Y:\local-run\config\nym\networks\mainnet\mainnet_discovery.json',
  'Z:\nym-vpn-client\local-run\config\nym\networks\mainnet\mainnet_discovery.json',
  '\\192.168.1.10\nym-vpn-client\local-run\config\nym\networks\mainnet\mainnet_discovery.json',
  (Join-Path $netDir 'mainnet_discovery.json')
)
$netSrcCandidates = @(
  'Y:\local-run\config\nym\networks\mainnet\mainnet.json',
  'Z:\nym-vpn-client\local-run\config\nym\networks\mainnet\mainnet.json',
  '\\192.168.1.10\nym-vpn-client\local-run\config\nym\networks\mainnet\mainnet.json',
  (Join-Path $netDir 'mainnet.json')
)

function Ensure-Share {
  if (-not (Test-Path 'Y:\local-run')) {
    net use Y: /delete /y 2>$null | Out-Null
    net use Y: \\192.168.1.10\nym-vpn-client /user:willcfyang NymVpnShare2026! /persistent:yes | Out-Null
  }
}

Ensure-Share
$discSrc = $discSrcCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
$netSrc = $netSrcCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $discSrc -or -not $netSrc) {
  throw "Missing lab network JSON. Expected local-run/config/nym/networks/mainnet/*.json on share."
}
Copy-Item $discSrc (Join-Path $netDir 'mainnet_discovery.json') -Force
Copy-Item $netSrc (Join-Path $netDir 'mainnet.json') -Force
Write-Host "Seeded $netDir"

# Stop previous standalone vpnd
Get-Process -Name 'nym-vpnd' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep 1

$env:NYM_VPND_CONFIG_DIR = $configDir
$env:NYM_VPND_DATA_DIR = $dataDir
$env:NYM_VPND_LOG_DIR = $logDir
$env:NYM_VPN_LAB_SKIP_CONNECTION_PROBE = '1'
$env:NYM_VPN_LAB_PROBE_IP = '104.250.122.199'
$env:RUST_LOG = 'nym_vpn_lib=info,nym_vpnd=info'

$vpndLog = Join-Path $logDir 'vpnd-foreground.log'
$vpndErr = Join-Path $logDir 'vpnd-foreground.err.log'
Write-Host "Starting $Vpnd (pipe \\.\pipe\nym-vpn)..."
$p = Start-Process -FilePath $Vpnd `
  -ArgumentList @('-vv', 'run-with-args', '--disable-client-verification') `
  -WorkingDirectory $GuiDir `
  -RedirectStandardOutput $vpndLog `
  -RedirectStandardError $vpndErr `
  -PassThru `
  -WindowStyle Hidden

$ok = $false
for ($i = 0; $i -lt 30; $i++) {
  Start-Sleep 1
  if (-not (Get-Process -Id $p.Id -ErrorAction SilentlyContinue)) {
    Write-Host "vpnd exited early; tail log:"
    Get-Content $vpndLog,$vpndErr -Tail 40 -ErrorAction SilentlyContinue
    throw "vpnd failed"
  }
  if (Test-Path '\\.\pipe\nym-vpn') { $ok = $true; break }
}
if (-not $ok) {
  Get-Content $vpndLog,$vpndErr -Tail 40 -ErrorAction SilentlyContinue
  throw "named pipe \\.\pipe\nym-vpn not ready"
}

Write-Host "RPC pipe ready (pid=$($p.Id))"

if (Test-Path $Vpnc) {
  Write-Host "Configuring via nym-vpnc..."
  & $Vpnc network set mainnet 2>&1 | Out-Host
  & $Vpnc tunnel set --two-hop on 2>&1 | Out-Host
  & $Vpnc gateway set `
    --entry-id 3yJCWPL4X8KXNH86gYpP5LmN165Rru2jAEyxiWr9vQyP `
    --exit-id D5p6S6wiPvGYfJme5dkGvPgvcMo7Jq7FPQga3Dhhn2Vf 2>&1 | Out-Host
  & $Vpnc status 2>&1 | Out-Host
}

Write-Host "OK: restart NymVPN-labmock.exe if it is already open."
Write-Host "Log: $vpndLog"
