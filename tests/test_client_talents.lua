local Mock = dofile("tests/wow_mock.lua")
local FT = Mock.Load()
local M, P, S, C = FT.Model, FT.Snapshot, FT.Store, FT.Character
local fixtureFor = dofile("tests/trait_fixture.lua")
local checks = 0
local function check(value, message)
    checks = checks + 1
    assert(value, message)
end
local function compare(expected)
    local actual, why = FT.ReadPlayerBuild()
    check(actual, why)
    check(M.Validate(actual))
    check(actual.classID == expected.classID and actual.raceID == expected.raceID)
    check(actual.level == expected.level and #actual.order == #expected.order)
    local ranks, expectedRanks = M.Counts(actual), M.Counts(expected)
    for id in pairs(M.Index(expected.classID)) do
        check(
            (ranks[id] or 0) == (expectedRanks[id] or 0),
            "Imported the wrong purchased talent rank"
        )
    end
    check(FT.Codec.Decode(assert(FT.Codec.Encode(actual))))
end
for _, cid in ipairs(FT.classOrder) do
    local build = M.New(cid, nil, 60)
    fixtureFor(FT, build)
    compare(build) -- Explicitly observed zero ranks are a legitimate empty build.
    build = assert(M.Add(build, M.Class(cid).trees[1].talents[1].id, true))
    fixtureFor(FT, build)
    compare(build)
    while #build.order < 51 do
        local added
        for _, tree in ipairs(M.Class(cid).trees) do
            for _, talent in ipairs(tree.talents) do
                added = M.Add(build, talent.id)
                if added then
                    break
                end
            end
            if added then
                break
            end
        end
        build = assert(added, "Fixture cannot reach 51 legal points")
    end
    fixtureFor(FT, build)
    compare(build)
end

local build = assert(M.Add(M.New(11, 4, 25), M.Class(11).trees[1].talents[1].id, true))
local f = fixtureFor(FT, build)
local function failure(change, restore, phrase)
    local before = FT.Codec.Encode(S.Build())
    local character = FT.Library.Pack(C.Get(S.View()))
    change()
    local ok, why = FT.ImportPlayerCharacter()
    check(not ok and type(why) == "string" and why:find(phrase, 1, true), why)
    check(FT.Codec.Encode(S.Build()) == before, "Failed talent import changed the draft")
    check(FT.Library.Pack(C.Get(S.View())) == character, "Failed talent import changed Character")
    restore()
end
failure(function()
    f.staged = true
end, function()
    f.staged = false
end, "Apply or cancel")
failure(function()
    f.configID = nil
end, function()
    f.configID = 202
end, "not ready")
local first = f.ids[1]
local node = f.nodes[first]
failure(function()
    f.nodes[first] = nil
end, function()
    f.nodes[first] = node
end, "node could not")
failure(function()
    node.ranksPurchased = nil
end, function()
    node.ranksPurchased = 0
end, "node could not")
failure(function()
    node.ranksPurchased = 0.5
end, function()
    node.ranksPurchased = 0
end, "node could not")
failure(function()
    node.ranksPurchased = -1
end, function()
    node.ranksPurchased = 0
end, "node could not")
local max = node.maxRanks
failure(function()
    node.maxRanks = max + 1
end, function()
    node.maxRanks = max
end, "ranks differ")
local entry = f.entries[node.entryIDs[1]]
local definition = f.definitions[entry.definitionID]
failure(function()
    f.definitions[entry.definitionID] = nil
end, function()
    f.definitions[entry.definitionID] = definition
end, "spell could not")
local spell = definition.spellID
failure(function()
    definition.spellID = 9999999
end, function()
    definition.spellID = spell
end, "outside this dataset")
failure(function()
    f.points = f.points + 1
end, function()
    f.points = f.points - 1
end, "spent-point total")
failure(function()
    table.remove(f.ids, 1)
end, function()
    table.insert(f.ids, 1, first)
end, "of 52 talents")
failure(function()
    table.insert(f.ids, first)
end, function()
    table.remove(f.ids)
end, "duplicate")
local getNode = C_Traits.GetNodeInfo
failure(function()
    C_Traits.GetNodeInfo = function()
        error("Client data unavailable")
    end
end, function()
    C_Traits.GetNodeInfo = getNode
end, "node could not")
local staged = C_Traits.ConfigHasStagedChanges
local reads
failure(function()
    reads = 0
    C_Traits.ConfigHasStagedChanges = function()
        reads = reads + 1
        return reads > 1
    end
end, function()
    C_Traits.ConfigHasStagedChanges = staged
end, "changed during capture")
local mapping = C_SpecializationInfo.GetCombatConfigIDForSpecGroup
C_SpecializationInfo.GetCombatConfigIDForSpecGroup = nil
C_ClassTalents.GetActiveConfigID = function()
    return f.configID
end
compare(build)
C_SpecializationInfo.GetCombatConfigIDForSpecGroup = mapping

-- A full native capture passes through the existing portable FC1 format, with
-- trained spellbook ranks and recognized source talents for stat normalization.
GetNumSpellTabs = function()
    return 1
end
GetSpellTabInfo = function()
    return "Localized", 0, 0, 2, false, 0
end
GetSpellBookItemInfo = function(index)
    return "SPELL", index == 1 and 5177 or 5185
end
local snapshot, why = FT.ReadPlayerSnapshot()
check(snapshot, why)
check(#snapshot.build.order == #build.order)
check(snapshot.stats.character.trainedSkills.spellIDs[1] == 5177)
check(FT.Codec.Decode(snapshot.stats.character.capture.learnedCode))
check(FT.ImportPlayerCharacter())
check(#S.Build().order == #build.order and FT.UI.skillFilterKey == "trained")
local code = assert(P.EncodeCharacter(S.ExportView(), P.Current(S.ExportView())))
local imported = assert(P.Decode(code))
check(imported.stats.character.trainedSkills.spellIDs[1] == 5177)
check(FT.Codec.Encode(imported.build) == FT.Codec.Encode(S.ExportView()))
if arg[1] then
    local file = assert(io.open(arg[1], "w"))
    file:write(code)
    file:close()
end
print(
    "Client talents: "
        .. checks
        .. " assertions passed (Forever configurations, all classes, complete capture, staged edits, portability)"
)
