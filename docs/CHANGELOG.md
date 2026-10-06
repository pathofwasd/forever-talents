# Changelog

## 1.2.4

Fixed live talent import for Forever’s C_Traits combat configurations. The importer reads the active
spec group, matches talent spell definitions, checks every rank and point total, and keeps the
current build on incomplete data or pending game talent edits. Character captures and portable
sharing use the corrected reader; the web guide explains the native capture steps. See
[release notes](RELEASE-1.2.4.md).

## 1.2.3

Nested screens now return to their parent with X or Escape, preserving temporary simulator inputs.
Fixed Character's copy/paste button error, added one-click native talents/trained-skills capture and
portable trained-rank snapshots, clarified Library's New build action, and added six matching
checkbox/talent highlight colors with overlap markers. Both interfaces retain existing saves and
sharing compatibility. See [release notes](RELEASE-1.2.3.md).

## 1.2.2

Corrected October 1 Druid/Warrior descriptions and Berserker Rage's level-30 unlock. Removed Tiger's
Fury from the current skill browser. Restored the talent-granted first rank of 31 abilities in the
shared engine, including the Classic/Simple progression view. Added 23 first-rank simulator models
from the existing verified client snapshot; unsupported scripted effects remain labeled. Talent
layout, saved builds and sharing compatibility are unchanged. See [release notes](RELEASE-1.2.2.md).

## 1.2.1

Added optional Classic mode in addon Settings and a visible Simple view checkbox on desktop/mobile
web. Both reduce the interface to class, talent trees and skill unlock/upgrade levels. Extra tools
are hidden; existing data, Auto level and Undo/Redo stay intact. The reduced view uses the same
catalog and engine, remembers its setting locally and keeps full-library sharing unchanged. See
[release notes](RELEASE-1.2.1.md).

## 1.2.0

Rebuilt the per-use Simulator from reviewed client effects and documented corrections. Added a
central character/equipment workspace, native stats/item capture, portable FS2 gear sharing and
scoped simulator experiments. Results now distinguish direct effects, ticks, shields and health
costs, expose applicable inputs, and include formulas, evidence and missing-mechanic notes. The PWA
uses the same engine and adds a responsive workspace and live phone result summary. Existing
FT1/FS1/FC1/FL1 data remains supported. See [Simulator](SIMULATOR.md) and
[release notes](RELEASE-1.2.0.md).

## 1.1.2

- Consolidate the catalog and local assets into a self-contained build pipeline.
- Format shared Lua, native interface, and web sources for maintenance.
- Replace historical development notes with installation, data, and parity guides.
- Keep existing portable sharing strings and saved-library compatibility.
- Keep every class visible at tablet widths and use labeled touch targets on phones.
- Start detail dialogs at the top, label them for screen readers, and give the close control a
  larger touch target.
- Add desktop/mobile screenshots, a shorter installation README, and GitHub Pages deployment setup.
- Identify the project as free and unofficial in both guides and the browser footer; link the
  browser footer to the offline ownership notice.
