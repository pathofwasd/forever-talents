# Addon / PWA parity and ownership

| Responsibility                                                           | Single source / platform behavior                                                    |
| ------------------------------------------------------------------------ | ------------------------------------------------------------------------------------ |
| Captured data, authentic grid positions, ranks, prerequisites            | `data/catalog.json` → `tools/build_data.py` → addon Data.lua → shared browser engine |
| Budget, gates, allocation, removal and point reordering                  | `core/lua/Model.lua`                                                                 |
| FT1 build, FS1/FS2 stats and gear, FC1 character formats                 | `core/lua/Codec.lua`, `Snapshot.lua`                                                 |
| Build links, exact ordered FT1 payload and link validation               | `core/lua/Codec.lua`; native Share / Import and browser URL preview                  |
| Full FL1 library encoding, validation, merge and duplicate handling      | `core/lua/Library.lua`                                                               |
| Drafts, Auto level, undo/redo, editable checkpoints and subtree deletion | `core/lua/Store.lua`                                                                 |
| Skill ranks, search, unlocks and related talent evidence                 | `core/lua/Skills.lua`                                                                |
| Classic / Simple view preference and compact skill progression           | `core/lua/Store.lua`, `Skills.lua`; native visibility/layout and browser visibility  |
| Per-use numerical estimate, applicable inputs, evidence and assumptions  | `core/lua/Simulation.lua`                                                            |
| Central character, custom gear, stat passives and scoped skill overrides | `core/lua/Character.lua`, `Simulation.lua`                                           |
| Native talent API, school stats and equipped-item capture                | addon `Player.lua`; export portable data for the PWA                                 |
| Native frames, chat receipts, keybind and minimap                        | addon `UI/`, `Comms.lua`, `Bootstrap.lua`                                            |
| Responsive layout, keyboard/touch interaction, clipboard/files           | `web/src/main.js`, `simulator.js`, `style.css`                                       |
| Browser object/table adaptation, whitelisted engine calls                | `web/lua/bridge.lua`                                                                 |
| Shared module copies, engine hashes, local WASM/icon assets              | `tools/sync_core.py`                                                                 |
| Atomic offline cache, update lifecycle and static archive                | `tools/build_pwa.mjs`, `web/src/updates.js`                                          |
| GitHub Pages verification, build and manual deployment                   | `.github/workflows/pages.yml`; setup in `docs/HOSTING.md`                            |
| Code license and content ownership                                       | Root NOTICE/LICENSE copied into addon and PWA                                        |

## Features required in both interfaces

Single-profile FP1 strings and `#profile=` links preserve every checkpoint title, branch and exact
allocation order. `Store.ShareProfile` copies only saved nodes. Unsaved drafts are excluded from
both FP1 strings and profile links; update or create a checkpoint to include those edits. Sharing
never changes source saves. `Library` owns compact encoding, validation through the existing store,
deduplication and import. No other profiles, character stats, equipment or undo history are exported
in FP1. Both imports preview the checkpoint count; the PWA previews each node. Accepted profiles
open at the selected snapshot’s saved level, preserving previous edits as child checkpoints.
Existing FT1 allocation links and all earlier sharing formats remain supported. Large profiles can
use an FP1 string/file when they exceed the 64 KiB link limit. Addon whispers remain
single-allocation.

Authentic three trees with prerequisites; current/next/all rank descriptions; legal exact point
order; class/race choice; skill/racial search and persistent checkbox highlights with six matching
colors and overlap markers; Auto/manual level; Undo/Redo; saved builds/checkpoint branches;
delete-parent-and-descendants; leveling preview and branching; text sharing; character and
stats-only import/export; full-library merge; simple and Advanced one-use estimates; race atlas, pet
atlas and perk reference.

Talent removal preserves the surviving order whenever it is already legal. If a historical row gate
blocks an otherwise legal allocation, `Model.Remove` replays the earliest eligible surviving points
without removing any other ranks. Both interfaces display the adjustment notice. Real prerequisites
and tier gates remain enforced, and Undo restores the exact previous order.

The PWA puts **Checkpoints & order** in a dedicated desktop workspace; phones retain **Builds**. The
addon’s **Checkpoints** tab opens its full graph. Both use readable wrapped node titles, compact
branch indentation, scrolling for deep trees and selection centering. Saving, sharing and canceling
deletion return to that workspace. Graph layout remains platform presentation; branch mutation stays
in the shared store.

