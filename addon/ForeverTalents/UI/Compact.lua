local _, FT = ...
local UI, W, S, M = FT.UI, FT.UI.W, FT.Store, FT.Model

-- A native window layout preference, independent of Simple view and portable builds.
function UI.CompactView()
    return S.db.settings.compactView == true
end

function UI.SetCompactView(enabled)
    S.db.settings.compactView = not not enabled
    FT.Changed(
        enabled and "Compact view enabled. Drag the title bar to move it."
            or "Full-size window restored."
    )
end

function UI.RememberWindowPosition(compact)
    if compact == nil then
        return
    end
    local point, _, relativePoint, x, y = UI.frame:GetPoint()
    if relativePoint and type(x) == "number" and type(y) == "number" then
        S.db.settings[compact and "compactPosition" or "position"] =
            { point = point, relativePoint = relativePoint, x = x, y = y }
    end
end

function UI.RestoreWindowPosition(compact)
    local p = S.db.settings[compact and "compactPosition" or "position"]
    local function finite(n)
        return type(n) == "number" and n == n and math.abs(n) < math.huge
    end
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
    UI.frame:ClearAllPoints()
    if
        type(p) == "table"
        and anchors[p.point]
        and anchors[p.relativePoint]
        and finite(p.x)
        and finite(p.y)
    then
        UI.frame:SetPoint(p.point, UIParent, p.relativePoint, p.x, p.y)
    elseif compact then
        UI.frame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -20, -80)
    else
        UI.frame:SetPoint("CENTER")
    end
end

local function move(widget, x, y, width, height)
    widget:ClearAllPoints()
    widget:SetPoint("TOPLEFT", x, y)
    if width then
        widget:SetWidth(width)
    end
    if height then
        widget:SetHeight(height)
    end
end

