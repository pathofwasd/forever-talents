# Forever Talents

A talent planner for World of Warcraft Forever, available as an in-game addon and an offline web app
for desktop and mobile.

## Install the addon

Download **ForeverTalents.zip** from Releases, extract it, and place the **ForeverTalents** folder
in your Forever client's **Interface/AddOns** folder. The final path should be
`Interface/AddOns/ForeverTalents/ForeverTalents.toc`. Enable it in the character-selection AddOns
menu, then type `/ftc` in game. There are no addon dependencies.

To update, replace only the addon folder. Your saved builds live separately in WoW's `WTF` folder;
keep that folder when updating. The included [guide](addon/ForeverTalents/README.txt) explains
controls and sharing.

## Plan and share

- Nine classes with their authentic talent grids, rank descriptions, prerequisites, legal point
  order, and race restrictions.
- Searchable skills, rank unlock levels, racials, and persistent checkboxes highlighting related
  talents.
- Manual or automatic level, undo/redo, leveling previews, named builds, and branching checkpoints.
  Removing a checkpoint removes its descendants.
- Copy/paste builds, character setups, simulation stats, or the whole library between the addon and
  web app. Addon whispers also support clickable receipts.
- Simple and advanced per-use damage/healing estimates with editable assumptions. These estimates do
  not model a complete combat rotation.

Sharing formats: **FT1** for one build, **FC1** for character setup, **FS1** for simulation stats,
and **FL1** for the whole saved library. Import previews and validates the string before loading.
Export FL1 periodically as a backup.

## Web and mobile

The web app runs the same Lua engine and catalog as the addon. It works offline after its first
successful cache installation and can be installed from a supported browser. Saves stay on your
device; there is no account or cloud service. Export your library before clearing browser data or
switching sites.

The browser imports character snapshots captured in the addon. Reading live WoW stats/talents and
sending game whispers require the in-game client. See the [web guide](web/README.md) for
installation and deployment details.

## Develop

Requirements: Node.js 22.12+ or 24+, pnpm 11.19.0, Python 3.11+, Pillow, and Lua 5.1 with `luac5.1`.
Python tooling can be installed in a virtual environment with `pip install -r requirements-dev.txt`.

```sh
pnpm install --frozen-lockfile
pnpm dev
pnpm verify
pnpm build
python3 tools/package_addon.py
python3 tools/check_package.py
```

`pnpm build` creates the static site in `web/dist/` and its ZIP in `dist/`. `package_addon.py`
creates both a versioned ZIP and `ForeverTalents.zip`. No build tools are needed by users of either
packaged application.

Edit shared behavior in `core/lua/`, and catalog content in `data/catalog.json`. Build commands
generate platform copies; do not edit those copies directly. See [development guidance](AGENTS.md),
[feature ownership](docs/FEATURE-PARITY.md), and [data documentation](docs/DATA.md). Addon updates
must also update the PWA, including its phone layouts.

## Data and license

The bundled snapshot covers Forever 1.60.1, build 69876, collected October 4, 2026. Later game
patches may differ. The code is MIT licensed; game data and artwork retain their owners' rights. See
[LICENSE.txt](LICENSE.txt) and [NOTICE.txt](NOTICE.txt). Third-party runtime licenses are included
in web builds.
