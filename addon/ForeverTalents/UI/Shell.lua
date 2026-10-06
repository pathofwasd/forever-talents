local _, FT = ...
local UI, W, M, S = FT.UI, FT.UI.W, FT.Model, FT.Store
local WIDTH, HEIGHT = 1280, 824

function UI.Status(message, errorState)
    UI.lastStatus = message
    if UI.status then
        UI.status:SetText(message)
        UI.status:SetTextColor(unpack(errorState and { 1, 0.48, 0.40 } or W.colors.muted))
    end
end

function UI.Fit()
    if not UI.frame then
        return
    end
    local fit = math.min(
        (UIParent:GetWidth() - 24) / UI.frame:GetWidth(),
        (UIParent:GetHeight() - 24) / UI.frame:GetHeight()
    )
    UI.frame:SetScale(math.min(S.db.settings.scale or 1, fit))
end

function UI.RefreshViewMode()
    local simple = S.SimpleView()
    if UI.lastSimpleView == simple then
        return
    end
    UI.lastSimpleView = simple
    local width, height = simple and 1028 or WIDTH, simple and 758 or HEIGHT
    UI.frame:SetSize(width, height)
    UI.drag:SetWidth(width - (simple and 80 or 430))
    UI.toolbar:SetWidth(width - 32)
    UI.hero:SetWidth(width - 32)
    for _, control in ipairs(UI.fullControls) do
        control:SetShown(not simple)
    end
    for _, item in ipairs({
        { UI.levelLabel, 653, -16 },
        { UI.levelMinus, 706, -8 },
        { UI.levelInput, 734, -8 },
        { UI.levelPlus, 776, -8 },
        { UI.levelAuto, 804, -8 },
        { UI.undo, 862, -8 },
        { UI.redo, 926, -8 },
        { UI.reset, 990, -8 },
    }) do
        item[1]:ClearAllPoints()
        item[1]:SetPoint("TOPLEFT", item[2] - (simple and 273 or 0), item[3])
    end
    for _, item in ipairs({ { UI.heroLevel, -10 }, { UI.heroBudget, -39 } }) do
        item[1]:ClearAllPoints()
        item[1]:SetPoint("TOPRIGHT", -16, item[2])
        item[1]:SetWidth(simple and 226 or 282)
    end
    for _, item in ipairs({ { UI.heroTrees, -16 }, { UI.heroHint, -39 } }) do
        item[1]:ClearAllPoints()
        item[1]:SetPoint("TOPLEFT", simple and 300 or 376, item[2])
        item[1]:SetWidth(simple and 434 or (item[1] == UI.heroTrees and 512 or 572))
    end
    UI.status:ClearAllPoints()
    UI.status:SetPoint("TOPLEFT", 22, -(height - 23))
    UI.status:SetWidth(width - 150)
    UI.closeButton:ClearAllPoints()
    UI.closeButton:SetPoint("TOPRIGHT", -20, -13)
    UI.settingsButton:ClearAllPoints()
    UI.settingsButton:SetPoint("BOTTOMRIGHT", -16, 8)
    if UI.dialogs and not (UI.dialogs.settings and UI.dialogs.settings:IsVisible()) then
        UI.CloseDialog(true)
    end
    if GameTooltip then
        GameTooltip:Hide()
    end
    UI.hoverSkill = nil
    UI.Fit()
end

local function changeLevel(delta)
    if S.AutoLevel() then
        return
    end
    local build = FT.Copy(S.Build())
    build.level = math.max(1, math.min(60, build.level + delta))
    W.Result(S.Edit(build))
end

