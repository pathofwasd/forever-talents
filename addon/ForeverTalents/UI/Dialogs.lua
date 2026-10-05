local _, FT = ...
local UI, W, M, S = FT.UI, FT.UI.W, FT.Model, FT.Store

function UI.CloseDialog()
    if UI.dialogOverlay then
        UI.dialogOverlay:Hide()
    end
    if GameTooltip then
        GameTooltip:Hide()
    end
    UI.HighlightSkill(nil)
end

function UI.Dialog(key, title, width, height)
    if UI.menu then
        UI.menu:Hide()
    end
    if not UI.dialogOverlay then
        local overlay = CreateFrame("Frame", "ForeverTalentsModal", UI.frame)
        overlay:SetAllPoints()
        overlay:SetFrameStrata("DIALOG")
        overlay:SetFrameLevel(80)
        overlay:EnableMouse(true)
        local shade = overlay:CreateTexture(nil, "BACKGROUND")
        shade:SetAllPoints()
        shade:SetColorTexture(0.01, 0.02, 0.03, 0.76)
        overlay:SetScript("OnHide", function()
            if GameTooltip then
                GameTooltip:Hide()
            end
            UI.HighlightSkill(nil)
        end)
        UI.dialogOverlay = overlay
        table.insert(UISpecialFrames, "ForeverTalentsModal")
        UI.dialogs = {}
    end
    for _, f in pairs(UI.dialogs) do
        f:Hide()
    end
    local f = UI.dialogs[key]
    local first = not f
    if not f then
        f = W.Panel(UI.dialogOverlay, 0, 0, width, height, { 0.066, 0.083, 0.103 })
        f:ClearAllPoints()
        f:SetPoint("CENTER")
        f:SetFrameLevel(85)
        f.heading = W.Text(f, title, 22, -20, width - 80, 21)
        W.Button(f, "x", width - 46, -14, 30, UI.CloseDialog, false, 28)
        UI.dialogs[key] = f
    end
    f.heading:SetText(title)
    f:Show()
    UI.dialogOverlay:Show()
    return f, first
end

function UI.SaveDialog(checkpoint)
    local profile = S.ActiveProfile()
    local f, first =
        UI.Dialog("save", profile and "Save a checkpoint" or "Save your build", 520, 248)
    if first then
        f.detail = W.Text(f, "", 22, -64, 476, 13, W.colors.muted)
        f.input = W.Edit(f, "A short, memorable title", 22, -116, 476, nil, 48)
        f.error = W.Text(f, "", 22, -153, 476, 12, { 1, 0.48, 0.40 })
        f.save = W.Button(f, "Save", 22, -197, 226, nil, true, 30)
        f.new = W.Button(f, "Save as new build", 258, -197, 240, nil, false, 30)
        f.input:SetScript("OnEnterPressed", function()
            f.save:Click()
        end)
    end
    f.detail:SetText(
        profile
                and "This creates a new node below your selected checkpoint.\nLoad any older node to try a different branch."
            or "Your draft already autosaves. A named profile keeps this build\nand lets you collect alternate paths as checkpoints."
    )
    f.error:SetText("")
    f.input:SetText(
        profile and ("Level " .. M.RequiredLevel(S.Build()) .. " checkpoint")
            or (
                S.Build().name == "Untitled build"
                    and M.Class(S.Build().classID).name .. " build"
                or S.Build().name
            )
    )
    f.save:SetText(profile and "Save checkpoint" or "Save build")
    f.save:SetScript("OnClick", function()
        local result, why
        if profile then
            result, why = S.Checkpoint(f.input:GetText())
        else
            result, why = S.CreateProfile(f.input:GetText())
        end
        if result then
            UI.CloseDialog()
            UI.historyTab = "graph"
            UI.RefreshHistory()
        else
            f.error:SetText(why)
        end
    end)
    f.new:SetShown(profile ~= nil)
    f.new:SetScript("OnClick", function()
        local p, why = S.CreateProfile(f.input:GetText())
        if p then
            UI.CloseDialog()
        else
            f.error:SetText(why)
        end
    end)
    f.input:SetFocus()
    f.input:HighlightText()
