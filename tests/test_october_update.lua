local Mock = dofile("tests/wow_mock.lua")
local FT = Mock.Load()
local M, C, S, L, P, A, Sim, Character =
    FT.Model, FT.Codec, FT.Store, FT.Library, FT.Snapshot, FT.Skills, FT.Simulation, FT.Character
local checks = 0
local function check(v, why)
    checks = checks + 1
    assert(v, why)
end
local function near(a, b)
    check(math.abs(a - b) < 0.00002, tostring(a) .. " vs " .. tostring(b))
end
local index = M.Index(1)
local old = M.New(1, 1, 60, "Original Impale route")
-- Reproduce the old allocator without Deep Wounds; restore the real rule immediately.
local requires = index[105947].requires
index[105947].requires = {}
while #old.order < 15 do
    local found = false
    for _, t in ipairs(M.Class(1).trees[1].talents) do
        if t.id ~= 105950 and t.id ~= 105947 and M.CanAdd(old, t.id) then
            old = assert(M.Add(old, t.id))
            found = true
            break
        end
    end
    check(found)
end
old = assert(M.Add(old, 105947))
local oldCode = assert(C.Encode(old))
index[105947].requires = requires
local function retag(code, tag)
    local body = code:match("^(.*):[^:]+$"):gsub("^([A-Z]+1):[^:]+:", "%1:" .. tag .. ":")
    return body .. ":" .. C.Checksum(body)
