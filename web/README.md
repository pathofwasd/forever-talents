# Forever Talents PWA

The browser app runs the shared Lua engine through Wasmoon (Lua 5.4/WebAssembly). Desktop and touch
layouts use the same catalog and bundled icons as the addon. It works offline once the status shows
**Ready offline**.

Forever Talents is a free, unofficial community project. The footer identifies game-content
ownership and links to the bundled `NOTICE.txt`, which remains available offline.

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
http://localhost:4173. `web/dist/` is the complete static site; `dist/ForeverTalents-PWA-1.2.0.zip`
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

## Updates and saves

An entire release is precached before its service worker becomes ready. The engine is
content-addressed, like the JS/CSS shell, to prevent mixed versions. New releases show Update now;
local saves are written before reloading. Keep previous immutable build assets available during a
real hosting rollout. The generated worker retains recent release caches while old clients finish.

Local storage contains the same logical schema as addon SavedVariables, with separate device
ownership. Export FL1 for portable backups and merges. No telemetry, account, cloud sync or live
connection to WoW is used. Updates do not remove saved libraries. Clearing site data or changing
origins can remove access to a library, so export first. Newer/unreadable browser saves disable
writing; the More view offers the original saved-data download.

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
