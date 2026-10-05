local Mock = dofile("tests/wow_mock.lua")
local FT = Mock.Load()
local UI, S, M = FT.UI, FT.Store, FT.Model
local checks = 0
local function check(value, message)
    checks = checks + 1
    assert(value, message)
end

UI.Toggle()
S.Apply(M.Add, M.Class(11).trees[1].talents[1].id)
S.CreateProfile("Kept build")
S.Checkpoint("Kept checkpoint")
local buildCode = FT.Codec.Encode(S.Build())
local libraryCode = FT.Library.Encode()
local undoCount = #S.Draft().undo
UI.skillFilterKey = "racial"
UI.RefreshBrowser()
UI.racialButtons[1].check:Click()
UI.SettingsDialog()
local settings = UI.dialogs.settings
settings.classic:Click()
check(S.SimpleView() and settings:IsVisible())
check(UI.frame:GetWidth() == 1028 and UI.frame:GetHeight() == 758)
check(FT.Codec.Encode(S.Build()) == buildCode)
check(FT.Library.Encode() == libraryCode, "view preference changed a portable library")
check(#S.Draft().undo == undoCount)
for _, control in ipairs(UI.fullControls) do
    check(not control:IsVisible(), "extra control visible in Classic mode")
end
check(UI.heroRace:GetText() == "Classic mode")
check(next(UI.highlight) == nil)
check(not UI.clearHighlight:IsVisible())
UI.CloseDialog()
for _, cid in ipairs(FT.classOrder) do
    UI.classButtons[cid]:Click()
    check(S.Build().classID == cid)
    check(UI.skillFilter:GetText() == "All class skills  v")
    for _, row in ipairs(UI.skillRows) do
        if row:IsVisible() then
            check(row.skill.kind ~= "racial")
            check(not row.check:IsVisible())
            row:Trigger("OnEnter")
            check(next(UI.highlight) == nil)
            check(GameTooltip:IsShown())
            row:Trigger("OnLeave")
            row:Click()
            local f = UI.dialogs.skillLevels
            check(f:IsVisible())
            check(not (UI.dialogs.skill and UI.dialogs.skill:IsVisible()))
            local levels = FT.Skills.Levels(row.skill)
            for i, level in ipairs(levels) do
                check(f.levelRows[i]:GetText():find("Level " .. level.level, 1, true))
            end
            UI.CloseDialog()
        end
    end
    local first = UI.talentButtons[M.Class(cid).trees[1].talents[1].id]
    local before = #S.Build().order
    first:Click()
    check(#S.Build().order == before + 1)
    UI.undo:Click()
    check(#S.Build().order == before)
    UI.redo:Click()
    check(#S.Build().order == before + 1)
    UI.undo:Click()
end
S.SwitchClass(11)
check(FT.Codec.Encode(S.Build()) == buildCode)
check(S.SimpleView())
S.Init(11, 4, 60)
check(S.SimpleView(), "view preference did not survive SavedVariables reload")
S.Preview(0)
S.SetSimpleView(true)
check(S.preview == nil)
UI.SkillDialog(FT.Skills.Prepare(11).byName.Wrath)
check(UI.dialogs.skillLevels:IsVisible())
S.SetSimpleView(false)
check(not UI.dialogOverlay:IsVisible(), "mode switch left the old skill dialog visible")
check(UI.frame:GetWidth() == 1280 and UI.frame:GetHeight() == 824)
for _, control in ipairs(UI.fullControls) do
    check(control:IsVisible(), "full view did not restore a control")
end
check(UI.skillFilterKey == "racial", "mode switch changed the full-view filter")
UI.SkillDialog(FT.Skills.Prepare(11).byName.Wrath)
check(UI.dialogs.skill.sim:IsVisible())
UI.CloseDialog()
SlashCmdList.FOREVERTALENTS("classic")
check(S.SimpleView())
SlashCmdList.FOREVERTALENTS("full")
check(not S.SimpleView())
S.SetSimpleView(true)
Mock.Dump("preview/addon-classic.json", UI.frame)
UI.SettingsDialog()
Mock.Dump("preview/addon-classic-settings.json", UI.dialogs.settings)
UI.CloseDialog()
UI.SkillDialog(FT.Skills.Prepare(11).byName.Wrath)
Mock.Dump("preview/addon-classic-levels.json", UI.dialogs.skillLevels)
print("Classic view: " .. checks .. " assertions passed")
