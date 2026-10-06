local Mock = dofile("tests/wow_mock.lua")
local FT = Mock.Load()
local UI, S, M = FT.UI, FT.Store, FT.Model
local checks = 0
local function check(value, message)
    checks = checks + 1
    assert(value, message)
end
local function menuHas(text)
    for _, row in ipairs(UI.menu.rows) do
        if row:IsVisible() and row:GetText() == text then
            return true
        end
    end
    return false
end
UI.Toggle()
S.Apply(M.Add, M.Class(11).trees[1].talents[1].id)
S.CreateProfile("Compact retained build")
S.Checkpoint("Compact retained child")
local sheet = FT.Copy(FT.Character.Get(S.Build()))
sheet.mode, sheet.stats.power = "gear", 125
sheet.gear.head = { name = "Retained hat", stats = { intellect = 15 } }
check(FT.Character.Save(S.Build(), sheet))
local before =
    { FT.Codec.Encode(S.Build()), FT.Library.Encode(), FT.Snapshot.EncodeCharacter(S.Build()) }
local undo = #S.Draft().undo
UI.frame:ClearAllPoints()
UI.frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 80, -90)
UI.compactToggle:Click()
check(UI.CompactView() and UI.frame:GetWidth() == 420 and UI.frame:GetHeight() == 680)
check(UI.simpleToggle:IsVisible() and UI.compactToggle:IsVisible())
check(FT.Codec.Encode(S.Build()) == before[1] and FT.Library.Encode() == before[2])
check(FT.Snapshot.EncodeCharacter(S.Build()) == before[3] and #S.Draft().undo == undo)
check(S.db.settings.position.x == 80 and S.db.settings.position.y == -90)
for _, cid in ipairs(FT.classOrder) do
    UI.classButtons[cid]:Click()
    check(S.Build().classID == cid)
    for i, tree in ipairs(M.Class(cid).trees) do
        UI.compactTreeTabs[i]:Click()
        check(UI.compactTree == i and UI.treePanels[i]:IsVisible())
        check(UI.treePanels[i].body:GetWidth() == 244 and UI.treePanels[i].body:GetHeight() == 410)
        check(UI.treePanels[i]:GetParent() == UI.compactTreeScroll.content)
        check(UI.compactTreeTabs[i]:GetText():find(tree.name, 1, true))
        for j, panel in ipairs(UI.treePanels) do
            check(panel:IsVisible() == (j == i))
        end
        UI.compactTreeScroll:ScrollTo(120)
        local first = UI.talentButtons[tree.talents[1].id]
        local count = #S.Build().order
        first:Click()
        check(#S.Build().order == count + 1)
        check(UI.compactTreeScroll.offset == 120, "point edits moved the compact tree")
        UI.undo:Click()
        check(#S.Build().order == count)
        UI.redo:Click()
        first:Click("RightButton")
        check(#S.Build().order == count)
    end
end
S.SwitchClass(11)
UI.compactTreeTabs[1]:Click()
Mock.Dump("preview/addon-compact.json", UI.frame)
UI.compactTabs.skills:Click()
check(UI.skillsPanel:IsVisible() and not UI.compactTreeScroll:IsVisible())
local row = UI.skillRows[1]
check(row:GetWidth() == 364 and row.check:IsVisible())
row.check:Click()
check(UI.IsSkillHighlighted(row.skill) and row.check.highlightColor)
UI.compactTabs.trees:Click()
check(UI.IsSkillHighlighted(row.skill))
UI.compactTabs.skills:Click()
Mock.Dump("preview/addon-compact-skills.json", UI.frame)
UI.clearHighlight:Click()
check(next(UI.selectedSkills) == nil)
UI.compactTabs.builds:Click()
check(UI.historyPanel:IsVisible() and not UI.skillsPanel:IsVisible())
check(UI.historyRows[1]:GetWidth() == 364)
Mock.Dump("preview/addon-compact-builds.json", UI.frame)
UI.simpleToggle:Click()
check(S.SimpleView() and UI.CompactView() and UI.compactPage == "trees")
check(not UI.compactTabs.builds:IsVisible() and not UI.saveButton:IsVisible())
UI.compactTabs.skills:Click()
row.check:Click()
check(row.check:IsVisible() and UI.IsSkillHighlighted(row.skill))
UI.simpleToggle:Click()
UI.frame:ClearAllPoints()
UI.frame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -40, -55)
UI.compactToggle:Click()
check(UI.frame:GetWidth() == 1280 and UI.frame:GetHeight() == 824)
check(S.db.settings.compactPosition.x == -40 and S.db.settings.compactPosition.y == -55)
check(select(4, UI.frame:GetPoint()) == 80)
for _, panel in ipairs(UI.treePanels) do
    check(panel:GetParent() == UI.frame and panel:IsVisible() and panel:GetWidth() == 246)
end
check(UI.skillRows[1]:GetWidth() == 194 and UI.skillScroll.viewport == 324)
check(UI.historyScroll.viewport == 342 and UI.historyRows[1]:GetWidth() == 214)
UI.compactToggle:Click()
check(select(4, UI.frame:GetPoint()) == -40)
for _, size in ipairs({ { 1920, 1080 }, { 1366, 768 }, { 1024, 768 } }) do
    UIParent:SetSize(unpack(size))
    UI.Fit()
    check(UI.frame:GetWidth() * UI.frame:GetEffectiveScale() <= size[1] - 24)
    check(UI.frame:GetHeight() * UI.frame:GetEffectiveScale() <= size[2] - 24)
    UI.SettingsDialog()
    local settings = UI.dialogs.settings
    check(settings:GetWidth() * settings:GetEffectiveScale() <= size[1] - 24)
    check(settings:GetHeight() * settings:GetEffectiveScale() <= size[2] - 24)
    UI.CloseDialog()
end
UIParent:SetSize(1920, 1080)
S.Init(11, 4, 60)
check(UI.CompactView(), "SavedVariables reload lost compact preference")
for _, invalid in ipairs({
    false,
    "broken",
    { point = "INVALID" },
    { point = "TOP", relativePoint = "TOP", x = 0 / 0, y = 0 },
}) do
    S.db.settings.compactPosition = invalid
    UI.RestoreWindowPosition(true)
    check(select(4, UI.frame:GetPoint()) == -20, "damaged position did not fall back")
end
UI.SetCompactView(false)
check(S.SimulationEnabled() and UI.characterButton:IsVisible())
local library = FT.Library.Encode()
local character = FT.Snapshot.EncodeCharacter(S.Build())
UI.SkillDialog(FT.Skills.Prepare(11).byName.Wrath)
check(UI.dialogs.skill.sim:IsVisible())
UI.CloseDialog()
UI.SettingsDialog()
UI.dialogs.settings.simulation:Click()
check(not S.SimulationEnabled() and UI.dialogs.settings:IsVisible())
check(not UI.characterButton:IsVisible() and not UI.dialogs.skill.sim:IsShown())
UI.CloseDialog()
UI.SkillDialog(FT.Skills.Prepare(11).byName.Wrath)
check(not UI.dialogs.skill.sim:IsVisible())
UI.CloseDialog()
UI.CharacterSheet()
check(not UI.dialogOverlay:IsVisible())
UI.SimulationDialog(FT.Skills.Prepare(11).byName.Wrath, 1)
check(not UI.dialogOverlay:IsVisible())
UI.SetCompactView(true)
UI.compactTabs.more:Click()
check(menuHas("Settings") and not menuHas("Character & experimental simulator"))
UI.menu:Hide()
check(FT.Library.Encode() == library and FT.Snapshot.EncodeCharacter(S.Build()) == character)
S.Init(11, 4, 60)
check(not S.SimulationEnabled())
UI.SettingsDialog()
UI.dialogs.settings.simulation:Click()
check(S.SimulationEnabled())
UI.CloseDialog()
UI.compactTabs.more:Click()
check(menuHas("Character & experimental simulator"))
UI.menu:Hide()
UI.SetCompactView(false)
check(UI.characterButton:IsVisible())
UI.CharacterSheet()
check(UI.dialogs.characterSheet:IsVisible())
check(UI.dialogs.characterSheet.heading:GetText():find("experimental", 1, true))
UI.SettingsDialog()
UI.dialogs.settings.simulation:Click()
UI.CloseDialog()
check(not UI.dialogOverlay:IsVisible(), "closing Settings reopened a hidden experimental tool")
check(not UI.dialogs.characterSheet:IsVisible())
check(FT.Library.Encode() == library and FT.Snapshot.EncodeCharacter(S.Build()) == character)
print("Compact window and experimental settings: " .. checks .. " assertions passed")
