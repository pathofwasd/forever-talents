#!/usr/bin/env python3
"""Build a reproducible, single-folder WoW addon ZIP and its SHA-256 manifest."""

from pathlib import Path
import hashlib
import json
import re
import shutil
import subprocess
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[1]
ADDON = ROOT / "addon/ForeverTalents"


def main():
    subprocess.run(
        [sys.executable, str(ROOT / "tools/check_package.py"), "--source-only"],
        cwd=ROOT,
        check=True,
    )
    version = re.search(r"^## Version: (.+)$", (ADDON / "ForeverTalents.toc").read_text(), re.M)[
        1
    ].strip()
    dist = ROOT / "dist"
    dist.mkdir(exist_ok=True)
    path = dist / f"ForeverTalents-{version}.zip"
    entries = []
    with zipfile.ZipFile(path, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for source in sorted(ADDON.rglob("*")):
            if not source.is_file():
                continue
            if source.is_symlink():
                raise ValueError(f"Refusing symlink: {source}")
            name = "ForeverTalents/" + source.relative_to(ADDON).as_posix()
            content = source.read_bytes()
            info = zipfile.ZipInfo(name, date_time=(2026, 10, 5, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o100644 << 16
            archive.writestr(info, content, compresslevel=9)
            entries.append(
                dict(path=name, bytes=len(content), sha256=hashlib.sha256(content).hexdigest())
            )
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    share = dist / "ForeverTalents.zip"
    shutil.copyfile(path, share)
    manifest = dict(
        addon="ForeverTalents",
        version=version,
        interface=16001,
        archive=path.name,
        shareArchive=share.name,
        bytes=path.stat().st_size,
        sha256=digest,
        files=entries,
    )
    (dist / "release-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    (dist / f"{path.name}.sha256").write_text(f"{digest}  {path.name}\n")
    (dist / f"{share.name}.sha256").write_text(f"{digest}  {share.name}\n")
    (dist / "INSTALL-AND-UPDATE.txt").write_text(f"""FOREVER TALENTS {version} - INSTALL AND UPDATE

Download: ForeverTalents.zip
No other addons or internet connection are needed to use it.

FIRST INSTALL
1. Close World of Warcraft.
2. Unzip ForeverTalents.zip.
3. Copy the ForeverTalents folder into your WoW Forever client's
   Interface/AddOns folder.
4. Check the layout: Interface/AddOns/ForeverTalents/ForeverTalents.toc
   There should be only one ForeverTalents folder, with no extra nesting.
5. Start the game. Enable Forever Talents in the character-selection
   AddOns menu, then log in and type /ftc.

UPDATING
1. Close World of Warcraft and download the latest ForeverTalents.zip.
2. Move the old Interface/AddOns/ForeverTalents folder somewhere outside
   AddOns as a backup, then unzip/copy the new ForeverTalents folder there.
3. Start the game and type /ftc.

Your builds are saved separately in WoW's WTF folder. Leave that folder
alone when updating; your profiles and checkpoints are kept.

Always use the Forever client folder, not another WoW installation.
The Forever beta client is commonly named _classic_beta_.

SHARING BUILDS
Use Share inside the addon to copy a build string. Your friends can paste
that string into Import. With the addon installed on both sides, Share
also supports addon whispers.
""")
    print(json.dumps({key: value for key, value in manifest.items() if key != "files"}))


if __name__ == "__main__":
    main()
