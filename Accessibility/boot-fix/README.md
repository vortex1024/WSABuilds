# boot-fix: restart the screen reader once WSA has booted

## Problem

WSA binds an enabled accessibility service (e.g. Jieshuo) before the user is unlocked. A process
started in that "direct boot" window never gains access to shared storage (`/sdcard`) for its whole
life, even with all-files access. Jieshuo then starts with an empty hotkey scheme and, because they
live under `/sdcard/解说`, empty gestures, plugins, labels and tools, until its process restarts.
In the logs: `hotkey : loadPackage: {}` and `FuseDaemon: Rejected access ... from uid: <reader>`.

An ordinary Android app cannot fix this: `ActivityManager.killBackgroundProcesses` is ignored for
another app's process on this build, there is no root by default, and SELinux is enforcing.
adb shell can force-stop, so these scripts drive it from Windows.

## Scripts

- `restart-once.ps1`: over adb, takes the enabled accessibility services installed under `/data`
  (third-party ones; system services are left alone) out of `enabled_accessibility_services`,
  force-stops their packages and writes the original setting back, in a `finally` block so the
  reader is never left disabled. The service rebinds in a fresh process that can read `/sdcard`.
  About 4 s.
- `watch-wsa.ps1`: while running, calls `restart-once.ps1` once per WSA session, after Android
  reports boot complete. Logs to `%LOCALAPPDATA%\wsa-a11y\watch.log`.
- `install-task.ps1`: registers `watch-wsa.ps1` as a per-user Scheduled Task at logon (no admin).

## Install

```powershell
.\install-task.ps1                     # -Serial 127.0.0.1:<port> if WSA's adb port differs
Start-ScheduledTask -TaskName "WSA screen reader boot fix"
.\install-task.ps1 -Uninstall          # remove
.\restart-once.ps1                     # one restart by hand, any time
```

Requirements: WSA Developer mode (adb) on, `adb.exe` on PATH (or pass `-Adb`). WSA Settings >
Developer mode shows the adb address.

Speech stops for about 4 s a few seconds after each WSA launch, then the reader runs with its full
configuration.

Tested with Jieshuo on WSA 2407.40000.4.0 x64 (Android 13), October 2026, across WSA restarts.
