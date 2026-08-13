# Registers claude-tray.ps1 to start hidden on login, from wherever this repo sits.
# Run: powershell -ExecutionPolicy Bypass -File install.ps1        (add -Uninstall to remove)
param([switch]$Uninstall)

$lnk = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Startup\claude-tray.lnk'

if ($Uninstall) {
    Remove-Item $lnk -ErrorAction SilentlyContinue
    Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" |
        Where-Object { $_.ProcessId -ne $PID -and $_.CommandLine -like '*-File *claude-tray.ps1*' } |
        ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
    "Uninstalled."; return
}

$script = Join-Path $PSScriptRoot 'claude-tray.ps1'
if (-not (Test-Path $script)) { throw "claude-tray.ps1 not found next to install.ps1" }

$s = (New-Object -ComObject WScript.Shell).CreateShortcut($lnk)
$s.TargetPath = 'powershell.exe'
$s.Arguments = "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$script`""
$s.WorkingDirectory = $PSScriptRoot
$s.WindowStyle = 7   # minimized, so no console flash on login
$s.Description = 'Claude Code usage tray'
$s.Save()

"Installed: $lnk"
Start-Process $lnk
"Started. Look for the tray icon, and a readout box top-right of your primary screen."
