# Verification

Install the development dependencies from the root README, then run:

```sh
pnpm verify
pnpm build
python3 tools/package_addon.py
python3 tools/check_package.py
pnpm format:check
ruff check tools
ruff format --check tools
```

The native suites cover allocation rules, randomized legal edits, Auto level, checkpoint
branches/deletion, portable formats, character API adaptation, and interface callbacks using a Lua
5.1 WoW API harness. Browser engine tests run the same canonical Lua through WebAssembly and compare
exact results and sharing strings against native Lua. Generated output drift is checked as well.

The UI suite creates ignored `preview/` geometry dumps. `render_preview.py` can render these for
inspecting native frame layout; this is a test harness, and does not substitute for verification in
a running WoW client.

## Browser release checks

Use the production preview, not only the development server. Check desktop, tablet, narrow phones,
landscape, and the layout transitions at 600 and 1050 pixels. Verify all nine class buttons, long
race names, tree tabs, rank inspection, skill highlights, checkpoint graph, sharing/import dialogs,
and simple/advanced estimates. Check keyboard navigation, visible focus, closing dialogs, touch
targets, and horizontal overflow.

After a build update, wait for the update notice and accept it. Confirm the version changes while
drafts, saved profiles, and checkpoint branches remain. Stop the local server and reload to verify
offline startup. Back up an existing library before using it for manual tests; prefer a separate
test origin.

Check Classic / Simple view in both interfaces: all classes and talent edits still work, skills show
only unlock/upgrade levels, and race/racials and extra tools disappear. Turn it off and confirm the
library, gear, selected highlights and full skill tools return. Check colored class-skill boxes and
Clear highlights within the reduced view; hidden racial selections must not paint the tree. Enter
from a leveling preview and confirm editing resumes. Verify the preference persists locally, remains
independent of FL1 library imports, and never hides browser recovery controls.

## Native release checks

Use the Forever client with the matching interface version. Check window fitting at multiple
resolutions/UI scales, reading logged-in talents/stats, key binding discovery, tooltip fallback, and
whispers with another addon user. Automated API mocks do not establish that live client APIs or chat
delivery work on every client patch.

## Simulator and character checks

`tests/test_simulation.lua` covers hand-calculated direct/tick/shield/AP/weapon examples, scope
exclusions, reported-crit normalization, gear/attribute effects, capture deltas, isolated temporary
inputs, portable FS1/FS2/FC1/FL1 data, corruption rejection and every captured effect model. Native
UI checks exercise real button callbacks, nested X/Escape navigation, discarded gear edits,
temporary simulator input retention, legacy/modern spellbook capture, incomplete-import rejection,
independent profile creation and stable recycled highlight colors. Captured training records are
validated and transferred through FC1/FS2/FL1, including exact Lua 5.1/WASM string comparison. The
browser-engine parity suite compares central workspaces, resolved inputs, results and exact export
strings to Lua 5.1.

For release QA, use an isolated browser origin. Check desktop, 320/375 px phones, tablet and
landscape; enter gear/stats, calculate multiple effects, paste invalid and valid inputs, and confirm
the central character remains intact. Test the production service worker with the preview server
stopped, then accept a new bundle and confirm character/equipment and saved build branches remain. A
browser or mocked-frame check is not verification of the native live WoW client.

## Version 1.2.0 validation

The release passed the shared/native verification gate, browser-engine parity, format checks, Python
lint/format checks and archive validation. The reviewed CSV replay matches all 728 simulator models
and reported-crit flags in the canonical catalog.

Production browser checks covered desktop, 1600 px desktop, tablet, 320/375 px phones and landscape:
custom gear and central stats, live temporary results, valid/damaged character and skill-input
strings, full-library deduplication, sibling checkpoints, shield/heal/cost controls, keyboard focus,
horizontal fit and sticky result visibility. Update acceptance preserved character gear and branch
history. With the local server stopped, reload and calculation still worked with those saves.

Live WoW character/item capture and native visual behavior still require in-client verification; API
fixtures and browser screenshots do not establish live-client compatibility.

## Version 1.2.1 validation

