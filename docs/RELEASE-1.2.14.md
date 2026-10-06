# Forever Talents 1.2.14

- **Compact view** at the addon's top left makes a small movable planner with Trees, Skills and
  Builds tabs. It keeps the real talent grid, tree search, colored highlights, Auto and Undo/Redo.
  More opens the larger tools. Compact and full windows remember separate positions; Compact works
  alongside Simple view.
- **Settings → Show experimental simulator** in both the addon and web/mobile app can hide Character
  and all simulator buttons. Stats, gear and saved builds are kept, ready to restore when enabled.
  This preference stays on each device; sharing a library does not change someone else's setting.
- Character and simulator tools are now labeled **experimental**. They estimate individual uses;
  they have not been validated in live gameplay.
- Talent data, allocation rules, calculations and existing saves/share formats are unchanged.

## Download and install

Scroll to **Assets** below and download **ForeverTalents.zip**. Expand Assets if needed. The “Source
code” archives are for development.

1. Close World of Warcraft.
2. Extract the ZIP and copy **ForeverTalents** into the Forever client's `Interface/AddOns` folder.
3. Check that `Interface/AddOns/ForeverTalents/ForeverTalents.toc` exists without extra nesting.
4. Enable the addon and type `/ftc`.

For updates, move the previous addon folder outside AddOns as a backup. Keep your `WTF` folder; it
contains your saved builds and settings. If files are replaced while playing, use `/reload`.

The [web/mobile app](https://pathofwasd.github.io/forever-talents/) uses the same engine. Accept its
update prompt to load this release. Export your full library for backups or transfer between the
addon and web.
