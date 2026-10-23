# Camera / microphone indicators (0.1.14)

The selected Android SystemUI path animates a green chip containing camera/mic
glyphs, then contracts it into a persistent green dot. The port uses the pinned
`SystemEventChipAnimationController`, `SystemStatusAnimationScheduler`,
`StatusBarSystemEventAnimator`, `PrivacyItemController` and privacy resources.

## Choreography

- 100 ms debounce, 500 ms entrance and 3000 ms displayed-chip hold.
- Background alpha starts at frame 7 over 5 frames; content starts at frame 10
  over 10 frames. Width expands over 23 frames with `(0,0,0,1)` interpolation.
- Dot contraction reproduces the 9/20-frame width stages, 8-frame delayed 6/15-
  frame height stages and 3-frame delayed 11-frame translation, with the pinned
  per-stage cubic interpolators. These are spec frames at 60 Hz, not device frames.
- System icons move/fade out and return with the source's timings/curves. The
  remaining dot fades out over 160 ms after activity finishes. Camera/mic
  indications are held at least five seconds from appearance.

Background is `#3DDC84`; camera/mic glyph paths are the grouped-privacy resources.
Chip height/icons fit the iOS native row (18 pt on the SE instead of Android's
24 sp); the persistent dot is 6 pt. Reduce Motion uses the persistent dot directly.
This reproduces the selected animation path, not every Android feature-flag/theme
variant or its camera-app exemptions. Location privacy chips are flag-controlled
in upstream; DroidSB retains its existing separate location status icon instead.

## Native activity data and limitations

SpringBoard's existing recording-indicator manager supplies real active sensor
attributions. Their native sensor values are passed back to Apple's identifier/
color helpers, not decoded through guessed numeric enums. Empty activity sets
clear the state. Hooks are installed only if both the class and selector exist.
No camera/microphone APIs are started by the tweak.

In app-owned status bars, a native sensor entry/registered indicator may expose
only its priority color, or an opaque portal. The port then shows that identified
sensor or a generic active privacy dot; it does not invent simultaneous camera
and microphone access. There is no cross-process IPC or global app-event hook.

The custom indicator is hosted in the existing status-bar row. It does not add
an always-on overlay when iOS hides the entire bar, suppress standalone native
privacy windows, or implement an Android privacy-dashboard tap action. Native
fallbacks outside the custom host are deliberately preserved.

Physical SE/iOS 15.8.2 testing is required for native classifications, shutdown,
app transitions, camera+mic together, fullscreen, lock screen and animation timing.
