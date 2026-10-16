# Forever Talents 1.3.0

- Updated all nine classes for the October 8 and October 15 Forever notes, with client effects and
  base ability details from **1.60.1.70425**. Includes revised talents, skill ranks, racials and
  pet/perk references.
- Skills now shows a simple timeline: **one row per rank, grouped by unlock level**. See what is
  available now or coming next, open that exact rank, and filter by imported training when enabled.
  All ranks of an ability share the same highlight color. Addon full/Simple/Compact and web/mobile
  use the same list.
- Older builds keep their original talents, spending order and checkpoint branches. Affected
  allocations show **Needs repair**. Review conversion, apply it explicitly, then Update checkpoint
  when ready. Undo and Share → Original build retain the original allocation.
- Updated supported simulator effects and conditional inputs. Unverified racial, proc, pet and
  scripted effects remain clearly limited. Re-import older live captures before comparing changed
  training ranks or simulating changed passives. The simulator remains experimental.

## Download and install

On this release page, expand **Assets** and download **ForeverTalents.zip**. The Source code
archives are for development. Extract its **ForeverTalents** folder into the Forever client's
**Interface/AddOns** directory; `Interface/AddOns/ForeverTalents/ForeverTalents.toc` should exist.
Move the previous addon folder outside AddOns as a backup. Keep **WTF**, which holds player saves.
Enable the addon, then use `/ftc`; use `/reload` after updating an active session.

The [web/mobile app](https://pathofwasd.github.io/forever-talents/) uses the same engine and data.
After deployment, choose **Check for updates**, then **Update now** once the complete release is
ready. Local libraries stay intact. Export a library before changing devices or clearing site data.
Update both recipients to exchange new builds; known older strings remain importable.

Shared Lua/native API-harness, save/share recovery and exact Lua 5.1/WASM parity checks cover this
change. Native visuals, live character capture and numerical combat accuracy still need real-client
testing. Packaging this version does not itself publish a release or deploy the website.
