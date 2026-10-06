# Forever Talents 1.2.9

- Corrects Holy Light at levels 50–53, Mutilate and Penance cast-rank selection, Polymorph's maximum
  rank, and Shadow Bolt rank 10. Legitimate upgrades learned at the same level remain available.
- Recognizes verified helper and cosmetic spell IDs in character imports without changing your
  captured IDs, saved builds, checkpoints or sharing strings.
- Makes Eureka's omitted bonuses explicit. Scripted Mutilate/Penance casts with incomplete models
  use measured manual amounts instead of presenting one helper hit as the full cast. Vengeance and
  Savage Strikes explain conflicting upstream descriptions; unconfirmed numbers are not applied.
- Adds Cultivation's player-level requirements, Touch of the Grave's trigger restrictions and an
  announced Fox/Trickster's Dance reference note. Fox family IDs and tameable locations remain
  unverified.

The addon and web/mobile app share these corrections. Talent layouts and allocation rules are
unchanged; existing saves and FT1/FS1/FS2/FC1/FL1 exports remain compatible.

## Download and install

Scroll to **Assets** below and download **ForeverTalents.zip**. Expand Assets if needed. The “Source
code” archives are for development.

1. Close World of Warcraft.
2. Extract the ZIP and copy **ForeverTalents** into the Forever client's `Interface/AddOns` folder.
3. Check that `Interface/AddOns/ForeverTalents/ForeverTalents.toc` exists without extra nesting.
4. Enable the addon and type `/ftc`.

For updates, move the previous addon folder outside AddOns as a backup. Keep your `WTF` folder; it
contains your saved builds and settings. If files are replaced while playing, use `/reload`.

The [web/mobile app](https://pathofwasd.github.io/forever-talents/) uses the same engine. Accept its
update prompt to load this release. Export your full library for backups or transfer between the
addon and web.
