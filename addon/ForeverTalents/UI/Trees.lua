local _, FT = ...
local UI, M = FT.UI, FT.Model
local W = UI.W

function UI.TalentTooltip(button)
    local t, build = button.talent, FT.Store.View()
    if not t or not GameTooltip then
        return
    end
    local points = M.Counts(build)
    local rank = points[t.id] or 0
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    GameTooltip:SetText(t.name, 0.94, 0.76, 0.50, 1, true)
    GameTooltip:AddDoubleLine(
        t.treeName,
        "Rank " .. rank .. " / " .. t.max,
        0.6,
        0.7,
        0.75,
        0.6,
        0.7,
        0.75
    )
    if rank > 0 then
        GameTooltip:AddLine("\nCurrent rank", 0.35, 0.84, 0.67)
        GameTooltip:AddLine(t.ranks[rank].text, 0.86, 0.90, 0.92, true)
    end
    if rank < t.max then
        GameTooltip:AddLine(rank > 0 and "\nNext rank" or "\nRank 1", 0.94, 0.76, 0.50)
        GameTooltip:AddLine(t.ranks[rank + 1].text, 0.86, 0.90, 0.92, true)
    end
    local ok, why = M.CanAdd(FT.Store.PlanningView(), t.id)
    if not ok and rank < t.max then
        GameTooltip:AddLine("\n" .. why, 1, 0.43, 0.37, true)
    end
    if #t.requires > 0 then
        for _, r in ipairs(t.requires) do
            GameTooltip:AddLine(
                "Requires " .. r.points .. " points in " .. r.name .. ".",
                0.66,
                0.74,
                0.79,
                true
            )
        end
    end
    local related = FT.Skills.TalentSkills(build.classID, t.id)
    if #related > 0 then
        local names = {}
        for i = 1, math.min(6, #related) do
            names[#names + 1] = related[i]
        end
        GameTooltip:AddLine(
            "\nInteracts with: " .. table.concat(names, ", ") .. (#related > 6 and " …" or ""),
            0.36,
            0.79,
            0.80,
            true
        )
    end
    if IsShiftKeyDown and IsShiftKeyDown() and t.max > 1 then
        for i, r in ipairs(t.ranks) do
            GameTooltip:AddLine("\nRank " .. i .. ": " .. r.text, 0.72, 0.78, 0.82, true)
        end
    end
    if FT.Store.preview then
        GameTooltip:AddLine(
            "\nLevel preview: return to full build to edit.",
            0.94,
            0.76,
            0.50,
            true
        )
    else
        GameTooltip:AddLine(
            "\nLeft click: add • Right click: remove\nShift: fill / clear • Ctrl: inspect skill\nHold Shift while hovering for all ranks.",
            0.56,
            0.63,
            0.68,
            true
        )
    end
    GameTooltip:Show()
end

function UI.CreateTrees(parent)
    UI.treePanels, UI.talentButtons = {}, {}
    for i = 1, 3 do
        local panel = W.Panel(parent, 252 + (i - 1) * 252, -234, 246, 482)
        panel.headerIcon = W.Icon(panel, "class_druid", 10, -7, 22)
        panel.title = W.Text(panel, "", 40, -9, 145, 13)
        panel.points = W.Text(panel, "", 185, -10, 50, 12, W.colors.muted)
        panel.points:SetJustifyH("RIGHT")
        local body = CreateFrame("Frame", nil, panel)
        body:SetPoint("TOPLEFT", 1, -36)
        body:SetSize(244, 410)
        local fallback = body:CreateTexture(nil, "BACKGROUND")
        fallback:SetAllPoints()
        fallback:SetTexture("Interface\\AddOns\\ForeverTalents\\Media\\Tree" .. i .. ".tga")
        panel.art = {}
        -- Classic backgrounds consist of four client texture tiles. Keep the
        -- authentic art and actual grid, rather than flattening into a list.
        local left, top = 244 * 256 / 300, 410 * 256 / 331
        local tiles = {
            { "TopLeft", 0, 0, left, top },
            { "TopRight", left, 0, 244 - left, top },
            { "BottomLeft", 0, top, left, 410 - top },
            { "BottomRight", left, top, 244 - left, 410 - top },
        }
        for j, tile in ipairs(tiles) do
            local tex = body:CreateTexture(nil, "BACKGROUND", nil, 1)
            tex:SetPoint("TOPLEFT", tile[2], -tile[3])
            tex:SetSize(tile[4], tile[5])
            tex:SetTexCoord(0, (j == 2 or j == 4) and 0.6875 or 1, 0, j >= 3 and 0.5859375 or 1)
            panel.art[j] = { texture = tex, suffix = tile[1] }
        end
        local shade = body:CreateTexture(nil, "BACKGROUND", nil, 2)
        shade:SetAllPoints()
        shade:SetColorTexture(0.025, 0.032, 0.043, 0.36)
        panel.body, panel.buttons, panel.links, panel.linePool = body, {}, {}, {}
        for n = 1, 24 do
            local b = CreateFrame("Button", nil, body, "BackdropTemplate")
            b:SetSize(40, 40)
            W.Skin(b, { 0.02, 0.025, 0.03 })
            b.icon = W.Icon(b, "class_druid", 2, -2, 36)
            local badge = CreateFrame("Frame", nil, b, "BackdropTemplate")
            badge:SetPoint("BOTTOMRIGHT", 5, -5)
            badge:SetSize(32, 16)
            W.Skin(badge, { 0.018, 0.022, 0.028 }, { 0.20, 0.24, 0.28 })
            b.rank = W.Text(badge, "", 2, -2, 28, 11)
            b.rank:SetJustifyH("CENTER")
            b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            b:SetScript("OnEnter", function(self)
                UI.TalentTooltip(self)
            end)
            b:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)
            b:SetScript("OnClick", function(self, mouse)
                if IsControlKeyDown and IsControlKeyDown() then
                    UI.FocusTalentSkill(self.talent)
                    return
                end
                if FT.Store.preview then
                    UI.Status("Return to the full build before editing talents.", true)
                    return
                end
                local action = mouse == "RightButton" and M.Remove or M.Add
                W.Result(
                    FT.Store.Apply(action, self.talent.id, IsShiftKeyDown and IsShiftKeyDown())
                )
                UI.TalentTooltip(self)
            end)
            panel.buttons[n] = b
        end
        panel.reset = W.Button(panel, "Reset tree", 10, -449, 226, function()
            W.Result(FT.Store.Apply(M.Reset, panel.treeID))
            UI.Status("Tree reset. Undo restores it.")
        end)
        panel.reset.tip =
            "Clear this tree and preserve the other two trees. Undo restores all points and their order."
        UI.treePanels[i] = panel
    end
end

local function position(t)
    return 16 + t.col * 57, 24 + t.row * 55
end

function UI.RefreshTrees()
    if not UI.treePanels then
        return
    end
    local build, view = FT.Store.Build(), FT.Store.View()
    local planning = FT.Store.PlanningView()
    local c = M.Class(build.classID)
    M.Index(build.classID)
    local points, treePoints = M.Counts(view)
    UI.talentButtons = {}
    local matches = 0
    for i, tree in ipairs(c.trees) do
        local p = UI.treePanels[i]
        local changed = p.treeID ~= tree.id
        p.treeID = tree.id
        p.title:SetText(tree.name)
        p.points:SetText((treePoints[tree.id] or 0) .. " / 51")
        p.headerIcon:SetTexture(
            "Interface\\AddOns\\ForeverTalents\\Media\\Icons\\" .. tree.icon .. ".tga"
        )
        if changed then
            for _, a in ipairs(p.art) do
                a.texture:SetTexture("Interface\\TalentFrame\\" .. tree.art .. "-" .. a.suffix)
            end
            for _, link in ipairs(p.links) do
                for _, line in ipairs(link.lines) do
                    line:Hide()
                end
            end
            p.links = {}
            local used = 0
            local function line(x1, y1, x2, y2)
                used = used + 1
                return W.PooledLine(p.linePool, used, p.body, x1, y1, x2, y2)
            end
            for _, t in ipairs(tree.talents) do
                local x, y = position(t)
                for _, req in ipairs(t.requires) do
                    local prerequisite = c.index[req.id]
                    local sx, sy = position(prerequisite)
                    local lines = {}
                    sx, sy, x, y = sx + 20, sy + 45, x + 20, y - 5
                    if sx ~= x then
                        local bend = sy + (y - sy) / 2
                        lines[#lines + 1] = line(sx, sy, sx, bend)
                        lines[#lines + 1] = line(sx, bend, x, bend)
                        lines[#lines + 1] = line(x, bend, x, y)
                    else
                        lines[#lines + 1] = line(sx, sy, x, y)
                    end
                    lines[#lines + 1] = line(x - 4, y - 5, x, y)
                    lines[#lines + 1] = line(x + 4, y - 5, x, y)
                    p.links[#p.links + 1] = { requires = req, lines = lines }
                    x, y = position(t)
                end
            end
        end
        for n, b in ipairs(p.buttons) do
            local t = tree.talents[n]
            b:SetShown(t ~= nil)
            if t then
                local x, y = position(t)
                b:ClearAllPoints()
                b:SetPoint("TOPLEFT", x, -y)
                b.talent = t
                UI.talentButtons[t.id] = b
                b.icon:SetTexture(
                    "Interface\\AddOns\\ForeverTalents\\Media\\Icons\\" .. t.icon .. ".tga"
                )
                local rank = points[t.id] or 0
                local available = M.CanAdd(planning, t.id)
                b.locked = rank == 0 and not available
                b.icon:SetDesaturated(rank == 0 and not available)
                b.icon:SetVertexColor(
                    rank == 0 and not available and 0.48 or 1,
                    rank == 0 and not available and 0.52 or 1,
                    rank == 0 and not available and 0.58 or 1
                )
                b.rank:SetText(rank .. "/" .. t.max)
                local color = rank == t.max and W.colors.gold
                    or ((available or rank > 0) and W.colors.teal or W.colors.muted)
                b.rank:SetTextColor(unpack(color))
                b:SetBackdropBorderColor(unpack(color))
                local match = FT.Skills.SearchTalent(t, UI.talentQuery or "")
                if match then
                    matches = matches + 1
                end
                b:SetAlpha(match and 1 or 0.22)
                b.match, b.baseColor = match, color
                if (UI.talentQuery or "") ~= "" and match then
                    b:SetBackdropBorderColor(1, 0.70, 0.32, 1)
                end
            end
        end
        for _, link in ipairs(p.links) do
            local met = (points[link.requires.id] or 0) >= link.requires.points
            for _, line in ipairs(link.lines) do
                line:SetColorTexture(
                    unpack(met and { 0.36, 0.65, 0.57, 0.9 } or { 0.39, 0.43, 0.47, 0.75 })
                )
            end
        end
        p.reset:SetEnabled(not FT.Store.preview and (treePoints[tree.id] or 0) > 0)
    end
    if UI.talentMatches then
        UI.talentMatches:SetText(
            (UI.talentQuery or "") ~= "" and matches .. " found"
                or (
                    FT.Store.AutoLevel()
                        and not FT.Store.preview
                        and (51 - #view.order) .. " more to level 60"
                    or (M.Budget(view.level) - #view.order) .. " points left"
                )
        )
    end
    UI.UpdateSkillHighlights()
end

function UI.PaintHighlights()
    for id, b in pairs(UI.talentButtons or {}) do
        if UI.highlight and UI.highlight[id] then
            b:SetAlpha(1)
            b:SetBackdropBorderColor(0.35, 0.85, 1, 1)
            b.icon:SetVertexColor(1, 1, 1)
        else
            b:SetAlpha(b.match and 1 or 0.22)
            if b.baseColor then
                b:SetBackdropBorderColor(unpack(b.baseColor))
            end
            b.icon:SetVertexColor(
                b.locked and 0.48 or 1,
                b.locked and 0.52 or 1,
                b.locked and 0.58 or 1
            )
            if (UI.talentQuery or "") ~= "" and b.match then
                b:SetBackdropBorderColor(1, 0.70, 0.32, 1)
            end
        end
    end
end

function UI.UpdateSkillHighlights()
    UI.highlight = {}
    for _, skill in pairs(UI.selectedSkills or {}) do
        for _, link in ipairs(skill.related or {}) do
            UI.highlight[link.id] = link
        end
    end
    for _, link in ipairs(UI.hoverSkill and UI.hoverSkill.related or {}) do
        UI.highlight[link.id] = link
    end
    UI.PaintHighlights()
end

function UI.HighlightSkill(skill)
    UI.hoverSkill = skill
    UI.UpdateSkillHighlights()
end
