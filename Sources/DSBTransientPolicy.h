// SPDX-License-Identifier: Apache-2.0
#pragma once
#include <stdint.h>
#include <stdbool.h>

// Android AutoHideControllerImpl: accessibility-adjusted 2250 / 350 ms.
// iOS has no recommended-timeout API; VoiceOver/Switch Control get 10 seconds.
static inline double DSBTransientTimeout(bool outside, bool assistive) {
    return assistive ? 10.0 : outside ? .350 : 2.250;
}
static inline uint64_t DSBQuantizeUnit(double value) {
    return value <= 0 ? 0 : value >= 1 ? 4095 : (uint64_t)(value * 4095 + .5);
}
// Fixed-screen normalized bounds + presentation generation fit a notify state.
// No touch data is broadcast: clients report only an outside-start generation.
static inline uint64_t DSBTransientFrame(uint16_t generation, double left, double top, double right, double bottom) {
    if (!generation || right <= left || bottom <= top) return 0;
    return ((uint64_t)generation << 48) | DSBQuantizeUnit(left)
        | (DSBQuantizeUnit(top) << 12) | (DSBQuantizeUnit(right) << 24)
        | (DSBQuantizeUnit(bottom) << 36);
}
static inline bool DSBTransientContains(uint64_t state, double x, double y) {
    if (!(state >> 48)) return false;
    double px = x * 4095, py = y * 4095;
    return px >= (double)(state & 4095) - 1 && px <= (double)((state >> 24) & 4095) + 1
        && py >= (double)((state >> 12) & 4095) - 1 && py <= (double)((state >> 36) & 4095) + 1;
}
static inline bool DSBTransientGenerationMatches(uint64_t state, uint64_t generation) {
    return generation && (state >> 48) == generation;
}
