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

## Dismissal (0.1.9)

The pinned Android [`AutoHideControllerImpl`](../reference/upstream/packages/SystemUI/src/com/android/systemui/statusbar/phone/AutoHideControllerImpl.java)
uses a 2250 ms ordinary auto-hide timeout and a 350 ms outside-touch timeout.
DroidSB now owns those deadlines while its row is presented, canceling/suppressing
the old native grabber timer. Timers pause during a bar touch or native pull;
release/cancellation restarts the ordinary timeout, or the pending outside-touch
timeout. Repeated outside touches do not postpone the pending dismissal.

Android's accessibility service adjusts both delays. iOS exposes no equivalent
recommended-timeout API: DroidSB extends both to 10 seconds when VoiceOver or
Switch Control is running. This is an explicit iOS adaptation, not a recreation
of Android's per-user accessibility timeout preference.

The UIKit `sendEvent:` hook observes touch starts; it does not consume, cancel
or change delivery to fullscreen apps. SpringBoard publishes the row's normalized
fixed-screen bounds and a reveal generation using Darwin notify state. App
processes report only an outside-start generation, not coordinates or app data.
Late reports from older reveals are ignored. The IPC is active only while a row
is published and is scoped to the main screen. A touch starting inside the row
does not count as outside; recording actions and top pulls retain their behavior.
An upward swipe starting outside qualifies on its initial touch; no global
swipe-up recognizer is added.

Expiry invokes SpringBoard's own timer-dismiss entry point to clear native
visibility/second-swipe state, not just remove the custom view. Forced native
teardown and accepted shade pulls still dismiss normally. Missing IPC support
would leave timer auto-hide working but outside app touches require device
verification. Relaunch already-running apps after installing the update.

Data comes from SpringBoard's existing `_UIStatusBar` updates in the same process;
the row also refreshes its clock each second while presented. Recording actions
are forwarded to the actual source status bar, never to the presentation host.
Missing host/data/assets leave the grabber alone; native status entries do not
trigger a stock status-bar fallback. Toggle Disabled restores the native arrow.

Private grabber hooks and landscape presentation require physical iOS 15/16
testing. Build/package validation cannot establish gesture correctness on device.
