# Forever Talents PWA

The browser app runs the shared Lua engine through Wasmoon (Lua 5.4/WebAssembly). Desktop and touch
layouts use the same catalog and bundled icons as the addon. It works offline once the status shows
**Ready offline**.

Forever Talents is a free, unofficial community project. The footer identifies game-content
ownership and links to the bundled `NOTICE.txt`, which remains available offline.

Check **Simple view** above the class picker for class, talent trees and skill levels only. Race,
racials, character/simulator, sharing and checkpoint tools are hidden. Click a skill for its unlock
and upgrade levels. Phones keep Trees / Skills tabs and the normal talent Add / Remove controls.
Uncheck to restore the full view with all saved data intact. The preference is local to this device
and survives reloads; library imports do not change it. Talent data and rules are shared with the
full view, so future catalog updates apply to both.

## Develop and package

Follow the root [development setup](../CONTRIBUTING.md), then run:

```sh
pnpm install --frozen-lockfile
pnpm dev
pnpm test
pnpm build
pnpm preview
```

`npm` can run the scripts too, but pnpm owns the dependency lockfile. The local preview listens at
http://localhost:4173. `web/dist/` is the complete static site; `dist/ForeverTalents-PWA-1.2.1.zip`
is its release archive. Neither needs Node, Python, a server database or a CDN on the hosting
service.

Serve the directory through HTTP for local use, or deploy it on an HTTPS static host for
sharing/installation on other devices. Opening index.html as a local file does not provide fetch,
service-worker or clipboard support. Use a stable URL so browser saves stay with the same origin.
The relative manifest, engine, WASM, icon and cache paths support a subdirectory deployment. Do not
expose the development server publicly. See [GitHub Pages setup](../docs/HOSTING.md) to publish the
production build.

On Windows/Linux/Android, use an install-capable browser's Install menu. On iPhone/iPad, open in
Safari, Share → Add to Home Screen. Browser and OS support determine the available install prompt. A
hosted URL is required for a phone; another device's localhost refers to that device.

## Experimental tools

Open **Settings** above the class picker, or in the phone's More section. Uncheck **Show
experimental simulator** to hide Character and simulator buttons, including those in rank details.
Saved stats, equipment and builds stay intact. This preference persists on the device; library sync
keeps the recipient's setting. Estimates are experimental and have not been validated in live
gameplay.

## Updates and saves

An entire release is precached before its service worker becomes ready. The engine is
content-addressed, like the JS/CSS shell, to prevent mixed versions. New releases show Update now;
local saves are written before reloading. Keep previous immutable build assets available during a
real hosting rollout. The generated worker retains recent release caches while old clients finish.

Local storage contains the same logical schema as addon SavedVariables, with separate device
ownership. Export FL1 for portable backups and merges. No telemetry, account, cloud sync or live
connection to WoW is used. Updates do not remove saved libraries. Clearing site data or changing
origins can remove access to a library, so export first. Newer/unreadable browser saves disable
writing; a recovery banner offers the original saved-data download in either view.

## Sharing

- FT1: talent allocation, exact ordered spending, race and target level.
- FC1: those talents and level plus central character stats and custom/captured equipment.
- FS2: character stats/equipment or temporary skill inputs. FS1 remains supported.
- FL1: all saved profiles, checkpoint branches, class drafts, undo/redo and character workspaces.

Share → choose format → Copy string or Save to file. Import previews strings before loading. Library
imports merge profiles, skipping exact duplicates. Replacing class drafts is a separate explicit
checkbox. Existing saves can be backed up with a whole-library export before importing. Native
window settings and received whisper receipts stay on their own platform.

In-game Character can capture live talents, stats and available gear, or copy a planned setup. Paste
the same string here. Live talent order is reconstructed because the client does not expose the
original spending history. A browser cannot read WoW APIs or send addon whispers; clickable in-game
receipts remain addon-only.

Character holds the shared gear/stat workspace. Simulator edits and its Paste skill inputs control
are temporary; they leave that character unchanged. See the [simulator guide](../docs/SIMULATOR.md)
for formulas, evidence and accuracy limits.

See [feature ownership](../docs/FEATURE-PARITY.md) and [update requirements](../AGENTS.md) before
editing either platform. Release packages include content ownership notices and bundled software
licenses.
