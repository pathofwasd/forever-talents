# Forever Talents 1.2.10

- Fixes talent points getting stuck because removing them invalidated an old leveling step, even
  when the remaining allocation was legal. The calculator now adjusts only the necessary order
  steps. Other talents keep their ranks; actual tier and prerequisite restrictions still apply. Undo
  restores the exact previous allocation and order.
- Keeps edits made after a checkpoint when you switch nodes. They appear as an **Autosaved** child
  checkpoint, while the original snapshot stays intact. **Current draft** shows the allocation you
  are editing. Use **Checkpoint** to give it a title yourself. Repeated navigation reuses an
  identical saved child rather than making duplicates.
- Loading a checkpoint restores its saved level. If Auto conflicts, it turns off with a clear
  message. Undo returns to the previous build and level mode.
- Saving a profile or checkpoint clears old Redo entries that could otherwise restore an earlier
  name or leave the saved profile unexpectedly.
- Applies these fixes to the addon and desktop/mobile PWA through the shared engine.
- Adds **Build + checkpoints** links and FP1 strings. Share one build with its entire checkpoint
  tree and current draft. Friends preview the branches before opening; existing builds and character
  stats stay intact. In the PWA, choose **Share → Build + checkpoints link** or **Library → Share
  checkpoints**. In the addon, choose **Share → Checkpoints link**. The regular build link still
  shares one allocation. Large trees can use a profile string or file instead.

Game data, talent layouts, existing libraries and FT1/FS1/FS2/FC1/FL1 strings remain compatible.
Both sides need version 1.2.10 or later to open the new profile format.

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
addon and web. If you already navigated away from edits in an older version, **Undo** can recover
them while they remain in that class's history; save a checkpoint after recovery.
