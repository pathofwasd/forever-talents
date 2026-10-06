# Forever Talents 1.2.13

- Active checkpoints have a visible name, saved/unsaved status and a highlighted graph node on
  desktop, mobile and the addon. The mobile talent panel also shows the active checkpoint.
- **Update checkpoint** saves edits in place. **Save as new checkpoint** creates a child. Switching
  checkpoints no longer creates draft or autosave nodes; Undo brings back unsaved edits.
- **Copy talents / Paste talents** sit beside talent search. Transfer just class and ordered points
  while retaining the destination checkpoint, race, manual level and character settings.
- **Simple view** is at the addon’s top left. Both platforms retain colored skill checkboxes and
  Clear highlights in Simple view, with skill clicks still showing unlock and upgrade levels only.
- Existing saves and share formats remain compatible. New talents-only FA1 strings require 1.2.13 at
  both ends. Build + checkpoints sharing includes saved nodes only.

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
