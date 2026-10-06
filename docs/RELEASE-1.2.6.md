# Forever Talents 1.2.6

See what your imported character can learn next.

- Enable **Compare imported character** in **Skills & ranks**. It starts off and remembers your
  choice locally.
- View the count of skills needing training and use **Needs training** (or click the count) to show
  only missing skills and rank upgrades available at the displayed level.
- **New** marks a skill missing from the imported spellbook; **Train Rank…** marks a rank upgrade.
  Gold text/borders distinguish these from skills you already know.
- **↑3** means three levels until the next rank or first unlock; **↑0** means that level has been
  reached. Hover or open the skill for the rank and unlock level. Talent requirements still apply.
- Compare the displayed level and talent build with the last imported spellbook. Racials and
  automatically granted talent ranks are excluded from training tasks. Some skills require quests or
  items. Re-import after learning skills to refresh the comparison.
- Missing or unmatched imports show guidance instead of marking every skill untrained.
- Available in the addon and web/mobile app, including Classic / Simple view. Saved builds,
  character data, undo history and sharing formats remain compatible; game data is unchanged.

## Download and install

Scroll to **Assets** on this release page and download **ForeverTalents.zip**. Expand Assets if
needed. The “Source code” archives are for development.

1. Close World of Warcraft.
2. Extract the ZIP and copy **ForeverTalents** into the Forever client’s `Interface/AddOns` folder.
3. Check that `Interface/AddOns/ForeverTalents/ForeverTalents.toc` exists without extra nesting.
4. Enable the addon and type `/ftc`.

When updating, move the previous addon folder outside AddOns as a backup. Keep your `WTF` folder; it
contains saved builds and settings. If files were updated while playing, use `/reload`.

For comparison, first capture **Character → Import my talents & skills** in the addon, then check
**Compare imported character** in the skill area. The browser imports the addon’s character string;
it cannot read the running game directly.

The [web/mobile app](https://pathofwasd.github.io/forever-talents/) uses the same engine. Accept its
update prompt to load this release; local saves remain intact. Export your full library for backups
or transfer between the addon and web app.
