local Mock = dofile("tests/wow_mock.lua")
local FT = Mock.Load()
local M, C, S, P, UI = FT.Model, FT.Codec, FT.Store, FT.Snapshot, FT.UI
local checks = 0
local function check(value, message)
    checks = checks + 1
    assert(value, message)
end
local function greedy(cid)
    local build = M.New(cid, nil, 60, "A friend’s build")
    while #build.order < 51 do
        local placed
        for _, tree in ipairs(M.Class(cid).trees) do
            for _, talent in ipairs(tree.talents) do
                if M.CanAdd(build, talent.id) then
                    build = assert(M.Add(build, talent.id))
                    placed = true
                    break
                end
            end
            if placed then
                break
            end
        end
        assert(placed)
    end
    return build
end
for _, cid in ipairs(FT.classOrder) do
    local build = greedy(cid)
    local code, link = assert(C.Encode(build)), assert(C.BuildLink(build))
    check(link == C.WebURL .. "#build=" .. code)
    local decoded = assert(C.Decode(link))
    check(M.Same(build, decoded) and build.name == decoded.name)
    check(C.Encode(decoded) == code, "Link changed exact FT1 bytes")
    check(M.Same(assert(C.Decode(" \n" .. link .. "\n ")), build))
    local escaped = link:gsub("#build=(.*)", function(text)
        return "#build="
            .. text:gsub(".", function(c)
                return string.format("%%%02X", c:byte())
            end)
    end)
    check(M.Same(assert(C.Decode(escaped)), build))
    local before = assert(FT.Library.Encode())
    check(P.Decode(link).kind == "build")
    check(FT.Library.Encode() == before, "Preview changed library")
    for _, bad in ipairs({
        link:sub(1, -2),
        link .. "&build=" .. code,
        link .. "#other",
        link .. "?x=1",
        link:gsub("https://", "http://"),
        link:gsub("pathofwasd", "other"),
        link:gsub("#build=", "?build="),
        link:gsub("FT1", "FC1"),
        link:gsub("FT1", "FL1"),
        link:gsub("FT1", "FT2"),
        link:gsub("FT1", "FT%%201"),
        link:gsub("FT1", "FT%%+11"),
        link:gsub("FT1", "FT%% 11"),
        link:gsub("FT1", "FT%%GG1"),
        link .. "%",
        link .. "%2",
        link .. "%00",
        C.WebURL .. "#build=" .. string.rep("x", 2049),
    }) do
        local value, why = C.Decode(bad)
        check(not value and type(why) == "string", "Accepted invalid link")
        check(not P.Decode(bad))
    end
    check(FT.Library.Encode() == before, "Invalid link changed library")