Passed 50,010 native assertions, five browser-engine tests, exact native/WASM parity, generated-file
drift checks, the production build, format/lint checks and addon archive validation. Reduced-view
tests cover all nine classes, live skill rank progression, talent unlock requirements, local
preference persistence, preview exit, legal edits, undo/redo and full-view restoration. FT1/FC1/FL1
strings remain identical when the view changes; library imports keep the recipient's preference.

Production browser checks covered 320, 375, 600, 768, 1050, 1366 and 1600 px widths, plus 844×390
landscape. All class buttons stayed visible without horizontal overflow. Phone navigation retained
Trees / Skills, explicit talent edits and readable level-only skill dialogs. Keyboard toggling,
focus restoration, invalid allocation rejection, Auto and Undo/Redo worked. Switching the view
preserved the exact full-library export. Unreadable and newer save fixtures retained their original
data and exposed recovery controls in Simple view.

Accepting the final service-worker update preserved saved branches, character gear and the view
preference. With the preview server paused, reload and skill rank inspection still worked. Native
mock geometry was reviewed for the compact window, Settings and skill-level dialog; live WoW visual
behavior remains unverified.

## Version 1.2.3 validation

Passed 50,353 native assertions, seven browser-engine tests, exact Lua 5.1/WASM sharing parity,
generated-file drift checks, production build, formatting and archive validation. Regression tests
exercise the actual button callback that previously failed SetText, X/Escape parent navigation,
simulator override retention, discarded gear edits, native spellbook API variants, incomplete
capture rejection, malformed training recovery and independent profile creation.

Production browser checks covered desktop, 320/375 px phones, tablet and landscape. Nested
character/gear/sharing/input screens returned to their parent; temporary simulator values remained.
Library refreshed after New build and retained the previous profile's checkpoint count. Six checked
skills used distinct colors, the seventh reused the first, and shared talents showed multiple
markers. Damaged imports were rejected; a native FC1 fixture round-tripped as the exact same string.
Trained ranks survived stats import, update acceptance and an offline reload. The service-worker
update preserved saved profiles, checkpoints and gear. With the preview server stopped, reload,
trained filtering, Library and full-library export still worked.

Native behavior was exercised through API fixtures and the addon callback harness. Live client
loading, live captures and native visual behavior still require in-game verification.

## Version 1.2.4 validation

Passed 51,993 native assertions, seven browser-engine tests, exact Lua 5.1/WASM format parity,
generated-file checks, production build, formatting and archive validation. Forever-specific
C_Traits fixtures cover all nine classes at zero, partial and 51 points; active second spec-group
selection; arbitrary node order and IDs; purchased versus granted ranks; incomplete records; missing
definitions; changed maximum ranks; point-total mismatches; duplicates; pending edits and
configuration changes during capture. Failed imports preserve both the draft and Character.

The adapter follows the Forever client's
[talent window](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_PlayerSpells/Camelot/ClassTalents/Blizzard_ClassTalentsFrame.lua)
and its
[documented trait API](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/SharedTraitsDocumentation.lua).
The previous Classic API fixtures did not cover this path. Live character capture still needs
in-game verification; fixture results are not evidence of live client behavior.

Production browser checks covered 320/375 px phones, 844×390 landscape, 1024 px tablet and 1280 px
desktop. They verified the new capture guidance without horizontal overflow, keyboard closing and
scrollable long help text, character preview and damaged-string rejection, trained-rank filtering,
and an exact native FC1 round trip. Updating from 1.2.3 preserved the entire test library byte for
byte, including profiles, checkpoints, class drafts and Character. With the preview server stopped,
1.2.4 reloaded offline and retained talents, trained ranks, saved builds and library export.

## Version 1.2.5 validation

Passed 52,073 native assertions, seven browser-engine tests, generated-file checks, the production
build, formatting/lint checks and addon archive validation. Native regressions invoke actual
talent-order OnEnter/OnLeave and skill-to-talent OnClick callbacks. They verify unnamed temporary
highlights, retained checkbox selections and colors, restoring pinned highlights, unchanged build
strings, clear-all behavior and suppression in Classic mode.