end
oldCode = retag(oldCode, "7ba43a60")
local imported = assert(C.Decode(oldCode))
check(M.RepairStatus(imported) and not M.Validate(imported))
check(M.Same(old, imported) and L.Pack(old.order) == L.Pack(imported.order))
check(C.EncodeOriginal(imported) == oldCode)
check(C.Encode(imported) == oldCode)
check(not C.Decode(retag(oldCode, FT.Data.meta.tag)), "Current envelopes bypassed current rules")
check(not C.Decode(retag(oldCode, "aaaaaaaa")))
check(not C.Decode(oldCode:sub(1, -2)))
local talentsOnly = assert(C.EncodeTalents(imported))
check(C.DecodeTalents(talentsOnly).legacyTag == "7ba43a60")
local unchanged = M.New(11, 4, 60, "Unchanged druid")
check(not C.Decode(retag(C.Encode(unchanged), "7ba43a60")).legacyTag)
local invalid = FT.Copy(old)
invalid.order[#invalid.order + 1] = 999999
check(not M.Preserve(invalid, "7ba43a60"))
-- A final-valid allocation with an obsolete spend order is also preserved intact.
local ordered = FT.Copy(old)
for i = 1, 3 do
    ordered.order[#ordered.order + 1] = 105950
end
check(not M.Validate(ordered))
check(M.ValidateLegacy(ordered, "7ba43a60"))
check(M.Preserve(ordered, "7ba43a60") and M.RepairStatus(ordered))
local database = {
    schema = 1,
    tag = "7ba43a60",
    nextID = 2,
    currentClass = 1,
    settings = {},
    inbox = {},
    drafts = { [1] = { build = FT.Copy(old), profileID = "p1", nodeID = 2, undo = {}, redo = {} } },
    profiles = {
        p1 = {
            id = "p1",
            name = "Old Warrior branches",
            nextNode = 4,
            order = { 1, 2, 3 },
            nodes = {
                [1] = { id = 1, title = "Before Impale", build = M.Prefix(old, 15), created = 1 },
                [2] = {
                    id = 2,
                    parent = 1,
                    title = "Needs repair",
                    build = FT.Copy(old),
                    created = 2,
                },
                [3] = {
                    id = 3,
                    parent = 1,
                    title = "Other branch",
                    build = M.Prefix(old, 10),
                    created = 3,
                },
            },
        },
    },
    profileOrder = { "p1" },
}
local function envelope(prefix, tag, payload)
    local body = prefix .. ":" .. tag .. ":" .. C.Base64(L.Pack(payload))
    return body .. ":" .. C.Checksum(body)
end
local migrated = assert(L.Decode(envelope("FL1", "7ba43a60", database)))
check(migrated.database.tag == FT.Data.meta.tag)
check(#migrated.database.profiles.p1.order == 3 and not migrated.database.recovered)
check(migrated.database.profiles.p1.nodes[2].build.recovery)
_G.ForeverTalentsDB = FT.Copy(database)
S.Init(1, 1, 60)
check(S.ActiveProfile().name == "Old Warrior branches")
check(not S.UpdateCheckpoint() and not S.Checkpoint("Invalid new"))
local before = L.Pack(S.Build().order)
check(S.PasteTalents(talentsOnly) and L.Pack(S.Build().order) == before)
local library = assert(L.Decode(L.Encode()))
check(C.EncodeOriginal(library.database.profiles.p1.nodes[2].build) == oldCode)
local profile = assert(L.DecodeProfile(L.EncodeProfile("p1")))
check(profile.nodes == 3 and profile.selected == 2)
check(C.EncodeOriginal(profile.build) == oldCode)
-- Nested character and stat formats keep their legacy source contribution intact.
local stat = P.Stats({ power = 50, crit = 5 }, imported)
stat.learnedCode = oldCode
local fs1 = assert(P.EncodeStats(stat))
check(P.DecodeStats(fs1).learnedCode == oldCode)
local full = assert(P.Decode(P.EncodeCharacter(imported, stat)))
check(M.RepairStatus(full.build) and full.stats.learnedCode == oldCode)
local modern = Character.New()
local fs2 = P.Current(imported)
fs2.character = modern
fs2.learnedCode = oldCode
check(P.DecodeStats(P.EncodeStats(fs2)).learnedCode == oldCode)
-- Repair is explicit and incremental; no point/order is auto-inserted during migration.
for i = 1, 3 do
    check(S.Apply(M.Add, 105950))
end
check(M.RepairStatus(S.Build()), "Unexpected automatic reordering")
local from = #S.Build().order - 2
for i = 1, 3 do
    check(S.Apply(M.Reorder, from + i - 1, 16 + i - 1))
end
check(M.Validate(S.Build()) and not S.Build().legacyTag)
check(S.UpdateCheckpoint())
check(S.Build().recovery and C.EncodeOriginal(S.Build()) == oldCode)
check(C.Decode(C.Encode(S.Build())) and C.Encode(S.Build()):find(FT.Data.meta.tag, 1, true))
local fixedProfile = assert(L.DecodeProfile(L.EncodeProfile("p1")))
check(C.EncodeOriginal(fixedProfile.build) == oldCode)
check(S.Undo() and M.RepairStatus(S.Build()))
check(S.Redo() and M.Validate(S.Build()))
check(S.DeleteNode("p1", 2))
check(#S.db.profiles.p1.order == 2 and S.db.profiles.p1.nodes[3])
-- Reload preserves original exports after repair and partial edits.
S.Init(1, 1, 60)
check(C.EncodeOriginal(S.Build()) == oldCode)
local saved = _G.ForeverTalentsDB
_G.ForeverTalentsDB = FT.Copy(database)
_G.ForeverTalentsDB.tag = "aaaaaaaa"
local unknown = _G.ForeverTalentsDB
S.Init(1, 1, 60)
check(S.readOnly and _G.ForeverTalentsDB == unknown)
_G.ForeverTalentsDB = saved
S.Init(1, 1, 60)
-- Independent effect values at learn, intermediate and scaling-cap levels.
local function parse(cid, name, rank, level, mode)
    local skill = A.Prepare(cid).byName[name]
    return assert(Sim.Parse(skill.ranks[rank], skill, level, mode))
end
near(parse(11, "Wrath", 1, 1).min, 13.846155)
near(parse(11, "Wrath", 1, 3).min, 14.246155)
near(parse(11, "Wrath", 1, 60).min, 14.646155)
near(parse(5, "Lesser Heal", 2, 4).min, 85.564111)
near(parse(5, "Smite", 1, 1).min, 12.999997)
near(parse(7, "Lightning Bolt", 1, 1).min, 13.928572)
near(parse(9, "Shadow Bolt", 1, 1).min, 11.142859)
near(parse(8, "Fireball", 1, 1).min, 14.000004)
local penance = A.Prepare(5).byName.Penance
local parents = { 402174, 1240720, 1240721, 1316995 }
for i, id in ipairs(parents) do
    local rank
    for _, r in ipairs(penance.ranks) do
        if r.spellID == id then
            rank = r
        end
    end
    check(rank and rank.live)
    local d = assert(Sim.Parse(rank, penance, rank.level, "damage"))
    local h = assert(Sim.Parse(rank, penance, rank.level, "healing"))
    check(d.duration == 2 and #d.components == 1 and d.components[1].ticks == 3)
    near(d.components[1].sp, 0.19)
    near(h.components[1].sp, 0.19)
    check(d.components[1].kind == "damage" and h.components[1].kind == "healing")
    check(A.AbilityDetails(rank):find("Channeled • 2 sec", 1, true))
    check(A.AbilityDetails(rank):find(({ 150, 220, 270, 385 })[i] .. " Mana", 1, true))
    local result = assert(
        Sim.Calculate(
            M.New(5, nil, rank.level),
            penance,
            rank,
            { power = 100, crit = 0, effectMode = "damage" }
        )
    )
    near(result.normalMin, (d.components[1].low + 19) * 3)
end
check(A.AbilityDetails({ spellID = 20177 }):find("Proc interval: 1.5 sec", 1, true))
local water = A.AbilityDetails({ spellID = 408510 })
check(
    water:find("No ability cooldown recorded", 1, true)
        and water:find("Proc interval: 3.5 sec", 1, true)
)
for _, case in ipairs({ { 11, "Thorns" }, { 2, "Retribution Aura" } }) do
    local skill = A.Prepare(case[1]).byName[case[2]]
    local result, why = Sim.Calculate(M.New(case[1]), skill, skill.ranks[1], {})
    check(not result and why:find("not verified", 1, true))
end
-- Natural Instinct preserves the melee crit bonus and uses final Intellect for healing.
local druid = M.New(11)
druid.order = { 104950 }
local manual = Character.New()
manual.mode = "manual"
manual.stats.intellect = 100
near(Character.Compute(druid, manual).totals.healing, 12)
druid.order = { 104950, 104950 }
near(Character.Compute(druid, manual).totals.healing, 25)
local gear = Character.New()
gear.mode = "gear"
gear.gear.head = { name = "Intellect fixture", stats = { intellect = 50 } }
local totals = Character.Compute(druid, gear).totals
near(totals.healing, totals.intellect * 0.25)
local source = P.Stats({ healing = 25, crit = 5 }, druid)
source.learnedCode = C.Encode(druid)
-- Use a legal source build to validate captures, independent of the numeric fixture above.
local ranks = { [104950] = 2 }
local legal = M.New(11)
for _, t in ipairs(M.Class(11).trees[2].talents) do
    while #legal.order < 20 and t.id ~= 104950 and M.CanAdd(legal, t.id) do
        legal = assert(M.Add(legal, t.id))
    end
end
legal = assert(M.Add(legal, 104950, true))
check(M.Validate(legal))
source = P.Stats({ healing = 125, crit = 5 }, legal)
source.learnedCode = C.Encode(legal)
source.attributes = {
    strength = 30,
    agility = 30,
    intellect = 100,
    stamina = 30,
    spirit = 30,
    health = 1000,
    mana = 500,
}
source.raw = { crit = { [7] = 5 }, meleeCrit = 5, healing = 125 }
local live = Character.FromSnapshot(source)
near(Character.Compute(legal, live).totals.healing, 125)
near(Character.Compute(M.New(11, legal.raceID, 60), live).totals.healing, 100)
near(live.stats.healing, 125)
source.learnedCode = retag(source.learnedCode, "7ba43a60")
local oldCapture = Character.FromSnapshot(source)
local preserved = Character.Compute(M.New(11, legal.raceID, 60), oldCapture)
near(preserved.totals.healing, 125)
check(table.concat(preserved.warnings, " "):find("reported healing total is kept", 1, true))

local healingLinks = A.Prepare(11).byName["Healing Touch"].related
local linked = false
for _, link in ipairs(healingLinks) do
    if link.id == 104950 then
        linked = true
    end
end
check(linked, "Natural Instinct missing healing link")
print("October update and migration: " .. checks .. " assertions passed")
