# Forever Talents 1.2.3

Navigation and character import improvements for the addon and web/mobile app.

- X and Escape return to the previous screen in nested dialogs. Calculation details return to
  Simulator with temporary inputs intact; closing a gear editor returns to Character and discards
  unfinished item edits.
- Fix the Character → Copy / paste character button error.
- Add **Import my talents & trained skills** to the addon's Import and Character screens. It
  captures active talents, learned skill ranks, level, stats and equipment together. If the client
  data is unavailable, the existing build stays intact; open the game's Talents/Spellbook windows
  and retry. Original talent spending order cannot be read and is reconstructed as a legal order.
- Add **Trained on captured character** to the skill filter. Captured ranks stay separate from
  planned-level availability and transfer to the web app in character, stats and whole-library
  strings. The browser cannot read a running WoW client directly.
- Library now offers **New build**, creating an independent profile. Checkpoints remain in the
  checkpoint workflow.
- Give selected skill/racial boxes matching talent-highlight colors. Six colors repeat, existing
  selections keep their color, and talents shared by several selections show each color marker.
  Clear highlights unchecks everything.

Existing builds, checkpoint branches, character workspaces and older sharing strings remain
supported. The talent data compatibility tag is unchanged.

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
update prompt to load this release; local saves remain intact. Export your full library for backups
or transfer between the addon and web app.
