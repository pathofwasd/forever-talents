local _, FT = ...
local UI, W, M = FT.UI, FT.UI.W, FT.Model
local filterLabels = {
    all = "All skills & racials",
    now = "Available at this level",
    talent = "Talent skills & effects",
    racial = "Racial traits",
}

function UI.SkillHighlightKey(skill)
    if skill.kind == "racial" then
        return "racial:" .. FT.Store.Build().raceID .. ":" .. skill.ranks[1].spellID
    end
    return "skill:" .. skill.name
end

function UI.IsSkillHighlighted(skill)
    return skill and UI.selectedSkills and UI.selectedSkills[UI.SkillHighlightKey(skill)] ~= nil
        or false
end

function UI.RefreshHighlightChecks()
    local count = 0
    for _ in pairs(UI.selectedSkills or {}) do
        count = count + 1
    end
    for _, rows in ipairs({ UI.skillRows or {}, UI.racialButtons or {} }) do
        for _, row in ipairs(rows) do
            if row.check then
                row.check:SetChecked(UI.IsSkillHighlighted(row.skill))
                row.check:Paint(false)
            end
        end
    end
    if UI.clearHighlight then
        UI.clearHighlight:SetText(
            count > 0 and "Clear highlights (" .. count .. ")" or "Clear highlights"
        )
    end
end

function UI.SetSkillHighlight(skill, checked)
    UI.selectedSkills = UI.selectedSkills or {}
    UI.selectedSkills[UI.SkillHighlightKey(skill)] = checked and skill or nil
    UI.HighlightSkill(nil)
    UI.RefreshHighlightChecks()
end

function UI.ClearSkillHighlights()
    UI.selectedSkills = {}
    UI.HighlightSkill(nil)
    UI.RefreshHighlightChecks()
end

function UI.AddHighlightCheckbox(row, x, y)
    row.check = W.Checkbox(row, x, y, function(checked)
        UI.SetSkillHighlight(row.skill, checked)
    end)
    row.check:SetScript("OnEnter", function(self)
        self:Paint(true)
        UI.HighlightSkill(nil)
        W.Tooltip(self, "Keep " .. row.skill.name .. " highlighted", {
            "Check any number of skills to combine their related talents in blue. Uncheck to remove this selection.",
            "Clear highlights unchecks every skill and racial trait, including hidden search results.",
            #row.skill.related == 0 and "No talent interactions are recorded for this skill."
                or "Click the skill name or icon for its ranks and details.",
        })
    end)
    return row.check
end

