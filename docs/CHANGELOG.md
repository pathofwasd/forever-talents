# Changelog

## 1.2.8

Share builds with a browser link from the addon or PWA. Opening one previews the class, race, level
and exact talent order before loading an undoable draft; existing saves stay intact. Both interfaces
accept links through Import. Mobile talent details now open in a bottom panel with pinned point
controls while the tree remains interactive. Skill rows distinguish first unlock and current rank
level, show a lock beside the next rank until its level is reached, and remove the duplicate
max-rank line. Imported ranks retain a Trained marker. See [release notes](RELEASE-1.2.8.md).

Talent tooltips list affected skills, and Alt-click opens the full talent inspector in both
interfaces. The native inspector adds rank descriptions, point controls and related-skill links
without changing right-click removal.

## 1.2.7

Skill rows show the next rank and its unlock level, or the maximum rank when no further upgrade
exists. Unlearned skills show their first unlock; abilities without upgrades are labeled
accordingly. The extra line follows the rank shown in the row, including imported ranks and training
targets, and works without enabling comparison in both the addon and PWA, including Classic / Simple
view. Game data and sharing formats are unchanged. See [release notes](RELEASE-1.2.7.md).

## 1.2.6

Added optional imported-character comparison in Skills & ranks: a training count, new/upgrade
indicators, Needs training filter and ↑N levels until the next rank or first unlock. Availability
follows the displayed level and talents; automatic talent grants and racials are excluded from
training tasks. The local preference defaults off and keeps saved builds and sharing unchanged.
Works in the addon and web/mobile app, including their reduced views. See
[release notes](RELEASE-1.2.6.md).

## 1.2.5

Fixed the Lua error when hovering talent-order entries and following skill-to-talent links.
Temporary talent highlights preserve checked skills and their colors. Web order entries now
highlight their talent on hover or keyboard focus through the shared engine. Existing builds,
character captures and sharing formats remain unchanged. See [release notes](RELEASE-1.2.5.md).

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
