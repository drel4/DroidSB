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

The row lives in the existing SpringBoard grabber host, not a new overlay window.
The physical starting-edge approach was adapted from LineageQS: SpringBoard's
scene may remain portrait-aligned over a landscape app. As of 0.1.8, the actual
initial touch is captured before recognition in fixed screen coordinates and
converted into the host AFTER its presentation layout, with one deferred layout
check for first-use setup. This avoids retaining an edge calculated in the old
host coordinates. Near corners, the inward pan direction breaks distance ties.
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

The retained Android [`AutoHideControllerImpl`](../reference/upstream/packages/SystemUI/src/com/android/systemui/statusbar/phone/AutoHideControllerImpl.java)
reference specifies 2250 ms auto-hide and 350 ms outside-touch dismissal, with
accessibility adjustments. These remain reference material, not active features
of the recovery build. They need a separately validated redesign before returning.

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
