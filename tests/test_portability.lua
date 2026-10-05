local Mock = dofile("tests/wow_mock.lua")
local FT = Mock.Load()
local M, S, P, L, C = FT.Model, FT.Store, FT.Snapshot, FT.Library, FT.Codec
local n = 0
local function check(v, msg)
    n = n + 1
    assert(v, msg)
end
for _, cid in ipairs(FT.classOrder) do
    S.SwitchClass(cid)
    S.SetAutoLevel(true)
    local first = M.Class(cid).trees[1].talents[1]
    check(S.Apply(M.Add, first.id, true))
    local b = FT.Copy(S.Build())
    b.level = 60
    b.name = "Portable " .. M.Class(cid).name
    local stats = P.Stats(
        { power = 123.456789, crit = 17.25, attackPower = 321, coefficient = 57.1, bleeding = true },
        b,
        "Skill",
        "fixture"
    )
    stats.raw = { power = { [7] = 87.5 }, crit = { [7] = 19 }, meleeCrit = 20, healing = 95 }
    stats.learnedCode = C.Encode(b)
    local code, why = P.EncodeStats(stats)
    check(code, why)
    local copy
    copy, why = P.DecodeStats(code)
    check(copy, why)
    check(
        copy.state.power == 123.456789
            and copy.state.bleeding
            and copy.raw.crit[7] == 19
            and copy.learnedCode == stats.learnedCode
    )
    local character = P.EncodeCharacter(b, stats)
    local decoded = P.Decode(character)
    check(decoded and decoded.kind == "character")
    check(M.Same(b, decoded.build))
    check(P.Apply(decoded))
    check(S.Build().level == 60 and not S.AutoLevel())
    local current = FT.Copy(S.Build())
    check(P.Apply(P.Decode(code)))
    check(M.Same(S.Build(), current), "stats-only changed talents")
    for i = 1, #code do
        check(
            not P.DecodeStats(code:sub(1, i - 1) .. "!" .. code:sub(i + 1)),
            "damaged string accepted"
        )
    end
    check(not P.Decode(character .. "x"))
    check(not P.Decode("FC2:unsupported"))
end
S.SwitchClass(11)
S.SetAutoLevel(true)
S.Apply(M.Reset)
S.Apply(M.Add, M.Class(11).trees[1].talents[1].id, true)
local profile = S.CreateProfile("A portable tree")
S.Checkpoint("Child")
S.LoadNode(profile.id, 1)
S.Checkpoint("Other branch")
local before = FT.Copy(S.db)
local code = L.Encode()
local snap, why = L.Decode(code)
check(snap, why)
check(snap.profiles == 1 and snap.nodes == 3)
local result = L.Merge(snap, true)
check(result and result.added == 0 and result.skipped == 1, "reimport duplicated a profile")
check(S.ActiveProfile())
_G.ForeverTalentsDB = nil
S.Init(11, 4, 60)
local empty = FT.Copy(S.Build())
check(L.Merge(snap, false))
check(M.Same(S.Build(), empty), "default merge changed working draft")
check(#S.db.profileOrder == 1)
check(L.Merge(snap, true))
check(S.AutoLevel())
local p = S.db.profiles[S.db.profileOrder[1]]
check(#p.order == 3 and p.nodes[2].parent == 1 and p.nodes[3].parent == 1)
check(S.Draft().profileID == p.id)
check(S.Undo())
check(S.Redo())
check(S.ActiveProfile())
for _, bad in ipairs({
    "",
    "FL1:bad",
    "FL2:x",
    code:sub(1, -2),
    "FL1:" .. FT.Data.meta.tag .. ":" .. C.Base64("T9999999:") .. ":12345678",
}) do
    check(not L.Decode(bad))
end
for _, bad in ipairs({
    "T1:S1:xS999999:a",
    "T1:B1Z",
    "T2:S1:xB1S1:xB0",
    "N3:nan",
    "N4:1e99",
    "T9999999:",
}) do
    check(not pcall(L.Unpack, bad))
end
local nested = "B1"
for i = 1, 55 do
    nested = "T1:S1:x" .. nested
end
check(not pcall(L.Unpack, nested))
-- Invalid graphs with a freshly correct checksum are still rejected, and the
-- current database and class context are untouched on failure.
local invalid = FT.Copy(before)
invalid.profiles[profile.id].nodes[2].parent = 999
local body = "FL1:" .. FT.Data.meta.tag .. ":" .. C.Base64(L.Pack(invalid))
local db = S.db
check(not L.Decode(body .. ":" .. C.Checksum(body)))
check(S.db == db)
-- Structured API fallback queries coordinates, and zero/partial data fails.
local oldC, oldNum, oldGet = C_SpecializationInfo, GetNumTalents, GetTalentInfo
GetTalentInfo = nil
GetNumTalents = nil
C_SpecializationInfo = {
    IsInitialized = function()
        return true
    end,
    GetTalentInfo = function(q)
        if q.talentIndex then
            return nil
        end
        for _, t in ipairs(M.Class(11).trees[q.specializationIndex].talents) do
            if t.row + 1 == q.tier and t.col + 1 == q.column then
                return {
                    name = "Localized",
                    tier = q.tier,
                    column = q.column,
                    maxRank = t.max,
                    rank = q.specializationIndex == 1 and t.index == 1 and 3 or 0,
                }
            end
        end
    end,
}
local b, err = FT.ReadPlayerBuild()
check(b, err)
check(#b.order == 3)
C_SpecializationInfo.IsInitialized = function()
    return false
end
check(not FT.ReadPlayerBuild())
C_SpecializationInfo.IsInitialized = function()
    return true
end
C_SpecializationInfo.GetTalentInfo = function()
    return { name = "Loading", tier = 1, column = 1, maxRank = 5 }
end
check(not FT.ReadPlayerBuild())
C_SpecializationInfo, GetNumTalents, GetTalentInfo = oldC, oldNum, oldGet

local hunter = M.New(3)
local skill = FT.Skills.Prepare(3).byName["Aimed Shot"]
local ranged = P.Stats({ weaponMin = 10, weaponMax = 20, attackPower = 55 }, hunter)
ranged.raw = { rangedAP = 400, rangedMin = 110, rangedMax = 150, rangedCrit = 17 }
local shared = P.DecodeStats(P.EncodeStats(ranged))
check(shared.raw.rangedAP == 400)
local values = P.ForSkill(shared, skill, skill.ranks[1], hunter)
check(
    values.weaponMin == 110 and values.weaponMax == 150 and values.attackPower == 400,
    "ranged skills used melee damage"
)

-- The native adapter exposes the same full-library and character affordance.
FT.UI.Toggle()
FT.UI.CharacterDialog()
check(FT.UI.dialogs.character:IsShown())
FT.UI.dialogs.character.output:SetText(code)
check(FT.UI.dialogs.character.snapshot.kind == "library")
check(FT.UI.dialogs.character.load:IsEnabled())
FT.UI.CloseDialog()
print(
    "Portability: "
        .. n
        .. " assertions passed (stats, characters, libraries, source import, native controls)"
)
