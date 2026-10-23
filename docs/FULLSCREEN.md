# Fullscreen transient status bar

Android does animate its status bar. The pinned LineageOS 24 framework
[`InsetsController.java`](../reference/upstream/core/java/android/view/InsetsController.java)
uses a 275 ms slide in and 340 ms slide out for swipe-revealed transient bars,
with cubic control points `(0.4, 0), (0.2, 1)`. Other policies use fades instead;
SystemUI also animates icon/background changes. These are distinct animations,
not a constant pulse on the recording chip.

DroidSB 0.1.6 replaces the top fullscreen first-swipe grabber's arrow visual with
a temporary live DroidSB row. It uses those slide durations/easing, a dark
translucent backing for legibility, and white foreground. Reduce Motion skips
the slide. It does not reveal a permanent status bar or resize the fullscreen app.

As of 0.1.13, the translucent background belongs to the sliding row, not its
stationary clipping host. The background and glyphs travel together in both
directions; the scrim no longer fades in place behind moving icons. Slide
timings, orientation geometry and bar-only interaction handling are unchanged.

0.1.14 reproduces the transient motion calculation from `InsetsController`:
linear elapsed fraction, cubic `(0.4, 0, 0.2, 1)` position interpolation, then
truncation of interpolated physical-pixel insets. A display-link driver applies
those positions directly without inherited UIKit animation transactions. The
same row contains both background and glyphs, with constant opacity. Entrance
starts only after the deferred geometry pass. Interrupted entry retains its
current offset; native completion no longer forcibly truncates the 340 ms exit.
No emphasized curve, spring or subjective motion tuning is substituted.

The timing and mathematical motion path are reproduced; native iOS bar height,
orientation/gesture ownership, scrim styling and Reduce Motion remain platform
adaptations. Different displays/refresh rates do not produce identical captures.

The row lives in the existing SpringBoard grabber host, not a new overlay window.
The physical starting-edge approach was adapted from LineageQS: SpringBoard's
scene may remain portrait-aligned over a landscape app. As of 0.1.8, the actual
initial touch is captured before recognition in fixed screen coordinates and
converted into the host AFTER its presentation layout, with one deferred layout
check for first-use setup. This avoids retaining an edge calculated in the old
host coordinates. In 0.1.11, portrait placement is locked to the fixed screen's top (or bottom
for upside-down portrait), independent of corner proximity and drag direction.
Landscape considers only the two possible fixed-screen top sides; position
along that edge cannot select a different boundary. The row's basis is converted
from fixed screen space into the final host, including already-oriented hosts.
The row rotates onto the touched edge and slides outward through that edge.
Scene conversion remains the fallback for presentations without a touch.
SpringBoard's existing
gesture recognizers, first/second-swipe decisions,
and LineageQS routing remain intact. The top grabber's center-only region test
is widened while DroidSB is enabled: pulls can start along the full top edge,
but native edge recognition and eligibility still apply. The bottom/home
grabber is not replaced; disabling DroidSB restores the native region test.
This is an Android-looking presentation on iOS gesture policy, not a port of
Android's entire immersive-mode window manager.

## Dismissal / recovery

**0.1.9 is withdrawn after a reported SpringBoard startup freeze (black screen
or spinning wheel, Safe Mode after force reboot).** The exact on-device failure
is not confirmed without device logs.

0.1.10 restores the runtime sources from 0.1.8. The global UIApplication event
hook, notification IPC, constructor initialization, custom auto-hide timer and
native timer/tap suppression introduced in 0.1.9 are removed entirely. Native
iOS grabber dismissal is restored. Android-specific dismissal is NOT enabled.

## Bar-local auto-hide (0.1.11)

0.1.11 restores a 2.25-second deadline using the native grabber's existing
`_dismissTongue:` callback. A non-recognizing, non-canceling touch observer is
attached ONLY to the bar's bounds. Holding the bar or its native top-pull gesture
cancels the pending deadline; release/cancellation starts a fresh 2.25 seconds.
Native presentations which explicitly disable auto-dismiss retain that decision;
missing private scheduling methods retain native behavior.

The bar's hit-test area is limited to its row. Recording controls receive their
original touch delivery, and native shade/LineageQS pull routing is unchanged.
There is NO full-screen layer, app event hook, outside-touch IPC, constructor
initialization, VoiceOver-specific timeout or timer/tap suppression hook.
Ordinary app taps/scrolls neither pause the timer nor request dismissal.

The Android reference's 350 ms branch is conditional on an actual
`ACTION_OUTSIDE` event plus visibility and `shouldHideOnTouch()` checks; it was
incorrect to equate that with every app touch. A generic touch-catching overlay
would not reproduce normal Android fullscreen interaction and is not implemented.

If affected, remain in Safe Mode and uninstall 0.1.9 or replace it with the
recovery package before attempting another respring. The recovery build still
requires confirmation on the physical device; successful Linux tests do not
prove SpringBoard startup or gesture correctness.

Data comes from SpringBoard's existing `_UIStatusBar` updates in the same process;
the row also refreshes its clock each second while presented. Recording actions
are forwarded to the actual source status bar, never to the presentation host.
Missing host/data/assets leave the grabber alone; native status entries do not
trigger a stock status-bar fallback. Toggle Disabled restores the native arrow.

Private grabber hooks and landscape presentation require physical iOS 15/16
testing. Build/package validation cannot establish gesture correctness on device.
