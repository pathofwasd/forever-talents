local Mock = dofile("tests/wow_mock.lua")
local FT = Mock.Load()
local UI, M, S = FT.UI, FT.Model, FT.Store
local checks = 0
local function check(value, message)
    checks = checks + 1
    assert(value, message)
end
local function fillTree(tree, points)
    local guard = 0
    while #S.Build().order < points and guard < 100 do
        local placed = false
        for _, t in ipairs(tree.talents) do
            if M.CanAdd(S.Build(), t.id) then
                S.Apply(M.Add, t.id)
                placed = true
                break
            end
        end
        if not placed then
            break
        end
        guard = guard + 1
    end
end

UI.Toggle()
check(UI.frame:IsShown())
check(UI.frame:GetScale() <= 1)
for _, cid in ipairs(FT.classOrder) do
    UI.classButtons[cid]:Click()
    check(S.Build().classID == cid)
    local count = 0
    for id, b in pairs(UI.talentButtons) do
        count = count + 1
        check(b.talent.id == id and b:IsShown())
        b:Trigger("OnEnter")
        check(GameTooltip:IsShown())
        b:Trigger("OnLeave")
    end
    local expected = 0
    for _, tree in ipairs(M.Class(cid).trees) do
        expected = expected + #tree.talents
    end
    check(count == expected)
    for _, row in ipairs(UI.skillRows) do
        if row:IsShown() then
            row:Trigger("OnEnter")
            row:Trigger("OnLeave")
        end
    end
    UI.RefreshRacials()
    for _, b in ipairs(UI.racialButtons) do
        b:Trigger("OnEnter")
        b:Trigger("OnLeave")
    end
