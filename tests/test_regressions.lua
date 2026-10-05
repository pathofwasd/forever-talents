local Mock = dofile("tests/wow_mock.lua")
local FT = Mock.Load()
local M, S, Sim = FT.Model, FT.Store, FT.Simulation
local checks = 0
local function check(value, message)
    checks = checks + 1
    assert(value, message)
end
local function talent(cid, name)
    for _, t in pairs(M.Index(cid)) do
        if t.name == name then
            return t
        end
    end
    error("Missing talent: " .. name)
end
local function isolated(cid, name, rank, skill, parsed, state)
    local t = talent(cid, name)
    local build = M.New(cid)
    for i = 1, rank or t.max do
        build.order[i] = t.id
    end
    return Sim.Modifiers(build, skill, parsed, state or Sim.Defaults())
end

-- These checks exercise real multi-effect descriptions, not a copy of the
-- implementation. Each allocation isolates one talent's numerical effect.
local druid = FT.Skills.Prepare(11)
local moon = druid.byName.Moonfire
local moonParsed = Sim.Parse(moon.ranks[1])
local wrath = druid.byName.Wrath
local wrathParsed = Sim.Parse(wrath.ranks[1])
local mod = isolated(11, "Improved Moonfire", 2, moon, moonParsed)
check(mod.damage == 10 and mod.crit == 10, "combined damage and crit lost an effect")
mod = isolated(
    8,
    "Arcane Instability",
    3,
    { name = "Arcane Blast", related = {} },
    { kind = "damage", school = "Arcane", periodic = 0 }
)
check(mod.damage == 3 and mod.crit == 3)
check(mod.statsCrit == 3)
mod = isolated(
    8,
    "Incineration",
    3,
    { name = "Fire Blast", related = {} },
    { kind = "damage", school = "Fire", periodic = 0 }
)
check(
    mod.crit == 6 and mod.statsCrit == 0,
    "spell-specific crit was subtracted from general reported stats"
)
mod = isolated(
    8,
    "Arcane Mind",
    5,
    { name = "Arcane Blast", related = {} },
    { kind = "damage", school = "Arcane", periodic = 0 }
)
check(mod.critBonus == 100 and mod.damage == 0, "Intellect was mistaken for critical damage")
local physical = { kind = "damage", school = "Physical", periodic = 0 }
mod = isolated(1, "Impale", 2, { name = "Overpower", related = {} }, physical)
check(mod.critBonus == 20)
mod = isolated(1, "Death Wish", 1, { name = "Overpower", related = {} }, physical)
check(mod.damage == 0)
mod = isolated(
    1,
    "Death Wish",
    1,
    { name = "Overpower", related = {} },
    physical,
    { cooldowns = true }
)
check(mod.damage == 20, "active physical bonus missing")
local frost = { kind = "damage", school = "Frost", periodic = 0 }
mod = isolated(8, "Shatter", nil, { name = "Frostbolt", related = {} }, frost)
check(mod.crit == 0)
mod = isolated(8, "Shatter", nil, { name = "Frostbolt", related = {} }, frost, { frozen = true })
check(mod.crit == 50)
check(mod.statsCrit == 0, "target-dependent crit was mistaken for reported base crit")
mod = isolated(11, "Genesis", 5, wrath, wrathParsed)
check(mod.periodic == 0 and #mod.included == 0, "a periodic-only effect was applied to Wrath")
mod = isolated(11, "Genesis", 5, moon, moonParsed)
check(mod.periodic == 5)
local heal = druid.byName["Healing Touch"]
mod = isolated(11, "Gift of Nature", 5, heal, Sim.Parse(heal.ranks[1]))
check(mod.damage == 10)
local healingParsed = Sim.Parse(heal.ranks[1], heal)
check(healingParsed.school == "Nature")
mod = isolated(11, "Nature's Majesty", 2, heal, healingParsed)
check(mod.crit == 4 and mod.statsCrit == 4, "general spell crit did not cover healing")
mod = isolated(11, "Vengeance", 5, heal, healingParsed)
check(mod.critBonus == 0, "spell critical damage bonus applied to healing")
local priestHeal = FT.Skills.Prepare(5).byName["Flash Heal"]
mod = isolated(5, "Holy Specialization", 5, priestHeal, Sim.Parse(priestHeal.ranks[1], priestHeal))
check(mod.crit == 5 and mod.statsCrit == 5, "healing school crit was omitted")
local linked = false
for _, link in ipairs(heal.related) do
    if link.id == talent(11, "Gift of Nature").id then
        linked = true
        check(link.kind == "general")
    end
end
check(linked, "general healing modifier not highlighted")
local periodicLink, manaLink = false, false
for _, link in ipairs(wrath.related) do
    if link.id == talent(11, "Genesis").id then
        periodicLink = true
    end
    if link.id == talent(11, "Moonglow").id then
        manaLink = true
    end
end
check(not periodicLink, "periodic talent incorrectly highlighted for direct Wrath")
check(manaLink, "general damaging-spell mana modifier missing")
local bark = druid.byName.Barkskin
for _, link in ipairs(bark.related) do
    check(link.id ~= talent(11, "Moonglow").id, "defensive utility misidentified as damage dealt")
end
check(Sim.Parse({ text = "Deals 120 Nature damage." }).min == 120)
check(not Sim.Parse({ text = "Absorbs 100 to 200 Fire damage." }))
check(
    not Sim.Calculate(
        M.New(11),
        wrath,
        wrath.ranks[1],
        { manual = true, baseMin = 200, baseMax = 100 }
    )
)
local effect = {
    unlock = { id = 42 },
    ranks = {
        { level = 10, live = true, talentRank = 1 },
        { level = 11, live = true, talentRank = 2 },
        { level = 12, live = true, talentRank = 3 },
    },
}
check(
    FT.Skills.CurrentRank(effect, 60, { [42] = 1 }) == effect.ranks[1],
    "unspent talent ranks appeared as learned"
)
check(not FT.Skills.CurrentRank(effect, 60, {}))
local oldSpells = C_Spell
C_Spell = {
    GetSpellDescription = function()
        return "Deals 120 Nature damage."
    end,
}
local description, source = FT.Description({ text = "", spellID = 123 })
check(description == "Deals 120 Nature damage." and source == "client")
check(Sim.Parse({ text = "", spellID = 123 }).min == 120)
check(
    select(2, FT.Description(wrath.ranks[1])) == "snapshot",
    "client text overwrote captured data"
)
C_Spell = oldSpells
check(select(2, FT.Description({ text = "", spellID = 123 })) == "missing")

-- Undo restores the profile/node context as well as the allocation, including
-- an import that deliberately detached the working draft from its old profile.
_G.ForeverTalentsDB = nil
S.Init(11, 4)
local id = talent(11, "Improved Wrath").id
local a = S.CreateProfile("A")
S.Apply(M.Add, id)
local a2 = S.Checkpoint("A2")
S.Apply(M.Add, id)
local prior = FT.Copy(S.Build())
S.LoadNode(a.id, 1)
check(S.Draft().nodeID == 1)
S.Undo()
check(M.Same(S.Build(), prior) and S.Draft().nodeID == a2.id)
S.Redo()
check(S.Draft().nodeID == 1 and #S.Build().order == 0)
S.Undo()
local b = S.CreateProfile("B")
check(S.ActiveProfile().id == b.id)
S.LoadNode(a.id, 1)
S.Undo()
check(S.ActiveProfile().id == b.id)
S.Redo()
check(S.ActiveProfile().id == a.id)
S.Import(S.Build())
check(not S.ActiveProfile())
S.Undo()
check(S.ActiveProfile().id == a.id)
local saved = FT.Copy(S.db)
_G.ForeverTalentsDB = saved
S.Init(11, 4)
S.Redo()
check(not S.ActiveProfile(), "redo context did not survive reload")

-- Damaged graph records and orphaned profile records cannot reach the UI.
saved = FT.Copy(S.db)
saved.profiles.orphan = { nodes = "broken" }
saved.profileOrder[#saved.profileOrder + 1] = "orphan"
saved.profiles[a.id].nodes[1].parent = 999
saved.nextID = math.huge
_G.ForeverTalentsDB = saved
S.Init(11, 4)
check(not S.db.profiles.orphan and not S.db.profiles[a.id])
check(#S.db.recovered >= 2)
check(S.db.nextID == 1)
check(S.CreateProfile("Recovered draft"))

-- Old schema-1 build-only history still migrates, and wrong-class history is
-- discarded before Undo can restore a build to the wrong class workspace.
S.Draft().undo = { M.New(11), M.New(8) }
S.Init(11, 4)
check(#S.Draft().undo == 1)
check(S.Undo() and S.Build().classID == 11)

-- Latest Classic clients use structured specialization queries. Exercise the
-- alternative without leaving the test harness' live APIs altered.
local oldAPI, oldC, oldClass = GetTalentInfo, C_SpecializationInfo, UnitClass
GetTalentInfo = nil
UnitClass = function()
    return "Druid", "DRUID", 11
end
C_SpecializationInfo = {
    GetActiveSpecGroup = function()
        return 1
    end,
    GetTalentInfo = function(query)
        local t = M.Class(11).trees[query.specializationIndex].talents[query.talentIndex]
        if not t then
            return
        end
        return {
            name = "Localized name",
            tier = t.row + 1,
            column = t.col + 1,
            rank = query.specializationIndex == 1 and query.talentIndex == 1 and 1 or 0,
            maxRank = t.max,
            spellID = t.ranks[1].spellID,
        }
    end,
}
local oldNum, oldTabs = GetNumTalents, GetNumTalentTabs
GetNumTalents = function(tab)
    return #M.Class(11).trees[tab].talents
end
GetNumTalentTabs = function()
    return 3
end
local imported, oldDialog = nil, FT.UI.ImportDialog
FT.UI.ImportDialog = function(code)
    imported = FT.Codec.Decode(code)
end
check(FT.ImportPlayer())
check(imported and #imported.order == 1)
C_SpecializationInfo.GetTalentInfo = function()
    return nil
end
local before = FT.Copy(S.Build())
check(not FT.ImportPlayer())
check(M.Same(S.Build(), before))
GetTalentInfo, C_SpecializationInfo, UnitClass = oldAPI, oldC, oldClass
GetNumTalents, GetNumTalentTabs, FT.UI.ImportDialog = oldNum, oldTabs, oldDialog

-- Random edit sequences expose interactions between row gates, prerequisites,
-- rank caps, removal, tree resets, level budgets and reorder rejection.
math.randomseed(20261005)
for _, cid in ipairs(FT.classOrder) do
    local build = M.New(cid)
    local talents = {}
    for _, tree in ipairs(M.Class(cid).trees) do
        for _, t in ipairs(tree.talents) do
            talents[#talents + 1] = t
        end
    end
    for step = 1, 500 do
        local op = math.random(1, 5)
        local t = talents[math.random(1, #talents)]
        local candidate
        if op == 1 then
            candidate = M.Add(build, t.id, math.random() < 0.15)
        elseif op == 2 then
            candidate = M.Remove(build, t.id, math.random() < 0.15)
        elseif op == 3 then
            candidate = M.Reset(build, M.Class(cid).trees[math.random(1, 3)].id)
        elseif op == 4 and #build.order > 0 then
            candidate = M.Reorder(build, math.random(1, #build.order), math.random(1, #build.order))
        elseif op == 5 then
            candidate = FT.Copy(build)
            candidate.level = math.random(1, 60)
            if not M.Validate(candidate) then
                candidate = nil
            end
        end
        if candidate then
            build = candidate
        end
        check(M.Validate(build), "random edit produced illegal order")
        local code = FT.Codec.Encode(build)
        check(M.Same(build, FT.Codec.Decode(code)), "random edit sharing changed allocation/order")
    end
end
print(
    string.format(
        "Regressions: %d assertions passed, including 4,500 randomized edit steps",
        checks
    )
)
