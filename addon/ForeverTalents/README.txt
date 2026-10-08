FOREVER TALENTS 1.2.15
An offline talent planner for World of Warcraft Forever (Interface 16001).
Free, unofficial community project. Not affiliated with or endorsed by
Blizzard Entertainment. Game artwork and text belong to their rights holders.

INSTALL
1. Close the game, or return to character selection.
2. Extract the archive. Copy the ForeverTalents folder into your Forever
   client's Interface/AddOns folder. The final layout must be:
   Interface/AddOns/ForeverTalents/ForeverTalents.toc
3. Enable Forever Talents in the character-selection AddOns menu.
4. Log in and type /ftc. You can also use the minimap button or assign a key
   under WoW's Key Bindings > Forever Talents.

No other addon or internet connection is required.

COMPACT VIEW
Check Compact view at the top left, or in Settings, for a small movable planner.
Trees shows one real talent tree at a time; tabs select its specialization.
Skills keeps search, ranks and colored highlights; Builds keeps order/library.
More opens sharing, checkpoints, race and other tools. Drag the title bar to
move it. Compact and full windows remember their positions independently.
Compact works alongside Simple view without changing your build or point order.

EXPERIMENTAL TOOLS
Settings > Show experimental simulator controls Character and simulator buttons.
Turn it off to hide them while keeping stats, gear, captures and saved builds.
Turn it on to restore them. This preference stays on your device and is not
included in library sharing. Estimates have not been validated in live gameplay.

CLASSIC MODE
Simple view at the top left (also Settings > Classic mode) reduces the planner to class, talents and skill levels.
The window becomes smaller. Race, racials, character/simulator, sharing and
checkpoint controls are hidden. Click a skill for its unlock and upgrade levels.
Talent descriptions, search, colored skill boxes, Auto and Undo/Redo keep working.
Class drafts still save between sessions. Uncheck Classic mode to restore all
tools with your builds, checkpoints, race and character settings intact.
The preference stays on this device and is not included in library sharing.
Use /ftc classic to toggle it, or /ftc full to return to the full view.
Classic mode uses the same current Forever talents and rules.

FIRST BUILD
Choose a class icon and an available race. Races opens the complete class/race
atlas. Target level controls your point budget; Build level shows the minimum
level needed for the points you have already spent.

Left click a talent to add a point; right click to remove a point. Shift fills
or clears a talent. Rows, prerequisites, maximum ranks and the 51-point limit
are enforced at every step in the leveling order. If surviving points need a new legal order, removal adjusts the necessary steps.
Real prerequisites and tier gates still prevent invalid allocations.
Reset and all talent edits can be undone.

Hover for the current and next descriptions. Hold Shift while hovering for
every talent rank. Ctrl click a talent to inspect an associated skill.
Search accepts names and words from descriptions, including damage schools.
Auto beside the level controls makes the planned level follow spent points:
one point is level 10, 51 points are level 60, and an empty build is level 1.
Adding, removing, filling, clearing, Undo and Redo keep the level in sync.
Turn Auto off to restore your manual target (at least the level needed for
your current talents). The mode is remembered per class draft and can itself
be undone. Manual target levels still enforce their normal point budget.

SKILLS AND RACIALS
Hover a skill to highlight its related talents. Six colors identify selections. Click for every rank,
the first learn level and subsequent rank levels, talent unlocks and full
descriptions. Named, school and general effects are labeled separately.
Check the box beside any skill or racial trait to keep its highlight. Multiple
checked skills combine their related talents. Clear highlights unchecks all,
including selections hidden by a search or filter. Selections stay when you
inspect details, change level, or edit talents. Changing class clears them;
changing race clears racial selections while keeping selected class skills.
Some source ranks are alternate records; they remain visible and labeled.
When the snapshot has no description, the addon can display the client's
description if available; otherwise it labels the missing source text.
All current skills are browsable even before you unlock them. Rank details label
the initial talent unlock and the subsequent trainer upgrades. Removed abilities
are excluded; archived alternates for current skills remain in full details.
Available at this level filters the list to the planned level and talents,
including talent-granted ranks only after learning their talent. Selecting an
Order step changes the preview level and skill availability.