local function remember(widget, scroll)
    local saved = {
        widget = widget,
        parent = widget:GetParent(),
        anchor = { widget:GetPoint() },
        width = widget:GetWidth(),
        height = widget:GetHeight(),
        shown = widget:IsShown(),
        scroll = scroll,
    }
    UI.compactLayout[#UI.compactLayout + 1] = saved
end

function UI.RestoreCompactLayout()
    for _, saved in ipairs(UI.compactLayout or {}) do
        local widget = saved.widget
        widget:SetParent(saved.parent)
        widget:ClearAllPoints()
        widget:SetPoint(unpack(saved.anchor))
        if saved.scroll then
            widget:Resize(saved.width + 12, saved.height)
        else
            widget:SetSize(saved.width, saved.height)
        end
        widget:SetShown(saved.shown)
    end
    UI.compactLayout = nil
end

function UI.CompactMenu(anchor)
    local options = {}
    local function add(text, action, enabled)
        options[#options + 1] = { text = text, action = action, enabled = enabled }
    end
    add("Copy talents", function()
        UI.TalentTransferDialog(false)
    end)
    add("Paste talents", function()
        UI.TalentTransferDialog(true)
    end, not S.preview)
    if S.preview then
        add("Return to full build", function()
            S.Preview(nil)
        end)
    end
    if not S.SimpleView() then
        add("Race: " .. FT.Data.races[S.Build().raceID].name, function()
            local races = {}
            for _, rid in ipairs(M.Class(S.Build().classID).races) do
                local id = rid
                races[#races + 1] = {
                    text = FT.Data.races[id].name,
                    action = function()
                        local build = FT.Copy(S.Build())
                        build.raceID = id
                        W.Result(S.Edit(build))
                    end,
                }
            end
            W.Menu(anchor, races, 260)
        end)
        if S.SimulationEnabled() then
            add("Character & experimental simulator", UI.CharacterSheet)
        end
        add("Checkpoints", UI.GraphDialog)
        add("Share build", UI.ShareDialog)
        add("Import", UI.ImportDialog)
    end
    add("Settings", UI.SettingsDialog)
    add("Guide", UI.HelpDialog)
    W.Menu(anchor, options, 260)
end

function UI.CreateCompactControls(parent)
    UI.compactToggle = W.Checkbox(parent, 172, -34, function(checked)
        UI.SetCompactView(checked)
    end)
    UI.compactLabel = W.Button(parent, "Compact view", 198, -34, 110, function()
        UI.SetCompactView(not UI.CompactView())
    end, false, 20)
    UI.compactToggle.tip =
        "A small movable window with tree tabs, Skills and Builds. Works with Simple view too; your build is unchanged."
    UI.compactSummary = W.Text(parent, "", 14, -148, 392, 12, W.colors.teal)
    UI.compactTabs, UI.compactTreeTabs = {}, {}
    for i, entry in ipairs({
        { "trees", "Trees" },
        { "skills", "Skills" },
        { "builds", "Builds" },
        { "more", "More" },
    }) do
        local key = entry[1]
        UI.compactTabs[key] = W.Button(
            parent,
            entry[2],
            12 + (i - 1) * 100,
            -204,
            96,
            function(self)
                if key == "more" then
                    UI.CompactMenu(self)
                    return
                end
                UI.compactPage = key
                UI.RefreshCompactControls()
            end,
            false,
            28
        )
    end
    for i = 1, 3 do
        local index = i
        UI.compactTreeTabs[i] = W.Button(parent, "", 12 + (i - 1) * 132, -280, 128, function()
            UI.compactTree = index
            UI.compactTreeScroll:ScrollTo(0)
            UI.RefreshCompactControls()
        end, false, 28)
        UI.compactTreeTabs[i].fontString:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
    end
    UI.compactTreeScroll = W.Scroll(parent, 12, -316, 396, 322)
    UI.compactTreeScroll:SetContentHeight(482)
    UI.compactPage, UI.compactTree = "trees", 1
end

function UI.ApplyCompactLayout()
    if not UI.CompactView() then
        return
    end
    UI.compactLayout = {}
    for _, widget in ipairs({
        UI.brandTitle,
        UI.drag,
        UI.toolbar,
        UI.hero,
        UI.buildName,
        UI.saveButton,
        UI.shareButton,
        UI.importButton,
        UI.raceButton,
        UI.racesButton,
        UI.characterButton,
        UI.helpButton,
        UI.historyPanel,
        UI.racialPanel,
        UI.skillsPanel,
        UI.levelLabel,
        UI.levelMinus,
        UI.levelInput,
        UI.levelPlus,
        UI.levelAuto,
        UI.undo,
        UI.redo,
        UI.reset,
        UI.talentBar,
        UI.talentBarTitle,
        UI.talentSearch,
        UI.talentSearch.placeholder,
        UI.talentSearch.clear,
        UI.talentMatches,
        UI.copyTalents,
        UI.pasteTalents,
        UI.skillSearch,
        UI.skillSearch.placeholder,
        UI.skillSearch.clear,
        UI.skillFilter,
        UI.trainingInfo,
        UI.clearHighlight,
        UI.profileName,
        UI.profileHint,
        UI.previewBack,
        UI.previewBranch,
        UI.status,
        UI.settingsButton,
    }) do
        remember(widget)
    end
    remember(UI.skillScroll, true)
    remember(UI.historyScroll, true)
    for _, panel in ipairs(UI.treePanels) do
        for _, widget in ipairs({ panel, panel.body, panel.title, panel.points, panel.reset }) do
            remember(widget)
        end
    end
    for _, row in ipairs(UI.skillRows) do
        remember(row)
        remember(row.check)
    end
    UI.frame:SetSize(420, 680)
    move(UI.brandTitle, 14, -10, 340)
    UI.drag:SetWidth(368)
    move(UI.toolbar, 12, -62, 396, 80)
    for _, item in ipairs({
        { UI.levelLabel, 8, -54 },
        { UI.levelMinus, 52, -45 },
        { UI.levelInput, 80, -45 },
        { UI.levelPlus, 122, -45 },
        { UI.levelAuto, 150, -45 },
        { UI.undo, 206, -45 },
        { UI.redo, 270, -45 },
        { UI.reset, 334, -45, 54 },
    }) do
        move(item[1], item[2], item[3], item[4])
    end
    for _, widget in ipairs({
        UI.hero,
        UI.shareButton,
        UI.importButton,
        UI.raceButton,
        UI.racesButton,
        UI.characterButton,
        UI.helpButton,
        UI.racialPanel,
        UI.settingsButton,
    }) do
        widget:Hide()
    end
    move(UI.buildName, 14, -170, 286, 32)
    move(UI.saveButton, 310, -170, 98, 28)
    move(UI.talentBar, 12, -240, 396, 34)
    UI.talentBarTitle:Hide()
    UI.talentMatches:Hide()
    move(UI.talentSearch, 8, -3, 186)
    UI.talentSearch.placeholder:SetWidth(151)
    move(UI.talentSearch.clear, 163, -3)
    move(UI.copyTalents, 202, -3, 88)
    move(UI.pasteTalents, 296, -3, 88)
    move(UI.skillsPanel, 12, -240, 396, 398)
    move(UI.skillSearch, 10, -54, 376)
    UI.skillSearch.placeholder:SetWidth(341)
    move(UI.skillSearch.clear, 353, -3)
    UI.skillFilter:SetWidth(376)
    UI.trainingInfo:SetWidth(376)
    UI.skillScroll:Resize(380, 202)
    move(UI.clearHighlight, 10, -365, 376)
    for _, row in ipairs(UI.skillRows) do
        row:SetWidth(364)
        move(row.check, 337, -18)
    end
    move(UI.historyPanel, 12, -240, 396, 398)
    UI.profileName:SetWidth(372)
    UI.profileHint:SetWidth(372)
    UI.historyScroll:Resize(376, 224)
    move(UI.previewBack, 12, -365)
    move(UI.previewBranch, 122, -365)
    for _, panel in ipairs(UI.treePanels) do
        panel:SetParent(UI.compactTreeScroll.content)
        move(panel, 0, 0, 384, 482)
        move(panel.body, 70, -36)
        panel.title:SetWidth(274)
        move(panel.points, 324, -10)
        panel.reset:SetWidth(364)
    end
    move(UI.status, 14, -646, 392, 26)
end

function UI.RefreshCompactControls()
    if not UI.compactToggle then
        return
    end
    local compact, simple = UI.CompactView(), S.SimpleView()
    UI.compactToggle:SetChecked(compact)
    UI.compactToggle:Paint(false)
    UI.compactSummary:SetShown(compact)
    local page = UI.compactPage or "trees"
    if simple and page == "builds" then
        page = "trees"
        UI.compactPage = page
    end
    for key, button in pairs(UI.compactTabs) do
        button:SetShown(compact and (not simple or key ~= "builds"))
        button:SetActive(key == page)
    end
    for i, button in ipairs(UI.compactTreeTabs) do
        local tree = M.Class(S.Build().classID).trees[i]
        local _, points = M.Counts(S.View())
        button:SetText(tree.name .. " " .. (points[tree.id] or 0))
        button:SetActive(i == UI.compactTree)
        button:SetShown(compact and page == "trees")
        UI.treePanels[i]:SetShown(not compact or (page == "trees" and i == UI.compactTree))
    end
    UI.compactTreeScroll:SetShown(compact and page == "trees")
    UI.compactTreeScroll.slider:SetShown(
        compact and page == "trees" and UI.compactTreeScroll.maximum > 0
    )
    if compact then
        local build = S.View()
        UI.compactSummary:SetText(
            M.Class(build.classID).name
                .. " • Lv. "
                .. S.ViewLevel()
                .. " • "
                .. #build.order
                .. " points • "
                .. math.max(
                    0,
                    (S.AutoLevel() and not S.preview and 51 or M.Budget(S.ViewLevel()))
                        - #build.order
                )
                .. " left"
        )
        UI.skillsPanel:SetShown(page == "skills")
        UI.historyPanel:SetShown(not simple and page == "builds")
        UI.talentBar:SetShown(page == "trees")
        UI.skillScroll.slider:SetShown(page == "skills" and UI.skillScroll.maximum > 0)
        UI.historyScroll.slider:SetShown(page == "builds" and UI.historyScroll.maximum > 0)
    end
end
