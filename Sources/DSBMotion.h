// SPDX-License-Identifier: Apache-2.0
#pragma once
#include <math.h>

// Android PathInterpolator cubic inversion: interpolate Y at a given time X,
// rather than treating the Bezier parameter itself as elapsed time.
static inline double DSBCubic(double t, double p1, double p2) {
    double u = 1-t;
    return 3*u*u*t*p1 + 3*u*t*t*p2 + t*t*t;
}
static inline double DSBBezier(double x, double x1, double y1, double x2, double y2) {
    if (x <= 0) return 0;
    if (x >= 1) return 1;
    double lo = 0, hi = 1;
    for (int i = 0; i < 26; i++) {
        double t = (lo+hi)/2;
        if (DSBCubic(t, x1, x2) < x) lo = t; else hi = t;
    }
    return DSBCubic((lo+hi)/2, y1, y2);
}
static inline double DSBTransientDuration(int showing) { return showing ? .275 : .340; }
static inline double DSBTransientOffset(double fraction, double height, double startOffset, int showing) {
    // InsetsController.sEvaluator truncates interpolated physical-pixel insets.
    float eased = (float)DSBBezier(fraction, .4, 0, .2, 1);
    float start = (float)(height + startOffset), end = showing ? (float)height : 0;
    int visible = (int)(start + eased*(end-start));
    return visible-height;
}
