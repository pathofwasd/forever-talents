# Forever Talents 1.2.4

Fix live talent import for the Forever client.

- Read the active Forever talent configuration through `C_Traits`. The older Classic APIs can remain
  present without returning any talent records.
- Match talent spell definitions independently of node order, localized names and screen positions.
  Read every talent, including explicit zero ranks, and validate purchased ranks and point totals.
- Keep the current build and character capture if client records are incomplete. Apply or cancel
  pending changes in the game's Talents window before importing; a capture never applies talents to
  your actual character.
- Character captures now include the corrected source talents for simulator stat normalization. FC1
  character sharing, trained ranks, older strings and saved libraries remain compatible.
- Update addon and web/mobile help with the live capture steps. The browser imports addon snapshots
  through text strings; it cannot read the running WoW client directly.

## Download and install

Scroll to **Assets** on this release page and download **ForeverTalents.zip**. Expand Assets if
needed. The “Source code” archives are for development.

1. Close World of Warcraft.
2. Extract the ZIP and copy **ForeverTalents** into the Forever client's `Interface/AddOns` folder.
3. Check that `Interface/AddOns/ForeverTalents/ForeverTalents.toc` exists without extra nesting.
4. Enable the addon and type `/ftc`.

For live capture, open **Character → Import my talents & skills** or the Import screen's matching
button. Finish any pending game talent edits first. If data is still loading, open the game's
Talents and Spellbook windows and retry.

When updating, move the previous addon folder outside AddOns as a backup. Keep your `WTF` folder; it
contains saved builds and settings.

The [web/mobile app](https://pathofwasd.github.io/forever-talents/) uses the same engine. Accept its
update prompt to load this release; local saves remain intact. Export your full library for backups
or transfer between the addon and web app.
