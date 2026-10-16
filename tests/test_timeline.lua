local Mock = dofile("tests/wow_mock.lua")
local FT = Mock.Load()
local A, M, S, C, UI = FT.Skills, FT.Model, FT.Store, FT.Character, FT.UI
local checks = 0
local function check(value, why)
    checks = checks + 1
    assert(value, why)
end
for _, cid in ipairs(FT.classOrder) do
    S.SwitchClass(cid)
    local b = M.New(cid, nil, 25)
    check(S.Edit(b))
    local rows, previous, seen, count = A.Timeline(b, 25, "", "all", false), 0, {}, 0
    for _, entry in ipairs(rows) do
        check(entry.level >= previous, "Unlocks are not chronological")
        check(not seen[entry.key], "Duplicate player rank")
        check(entry.skill.kind ~= "racial")
        check(entry.rank.live and not entry.rank.aliasOf and not entry.rank.referenceOnly)
        check(entry.rank == entry.skill.ranks[entry.rankIndex])
        seen[entry.key], previous = true, entry.level
    end
    for _, skill in ipairs(A.Prepare(cid).list) do
        count = count + #A.Levels(skill)
    end
    check(#rows == count, "A live rank is missing")
    for _, entry in ipairs(A.Timeline(b, 25, "", "now", false)) do
        check(entry.level <= 25 and entry.available and not entry.requiresTalent)
    end
end
S.SwitchClass(11)
check(S.Edit(M.New(11, 4, 38)))
local rows = A.Timeline(S.Build(), 38, "Shred", "all", false)
check(#rows == 5)
for i, level in ipairs({ 20, 30, 38, 46, 54 }) do
    check(rows[i].level == level and rows[i].label == "Rank " .. i)
    check(rows[i].available == (level <= 38))
end
check(rows[4].status == "In 8 levels")
local sheet = C.Get(S.Build())
sheet.trainedSkills = {
    schema = 1,
    classID = 11,
    raceID = 4,
    level = 38,
    dataTag = FT.Data.meta.tag,
    spellIDs = { rows[2].rank.spellID },
}
check(C.Save(S.Build(), sheet))
check(#A.Timeline(S.Build(), 38, "Shred", "needsTraining", false) == 0)
S.SetCheckTraining(true)
local needs = A.Timeline(S.Build(), 38, "Shred", "needsTraining", false)
check(#needs == 1 and needs[1].level == 38 and needs[1].status == "Train now")
local trained = A.Timeline(S.Build(), 38, "Shred", "trained", false)
check(#trained == 2 and trained[1].status == "Trained")
sheet = C.Get(S.Build())
sheet.trainedSkills.dataTag = "759c22c2"
check(C.Save(S.Build(), sheet))
check(not A.TrainingReport(S.Build(), 38).ready)
check(#A.Timeline(S.Build(), 38, "Shred", "needsTraining", false) == 0)
S.SetCheckTraining(false)
UI.Toggle()
UI.skillSearch:SetText("Shred")
UI.RefreshBrowser()
local rankRow
for _, row in ipairs(UI.skillRows) do
    if row.shown and row.rank and row.rank.label == "Rank 3" then
        rankRow = row
    end
end
check(rankRow and rankRow.detail:GetText():find("Rank 3", 1, true))
rankRow.scripts.OnClick(rankRow)
check(UI.dialogs.skill.selectedRank == rows[3].rank, "Clicked rank did not open its description")
UI.CloseDialog()
rankRow.check:SetChecked(true)
rankRow.check.scripts.OnClick(rankRow.check)
for _, row in ipairs(UI.skillRows) do
    if row.shown and row.skill and row.skill.name == "Shred" then
        check(row.check:GetChecked(), "Ranks of one skill lost their shared highlight")
    end
end
UI.ClearSkillHighlights()
print("Chronological unlock timeline: " .. checks .. " assertions passed")