Production browser checks covered desktop, 320/375 px phones, 844×390 landscape and 1024 px tablet.
Keyboard focus highlighted the order entry’s talent without editing the build, retained both pinned
colors and restored the exact pinned highlight map on leaving. Skill-to-talent links, level
previews, clear-all and Simple view worked; phone tap descriptions and order previews stayed
accessible without horizontal overflow. The console reported no errors.

Updating from 1.2.4 preserved the test library byte for byte. After stopping the preview server,
1.2.5 reloaded offline, highlighted order entries and exported the identical full library. Installed
files matched the verified archive, and the recoverable backup matched the previous addon. Player
SavedVariables were preserved. Native callbacks were verified in the Lua harness; live WoW loading
and visual behavior still need in-game verification.

## Version 1.2.6 validation

Passed 53,104 native assertions, eight browser-engine tests, exact Lua 5.1/WASM training-report and
sharing parity, generated-file checks, formatting, the production build and addon archive
validation. Training regressions cover all nine classes, missing and unmatched captures, higher
imported ranks, talent-granted skills, unlock requirements, future rank boundaries and overdue
training. The native callback harness verifies the checkbox, count shortcut, filter, tooltips,
Classic view and preference persistence. Toggling comparison leaves portable library strings and
undo history unchanged; library imports retain the recipient's local preference.

Production browser checks covered 320/375 px phones, 844×390 landscape, 1024 px tablet and 1280 px
desktop without horizontal overflow. The checkbox and count shortcut have 44 px touch targets.
Skills distinguish new abilities from rank upgrades, and tap-accessible details explain the next
unlock. Level buttons changed Wrath's countdown from five levels at 25 to one at 29, then an
available rank upgrade at 30. Simple view, keyboard toggling, missing-import guidance, empty
searches and damaged-string rejection worked. A native FC1 capture round-tripped exactly. The
console reported no errors.

Updating from 1.2.5 preserved the test library exactly. Subsequent cache updates retained the
imported spellbook and enabled preference. After stopping the preview server, offline reload kept
the comparison and filter functional and exported the identical full library. Installed files
matched the source package, the recoverable backup matched the previous addon, and player saves and
other addons were unchanged. Native callbacks were verified in the harness; live WoW loading,
spellbook captures and visual behavior still require in-game verification.

## Version 1.2.7 validation

Passed 55,231 native assertions, nine browser-engine tests, exact Lua 5.1/WASM parity,
generated-file checks, formatting, production build and archive validation. Progression regressions
cover every class's live skill ranks, skipped archived records, first unlocks, maximum ranks, talent
unlocks, unranked abilities and captured ranks that no longer match. They distinguish the displayed
imported rank from a newer training target and exercise the actual native row and Classic view
without changing portable library strings.

Production browser checks covered 320/375 px phones, 844×390 landscape, 1024 px tablet and 1280 px
desktop. Arcane Shot showed its next rank at level 12; Hunter's Mark showed Max rank 4 at level 58;
Call Pet and talent skills showed their first unlock. Simple view retained the same labels, and
keyboard activation opened the rank-level sheet. The next-rank line remained readable alongside the
imported-character countdown without horizontal overflow. The console reported no errors.

Updating from 1.2.6 preserved the entire test library and comparison preference. With the preview
server stopped, the new progression labels reloaded offline and the full-library export remained
identical. Installed files matched source, the recoverable backup matched the previous addon, and
player saves and other addons were unchanged. Native behavior was checked in the callback harness;
live WoW loading and native visual behavior still require in-game verification.

## Version 1.2.8 validation

Passed 55,664 native assertions, eleven browser-engine tests, exact Lua 5.1/WASM sharing parity,
generated-file checks, production build, formatting and archive validation. Build-link regressions
cover all nine classes, 51 ordered points, URL escaping, corrupted or foreign links, unsupported
payloads, safe previews, unchanged libraries, Auto restoration through Undo, and leveling-prefix
exports. The native callback harness verifies string/link selection, preserved FT1 whispers, link
import, precise skill-level labels, trained rank sources, locked talent inspection, Alt-click,
allocation controls and returning from related skills. Existing saved-data recovery, branch deletion
and randomized edit regressions also pass.