end
check(not C.BuildLink({}), "Encoded an invalid build")
check(not C.Decode(nil))
S.SwitchClass(11)
S.SetAutoLevel(true)
S.CreateProfile("Retained")
S.Checkpoint("Retained child")
local before = FT.Copy(S.Build())
local profiles = FT.Library.Pack(S.db.profiles)
local build = greedy(11)
local link = C.BuildLink(build)
UI.Toggle()
UI.ImportDialog(link)
local dialog = UI.dialogs.import
check(dialog.load:IsEnabled())
check(M.Same(S.Build(), before) and S.AutoLevel(), "Preview changed draft")
UI.CloseDialog()
check(M.Same(S.Build(), before))
UI.ImportDialog(link)
dialog.load:Click()
check(M.Same(S.Build(), build) and not S.AutoLevel())
check(FT.Library.Pack(S.db.profiles) == profiles, "Loading removed saved profiles")
S.Undo()
check(M.Same(S.Build(), before) and S.AutoLevel(), "Undo did not restore prior draft and Auto")
S.Redo()
check(M.Same(S.Build(), build))
UI.ShareDialog()
local share = UI.dialogs.share
check(share.code:GetText() == C.Encode(S.ExportView()))
share.link:Click()
check(share.code:GetText() == C.BuildLink(S.ExportView()) and share.code.selected)
share.recipient:UserText("Friend")
share.text:Click()
check(Mock.chatDraft == "/w Friend " .. C.Encode(S.ExportView()), "Whisper stopped using FT1")
UI.ShareDialog()
share.link:Click()
share.string:Click()
check(share.code:GetText() == C.Encode(S.ExportView()))
UI.CloseDialog()
S.Preview(3)
local preview = assert(C.Decode(C.BuildLink(S.ExportView())))
check(#preview.order == 3 and preview.level == 12)
S.Preview(0)
preview = assert(C.Decode(C.BuildLink(S.ExportView())))
check(#preview.order == 0 and preview.level == 1)
S.Preview(nil)
S.Edit(M.New(11, 4, 60))
UI.skillSearch:UserText("Shred")
local row = UI.skillRows[1]
check(row.detail:GetText() == "Lv. 22 · Max rank 5 Lv. 54")
check(row.unlock:IsShown() and not row.nextRank:IsShown() and not row.nextLock:IsShown())
S.Edit(M.New(11, 4, 45))
check(row.detail:GetText() == "Lv. 22 · Rank 3 Lv. 38")
check(row.nextRank:GetText() == "Rank 4 Lv. 46" and row.nextLock:IsShown())
local sheet = FT.Character.Get(S.Build())
sheet.trainedSkills = { schema = 1, classID = 11, raceID = 4, level = 45, spellIDs = { 8992 } }
FT.Character.Save(S.Build(), sheet)
S.Edit(M.New(11, 4, 60))
check(row.detail:GetText() == "Lv. 22 · Rank 3 Lv. 38")
check(
    row.nextRank:IsShown() and not row.nextLock:IsShown(),
    "Already reached next level was labeled locked"
)
S.SetCheckTraining(true)
check(row.detail:GetText() == "Lv. 22 · Max rank 5 Lv. 54")
check(not row.nextRank:IsShown())
UI.skillSearch:UserText("")
S.SwitchClass(3)
S.Edit(M.New(3, nil, 60))
local talent
for _, tree in ipairs(M.Class(3).trees) do
    for _, candidate in ipairs(tree.talents) do
        if candidate.name == "Efficiency" then
            talent = candidate
        end
    end
end
check(talent ~= nil)
local button = UI.talentButtons[talent.id]
button:Trigger("OnEnter")
local lines = {}
for _, line in ipairs(GameTooltip.lines) do
    lines[#lines + 1] = line.text
end
check(table.concat(lines, "\n"):find("Affected skills:", 1, true))
check(table.concat(lines, "\n"):find("Alt click: talent details", 1, true))
before = FT.Copy(S.Build())
Mock.alt = true
button:Click()
Mock.alt = false
local detail = UI.dialogs.talent
check(detail:IsShown() and M.Same(S.Build(), before), "Inspect spent a point")
check(#detail.related == #FT.Skills.TalentSkills(3, talent.id))
check(not detail.add:IsEnabled(), "Locked row allowed allocation")
UI.CloseDialog()
for _, candidate in ipairs(M.Class(3).trees[talent.treeIndex].talents) do
    while #S.Build().order < talent.gate and M.CanAdd(S.Build(), candidate.id) do
        S.Apply(M.Add, candidate.id)
    end
end
before = FT.Copy(S.Build())
Mock.alt = true
button:Click()
Mock.alt = false
check(detail.add:IsEnabled() and not detail.remove:IsEnabled())
detail.add:Click()
check(M.Counts(S.Build())[talent.id] == 1 and detail:IsShown())
detail.remove:Click()
check(M.Same(S.Build(), before))
detail.related[1]:Click()
check(UI.dialogs.skill:IsShown())
UI.CloseDialog()
check(detail:IsShown(), "Related skill closed to home instead of the talent")
detail.close:Click()
Mock.shift = true
button:Click()
Mock.shift = false
button:Click("RightButton")
check(M.Counts(S.Build())[talent.id] == talent.max - 1, "Right-click no longer removes points")
S.Preview(0)
Mock.alt = true
button:Click()
Mock.alt = false
check(not detail.add:IsEnabled() and not detail.remove:IsEnabled())
UI.CloseDialog()
S.Preview(nil)
S.SetSimpleView(true)
Mock.alt = true
button:Click()
Mock.alt = false
check(not detail.relatedTitle:IsShown())
print("PASS build links: " .. checks .. " assertions")