function UI.SkillTooltip(owner, skill)
    local view, level = FT.Store.View(), FT.Store.ViewLevel()
    local points = M.Counts(view)
    local rank = FT.Skills.CurrentRank(skill, level, points) or skill.ranks[1]
    if not GameTooltip then
        return
    end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetText(skill.name, 0.94, 0.76, 0.50, 1, true)
    if skill.kind == "racial" then
        GameTooltip:AddLine("Racial trait • " .. FT.Data.races[view.raceID].name, 0.6, 0.7, 0.75)
    elseif skill.unlock then
        GameTooltip:AddLine(
            "Talent: " .. skill.unlock.treeName .. " • row " .. (skill.unlock.row + 1),
            0.36,
            0.79,
            0.80
        )
    else
        GameTooltip:AddLine("First learned at level " .. skill.firstLevel, 0.6, 0.7, 0.75)
    end
    GameTooltip:AddLine(
        (rank.label ~= "" and rank.label .. " • " or "") .. "Level " .. rank.level,
        0.6,
        0.7,
        0.75
    )
    local description, source = FT.Description(rank)
    GameTooltip:AddLine("\n" .. description, 0.86, 0.90, 0.92, true)
    if source == "client" then
        GameTooltip:AddLine(
            "Description supplied by your client; missing from the snapshot.",
            0.56,
            0.63,
            0.68,
            true
        )
    end
    if skill.unlock then
        GameTooltip:AddLine(
            "\nRequires "
                .. skill.unlock.name
                .. " in "
                .. skill.unlock.treeName
                .. ". Earliest talent level "
                .. (10 + skill.unlock.gate)
                .. ".",
            0.94,
            0.76,
            0.50,
            true
        )
    end
    if #skill.related > 0 then
        GameTooltip:AddLine("\nRelated talents are highlighted in blue:", 0.35, 0.85, 1, true)
        local index = M.Index(view.classID)
        for i = 1, math.min(7, #skill.related) do
            local r = skill.related[i]
            GameTooltip:AddLine(
                index[r.id].name .. (r.kind == "school" and " (school modifier)" or ""),
                0.70,
                0.80,
                0.85,
                true
            )
        end
        if #skill.related > 7 then
            GameTooltip:AddLine(
                "+ " .. (#skill.related - 7) .. " more in the details.",
                0.6,
                0.7,
                0.75,
                true
            )
        end
    end
    GameTooltip:AddLine(
        "\nCheck the box to keep related talents highlighted.\nClick for every rank, unlock details and Simulator",
        0.56,
        0.63,
        0.68,
        true
    )
    GameTooltip:Show()
end

function UI.CreateBrowser(parent)
    local p = W.Panel(parent, 16, -188, 226, 528)
    W.Text(p, "Skills & ranks", 12, -13, 202, 15)
    UI.skillCount = W.Text(p, "", 12, -36, 202, 11, W.colors.muted)
    UI.skillSearch = W.Edit(p, "Search skills…", 10, -54, 206, function(text)
        UI.skillQuery = text
        if UI.skillScroll then
            UI.skillScroll:ScrollTo(0)
            UI.RefreshBrowser()
        end
    end)
    UI.skillFilter = W.Button(p, filterLabels.all .. "  v", 10, -88, 206, function(self)
        local options = {}
        for _, key in ipairs({ "all", "now", "talent", "racial" }) do
            options[#options + 1] = {
                text = filterLabels[key],
                action = function()
                    UI.skillFilterKey = key
                    UI.skillScroll:ScrollTo(0)
                    UI.RefreshBrowser()
                end,
            }
        end
        W.Menu(self, options, 246)
    end)
    UI.skillScroll = W.Scroll(p, 8, -126, 210, 356)
    UI.skillRows = {}
    for i = 1, 110 do
        local row = W.Button(UI.skillScroll.content, "", 0, -(i - 1) * 49, 194, function(self)
            UI.SkillDialog(self.skill)
        end, false, 46)
        row.icon = W.Icon(row, "class_druid", 7, -8, 28)
        row.title = W.Text(row, "", 42, -7, 119, 12)
        row.title:SetWordWrap(false)
        row.detail = W.Text(row, "", 42, -26, 119, 10, W.colors.muted)
        row.detail:SetWordWrap(false)
        UI.AddHighlightCheckbox(row, 167, -13)
        row:SetScript("OnEnter", function(self)
            self:Paint(true)
            UI.HighlightSkill(self.skill)
            UI.SkillTooltip(self, self.skill)
        end)
        row:SetScript("OnLeave", function(self)
            self:Paint(false)
            GameTooltip:Hide()
            UI.HighlightSkill(nil)
        end)
        UI.skillRows[i] = row
    end
    UI.skillEmpty = W.Text(
        UI.skillScroll.content,
        "No matching skills.\nTry a name, school, or effect.",
        10,
        -12,
        175,
        12,
        W.colors.muted
    )
    UI.clearHighlight =
        W.Button(p, "Clear highlights", 10, -490, 206, UI.ClearSkillHighlights, false, 26)
    UI.clearHighlight.tip =
        "Uncheck every skill and racial trait and remove their highlights, including selections hidden by a search or filter."
end

function UI.RefreshBrowser()
    if not UI.skillScroll then
        return
    end
    local build, level = FT.Store.View(), FT.Store.ViewLevel()
    local filter = UI.skillFilterKey or "all"
    UI.skillFilter:SetText(filterLabels[filter] .. "  v")
    local list = FT.Skills.List(build, level, UI.skillQuery, filter)
    UI.skillCount:SetText(#list .. " skills • showing level " .. level)
    for i, row in ipairs(UI.skillRows) do
        local entry = list[i]
        row:SetShown(entry ~= nil)
        if entry then
            local s = entry.skill
            row.skill = s
            row.title:SetText(s.name)
            row.icon:SetTexture(
                "Interface\\AddOns\\ForeverTalents\\Media\\Icons\\" .. s.icon .. ".tga"
            )
            row.icon:SetDesaturated(not entry.current)
            local detail = s.kind == "racial" and "Racial • level 1"
                or (
                    s.unlock
                        and s.unlock.treeName .. (entry.current and " • learned" or " • talent")
                    or "Lv. "
                        .. s.firstLevel
                        .. " • "
                        .. (
                            entry.current
                                and (entry.current.label ~= "" and entry.current.label or "available")
                            or "not yet"
                        )
                )
            row.detail:SetText(detail)
            row.detail:SetTextColor(unpack(entry.current and W.colors.teal or W.colors.muted))
        else
            row.skill = nil
        end
    end
    UI.skillEmpty:SetShown(#list == 0)
    UI.skillScroll:SetContentHeight(#list * 49)
    UI.RefreshHighlightChecks()
end

function UI.FocusTalentSkill(talent)
    local prepared = FT.Skills.Prepare(FT.Store.Build().classID)
    local skill = prepared.byName[talent.name]
    if not skill then
        local names = FT.Skills.TalentSkills(FT.Store.Build().classID, talent.id)
        skill = names[1] and prepared.byName[names[1]]
    end
    if skill then
        UI.SkillDialog(skill)
    else
        skill = {
            name = talent.name,
            icon = talent.icon,
            kind = "talent",
            unlock = talent,
            firstLevel = 10 + talent.gate,
            related = { { id = talent.id, kind = "unlock", reason = "Talent effect." } },
            ranks = {},
        }
        for i, r in ipairs(talent.ranks) do
            skill.ranks[#skill.ranks + 1] = {
                spellID = r.spellID,
                level = 9 + talent.gate + i,
                label = "Talent rank " .. i,
                text = r.text,
                live = true,
                talentRank = i,
            }
        end
        UI.SkillDialog(skill)
    end
end

function UI.RefreshRacials()
    if not UI.racialButtons then
        return
    end
    local build = FT.Store.Build()
    for i, b in ipairs(UI.racialButtons) do
        local r = FT.Data.racials[build.classID][build.raceID][i]
        b:SetShown(r ~= nil)
        if r then
            b.skill = {
                name = r.name,
                icon = r.icon,
                kind = "racial",
                firstLevel = 1,
                related = {},
                ranks = {
                    {
                        spellID = r.spellID,
                        level = 1,
                        label = "Racial",
                        live = true,
                        text = r.text,
                    },
                },
            }
            b.icon:SetTexture(
                "Interface\\AddOns\\ForeverTalents\\Media\\Icons\\" .. r.icon .. ".tga"
            )
            b.title:SetText(r.name)
        end
    end
    UI.racialTitle:SetText("Racial traits\n|cff8fa0ad" .. FT.Data.races[build.raceID].name .. "|r")
    UI.RefreshHighlightChecks()
end
