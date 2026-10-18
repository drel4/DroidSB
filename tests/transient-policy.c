// SPDX-License-Identifier: Apache-2.0
#include "DSBTransientPolicy.h"
#include <assert.h>

int main(void) {
    assert(DSBTransientTimeout(false, false) == 2.250);
    assert(DSBTransientTimeout(true, false) == .350);
    assert(DSBTransientTimeout(false, true) == 10);
    assert(DSBTransientTimeout(true, true) == 10);
    uint64_t frame = DSBTransientFrame(17, 0, 0, 1, 20.0/568);
    assert(DSBTransientGenerationMatches(frame, 17));
    assert(!DSBTransientGenerationMatches(frame, 16));
    assert(!DSBTransientGenerationMatches(0, 17));
    assert(!DSBTransientGenerationMatches(frame, 0));
    assert(!DSBTransientContains(0, .5, .01));
    assert(DSBTransientFrame(0, 0, 0, 1, 1) == 0);
    assert(DSBTransientFrame(17, .5, 0, .5, 1) == 0);
    for (int x = 0; x <= 1000; x++) {
        assert(DSBTransientContains(frame, x/1000.0, .02));
        assert(!DSBTransientContains(frame, x/1000.0, .1));
    }
    // Portrait-aligned host over either landscape orientation, fixed-screen frame.
    uint64_t left = DSBTransientFrame(18, 0, 0, 20.0/320, 1);
    uint64_t right = DSBTransientFrame(19, 1-20.0/320, 0, 1, 1);
    for (int y = 0; y <= 1000; y++) {
        assert(DSBTransientContains(left, .02, y/1000.0));
        assert(!DSBTransientContains(left, .5, y/1000.0));
        assert(DSBTransientContains(right, .98, y/1000.0));
        assert(!DSBTransientContains(right, .5, y/1000.0));
    }
    assert(!DSBTransientGenerationMatches(right, 18)); // late previous-reveal touch
    return 0;
}
