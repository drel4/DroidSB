# Device acceptance

Build success is not a device test. No device connection was provided during
initial implementation. Track actual results here when testing on SE 2016 / 15.8.2.

User feedback: v0.1.0 works on the target SE, but VPN was small, connecting
AirPods restored stock, and the lock screen remained stock. v0.1.1 handles
Bluetooth/lock entries and fits the VPN artwork to 12pt; these fixes still need
on-device confirmation.

v0.1.2 corrects the oversized v0.1.1 VPN glyph using Android's actual VPN slot
drawable and 15dp system-icon viewport sizing. See [VPN-SIZING.md](VPN-SIZING.md).

v0.1.3 intentionally ignores iOS back/forward navigation entries. Opening an app
from App Store or a deep link should retain DroidSB without a breadcrumb button.

User confirmed that rotation lock caused the persistent stock bar, and reported
the same during recording. v0.1.4 handles rotation lock and identified screen
recording, and repairs attachment/early-resource recovery. Needs device testing.

v0.1.5 follows Android's default rotation-icon exclusion and keeps the ordinary
clock visible while collapsing recording text to an icon-only chip when needed.
It also removes status-entry-triggered stock fallback, including network activity.

## Required before claiming stable

- In a fullscreen video/game with deferred top gestures, swipe once: DroidSB
  should slide in instead of the iOS arrow, without resizing the app. Wait for
  native auto-dismiss, then repeat. Swipe a second time to open the shade.
- Repeat fullscreen swipes in both landscape directions, with/without LineageQS,
  and during recording. Check the clock, live signal/battery, recording tap,
  rapid dismiss/reveal, rotation while visible, and leaving the fullscreen app.
- v0.1.7 orientation regression: on an SE with a portrait-aligned SpringBoard
  host, the row should run along the landscape app's top edge, with upright
  clock/icons, full landscape width and outward hide motion. Test both directions,
  then return to portrait and repeat; no cached landscape edge should remain.
- Disable DroidSB while the transient row is visible: it and its timers should
  disappear and restore the arrow's original visibility. Re-enable and retry.
  Enable Reduce Motion: the transient row should appear without sliding.
- Install rootless package; verify SpringBoard and Settings start without crashes.
- Check 320pt portrait SE layout: clock left, policy/mobile/Wi-Fi/battery right.
- Compare Wi-Fi levels 0–3, mobile 0–4, airplane + Wi-Fi and no SIM to stock.
- Check battery 0/5/50/100%, unknown capacity, charge/full/unplug, Low Power Mode.
- Confirm native entry `enabled`, `displayValue`, `capacity`, `string` and
  `currentAggregatedData` are available on 15.8.2; missing/private schema changes
  must leave stock visible. Investigate a persistent stock bar before widening hooks.
- Verify black on white / white on dark across SpringBoard and apps; animations.
- Check clock minute rollover, locale, 12/24h, time-zone/time changes and midnight.
- Compare clock/carrier lettering with LineageQS: Google Sans Flex, 500 weight,
  13pt optical size. Test both with and without LineageQS installed; verify shared
  font registration does not affect either tweak. Battery digits remain vectors.
- Lock/unlock, landscape, app switcher, launch/exit full-screen apps, rotation.
- Toggle rotation lock in Control Center/LineageQS, leave it enabled, and respring
  repeatedly. DroidSB should stay visible on the Home Screen and inside apps,
  with no rotation-lock glyph (the default Android exclusion).
- Start screen recording, switch apps, stop it, and record again. Check the red
  chip/timer, clock and system icons fit the 20pt SE bar without overlapping.
- Add VPN/Bluetooth/other status icons while recording, then remove them. The
  chip should shrink to icon-only before truncating the clock, and expand again
  when room permits. Tapping and VoiceOver should work in both layouts.
- Tap the red chip: native recording confirmation/control should open when its
  action is exposed; otherwise show the Control Center instruction. Confirm Stop
  saves the video, Cancel continues recording, and there is no duplicate action.
- Check recording after lock/unlock/rotation; elapsed time must not reset due to
  view recreation. With an invalid/missing timestamp, show REC rather than zero.
- Check calls, mirroring and camera/mic access while recording. DroidSB should
  remain visible; unported native indicators are omitted, not converted.
- Open an installed app using App Store's Open button; follow an app link from
  Safari/Mail. Verify DroidSB remains visible, with no "Back to" or forward
  breadcrumb. Native status entries must not restore the stock bar.
- Toggle DroidSB off while a breadcrumb is active: the native breadcrumb and
  bar should return unchanged. Re-enable and confirm only the breadcrumb vanishes.
- Connect/disconnect AirPods with VPN active, both unlocked and on the lock
  screen. Verify DroidSB stays visible, the VPN key is legible, and phone battery
  does not change to the AirPods battery. Check VoiceOver accessory percentage.
- Lock/unlock with and without Touch ID/passcode. Confirm the small clock is
  not duplicated when iOS hides it; carrier and lock indicator use DroidSB.
- Verify scroll-to-top, Control Center gestures and VoiceOver clock/battery labels.
- Trigger network activity/spinning wheel, calls and camera/mic activity: the
  bar must remain DroidSB. Verify VPN/location/DND glyphs still track native state.
- Enable/disable repeatedly in Settings; confirm no invisible or double foreground.
- Install alongside LineageQS; confirm its shade and header are unchanged.
- Inspect SpringBoard/app crash logs; verify safe-mode recovery and removal.
- Independently validate iOS 16 and notched/dynamic-island devices; these are not
  covered by a successful SE test.

## Current limitations

No app-notification icons, dual-SIM composition, custom font selection, Android RAT enum
translation, fancy battery interpolation or background service. Unported active
entries are omitted; there is no status-entry fallback. Apps drawing their own custom
status bar and legacy hosts other than `_UIStatusBar` remain untouched.