function UI.Create()
    if UI.frame then
        return
    end
    local f = CreateFrame("Frame", "ForeverTalentsWindow", UIParent, "BackdropTemplate")
    f:SetSize(WIDTH, HEIGHT)
    f:SetPoint("CENTER")
    f:SetFrameStrata("HIGH")
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    W.Skin(f, W.colors.bg, { 0.32, 0.36, 0.40 })
    UI.frame = f
    table.insert(UISpecialFrames, "ForeverTalentsWindow")
    local drag = CreateFrame("Frame", nil, f)
    UI.drag = drag
    drag:SetPoint("TOPLEFT", 1, -1)
    drag:SetSize(WIDTH - 430, 50)
    drag:EnableMouse(true)
    drag:RegisterForDrag("LeftButton")
    f:SetMovable(true)
    drag:SetScript("OnDragStart", function()
        f:StartMoving()
    end)
    drag:SetScript("OnDragStop", function()
        f:StopMovingOrSizing()
        local point, _, relativePoint, x, y = f:GetPoint()
        S.db.settings.position = { point = point, relativePoint = relativePoint, x = x, y = y }
    end)
    W.Text(f, "Forever Talents", 22, -16, 270, 23, W.colors.gold)
    UI.buildName = W.Text(f, "", 302, -20, 550, 14)
    UI.buildName:SetWordWrap(false)
    UI.saveButton = W.Button(f, "Save build", 902, -13, 110, function()
        UI.SaveDialog(S.ActiveProfile() ~= nil)
    end, true, 31)
    UI.shareButton = W.Button(f, "Share", 1024, -13, 90, function()
        UI.ShareDialog()
    end, false, 31)
    UI.importButton = W.Button(f, "Import", 1126, -13, 86, function()
        UI.ImportDialog()
    end, false, 31)
    UI.closeButton = W.Button(f, "x", 1224, -13, 36, function()
        f:Hide()
    end, false, 31)
    local toolbar = W.Panel(f, 16, -58, 1248, 44, { 0.069, 0.081, 0.096 })
    UI.toolbar = toolbar
    UI.classButtons = {}
    for i, cid in ipairs(FT.classOrder) do
        local c = M.Class(cid)
        local b = W.Button(toolbar, "", 8 + (i - 1) * 40, -5, 35, function()
            S.SwitchClass(cid)
        end, false, 34)
        local icon = W.Icon(b, c.icon, 3, -3, 29)
        b.tip = c.name .. " • drafts are kept when changing class"
        UI.classButtons[cid] = b
    end
    UI.raceButton = W.Button(toolbar, "", 380, -8, 204, function(self)
        local options = {}
        local build = S.Build()
        for _, rid in ipairs(M.Class(build.classID).races) do
            local race = FT.Data.races[rid]
            options[#options + 1] = {
                text = race.name .. " • " .. race.faction,
                action = function()
                    local nextBuild = FT.Copy(S.Build())
                    nextBuild.raceID = rid
                    W.Result(S.Edit(nextBuild))
                end,
            }
        end
        W.Menu(self, options, 286)
    end)
    UI.racesButton = W.Button(toolbar, "Races", 592, -8, 52, UI.RaceDialog)
    UI.levelLabel = W.Text(toolbar, "Target", 653, -16, 52, 11, W.colors.muted)
    UI.levelMinus = W.Button(toolbar, "−", 706, -8, 24, function()
        changeLevel(-1)
    end)
    UI.levelInput = W.Edit(toolbar, "60", 734, -8, 38, nil, 2)
    UI.levelInput.hideClear = true
    UI.levelInput:SetTextInsets(6, 6, 0, 0)
    UI.levelInput.clear:Hide()
    UI.levelInput.placeholder:SetWidth(26)
    UI.levelInput:SetScript("OnEditFocusGained", function(self)
        if S.AutoLevel() then
            self:ClearFocus()
            UI.Status("Turn off Auto to enter a manual target level.")
        end
    end)
    UI.levelInput:SetScript("OnEnterPressed", function(self)
        if S.AutoLevel() then
            self:SetText(S.Build().level)
            self:ClearFocus()
            return
        end
        local level = tonumber(self:GetText())
        local build = FT.Copy(S.Build())
        if not level then
            UI.Status("Enter a target level from 1 to 60.", true)
            self:SetText(build.level)
        else
            build.level = level
            if not W.Result(S.Edit(build)) then
                self:SetText(S.Build().level)
            end
        end
        self:ClearFocus()
    end)
    UI.levelPlus = W.Button(toolbar, "+", 776, -8, 24, function()
        changeLevel(1)
    end)
    UI.levelAuto = W.Button(toolbar, "Auto", 804, -8, 48, function()
        W.Result(S.SetAutoLevel(not S.AutoLevel()))
    end)
    UI.levelAuto.tip =
        "Automatically raise or lower your planned level as talents are added or removed. First point = level 10, 51 points = level 60. With no talents, level 1 is shown. Turn off Auto to restore your manual target."
    UI.undo = W.Button(toolbar, "Undo", 862, -8, 56, function()
        W.Result(S.Undo())
    end)
    UI.undo.tip = "Undo the last edit (Ctrl+Z). Up to 100 changes per class are kept."
    UI.redo = W.Button(toolbar, "Redo", 926, -8, 56, function()
        W.Result(S.Redo())
    end)
    UI.redo.tip = "Redo an undone edit (Ctrl+Y or Ctrl+Shift+Z). A new edit starts a new path."
    UI.reset = W.Button(toolbar, "Reset", 990, -8, 68, function()
        W.Result(S.Apply(M.Reset))
        UI.Status("Build reset. Undo restores it.")
    end)
    UI.reset.tip = "Clear all trees. Your checkpoints stay saved; Undo restores this draft."
    UI.characterButton = W.Button(toolbar, "Character", 1066, -8, 94, UI.CharacterSheet)
    UI.helpButton = W.Button(toolbar, "Help", 1168, -8, 72, UI.HelpDialog)
    local hero = W.Panel(f, 16, -112, 1248, 62, { 0.067, 0.097, 0.123 })
    UI.hero = hero
    UI.heroIcon = W.Icon(hero, "class_druid", 12, -8, 46)
    UI.heroClass = W.Text(hero, "", 74, -10, 260, 22)
    UI.heroRace = W.Text(hero, "", 75, -39, 310, 11, W.colors.muted)
    UI.heroTrees = W.Text(hero, "", 376, -16, 512, 15, W.colors.gold)
    UI.heroHint = W.Text(hero, "", 376, -39, 572, 11, W.colors.muted)
    UI.heroLevel = W.Text(hero, "", 950, -10, 282, 22)
    UI.heroLevel:SetJustifyH("RIGHT")
    UI.heroBudget = W.Text(hero, "", 950, -39, 282, 11, W.colors.muted)
    UI.heroBudget:SetJustifyH("RIGHT")
    UI.CreateBrowser(f)
    local talentbar = W.Panel(f, 252, -188, 750, 38)
    W.Text(talentbar, "Talents", 12, -12, 82, 14)
    UI.talentSearch = W.Edit(talentbar, "Search talents or effects…", 96, -5, 456, function(text)
        UI.talentQuery = text
        UI.RefreshTrees()
    end)
    UI.talentMatches = W.Text(talentbar, "", 568, -12, 168, 13, W.colors.gold)
    UI.talentMatches:SetJustifyH("RIGHT")
    UI.CreateTrees(f)
    UI.CreateHistory(f)
    local racial = W.Panel(f, 16, -728, 1248, 54)
    UI.racialPanel = racial
    UI.racialTitle = W.Text(racial, "", 12, -12, 200, 11, W.colors.muted)
    UI.racialButtons = {}
    for i = 1, 4 do
        local b = W.Button(racial, "", 222 + (i - 1) * 254, -8, 248, function(self)
            UI.SkillDialog(self.skill)
        end, false, 38)
        b.icon = W.Icon(b, "class_druid", 7, -6, 26)
        b.title = W.Text(b, "", 42, -12, 170, 12, W.colors.gold)
        b.title:SetWordWrap(false)
        UI.AddHighlightCheckbox(b, 220, -9)
        b:SetScript("OnEnter", function(self)
            self:Paint(true)
            UI.HighlightSkill(self.skill)
            UI.SkillTooltip(self, self.skill)
        end)
        b:SetScript("OnLeave", function(self)
            self:Paint(false)
            GameTooltip:Hide()
            UI.HighlightSkill(nil)
        end)
        UI.racialButtons[i] = b
    end
    UI.status = W.Text(
        f,
        "Click to add • Right click to remove • Shift to fill • Alt: talent details",
        22,
        -801,
        1040,
        11,
        W.colors.muted
    )
    UI.settingsButton = W.Button(f, "Settings", 1172, -792, 92, UI.SettingsDialog, false, 24)
    UI.fullControls = {
        UI.saveButton,
        UI.shareButton,
        UI.importButton,
        UI.raceButton,
        UI.racesButton,
        UI.characterButton,
        UI.helpButton,
        UI.historyPanel,
        UI.racialPanel,
    }
    f:SetScript("OnShow", function()
        UI.Fit()
        UI.Refresh()
    end)
    f:SetScript("OnHide", function()
        UI.CloseDialog(true)
        if UI.menu then
            UI.menu:Hide()
        end
        if GameTooltip then
            GameTooltip:Hide()
        end
        UI.HighlightSkill(nil)
    end)
    f:EnableKeyboard(true)
    if f.SetPropagateKeyboardInput then
        f:SetPropagateKeyboardInput(true)
        f:SetScript("OnKeyDown", function(self, key)
            local focus = GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus()
            local consumed = false
            if not focus and IsControlKeyDown() then
                if key == "Z" then
                    if IsShiftKeyDown() then
                        W.Result(S.Redo())
                    else
                        W.Result(S.Undo())
                    end
                    consumed = true
                elseif key == "Y" then
                    W.Result(S.Redo())
                    consumed = true
                end
            end
            if not InCombatLockdown or not InCombatLockdown() then
                self:SetPropagateKeyboardInput(not consumed)
            end
        end)
    end
    local p = S.db.settings.position
    if
        type(p) == "table"
        and type(p.point) == "string"
        and type(p.relativePoint) == "string"
        and type(p.x) == "number"
        and type(p.y) == "number"
    then
        local anchors = {
            TOP = true,
            TOPLEFT = true,
            TOPRIGHT = true,
            BOTTOM = true,
            BOTTOMLEFT = true,
            BOTTOMRIGHT = true,
            LEFT = true,
            RIGHT = true,
            CENTER = true,
        }
        if anchors[p.point] and anchors[p.relativePoint] then
            f:ClearAllPoints()
            f:SetPoint(p.point, UIParent, p.relativePoint, p.x, p.y)
        end
    end
    UI.RefreshViewMode()
    f:Hide()
