# Forever Talents: addon first, shared engine, desktop and mobile PWA

## Required update workflow

Every addon update must be reflected in the web/mobile PWA in the same change. Develop and validate
the addon behavior first, then verify the PWA reflects it. Do not finish an addon update while a
supported PWA feature remains stale. If a feature requires the live WoW client (character import,
whispers, client spell fallback), explain that boundary in the PWA and keep text sharing available.

## Ownership and single sources of truth

- `core/lua/` owns allocation rules, build encoding, skill links, character/stats/library sharing,
  numerical estimates and build/profile/history behavior. Edit these Lua modules once.
- `data/` and `tools/build_data.py` own the normalized catalog, local icons and generated addon
  data. Do not create hand-maintained web talent tables or rule implementations.
- `tools/sync_core.py` generates addon module copies and the browser engine bundle from the shared
  Lua source. Do not edit generated copies to fix behavior.
- `addon/ForeverTalents/UI/`, Bootstrap and Comms own native WoW interactions.
- `web/src/` owns the responsive browser interface, browser storage adapter,
  installation/offline/update behavior, clipboard and browser accessibility.
- The PWA runs the shared Lua engine through a locally bundled WASM runtime. JavaScript must not
  duplicate talent validation, codecs, profile graph mutation or the numerical engine. The bridge
  may convert tables and adapt platform APIs.

## Interface parity

Keep talent grids, prerequisite links, descriptions, ordering, skill/racial highlight selections,
Auto level, undo/redo, sharing, character/stats/library sync and checkpoint branches in sync. UI
improvements must be implemented in both interfaces when applicable. Use native mouse/keyboard
conventions on desktop and explicit accessible touch controls on phones. Mobile must retain the true
tree layout; use tree tabs, tap descriptions and clear add/remove controls rather than shrinking
three trees into unreadable icons. Test narrow screens and landscape/tablet layouts. Do not call a
mock/browser screenshot proof of native WoW behavior.

## Required verification and releases

Run `python3 tools/verify.py` (or `pnpm verify`), `pnpm build`, and browser verification of changed
flows. Verify invalid imports, exact addon/PWA share strings, saved-data recovery, branch deletion
and undo/redo whenever their behavior changes. For PWA changes, verify offline reload and coherent
service-worker updates without losing saves. Check desktop and mobile layouts, keyboard access,
touch targets and long text. Update the feature-parity document and relevant guide/release notes.

Keep addon and PWA releases tied to the same source version and data tag. Build outputs are
generated; commit source, lockfile and instructions, not node_modules, PWA output, distribution ZIPs
or temporary QA dumps. Preserve player SavedVariables and browser saves. Make recoverable backups
outside AddOns before replacing installed addon files. Do not push, publish, or deploy externally
unless the user requests it. A local preview is appropriate.

Keep build tools self-contained: data/catalog.json is the canonical catalog, and data/icons/
contains the local image inputs. Preserve existing talent ordering and compatibility tags unless a
deliberate migration is required. Keep personal paths, credentials, acquisition logs and temporary
QA output outside the repository. Retain copyright and third-party license notices. Do not
misrepresent authorship or rights to game content.
