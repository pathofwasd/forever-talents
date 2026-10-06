# Forever Talents 1.2.12

- Load a checkpoint, edit its talents or level, then click **Update checkpoint**. It replaces that
  saved snapshot while keeping its title and all branches. Children and siblings keep their own
  builds.
- **New checkpoint** creates a separate child; **New build** creates an independent profile.
- **Build + checkpoints** links and strings include saved checkpoints only. Update or create a
  checkpoint first to include current edits. Full-library exports still preserve drafts for backups.
- Switching without updating protects edits as an autosaved child. Existing saves, Auto/Undo/Redo
  and sharing formats remain compatible.

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
