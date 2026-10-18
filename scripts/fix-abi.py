#!/usr/bin/env python3
"""Verify arm64e v2 ABI in staged files; optionally convert Linux old-ABI output.

Never edits Theos or shared toolchains. Conversion is performed before final
Debian packaging, then the modified binary is re-signed and re-checked.
"""
import os
import hashlib
import json
from pathlib import Path
import shutil
import struct
import subprocess
import sys

def needs_conversion(path):
    data = path.read_bytes()
    magic, count = struct.unpack_from(">II", data)
    if magic != 0xCAFEBABE:
        return False
    for i in range(count):
        cpu, sub, offset, size, align = struct.unpack_from(">IIIII", data, 8 + 20 * i)
        inner_sub = struct.unpack_from("<I", data, offset + 8)[0]
        if sub & 0xFFFFFF == 2 and (not sub & 0x80000000 or not inner_sub & 0x80000000):
            return True
    return False

def arm64_hash(path):
    data = path.read_bytes()
    _, count = struct.unpack_from(">II", data)
    for i in range(count):
        cpu, sub, offset, size, align = struct.unpack_from(">IIIII", data, 8 + 20 * i)
        if sub & 0xFFFFFF == 0:
            return hashlib.sha256(data[offset:offset + size]).hexdigest()
    raise AssertionError("Missing arm64 slice")

root = Path(sys.argv[1]).resolve()
paths = [*root.rglob("DroidSB.dylib"), *root.rglob("DroidSBPrefs")]
assert len(paths) == 2, f"Unexpected staged binary count: {paths}"
records = {}
for path in paths:
    if not needs_conversion(path):
        continue
    converter = os.environ.get("DROIDSB_ALLEMANDE") or shutil.which("allemande")
    if not converter:
        sys.exit("Old arm64e ABI detected. Set DROIDSB_ALLEMANDE=/path/to/allemande, or build with an Apple linker supporting the iOS 14+ ABI. Refusing to package an incompatible arm64e slice.")
    original_arm64 = arm64_hash(path)
    log = subprocess.run([converter, str(path)], check=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    assert arm64_hash(path) == original_arm64, "Converter changed the SE's arm64 slice"
    assert b"Wrote out patched file" in log.stdout, log.stdout.decode(errors="replace")
    ldid = os.environ.get("DROIDSB_LDID") or shutil.which("ldid")
    if not ldid:
        ldid = str(Path(os.environ["THEOS"]) / "toolchain/linux/iphone/bin/ldid")
    subprocess.run([ldid, "-S", str(path)], check=True)
    # Allemande fixes pointer encodings but deliberately retains the old header
    # subtype. Do not forge a v2 ABI marker to make a structural check pass.
    records[path.name] = {"strategy": "allemande", "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
                          "converter_sha256": hashlib.sha256(Path(converter).read_bytes()).hexdigest(),
                          "arm64_unchanged_before_resign": True}
    print(f"Converted/re-signed arm64e ABI: {path.name} (arm64 unchanged)")
catalog = root / "Library/Application Support/DroidSB"
(catalog / "build-info.json").write_text(json.dumps({"arm64e_conversion": records}, indent=2) + "\n")
