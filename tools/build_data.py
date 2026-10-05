#!/usr/bin/env python3
"""Compile the canonical catalog and local images into offline addon assets."""

import hashlib
import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "addon/ForeverTalents"


def numeric_keys(value):
    """JSON object keys are strings; restore numeric Lua lookup tables."""
    if isinstance(value, list):
        return [numeric_keys(item) for item in value]
    if isinstance(value, dict):
        return {
            int(key) if key.removeprefix("-").isdigit() else key: numeric_keys(item)
            for key, item in value.items()
        }
    return value


def lua(value):
    if value is None:
        return "nil"
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float)):
        return str(value)
    if isinstance(value, str):
        escaped = value.replace("\\", "\\\\").replace('"', '\\"')
        escaped = escaped.replace("\n", "\\n").replace("\t", "\\t").replace("\r", "\\r")
        return '"' + escaped + '"'
    if isinstance(value, list):
        return "{" + ",".join(lua(item) for item in value) + "}"
    return "{" + ",".join("[" + lua(key) + "]=" + lua(item) for key, item in value.items()) + "}"


def compatibility_tag(classes):
    """Retain the established wire-format identity, including prerequisite order."""
    identity = [
        (
            class_id,
            cls["races"],
            [
                (
                    tree["id"],
                    [
                        (
                            talent["id"],
                            talent["max"],
                            talent["gate"],
                            [
                                {"id": rule["id"], "points": rule["points"], "name": rule["name"]}
                                for rule in talent["requires"]
                            ],
                        )
                        for talent in tree["talents"]
                    ],
                )
                for tree in cls["trees"]
            ],
        )
        for class_id, cls in sorted(classes.items())
    ]
    encoded = json.dumps(identity, separators=(",", ":")).encode()
    return hashlib.sha256(encoded).hexdigest()[:8]


def validate(data, icons):
    meta = data["meta"]
    assert (meta["firstLevel"], meta["maxLevel"], meta["maxPoints"], meta["rowPoints"]) == (
        10,
        60,
        51,
        5,
    ), "Changed talent rules require an engine review."
    assert len(data["classes"]) == 9 and len(data["races"]) == 10
    for class_id, cls in data["classes"].items():
        assert cls["id"] == class_id and len(cls["trees"]) == 3
        assert all(race in data["races"] for race in cls["races"])
        index = 0
        for tree in cls["trees"]:
            talents = {talent["id"]: talent for talent in tree["talents"]}
            assert len(talents) == len(tree["talents"]), "Duplicate talent ID"
            positions = set()
            for talent in tree["talents"]:
                index += 1
                assert talent["index"] == index, "Changing talent order breaks saved builds."
                position = (talent["row"], talent["col"])
                assert position not in positions, "Duplicate grid position"
                positions.add(position)
                assert 0 <= talent["row"] <= 6 and 0 <= talent["col"] < tree["columns"]
                assert talent["gate"] == talent["row"] * meta["rowPoints"]
                assert 1 <= talent["max"] <= 5 and len(talent["ranks"]) == talent["max"]
                assert talent["icon"] in icons
                for rule in talent["requires"]:
                    parent = talents[rule["id"]]
                    assert 1 <= rule["points"] <= parent["max"]
                    assert parent["id"] != talent["id"] and parent["row"] <= talent["row"]
    assert compatibility_tag(data["classes"]) == meta["tag"], (
        "Talent compatibility changed; review the data tag and sharing migration."
    )
    for icon in icons:
        assert icon and all(char.isalnum() or char == "_" for char in icon)
        for size in ("medium", "large"):
            assert (ROOT / "data/icons" / size / f"{icon}.jpg").is_file()


def build_icons(icons):
    media = OUT / "Media/Icons"
    media.mkdir(parents=True, exist_ok=True)
    for icon in sorted(icons):
        with Image.open(ROOT / "data/icons/large" / f"{icon}.jpg") as image:
            image.convert("RGB").resize((64, 64), Image.Resampling.LANCZOS).save(
                media / f"{icon}.tga", compression=None
            )
    for name, color in [("Tree1", (25, 51, 50)), ("Tree2", (46, 36, 54)), ("Tree3", (39, 47, 37))]:
        image = Image.new("RGB", (64, 256))
        image.putdata(
            [
                tuple(
                    int(component * (0.35 + 0.65 * (1 - y / 256)) + ((x * 17 + y * 31) % 7))
                    for component in color
                )
                for y in range(256)
                for x in range(64)
            ]
        )
        image.save(OUT / "Media" / f"{name}.tga")


def main():
    data = numeric_keys(json.loads((ROOT / "data/catalog.json").read_text()))
    icons = json.loads((ROOT / "data/icons.json").read_text())["icons"]
    validate(data, icons)
    target = OUT / "Data.lua"
    target.write_text(
        "-- Generated by tools/build_data.py; edit data/catalog.json, then rebuild.\n"
        "local _, FT = ...\nFT.Data = " + lua(data) + "\n",
        encoding="utf-8",
    )
    build_icons(icons)
    classes = data["classes"].values()
    manifest = dict(
        schema=1,
        dataTag=data["meta"]["tag"],
        classes=len(data["classes"]),
        trees=sum(len(cls["trees"]) for cls in classes),
        talents=sum(len(tree["talents"]) for cls in classes for tree in cls["trees"]),
        skillRanks=sum(len(skill["ranks"]) for cls in classes for skill in cls["skills"]),
        icons=len(icons),
        dataSha256=hashlib.sha256(target.read_bytes()).hexdigest(),
    )
    (ROOT / "docs/data-build.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(json.dumps(manifest))


if __name__ == "__main__":
    main()
