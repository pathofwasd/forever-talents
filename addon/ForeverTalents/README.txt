FOREVER TALENTS 1.1.2
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

FIRST BUILD
Choose a class icon and an available race. Races opens the complete class/race
atlas. Target level controls your point budget; Build level shows the minimum
level needed for the points you have already spent.

Left click a talent to add a point; right click to remove a point. Shift fills
or clears a talent. Rows, prerequisites, maximum ranks and the 51-point limit
are enforced at every step in the leveling order. A removal that would break
a later step is refused: remove dependent points first, or reset that tree.
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
Hover a skill to highlight its related talents in blue. Click for every rank,
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
All skills are browsable even before you unlock them. Available at this level
filters the list to the currently planned level and talents. Selecting an
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

WHAT IF?
Open a skill, choose a rank and click What if? for an estimate of one use.
Start with bonus spell/healing power, crit chance and damage stopped. Use my
stats copies reported values from your current character. Base critical chance
is the chance before the modeled talent bonuses. When learned talents can be
read, recognized passive general/school crit bonuses are removed from reported
crit before your planned bonuses are added. The notes show the adjustment.
Other reported values can include buffs; edit values that already include a
bonus listed as Included. Target bleeding,
frozen and active-cooldown toggles enable supported simple talent conditions.

Normal use, Critical use and Expected average include direct and captured
periodic amounts. The comparison uses the same assumptions without selected
talent modifiers. Advanced exposes attack power, weapon hit range, chance to
land, scaling coefficients, another multiplier and a manual base range. Hover
fields and How this works explain each input and the formula.

Read the Included and Omitted notes. This is a planning estimate, not a full
combat simulator. Some direct coefficients come from an older Forever beta
datamine; other spells use a client cast-time approximation or zero when the
coefficient is unknown. Unknown periodic scaling starts at zero. Advanced
can replace these assumptions. Proc uptime, rotations, forms, racial bonuses,
combo-point/resource rules, multi-target hits and complex intrinsic conditions
are not automatically simulated. Coefficient/manual overrides are cleared
when switching to a different skill; character and target assumptions persist.

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
exports level, exact talents/order and simulation settings (FC1). Copy
simulation stats exports only the estimate inputs (FS1); importing FS1 keeps
your current talents and target level. Live captures include reported power
and crit by school, healing power, AP and normal weapon damage. Recognized
source-talent crit bonuses can be removed before planned bonuses are added.
Reported numbers can include buffs; hit, mitigation and target states remain
assumptions. Select a skill's What if? panel to edit all estimate inputs.

Read logged-in character captures live talents, level and stats. Read only
live stats still works when talents are unreadable, with a crit-normalization
note. If talents are unavailable or their layout differs, import stops and
keeps the draft. Open the game's Talents window and retry after login. Original
spending order is not exposed by the client: imports derive a legal order.

Copy whole library exports FL1: all named profiles, checkpoint parents/titles,
class drafts, undo/redo and simulation stats. Copy one large string with Ctrl+C
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