end

function UI.ShareDialog(build, title)
    local profile = not build and S.ActiveProfile()
    build = FT.Copy(build or S.ExportView())
    if title or profile then
        build.name = FT.SafeText(title or profile.name, 48)
    end
    local code, why = FT.Codec.Encode(build)
    if not code then
        UI.Status(why, true)
        return
    end
    local f, first = UI.Dialog("share", "Share a build", 720, 354)
    if first then
        f.summary = W.Text(f, "", 22, -61, 676, 14, W.colors.gold)
        W.Text(
            f,
            "Copy this entire string with Ctrl+C. It includes the race, target level,\nall talent ranks, and the exact leveling order.",
            22,
            -94,
            676,
            13,
            W.colors.muted
        )
        f.code = W.Edit(f, "", 22, -146, 676, nil, 512)
        f.code:SetHeight(48)
        f.code:SetMultiLine(true)
        f.code:SetTextInsets(10, 10, 8, 8)
        W.Text(f, "In-game sharing", 22, -214, 220, 14)
        f.recipient = W.Edit(f, "Player or Player-Realm", 22, -240, 320, nil, 64)
        f.send = W.Button(f, "Send addon whisper", 354, -240, 192, nil, true)
        f.text = W.Button(f, "Text whisper", 558, -240, 140, nil)
        f.message = W.Text(f, "", 22, -286, 676, 12, W.colors.muted)
    end
    f.summary:SetText(
        FT.SafeText(build.name, 48)
            .. " • "
            .. M.Class(build.classID).name
            .. " • "
            .. #build.order
            .. " points"
    )
    f.code:SetText(code)
    f.code.clear:Hide()
    f.code:SetFocus()
    f.code:HighlightText()
    f.message:SetText(
        "Both players need Forever Talents for clickable addon whispers. Text strings work anywhere."
    )
    f.send:SetScript("OnClick", function()
        local ok, msg = FT.Comms.Send(build, f.recipient:GetText())
        f.message:SetText(msg)
        f.message:SetTextColor(unpack(ok and W.colors.teal or { 1, 0.48, 0.40 }))
    end)
    f.text:SetScript("OnClick", function()
        local name = FT.SafeText(f.recipient:GetText(), 64)
        if name == "" or name:find("[%s:%[%]]") then
            f.message:SetText("Enter the player name first.")
            return
        end
        if ChatFrame_OpenChat then
            UI.CloseDialog()
            ChatFrame_OpenChat("/w " .. name .. " " .. code)
        else
            f.message:SetText("Use Ctrl+C to copy the string, then paste it into your whisper.")
        end
    end)
end

