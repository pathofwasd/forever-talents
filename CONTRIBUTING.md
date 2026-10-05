# Contributing

## Setup

Requirements: Node.js 22.12+ or 24+, pnpm 11.19.0, Python 3.11+, and Lua 5.1 with `luac5.1`.

```sh
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements-dev.txt
pnpm install --frozen-lockfile
pnpm dev
```

On Windows, activate the environment with `.venv\Scripts\activate`. The development site runs at
`http://localhost:4173`.

## Source layout

| Directory               | Contents                                                            |
| ----------------------- | ------------------------------------------------------------------- |
| `core/lua/`             | Allocation rules, sharing formats, saves, checkpoints and estimates |
| `data/`                 | Canonical catalog and local icon inputs                             |
| `addon/ForeverTalents/` | WoW interface, character capture and communication                  |
| `web/src/`              | Browser interface, storage, clipboard and installation              |
| `web/lua/bridge.lua`    | Browser adapter for the shared Lua engine                           |
| `tools/`                | Data compilation, source sync, packaging and verification           |
| `tests/`                | Native Lua and WebAssembly engine tests                             |

Change shared behavior in `core/lua/` and catalog content in `data/catalog.json`. `pnpm sync`
generates addon module copies and the browser engine; edit their source files.

Each addon change must include the corresponding browser behavior and phone controls. See
[AGENTS.md](AGENTS.md), [feature ownership](docs/FEATURE-PARITY.md) and
[catalog documentation](docs/DATA.md).

## Verification and packaging

```sh
pnpm verify
pnpm build
python3 tools/package_addon.py
python3 tools/check_package.py
pnpm format:check
ruff check tools
ruff format --check tools
```

`pnpm format` applies the JavaScript/Markdown and Lua formatters. Use `ruff format tools` for
Python. Follow the [release checks](docs/TESTING.md) for browser and in-game verification.

Build outputs:

- `web/dist/`: static website, including the offline cache and runtime licenses.
- `dist/ForeverTalents-PWA-<version>.zip`: packaged website.
- `dist/ForeverTalents-<version>.zip` and `dist/ForeverTalents.zip`: installable addon.

Keep addon and web versions aligned. Commit source, instructions and the lockfile; leave build
outputs, dependencies, credentials and temporary test results out of Git. Preserve saved player data
and back up installed addon files outside `AddOns` before replacing them.

## Reporting issues

Include the addon/app version, class and race, expected behavior, and steps to reproduce it. For
layout issues, include your screen size or game UI scale and a screenshot. For import issues,
include a sample string only if you are comfortable sharing the character or build details in it.
