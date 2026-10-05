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
