$cmd = 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File D:\vpn-build\win-build-gui.ps1'
$r = Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{
  CommandLine = $cmd
  CurrentDirectory = 'D:\vpn-build'
}
"CreateReturn=$($r.ReturnValue) ProcessId=$($r.ProcessId)" | Out-File D:\vpn-build\gui-launch.txt
Start-Sleep 10
$alive = [bool](Get-Process -Id $r.ProcessId -ErrorAction SilentlyContinue)
"alive=$alive" | Add-Content D:\vpn-build\gui-launch.txt
Get-Content D:\vpn-build\gui-build.log -ErrorAction SilentlyContinue | Add-Content D:\vpn-build\gui-launch.txt
