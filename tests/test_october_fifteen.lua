local Mock = dofile("tests/wow_mock.lua")
local FT = Mock.Load()
local M, C, S, A, P, L, Sim =
    FT.Model, FT.Codec, FT.Store, FT.Skills, FT.Snapshot, FT.Library, FT.Simulation
local checks = 0
local function check(v, why)
    checks = checks + 1
    assert(v, why)
end
local function near(a, b)
    check(math.abs(a - b) < 0.00002, tostring(a) .. " vs " .. tostring(b))
end
local function oldBuild(cid, name)
    local index, ordered = M.LegacyIndex(cid, "759c22c2")
    local target
    for _, t in pairs(index) do
        if t.name == name then
            target = t
        end
    end
    check(target ~= nil)
    local b = M.New(cid, nil, 60, "Old " .. name)
    b.legacyTag = "759c22c2"
    local function add(id)
        local trial = FT.Copy(b)
        trial.order[#trial.order + 1] = id
        if M.ValidateLegacy(trial, b.legacyTag) then
            b = trial
            return true
        end
    end
    while (M.Counts(b)[target.id] or 0) < target.max do
        if not add(target.id) then
            local added
            for _, t in ipairs(ordered) do
                if t.treeID == target.treeID and t.id ~= target.id and add(t.id) then
                    added = true
                    break
                end
            end
            check(added, "Cannot construct legacy fixture")
        end
    end
    check(M.ValidateLegacy(b, b.legacyTag))
    return b
end
for _, case in ipairs({
    { 8, "Fire Power" },
    { 5, "Shadow Affinity" },
    { 7, "Call of Thunder" },
    { 9, "Malediction" },
}) do
    local old = oldBuild(unpack(case))
    local packed = L.Pack(old.order)
    local code = assert(C.Encode(old))
    local restored = assert(C.Decode(code))
    check(M.RepairStatus(restored) and L.Pack(restored.order) == packed)
    check(C.EncodeOriginal(restored) == code and C.Encode(restored) == code)
    check(L.Pack(C.DecodeTalents(C.EncodeTalents(restored)).order) == packed)
    local converted, message, removed = M.Convert(restored)
    check(converted and M.Validate(converted) and removed > 0 and #message > 0)
    check(C.EncodeOriginal(converted) == code)
    check(L.Pack(restored.order) == packed, "Conversion mutated the original")
    local profile = P.Stats({ power = 100 }, restored)
    check(C.Encode(P.Decode(P.EncodeCharacter(restored, profile)).build) == code)
    check(S.Import(restored))
    check(S.ConvertCurrent())
    check(S.Undo() and C.Encode(S.Build()) == code)
    check(S.Redo() and M.Validate(S.Build()))
    local id = assert(S.CreateProfile("Converted " .. case[2])).id
    local fp = assert(L.DecodeProfile(L.EncodeProfile(id)))
    check(C.EncodeOriginal(fp.build) == code)
    local library = assert(L.Decode(L.Encode()))
    check(C.EncodeOriginal(library.database.profiles[id].nodes[1].build) == code)
end
local function sk(cid, name)
    return assert(A.Prepare(cid).byName[name])
end
local function calc(cid, name, state, rank, race)
    local skill = sk(cid, name)
    return assert(
        Sim.Calculate(
            M.New(cid, race or (cid == 7 and 8 or 5)),
            skill,
            skill.ranks[rank or 1],
            state
        )
    )
end
local ice = calc(8, "Ice Lance", { crit = 0, power = 100, frozen = false })
local frozen = calc(8, "Ice Lance", { crit = 0, power = 100, frozen = true })
near(frozen.normalMin, ice.normalMin * 3)
local nova = sk(7, "Fire Nova")
near(Sim.Parse(nova.ranks[1], nova, 60).components[1].sp, 0.143)
local consecration = calc(2, "Consecration", { crit = 0, power = 100 }, 1)
local outside = calc(2, "Consecration", { crit = 0, power = 100, firstFour = false }, 1)
near(consecration.dotCoefficient, 8 * 0.042)
near(outside.dotCoefficient, 0)
check(consecration.normalMin > outside.normalMin)
local used = {}
for _, field in ipairs(outside.inputs) do
    used[field.key] = true
end
check(not used.power and used.firstFour)
local wrath = calc(8, "Arcane Wrath", { crit = 0, power = 100, mana = 1000 })
local without = calc(8, "Arcane Wrath", { crit = 0, power = 100, mana = 0 })
near(wrath.normalMin - without.normalMin, 50 * wrath.coefficient)
local human = calc(8, "Fireball", { crit = 0 }, 1, 1)
local orc = calc(8, "Fireball", { crit = 0 }, 1, 2)
near(human.crit, 2)
near(orc.crit, 1)
local tauren = calc(7, "Lightning Bolt", { crit = 0, hit = 90 }, 1, 6)
near(tauren.hit, 90)
check(tauren.confidence == "Partial estimate")
local dwarf = calc(7, "Lightning Bolt", { crit = 0 }, 1, 3)
check(dwarf.confidence == "Partial estimate")
local warrior = sk(1, "Battle Shout")
check(A.AbilityDetails(warrior.ranks[1]):find("10 Rage", 1, true))
local profile = P.Stats({
    intellect = 123,
    mana = 999,
    arcaneBlastStacks = 4,
    fireEffects = 5,
    holyFireOrPain = true,
    firstFour = false,
}, M.New(8, 5))
local encoded = assert(P.EncodeStats(profile))
check(encoded:find("FS2:", 1, true) == 1)
local decoded = assert(P.DecodeStats(encoded))
for _, key in ipairs({
    "intellect",
    "mana",
    "arcaneBlastStacks",
    "fireEffects",
    "holyFireOrPain",
    "firstFour",
}) do
    check(decoded.state[key] == profile.state[key], "Scenario field lost: " .. key)
end
check(P.EncodeStats(P.Stats({}, M.New(8, 5))):find("FS1:", 1, true) == 1)
print("October 15 data and compatibility: " .. checks .. " assertions passed")