Racial traits depend on both your race and class and appear along the bottom.
Help also opens the pet atlas (families, skills, rank levels and tameable
beasts) and the separate Forever perk reference.

UNDO, LEVEL PREVIEWS AND CHECKPOINTS
Undo/Redo buttons, Ctrl+Z, Ctrl+Y and Ctrl+Shift+Z keep 100 changes per class.
Each class has an independent draft that is saved between sessions. WoW
writes SavedVariables when you log out or /reload; a crash can lose the
current session's changes.

Save build names your draft and creates a starting node. After editing, Save
checkpoint adds a node below the selected checkpoint. Click an older node
and edit from there to create an alternate branch. Existing nodes stay intact.
Checkpoints shows the compact tree; Expand shows a scrollable graph.
Undo after loading a node also restores the previously selected branch.

Order records every point at levels 10 onward. The small arrows move one
point earlier/later if the resulting entire path is legal. Click an Order
step for a read-only level preview. Full build returns to the draft. Branch
here starts a draft from that step and opens the checkpoint naming dialog.

Library loads saved profiles; Ctrl click one to share. Right click for its
checkpoints, sharing, renaming or deletion. Save as new build creates an
independent copy. Profiles and checkpoints are shared across your characters.
A profile supports 400 checkpoints; start a new profile if you reach that limit.
Use the x on a checkpoint (in the sidebar or expanded graph) to delete it and
every descendant. The confirmation shows the affected count. Other branches
stay saved; deleting the starting node removes the entire profile. Your current
working talents are kept. If the selected node is removed, the draft branches
from its surviving parent. Node deletion cannot be undone; talent edits still can.

LIVE CHARACTER IMPORT
Open Import or Character and choose Import my talents & skills. The addon reads
the active Forever talent configuration, learned skill ranks, level and stats.
Apply or cancel pending changes in the game’s Talents window before importing.
If client data is loading, open Talents and Spellbook and retry. Failed reads
keep your draft and character capture; unread talents are never assumed empty.
Original spending order is unavailable; the importer derives a legal order.
Copy a character string (FC1) to carry this capture into the web/mobile app.

SHARE
Share selects one compact FT1: string. Press Ctrl+C, send it in any text chat,
and have your friend paste it into Import. The string includes class, race,
target level, all ranks and the exact point order. It shares one build, not
the entire checkpoint graph. When viewing a level preview, Share copies that
preview. Import validates and previews a build before you choose to load it.

Both players can also use Send addon whisper. The recipient gets a clickable
local chat receipt and a copy in Library > Received. Clicking previews it;
incoming builds never replace a draft automatically. A receipt confirms that
the friend's addon received it. Client/realm restrictions or a missing addon
can prevent delivery; the text string always remains available.

Text whisper prepares an ordinary whisper containing the string. You choose
when to send it. Friends using different talent-data versions may need to
update: incompatible point encodings are rejected with an explanation.

MY TALENTS
My talents previews a legal build read from the logged-in character. The game
does not expose the original spending order, so a valid order is derived.
Mismatched client talents stop the import and preserve the draft. Structured
Classic APIs support matching spell IDs; legacy API imports may require
English talent names. Planning itself uses English source descriptions.

CHARACTER AND SIMULATOR
Character opens a central workspace shared by all skill simulations for this
class. Choose Base + gear to create custom items and add extra bonuses, or
Overall stats to enter totals before modeled passives. Gold numbers show the
result after recognized race, level and talent changes. Base stats and stat
conversions are approximate references; captured live totals are preferred.

Capture in game records reported stats and available equipped-item details.
Captured gear is reference only: reported totals already include equipment and
buffs. Original captures are retained, so planned passive changes do not compound.
When item information is still loading, open Character and capture again.
Weapon details currently require English item tooltip text. Feral weapon hit
ranges need measured form totals; equipped weapon damage is not claw damage.

