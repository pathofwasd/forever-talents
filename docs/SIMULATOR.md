# Simulator and character workspace

These tools are **experimental** and have not been validated in live gameplay. In either version,
open **Settings** and uncheck **Show experimental simulator** to hide Character and simulator
buttons. Saved stats, gear and builds remain intact. Turn it back on to restore the tools; library
imports keep your own visibility setting.

Open **Character** to keep one stat and equipment workspace per class. A skill's **Simulator** uses
that workspace and the displayed race, level and talents. Edits and pasted inputs inside Simulator
are temporary. **Reset skill overrides** restores the inherited values.

## Character modes

- **Base + custom gear** starts with reference attributes for the class, race and level. Create
  named items in the equipment slots or enter additional bonuses. Spell / healing power benefits
  both; damage-only and healing-only bonuses remain separate. Weapons take raw damage and speed; the
  engine adds their normal AP contribution. Recognized talent and racial passives update totals.
- **Overall stats** accepts totals before the modeled passives. Enter attributes as well as combat
  totals to estimate changes from attribute talents. Already included bonuses should not be entered
  again. This mode does not add reference base stats or equipment a second time.
- **Live capture**, in the addon, reads reported school power/crit, AP, weapon damage, attributes,
  resources, equipped item names and available bonuses. The original totals stay intact. Recognized
  talent-stat differences can be estimated relative to that capture; equipment is reference only.
  Re-capture to confirm changes, or choose Base + gear to preview another race/level. Item data that
  is still loading needs another capture. Raw weapon tooltip parsing currently expects English;
  reported weapon hit totals remain usable when item details cannot be read.

Custom gear is a stat worksheet, not an item database. Common spell power also contributes to
healing; healing-only and damage-only bonuses stay separate. Common item Attack Power contributes to
both attacks; ranged-only AP stays separate. Melee and ranged speeds are independent. Feral base hit
ranges require measured form totals instead of the equipped weapon's raw damage. Item ratings,
enchants, set effects, procs, weapon skill and most buffs are not reconstructed automatically. The
character illustration is original project artwork, generated for both interfaces from
`data/ui/character.json`.

## Reading results

The simulator estimates **one use against one target**, including the full periodic duration.
Damage, healing, shield capacity and a spell's self-health cost are separate effects. Expected total
averages critical rolls and the entered chance to land. The “every eligible effect crits” card is an
upper scenario; it does not mean every tick shares a single critical roll.

Each component uses:

```
(base at your level + power × coefficient + AP × ratio + weapon + resource)
× modeled bonuses × damage remaining
```

Periodic components multiply by the captured tick count. Expected total then uses:

```
mean non-critical total × (1 + crit chance × (critical multiplier − 1)) × chance to land
```

Open **How this is calculated** for numeric substitutions, coefficients, tick timing and source
spell IDs. **Included bonuses & data sources** shows the selected talent-rank text and links. Native
WoW offers the same information through **Calculation & sources**.

Inputs appear only when the model uses them. Healing and shields ignore hit/reduction assumptions;
non-critical effects hide critical chance. A zero scaling override hides power. Advanced accepts
explicit direct/periodic spell-power or Attack Power coefficients, a measured downranking factor and
replacement amounts. Periodic overrides are totals across all ticks, not a coefficient applied in
full to each tick.

## Accuracy and evidence

The effect snapshot is client build **1.60.1.70009**, reviewed October 5, 2026. Effect amounts,
level growth, scaling coefficients, intervals, critical flags and attack category come from the
client tables. Selected numerical corrections follow Blizzard's
[Forever development notes](https://us.forums.blizzard.com/en/wow/t/wow-forever-beta-development-notes-%E2%80%93-updated-october-1/2360696):
Bloodthirst's AP ratio, Swipe's AP contribution, and Inner Focus's periodic exclusion. Eureka is not
modeled: its class-specific spell eligibility and scripted bonuses remain unverified. Gnome
simulations display this limitation and mark the result as a partial estimate. These corrections do
not constitute a full talent-catalog migration to the latest beta build.

Rank pickers use player-facing spells, with verified helper and cosmetic aliases recognized when
reading an imported spellbook. Holy Light keeps rank 7 through level 53; rank 8 starts at 54.
Mutilate and Penance retain their proper cast descriptions, but their scripted weapon hits and
damage/healing volleys require manual measured amounts when no complete client model exists. A
single helper effect is not presented as the full cast.

Vengeance uses the reviewed Arcane/Nature critical-damage bonus. Savage Strikes uses the talent's
2/4% melee critical chance. Their broader effects in the class overview disagree with current rank
data; relevant calculations explain that uncertainty instead of substituting unconfirmed numbers.

The shared skill list includes talent-granted first ranks as well as trainer upgrades. Release 1.2.2
adds 23 first-rank effect models from the same checksum-verified snapshot, including Bloodthirst,
Lava Burst and Riptide. A restored unlock does not imply a complete simulation: scripted skills
without usable effect rows retain the tooltip fallback and its warnings. Summon Hawk covers only the
initial captured hit; Holy Nova's model covers damage and omits linked party healing. Read each
result's notes for these boundaries. An unlearned talent ability is labeled as a rank preview; its
numbers do not imply that the displayed build can cast it.

**Client-data estimate** means the captured components and supported modifiers were used. **Partial
estimate** identifies missing scaling, scripted interactions, omitted talents, low-rank penalty
uncertainty, or reference character conversions. **Manual estimate** uses supplied amounts. Client
tables cannot establish every server-side behavior or replace live measurements.

The reference base attributes and conventional stat conversions come from the
[Forever simulation data project](https://github.com/gunba/wow-forever-sim/tree/forever/assets/db_inputs).
They are not verified current Forever server baselines. Live totals are recommended for comparisons.
In particular, a missing Serpent Sting coefficient is unknown; the engine does not silently invent
one. Very low rank penalties need a measured override until the current curve is established.

Rotations, proc uptime, target-level attack tables, travel time, automatic armor/resistance,
off-hand attacks, most pets/forms and overhealing remain outside this per-use model. Recognized form
stat/critical changes are supported, but that does not make every feral ability fully modeled. Read
the result's accuracy notes before treating its output as a live damage prediction.

## Sharing

**FC1** transfers the displayed talent build, level and central character/gear workspace. **FS2**
transfers character stats/gear or temporary skill inputs; old **FS1** strings still load. Use the
simulator's paste control for a temporary experiment and Character's import control to replace the
central workspace. **FL1** transfers all builds, branches, class drafts and character workspaces.
The addon and PWA generate identical strings through the same Lua code. No account or connection
between the game and browser is required.
