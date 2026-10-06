local Mock = dofile("tests/wow_mock.lua")
local FT = Mock.Load()
local A, M, S, C, UI = FT.Skills, FT.Model, FT.Store, FT.Character, FT.UI
local checks = 0
local function check(value, message)
    checks = checks + 1
    assert(value, message)
end
local function capture(ids, level)
    local sheet = C.Get(S.Build())
    sheet.trainedSkills = {
        schema = 1,
        classID = S.Build().classID,
        raceID = S.Build().raceID,
        level = level or S.Build().level,
        spellIDs = ids,
    }
    check(C.Save(S.Build(), sheet))
end
S.SwitchClass(11)
check(S.Edit(M.New(11, 4, 25)))
check(not S.CheckTraining(), "Comparison must start off")
check(not A.TrainingReport(S.Build(), 25).enabled)
check(#A.List(S.Build(), 25, "", "needsTraining") == 0)
S.SetCheckTraining(true)
local report = A.TrainingReport(S.Build(), 25)
check(not report.ready and report.total == 0 and not next(report.skills))
check(#A.List(S.Build(), 25, "", "needsTraining") == 0, "Missing import became an empty spellbook")
capture({ 9999999 })
report = A.TrainingReport(S.Build(), 25)
check(not report.ready and not next(report.skills), "Unrecognized IDs marked every skill missing")
capture({ 5177, 5185 })
local before = assert(FT.Library.Encode())
local undo = #S.Draft().undo
report = A.TrainingReport(S.Build(), 25)
check(report.ready and report.total == report.new + report.upgrades)
check(report.skills.Wrath.status == "upgrade")
check(report.skills.Wrath.current.spellID == 5179 and report.skills.Wrath.levelsAway == 0)
check(report.skills.Moonfire.status == "new" and report.skills.Moonfire.needsTraining)
check(report.skills["Travel Form"].status == "future")
check(report.skills["Travel Form"].nextLevel == 30 and report.skills["Travel Form"].levelsAway == 5)
check(not report.skills["Travel Form"].needsTraining)
local needed = A.List(S.Build(), 25, "", "needsTraining")
check(#needed == report.total)
for _, entry in ipairs(needed) do
    check(entry.current and entry.comparison.needsTraining and entry.skill.kind ~= "racial")
end
local searched = A.List(S.Build(), 25, "Wrath", "needsTraining")
check(#searched > 0 and searched[1].skill.name == "Wrath")
check(A.TrainingReport(S.Build(), 25).total == report.total, "Search changed the total")
check(FT.Library.Encode() == before and #S.Draft().undo == undo)
-- A newer trained rank covers older plans, and the boundary updates exactly on level-up.
capture({ 5179, 5188 }, 25)
local wrath = A.TrainingReport(S.Build(), 25).skills.Wrath
check(not wrath.needsTraining and wrath.levelsAway == 5 and wrath.next.spellID == 5180)
wrath = A.TrainingReport(S.Build(), 29).skills.Wrath
check(wrath.levelsAway == 1)
wrath = A.TrainingReport(S.Build(), 30).skills.Wrath
check(wrath.needsTraining and wrath.levelsAway == 0 and wrath.next.spellID == 5180)
wrath = A.TrainingReport(S.Build(), 10).skills.Wrath
check(not wrath.needsTraining and wrath.levelsAway == 20)
capture({ 9912, 25297 }, 60)
wrath = A.TrainingReport(S.Build(), 60).skills.Wrath
check(not wrath.needsTraining and not wrath.progress and not wrath.next)
-- Talent grants (including cast-spell aliases) never become trainer tasks.
for _, case in ipairs({ { 8, "Pyroblast", 20, 24 }, { 4, "Mutilate", 30, 40 } }) do
    local cid, name, at, upgrade = unpack(case)
    S.SwitchClass(cid)
    local skill = A.Prepare(cid).byName[name]
    local build = M.New(cid, nil, 60)
    while not M.CanAdd(build, skill.unlock.id) do
        local added
        for _, talent in ipairs(M.Class(cid).trees[skill.unlock.treeIndex].talents) do
            added = M.Add(build, talent.id)
            if added then
                break
            end
        end
        build = assert(added)
    end
    build = assert(M.Add(build, skill.unlock.id))
    check(S.Edit(build))
    local other = A.Prepare(cid).list[1]
    capture({ other.ranks[1].spellID })
    local granted = A.TrainingReport(build, at).skills[name]
    check(
        not granted.needsTraining and granted.status == "granted",
        name .. " grant sent to trainer"
    )
    if name == "Pyroblast" then
        check(granted.levelsAway == 4)
        check(A.TrainingReport(build, upgrade).skills[name].needsTraining)
    end
    local locked = M.New(cid, nil, 60)
    local status = A.TrainingReport(locked, 60).skills[name]
    check(not status.needsTraining and status.requiresTalent == name and status.levelsAway == 0)
end
-- Capture each class's actual available ranks; missing future skills stay future.
for _, cid in ipairs(FT.classOrder) do
    S.SwitchClass(cid)
    local build = M.New(cid, nil, 35)
    check(S.Edit(build))
    local ids = {}
    for _, skill in ipairs(A.Prepare(cid).list) do
        local current = A.CurrentRank(skill, 35, {})
        if current then
            ids[#ids + 1] = current.spellID
        end
    end
    capture(ids, 35)
    report = A.TrainingReport(build, 35)
    check(report.ready and report.total == 0, "Complete class capture needs training")
    for _, status in pairs(report.skills) do
        check(not status.needsTraining)
        if status.next and not status.requiresTalent then
            check(
                status.next.live
                    and status.nextLevel > 35
                    and status.levelsAway == status.nextLevel - 35
            )
        end
    end
end
-- Actual native controls, local preference and unchanged sharing strings.
S.SwitchClass(11)
check(S.Edit(M.New(11, 4, 25)))
capture({ 5177, 5185 })
UI.Toggle()
check(UI.trainingCheck:GetChecked())
UI.trainingInfo:Click()
check(UI.skillFilterKey == "needsTraining")
for _, row in ipairs(UI.skillRows) do
    if row:IsShown() then
        check(row.comparison.needsTraining and row.progress:GetText() == "↑0")
        row:Trigger("OnEnter")
        check(GameTooltip:IsShown())
        row:Trigger("OnLeave")
    end
end
before = assert(FT.Library.Encode())
UI.trainingCheck:Click()
check(not S.CheckTraining() and UI.skillFilterKey == "all" and not UI.trainingInfo:IsShown())
for _, row in ipairs(UI.skillRows) do
    if row:IsShown() then
        check(not row.comparison and not row.progress:IsShown())
    end
end
check(FT.Library.Encode() == before, "Display preference changed a library string")
UI.trainingCheck:Click()
S.SetSimpleView(true)
UI.trainingInfo:Click()
check(UI.skillFilterKey == "needsTraining" and UI.skillRows[1].comparison.needsTraining)
check(not UI.skillRows[1].check:IsShown())
S.SetSimpleView(false)
local snapshot = assert(FT.Library.Decode(before))
S.SetCheckTraining(false)
check(FT.Library.Merge(snapshot, true))
check(not S.CheckTraining(), "Library sharing replaced recipient's preference")
S.SetCheckTraining(true)
S.Init(11, 4, 25)
check(S.CheckTraining(), "Preference did not survive saved-data reload")
print("Training comparison: " .. checks .. " assertions passed")