Open a skill, choose a rank and select Simulator. Only inputs used by its model
appear. Target conditions, resource inputs and active-cooldown assumptions are
shown where applicable. Temporary edits, pasted skill inputs and scaling
experiments leave the central character unchanged. Reset skill overrides returns
to the character's current values. Edit character changes the shared workspace.

Results estimate one use against one target, including full periodic duration.
Damage, healing, shield capacity and self-health costs are separate effects.
Expected total includes eligible critical rolls and the assumed chance to land.
Calculation & sources explains numeric steps, coefficients, ticks, talent-rank
text and evidence. Advanced accepts measured scaling or replacement amounts.
Periodic overrides describe the entire effect, not the coefficient per tick.

Effects use the reviewed Forever client build 70009, with selected corrections
from development notes. Unknown coefficients, scripted interactions, unmodeled
talents and uncertain low-rank scaling produce a Partial estimate. Rotations,
proc uptime, automatic armor/resistance, most pets and off-hand attacks remain
outside this model. Accuracy notes describe the limits for the selected skill.

QUICK COMMANDS
/ftc or /forevertalents  Open/close the planner
/ftc help               Open the guide
/ftc import <string>    Preview a shared string
/ftc share              Open sharing
/ftc mine               Preview your learned talents
/ftc minimap            Show/hide the minimap button
/ftc resetwindow        Recenter the window

Settings controls size, position and the minimap button. The window fits the
screen automatically. Drag its title to move it; drag the minimap button to
move that button around the minimap. Escape closes dialogs/window.

DATA
Bundled snapshot: 2026-10-04, Forever 1.60.1 build 69876.
9 classes, 27 trees, 466 talents, 1,314 talent ranks, 1,519 skill-rank records,
10 races, 604 icons, 17 pet families, 750 beasts, 102 pet skill records,
and 3 perk trees. The addon runs entirely from its bundled Lua and textures.
Seven class-skill records and the pet skill table have no captured description;
their spell IDs allow a client-description fallback when the client exposes it.

The snapshot can differ from a later game patch. Source and verification
instructions live in the development repository.

Code license and third-party attribution are in LICENSE.txt and NOTICE.txt.

CHARACTER AND FULL-LIBRARY SYNC (ADDON <-> WEB / MOBILE)
Open Character on the toolbar, or /ftc character. Copy planned character
exports level, exact talents/order, central stats and equipment (FC1). Copy
character stats exports stats/equipment (FS2); importing FS1 or FS2 keeps
your current talents and target level. Live captures include reported power
and crit by school, healing power, AP and normal weapon damage. Recognized
source-talent crit bonuses can be removed before planned bonuses are added.
Reported numbers can include buffs; hit, mitigation and target states remain
assumptions. Select a skill's Simulator panel to edit all estimate inputs.

Read logged-in character captures live talents, level, stats and available gear. Read only
live stats still works when talents are unreadable, with a crit-normalization
note. If talents are unavailable or their layout differs, import stops and
keeps the draft. Open the game's Talents window and retry after login. Original
spending order is not exposed by the client: imports derive a legal order.

Copy whole library exports FL1: all named profiles, checkpoint parents/titles,
class drafts, undo/redo and central character workspaces. Copy one large string with Ctrl+C
and paste it into Import in the PWA or this Character panel. Preview counts
before loading. Library imports merge saved profiles and skip exact duplicates;
optionally check Replace class drafts. Export first to keep a backup. Window
position, scale, minimap settings and received whispers stay on this device.
The PWA can save the same string to a .txt file. Large library strings should
be sent as text/files outside game chat, which has much shorter message limits.

Explicit FT1/FC1 imports retain their shared target level and exit Auto mode;
Undo restores the previous allocation and mode. Preview exports use the
level actually displayed. The PWA cannot directly read a running WoW client;
capture in the addon and paste the snapshot into the PWA instead.


Simulator Copy/Paste inputs uses FS1/FS2 for temporary skill experiments.
Character import intentionally changes the central workspace; the simulator
paste control does not. Old FS1 strings remain supported.
