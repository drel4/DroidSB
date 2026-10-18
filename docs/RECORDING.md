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
an enabled native background activity plus native recording symbol/red-color
evidence while capture is active. The native activity type number is passed back
to UIKit's own symbol/color helpers, not interpreted through a guessed enum.
Unclassified activity stays native; the initial countdown may therefore stay
native until capture starts. Camera/microphone privacy entries still retain the
stock bar, including when recording with additional privacy activity.

The timer uses a plausible native `displayStartDate` rather than starting over
when a view is recreated. If no usable start date is available, display `REC`.
The timer is invalidated on detach/fallback and captures the view weakly.

## Persistent rotation lock and recovery

The previous generic fallback treated `rotationLockEntry` as unsupported. Since
the setting persists, respringing did not help. It now has Android's portrait /
landscape rotation-lock glyph and is covered by executable policy regressions.

The associated replacement is reattached if UIKit removes its view, and retried
on window attachment. Empty asset/font reads are no longer cached permanently;
missing prerequisites get up to eight delayed retries. Unknown active entries
still preserve stock, with `[DroidSB] Native fallback: entry:...` in the process
log when the reason changes. These recovery fixes are separate from the user's
confirmed rotation-lock cause.
