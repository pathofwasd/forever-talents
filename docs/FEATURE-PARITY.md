# Addon / PWA parity and ownership

| Responsibility                                                            | Single source / platform behavior                                                    |
| ------------------------------------------------------------------------- | ------------------------------------------------------------------------------------ |
| Captured data, authentic grid positions, ranks, prerequisites             | `data/catalog.json` → `tools/build_data.py` → addon Data.lua → shared browser engine |
| Budget, gates, allocation, removal and point reordering                   | `core/lua/Model.lua`                                                                 |
| FT1 build, FS1/FS2 stats and gear, FC1 character formats                  | `core/lua/Codec.lua`, `Snapshot.lua`                                                 |
| Full FL1 library encoding, validation, merge and duplicate handling       | `core/lua/Library.lua`                                                               |
| Drafts, Auto level, undo/redo, immutable checkpoints and subtree deletion | `core/lua/Store.lua`                                                                 |
| Skill ranks, search, unlocks and related talent evidence                  | `core/lua/Skills.lua`                                                                |
| Per-use numerical estimate, applicable inputs, evidence and assumptions   | `core/lua/Simulation.lua`                                                            |
| Central character, custom gear, stat passives and scoped skill overrides  | `core/lua/Character.lua`, `Simulation.lua`                                           |
| Native talent API, school stats and equipped-item capture                 | addon `Player.lua`; export portable data for the PWA                                 |
| Native frames, chat receipts, keybind and minimap                         | addon `UI/`, `Comms.lua`, `Bootstrap.lua`                                            |
| Responsive layout, keyboard/touch interaction, clipboard/files            | `web/src/main.js`, `simulator.js`, `style.css`                                       |
| Browser object/table adaptation, whitelisted engine calls                 | `web/lua/bridge.lua`                                                                 |
| Shared module copies, engine hashes, local WASM/icon assets               | `tools/sync_core.py`                                                                 |
| Atomic offline cache, update lifecycle and static archive                 | `tools/build_pwa.mjs`                                                                |
| GitHub Pages verification, build and manual deployment                    | `.github/workflows/pages.yml`; setup in `docs/HOSTING.md`                            |
| Code license and content ownership                                        | Root NOTICE/LICENSE copied into addon and PWA                                        |

## Features required in both interfaces

Authentic three trees with prerequisites; current/next/all rank descriptions; legal exact point
order; class/race choice; skill/racial search and persistent checkbox highlights; Auto/manual level;
Undo/Redo; saved builds/checkpoint branches; delete-parent-and-descendants; leveling preview and
branching; text sharing; character and stats-only import/export; full-library merge; simple and
Advanced one-use estimates; race atlas, pet atlas and perk reference.

Desktop shows three trees with hover inspection and click/right-click edits. Mobile uses a readable
real 7×4 tree per tab, a tap-to-inspect sheet with explicit Add/Remove controls, and
Trees/Skills/Builds/More navigation. Rank and prerequisite positions must not be rearranged for
smaller screens. All key information is available without hover. Escape closes browser dialogs;
focus returns to the originating control. Ctrl/Cmd+Z/Y shortcuts do not intercept text editing.
Browser saves and native SavedVariables are independent until explicitly synced with text; no
automatic connection is implied.

## Platform limits

Live stats/talents capture, client descriptions/cast times and clickable whisper receipts need WoW
and stay native. The PWA imports their portable snapshots. Captured school power/crit and source
talents support recognized crit normalization across skill selections. Reported stats can include
buffs; hit, reduction, procs and rotations are assumptions/omissions. Unknown scaling is explicitly
unverified in both interfaces; a coefficient override can supply a measured value. Character
reference conversions are marked approximate. Native item capture retains reported totals and
available item details, without reconstructing procs or set bonuses. The PWA accepts portable
character/gear snapshots; simulator pastes remain temporary. Pet/perk data is reference-only in both
interfaces; it is not silently added to class builds.

## Update checklist

1. Develop addon behavior, edit canonical Lua once, then sync generated copies.
2. Add native/bridge controls for the same applicable workflow. Review phone UX.
3. Run `python3 tools/verify.py`, then build both archives. Check generated drift.
4. Verify desktop and 320/375 px browser layouts, keyboard and explicit tap controls.
5. Verify production cold start, offline reload, update acceptance, and saved builds.
6. Keep version/data tag aligned and update release notes. Back up installed addon files outside
   AddOns before replacing code; never rewrite player SavedVariables.

A release is incomplete if an applicable addon feature is stale in the PWA. The GitHub Pages
workflow publishes on manual request. Hosted PWA updates use the offline cache lifecycle; addon
releases are distributed as ZIPs.

The browser footer and addon guide identify the project as free and unofficial, with game-content
ownership notices. The PWA footer links to the bundled `NOTICE.txt`, including during offline use.
