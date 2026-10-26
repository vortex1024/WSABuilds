param(
    [string]$Serial = "127.0.0.1:58526",
    [string]$Adb = "",   # default: adb.exe from PATH
    [switch]$Quiet
)
# Restart every enabled, non-system accessibility service (e.g. Jieshuo) once, over adb.
# A process WSA binds before the user is unlocked never gains /sdcard access; rebinding in a fresh
# post-unlock process fixes it. adb shell (uid shell) has the force-stop power an app lacks.
if (-not $Adb) { $Adb = (Get-Command adb.exe -ErrorAction SilentlyContinue).Source }
if (-not $Adb) { throw "adb.exe not found: put Android platform-tools on PATH or pass -Adb" }

function Sh([string]$cmd) { & $Adb -s $Serial shell $cmd 2>$null }
function Log([string]$m) { if (-not $Quiet) { "$(Get-Date -Format HH:mm:ss) $m" } }

& $Adb connect $Serial *> $null
if ((Sh "getprop sys.boot_completed").Trim() -ne "1") { Log "WSA not booted"; return $false }

$enabled = (Sh "settings get secure enabled_accessibility_services").Trim()
if (-not $enabled -or $enabled -eq "null") { Log "No accessibility services"; return $false }

# a component is third-party (restartable) when its APK lives under /data
$restart = @(); $keep = @(); $packages = [ordered]@{}
foreach ($flat in $enabled -split ":") {
    $pkg = ($flat -split "/")[0]
    if (-not $pkg) { continue }
    $path = (Sh "pm path $pkg" | Select-Object -First 1)
    if ($path -match "^package:/data/") { $restart += $flat; $packages[$pkg] = $true }
    else { $keep += $flat }
}
if ($packages.Count -eq 0) { Log "No third-party screen reader enabled"; return $false }

Log ("Restarting: " + ($packages.Keys -join ", "))
try {
    Sh ("settings put secure enabled_accessibility_services '" + ($keep -join ":") + "'") | Out-Null
    Start-Sleep -Milliseconds 2500
    foreach ($pkg in $packages.Keys) { Sh "am force-stop $pkg" | Out-Null }
    Start-Sleep -Milliseconds 800
} finally {
    Sh ("settings put secure enabled_accessibility_services '$enabled'") | Out-Null
}
Log "Done"
return $true
