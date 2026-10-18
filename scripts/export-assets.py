#!/usr/bin/env python3
"""Generate the small runtime asset catalog from vendored Apache-2.0 sources."""
import json
import re
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "reference/upstream"
OUT = ROOT / "layout/Library/Application Support/DroidSB"
A = "{http://schemas.android.com/apk/res/android}"
assets = {}
paths = list((SRC / "packages/SettingsLib/res/drawable").glob("ic_*.xml"))
paths += [SRC / f"packages/SystemUI/res/drawable/{n}.xml" for n in
          ("stat_sys_airplane_mode", "ic_alarm", "stat_sys_vpn_ic", "ic_location",
           "ic_bluetooth_connected", "ic_device_lock_on")]
paths += [SRC / f"packages/SystemUI/res/drawable/{n}.xml" for n in
          ("stat_sys_rotate_portrait", "stat_sys_rotate_landscape", "ic_screenrecord")]
paths += [SRC / "core/res/res/drawable/ic_qs_dnd.xml"]
for path in sorted(paths):
    root = ET.parse(path).getroot()
    if root.tag == "inset":
        # Rotation-lock wrappers add horizontal spacing around an inline
        # vector. The iOS row already provides gaps; preserve vector geometry.
        root = root.find("vector")
        assert root is not None, path
    assert root.tag == "vector", path
    # Fail on unsupported geometry instead of silently producing the wrong icon.
    def nodes(element):
        result = []
        for el in element:
            assert el.tag in ("path", "group", "clip-path"), (path, el.tag)
            if el.tag == "group":
                result.append({"group": nodes(el), "transform": {
                    k: float(el.get(A + k, default)) for k, default in
                    (("translateX", "0"), ("translateY", "0"), ("scaleX", "1"),
                     ("scaleY", "1"), ("pivotX", "0"), ("pivotY", "0"), ("rotation", "0"))}})
            elif el.tag == "clip-path":
                result.append({"clip": el.attrib[A + "pathData"]})
            else:
                result.append({"d": el.attrib[A + "pathData"],
                               "alpha": float(el.get(A + "fillAlpha", "1")),
                               "evenOdd": el.get(A + "fillType") == "evenOdd"})
        return result
    assets[path.stem] = {
        "w": float(root.attrib[A + "viewportWidth"]),
        "h": float(root.attrib[A + "viewportHeight"]),
        "paths": nodes(root),
    }
glyph_source = (SRC / "packages/SystemUI/src/com/android/systemui/statusbar/pipeline/battery/shared/ui/BatteryGlyph.kt").read_text()
glyphs = {}
for name, block in re.findall(r"data object (\w+) : BatteryGlyph \{(.*?)(?=\n    data object|\n\})", glyph_source, re.S):
    path = re.search(r'addSvg\(\s*"([^"]+)"', block)
    w = re.search(r"override val width: Float = ([\d.]+)f", block)
    h = re.search(r"override val height: Float = ([\d.]+)f", block)
    if path and w and h:
        glyphs[name] = {"d": path[1], "w": float(w[1]), "h": float(h[1])}
assert all(n in glyphs for n in ("Bolt", "Plus", "Zero", "Nine"))
OUT.mkdir(parents=True, exist_ok=True)
(OUT / "icons.json").write_text(json.dumps(assets, indent=2) + "\n", encoding="utf-8", newline="\n")
(OUT / "battery-glyphs.json").write_text(json.dumps(glyphs, indent=2) + "\n", encoding="utf-8", newline="\n")
print(f"Exported {len(assets)} icons and {len(glyphs)} battery glyphs")
