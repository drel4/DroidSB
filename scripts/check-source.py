#!/usr/bin/env python3
"""Validate real asset provenance, regenerated catalogs and install plists."""
import hashlib
import json
from pathlib import Path
import plistlib
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
manifest = json.loads((ROOT / "reference/manifest.json").read_text())
for entry in manifest["files"]:
    data = (ROOT / "reference/upstream" / entry["path"]).read_bytes()
    assert hashlib.sha256(data).hexdigest() == entry["sha256"], entry["path"]
assets = ROOT / "layout/Library/Application Support/DroidSB"
before = {p.name: p.read_bytes() for p in assets.glob("*.json")}
subprocess.run([sys.executable, str(ROOT / "scripts/export-assets.py")], check=True)
assert before == {p.name: p.read_bytes() for p in assets.glob("*.json")}, "Generated catalogs are stale"
icons = json.loads((assets / "icons.json").read_text())
for name in [*[f"ic_wifi_{i}" for i in range(4)], *[f"ic_mobile_{i}_4_bar" for i in range(5)],
             "ic_alarm", "stat_sys_airplane_mode", "ic_qs_dnd", "ic_location", "ic_statusbar_vpn"]:
    assert name in icons and icons[name]["w"] > 0 and icons[name]["h"] > 0, name
glyphs = json.loads((assets / "battery-glyphs.json").read_text())
for name in ("Zero", "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine", "Plus", "Bolt", "Question"):
    assert glyphs[name]["w"] > 0 and glyphs[name]["h"] > 0 and glyphs[name]["d"], name
for path in [*ROOT.glob("Prefs/Resources/*.plist"), *ROOT.glob("layout/Library/PreferenceLoader/Preferences/*.plist")]:
    with path.open("rb") as stream:
        plistlib.load(stream)
for name in ("LICENSE", "NOTICE"):
    assert (ROOT / name).read_bytes() == (assets / name).read_bytes(), f"Bundled {name} is stale"
print(f"PASS: {len(manifest['files'])} upstream hashes, reproducible assets, battery glyphs, plists, bundled licenses")