end
S.SwitchClass(11)
local class = M.Class(11)
local first = UI.talentButtons[class.trees[1].talents[1].id]
first:Click()
check(#S.Build().order == 1)
UI.undo:Click()
check(#S.Build().order == 0)
UI.redo:Click()
check(#S.Build().order == 1)
first:Click("RightButton")
check(#S.Build().order == 0)
Mock.shift = true
first:Click()
Mock.shift = false
check(#S.Build().order == first.talent.max)
Mock.ctrl = true
first:Click()
Mock.ctrl = false
check(UI.dialogOverlay:IsShown())
UI.CloseDialog()
UI.talentSearch:UserText("moonkin")
local matches = 0
for _, b in pairs(UI.talentButtons) do
    if b.match then
        matches = matches + 1
    end
end
check(matches >= 1)
check(UI.talentMatches:GetText():find("found", 1, true))
UI.talentSearch:SetText("")
UI.skillSearch:UserText("wrath")
check(UI.skillRows[1].skill.name == "Wrath")
UI.skillSearch:SetText("")
-- Checkboxes pin a union of interactions without opening skill details.
UI.CloseDialog()
local selectedSkills = FT.Skills.Prepare(11)
local wrath, starfire = selectedSkills.byName.Wrath, selectedSkills.byName.Starfire
local function findSkillRow(name)
    for _, row in ipairs(UI.skillRows) do
        if row:IsShown() and row.skill.name == name then
            return row
        end
    end
    error("Missing skill row: " .. name)
end
local function checkHighlightUnion(skills)
    local expected = {}
    for _, skill in ipairs(skills) do
        for _, link in ipairs(skill.related) do
            expected[link.id] = true
        end
    end
    for id in pairs(expected) do
        check(UI.highlight[id], "missing selected talent highlight")
    end
    for id in pairs(UI.highlight) do
        check(expected[id], "unexpected lingering highlight")
    end
end
local wrathRow = findSkillRow("Wrath")
wrathRow.check:Click()
check(wrathRow.check:GetChecked())
check(not UI.dialogOverlay:IsShown())
checkHighlightUnion({ wrath })
local starfireRow = findSkillRow("Starfire")
starfireRow:Trigger("OnEnter")
checkHighlightUnion({ wrath, starfire })
starfireRow:Trigger("OnLeave")
checkHighlightUnion({ wrath })
starfireRow.check:Click()
check(starfireRow.check:GetChecked())
checkHighlightUnion({ wrath, starfire })
UI.SkillDialog(selectedSkills.byName.Moonfire)
UI.CloseDialog()
checkHighlightUnion({ wrath, starfire })
wrathRow.check:Trigger("OnEnter")
wrathRow.check:Click()
check(not wrathRow.check:GetChecked())
checkHighlightUnion({ starfire })
wrathRow.check:Trigger("OnLeave")
UI.skillSearch:UserText("wrath")
check(UI.IsSkillHighlighted(starfire))
check(not UI.skillRows[1].check:GetChecked())
UI.Refresh()
checkHighlightUnion({ starfire })
UI.skillFilterKey = "racial"
UI.skillSearch:SetText("")
UI.RefreshBrowser()
local racialRow = UI.skillRows[1]
local racial = racialRow.skill
check(racial.kind == "racial")
racialRow.check:Click()
check(racialRow.check:GetChecked())
check(UI.racialButtons[1].check:GetChecked(), "footer checkbox did not synchronize")
UI.racialButtons[1].check:Click()
check(not racialRow.check:GetChecked(), "list checkbox did not synchronize")
racialRow.check:Click()
local oldRace = S.Build().raceID
local changedRace = FT.Copy(S.Build())
for _, raceID in ipairs(class.races) do
    if raceID ~= oldRace then
        changedRace.raceID = raceID
        break
    end
end
check(S.Edit(changedRace))
check(UI.IsSkillHighlighted(starfire))
check(not UI.racialButtons[1].check:GetChecked())
for _, skill in pairs(UI.selectedSkills) do
    check(skill.kind ~= "racial", "stale racial selection after changing race")
end
S.Undo()
check(S.Build().raceID == oldRace)
checkHighlightUnion({ starfire })
UI.skillFilterKey = "all"
UI.skillSearch:UserText("wrath")
UI.clearHighlight:Click()
check(next(UI.selectedSkills) == nil)
check(next(UI.highlight) == nil)
UI.skillSearch:SetText("")
check(not findSkillRow("Starfire").check:GetChecked(), "clear missed a filtered-out selection")
findSkillRow("Wrath").check:Click()
check(UI.IsSkillHighlighted(wrath))
UI.Toggle()
UI.Toggle()
check(findSkillRow("Wrath").check:GetChecked(), "selection did not survive closing the planner")
S.SwitchClass(3)
check(next(UI.selectedSkills) == nil)
check(next(UI.highlight) == nil)
S.SwitchClass(11)
-- A numeric level input must never show the overlapping search-clear control.
check(not UI.levelInput.clear:IsShown())
UI.levelInput:UserText("10")
check(not UI.levelInput.clear:IsShown())
UI.levelInput:SetText("60")
check(not UI.levelInput.clear:IsShown())
UI.skillSearch:UserText("wrath")
check(UI.skillSearch.clear:IsShown(), "search clear buttons were removed too")
UI.skillSearch:SetText("")
local manualBeforeAuto = FT.Copy(S.Build())
UI.levelAuto:Click()
check(S.AutoLevel())
check(S.Build().level == M.RequiredLevel(S.Build()))
check(not UI.levelPlus:IsEnabled() and not UI.levelMinus:IsEnabled())
check(UI.levelAuto.active and UI.levelLabel:GetText() == "Level")
local extra = UI.talentButtons[class.trees[2].talents[1].id]
local autoPoints = #S.Build().order
extra:Click()
check(#S.Build().order == autoPoints + 1 and S.Build().level == autoPoints + 10)
extra:Click("RightButton")
check(#S.Build().order == autoPoints and S.Build().level == autoPoints + 9)
UI.undo:Click()
check(S.Build().level == autoPoints + 10 and S.AutoLevel())
UI.redo:Click()
check(S.Build().level == autoPoints + 9 and S.AutoLevel())
UI.levelInput:UserText("60")
check(not UI.levelInput.clear:IsShown())
UI.levelInput:Trigger("OnEnterPressed")
check(UI.levelInput:GetText() == tostring(S.Build().level), "auto level accepted a manual target")
UI.levelAuto:Click()
check(not S.AutoLevel() and M.Same(S.Build(), manualBeforeAuto))
UI.undo:Click()
check(S.AutoLevel())
UI.redo:Click()
check(not S.AutoLevel())
UI.levelInput:UserText("1")
UI.levelInput:Trigger("OnEnterPressed")
check(S.Build().level == 60, "invalid cap accepted")
UI.levelInput:UserText("60")
UI.levelInput:Trigger("OnEnterPressed")
UI.SaveDialog()
local save = UI.dialogs.save
save.input:UserText("Moonkin journey")
save.save:Click()
check(S.ActiveProfile())
check(not UI.dialogOverlay:IsShown())
fillTree(class.trees[1], 31)
S.Checkpoint("Moonkin at 40")
local p, node = S.ActiveProfile()
check(node.parent == 1)
S.LoadNode(p.id, 1)
S.Apply(M.Add, class.trees[2].talents[1].id)
S.Checkpoint("Feral detour")
UI.historyTab = "graph"
UI.RefreshHistory()
check(UI.historyRows[1]:IsShown())
UI.historyTabs.graph:Click()
local graphWorkspace = UI.dialogs.graph
check(graphWorkspace:IsVisible() and graphWorkspace:GetWidth() == 1040)
check(graphWorkspace.rows[3]:IsShown())
check(graphWorkspace.rows[3].title.wrap and graphWorkspace.rows[3].title:GetWidth() == 244)
check(graphWorkspace.rows[3]:GetWidth() == 272 and graphWorkspace.rows[3]:GetHeight() == 76)
graphWorkspace.checkpoint:Click()
UI.dialogs.save.input:UserText("Checkpoint from workspace")
UI.dialogs.save.save:Click()
check(
    graphWorkspace:IsVisible() and not UI.dialogs.save:IsShown(),
    "Saving did not return to the checkpoint workspace"
)
check(
    graphWorkspace.rows[4]:IsShown()
        and graphWorkspace.rows[4].title:GetText() == "Checkpoint from workspace"
)
graphWorkspace.share:Click()
check(FT.Library.IsProfileShare(UI.dialogs.share.code:GetText()))
UI.CloseDialog()
check(graphWorkspace:IsVisible(), "Sharing did not return to the checkpoint workspace")
UI.CloseDialog()
UI.historyTab = "order"
UI.RefreshHistory()
UI.historyRows[1]:Click()
check(S.preview == 1)
UI.previewBack:Click()
check(S.preview == nil)
UI.ShareDialog()
local share = UI.dialogs.share
check(share.code.selected and share.code:GetText():find("FT1:", 1, true))
share.recipient:UserText("Friend")
share.text:Click()
check(Mock.chatDraft:find("/w Friend FT1:", 1, true))
local code = FT.Codec.Encode(S.Build())
local before = FT.Copy(S.Build())
UI.ImportDialog("bad code")
check(not UI.dialogs.import.load:IsEnabled())
check(M.Same(S.Build(), before))
UI.dialogs.import.input:UserText(code)
check(UI.dialogs.import.load:IsEnabled())
UI.dialogs.import.load:Click()
check(not S.ActiveProfile(), "import attached itself to an existing profile")
UI.RaceDialog()
check(#UI.dialogs.races.cells == 90)
UI.CloseDialog()
for _, cell in ipairs(UI.dialogs.races.cells) do
    check(cell.button:IsEnabled() == M.RaceAllowed(cell.classID, cell.raceID))
    if cell.button:IsEnabled() then
        UI.RaceDialog()
        cell.button:Click()
        check(
            S.Build().classID == cell.classID and S.Build().raceID == cell.raceID,
            "race atlas selected the wrong cell"
        )
    end
end
S.SwitchClass(11)
UI.SettingsDialog()
check(UI.dialogs.settings:IsShown())
UI.CloseDialog()
UI.PetDialog()
check(UI.dialogs.pets.rows[1]:IsShown())
UI.dialogs.pets.switch:Click()
check(UI.dialogs.pets.count:GetText():find("750", 1, true))
UI.dialogs.pets.next:Click()
check(UI.dialogs.pets.page == 2)
UI.CloseDialog()
UI.PerkDialog()
check(UI.dialogs.perks:IsShown())
UI.CloseDialog()
UI.HelpDialog()
check(UI.dialogs.help:IsShown())
UI.CloseDialog()
local skills = FT.Skills.Prepare(11)
UI.SkillDialog(skills.byName.Wrath)
check(UI.dialogs.skill.rankRows[1]:IsShown())
UI.dialogs.skill.sim:Click()
local sim = UI.dialogs.simulation
check(sim:IsShown())
sim.fields.power:UserText("500")
check(sim.cards[1].value:GetText() ~= "—")
sim.advancedButton:Click()
check(sim.advancedPanel:IsShown())
sim.fields.coefficient:UserText("100")
sim.stats:Click()
check(sim.fields.power:GetText() == "200")
local beforeEstimate = sim.cards[3].value:GetText()
for _, t in ipairs(class.trees[1].talents) do
    if t.name == "Nature's Majesty" then
        check(S.Apply(M.Add, t.id))
    end
end
check(
    sim.cards[3].value:GetText() ~= beforeEstimate,
    "open estimate did not refresh after a build edit"
)
S.Undo()
check(sim.cards[3].value:GetText() == beforeEstimate, "open estimate stayed stale after Undo")
local oldRead, oldCrit = FT.ReadPlayerBuild, GetSpellCritChance
local live = M.New(11)
local ranks = {}
for _, t in ipairs(class.trees[1].talents) do
    if t.name == "Improved Wrath" or t.name == "Genesis" then
        ranks[t.id] = 5
    elseif t.name == "Nature's Majesty" then
        ranks[t.id] = 2
    end
end
live = M.FromRanks(11, 4, 60, ranks, "Live stats fixture")
check(live)
FT.ReadPlayerBuild = function()
    return live
end
GetSpellCritChance = function()
    return 14
end
sim.stats:Click()
check(sim.fields.crit:GetText() == "10", "copied learned crit bonus counted twice")
check(sim.statsNote:find("4.0%", 1, true))

-- The central workspace and skill overrides have separate lifetimes.
UI.CharacterSheet()
local characterSheet = UI.dialogs.characterSheet
check(characterSheet:IsShown() and characterSheet.gearButtons.head:IsShown())
characterSheet.modeButtons.manual:Click()
characterSheet.fields.power:UserText("321")
check(FT.Character.Get(S.View()).stats.power == 321)
UI.GearDialog("head")
local gearEditor = UI.dialogs.gear
check(not gearEditor.weaponFields.low:IsShown() and not gearEditor.weaponLabels.low:IsShown())
gearEditor.name:SetText("Test circlet")
gearEditor.fields.intellect:SetText("20")
gearEditor.equip:Click()
check(FT.Character.Get(S.View()).gear.head.name == "Test circlet")
UI.SimulationDialog(FT.Skills.Prepare(11).byName.Wrath, FT.Skills.Prepare(11).byName.Wrath.ranks[1])
sim.fields.power:UserText("999")
check(FT.Character.Get(S.View()).stats.power == 321, "skill edit changed central stats")
sim.reset:Click()
check(sim.fields.power:GetText() == "321")
UI.CharacterSheet()
check(UI.dialogs.characterSheet.fields.power:GetText() == "321")
UI.CloseDialog()

FT.ReadPlayerBuild, GetSpellCritChance = oldRead, oldCrit
UI.SimulationHelp()
check(UI.dialogs.simulationHelp:IsShown())
UI.CloseDialog()
S.LoadNode(p.id, 1)
UI.GraphDialog()
UI.CloseDialog()
UI.raceButton:Click()
UI.menu:Hide()
local oldCount = #Mock.objects
for i = 1, 15 do
    UI.GraphDialog()
    UI.CloseDialog()
    UI.raceButton:Click()
    UI.menu:Hide()
    UI.historyTab = i % 2 == 0 and "order" or "graph"
    UI.RefreshHistory()
end
check(#Mock.objects <= oldCount + 4, "reopening graph/menu keeps allocating UI objects")
UI.SkillDialog(skills.byName["Moonkin Form"])
UI.CloseDialog()
S.RenameProfile(p.id, "Renamed journey")
S.LoadNode(p.id, 1)
UI.ShareDialog()
check(FT.Codec.Decode(UI.dialogs.share.code:GetText()).name == "Renamed journey")
UI.CloseDialog()
Mock.focus = nil
Mock.ctrl = true
UI.frame:Trigger("OnKeyDown", "Z")
Mock.ctrl = false
check(UI.frame.propagate == false)
UI.Toggle()
check(not UI.frame:IsShown())
UI.Toggle()

-- Node deletion is discoverable in both graphs, counted, and cancellable.
S.Import(M.New(11))
local deletionProfile = S.CreateProfile("Disposable UI fixture")
S.Apply(M.Add, class.trees[1].talents[1].id)
local deletionParent = S.Checkpoint("Delete branch")
S.Apply(M.Add, class.trees[1].talents[1].id)
local deletionChild = S.Checkpoint("Delete child")
S.LoadNode(deletionProfile.id, 1)
S.Apply(M.Add, class.trees[2].talents[1].id)
local deletionSibling = S.Checkpoint("Keep sibling")
S.LoadNode(deletionProfile.id, deletionParent.id)
local deletionWorking = FT.Copy(S.Build())
UI.historyTab = "graph"
UI.RefreshHistory()
check(UI.historyRows[2].delete:IsShown())
UI.historyRows[2].delete:Click()
local deletionDialog = UI.dialogs.deleteNode
check(deletionDialog:IsVisible() and deletionDialog.delete:GetText():find("(2)", 1, true))
deletionDialog.keep:Click()
check(#deletionProfile.order == 4 and M.Same(S.Build(), deletionWorking))
UI.GraphDialog()
UI.dialogs.graph.rows[2].delete:Click()
check(deletionDialog:IsVisible())
deletionDialog.delete:Click()
check(not deletionProfile.nodes[deletionParent.id] and not deletionProfile.nodes[deletionChild.id])
check(deletionProfile.nodes[deletionSibling.id] and #deletionProfile.order == 2)
check(S.Draft().nodeID == 1 and M.Same(S.Build(), deletionWorking))
check(UI.dialogs.graph:IsVisible())
check(not UI.dialogs.graph.rows[3]:IsShown(), "unsaved edits created a draft node")
check(UI.dialogs.graph.rows[1].active, "active node lost its highlight")
UI.dialogs.graph.rows[2].delete:Click()
check(deletionDialog.delete:GetText() == "Delete checkpoint")
deletionDialog.delete:Click()
check(#deletionProfile.order == 1 and M.Same(S.Build(), deletionWorking))
UI.CloseDialog()
UI.RefreshHistory()
UI.historyRows[1].delete:Click()
check(deletionDialog.delete:GetText():find("Delete profile", 1, true))
deletionDialog.delete:Click()
check(not S.db.profiles[deletionProfile.id] and not S.ActiveProfile())
check(M.Same(S.Build(), deletionWorking))
UI.historyTab = "order"
UI.RefreshHistory()
for _, row in ipairs(UI.historyRows) do
    check(not row.delete:IsVisible(), "node deletion control leaked into talent order rows")
end
S.LoadNode(p.id, 1)

-- Render a useful, legal example through the same Lua functions as the addon.
S.SwitchClass(11)
S.Preview(nil)
S.Apply(M.Reset)
UI.talentSearch:SetText("")
UI.skillSearch:SetText("")
UI.ClearSkillHighlights()
local function spend(name, n)
    for _, t in ipairs(class.trees[1].talents) do
        if t.name == name then
            for i = 1, n do
                check(S.Apply(M.Add, t.id), "invalid example point: " .. name)
            end
            return
        end
    end
    error("unknown example talent: " .. name)
end
spend("Improved Wrath", 5)
local root = S.CreateProfile("Moonkin journey")
spend("Genesis", 5)
spend("Improved Moonfire", 2)
spend("Nature's Majesty", 2)
spend("Moonglow", 1)
S.Checkpoint("Caster foundations")
spend("Vengeance", 5)
spend("Nature's Grace", 1)
spend("Improved Starfire", 4)
spend("Moonfury", 5)
spend("Moonkin Form", 1)
S.Checkpoint("Moonkin at 40")
S.LoadNode(root.id, 2)
S.Apply(M.Add, class.trees[2].talents[1].id, true)
S.Checkpoint("Feral utility")
S.LoadNode(root.id, 3)
UI.historyTab = "order"
UI.Refresh()
UI.frame:Show()
UI.SetSkillHighlight(skills.byName.Wrath, true)
UI.SetSkillHighlight(skills.byName.Starfire, true)
UI.levelAuto:Click()
Mock.Dump("preview/main.json", UI.frame)
UI.historyTab = "graph"
UI.RefreshHistory()
Mock.Dump("preview/checkpoints.json", UI.frame)
UI.GraphDialog()
Mock.Dump("preview/graph.json", UI.frame)
UI.CloseDialog()
UI.SkillDialog(skills.byName.Wrath)
Mock.Dump("preview/skill.json", UI.frame)
UI.CloseDialog()
UI.SimulationDialog(
    skills.byName.Wrath,
    FT.Skills.CurrentRank(skills.byName.Wrath, 60, M.Counts(S.Build()))
)
sim.fields.power:UserText("500")
sim.fields.crit:UserText("15")
sim.fields.coefficient:UserText("57.1")
if sim.advanced then
    sim.advancedButton:Click()
end
Mock.Dump("preview/simulation.json", UI.frame)
sim.advancedButton:Click()
Mock.Dump("preview/advanced.json", UI.frame)
UI.CloseDialog()
UI.RaceDialog()
Mock.Dump("preview/races.json", UI.frame)
UI.CloseDialog()
UI.PetDialog()
Mock.Dump("preview/pets.json", UI.frame)
UI.CloseDialog()
-- Deep branches open at the selected node and retain manual graph scrolling.
local deep = S.CreateProfile("Deep checkpoint workspace")
for i = 1, 25 do
    check(S.Checkpoint("Long checkpoint title for branch depth " .. i))
end
UI.historyTabs.graph:Click()
local graph = UI.dialogs.graph
check(graph.rows[26]:IsShown() and graph.horizontal:IsShown())
local selectedX, selectedY = 14 + 25 * 52, 14 + 25 * 96
check(
    selectedY - graph.scroll.offset >= 0
        and selectedY - graph.scroll.offset + 76 <= graph.scroll.viewport
)
check(
    selectedX - graph.horizontal:GetValue() >= 0
        and selectedX - graph.horizontal:GetValue() + 272 <= 984
)
graph.scroll:ScrollTo(100)
graph.horizontal:SetValue(50)
UI.GraphDialog()
check(
    graph.scroll.offset == 100 and graph.horizontal:GetValue() == 50,
    "Refreshing reset manual graph scrolling"
)
UI.CloseDialog()
check(S.LoadNode(deep.id, 1))
UI.historyTabs.graph:Click()
check(
    graph.scroll.offset == 0 and graph.horizontal:GetValue() == 0,
    "Root selection retained a deep-node viewport"
)
UI.CloseDialog()
-- Native update controls replace a snapshot without growing its graph.
local editable = S.CreateProfile("Editable checkpoint controls")
local t = M.Class(S.Build().classID).trees[1].talents[1].id
check(S.Apply(M.Reset))
check(S.UpdateCheckpoint())
local oldNodes = #editable.order
check(S.Apply(M.Add, t))
UI.historyTab = "order"
UI.RefreshHistory()
check(UI.checkpointButton:GetText() == "Save as new checkpoint")
UI.GraphDialog()
check(UI.dialogs.graph.update:IsEnabled())
UI.dialogs.graph.update:Click()
check(not S.Dirty() and #editable.order == oldNodes)
check(not UI.dialogs.graph.update:IsEnabled())
check(S.Apply(M.Add, t))
UI.RefreshHistory()
UI.saveButton:Click()
check(not S.Dirty() and #editable.order == oldNodes)
UI.GraphDialog()
UI.dialogs.graph.checkpoint:Click()
UI.dialogs.save.input:SetText("Separate branch")
UI.dialogs.save.save:Click()
check(#editable.order == oldNodes + 1)
check(UI.dialogs.graph:IsShown())

print(
    string.format(
        "UI: %d assertions passed; %d recorded objects; screenshots use actual Lua widget geometry",
        checks,
        #Mock.objects
    )
)
