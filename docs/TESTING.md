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
library, gear, selected highlights and full skill tools return. Enter from a leveling preview and
confirm editing resumes. Verify the preference persists locally, remains independent of FL1 library
imports, and never hides browser recovery controls.

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
