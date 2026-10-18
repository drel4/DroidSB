// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 drel4. UIKit-independent fallback policy, also used by tests.
#pragma once
#include <stdbool.h>
#include <stddef.h>
#include <string.h>

static inline bool DSBEntryRequiresNative(const char *key, bool screenRecording) {
    if (!key) return true;
    if (strcmp(key, "backgroundActivityEntry") == 0) return !screenRecording;
    const char *handled[] = {
        "timeEntry", "shortTimeEntry", "dateEntry", "mainBatteryEntry",
        "cellularEntry", "wifiEntry", "airplaneModeEntry", "alarmEntry", "quietModeEntry",
        "deviceNameEntry", "personNameEntry", "vpnEntry", "locationEntry", "bluetoothEntry",
        "lockEntry", "rotationLockEntry", "backNavigationEntry", "forwardNavigationEntry",
    };
    for (size_t i = 0; i < sizeof(handled) / sizeof(handled[0]); i++) {
        if (strcmp(key, handled[i]) == 0) return false;
    }
    return true;
}
