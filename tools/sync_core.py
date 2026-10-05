#!/usr/bin/env python3
"""Generate both platform copies from canonical Lua; --check rejects drift."""

import argparse
import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MODULES = [
    "Namespace",
    "Model",
    "Codec",
    "Skills",
    "Simulation",
    "Character",
    "Store",
    "Snapshot",
    "Library",
]


def outputs():
    out = {}
    version = json.loads((ROOT / "package.json").read_text())["version"]
    namespace = (ROOT / "core/lua/Namespace.lua").read_text()
    native = (ROOT / "addon/ForeverTalents/ForeverTalents.toc").read_text()
    assert re.search(r'FT.name, FT.version = name, "([^"]+)"', namespace)[1] == version, (
        "Update core Namespace and package.json to the same release version."
    )
    assert re.search(r"^## Version: (.+)$", native, re.MULTILINE)[1].strip() == version, (
        "Addon TOC version differs from the shared/PWA release."
    )
    data_tag = json.loads((ROOT / "docs/data-build.json").read_text())["dataTag"]
    for name in MODULES:
        out[ROOT / "addon/ForeverTalents" / f"{name}.lua"] = (
            ROOT / "core/lua" / f"{name}.lua"
        ).read_bytes()
    sources = ["unpack = table.unpack or unpack\nlocal FT = {}\n"]
    for name in [
        "Namespace",
        "Data",
        "Model",
        "Codec",
        "Skills",
        "Simulation",
        "Character",
        "Store",
        "Snapshot",
        "Library",
    ]:
        path = ROOT / (
            "addon/ForeverTalents/Data.lua" if name == "Data" else f"core/lua/{name}.lua"
        )
        sources.append(
            "do local function module(...)\n"
            + path.read_text()
            + '\nend module("ForeverTalents", FT) end\n'
        )
    sources.append((ROOT / "web/lua/bridge.lua").read_text())
    engine = "\n".join(sources).encode()
    out[ROOT / "web/public/generated/engine.lua"] = engine
    digest = hashlib.sha256(engine).hexdigest()
    out[ROOT / "web/public/generated" / f"engine-{digest[:16]}.lua"] = engine
    out[ROOT / "web/public/generated/release.json"] = (
        json.dumps(
            {"version": version, "dataTag": data_tag, "engineSha256": digest, "modules": MODULES},
            indent=2,
        )
        + "\n"
    ).encode()
    for path in (ROOT / "data/icons/medium").glob("*.jpg"):
        out[ROOT / "web/public/generated/icons" / path.name] = path.read_bytes()
    runtime = ROOT / "node_modules/wasmoon/dist/glue.wasm"
    if runtime.exists():
        out[ROOT / "web/public/runtime/glue.wasm"] = runtime.read_bytes()
    for name in ["NOTICE", "LICENSE"]:
        out[ROOT / "addon/ForeverTalents" / f"{name}.txt"] = (ROOT / f"{name}.txt").read_bytes()
        out[ROOT / "web/public" / f"{name}.txt"] = (ROOT / f"{name}.txt").read_bytes()
    return out


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    expected = outputs()
    stale = []
    if not args.check:
        for old in (ROOT / "web/public/generated").glob("engine-*.lua"):
            if old not in expected:
                old.unlink()
    for path, data in expected.items():
        if not path.is_file() or path.read_bytes() != data:
            if args.check:
                stale.append(str(path.relative_to(ROOT)))
            else:
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(data)
    if stale:
        raise SystemExit("Generated files are stale; run the shared sync:\n" + "\n".join(stale))
    print(
        ("Checked" if args.check else "Generated")
        + f" shared platform outputs: {len(expected)} files."
    )


if __name__ == "__main__":
    main()
