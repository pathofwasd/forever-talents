local Mock = dofile("tests/wow_mock.lua")
local FT = Mock.Load()
local M, S, C, UI = FT.Model, FT.Store, FT.Codec, FT.UI
local checks = 0
local function check(value, message)
    checks = checks + 1
    assert(value, message)
end
local build = dofile("tests/fixtures/mage_fire.lua")
local id = 105796 -- Incineration, top-middle Fire talent.
local original = C.Encode(build)
local removed, notice = M.Remove(build, id)
check(removed and notice:find("Leveling order adjusted", 1, true))
check(M.Validate(removed) and #removed.order == 40)
local points, trees = M.Counts(removed)
check(points[id] == 2 and trees[41] == 32 and trees[61] == 8)
check(C.Encode(build) == original, "Removal mutated its source")
for n = 0, #removed.order do
    check(M.Validate(M.Prefix(removed, n)), "Repaired prefix is illegal")
end
local twice = assert(M.Remove(removed, id))
check(M.Counts(twice)[id] == 1 and #twice.order == 39)
check(not M.Remove(twice, id), "Removal bypassed a genuine tier requirement")
check(not M.Remove(build, id, true), "Clear bypassed a genuine tier requirement")
check(not M.Remove(build, 105790), "Removal bypassed Heating Up's Pyroblast prerequisite")
check(not M.Remove(build, 105784), "Removal bypassed Combustion's Critical Mass prerequisite")

S.SwitchClass(8)
check(S.Edit(build))
check(S.SetAutoLevel(true))
local profile = S.CreateProfile("Preserved Fire checkpoint")
check(profile)
local before = FT.Copy(S.Build())
UI.Toggle()
UI.talentButtons[id]:Click("RightButton")
local after = FT.Copy(S.Build())
check(M.Counts(after)[id] == 2 and after.level == 49 and S.AutoLevel())
check(UI.status:GetText():find("Leveling order adjusted", 1, true))
check(M.Same(profile.nodes[1].build, before), "Removal mutated a saved checkpoint")
check(S.Undo() and M.Same(S.Build(), before) and S.AutoLevel())
check(S.Redo() and M.Same(S.Build(), after))
check(M.Same(C.Decode(C.Encode(after)), after))
local library = assert(FT.Library.Encode())
check(FT.Library.Decode(library), "Edited library no longer imports")
local saved = FT.Copy(S.db)
_G.ForeverTalentsDB = saved
S.Init(8, 2)
check(M.Same(S.Build(), after) and S.AutoLevel(), "Reload lost the repaired draft")
check(S.Undo() and M.Same(S.Build(), before), "Reload lost exact undo order")
check(S.Redo() and M.Same(S.Build(), after))
UI.TalentDialog(id)
UI.dialogs.talent.remove:Click()
check(M.Counts(S.Build())[id] == 1)
UI.dialogs.talent.remove:Click()
check(M.Counts(S.Build())[id] == 1, "Details bypassed the remaining tier restriction")
UI.CloseDialog()

-- The reported Feral allocation has exactly ten supporting points, across rows
-- one and two. The third row still needs ten after a removal, not five per row.
local feral = M.New(11)
for _, spec in ipairs({
    { 104938, 5 },
    { 104939, 3 },
    { 104941, 2 },
    { 104945, 3 },
    { 104948, 2 },
    { 104944, 1 },
}) do
    for _ = 1, spec[2] do
        feral = assert(M.Add(feral, spec[1]))
    end
end
local feralOriginal = C.Encode(feral)
local blocked, reason = M.Remove(feral, 104939)
check(
    not blocked and reason:find("9/10 supporting points", 1, true),
    "Feral removal did not explain the real tier gate"
)
check(reason:find("Shredding Attacks", 1, true) and reason:find("earlier row first", 1, true))
check(C.Encode(feral) == feralOriginal and M.Validate(feral), "Blocked removal altered the build")
local supported = assert(M.Add(feral, 104940))
local moved = assert(M.Remove(supported, 104939))
check(M.Counts(moved)[104939] == 2 and M.Counts(moved)[104940] == 1)
check(M.Validate(moved), "Moving a supporting point between earlier rows was incorrectly blocked")
S.SwitchClass(11)
check(S.Edit(feral))
local feralProfile = S.CreateProfile("Feral supporting points")
local savedFeral = FT.Copy(feralProfile.nodes[1].build)
check(S.Apply(M.Add, 104940))
local supportedDraft = FT.Copy(S.Build())
check(S.Apply(M.Remove, 104939))
local movedDraft = FT.Copy(S.Build())
check(S.Undo() and M.Same(S.Build(), supportedDraft))
check(S.Redo() and M.Same(S.Build(), movedDraft))
check(
    M.Same(feralProfile.nodes[1].build, savedFeral),
    "Moving supporting points changed the checkpoint"
)

-- A separate rank-to-build path checks whether the remaining allocation can
-- legally exist, independent of its historical point sequence.
for _, cid in ipairs(FT.classOrder) do
    for _, firstTree in ipairs(M.Class(cid).trees) do
        local filled = M.New(cid)
        while #filled.order < 51 do
            local found
            local trees = { firstTree }
            for _, tree in ipairs(M.Class(cid).trees) do
                if tree ~= firstTree then
                    trees[#trees + 1] = tree
                end
            end
            for _, tree in ipairs(trees) do
                for _, talent in ipairs(tree.talents) do
                    if M.CanAdd(filled, talent.id) then
                        filled = assert(M.Add(filled, talent.id))
                        found = true
                        break
                    end
                end
                if found then
                    break
                end
            end
            assert(found)
        end
        local initial = C.Encode(filled)
        local ranks = M.Counts(filled)
        for talentID, rank in pairs(ranks) do
            for _, clear in ipairs({ false, true }) do
                local wanted = FT.Copy(ranks)
                wanted[talentID] = clear and 0 or rank - 1
                local reference = M.FromRanks(cid, filled.raceID, filled.level, wanted)
                local candidate = M.Remove(filled, talentID, clear)
                check((candidate ~= nil) == (reference ~= nil), "Legal removal was refused")
                check(C.Encode(filled) == initial, "Trial removal mutated its source")
                if candidate then
                    local counts = M.Counts(candidate)
                    for otherID, remaining in pairs(wanted) do
                        check((counts[otherID] or 0) == remaining, "Removal changed another talent")
                    end
                    check(#candidate.order == 51 - (clear and rank or 1))
                    check(M.Validate(candidate))
                    check(M.Same(C.Decode(C.Encode(candidate)), candidate))
                    for n = 0, #candidate.order do
                        check(M.Validate(M.Prefix(candidate, n)))
                    end
                end
            end
        end
    end
end
check(FT.Data.meta.tag == "7ba43a60")
print("Talent removal: " .. checks .. " assertions passed")
