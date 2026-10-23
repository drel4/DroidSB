// SPDX-License-Identifier: Apache-2.0
#pragma once
#include "DSBMotion.h"
enum { DSBPrivacyCamera = 1, DSBPrivacyMicrophone = 2, DSBPrivacyUnknown = 4 };
typedef struct { double width, height, alpha, contentAlpha, shift, chromeAlpha, chromeShift; } DSBPrivacyFrame;
static inline double DSBPhase(double t, double delay, double duration) {
    double f = (t-delay)/duration; return f <= 1e-9 ? 0 : f >= 1-1e-9 ? 1 : f;
}
static inline double DSBMix(double a, double b, double f) { return a+(b-a)*f; }
// SystemStatusAnimationScheduler + SystemEventChipAnimationController, 60 Hz
// spec frames (not device-refresh frames), 100 ms debounce and 3000 ms hold.
static inline DSBPrivacyFrame DSBPrivacyAt(double time, double full, double height) {
    double f = 1.0/60, t = time-.1, min = 10*height/24, dot = 6;
    DSBPrivacyFrame v = {full, height, 1, 1, 0, 0, -15};
    if (t < .5+3) {
        v.width = DSBMix(min, full, DSBBezier(DSBPhase(t,7*f,23*f),0,0,0,1));
        v.alpha = DSBPhase(t,7*f,5*f);
        v.contentAlpha = DSBPhase(t,10*f,10*f);
        v.chromeAlpha = 1-DSBPhase(t,0,8*f);
        v.chromeShift = -15*DSBBezier(DSBPhase(t,0,23*f),.33,0,0,1);
    } else {
        t -= 3.5;
        v.width = t < 9*f
            ? DSBMix(full,min,DSBBezier(DSBPhase(t,0,9*f),.44,0,.25,1))
            : DSBMix(min,dot,DSBBezier(DSBPhase(t,9*f,20*f),.3,0,.26,1));
        v.height = t < 14*f
            ? DSBMix(height,dot*2,DSBBezier(DSBPhase(t,8*f,6*f),.4,0,.17,1))
            : DSBMix(dot*2,dot,DSBBezier(DSBPhase(t,14*f,15*f),.3,0,0,1));
        v.shift = dot*DSBBezier(DSBPhase(t,3*f,11*f),0,0,.05,1);
        // Source content clips naturally as its background contracts.
        v.chromeAlpha = DSBPhase(t,11*f,5*f);
        v.chromeShift = 7*(1-DSBBezier(DSBPhase(t,7*f,23*f),0,0,0,1));
    }
    return v;
}
#define DSB_PRIVACY_TIMELINE_SECONDS (0.1 + 0.5 + 3.0 + 0.5)
