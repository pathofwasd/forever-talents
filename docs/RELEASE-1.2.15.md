# Forever Talents 1.2.15

## What's changed

- Full skill rank descriptions now include base cast/channel time, instant/passive status, cooldown,
  global cooldown and range in the addon and web/mobile app. Missing values stay explicit.
- Fixed the addon error when opening the skills browser and compact tree tabs.
- Corrected Demonic Brand: Imp receives no extra threat; the tanking-pet Shadow effect does.
  Replaced the raw damage formula with readable text and marked conflicting beta proc counts.
- Added simulator notices for omitted Demonic Brand pet damage/threat and Demonic Knowledge's
  conditional spell-power bonus. The simulator remains experimental.
- Checked all nine current talent grids. Existing builds, checkpoints, libraries and sharing remain
  compatible. Exact rank/unlock values are retained where beta overview text disagrees.

Reviewed published information through October 8. Blizzard's announced October 8 maintenance notes
were still pending at the final source check; unpublished balance changes are not included.

## Download and install

Scroll to **Assets** below and download **ForeverTalents.zip**. Expand Assets if needed. The
**Source code** archives are for development.

1. Close World of Warcraft.
2. Extract the ZIP and copy **ForeverTalents** into the Forever client's `Interface/AddOns` folder.
3. Check that `Interface/AddOns/ForeverTalents/ForeverTalents.toc` exists without extra nesting.
4. Enable the addon and type `/ftc`.

For updates, move the previous addon folder outside AddOns as a backup. Keep your **WTF** folder; it
contains saved builds and settings. If updating while playing, use `/reload` afterward.

The [web/mobile app](https://pathofwasd.github.io/forever-talents/) uses the same release and
engine. Use **Check for updates**, then **Update now** when prompted. Your browser saves stay on the
device. Export your library for backups or transfer between addon and web.

Validation: shared Lua/native mock regression suites, browser engine tests, production PWA build and
ZIP integrity checks. Desktop/mobile UI, offline reload and the 1.2.14 → 1.2.15 service-worker
update were checked; the cached build and active checkpoint survived. Native WoW loading and pet
proc behavior still need gameplay verification.
