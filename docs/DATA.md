# Catalog and generated assets

`data/catalog.json` is the canonical, normalized offline catalog. `data/icons.json` lists its local
icon files; `data/icons/medium/` supplies web icons and `data/icons/large/` supplies native texture
inputs. No network access is needed to regenerate the data.

## Catalog layout

- `meta`: game build, snapshot date, talent rules, and compatibility tag.
- `classes`: numeric class ID lookup; each class has permitted race IDs, three ordered trees, and
  ordered skill groups with rank records.
- `races`: numeric race ID lookup including faction.
- `racials`: class ID → race ID → racial records.
- `pets`: families, tameable beasts, zone names, and skill rank records.
- `perks`: reference trees, separate from allocated class talents.

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
