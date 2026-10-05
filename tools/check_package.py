#!/usr/bin/env python3
"""Validate TOC inputs, native icon formats, Lua syntax and the built archive."""

from pathlib import Path, PurePosixPath
import argparse
import hashlib
import json
import re
import shutil
import struct
import subprocess
import xml.etree.ElementTree as ET
import zipfile

ROOT = Path(__file__).resolve().parents[1]
ADDON = ROOT / "addon/ForeverTalents"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-only", action="store_true")
    args = parser.parse_args()
    toc = (ADDON / "ForeverTalents.toc").read_text()
    assert "## Interface: 16001" in toc
    assert "## SavedVariables: ForeverTalentsDB" in toc
    inputs = [
        line.strip().replace("\\", "/")
        for line in toc.splitlines()
        if line.strip() and not line.startswith("#")
    ]
    assert len(inputs) == len(set(inputs))
    # WoW discovers this file with its binding loader, not the TOC UI XML loader.
    assert not any(PurePosixPath(name).name.lower() == "bindings.xml" for name in inputs), (
        "Bindings.xml must not be listed in the TOC"
    )
    bindings = ET.parse(ADDON / "Bindings.xml").getroot()
    assert bindings.tag == "Bindings" and len(bindings) > 0
    binding_names = []
    for binding in bindings:
        assert binding.tag == "Binding" and binding.get("name") and (binding.text or "").strip()
        binding_names.append(binding.get("name"))
    assert len(binding_names) == len(set(binding_names)), "Duplicate key binding names"
    compiler = shutil.which("luac5.1") or shutil.which("luac")
    assert compiler, "Lua 5.1 syntax compiler is required"
    runtime = subprocess.run([compiler, "-v"], capture_output=True, text=True, check=True)
    assert "Lua 5.1" in runtime.stdout + runtime.stderr, (
        "Use a Lua 5.1 compiler for the target WoW client"
    )
    for name in inputs:
        assert (ADDON / name).is_file(), f"Missing TOC input {name}"
        if name.endswith(".lua"):
            subprocess.run([compiler, "-p", str(ADDON / name)], check=True)
        elif name.endswith(".xml"):
            ET.parse(ADDON / name)
    icons = json.loads((ROOT / "data/icons.json").read_text())["icons"]
    for path in ADDON.rglob("*.tga"):
        raw = path.read_bytes()
        ident, colormap, kind = raw[:3]
        width, height, bits = struct.unpack_from("<HHB", raw, 12)
        assert colormap == 0 and kind == 2 and bits == 24, f"Unsupported TGA format {path}"
        assert width & (width - 1) == 0 and height & (height - 1) == 0, f"Texture dimensions {path}"
        assert len(raw) >= 18 + ident + width * height * 3, f"Truncated texture {path}"
        if path.parent.name == "Icons":
            assert width == 64 and height == 64
    bundled = {p.stem for p in (ADDON / "Media/Icons").glob("*.tga")}
    assert bundled == set(icons), "Bundled icons differ from the local icon manifest"
    data = json.loads((ROOT / "docs/data-build.json").read_text())
    assert data["dataSha256"] == hashlib.sha256((ADDON / "Data.lua").read_bytes()).hexdigest()
    for name in ["README.txt", "LICENSE.txt", "NOTICE.txt"]:
        assert (ADDON / name).is_file()
    count = len([p for p in ADDON.rglob("*") if p.is_file()])
    if args.source_only:
        print(
            f"Source package valid: {len(inputs)} TOC inputs, {len(bundled)} icons, {count} files; Lua syntax passed."
        )
        return
    manifest = json.loads((ROOT / "dist/release-manifest.json").read_text())
    path = ROOT / "dist" / manifest["archive"]
    assert hashlib.sha256(path.read_bytes()).hexdigest() == manifest["sha256"]
    if "shareArchive" in manifest:
        assert manifest["shareArchive"] == "ForeverTalents.zip"
        assert (ROOT / "dist" / manifest["shareArchive"]).read_bytes() == path.read_bytes(), (
            "Share ZIP differs from the versioned release"
        )
    expected = {f["path"]: f for f in manifest["files"]}
    with zipfile.ZipFile(path) as archive:
        assert archive.testzip() is None
        assert len(archive.namelist()) == count == len(set(archive.namelist()))
        assert set(archive.namelist()) == set(expected)
        for name in archive.namelist():
            parts = PurePosixPath(name).parts
            assert (
                not PurePosixPath(name).is_absolute()
                and parts[0] == "ForeverTalents"
                and ".." not in parts
            )
            raw = archive.read(name)
            assert raw == (ROOT / "addon" / name).read_bytes(), f"Archive is stale: {name}"
            assert (
                len(raw) == expected[name]["bytes"]
                and hashlib.sha256(raw).hexdigest() == expected[name]["sha256"]
            )
    version = re.search(r"^## Version: (.+)$", toc, re.M)[1].strip()
    assert manifest["version"] == version and manifest["interface"] == 16001
    print(
        f"Release package valid: {path.name}, {count} files, {path.stat().st_size:,} bytes; all entries match source."
    )


if __name__ == "__main__":
    main()
