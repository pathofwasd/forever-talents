# Forever Talents 1.2.1

An optional simpler view for the addon and web/mobile app.

- **Addon:** Settings → check **Classic mode**. A smaller window keeps class, talents and skills.
- **Website:** check **Simple view** above the class picker. Phones keep Trees / Skills navigation.
- Click a skill for its unlock and rank upgrade levels, including talent requirements.
- Race, racials, character/simulator, highlights, sharing and checkpoint tools are hidden.
- Talent descriptions, search, Auto level, undo/redo and class draft autosaving keep working.
- Turn the mode off to restore all tools and your saved builds, gear and checkpoints.

Both views use the same current Forever talent data and rules. The preference stays on each device;
library sharing does not overwrite it. Addon shortcuts: `/ftc classic` toggles, `/ftc full` restores
the full view. Existing sharing strings and saves remain compatible.

## Download and install

On this release page, scroll to **Assets** and download **ForeverTalents.zip**. Expand Assets if
needed. The “Source code” archives are for development.

1. Close World of Warcraft.
2. Extract the ZIP and put **ForeverTalents** in your Forever client's `Interface/AddOns` folder.
3. Check that `Interface/AddOns/ForeverTalents/ForeverTalents.toc` exists without extra nesting.
4. Enable the addon and type `/ftc`.

When updating, move the previous addon folder outside AddOns as a backup. Keep your `WTF` folder; it
contains saved builds and settings.

The [web/mobile app](https://pathofwasd.github.io/forever-talents/) uses the same engine. Its update
prompt preserves local saves. Turn off Simple view to access full-library export for backups/sync.