Production browser checks covered 320/375 px phones, 844×390 landscape, 1024 px tablet and 1280 px
desktop without horizontal overflow. Mobile inspection leaves the tree interactive, keeps point
controls visible, outlines the selected node and scrolls long descriptions independently.
Add/remove, switching talents, compact new selections, expanded related-skill navigation, X and
Escape worked. Desktop tooltips list affected skills; Alt-click and keyboard Enter open full
details, and closing a related skill returns to its talent. Locked additions are disabled. Skill
rows showed Shred’s first unlock at 22, rank 3 at 38, next rank 4 at 46, and maximum rank 5 at 54.
Trained captures remain marked, reached next-rank levels use an open lock, and maximum rows have no
duplicate secondary line. Classic / Simple view follows the same records.

Native FC1 and build-link exports matched the browser byte for byte, and the copy button copied the
exact native link. Incoming links preview before loading; Cancel leaves the full library intact,
damaged links disable Load, and explicit import round-trips the point order. Updating from 1.2.7
preserved the entire test library exactly; subsequent coherent cache updates also preserved saves.
With the preview server stopped, link preview/loading, the talent panel and Undo/Redo worked
offline, and the full-library export remained identical before edits.

Installed files match the verified source package, and the recoverable backup matches the previous
addon. Player SavedVariables and other addons were unchanged. Native callbacks were checked in the
harness; live WoW loading and native visual behavior still require in-game verification.

## Version 1.2.9 validation

Passed native regression suites, eleven browser-engine tests, exact Lua 5.1/WASM calculations and
sharing parity, generated-file checks, production build and addon archive validation. New cases
cover Holy Light at 46/49/50/53/54/60, player/helper rank aliases, cosmetic Polymorph captures,
Shadow Bolt rank 10, training comparison, preserved captured IDs, Eureka omission warnings and
explicit manual models for unsupported scripted casts. The compatibility tag remains 7ba43a60.

Production browser checks covered desktop, 320/375 px phones, 768 px tablet and 812×375 landscape.
Holy Light displays nine player ranks, rank 7 through level 53, and rank 8 unlocking at 54. Gnome
simulations show the Eureka limitation. Mutilate displays four cast ranks and offers an explicit
manual model; entered amounts update its labelled result. Fox's announced reference note stays
readable without horizontal overflow. X and Escape return to the parent skill screen.

Updating from 1.2.8 retained the saved build, allocation order and starting checkpoint. With the
preview server stopped, 1.2.9 reloaded offline and recovered that build and checkpoint. The browser
console reported no errors. Native callbacks were verified in the API harness; live WoW loading,
capture and native visual behavior remain unverified. No installed addon files were changed.

## Version 1.2.10 validation

Passed the native regression suites, fifteen browser-engine tests, exact Lua 5.1/WASM sharing
parity, generated-file checks, production build, formatting and archive validation. Removal tests
cover every talent in full builds across all nine classes: legal surviving allocations retain all
other ranks, every leveling prefix validates, and genuine prerequisite/tier failures stay blocked.
The reported Mage Fire sequence now allows the first two Incineration removals. Undo restores the
original order and immutable checkpoints.

Checkpoint tests cover automatic child snapshots, identical-child reuse, cross-class navigation,
read-only/capacity failures, subtree deletion, saved-data recovery and visible working drafts. The
exact level-60/five-point reproduction restores level 60, explicitly disables conflicting Auto,
shows skills for level 60 and remains clean. Undo/Redo restore their respective level modes. Saving
after Undo clears stale Redo without changing the new profile's name or association; failed saves
preserve history. Native sidebar and expanded graph labels show saved target levels.

FP1 tests cover full checkpoint trees and working drafts, exact addon/PWA exports, malformed or
corrupted payloads, wrong versions/data tags, invalid graphs, deduplication, library recovery and
large trees that require a string/file. Single-profile exports contain no other profiles, character
stats or equipment. Existing FT1/FS2/FC1/FL1 formats retain exact native/WASM parity.

