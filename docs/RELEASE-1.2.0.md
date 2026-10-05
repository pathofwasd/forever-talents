# Forever Talents 1.2.0

A new Character workspace and a rebuilt Simulator for the WoW addon and desktop/mobile PWA.

- Create custom equipment or enter overall stats in one central character sheet.
- Preview recognized race, level and talent-passive changes in the resulting totals.
- Capture reported stats and available equipped-item details inside WoW.
- Share characters and gear between addon and PWA; old build/stats strings remain supported.
- Experiment with skill inputs without overwriting the character, including pasted stats.
- See separate direct/tick/shield/health-cost results, expected critical totals, applicable
  controls, calculation steps, talent evidence, sources and accuracy notes.
- Improved phone layout, with a live result summary while editing.

The simulator is a per-use estimate. Missing server-side mechanics and uncertain coefficients are
marked; it is not a rotation simulator. The reference base-stat mode is approximate. Re-capture a
live character for measured totals. See the [simulator guide](../docs/SIMULATOR.md) for details.

## Download and install

On this release page, scroll to **Assets** below these notes. Expand it if needed and download
**ForeverTalents.zip**. The “Source code” archives are for development.

1. Close World of Warcraft.
2. Extract **ForeverTalents.zip**.
3. Put its **ForeverTalents** folder in the Forever client's `Interface/AddOns` folder.
4. Check that `Interface/AddOns/ForeverTalents/ForeverTalents.toc` exists without extra nesting.
5. Enable the addon and type `/ftc` in game.

When updating, move the old addon folder outside AddOns as a backup and replace it with the new
folder. Keep your `WTF` folder / SavedVariables; they contain saved builds and settings.

The [web/mobile app](https://pathofwasd.github.io/forever-talents/) uses the same engine. Its update
prompt keeps local saves. Use full-library export to move your data between devices and the addon.
