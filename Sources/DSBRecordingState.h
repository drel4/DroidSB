// SPDX-License-Identifier: Apache-2.0
#pragma once
#include <stdbool.h>
#include <stdint.h>

typedef struct {
    bool confirmed;
    int64_t type;
} DSBRecordingEvidence;

static inline bool DSBUpdateRecordingEvidence(DSBRecordingEvidence *state,
    bool enabled, bool recordingSymbol, bool redActivity, bool captured, int64_t type) {
    // A named native recording activity is authoritative. Red-only fallback
    // initially requires capture, but a confirmed SAME enabled native activity
    // survives a temporary capture drop (e.g. the native Stop/Cancel popup).
    bool same = state->confirmed && state->type == type;
    bool active = enabled && (recordingSymbol || (redActivity && captured) || same);
    *state = active ? (DSBRecordingEvidence){true, type} : (DSBRecordingEvidence){false, 0};
    return active;
}
