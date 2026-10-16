# Forever Talents 1.2.16

## Changes

- Updated addon and web/mobile data for Forever client **1.60.1.70291** and the October 8 class
  notes.
- Impale now requires 3/3 Deep Wounds. Existing builds and checkpoint branches stay intact. Affected
  allocations show **Needs repair**; add/reorder Deep Wounds before Impale or remove Impale, then
  update the checkpoint. **Share → Original build** exports the original allocation, even after
  repair.
- Natural Instinct replaces Predatory Instincts with the same identity, keeps its melee critical
  bonus and adds healing equal to 12/25% of Intellect. Old live captures retain reported healing
  until re-captured; manual, equipment and new live captures support the revised passive.
- Refreshed early spell-rank bases and growth, Penance's separate three-bolt damage/healing results,
  two-second channel and 150/220/270/385 Mana costs. Tooltip references are labeled by level;
  calculations use the displayed level and each effect's scaling cap.
- Corrected Thorns/Retribution Aura bases and 6% caster-power reference, Expose Prey duration,
  Reckoning/Water Shield proc intervals and activation/resource descriptions. Retaliation, rolling
  bleeds, threat, resource flow and rotations remain outside verified one-use simulation.
- Expanded the Fox ability reference without inventing family IDs or tameable entries.

## Download and install

Expand **Assets** below and download **ForeverTalents.zip**, not the source-code archives. Extract
and place its **ForeverTalents** folder in the Forever client's `Interface/AddOns` directory.
`Interface/AddOns/ForeverTalents/ForeverTalents.toc` should exist without extra folder nesting. Move
the previous addon folder outside AddOns as a backup; keep **WTF**, which contains your saves.
Enable the addon and use `/ftc`. If updating while playing, use `/reload` afterward.

The [web/mobile app](https://pathofwasd.github.io/forever-talents/) shares this version and engine.
After deployment, choose **Check for updates**, then **Update now** once the release is cached.
Browser saves remain local. Export your library before transferring devices or clearing site data.
Both recipients need this update to share current builds; known older strings remain importable.

Validation: shared Lua/native API-harness regressions, exact Lua 5.1/WASM migration/export parity,
production PWA build and archive checks. Native gameplay and numerical combat accuracy still require
live-client testing; simulator tools remain experimental.
