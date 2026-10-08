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

## Base ability tooltips

`spellDetails` stores passive/instant/cast/channel labels, ability and global cooldowns, and range
from client build 1.60.1.70009. `tools/import_spell_details.py` imports reviewed SpellMisc,
SpellCastTimes, SpellDuration, SpellCooldowns and SpellRange CSVs. Missing records stay explicit.
These are base reference values, not active cooldown timers or talent/haste-adjusted predictions.
Descriptions continue to come from each rank record, with a native client fallback when missing.

## October 8 review

The nine current talent grids match all 466 stored positions, rank maxima and first spell IDs. The
October 7
[Rogue/Warlock overview](https://worldofwarcraft.blizzard.com/en-us/news/24310968/world-of-warcraft-forever-class-deep-dives-rogue-and-warlock)
confirms that Demonic Brand's extra threat applies to the Shadow effect of a tanking pet, not the
Imp. Descriptions reflect that distinction without presenting an unevaluated level-60 formula as
character damage. Proc counts remain marked unverified: captured trait ranks are 2/4/6, while the
rendered talent, base buff and overview disagree. No pet damage or threat estimate is invented.

Demonic Knowledge retains captured trait values 33/67/100% of character level; the overview's
maximum 33% is a source disagreement. Its conditional spell-power bonus is not modeled; captured
live totals can already contain it. Call of the Ancestors (66843) remains level 30 and Call of the
Spirits (66844) remains level 40, matching exact spell records; the
[Mage/Shaman overview](https://worldofwarcraft.blizzard.com/en-us/news/24302097/world-of-warcraft-forever-class-deep-dives-mage-and-shaman)
reverses their names. Overview text alone does not change exact ranks or unlock levels.

[October 8 maintenance](https://us.forums.blizzard.com/en/wow/t/beta-realm-maintenance-october-8/2375900)
was announced during this review. Its gameplay notes were still pending; this review date does not
claim that unpublished changes are implemented. Catalog layout/share identity remains unchanged.
