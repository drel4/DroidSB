// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 drel4. Keep the clock while collapsing the chip to its icon.
#pragma once

typedef struct {
    double clockWidth;
    double chipWidth;
} DSBRecordingLayout;

static inline DSBRecordingLayout DSBLayoutRecording(double room, double clock, double full, double compact) {
    if (room < 0) room = 0;
    if (clock < 0) clock = 0;
    double gap = clock > 0 ? 5 : 0;
    // Android hides chip text if it cannot fit; do not consume the normal
    // clock's width just to retain recording timer text.
    double chip = room >= clock + gap + full ? full : compact;
    if (chip > room) chip = room;
    double remaining = room - chip - gap;
    if (remaining < 0) remaining = 0;
    if (clock > remaining) clock = remaining;
    return (DSBRecordingLayout){clock, chip};
}
