# DroidSB

Rootless iOS 15/16 tweak bringing the Android 17 / LineageOS 24 status bar to
the native iOS status-bar host. Designed to pair with
[LineageQS](https://github.com/drel4/LineageQS).

**Status: experimental. v0.1.0 confirmed working by the user on the SE below;
v0.1.9 caused a reported SpringBoard startup freeze and is withdrawn.
v0.1.10 rolled its runtime changes back. v0.1.12 adds recording-chip transitions
and retains the native recording indicator through confirmation; device
confirmation is still required.**
Primary test target: iPhone SE (2016), iOS 15.8.2, rootless jailbreak.
arm64 (SE/A9) and arm64e slices are included. iOS 16 and notched layouts still
need device validation; the original SE cannot run iOS 16.

## What it does

- Left-aligned, localized clock; Android 17 rounded mobile and Wi-Fi glyphs.
- Google Sans Flex clock, carrier and network labels, using the same unmodified
  variable font and CoreText weight/optical-size approach as LineageQS.
- Android unified horizontal battery with vector digits, charging bolt,
  power-saving attribution, charge fill and light/dark foreground adaptation.
- Airplane mode, alarm, DND, VPN, location, Bluetooth and lock from iOS's status data.
- Rotation lock is intentionally hidden, matching Android's default exclusion
  list, and does not cause a stock-bar fallback.
- Screen recording: Android red rounded chip, white recording icon and elapsed
  time when a valid native start timestamp is available (otherwise `REC`). Tap
  it to invoke the recording item's native controls; if unavailable, use Control
  Center. With limited width, the chip hides its timer and shrinks to its icon
  before squeezing the ordinary clock; it does not merge into the clock.
  See [recording behavior](docs/RECORDING.md) for details and limitations.
- Recording-chip fade in/out, smooth full/compact width changes and press feedback;
  changed system glyphs crossfade. No continuous recording pulse. Confirmed native
  recording activity remains visible through a temporary capture-state drop.
- Lock-screen carrier label when iOS suppresses the small clock; the large
  lock-screen clock remains untouched. AirPods accessory battery is exposed to
  VoiceOver without replacing the phone battery gauge.
- Replaces the normal native foreground in SpringBoard and UIKit apps, not a
  floating window. Native status-bar sizing, hiding, rotations and gestures remain.
- Settings → DroidSB: enable/disable, percentage and 24-hour clock.
- Leaves LineageQS's own QS header alone; no dependency on LineageQS.
- Omits iOS-only cross-app navigation breadcrumbs ("Back to App Store", etc.)
  without reverting to the stock bar or adding a replacement button.
- No status-entry-triggered stock-bar fallback. The native network-activity
  spinner, rotation lock and other unported indicators are omitted instead.
- Fullscreen top-edge first swipe: a temporary live DroidSB row replaces the
  native arrow, with Android's 275/340 ms slide and easing. Native second-swipe
  routing remains; a 2.25-second native dismissal deadline pauses only while
  touching/pulling the bar, then restarts on release. App interaction is untouched.
  No outside-touch dismissal or full-screen touch overlay. Reduce Motion is respected.
  See [fullscreen behavior](docs/FULLSCREEN.md).

Unported call/hotspot/privacy/secondary-SIM indicators are not recreated and do
not restore the stock bar. Stock visuals are used only when the tweak is disabled
or rendering prerequisites (host/data/assets) are unavailable. Notification app
icons are not ported yet. Carrier RAT labels
appear only when iOS supplies a recognized string;
the tweak does not guess private numeric enums. Google Sans Flex is bundled under
SIL OFL 1.1 and does not require LineageQS to be installed. The system font is
used only if loading the bundled font fails. No Android services run on iOS.

## Build (Linux / Theos)

```sh
cd ~/0drel/DroidSB
export THEOS="$HOME/theos"
bash scripts/build.sh
```

Requires Theos, Linux Apple clang/cctools, an iPhoneOS 16.5 SDK, ldid,
and the Theos Preferences headers/stubs. Packages appear in `packages/`.
To override the Theos toolchain, set `DROIDSB_TOOLCHAIN=/path/to/linux/iphone`.
Linux linkers may emit the old arm64e ABI even with a newer compiler. In that
case build [allemande](https://github.com/p0358/allemande) and set
`DROIDSB_ALLEMANDE=/path/to/allemande`. The build converts only the arm64e
slice, verifies arm64 is unchanged, re-signs both payloads, and records hashes
and conversion provenance in the packaged `build-info.json`. Allemande retains
the old Mach-O subtype marker; a marker alone does not prove ABI compatibility.
The SE's arm64 slice is unchanged. Conversion is experimental; arm64e devices
still require independent device testing. A compatible Apple linker can avoid
conversion. Incompatible arm64e output without a converter is rejected.
The package scheme is rootless (`iphoneos-arm64`, `/var/jb` prefix).
Host connection details are deliberately excluded from git.

## Install / remove

Install the `.deb` with Sileo/Zebra on a rootless iOS 15/16 jailbreak, then
respring. Relaunch already-running apps so their process loads the tweak.
PreferenceLoader is required for the settings page. Disable competing status-bar
tweaks before testing. Toggle Enabled off to restore stock visuals; uninstall
`dev.drel.droidsb` and respring to remove it entirely.

From a device shell with root privileges:

```sh
dpkg -i dev.drel.droidsb_0.1.12_iphoneos-arm64.deb
killall -9 SpringBoard
# Removal:
apt remove dev.drel.droidsb
```

## Upstream / licensing

Code: Apache-2.0. Bundled Google Sans Flex: SIL OFL 1.1 (license next to font).
See [LICENSE](LICENSE), [NOTICE](NOTICE), [reference/fonts.json](reference/fonts.json), and
[reference/manifest.json](reference/manifest.json). Reference sources are pinned to
[`LineageOS/android_frameworks_base`, lineage-24.0, commit 7f6de40](https://github.com/LineageOS/android_frameworks_base/tree/7f6de40b6429462d47ba9ba351b99943269c8067).
Upstream Android source is adapted to UIKit; this is not binary-compatible
Android SystemUI. The new status-bar icon style is selected explicitly, rather
than depending on Android feature flags.

```sh
python3 scripts/fetch-reference.py
python3 scripts/export-assets.py
python3 scripts/check-source.py
```

See [docs/TESTING.md](docs/TESTING.md) for device acceptance checks and known gaps.
