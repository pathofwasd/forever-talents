# Catalog and generated assets

`data/catalog.json` is the canonical, normalized offline catalog. `data/icons.json` lists its local
icon files; `data/icons/medium/` supplies web icons and `data/icons/large/` supplies native texture
inputs. No network access is needed to regenerate the data.

## Catalog layout

- `meta`: game build, snapshot date, talent rules, and compatibility tag. `reviewedAt` and
  `patchSource` identify later reviewed corrections without relabeling the snapshot as an unverified
  client build.
- `classes`: numeric class ID lookup; each class has permitted race IDs, three ordered trees, and
  ordered skill groups with rank records.
- `races`: numeric race ID lookup including faction.
- `racials`: class ID → race ID → racial records.
- `pets`: families, tameable beasts, zone names, and skill rank records.
- `perks`: reference trees, separate from allocated class talents.
- `simulation`: separately versioned client effects, attack categories, reported-crit aura flags,
  evidence URLs/checksums, documented corrections and approximate character reference tables.

Tree talents preserve their original row and column. Rows and columns start at zero; talent indices
are one-based across all three class trees. Records contain ID, icon, maximum rank, row gate,
prerequisite IDs/points, and spell IDs/descriptions per rank. Some prerequisites connect talents in
the same row. Empty descriptions mean the snapshot lacks text; native client descriptions may
provide a fallback.

JSON numeric lookup keys are converted to numeric Lua keys by the compiler. Array order is
significant, especially talent indices and skill ranks. Do not alphabetize or reindex talents:
existing build strings encode this order.

## Rebuild and compatibility

Run `pnpm sync`, or `python3 tools/build_data.py` followed by `python3 tools/sync_core.py`.
Generated outputs include addon `Data.lua`, TGA textures, the browser engine, and
`docs/data-build.json` with counts and hash. Generated data is compact for loading; the editable
catalog is formatted JSON.

The compatibility tag hashes class/race availability, ordered talent IDs, maximum ranks, row gates,
and prerequisites using the established FT1 identity. Text corrections can retain the tag. Talent
layout/rule changes require a review of stored builds and portable encodings before updating the
tag. The compiler refuses unexpected rules or a mismatched identity.

Current catalog: 9 classes, 27 trees, 466 talents, 1,314 talent ranks, 1,519 class-skill ranks, 10
races, 604 icons, 17 pet families, 750 tameable beasts, 102 pet skill records, and 3 perk trees.

## Simulator inputs

`tools/import_simulation_data.py` normalizes an already downloaded, reviewed set of client CSV
tables. It does not fetch data. Normal project builds only consume the canonical catalog. Keep
acquisition files outside the repository; the catalog records table URLs, checksums and build age.
Talent-granted first ranks are prepared by the shared Lua skill engine, rather than duplicated in
trainer tables. The simulator importer also reads those talent spell IDs when an ability has trainer
upgrades, so verified first-rank effects remain available to both platforms.

Skill rank `aliasOf` identifies a verified helper or cosmetic spell as the same player-facing cast.
`referenceOnly` keeps auxiliary records in the catalog without offering them as learned ranks. The
shared skill engine removes those entries from pickers and resolves aliases for training checks;
captured spell-ID lists remain unchanged. Legitimate different ranks at the same level are separate
records, including item/quest upgrades. Compiler checks reject live aliases and invalid targets.

The October 6 rank review retains the talent compatibility tag `7ba43a60`. It corrects player-cast
selection without claiming a complete migration of every tooltip or numerical effect to a newer
client build. Canonical pet notes distinguish announced Fox functionality from unverified family IDs
and tameable entries. Simulator `talentNotes` and `unsupportedFallbacks` retain evidence gaps across
regular builds and future effect imports.

`data/ui/character.json` owns the original paper-doll vector geometry. The compiler renders an RGBA
TGA for WoW and an SVG for the browser. The numerical model, sources and current coverage are
described in [SIMULATOR.md](SIMULATOR.md).
