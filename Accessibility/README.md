# Third-party screen readers in WSA

This fork adds keyboard support for screen readers other than WSA's built-in Subsystem Screen
Reader, e.g. TalkBack installed from the Play Store or Jieshuo. Everything else is MustardChef's
WSABuilds, unchanged.

## The problem

WSA sends most keys typed in Windows to Android with `InputManager.injectInputEvent()`. Injected
events skip Android's accessibility input filter, so a screen reader only receives modifier keys and
some Alt combinations. Its keyboard shortcuts (Jieshuo navigates with Ctrl+arrows, TalkBack has many
more) never arrive; the reader is usable only with mouse or touch. This is upstream issue
[#182](https://github.com/MustardChef/WSABuilds/issues/182).

## What this fork changes

- [`a11y-keys/`](a11y-keys/): a patch to `/system/framework/services.jar`. Key events injected by WSA
  go through the accessibility input filter, like hardware keys do on a phone, whenever an
  accessibility service has asked for key events. Keys no service consumes reach the app as before.
  The folder holds the patcher, the Java source of the added class and the integration diff for
  the upstream build scripts.
- [`boot-fix/`](boot-fix/): optional Windows scripts for screen readers that keep their settings on
  shared storage (Jieshuo does). WSA starts them before Android unlocks storage, so they come up
  without their hotkeys, gestures and plugins until restarted; the scripts restart them once per
  WSA launch over adb.

The release build is MustardChef's
[LTS 8](https://github.com/MustardChef/WSABuilds/releases/tag/Windows_11_2407.40000.4.0_LTS_8)
(Windows 11 x64, GApps, no Amazon) with only `system.vhdx` changed: `services.jar` patched, its
stale precompiled `oat/x86_64/services.*` files removed (Android recompiles them on first boot).
Install it exactly like the upstream build.

## Using a third-party screen reader

1. Install the screen reader in WSA and enable it in Android Settings > Accessibility, or over adb:
   `adb shell settings put secure enabled_accessibility_services <existing>:<package>/<service>`.
2. Turn off the Subsystem Screen Reader with Win+Ctrl+T or in WSA Settings, so the two do not speak
   at the same time. WSA re-applies that setting at every start, so turning TalkBack off only in
   Android's settings does not last.
3. For Jieshuo and similar readers, consider `boot-fix/`.

## Side effects to know

- The screen reader's shortcuts win over the app's, also in text fields: if its key scheme uses
  Ctrl+C, Ctrl+V, Ctrl+Z, Ctrl+F..., those run the reader's commands instead of copy, paste, undo or
  find. Adjust the reader's key scheme if needed.
- Each key now waits for the screen reader's answer before reaching the app: normally a few ms,
  up to 500 ms per key (Android's limit) if the reader is busy or hung.
- Any enabled accessibility service that asks for key events now sees keys typed in WSA, as on a
  phone with a hardware keyboard. Enable only services you trust.
- Text typed into text fields is unchanged: WSA delivers it through its input method, not as key
  events, so readers do not get those letters as keys (they still announce the typed text).
- Without an accessibility service that filters keys, nothing changes.

## Testing

The patched `services.jar` was boot-tested on a WSA 2407.40000.4.0 x64 install (LTS 7 hotfix 1
base) in October 2026: Jieshuo received Ctrl+arrows, arrows, Tab, letters and Ctrl/Alt
combinations; TalkBack behaved the same as on the unpatched image. LTS 8 ships a byte-identical
original `services.jar`, and the patcher's output is byte-identical too (sha256
`0c847bbc4a64e5bd2ae01097373f3494a66115dae43faacace12fb0c565814b4`). The complete LTS 8 package
itself was not installed and boot-tested. Only x64 was tested.
