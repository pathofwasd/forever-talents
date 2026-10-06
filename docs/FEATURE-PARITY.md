# Addon / PWA parity and ownership

| Responsibility                                                            | Single source / platform behavior                                                    |
| ------------------------------------------------------------------------- | ------------------------------------------------------------------------------------ |
| Captured data, authentic grid positions, ranks, prerequisites             | `data/catalog.json` → `tools/build_data.py` → addon Data.lua → shared browser engine |
| Budget, gates, allocation, removal and point reordering                   | `core/lua/Model.lua`                                                                 |
| FT1 build, FS1/FS2 stats and gear, FC1 character formats                  | `core/lua/Codec.lua`, `Snapshot.lua`                                                 |
| Full FL1 library encoding, validation, merge and duplicate handling       | `core/lua/Library.lua`                                                               |
| Drafts, Auto level, undo/redo, immutable checkpoints and subtree deletion | `core/lua/Store.lua`                                                                 |
| Skill ranks, search, unlocks and related talent evidence                  | `core/lua/Skills.lua`                                                                |
| Classic / Simple view preference and compact skill progression            | `core/lua/Store.lua`, `Skills.lua`; native visibility/layout and browser visibility  |
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
order; class/race choice; skill/racial search and persistent checkbox highlights with six matching
colors and overlap markers; Auto/manual level; Undo/Redo; saved builds/checkpoint branches;
delete-parent-and-descendants; leveling preview and branching; text sharing; character and
stats-only import/export; full-library merge; simple and Advanced one-use estimates; race atlas, pet
atlas and perk reference.

The addon calls the reduced view **Classic mode** (Settings; `/ftc classic` / `/ftc full`). The PWA
calls it **Simple view**, with a visible checkbox above the class picker. Both hide race/racials,
character/simulator, highlights, sharing, checkpoint/order/library and atlas tools. Class selection,
authentic talent grids/descriptions/search, levels, Auto and Undo/Redo reuse the full-view controls.
Skill clicks show only live rank unlock/upgrade levels, including talent requirements, derived by
`Skills.Levels`. The class-skill list and availability filter reuse `Skills.List` with racials
disabled. There is no separate talent catalog, allocation engine or simulator for the reduced view.
The shared preparation path adds a talent-granted first rank when the trainer list begins with
upgrades. Both views label that rank as a talent unlock and hide entirely historical skill groups;
archived alternate ranks remain available in the full details of current skills. Entering it exits a
leveling preview so the hidden preview controls cannot leave editing paused. Returning restores all
tools; mode changes do not edit builds, character data or undo history.

`settings.simpleView` is a local display preference. It persists in SavedVariables/browser storage,
is excluded from FL1 library sharing, and remains the recipient's choice during a library merge.
Unreadable browser data still exposes recovery outside hidden panels. Mobile reduced navigation
contains Trees / Skills, with the same explicit talent Add/Remove sheet and true grid positions.

Desktop shows three trees with hover inspection and click/right-click edits. Mobile uses a readable
real 7×4 tree per tab, a tap-to-inspect sheet with explicit Add/Remove controls, and
Trees/Skills/Builds/More navigation. Rank and prerequisite positions must not be rearranged for
smaller screens. All key information is available without hover. X and Escape return to the previous
screen when a dialog has a parent, keeping temporary simulator inputs. Closing the outermost dialog
returns focus to the originating control. Gear changes apply only through Equip; closing the editor
discards them. Ctrl/Cmd+Z/Y shortcuts do not intercept text editing. Browser saves and native
SavedVariables are independent until explicitly synced with text; no automatic connection is
implied.

Library's **New build** creates an independent profile; the checkpoint action creates a child in its
existing profile. Both reuse shared Store operations.

The addon offers **Import my talents & trained skills** in Import and Character. It reads active
player talent ranks through Forever’s C_Traits combat configuration, learned player spellbook IDs,
level, stats and available equipment in one capture. Future, flyout, pet and inactive specialization
entries are excluded. Talent order is reconstructed because the original live spending order is
unavailable. Incomplete talent/spellbook reads preserve the existing draft and capture. Pending game
talent changes must be applied or canceled first. Every catalog talent must be read explicitly,
including zero ranks; spell definitions identify talents independently of node order, localization
and client layout pixels. **Trained on captured character** uses exact recorded spell IDs
independently of the planned level; it also works after FC1/FS2/FL1 import into the PWA. Older
snapshots without trained ranks remain supported. All skills remains the planning catalog; training
is a dated-by-level snapshot, not a live browser connection.

## Platform limits

Live spellbook/stats/talents capture, client descriptions/cast times and clickable whisper receipts
need WoW and stay native. The PWA imports their portable snapshots. Captured school power/crit and
source talents support recognized crit normalization across skill selections. Reported stats can
include buffs; hit, reduction, procs and rotations are assumptions/omissions. Unknown scaling is
explicitly unverified in both interfaces; a coefficient override can supply a measured value.
Character reference conversions are marked approximate. Native item capture retains reported totals
and available item details, without reconstructing procs or set bonuses. The PWA accepts portable
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
