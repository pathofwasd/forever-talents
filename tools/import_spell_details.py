#!/usr/bin/env python3
"""Import base tooltip timing and range from a reviewed client CSV snapshot.

Usage: python3 tools/import_spell_details.py CSV_DIRECTORY --build BUILD
Regular builds use the normalized catalog and never fetch reference files.
"""
import argparse
import csv
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('directory', type=Path)
    parser.add_argument('--build', required=True)
    args = parser.parse_args()

    def rows(name):
        with (args.directory / (name + '.csv')).open(newline='') as source:
            return list(csv.DictReader(source))

    misc = {int(r['SpellID']): r for r in rows('SpellMisc') if int(r['DifficultyID']) == 0}
    casts = {int(r['ID']): r for r in rows('SpellCastTimes')}
    durations = {int(r['ID']): r for r in rows('SpellDuration')}
    ranges = {int(r['ID']): r for r in rows('SpellRange')}
    cooldowns = {int(r['SpellID']): r for r in rows('SpellCooldowns') if int(r['DifficultyID']) == 0}
    path = ROOT / 'data/catalog.json'
    catalog = json.loads(path.read_text())
    ids = set()

    def visit(value):
        if isinstance(value, dict):
            if 'spellID' in value:
                ids.add(int(value['spellID']))
            for item in value.values():
                visit(item)
        elif isinstance(value, list):
            for item in value:
                visit(item)

    for key in ['classes', 'racials', 'pets', 'perks']:
        visit(catalog[key])
    details = {}
    for sid in sorted(ids):
        if sid not in misc:
            continue
        spell = misc[sid]
        row = {'passive': bool(int(spell['Attributes_0']) & 0x40),
               'channel': bool(int(spell['Attributes_1']) & 0x44)}
        cast_index = int(spell['CastingTimeIndex'])
        if cast_index == 0:
            row['cast'] = 0
        elif cast_index in casts:
            # Negative client markers are instant, never negative durations.
            row['cast'] = max(0, int(casts[cast_index]['Base'])) / 1000
        duration = durations.get(int(spell['DurationIndex']))
        if row['channel'] and duration and int(duration['Duration']) > 0:
            row['channelDuration'] = int(duration['Duration']) / 1000
        cooldown = cooldowns.get(sid)
        if cooldown:
            row['cooldown'] = max(int(cooldown['RecoveryTime']), int(cooldown['CategoryRecoveryTime'])) / 1000
            row['globalCooldown'] = int(cooldown['StartRecoveryTime']) / 1000
        distance = ranges.get(int(spell['RangeIndex']))
        if distance:
            row['range'] = distance['DisplayName_lang']
            row['rangeMax'] = max(float(distance['RangeMax_0']), float(distance['RangeMax_1']))
        details[str(sid)] = row
    catalog['spellDetails'] = {'build': args.build,
        'sources': [f'https://wago.tools/db2/{name}/csv?build={args.build}' for name in
                    ['SpellMisc', 'SpellCastTimes', 'SpellDuration', 'SpellCooldowns', 'SpellRange']],
        'spells': details}
    path.write_text(json.dumps(catalog, indent=2, ensure_ascii=True) + '\n')
    print(f'Imported base ability details for {len(details)} spell IDs; {len(ids) - len(details)} missing.')


if __name__ == '__main__':
    main()