end

function UI.Refresh()
    if not UI.frame then
        return
    end
    UI.RefreshViewMode()
    if UI.menu then
        UI.menu:Hide()
    end
    local build, view = S.Build(), S.View()
    local c = M.Class(build.classID)
    if UI.lastClass ~= build.classID then
        if UI.lastClass then
            UI.CloseDialog(true)
        end
        UI.selectedSkills = {}
        UI.highlightColors = {}
        UI.hoverSkill = nil
        UI.lastClass = build.classID
        UI.skillScroll:ScrollTo(0)
        UI.historyScroll:ScrollTo(0)
    elseif UI.lastRace ~= build.raceID then
        for key, skill in pairs(UI.selectedSkills or {}) do
            if skill.kind == "racial" then
                UI.selectedSkills[key] = nil
                if UI.highlightColors then
                    UI.highlightColors[key] = nil
                end
            end
        end
        UI.hoverSkill = nil
    end
    UI.lastRace = build.raceID
    local d = S.Draft()
    local p = S.ActiveProfile()
    UI.buildName:SetText(
        S.SimpleView() and "Classic mode • class, talents and skill levels"
            or (
                FT.SafeText(p and p.name or build.name, 48)
                .. (S.Dirty() and "  • draft" or "  • saved")
            )
    )
    UI.saveButton:SetText(p and "Checkpoint" or "Save build")
    for id, b in pairs(UI.classButtons) do
        b:SetActive(id == build.classID)
    end
    UI.raceButton:SetText(FT.Data.races[build.raceID].name .. "  v")
    if not UI.levelInput:HasFocus() then
        UI.levelInput:SetText(build.level)
        UI.levelInput.clear:Hide()
    end
    UI.levelLabel:SetText(S.AutoLevel() and "Level" or "Target")
    UI.levelInput:SetAlpha(S.AutoLevel() and 0.7 or 1)
    UI.levelAuto:SetActive(S.AutoLevel())
    UI.levelAuto:SetEnabled(not S.preview)
    UI.levelMinus:SetEnabled(
        not S.AutoLevel() and not S.preview and build.level > math.max(1, M.RequiredLevel(build))
    )
    UI.levelPlus:SetEnabled(not S.AutoLevel() and not S.preview and build.level < 60)
    UI.undo:SetEnabled(#d.undo > 0)
    UI.redo:SetEnabled(#d.redo > 0)
    UI.reset:SetEnabled(#build.order > 0 and not S.preview)
    UI.heroIcon:SetTexture("Interface\\AddOns\\ForeverTalents\\Media\\Icons\\" .. c.icon .. ".tga")
    UI.heroClass:SetText(c.name)
    local race = FT.Data.races[build.raceID]
    UI.heroRace:SetText(S.SimpleView() and "Classic mode" or (race.name .. " • " .. race.faction))
    local _, trees = M.Counts(view)
    local summary = {}
    for _, tree in ipairs(c.trees) do
        summary[#summary + 1] = tree.name .. " " .. (trees[tree.id] or 0)
    end
    UI.heroTrees:SetText(table.concat(summary, "  /  "))
    UI.heroHint:SetText(
        S.SimpleView() and "Click a skill for its unlock and upgrade levels"
            or S.preview and "Level preview • Full build returns to your saved draft"
            or "Plan your path • Every point keeps its place in the leveling order"
    )
    UI.heroLevel:SetText(
        S.preview and "Preview level " .. S.ViewLevel() or "Build level " .. M.RequiredLevel(view)
    )
    UI.heroBudget:SetText(
        S.AutoLevel() and (#view.order .. " / 51 points • auto level")
            or (
                #view.order
                .. " / "
                .. M.Budget(build.level)
                .. " points • target level "
                .. build.level
            )
    )
    UI.RefreshTrees()
    UI.RefreshBrowser()
    UI.RefreshHistory()
    UI.RefreshRacials()
    local character = UI.dialogs and UI.dialogs.characterSheet
    if
        character
        and character:IsVisible()
        and character.classID == build.classID
        and character.refresh
    then
        character.refresh()
    end
    local sim = UI.dialogs and UI.dialogs.simulation
    if sim and sim:IsVisible() and sim.classID == build.classID and sim.update then
        sim.update()
    end
end

function UI.Toggle()
    if not UI.frame then
        UI.Create()
    end
    UI.frame:SetShown(not UI.frame:IsShown())
end

function UI.RefreshMinimap()
    if not Minimap then
        return
    end
    if not UI.minimap then
        local b = CreateFrame("Button", "ForeverTalentsMinimapButton", Minimap, "BackdropTemplate")
        b:SetSize(30, 30)
        b:SetFrameStrata("MEDIUM")
        W.Skin(b, { 0.08, 0.10, 0.13 }, W.colors.gold)
        W.Icon(b, "spell_nature_starfall", 3, -3, 24)
        b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        b:RegisterForDrag("LeftButton")
        b:SetScript("OnClick", function(_, button)
            if button == "RightButton" then
                if not UI.frame then
                    UI.Create()
                end
                UI.frame:Show()
                if S.SimpleView() then
                    UI.SettingsDialog()
                else
                    UI.HelpDialog()
                end
            else
                UI.Toggle()
            end
        end)
        b:SetScript("OnEnter", function(self)
            W.Tooltip(self, "Forever Talents", {
                S.SimpleView() and "Click to open • Right click for Settings"
                    or "Click to open • Right click for help",
                "Drag to move this button around the minimap.",
            })
        end)
        b:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        b:SetScript("OnDragStart", function(self)
            self:SetScript("OnUpdate", function()
                local x, y = GetCursorPosition()
                local cx, cy = Minimap:GetCenter()
                local scale = Minimap:GetEffectiveScale()
                S.db.settings.minimapAngle = math.deg(math.atan2(y / scale - cy, x / scale - cx))
                UI.PositionMinimap()
            end)
        end)
        b:SetScript("OnDragStop", function(self)
            self:SetScript("OnUpdate", nil)
        end)
        UI.minimap = b
    end
    UI.minimap:SetShown(S.db.settings.minimap)
    UI.PositionMinimap()
end

function UI.PositionMinimap()
    if not UI.minimap then
        return
    end
    local angle = math.rad(tonumber(S.db.settings.minimapAngle) or 220)
    UI.minimap:ClearAllPoints()
    UI.minimap:SetPoint(
        "CENTER",
        Minimap,
        "CENTER",
        math.cos(angle) * (Minimap:GetWidth() / 2 + 7),
        math.sin(angle) * (Minimap:GetHeight() / 2 + 7)
    )
end
