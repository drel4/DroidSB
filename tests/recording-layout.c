// SPDX-License-Identifier: Apache-2.0
#include "DSBRecordingLayout.h"
#include <assert.h>

int main(void) {
    DSBRecordingLayout layout = DSBLayoutRecording(120, 40, 60, 26);
    assert(layout.clockWidth == 40 && layout.chipWidth == 60);
    layout = DSBLayoutRecording(100, 40, 60, 26);
    assert(layout.clockWidth == 40 && layout.chipWidth == 26);
    layout = DSBLayoutRecording(71, 40, 60, 26);
    assert(layout.clockWidth == 40 && layout.chipWidth == 26);
    layout = DSBLayoutRecording(105, 40, 60, 26);
    assert(layout.clockWidth == 40 && layout.chipWidth == 60);
    layout = DSBLayoutRecording(20, 40, 60, 26);
    assert(layout.clockWidth == 0 && layout.chipWidth == 20);
    layout = DSBLayoutRecording(-1, 40, 60, 26);
    assert(layout.clockWidth == 0 && layout.chipWidth == 0);
    layout = DSBLayoutRecording(60, 0, 60, 26);
    assert(layout.clockWidth == 0 && layout.chipWidth == 60);
    // Preserve the clock whenever a compact chip fits; never overlap the
    // right-hand system icons, including at extreme and boundary widths.
    for (int width = 0; width <= 320; width++) {
        layout = DSBLayoutRecording(width, 40, 60, 26);
        double gap = layout.clockWidth > 0 ? 5 : 0;
        assert(layout.clockWidth >= 0 && layout.chipWidth >= 0);
        assert(layout.clockWidth + gap + layout.chipWidth <= width);
        if (width >= 71) assert(layout.clockWidth == 40);
        if (width >= 71 && width < 105) assert(layout.chipWidth == 26);
        if (width >= 105) assert(layout.chipWidth == 60);
    }
    return 0;
}
