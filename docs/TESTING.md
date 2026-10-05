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

## Native release checks

Use the Forever client with the matching interface version. Check window fitting at multiple
resolutions/UI scales, reading logged-in talents/stats, key binding discovery, tooltip fallback, and
whispers with another addon user. Automated API mocks do not establish that live client APIs or chat
delivery work on every client patch.

## Simulator and character checks

`tests/test_simulation.lua` covers hand-calculated direct/tick/shield/AP/weapon examples, scope
exclusions, reported-crit normalization, gear/attribute effects, capture deltas, isolated temporary
inputs, portable FS1/FS2/FC1/FL1 data, corruption rejection and every captured effect model. Native
UI checks exercise custom item editing and character/skill separation. The browser-engine parity
suite compares central workspaces, resolved inputs, results and exact export strings to Lua 5.1.

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
