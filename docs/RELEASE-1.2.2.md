# Forever Talents 1.2.2

Skill progression and Druid/Warrior data corrections for both the addon and web/mobile app.

- Restore the talent-granted first rank of 31 abilities, including Bloodthirst, Lava Burst, Riptide,
  Pyroblast and Mind Flay. Rank details and Classic/Simple view identify the talent unlock
  separately from later trainer upgrades.
- Berserker Rage now unlocks at level 30. Removed Tiger's Fury no longer appears as a current skill.
- Correct Bloodthirst's 45% Attack Power description, Shifting Power's 55% base Mana cost, Raging
  Blows' three-Rage discount, Dual Wield Specialization's removed Rage effect and Improved Slam's
  1.5/3-second cooldown reduction. Offhand Whirlwind is described as baseline behavior.
- Add 23 first-rank simulator models from the reviewed client snapshot. Calculation sources and
  notes still identify incomplete or unsupported effects; this remains a per-use estimate.
  Previewing an unlearned talent ability now includes an explicit warning.

These corrections follow Blizzard's
[Forever development notes](https://us.forums.blizzard.com/en/wow/t/wow-forever-beta-development-notes-%E2%80%93-updated-october-1/2360696).
The October 5 service-maintenance announcement did not list additional class/talent changes.
Existing builds, checkpoint branches, character workspaces and sharing strings remain compatible.
Talent layout and the data compatibility tag are unchanged.

## Download and install

Scroll to **Assets** on this release page and download **ForeverTalents.zip**. Expand Assets if
needed. The “Source code” archives are for development.

1. Close World of Warcraft.
2. Extract the ZIP and copy **ForeverTalents** into the Forever client's `Interface/AddOns` folder.
3. Check that `Interface/AddOns/ForeverTalents/ForeverTalents.toc` exists without extra nesting.
4. Enable the addon and type `/ftc`.

When updating, move the previous addon folder outside AddOns as a backup. Keep your `WTF` folder; it
contains saved builds and settings.

The [web/mobile app](https://pathofwasd.github.io/forever-talents/) uses the same engine. Accept its
update prompt to load this release; local saves remain intact. Full-library export remains available
in the full view for backups or transfer between the addon and web app.