Production browser checks covered 1280 px desktop, 320/375 px phones, 844×390 landscape and 1024 px
tablet without horizontal page overflow. Desktop right-click removal, keyboard inspection, phone
point controls, visible current drafts, checkpoint switching and full-profile link previews worked.
An incoming four-node tree opened at its selected draft without removing the recipient's existing
build. Damaged links disabled Open; Cancel kept the current build. The copy button produced the
exact complete-profile link.

Updating the previous cached release preserved the test library and checkpoints. With both preview
servers stopped, reload recovered every profile, node, point order and character setting; checkpoint
navigation, Undo/Redo and incoming link previews worked offline. The first reload normalized
optional saved flags, and the second reload produced an identical full-library export. Browser
console checks reported no errors. Native callbacks were verified in the API harness; live WoW
loading and native visual behavior remain unverified. No installed addon files were changed.

## Version 1.2.11 validation

Passed 119,166 native assertions and nineteen browser tests, including exact Lua 5.1/WASM sharing
parity, the reported Feral allocation, legal support-point replacement, blocked-removal immutability
and checkpoint-safe undo/redo. Update-monitor tests cover current, downloading, waiting, offline
failure, synchronous failure/retry, concurrent checks and cache-install failure. Generated outputs,
formatting, Python checks, the production build and addon archive validation passed.

Native callbacks cover opening the full workspace from Checkpoints, wrapped titles, saving and
sharing back to the graph, deletion cancellation, deep selected-node visibility, horizontal bounds,
manual scroll retention and returning to the root. These use the native Lua callback harness;
in-game appearance and live-client interaction still need client verification.

Production browser checks covered 320/375 px phones, 844×390 landscape, 1024 px tablet and 1280/1600
px desktop. Repeated talent +/− edits retained the exact main scroll position, selected-node
position and panel height through zero and maximum rank. Expanded details stayed open, with their
own scrolling and fixed point controls. Orientation changes kept inspection usable. Dedicated
checkpoint workspaces showed long titles, selected branches and separate talent order without page
overflow; keyboard graph scrolling, sharing all branches, corrupt-link rejection and deletion
cancellation worked. Simple view retained talent editing and restored the full tools afterward.

Cached updates retained the full test library byte for byte. Manual checks reported current,
downloading, ready and network failure accurately. With the preview server stopped, the app reloaded
offline and exported the identical library. Browser test data and screenshots stayed outside the
repository; no production browser saves or game SavedVariables were changed.

## Version 1.2.12 validation

Passed the seventeen native suites and twenty browser tests, including exact native Lua 5.1/WASM
command and sharing parity. Checkpoint updates validate before mutation, replace only the selected
snapshot, retain metadata and all descendants/siblings, clear stale Redo after an actual update, and
reject preview, invalid-class/build and read-only saves. Updated nodes survive library export,
profile transfer, saved-data reload, navigation, undo/edit/update and subtree deletion.

FP1 profile strings and links now exclude unsaved drafts without mutating the source library. Native
and browser tests verify saved node counts, selected snapshots, stable links while editing, changed
links after updating, corrupted imports, recovery, deduplication and existing formats. Full-library
exports still include class drafts.

Production UI checks covered desktop, 320/375 px phones, 844×390 landscape and 1024 px tablet with
no horizontal page overflow. Phone actions have 44 px targets. Update checkpoint works by keyboard
and click, keeps all branches, and clean navigation creates no additional nodes. New checkpoint
still creates a child. The selected checkpoint title is visible above the graph.

The complete cache update retained a byte-identical test library, including an unsaved draft. With
the local server stopped, offline reload retained an identical library; checkpoint updates, new
branches and navigation worked offline. A parent update kept both children's distinct saved levels
and point orders. Browser console checks reported no errors. Native callbacks were checked in the
API harness; live WoW visual behavior remains unverified. No game installation or player
SavedVariables were changed.

## Version 1.2.13 validation