function UI.ImportDialog(code)
    if code and code:match("^%s*F[CSL]1:") then
        return UI.CharacterDialog(code)
    end
    if not UI.frame then
        UI.Create()
    end
    UI.frame:Show()
    local f, first = UI.Dialog("import", "Preview a shared build", 680, 374)
    if first then
        W.Text(
            f,
            "Paste a complete Forever Talents string below.\nYour current draft stays here until you choose Load.",
            22,
            -64,
            636,
            13,
            W.colors.muted
        )
        f.input = W.Edit(f, "FT1 / FC1 / FS2 / FL1:…", 22, -118, 636, nil, 3 * 1024 * 1024)
        f.input:SetHeight(48)
        f.input:SetMultiLine(true)
        f.input:SetTextInsets(10, 25, 8, 8)
        f.summary = W.Text(f, "", 22, -190, 636, 15, W.colors.gold)
        f.detail = W.Text(f, "", 22, -222, 636, 13, W.colors.muted)
        f.error = W.Text(f, "", 22, -270, 636, 12, { 1, 0.48, 0.40 })
        f.load = W.Button(f, "Load into draft", 22, -321, 300, nil, true, 30)
        f.save = W.Button(f, "Load & save a copy", 336, -321, 322, nil, false, 30)
        local function update()
            if f.input:GetText():match("^%s*F[CSL]1:") then
                UI.CharacterDialog(f.input:GetText())
                return
            end
            local b, why = FT.Codec.Decode(f.input:GetText())
            f.build = b
            f.load:SetEnabled(b ~= nil)
            f.save:SetEnabled(b ~= nil)
            f.summary:SetText(b and FT.SafeText(b.name, 48) or "Waiting for a build string")
            if b then
                local _, trees = M.Counts(b)
                local class = M.Class(b.classID)
                f.detail:SetText(
                    class.name
                        .. " • "
                        .. FT.Data.races[b.raceID].name
                        .. " • target level "
                        .. b.level
                        .. "\n"
                        .. (trees[class.trees[1].id] or 0)
                        .. " / "
                        .. (trees[class.trees[2].id] or 0)
                        .. " / "
                        .. (trees[class.trees[3].id] or 0)
                        .. " • "
                        .. #b.order
                        .. " ordered talent points"
                )
            else
                f.detail:SetText("")
            end
            f.error:SetText(f.input:GetText() ~= "" and (why or "") or "")
        end
        f.input:HookScript("OnTextChanged", update)
        f.load:SetScript("OnClick", function()
            if f.build then
                W.Result(S.Import(f.build))
                UI.CloseDialog()
            end
        end)
        f.save:SetScript("OnClick", function()
            if f.build then
                W.Result(S.Import(f.build))
                UI.CloseDialog()
                UI.SaveDialog(false)
            end
        end)
    end
    f.input:SetText(code or "")
    f.input:SetFocus()
    if code then
        f.input:HighlightText()
    end
end

