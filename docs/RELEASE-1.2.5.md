# Forever Talents 1.2.5

Fix talent highlight errors and preserve checked selections.

- Fix the Lua error when hovering talent-order entries. Temporary talent highlights do not need a
  skill name and cannot become checkbox selections.
- Fix skill-to-talent links and keep the originating skill’s highlight color.
- Keep checked skill/racial highlights when hovering an order entry and restore them on leaving.
- Add matching talent-order highlighting on hover or keyboard focus in the web app, using the shared
  engine. Clicking or tapping an entry still previews that level.
- Preserve saved builds, characters, checkpoints and all existing sharing formats. Game data is
  unchanged from 1.2.4.

## Download and install

Scroll to **Assets** on this release page and download **ForeverTalents.zip**. Expand Assets if
needed. The “Source code” archives are for development.

1. Close World of Warcraft.
2. Extract the ZIP and copy **ForeverTalents** into the Forever client’s `Interface/AddOns` folder.
3. Check that `Interface/AddOns/ForeverTalents/ForeverTalents.toc` exists without extra nesting.
4. Enable the addon and type `/ftc`.

When updating, move the previous addon folder outside AddOns as a backup. Keep your `WTF` folder; it
contains saved builds and settings. If the files were updated while playing, use `/reload`.

The [web/mobile app](https://pathofwasd.github.io/forever-talents/) uses the same engine. Accept its
update prompt to load this release; local saves remain intact. Export your full library for backups
or transfer between the addon and web app.
