#!/usr/bin/env python3
"""Normalize a reviewed client CSV snapshot into the canonical simulator catalog.

Usage: python3 tools/import_simulation_data.py /path/to/csvs --build 1.60.1.70009
CSV acquisition is separate; regular builds never access the network.
"""

import argparse
import collections
import csv
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCHOOLS = {
    1: "Physical",
    2: "Holy",
    4: "Fire",
    8: "Nature",
    16: "Frost",
    32: "Shadow",
    64: "Arcane",
}
PATCH = "https://us.forums.blizzard.com/en/wow/t/wow-forever-beta-development-notes-%E2%80%93-updated-october-1/2360696"


def compile_spells(directory, build, catalog):
    def table(name):
        return list(csv.DictReader((directory / f"{name}.csv").open()))

    effects = collections.defaultdict(list)
    for row in table("SpellEffect"):
        if int(row["DifficultyID"]) == 0:
            effects[int(row["SpellID"])].append(row)
    misc = {int(r["SpellID"]): r for r in table("SpellMisc") if int(r["DifficultyID"]) == 0}
    categories = {
        int(r["SpellID"]): r for r in table("SpellCategories") if int(r["DifficultyID"]) == 0
    }
    levels = {int(r["SpellID"]): r for r in table("SpellLevels") if int(r["DifficultyID"]) == 0}
    durations = {int(r["ID"]): r for r in table("SpellDuration")}
    casts = {int(r["ID"]): int(r["Base"]) / 1000 for r in table("SpellCastTimes")}
    roots = {}
    for cls in catalog["classes"].values():
        skills = {skill["name"]: skill for skill in cls["skills"]}
        for skill in cls["skills"]:
            for rank in skill["ranks"]:
                roots[rank["spellID"]] = (cls["id"], skill["name"], skill["icon"])
        for tree in cls["trees"]:
            for talent in tree["talents"]:
                if talent["max"] == 1 and talent["name"] in skills:
                    roots.setdefault(
                        talent["ranks"][0]["spellID"],
                        (cls["id"], talent["name"], talent["icon"]),
                    )
    for cid, races in catalog["racials"].items():
        for racials in races.values():
            for skill in racials:
                roots.setdefault(skill["spellID"], (int(cid), skill["name"], skill["icon"]))

    def value(row, key):
        return round(float(row.get(key) or 0), 6)

    spells = {}
    for sid, (cid, name, icon) in roots.items():
        m = misc.get(sid, {})
        duration_row = durations.get(int(m.get("DurationIndex", 0)), {})
        duration = int(duration_row.get("Duration", 0)) / 1000
        school = SCHOOLS.get(int(m.get("SchoolMask", 0)), "Physical")
        can_crit = not (int(m.get("Attributes_2", 0)) & 0x20000000)
        defense = int(categories.get(sid, {}).get("DefenseType", 0))
        attack = {2: "melee", 3: "ranged"}.get(defense, "spell")
        components, notes = [], []
        rows = sorted(effects.get(sid, []), key=lambda r: int(r["EffectIndex"]))
        weapon_rows = [r for r in rows if int(r["Effect"]) in [17, 31, 58, 121]]
        if weapon_rows:
            percent = next(
                (
                    value(r, "EffectBasePointsF") / 100
                    for r in weapon_rows
                    if int(r["Effect"]) == 31
                ),
                1,
            )
            flat = sum(value(r, "EffectBasePointsF") for r in weapon_rows if int(r["Effect"]) != 31)
            components.append(
                {
                    "kind": "damage",
                    "part": "direct",
                    "low": flat,
                    "high": flat,
                    "sp": 0,
                    "ap": 0,
                    "weapon": percent,
                    "crit": can_crit,
                    "scalingKnown": True,
                    "normalized": any(int(r["Effect"]) == 121 for r in weapon_rows),
                    "sourceSpell": sid,
                }
            )
            if any(int(r["Effect"]) == 121 for r in weapon_rows):
                notes.append(
                    "Normalized weapon strikes require weapon speed and type. Without them, the entered normal hit is an approximation."
                )

        def append(
            row,
            source_sid,
            force_ticks=None,
            parent_period=None,
            notes=notes,
            duration=duration,
            school=school,
            m=m,
            can_crit=can_crit,
            components=components,
        ):
            effect, aura = int(row["Effect"]), int(row["EffectAura"])
            if effect in [17, 31, 58, 121]:
                return
            part, kind = "direct", None
            if effect == 2:
                kind = "damage"
            elif effect == 10:
                kind = "healing"
            elif effect in [6, 35] and aura in [3, 8, 53]:
                kind = "healing" if aura == 8 else "damage"
                part = "periodic"
                if aura == 53:
                    notes.append(
                        "Damage is modeled; the linked health transfer is not a separate healing result."
                    )
            elif effect in [6, 35] and aura == 69:
                kind = "absorption"
            if not kind:
                return
            period = parent_period or value(row, "EffectAuraPeriod") / 1000
            ticks = force_ticks or (int(duration / period) if period and duration > 0 else 0)
            if force_ticks:
                part = "periodic"
            if part == "periodic" and not ticks:
                notes.append("The periodic tick count is unavailable; this component is omitted.")
                return
            base, var = value(row, "EffectBasePointsF"), value(row, "Variance")
            sp = value(row, "EffectBonusCoefficient")
            if school == "Physical" and sp == 1:
                sp = 0  # This is a client sentinel on physical/scripted effects.
            ap = value(row, "BonusCoefficientFromAP")
            child = misc.get(source_sid, m)
            eligible = (
                bool(int(child.get("Attributes_8", 0)) & 0x200) if part == "periodic" else can_crit
            )
            # A periodic trigger fires direct impacts, which use the child spell's crit rule.
            if force_ticks:
                eligible = not (int(child.get("Attributes_2", 0)) & 0x20000000)
            self_damage = (
                kind == "damage"
                and int(row["ImplicitTarget_0"]) == 1
                and int(row["ImplicitTarget_1"]) == 0
            )
            components.append(
                {
                    "kind": kind,
                    "part": part,
                    "low": round(base * (1 - var / 2), 6),
                    "high": round(base * (1 + var / 2), 6),
                    "sp": sp,
                    "ap": ap,
                    "weapon": 0,
                    "crit": eligible if kind != "absorption" and not self_damage else False,
                    "ticks": ticks or 1,
                    "interval": period,
                    "growth": value(row, "EffectRealPointsPerLevel"),
                    "combo": value(row, "EffectPointsPerResource"),
                    "scalingKnown": bool(sp or ap or school == "Physical" or self_damage),
                    "selfDamage": self_damage,
                    "sourceSpell": source_sid,
                }
            )

        for row in rows:
            append(row, sid)
            if int(row["EffectAura"]) == 23 and int(row["EffectTriggerSpell"]) and duration > 0:
                period = value(row, "EffectAuraPeriod") / 1000
                child = int(row["EffectTriggerSpell"])
                if period:
                    for child_row in effects.get(child, []):
                        append(child_row, child, int(duration / period), period)
        if name == "Bloodthirst":
            flat = next((value(r, "EffectBasePointsF") for r in rows if int(r["Effect"]) == 2), 0)
            components = [
                {
                    "kind": "damage",
                    "part": "direct",
                    "low": flat,
                    "high": flat,
                    "sp": 0,
                    "ap": 0.45,
                    "weapon": 0,
                    "crit": True,
                    "scalingKnown": True,
                    "sourceSpell": sid,
                }
            ]
            notes.append(
                "Attack Power ratio corrected to 45% by the October 1 developer notes, overriding the older client effect."
            )
        if name == "Swipe" and components:
            components[0]["ap"] = 0.03
            notes.append(
                "Includes the 3% Attack Power fix from the October 1 developer notes, ahead of the tooltip."
            )
        if name == "Execute":
            base = next(
                (value(r, "EffectBasePointsF") for r in rows if int(r["Effect"]) == 3), None
            )
            rank_text = next(
                (
                    r["text"]
                    for cls in catalog["classes"].values()
                    for sk in cls["skills"]
                    if sk["name"] == name
                    for r in sk["ranks"]
                    if r["spellID"] == sid
                ),
                "",
            )
            import re

            rage = re.search(r"rage into ([\d.]+) additional damage", rank_text)
            if base is not None and rage:
                components = [
                    {
                        "kind": "damage",
                        "part": "direct",
                        "low": base,
                        "high": base,
                        "sp": 0,
                        "ap": 0,
                        "weapon": 0,
                        "rage": float(rage[1]),
                        "crit": can_crit,
                        "scalingKnown": True,
                        "sourceSpell": sid,
                    }
                ]
                notes.append(
                    "Extra Rage means Rage consumed beyond the cast cost. Target must be at or below 20% health."
                )
        if not components:
            if name == "Auto Shot":
                components = [
                    {
                        "kind": "damage",
                        "part": "direct",
                        "low": 0,
                        "high": 0,
                        "sp": 0,
                        "ap": 0,
                        "weapon": 1,
                        "crit": True,
                        "scalingKnown": True,
                        "sourceSpell": sid,
                    }
                ]
            else:
                continue
        if name in ["Eviscerate", "Ferocious Bite", "Garrote", "Rupture"]:
            notes.append(
                "The client effect rows do not expose every scripted Attack Power/resource interaction for this finisher or bleed. The result is partial."
            )
        if name in ["Whirlwind", "Mutilate"]:
            notes.append(
                "This result includes the main-hand effect only. Off-hand damage is not modeled."
            )
        if name == "Holy Nova":
            notes.append(
                "This result covers damage; the linked party healing effect is not modeled."
            )
        if name == "Summon Hawk":
            notes.append(
                "Initial captured hit only. Summoned hawk attacks and scripted Attack Power/talent scaling are not modeled."
            )
        if name in ["Serpent Sting", "Arcane Shot", "Consecration"]:
            for comp in components:
                if comp["sp"] == 0:
                    comp["scalingKnown"] = False
            notes.append(
                "The captured effect has no spell-power coefficient. This does not prove that server-side scaling is zero; use an explicit override if measured."
            )
        lv = levels.get(sid, {})
        channel = bool(int(m.get("Attributes_1", 0)) & (0x4 | 0x40))
        spells[str(sid)] = {
            "school": school,
            "attack": attack,
            "level": int(lv.get("SpellLevel") or lv.get("BaseLevel") or 1),
            "maxLevel": int(lv.get("MaxLevel", 0)),
            "duration": duration,
            "durationPerCombo": int(duration_row.get("DurationPerResource", 0)) / 1000,
            "cast": casts.get(int(m.get("CastingTimeIndex", 0)), 0),
            "channel": channel,
            "components": components,
            "notes": list(dict.fromkeys(notes)),
        }
    stats_crit = {}
    for cls in catalog["classes"].values():
        for tree in cls["trees"]:
            for talent in tree["talents"]:
                stats_crit[str(talent["id"])] = [
                    any(
                        int(r["EffectAura"]) in [52, 57, 71, 290]
                        for r in effects.get(rank["spellID"], [])
                    )
                    for rank in talent["ranks"]
                ]
    return spells, stats_crit


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path)
    parser.add_argument("--build", required=True)
    args = parser.parse_args()
    path = ROOT / "data/catalog.json"
    catalog = json.loads(path.read_text())
    sources = []
    for name in [
        "SpellEffect",
        "SpellMisc",
        "SpellLevels",
        "SpellDuration",
        "SpellCastTimes",
        "SpellCategories",
    ]:
        sources.append(
            {
                "table": name,
                "url": f"https://wago.tools/db2/{name}/csv?build={args.build}",
                "sha256": hashlib.sha256((args.directory / f"{name}.csv").read_bytes()).hexdigest(),
            }
        )
    previous = catalog.get("simulation", {})
    spells, stats_crit = compile_spells(args.directory, args.build, catalog)
    catalog["simulation"] = {
        "schema": 1,
        "build": args.build,
        "checked": "2026-10-05",
        "sources": sources,
        "patchSource": PATCH,
        "spells": spells,
        "statsCrit": stats_crit,
    }
    if "character" in previous:
        catalog["simulation"]["character"] = previous["character"]
    for key in ("talentNotes", "unsupportedFallbacks"):
        if key in previous:
            catalog["simulation"][key] = previous[key]
    path.write_text(json.dumps(catalog, indent=2, ensure_ascii=False) + "\n")
    print(f"Normalized {len(catalog['simulation']['spells'])} spell models from {args.build}.")


if __name__ == "__main__":
    main()
