param(
    [string]$Serial = "127.0.0.1:58526",
    [string]$Adb = "",   # default: adb.exe from PATH
    [int]$PollSeconds = 4,
    [int]$RunForSeconds = 0,   # 0 = run forever; >0 = exit after this long (for testing)
    [string]$LogFile = "$env:LOCALAPPDATA\wsa-a11y\watch.log"
)
# Background watcher: once per WSA session, after boot, restart third-party screen readers so
# they run in a post-unlock process that can read /sdcard. Install with install-task.ps1.
if (-not $Adb) { $Adb = (Get-Command adb.exe -ErrorAction SilentlyContinue).Source }
if (-not $Adb) { throw "adb.exe not found: put Android platform-tools on PATH or pass -Adb" }

$restartOnce = Join-Path $PSScriptRoot "restart-once.ps1"
New-Item -ItemType Directory -Force -Path (Split-Path $LogFile) | Out-Null
function Log([string]$m) {
    $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $m"
    Add-Content -Path $LogFile -Value $line
    if ((Get-Item $LogFile).Length -gt 1MB) { (Get-Content $LogFile -Tail 400) | Set-Content $LogFile }
}

Log "watcher started (serial $Serial)"
$fixedThisSession = $false
$deadline = if ($RunForSeconds -gt 0) { (Get-Date).AddSeconds($RunForSeconds) } else { [datetime]::MaxValue }

while ((Get-Date) -lt $deadline) {
    try {
        $wsaUp = [bool](Get-Process vmmemWSA -ErrorAction SilentlyContinue)
        if (-not $wsaUp) {
            $fixedThisSession = $false
        }
        elseif (-not $fixedThisSession) {
            & $Adb connect $Serial *> $null
            $prop = (& $Adb -s $Serial shell "getprop sys.boot_completed" 2>$null | Out-String).Trim()
            if ($prop -eq "1") {
                Start-Sleep -Seconds 3   # let WSA's own accessibility sync settle
                $out = & $restartOnce -Serial $Serial -Adb $Adb -Quiet
                $fixedThisSession = $true
                Log ("restart-once -> " + ($out | Select-Object -Last 1))
            }
        }
    } catch {
        Log "error: $_"
    }
    Start-Sleep -Seconds $PollSeconds
}
