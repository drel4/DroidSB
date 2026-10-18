// SPDX-License-Identifier: Apache-2.0
#include "DSBStatusPolicy.h"
#include <assert.h>

static bool stock(const char *const *active, size_t count, bool recording) {
    for (size_t i = 0; i < count; i++) if (DSBEntryRequiresNative(active[i], recording)) return true;
    return false;
}

int main(void) {
    const char *ordinary[] = {"timeEntry", "mainBatteryEntry", "wifiEntry", "rotationLockEntry", "bluetoothEntry", "backNavigationEntry"};
    // Persistent rotation lock, AirPods and cross-app navigation survive every
    // refresh/respring; none is a reason to restore the complete stock bar.
    for (int i = 0; i < 100; i++) assert(!stock(ordinary, sizeof ordinary / sizeof ordinary[0], false));
    const char *activity[] = {"timeEntry", "rotationLockEntry", "backgroundActivityEntry"};
    assert(!stock(activity, 3, true));  // positively identified screen recording
    assert(stock(activity, 3, false));  // call/mirroring/unclassified activity
    const char *privacy[] = {"backgroundActivityEntry", "sensorActivityEntry"};
    assert(stock(privacy, 2, true)); // recording must not suppress camera/mic dots
    assert(DSBEntryRequiresNative("secondaryCellularEntry", true));
    assert(DSBEntryRequiresNative("futureUnknownEntry", false));
    assert(DSBEntryRequiresNative(NULL, false));
    return 0;
}