Checkpoints can be updated explicitly through `Store.UpdateCheckpoint`. It replaces only the
selected snapshot, retaining its ID, title, parent, creation time and all child/sibling snapshots.
Both interfaces expose **Update checkpoint** separately from **New checkpoint**. Updates validate
the build and respect preview/read-only protection; successful updates clear stale Redo. The shared
store saves remaining changed profile drafts as child nodes before checkpoint navigation replaces
them, including source and destination classes. Identical children are reused. Both graphs show a
separate **Current draft** while editing and ordinary **Autosaved** children after navigation.
Loading restores the saved target level and explicitly turns off Auto if it conflicts. Undo/Redo
preserve each build's level mode. Successful profile and checkpoint saves clear stale Redo
continuations. Auto-saved nodes use the existing FL1 format and subtree deletion rules. Read-only
saves or a full profile block navigation rather than discarding work.

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
Trees/Skills/Builds/More navigation. The phone talent sheet has a stable height and persistent point
controls. Rank changes preserve the main viewport, the expanded disclosure and its internal scroll
position; only inspecting a different talent brings a new node into view. Rank and prerequisite
positions must not be rearranged for smaller screens. All key information is available without
hover. X and Escape return to the previous screen when a dialog has a parent, keeping temporary
simulator inputs. Closing the outermost dialog returns focus to the originating control. Gear
changes apply only through Equip; closing the editor discards them. Ctrl/Cmd+Z/Y shortcuts do not
intercept text editing. Browser saves and native SavedVariables are independent until explicitly
synced with text; no automatic connection is implied.

Talent-order entries temporarily highlight their talent on hover (and keyboard focus in the PWA).
They need no skill name or checkbox identity. Leaving restores the pinned skill/racial colors;
related-talent links keep the originating skill's assigned color in the addon. Highlighting does not
change allocations, saved profiles or sharing strings.

**Compare imported character** is off by default and persists only as a local display preference.
Enabling it compares the displayed level and talent build with the last imported class spellbook.
The skill area counts new skills and rank upgrades, offers a **Needs training** filter, and shows ↑N
levels until the next rank or first unlock (↑0 means the level has been reached). Talent
requirements remain explicit; racials and talent-granted ranks are excluded from trainer tasks.
Unmatched or absent captures show guidance rather than treating every skill as untrained. Re-import
after learning skills; this is a dated comparison, not a live trainer listing. The preference does
not alter allocations, undo history, character records or shared strings, and library imports retain
the recipient’s choice. It also works in Classic / Simple view with existing captured data.

Every class-skill row separates first unlock from the displayed rank’s own level, for example **🔓
Lv. 22 · Max rank 5 Lv. 54**. **Trained** identifies ranks from the imported spellbook. A secondary
line appears only when another rank/unlock exists, such as **🔒 Rank 4 Lv. 46**. The lock disappears
once that level is reached; talent requirements remain explicit. Maximum ranks have no duplicate
progression line. This works with comparison off and follows the imported rank when shown, the
available rank in an uncaptured plan, or the current training target. Shared `Skills.Progression`
selects only valid live records and retains talent unlock levels. Archived captures without a
current rank match are identified rather than labeled maximum. Native rows wrap the primary text and
draw their own padlock; PWA rows use an accessible inline icon. Classic / Simple view uses the same
progression.

Share offers a **Web link** in the addon and defaults to **Copy build link** in the PWA. The shared
Lua codec places the unchanged FT1 payload in the website’s `#build=` fragment. It includes class,
race, displayed level, title, talent allocation and exact point order; stats and libraries keep
their separate export formats. Both interfaces accept the full canonical URL through Import. Opening
a web link previews a validated build before loading; Cancel preserves the draft and saved library,
and Load imports an undoable independent draft. Build links cannot load character/stats or library
envelopes. Loading or canceling removes the fragment to avoid reopening an old link on reload. No
login, server-side build storage or live WoW connection is needed. Native in-game whispers keep FT1
strings and existing clickable addon receipts.

On phones and touch screens, talent inspection uses a non-modal bottom panel. The tree stays
interactive and scrollable; tap another node to change the inspected talent. Sticky + / − controls
update the ranks and budget in place. Locked additions and maximum ranks disable +; previews pause
editing. Additional ranks and related skills expand inside the panel, and closing a related-skill
dialog returns to it. The selected talent is outlined, scrolling leaves room beneath the tree, and X
/ Escape closes inspection. Native hover inspection already leaves its trees interactive.

Desktop talent tooltips list up to eight affected skills from the shared interaction index, with a
count pointing to full details for larger lists. **Alt-click** opens the full talent inspector in
both interfaces; browser keyboard Enter and mobile tap do the same. Right-click keeps removing a
point, and Ctrl-click retains the skill shortcut. Native talent details provide rank descriptions,
point controls and affected-skill buttons; closing a skill returns to the talent inspector. Reduced
views keep talent descriptions and allocation controls while hiding skill-interaction tools.

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

Both interfaces show player-facing rank progression and recognize verified helper/cosmetic aliases
without rewriting captured spell IDs. Holy Light, Mutilate, Penance, Polymorph and Shadow Bolt use
the corrected ranks; legitimate same-level upgrades remain visible. Shared simulator warnings cover
unmodeled Eureka and the Vengeance/Savage Strikes evidence disagreements. Scripted casts without a
complete model require explicit manual amounts. The pet atlas has an announced Fox reference note;
unverified family IDs and tameable locations are not invented.

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

The PWA exposes the installed version and **Check for updates** in its footer and mobile More menu.
`updates.js` observes installing and waiting workers; it offers **Update now** only after the atomic
cache is complete. Manual checks distinguish current, downloading, ready and failed states. The
existing service-worker activation flow preserves browser saves; no cache or storage clearing is
required. This browser-specific control has no counterpart in WoW’s addon loader.