function UI.ProfileMenu(anchor, p)
    local last = p.nodes[p.order[#p.order]]
    W.Menu(anchor, {
        {
            text = "Share this profile",
            action = function()
                UI.ShareDialog(last.build, p.name)
            end,
        },
        {
            text = "View checkpoints",
            action = function()
                S.LoadNode(p.id, last.id)
                UI.GraphDialog()
            end,
        },
        {
            text = "Rename profile",
            action = function()
                local f, first = UI.Dialog("rename", "Rename profile", 480, 190)
                if first then
                    f.input = W.Edit(f, "Profile name", 22, -70, 436, nil, 48)
                    f.error = W.Text(f, "", 22, -110, 436, 12, { 1, 0.48, 0.40 })
                    f.save = W.Button(f, "Rename", 22, -141, 436, nil, true)
                end
                f.error:SetText("")
                f.input:SetText(p.name)
                f.input:SetFocus()
                f.input:HighlightText()
                f.save:SetScript("OnClick", function()
                    local ok, why = S.RenameProfile(p.id, f.input:GetText())
                    if ok then
                        UI.CloseDialog()
                    else
                        f.error:SetText(why)
                    end
                end)
            end,
        },
        {
            text = "Delete profile…",
            action = function()
                local f, first = UI.Dialog("delete", "Delete this profile?", 520, 238)
                if first then
                    f.text = W.Text(f, "", 22, -72, 476, 13)
                    f.delete = W.Button(f, "Delete profile", 22, -188, 226, nil, true)
                    W.Button(f, "Keep profile", 258, -188, 240, UI.CloseDialog)
                end
                f.text:SetText(
                    "Delete "
                        .. FT.SafeText(p.name, 48)
                        .. " and its "
                        .. #p.order
                        .. " saved checkpoints?\n\nThe working draft is kept. This profile deletion cannot be undone."
                )
                f.delete:SetScript("OnClick", function()
                    W.Result(S.DeleteProfile(p.id))
                    UI.CloseDialog()
                end)
            end,
        },
    }, 234)
end

function UI.SkillLevelsDialog(skill)
    local f, first = UI.Dialog("skillLevels", "Skill levels", 560, 484)
    if first then
        f.icon = W.Icon(f, "class_druid", 22, -62, 36)
        f.title = W.Text(f, "", 72, -62, 466, 18, W.colors.gold)
        f.source = W.Text(f, "", 22, -116, 516, 12, W.colors.muted)
        f.scroll = W.Scroll(f, 22, -152, 516, 272)
        f.levelRows = {}
        f.empty = W.Text(
            f.scroll.content,
            "No trainable rank levels recorded.",
            8,
            -8,
            480,
            13,
            W.colors.muted
        )
        W.Text(
            f,
            "Talent skills also require their talent to be learned.\nLevels are the earliest recorded unlock or rank upgrade.",
            22,
            -434,
            516,
            12,
            W.colors.muted
        )
    end
    f.title:SetText(skill.name)
    f.icon:SetTexture("Interface\\AddOns\\ForeverTalents\\Media\\Icons\\" .. skill.icon .. ".tga")
    local levels, unlockLevel = FT.Skills.Levels(skill)
    f.source:SetText(
        skill.unlock
                and ("Talent: " .. skill.unlock.name .. " • " .. skill.unlock.treeName .. "\nEarliest unlock: level " .. unlockLevel)
            or ("First learned at level " .. (levels[1] and levels[1].level or skill.firstLevel))
    )
    for _, row in ipairs(f.levelRows) do
        row:Hide()
    end
    for i, rank in ipairs(levels) do
        local row = f.levelRows[i]
        if not row then
            row = W.Text(f.scroll.content, "", 8, -(i - 1) * 34 - 6, 480, 13)
            f.levelRows[i] = row
        end
        row:SetText(
            rank.label
                .. "  •  Level "
                .. rank.level
                .. (rank.talentRank and "  •  talent rank " .. rank.talentRank or "")
                .. (rank.toLevel and "–" .. rank.toLevel or "")
        )
        row:Show()
    end
    f.empty:SetShown(#levels == 0)
    f.scroll:SetContentHeight(math.max(34, #levels * 34))
    f.scroll:ScrollTo(0)
end

function UI.SkillDialog(skill)
    if S.SimpleView() then
        UI.SkillLevelsDialog(skill)
        return
    end
    UI.HighlightSkill(skill)
    local f, first = UI.Dialog("skill", "Skill details", 900, 646)
    if first then
        f.icon = W.Icon(f, "class_druid", 22, -60, 40)
        f.title = W.Text(f, "", 76, -61, 554, 19, W.colors.gold)
        f.source = W.Text(f, "", 76, -89, 570, 12, W.colors.muted)
        f.sim = W.Button(f, "Simulator", 690, -64, 188, nil, true, 32)
        local desc = W.Panel(f, 22, -122, 512, 124, { 0.05, 0.065, 0.082 })
        f.descScroll = W.Scroll(desc, 12, -12, 488, 100)
        f.description = W.Text(f.descScroll.content, "", 0, 0, 466, 13)
        W.Text(f, "Every rank & unlock level", 22, -266, 512, 14)
        f.rankScroll = W.Scroll(f, 22, -294, 512, 296)
        f.rankRows = {}
        local related = W.Panel(f, 554, -122, 324, 468, { 0.05, 0.065, 0.082 })
        W.Text(related, "Talent interactions", 12, -14, 300, 15)
        W.Text(
            related,
            "Blue = named, school, or general effects.\nClick a talent to locate it in the tree.",
            12,
            -41,
            300,
            12,
            W.colors.muted
        )
        f.relatedScroll = W.Scroll(related, 10, -88, 304, 365)
        f.relatedRows = {}
        W.Text(
            f,
            "Alternate source records stay visible; hover a rank for its full description.",
            22,
            -614,
            856,
            11,
            W.colors.muted
        )
    end
    f.title:SetText(skill.name)
    f.icon:SetTexture("Interface\\AddOns\\ForeverTalents\\Media\\Icons\\" .. skill.icon .. ".tga")
    local view, level = S.View(), S.ViewLevel()
    local points = M.Counts(view)
    local rank = FT.Skills.CurrentRank(skill, level, points) or skill.ranks[1]
    f.selectedRank = rank
    local function describe(r)
        f.selectedRank = r
        local description, source = FT.Description(r)
        f.description:SetText(description)
        f.descScroll:SetContentHeight(f.description:GetStringHeight() + 4)
        f.descScroll:ScrollTo(0)
        f.source:SetText(
            skill.unlock
                    and ("Unlocked in " .. skill.unlock.treeName .. " • row " .. (skill.unlock.row + 1) .. " • earliest level " .. (10 + skill.unlock.gate))
                or skill.kind == "racial" and (FT.Data.races[view.raceID].name .. " racial trait • level 1")
                or ((r.label ~= "" and r.label .. " • " or "") .. "Learned at level " .. r.level)
        )
        if source == "client" then
            f.source:SetText(f.source:GetText() .. " • client description")
        end
        for _, row in ipairs(f.rankRows) do
            row:SetActive(row.rank == r)
        end
    end
    for _, row in ipairs(f.rankRows) do
        row:Hide()
    end
    for i, r in ipairs(skill.ranks) do
        local row = f.rankRows[i]
        if not row then
            row = W.Button(f.rankScroll.content, "", 0, -(i - 1) * 42, 496, nil, false, 38)
            row.label = W.Text(row, "", 12, -8, 468, 12)
            f.rankRows[i] = row
        end
        row.rank = r
        row:Show()
        row.label:SetText(
            "Level "
                .. r.level
                .. "  •  "
                .. (r.label ~= "" and r.label or "Unranked")
                .. (not r.live and "  |cff8f9aa6Alternate source record|r" or "")
        )
        row:SetScript("OnClick", function()
            describe(r)
        end)
        row:SetScript("OnEnter", function(self)
            self:Paint(true)
            W.Tooltip(self, skill.name .. " • " .. (r.label or ""), {
                FT.Description(r),
                not r.live
                        and "The source never marks this spell ID as the highest trainable rank. It is kept for reference."
                    or ("Spell ID " .. r.spellID .. " • learned at level " .. r.level),
            })
        end)
        row:SetScript("OnLeave", function(self)
            self:Paint(false)
            GameTooltip:Hide()
        end)
    end
    describe(rank)
    f.rankScroll:ScrollTo(0)
    f.rankScroll:SetContentHeight(#skill.ranks * 42)
    for _, row in ipairs(f.relatedRows) do
        row:Hide()
    end
    local index = M.Index(view.classID)
    for i, link in ipairs(skill.related) do
        local talent = index[link.id]
        local row = f.relatedRows[i]
        if not row then
            row = W.Button(f.relatedScroll.content, "", 0, -(i - 1) * 57, 288, nil, false, 52)
            row.title = W.Text(row, "", 10, -8, 268, 12)
            row.detail = W.Text(row, "", 10, -29, 268, 10, W.colors.muted)
            f.relatedRows[i] = row
        end
        row:Show()
        row.title:SetText(talent.name)
        row.detail:SetText(
            talent.treeName
                .. " • "
                .. (
                    link.kind == "school" and "School modifier"
                    or link.kind == "general" and "General modifier"
                    or link.kind == "unlock" and "Unlocks this skill"
                    or "Named interaction"
                )
        )
        row:SetScript("OnClick", function()
            UI.CloseDialog()
            UI.Status(
                talent.name .. " is highlighted in blue. Hover it for the current and next rank."
            )
            UI.HighlightSkill({ related = { link } })
        end)
        row:SetScript("OnEnter", function(self)
            self:Paint(true)
            W.Tooltip(
                self,
                talent.name,
                { link.reason, talent.ranks[math.max(1, points[talent.id] or 0)].text }
            )
        end)
        row:SetScript("OnLeave", function(self)
            self:Paint(false)
            GameTooltip:Hide()
        end)
    end
    if not f.noRelated then
        f.noRelated = W.Text(
            f.relatedScroll.content,
            "No specific talent interaction is recorded for this skill.",
            10,
            -10,
            265,
            13,
            W.colors.muted
        )
    end
    f.noRelated:SetShown(#skill.related == 0)
    f.relatedScroll:ScrollTo(0)
    f.relatedScroll:SetContentHeight(#skill.related * 57)
    f.sim:SetScript("OnClick", function()
        UI.SimulationDialog(skill, f.selectedRank)
    end)
end

function UI.DeleteNodeDialog(profileID, nodeID, fromGraph)
    local p = S.db.profiles[profileID]
    local node = p and p.nodes[nodeID]
    local removed, count = S.NodeSubtree(profileID, nodeID)
    if not removed then
        UI.Status(count, true)
        return
    end
    local f, first =
        UI.Dialog("deleteNode", "Delete checkpoint" .. (count > 1 and " branch?" or "?"), 560, 292)
    if first then
        f.text = W.Text(f, "", 22, -68, 516, 13)
        f.delete = W.Button(f, "Delete", 22, -240, 248, nil, true, 30)
        f.keep = W.Button(f, "Cancel", 290, -240, 248, nil, false, 30)
    end
    local root = not node.parent
    f.text:SetText(
        'Delete "'
            .. FT.SafeText(node.title, 48)
            .. '" and '
            .. (count - 1)
            .. " child checkpoint"
            .. (count == 2 and "" or "s")
            .. "?\n\n"
            .. (root and "This is the starting node, so the entire profile will be removed.\n" or "Other branches stay saved.\n")
            .. "Your current working talents are kept.\n\nThis deletion cannot be undone."
    )
    f.delete:SetText(
        root and "Delete profile (" .. count .. ")"
            or "Delete checkpoint" .. (count > 1 and "s (" .. count .. ")" or "")
    )
    local function finish()
        UI.CloseDialog()
        local active = S.ActiveProfile()
        if fromGraph and active and active.id == profileID then
            UI.GraphDialog()
        end
    end
    f.keep:SetScript("OnClick", finish)
    f.delete:SetScript("OnClick", function()
        local ok, why = S.DeleteNode(profileID, nodeID)
        if ok then
            finish()
        else
            UI.Status(why, true)
        end
    end)
end

function UI.GraphDialog()
    local p, selected = S.ActiveProfile()
    if not p then
        UI.SaveDialog(false)
        return
    end
    local f, first = UI.Dialog("graph", "Build checkpoints", 1000, 618)
    if first then
        f.summary = W.Text(f, "", 22, -62, 956, 14, W.colors.gold)
        W.Text(
            f,
            "Click a node to load it. Edit talents, then save a checkpoint to grow a new branch.\nThe x deletes a node and all its descendants. Undo restores draft edits, not deleted nodes.",
            22,
            -88,
            956,
            12,
            W.colors.muted
        )
        f.scroll = W.Scroll(f, 22, -140, 956, 376)
        f.rows = {}
        f.lines = {}
        f.horizontal = CreateFrame("Slider", nil, f)
        f.horizontal:SetPoint("TOPLEFT", 22, -525)
        f.horizontal:SetSize(944, 8)
        f.horizontal:SetOrientation("HORIZONTAL")
        f.horizontal:SetMinMaxValues(0, 1)
        f.horizontal:SetValueStep(25)
        f.horizontal:SetThumbTexture("Interface\\Buttons\\WHITE8X8")
        f.horizontal:GetThumbTexture():SetSize(60, 8)
        f.horizontal:GetThumbTexture():SetVertexColor(0.38, 0.47, 0.53, 0.85)
        f.horizontal:SetScript("OnValueChanged", function(_, value)
            f.scroll:SetHorizontalScroll(value)
        end)
        f.selected = W.Text(f, "", 22, -550, 700, 13, W.colors.muted)
        W.Button(f, "+ Checkpoint", 782, -560, 196, function()
            UI.SaveDialog(true)
        end, true, 30)
    end
    for _, r in ipairs(f.rows) do
        r:Hide()
    end
    for _, l in ipairs(f.lines) do
        l:Hide()
    end
    local positions = {}
    local lineCount = 0
    local function line(x1, y1, x2, y2, c)
        lineCount = lineCount + 1
        W.PooledLine(f.lines, lineCount, f.scroll.content, x1, y1, x2, y2, c)
    end
    local items = UI.ProfileNodes(p)
    local maxDepth = 0
    for i, item in ipairs(items) do
        local node = item.node
        local x, y = 14 + item.depth * 180, 14 + (i - 1) * 70
        positions[node.id] = { x = x, y = y }
        maxDepth = math.max(maxDepth, item.depth)
        local row = f.rows[i]
        if not row then
            row = W.Button(f.scroll.content, "", 0, 0, 162, nil, false, 54)
            row.title = W.Text(row, "", 10, -9, 142, 13)
            row.title:SetWordWrap(false)
            row.detail = W.Text(row, "", 10, -33, 116, 11, W.colors.muted)
            row.delete = W.Button(row, "x", 139, -30, 18, nil, false, 18)
            row.delete.tip = "Delete this checkpoint and all its descendants."
            f.rows[i] = row
        end
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", x, -y)
        row:Show()
        row:SetActive(selected.id == node.id)
        row.title:SetText(FT.SafeText(node.title, 48))
        row.detail:SetText(
            "Lv. " .. M.RequiredLevel(node.build) .. " • " .. #node.build.order .. " pts"
        )
        row:SetScript("OnClick", function()
            S.LoadNode(p.id, node.id)
            UI.GraphDialog()
        end)
        row.delete:SetEnabled(not S.readOnly)
        row.delete:SetScript("OnClick", function()
            UI.DeleteNodeDialog(p.id, node.id, true)
        end)
        row:SetScript("OnEnter", function(self)
            self:Paint(true)
            W.Tooltip(self, FT.SafeText(node.title, 48), {
                "Click to load this checkpoint.",
                #node.build.order .. " points • target " .. node.build.level,
            })
        end)
        row:SetScript("OnLeave", function(self)
            self:Paint(false)
            GameTooltip:Hide()
        end)
        if node.parent then
            local parent = positions[node.parent]
            local mid = x - 9
            line(parent.x + 162, parent.y + 27, mid, parent.y + 27, { 0.50, 0.56, 0.60 })
            line(mid, parent.y + 27, mid, y + 27, { 0.50, 0.56, 0.60 })
            line(mid, y + 27, x, y + 27, { 0.50, 0.56, 0.60 })
        end
    end
    f.summary:SetText(
        FT.SafeText(p.name, 48)
            .. " • "
            .. #items
            .. " checkpoints"
            .. (S.Dirty() and " • unsaved draft changes" or "")
    )
    f.selected:SetText(
        "Selected: " .. FT.SafeText(selected.title, 48) .. " • new checkpoints branch from here"
    )
    local contentWidth = math.max(944, (maxDepth + 1) * 180 + 14)
    f.scroll.content:SetWidth(contentWidth)
    f.scroll:SetContentHeight(#items * 70 + 20)
    f.horizontal:SetMinMaxValues(0, math.max(1, contentWidth - 944))
    f.horizontal:SetShown(contentWidth > 944)
end

function UI.RaceDialog()
    local f, first = UI.Dialog("races", "Race & class atlas", 960, 626)
    if first then
        W.Text(
            f,
            "Choose a race and class by clicking an available cell. All existing class drafts are kept.",
            22,
            -63,
            916,
            13,
            W.colors.muted
        )
        f.cells = {}
        f.rows = {}
        f.headers = {}
        for i, cid in ipairs(FT.classOrder) do
            local c = M.Class(cid)
            local x = 246 + (i - 1) * 76
            local icon = W.Icon(f, c.icon, x + 20, -105, 26)
            f.headers[i] = W.Text(f, c.name, x, -137, 70, 10)
            f.headers[i]:SetJustifyH("CENTER")
        end
        for i, rid in ipairs({ 1, 3, 4, 7, 95, 2, 6, 8, 5, 96 }) do
            local race = FT.Data.races[rid]
            local y = -169 - (i - 1) * 38
            W.Text(
                f,
                race.name,
                22,
                y - 8,
                216,
                12,
                race.faction == "Alliance" and { 0.46, 0.67, 0.88 } or { 0.92, 0.47, 0.39 }
            )
            for j, cid in ipairs(FT.classOrder) do
                local available = M.RaceAllowed(cid, rid)
                local b = W.Button(
                    f,
                    available and "Select" or "—",
                    246 + (j - 1) * 76,
                    y,
                    70,
                    function()
                        S.SwitchClass(cid)
                        local build = FT.Copy(S.Build())
                        build.raceID = rid
                        W.Result(S.Edit(build))
                        UI.CloseDialog()
                    end,
                    false,
                    30
                )
                if not available then
                    b:Disable()
                end
                f.cells[#f.cells + 1] = { button = b, classID = cid, raceID = rid }
            end
        end
        W.Text(
            f,
            "Alliance • Horde   |   Forever race-and-class combinations for this snapshot.\nSkyborne choices differ by faction. Select an available combination to plan a build.",
            22,
            -568,
            916,
            12,
            W.colors.muted
        )
    end
    local build = S.Build()
    for _, cell in ipairs(f.cells) do
        cell.button:SetActive(cell.classID == build.classID and cell.raceID == build.raceID)
    end
end

function UI.HelpDialog()
    local f, first = UI.Dialog("help", "A quick guide", 850, 594)
    if first then
        W.Text(f, "Plan the whole journey", 22, -68, 806, 16, W.colors.gold)
        W.Text(
            f,
            "Left click adds a point; right click removes one. Shift fills or clears a talent.\nRows unlock every 5 points in the same tree. Prerequisites and the 51-point limit are enforced.\nThe target level controls your budget; the header shows the level your spent points require.",
            22,
            -100,
            806,
            13
        )
        W.Text(f, "Find the skill, understand the talents", 22, -172, 806, 16, W.colors.gold)
        W.Text(
            f,
            "Search names, schools, or description text. Hover a skill to highlight its talent interactions.\nCheck boxes to keep multiple highlights; Clear highlights unchecks all. Click a skill for ranks.\nCtrl click a talent to inspect skills. Simulator estimates one use; Advanced explains its assumptions.",
            22,
            -204,
            806,
            13
        )
        W.Text(f, "Undo, preview, and branch", 22, -276, 806, 16, W.colors.gold)
        W.Text(
            f,
            "Undo / Redo (Ctrl+Z / Ctrl+Y) keep up to 100 edits per class. Drafts autosave between sessions.\nClick an Order step to preview that level. Full build returns; Branch here starts from that step.\nSave a named build, then add checkpoints. Click an older node to grow an alternate branch.",
            22,
            -308,
            806,
            13
        )
        W.Text(f, "Share and open quickly", 22, -380, 806, 16, W.colors.gold)
        W.Text(
            f,
            "Share opens a selected string you can Ctrl+C and send anywhere. Import previews a pasted string.\nAddon whisper gives your friend a clickable receipt and stores it in Library → Received.\nCtrl click a Library profile to share; right click it to rename or delete. Text whisper opens a draft.\nOpen with /ftc, /forevertalents, the minimap button, or a key set in WoW's Key Bindings.",
            22,
            -412,
            806,
            13
        )
        W.Text(
            f,
            "Free, unofficial community project. Not affiliated with or endorsed by Blizzard Entertainment.\nWorld of Warcraft artwork and text © Blizzard Entertainment and respective rights holders. See NOTICE.txt.",
            22,
            -480,
            806,
            11,
            W.colors.muted
        )
        f.data = W.Text(f, "", 22, -514, 806, 11, W.colors.muted)
        W.Button(f, "Hunter pet atlas", 22, -552, 210, UI.PetDialog)
        W.Button(f, "Forever perk reference", 244, -552, 230, UI.PerkDialog)
        W.Button(f, "Settings", 486, -552, 342, UI.SettingsDialog)
    end
    f.data:SetText(
        "Data snapshot: "
            .. FT.Data.meta.generatedAt:sub(1, 10)
            .. " • client "
            .. FT.Data.meta.build
            .. " • 27 trees / 466 talents.\nPlanning is independent of your learned talents. My talents imports a legal order derived from the client."
    )
end
