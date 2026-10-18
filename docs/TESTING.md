# Device acceptance

Build success is not a device test. No device connection was provided during
initial implementation. Track actual results here when testing on SE 2016 / 15.8.2.

User feedback: v0.1.0 works on the target SE, but VPN was small, connecting
AirPods restored stock, and the lock screen remained stock. v0.1.1 handles
Bluetooth/lock entries and fits the VPN artwork to 12pt; these fixes still need
on-device confirmation.

v0.1.2 corrects the oversized v0.1.1 VPN glyph using Android's actual VPN slot
drawable and 15dp system-icon viewport sizing. See [VPN-SIZING.md](VPN-SIZING.md).

## Required before claiming stable

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
- Connect/disconnect AirPods with VPN active, both unlocked and on the lock
  screen. Verify DroidSB stays visible, the VPN key is legible, and phone battery
  does not change to the AirPods battery. Check VoiceOver accessory percentage.
- Lock/unlock with and without Touch ID/passcode. Confirm the small clock is
  not duplicated when iOS hides it; carrier and lock indicator use DroidSB.
- Verify scroll-to-top, Control Center gestures and VoiceOver clock/battery labels.
- Confirm call, recording and camera/mic indicators revert to stock; verify
  the Android VPN/location/DND glyphs track native enabled state.
- Enable/disable repeatedly in Settings; confirm no invisible or double foreground.
- Install alongside LineageQS; confirm its shade and header are unchanged.
- Inspect SpringBoard/app crash logs; verify safe-mode recovery and removal.
- Independently validate iOS 16 and notched/dynamic-island devices; these are not
  covered by a successful SE test.

## Current limitations

No app-notification icons, dual-SIM composition, custom font, Android RAT enum
translation, fancy battery interpolation or background service. Unsupported active
entries intentionally fall back to the native bar. Apps drawing their own custom
status bar and legacy hosts other than `_UIStatusBar` remain untouched.
