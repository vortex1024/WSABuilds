param(
    [string]$Serial = "127.0.0.1:58526",
    [string]$Adb = "",   # default: adb.exe from PATH
    [switch]$Uninstall
)
# Registers (or removes) a per-user Scheduled Task that runs watch-wsa.ps1 at logon, so every WSA
# session gets its third-party screen reader restarted into a storage-capable process. Run once.

$ErrorActionPreference = "Stop"
$taskName = "WSA screen reader boot fix"
$watcher = Join-Path $PSScriptRoot "watch-wsa.ps1"

if ($Uninstall) {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
    "Removed scheduled task '$taskName'."
    return
}
if (-not (Test-Path $watcher)) { throw "watch-wsa.ps1 not found next to this script" }
if (-not $Adb) { $Adb = (Get-Command adb.exe -ErrorAction SilentlyContinue).Source }
if (-not $Adb) { throw "adb.exe not found: put Android platform-tools on PATH or pass -Adb" }

$action = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument ("-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$watcher`" -Serial $Serial -Adb `"$Adb`"")
$trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -StartWhenAvailable -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1) `
    -ExecutionTimeLimit ([TimeSpan]::Zero)
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited

Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger `
    -Settings $settings -Principal $principal -Force | Out-Null
"Installed scheduled task '$taskName' (runs at logon for $env:USERNAME)."
"Start it now without logging off:  Start-ScheduledTask -TaskName '$taskName'"
"Remove it:  .\install-task.ps1 -Uninstall"
