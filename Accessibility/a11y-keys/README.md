# a11y-keys: screen readers receive every key in WSA

## Problem

WSA delivers most keys typed in Windows to Android through `InputManager.injectInputEvent()`
(`UserInputRedirectionHandler` in `com.microsoft.windows.userapp`). Injected events skip the
input filter, so an accessibility service that filters key events only sees modifiers and some Alt
combinations (the ones WSA sends through its `virtual_keyboard` evdev device). TalkBack's Alt-based
shortcuts work by luck; other screen readers (e.g. Jieshuo, whose navigation is Ctrl+arrows) and
most TalkBack keys never reach `AccessibilityService.onKeyEvent`.

## Fix

`services.jar` gets one hook at the top of `InputManagerService.injectInputEventToTarget()` and one
new class, `WsaA11yKeyRouter` (source: `WsaA11yKeyRouter.java`; the patcher assembles
`WsaA11yKeyRouter.smali`, generated from it with javac + d8 + baksmali).

For async, untargeted key events injected by the WSA input app's uid while an input filter is
installed (i.e. a service asked for key events), the router does what `InputDispatcher::notifyKey`
does for a hardware key: runs the policy (`interceptKeyBeforeQueueing`) and hands a copy to
`filterInputEvent`. The accessibility filter re-injects every key no service consumes, with
`FLAG_FILTERED`, so apps still get them. Every other call runs the original method unchanged. With
no screen reader running nothing changes; after an unexpected error the router disables itself.

Not changed: text typed into text fields (WSA commits it through its input method, not as key
events), and which screen reader Win+Ctrl+T starts.

## Patcher

```
python3 wsa_a11y_keys.py --system <mounted system dir> --smali smali-2.5.2.jar --baksmali baksmali-2.5.2.jar
python3 wsa_a11y_keys.py --jar services.jar --out services.patched.jar [--smali ...] [--baksmali ...]
python3 wsa_a11y_keys.py --jar services.jar --check
```

- Python 3.8+ (stdlib only) and Java; smali/baksmali 2.5.x release jars (or `$SMALI_JAR`,
  `$BAKSMALI_JAR`).
- Finds the dex holding `InputManagerService`, disassembles only that dex, inserts the hook using
  the method's parameter registers (independent of how a given build allocated its locals),
  reassembles it single-threaded (reproducible output) and adds the router as a new
  `classesN.dex`. Stored entries stay 4-byte aligned.
- `--system` rewrites `framework/services.jar` in place (same inode: owner, mode and
  `security.selinux` label are kept) and deletes the now stale `framework/oat/*/services.*`
  (odrefresh recompiles on first boot).
- Refuses, writing nothing, when the expected method or members are missing (exit code 2).
  Already patched jars are detected (exit code 0).
- About 30 s per run.

Tested on WSA 2407.40000.4.0 x64 (Android 13, MagiskOnWSALocal build), Oct 2026, with smali and
baksmali 2.5.2 (build 5dfadde8): boots, odrefresh recompiles services.jar, Jieshuo receives
Ctrl+arrows, plain arrows, Tab, letters and Ctrl/Alt combinations (letters typed into a text field
excepted, see above). TalkBack reacted the same way as on the unpatched image in a side-by-side run
(plain arrows still reach the app, Alt+arrows navigate). Output is identical across runs. The
sha256 values in the workflow step are those of the Bitbucket release jars as downloaded on
2026-10-26.

## Integration in WSABuilds

`upstream-integration.diff` (against MustardChef/WSABuilds master, Oct 2026):

- `.github/workflows/build.yml`: downloads smali/baksmali 2.5.2 (sha256-pinned) before
  "Install Houdini and Process Images" and exports `SMALI_JAR`/`BAKSMALI_JAR`.
- `MagiskOnWSA/libhoudini/houdini_installer.sh`: `patch_a11y_keys` runs on the mounted system
  image right after `make_changes`; it is skipped if `MagiskOnWSA/a11y-keys/` is absent and only
  warns when the build does not fit.

To use it in the build pipeline, copy this folder (without `upstream-integration.diff`) to
`MagiskOnWSA/a11y-keys/` and apply the diff. This fork does not change its own workflows; its
release build was patched with this script directly (see `../README.md`).
