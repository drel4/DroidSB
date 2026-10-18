// SPDX-License-Identifier: Apache-2.0
#include "DSBRecordingState.h"
#include <assert.h>

int main(void) {
    DSBRecordingEvidence state = {0};
    // Mirroring/capture alone must never create a recording indicator.
    assert(!DSBUpdateRecordingEvidence(&state, true, false, false, true, 42));
    assert(!DSBUpdateRecordingEvidence(&state, true, false, true, false, 42));
    // Confirm a red recording, then open the native Stop/Cancel popup. Its
    // enabled activity remains the same even when capture and items drop out.
    assert(DSBUpdateRecordingEvidence(&state, true, false, true, true, 42));
    assert(DSBUpdateRecordingEvidence(&state, true, false, true, false, 42));
    assert(DSBUpdateRecordingEvidence(&state, true, false, false, false, 42));
    // Cancel/continue: no false stop/start transition or lost evidence.
    assert(DSBUpdateRecordingEvidence(&state, true, false, true, true, 42));
    // Actual stop clears evidence even if capture has not updated yet.
    assert(!DSBUpdateRecordingEvidence(&state, false, true, true, true, 42));
    assert(!state.confirmed);
    assert(!DSBUpdateRecordingEvidence(&state, true, false, false, true, 42));
    // A named recording activity is authoritative even during a capture pause
    // or view recreation; changing to another native activity clears it.
    assert(DSBUpdateRecordingEvidence(&state, true, true, false, false, 17));
    assert(!DSBUpdateRecordingEvidence(&state, true, false, false, false, 18));
    assert(!DSBUpdateRecordingEvidence(&state, true, false, false, true, 17));
    // Fresh recording after stop must be independently confirmed.
    assert(DSBUpdateRecordingEvidence(&state, true, false, true, true, 21));
    assert(!DSBUpdateRecordingEvidence(&state, false, false, false, false, 21));
    assert(!DSBUpdateRecordingEvidence(&state, true, false, true, false, 21));
    return 0;
}
