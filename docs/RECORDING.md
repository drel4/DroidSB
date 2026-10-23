# Recording and rotation lock (0.1.4)

## Upstream appearance

The vendored/pinned Android 17 / LineageOS 24 `ScreenRecordChipViewModel` uses
`ColorsModel.Red`, a white `ic_screenrecord` and a running chronometer. Red is
`GM2_red_700` = **#C5221F**, not a theme-dependent red. The rounded chip normally
has a 24sp background and 16dp icon; DroidSB fits the height to the native iOS bar
(18pt on the SE's 20pt bar) rather than increasing the system status-bar height.

The checked chip/model/background and legacy `ScreenRecordDrawable` do **not**
contain a continuous color pulse. Launch/return transitions are separate. This
port does not invent a pulse, or recreate Android's countdown/toolbar.

As of 0.1.12, chip visibility fades in/out, matching the single-chip
`AnimatedVisibility(fadeIn(), fadeOut())` approach in `OngoingActivityChips.kt`.
The UIKit fade is 300 ms; width/clock reflow and changed-glyph crossfades are
200 ms, with 120 ms press-color feedback. These durations/press feedback are
iOS adaptations, not a claim that every Android animation is reproduced.
There is no continuous color pulse, timer-tick fade or invented dialog morph.
Reduce Motion makes these changes immediate. Interrupted visibility changes
reverse from the current fade, and exiting chips cannot receive actions.

`ChipContent.hideTextIfDoesNotFit` removes timer text if it does not completely
fit, leaving the icon centered in the red chip. `OngoingActivityChipsViewModel`
can also select `Content.IconOnly` for multiple chips on narrow displays. Neither
changes the chip into the ordinary clock. DroidSB v0.1.5 preserves the clock's
natural width first, then chooses full icon+timer or a compact icon-only chip.
It re-expands as space becomes available; it does not collapse after an invented
timeout. Multiple simultaneous Android-style chips are not implemented here.

## Tapping / stopping

Android's chip uses an expand action to open a recording toolbar or confirmation
dialog, not an unconditional immediate stop. DroidSB routes the tap to the native
action belonging specifically to iOS's background recording display item. UIKit
handles confirmation and recording finalization/saving. There is no synthetic tap,
guessed global status-bar action or direct ReplayKit stop call.

If the current iOS host does not expose that action, the chip explains that
recording can be stopped in Control Center. Other status-bar taps pass through;
the native action gesture is excluded only inside the custom recording chip.
This private-API path still requires validation on the test iPhone.

## Identifying recording

`UIScreen.isCaptured` also covers mirroring, so it is insufficient alone. Require
an enabled native background activity with an explicit recording symbol, or
initial red-color evidence while capture is active. The native activity type
number is passed back to UIKit's own symbol/color helpers, not interpreted
through a guessed enum.

Once confirmed, the same enabled native activity retains its recording identity
through a temporary capture-state drop, including the user-reported Stop/Cancel
popup. Evidence belongs to the native source bar and is shared with its transient
renderer. A disabled or changed native activity clears it, so Stop removes the
chip while Cancel/continue does not make it disappear/reappear or reset its timer.
This follows native indicator state; it does not assert whether iOS is encoding
video during the popup, control ReplayKit, or invent a paused-recording API.
As of v0.1.5, unclassified activity does not restore the native bar. During the
initial countdown a chip may not appear until capture starts. Other unported
native activity indicators are omitted rather than causing reversion. Camera/mic
privacy indicators have a separate native-driven presentation as of 0.1.14.

The timer uses a plausible native `displayStartDate` rather than starting over
when a view is recreated. If no usable start date is available, display `REC`.
The timer is invalidated on detach/disable/unavailable rendering and captures the view weakly.

## Persistent rotation lock and recovery

The previous generic fallback treated `rotationLockEntry` as unsupported. Since
the setting persists, respringing did not help. v0.1.5 removes status-entry
fallback entirely (including network activity's spinning wheel). Although `PhoneStatusBarPolicy` retains
rotation-lock drawing code, `config_statusBarIconsToExclude` explicitly excludes
`status_bar_rotate`. v0.1.5 follows that default and draws no rotation-lock icon;
the v0.1.4 icon was an incorrect reading of the drawable/policy alone.

The associated replacement is reattached if UIKit removes its view, and retried
on window attachment. Empty asset/font reads are no longer cached permanently;
missing prerequisites get up to eight delayed retries. Stock is restored only
when disabled or the renderer lacks a usable host, data or assets. Recovery fixes
are separate from the user's confirmed status-entry causes.
