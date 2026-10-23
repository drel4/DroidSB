#!/usr/bin/env python3
"""Inspect a built Debian payload and Mach-O architecture/ABI metadata (Linux)."""
import json
import hashlib
from pathlib import Path
import plistlib
import struct
import subprocess
import sys
import tempfile

package = Path(sys.argv[1]).resolve()
with tempfile.TemporaryDirectory(prefix="droidsb-verify-") as temp:
    subprocess.run(["dpkg-deb", "-x", str(package), temp], check=True)
    root = Path(temp)
    assert subprocess.check_output(["dpkg-deb", "-f", str(package), "Architecture"], text=True).strip() == "iphoneos-arm64"
    lib = root / "var/jb/Library"
    conversion = json.loads((lib / "Application Support/DroidSB/build-info.json").read_text())["arm64e_conversion"]
    expected = [lib / "MobileSubstrate/DynamicLibraries/DroidSB.dylib",
                lib / "PreferenceBundles/DroidSBPrefs.bundle/DroidSBPrefs"]
    for path in expected:
        data = path.read_bytes()
        magic, count = struct.unpack_from(">II", data)
        assert magic == 0xCAFEBABE and count == 2, f"Not a two-slice universal Mach-O: {path}"
        subtypes = set()
        for i in range(count):
            cpu, sub, offset, size, align = struct.unpack_from(">IIIII", data, 8 + 20 * i)
            assert cpu == 0x100000C, "Not ARM64"
            assert offset + size <= len(data)
            assert struct.unpack_from("<I", data, offset)[0] == 0xFEEDFACF
            subtypes.add(sub & 0xFFFFFF)
            if sub & 0xFFFFFF == 2:
                # arm64e v2 ABI marker (Apple clang >=12), required since iOS 14.
                if path.name in conversion:
                    record = conversion[path.name]
                    assert record["strategy"] == "allemande" and record["arm64_unchanged_before_resign"]
                    assert record["sha256"] == hashlib.sha256(data).hexdigest(), "Converted payload hash mismatch"
                else:
                    assert sub & 0x80000000, "Old/incompatible arm64e ABI without conversion"
                    assert struct.unpack_from("<I", data, offset + 8)[0] & 0x80000000, "Old inner arm64e ABI"
        assert subtypes == {0, 2}, subtypes
        print(f"PASS: {path.relative_to(root)} arm64 + arm64e; conversion provenance verified")
    catalog = lib / "Application Support/DroidSB"
    icons = json.loads((catalog / "icons.json").read_text())
    for name in ("stat_sys_rotate_portrait", "stat_sys_rotate_landscape", "ic_screenrecord", "ic_privacy_camera", "ic_privacy_mic"):
        assert name in icons and icons[name]["paths"], f"Missing new status glyph: {name}"
    for name in ("LICENSE", "NOTICE", "battery-glyphs.json"):
        assert (catalog / name).stat().st_size > 0
    font_manifest = json.loads((Path(__file__).resolve().parents[1] / "reference/fonts.json").read_text())
    for entry in font_manifest["files"]:
        assert hashlib.sha256((catalog / "fonts" / entry["path"]).read_bytes()).hexdigest() == entry["sha256"], "Font/license missing or modified in package"
    with (lib / "PreferenceBundles/DroidSBPrefs.bundle/Root.plist").open("rb") as stream:
        plistlib.load(stream)
    assert not (root / "Library").exists(), "Rootful payload accidentally packaged"
    assert not list(root.rglob("linuxserver.txt")), "Host credentials in package"
    print("PASS: rootless paths, catalogs, preference plist, Google Sans Flex + OFL, licenses; no host config")
