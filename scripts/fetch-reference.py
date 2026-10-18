#!/usr/bin/env python3
"""Fetch the exact Apache-2.0 upstream files used as geometry/design references.

No upstream Java/Kotlin is compiled into the tweak. The commit is deliberately
pinned: updating the port requires reviewing new sources, not a moving branch.
"""
import concurrent.futures
import hashlib
import json
from pathlib import Path
import urllib.request

COMMIT = "7f6de40b6429462d47ba9ba351b99943269c8067"
BASE = f"https://raw.githubusercontent.com/LineageOS/android_frameworks_base/{COMMIT}/"
FILES = [
    "packages/SystemUI/res/layout/status_bar.xml",
    "packages/SystemUI/res/values/dimens.xml",
    "packages/SystemUI/src/com/android/systemui/statusbar/pipeline/battery/ui/composable/UnifiedBattery.kt",
    "packages/SettingsLib/src/com/android/settingslib/graph/SignalDrawable.java",
    "packages/SettingsLib/src/com/android/settingslib/graph/ThemedBatteryDrawable.kt",
    "packages/SystemUI/res/drawable/stat_sys_airplane_mode.xml",
    "packages/SystemUI/res/drawable/stat_sys_alarm.xml",
    *[f"packages/SystemUI/src/com/android/systemui/statusbar/pipeline/battery/shared/ui/{name}.kt"
      for name in ("BatteryFrame", "BatteryColors", "BatteryGlyph")],
    *[f"packages/SettingsLib/res/drawable/ic_wifi_{i}.xml" for i in range(4)],
    "core/res/res/drawable/ic_signal_cellular.xml",
    *[f"core/res/res/drawable/ic_signal_cellular_{i}_4_bar.xml" for i in range(5)],
    *[f"packages/SettingsLib/res/drawable/ic_mobile_{i}_4_bar.xml" for i in range(5)],
    "packages/SystemUI/res/drawable/ic_alarm.xml",
    "packages/SystemUI/res/drawable/ic_statusbar_vpn.xml",
    "packages/SystemUI/res/drawable/ic_location.xml",
    "core/res/res/drawable/ic_qs_dnd.xml",
    "packages/SystemUI/res/drawable/ic_bluetooth_connected.xml",
    "packages/SystemUI/res/drawable/ic_device_lock_on.xml",
]
OUT = Path(__file__).resolve().parents[1] / "reference" / "upstream"

def fetch(path):
    data = urllib.request.urlopen(BASE + path, timeout=60).read()
    dest = OUT / path
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_bytes(data)
    return {"path": path, "sha256": hashlib.sha256(data).hexdigest()}

if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    with concurrent.futures.ThreadPoolExecutor(max_workers=5) as pool:
        records = list(pool.map(fetch, FILES))
    (OUT.parent / "manifest.json").write_text(json.dumps({
        "repository": "https://github.com/LineageOS/android_frameworks_base",
        "commit": COMMIT, "files": records,
    }, indent=2) + "\n", encoding="utf-8", newline="\n")
    print(f"Fetched {len(records)} pinned reference files")