Passed eighteen native suites and twenty-one browser tests, including exact native Lua 5.1/WASM
operation and sharing parity for all nine classes. Explicit checkpoint updates retain the graph;
loading never creates nodes, and Undo restores unsaved edits and profile context. Tests cover
Auto/saved levels, stale Redo, read-only saves, reload recovery, branching and subtree deletion. FA1
checks class, data tag, checksum, ordinals, rank limits, tier gates and point budget before
mutation. Copy/paste retains destination context and character data, rejects insufficient manual
levels and preview edits, and participates in Undo/Redo.

Production browser checks covered desktop, 390 and 320 px phones, and 844×390 landscape without
horizontal page overflow. Active titles and saved/unsaved status appear above the planner, inside
the graph workspace and in phone talent details. A long active node title fits its 84 px card at 320
px. Update retains node counts; Save as new checkpoint creates a child only after confirmation.
Valid native-generated FA1 pasted into the PWA retains level 55 and its selected checkpoint; damaged
input disables Apply. Browser clipboard automation uses a separate clipboard binding, so system
clipboard round-trip was not established by that check.

Simple view retains colored skill checkboxes, six-color shared highlighting and Clear highlights;
racials and advanced tools stay hidden. Phone skill clicks show only unlock/rank levels. Native
callback tests verify the top-left toggle, mode persistence, all classes, selected colors and
clearing. Live WoW visual behavior remains unverified.

A production cache update from 1.2.12 retained a byte-identical 60,778-character full library. With
the preview server stopped, offline reload retained the updated 65,882-character library exactly;
failed update checks correctly report a connection failure. Browser error logs were empty before the
intentional offline test. Player SavedVariables and the game install were not changed.

## Version 1.2.14 validation

Passed nineteen native suites and twenty-two browser tests, including exact native Lua 5.1/WASM
operations and portable sharing parity for all nine classes. The Compact view suite checks the true
talent grid, independent window positions, saved-data reload, corrupted-position fallback,
resolution fitting, stable scroll during point edits, skill colors, Simple view compatibility,
full-layout restoration and experimental-tool navigation. Visibility changes retain exact build,
character and library strings and do not change calculations or undo history.

Production browser checks covered desktop, 320/390 px phones, 768 px tablet, 844×390 landscape and
the 1050 px transition. All nine class buttons and Settings remain visible without horizontal page
overflow. Phone Settings has a 44 px touch target; keyboard Space toggles the preference. Character,
rank simulator buttons and the mobile More entry hide together. Skill ranks remain readable and
Simple view keeps Settings accessible. Re-enabling restores experimental headings and tools.

Accepting the 1.2.14 service-worker update preserved a byte-identical 65,882-character test library,
including branches and unsaved edits. Visibility changes also preserved the identical export and
persisted after reload. With the preview server stopped, offline startup kept the identical library
and hidden tools; browser error logs were empty. Native callbacks and fitting were checked in the
API harness; live WoW visual behavior and simulator accuracy remain unverified. No game install or
SavedVariables were changed.

## Version 1.2.16 validation

Passed 20 native suites and 23 browser tests, including 112 focused October-update assertions, exact
Lua 5.1/WASM migration and sharing parity, generated-file checks, formatting, the production build
and addon archive validation. Regressions cover the known previous catalog, unknown catalog
rejection, original-allocation exports, multiple checkpoint branches, legal repairs, undo/redo,
legacy/current character and stats formats, level growth caps, all Penance ranks and separate
damage/healing modes, proc intervals and Natural Instinct without duplicate capture bonuses.

Production UI checks used synthetic libraries on isolated local origins. Desktop and 320/390 px
phones, 1024 px tablet and 844×390 landscape had no horizontal overflow. The repair notice retained
all three imported branches; removing Impale through the phone sheet kept the page scroll position,
and Update checkpoint replaced only the selected snapshot. The original remained exportable.

A real service-worker update from 1.2.15 to 1.2.16 offered Update now and preserved two saved
level-60, 16-point checkpoints, their titles and selection. The new prerequisite repair notice
appeared without reallocating any points. After stopping the server, offline reload worked and
produced an identical full-library export. The browser console reported no errors.

Native UI callbacks and loading were exercised in the Lua API harness. Live WoW loading, visual
behavior, combat estimates and character capture still require in-game verification. Shield crit
behavior and Fox family membership remain explicitly unverified.
