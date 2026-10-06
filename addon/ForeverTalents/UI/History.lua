local _, FT = ...
local UI, W, M = FT.UI, FT.UI.W, FT.Model

function UI.CreateHistory(parent)
    local p = W.Panel(parent, 1012, -188, 252, 528)
    UI.historyPanel = p
    UI.historyTab = "order"
    UI.historyTabs = {}
    for i, spec in ipairs({
        { "order", "Order", 8, 60 },
        { "graph", "Checkpoints", 72, 100 },
        { "library", "Library", 176, 68 },
    }) do
        local key = spec[1]
        UI.historyTabs[key] = W.Button(p, spec[2], spec[3], -9, spec[4], function()
            UI.historyTab = key
            UI.historyScroll:ScrollTo(0)
            UI.RefreshHistory()
            if key == "graph" then
                UI.GraphDialog()
            end
        end)
    end
    UI.profileName = W.Text(p, "", 12, -48, 228, 13, W.colors.gold)
    UI.profileName:SetWordWrap(false)
    UI.profileHint = W.Text(p, "", 12, -68, 228, 11, W.colors.muted)
    UI.profileHint:SetWordWrap(false)
    UI.checkpointButton = W.Button(p, "+ Checkpoint", 12, -90, 145, function()
        UI.SaveDialog(UI.historyTab ~= "library")
    end)
    UI.graphButton = W.Button(p, "Open", 165, -90, 75, function()
        UI.GraphDialog()
    end)
    UI.historyScroll = W.Scroll(p, 10, -134, 232, 342)
    UI.historyRows, UI.historyLines = {}, {}
    UI.historyEmpty = W.Text(UI.historyScroll.content, "", 8, -12, 205, 13, W.colors.muted)
    UI.previewBack = W.Button(p, "Full build", 12, -490, 100, function()
        FT.Store.Preview(nil)
    end, false, 26)
    UI.previewBranch = W.Button(p, "Branch here", 122, -490, 118, function()
        W.Result(FT.Store.BranchPreview())
        UI.SaveDialog(true)
    end, false, 26)
end

local function rowAt(i, height)
    local row = UI.historyRows[i]
    if not row then
        row = W.Button(UI.historyScroll.content, "", 0, 0, 214, nil, false, height or 44)
        row.title = W.Text(row, "", 8, -6, 196, 12)
        row.title:SetWordWrap(false)
        row.detail = W.Text(row, "", 8, -24, 196, 10, W.colors.muted)
        row.detail:SetWordWrap(false)
        row.up = W.Button(row, "↑", 172, -4, 18, function(self)
            W.Result(FT.Store.Apply(M.Reorder, self:GetParent().step, self:GetParent().step - 1))
        end, false, 18)
        row.down = W.Button(row, "↓", 193, -4, 18, function(self)
            W.Result(FT.Store.Apply(M.Reorder, self:GetParent().step, self:GetParent().step + 1))
        end, false, 18)
        row.up.tip = "Move this point one level earlier. Talent rules still apply."
        row.down.tip = "Move this point one level later. Talent rules still apply."
        row.delete = W.Button(row, "x", 190, -5, 18, nil, false, 18)
        row.delete:ClearAllPoints()
        row.delete:SetPoint("TOPRIGHT", -5, -26)
        row.delete.tip =
            "Delete this checkpoint and all its child checkpoints. A confirmation shows how many will be removed."
        UI.historyRows[i] = row
    end
    row:Show()
    row.up:Hide()
    row.down:Hide()
    row.delete:Hide()
    local width = UI.CompactView() and 364 or 214
    row:SetSize(width, height or 44)
    row.up:ClearAllPoints()
    row.up:SetPoint("TOPLEFT", width - 42, -4)
    row.down:ClearAllPoints()
    row.down:SetPoint("TOPLEFT", width - 21, -4)
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", 0, -(i - 1) * (height or 44) - i * 3 + 3)
    row.title:ClearAllPoints()
    row.title:SetPoint("TOPLEFT", 8, -6)
    row.title:SetWidth(width - 18)
    row.detail:ClearAllPoints()
    row.detail:SetPoint("TOPLEFT", 8, -24)
    row.detail:SetWidth(width - 18)
    row:SetActive(false)
    row.tip = nil
    return row
end

function UI.ProfileNodes(profile)
    local result, children = {}, {}
    for _, id in ipairs(profile.order) do
        local node = profile.nodes[id]
        local parent = node.parent or 0
        children[parent] = children[parent] or {}
        children[parent][#children[parent] + 1] = node
    end
    local function walk(parent, depth)
        for _, node in ipairs(children[parent] or {}) do
            result[#result + 1] = { node = node, depth = depth }
            walk(node.id, depth + 1)
        end
    end
    walk(0, 0)
    return result
end

function UI.RefreshHistory()
    if not UI.historyPanel then
        return
    end
    for _, r in ipairs(UI.historyRows) do
        r:Hide()
    end
    for _, l in ipairs(UI.historyLines) do
        l:Hide()
    end
    local lineCount = 0
    local function line(x1, y1, x2, y2, c)
        lineCount = lineCount + 1
        return W.PooledLine(UI.historyLines, lineCount, UI.historyScroll.content, x1, y1, x2, y2, c)
    end
    local build = FT.Store.Build()
    local p, node = FT.Store.ActiveProfile()
    local dirty = FT.Store.Dirty()
    UI.checkpointButton:SetText(
        UI.historyTab == "library" and "+ New build" or "Save as new checkpoint"
    )
    UI.checkpointButton:SetEnabled(not FT.Store.readOnly and not FT.Store.preview)
    UI.profileName:SetText(
        p and ("Active: " .. FT.SafeText(node.title, 48)) or "No saved checkpoint"
    )
    UI.profileHint:SetText(
        p and (dirty and "Unsaved changes • use Update" or "Saved • " .. p.name)
            or "Save build to start checkpoints"
    )
    UI.graphButton:SetEnabled(p ~= nil)
    for k, b in pairs(UI.historyTabs) do
        b:SetActive(k == UI.historyTab)
    end
    UI.previewBack:SetShown(FT.Store.preview ~= nil)
    UI.previewBranch:SetShown(FT.Store.preview ~= nil)
    local count = 0
    if UI.historyTab == "order" then
        local index = M.Index(build.classID)
        for i, id in ipairs(build.order) do
            local t = index[id]
            local r = rowAt(i)
            count = i
            r.step = i
            r.title:SetWidth(UI.CompactView() and 308 or 158)
            r.title:SetText("Lv. " .. (9 + i) .. "  " .. t.name)
            local rank = 0
            for j = 1, i do
                if build.order[j] == id then
                    rank = rank + 1
                end
            end
            r.detail:SetText(t.treeName .. " • rank " .. rank .. " / " .. t.max)
            r.up:SetShown(i > 1 and not FT.Store.preview)
            r.down:SetShown(i < #build.order and not FT.Store.preview)
            r:SetActive(FT.Store.preview == i)
            r:SetScript("OnClick", function()
                FT.Store.Preview(i)
            end)
            r:SetScript("OnEnter", function(self)
                self:Paint(true)
                UI.HighlightSkill({ related = { { id = id } } })
                W.Tooltip(self, "Level " .. (9 + i), {
                    "Click to preview this level. The full build stays saved.",
                    "Use the small arrows to reorder a point; all rules still apply.",
                })
            end)
            r:SetScript("OnLeave", function(self)
                self:Paint(false)
                GameTooltip:Hide()
                UI.HighlightSkill(nil)
            end)
        end
        UI.historyEmpty:SetText(
            "Your leveling path starts here.\n\nLeft click a talent to add a point. Every step is kept in order.\n\nClick a step to preview that level, then branch from it if you like."
        )
    elseif UI.historyTab == "graph" then
        if p then
            local rows = UI.ProfileNodes(p)
            local positions = {}
            for i, item in ipairs(rows) do
                local n = item.node
                local r = rowAt(i, 48)
                count = i
                local indent = math.min(4, item.depth) * 12
                r:ClearAllPoints()
                r:SetPoint("TOPLEFT", indent, -(i - 1) * 58)
                local width = UI.CompactView() and 364 or 214
                r:SetWidth(width - indent)
                r.title:SetWidth(width - 18 - indent)
                r.detail:SetWidth(width - 44 - indent)
                r.title:SetText(FT.SafeText(n.title, 48))
                r.detail:SetText(
                    "Lv. "
                        .. n.build.level
                        .. " • "
                        .. #n.build.order
                        .. " pts"
                        .. (item.depth > 4 and " • branch " .. item.depth or "")
                )
                r:SetActive(node and node.id == n.id)
                r:SetScript("OnClick", function()
                    W.Result(FT.Store.LoadNode(p.id, n.id))
                end)
                r.delete:Show()
                r.delete:SetEnabled(not FT.Store.readOnly)
                r.delete:SetScript("OnClick", function()
                    UI.DeleteNodeDialog(p.id, n.id)
                end)
                r:SetScript("OnEnter", function(self)
                    self:Paint(true)
                    W.Tooltip(self, FT.SafeText(n.title, 48), {
                        node and node.id == n.id and "Active checkpoint."
                            or "Click to load this checkpoint.",
                        "Update saves edits here. Save as new checkpoint creates a child.",
                        "Loading another node does not save edits; Undo returns to them.",
                    })
                end)
                r:SetScript("OnLeave", function(self)
                    self:Paint(false)
                    GameTooltip:Hide()
                end)
                local y = (i - 1) * 58 + 24
                positions[n.id] = { x = indent, y = y }
                if n.parent and positions[n.parent] then
                    local parent = positions[n.parent]
                    line(indent - 6, parent.y, indent - 6, y, { 0.43, 0.49, 0.54 })
                    line(indent - 6, y, indent, y, { 0.43, 0.49, 0.54 })
                end
            end
        end
        UI.historyEmpty:SetText(
            "Save this build to create your first node.\n\nMake a checkpoint, try an alternate path, and checkpoint again.\n\nLoad a node and use Update checkpoint to save edits in place, or New checkpoint to branch."
        )
    else
        local library = UI.libraryMode or "saved"
        UI.graphButton:SetText(library == "saved" and "Received" or "Saved")
        UI.graphButton:SetEnabled(true)
        UI.graphButton:SetScript("OnClick", function()
            UI.libraryMode = library == "saved" and "received" or "saved"
            UI.historyScroll:ScrollTo(0)
            UI.RefreshHistory()
        end)
        if library == "saved" then
            for i = #FT.Store.db.profileOrder, 1, -1 do
                local profile = FT.Store.db.profiles[FT.Store.db.profileOrder[i]]
                count = count + 1
                local last = profile.nodes[profile.order[#profile.order]]
                local r = rowAt(count, 48)
                r.title:SetText(FT.SafeText(profile.name, 48))
                r.detail:SetText(
                    M.Class(last.build.classID).name .. " • " .. #profile.order .. " checkpoints"
                )
                r:SetActive(p and p.id == profile.id)
                r:SetScript("OnClick", function(_, button)
                    if IsControlKeyDown and IsControlKeyDown() then
                        UI.ShareDialog(last.build, profile.name, profile)
                    elseif button == "RightButton" then
                        UI.ProfileMenu(r, profile)
                    else
                        W.Result(FT.Store.LoadNode(profile.id, last.id))
                    end
                end)
                r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
                r:SetScript("OnEnter", function(self)
                    self:Paint(true)
                    W.Tooltip(self, FT.SafeText(profile.name, 48), {
                        "Click: load newest checkpoint • Ctrl click: share",
                        "Right click: share, view checkpoints, rename, or delete.",
                    })
                end)
                r:SetScript("OnLeave", function(self)
                    self:Paint(false)
                    GameTooltip:Hide()
                end)
            end
        else
            for i = #FT.Store.db.inbox, 1, -1 do
                local item = FT.Store.db.inbox[i]
                local shared = FT.Codec.Decode(item.code)
                if shared then
                    count = count + 1
                    local r = rowAt(count, 48)
                    r.title:SetText(FT.SafeText(shared.name, 48))
                    r.detail:SetText("From " .. FT.SafeText(item.sender, 64))
                    r:SetScript("OnClick", function()
                        UI.ImportDialog(item.code)
                    end)
                    r:SetScript("OnEnter", function(self)
                        self:Paint(true)
                        W.Tooltip(self, FT.SafeText(shared.name, 48), {
                            M.Class(shared.classID).name
                                .. " • "
                                .. #shared.order
                                .. " points. Click to preview.",
                        })
                    end)
                    r:SetScript("OnLeave", function(self)
                        self:Paint(false)
                        GameTooltip:Hide()
                    end)
                end
            end
        end
        UI.historyEmpty:SetText(
            library == "saved"
                    and "No saved profiles yet.\n\nUse Save build to give your build a name. Your profiles are shared across your characters.\n\nCtrl click a saved profile to share it."
                or "No builds received yet.\n\nA friend's addon whisper appears here and as a clickable chat receipt.\n\nYou can also paste their string with Import."
        )
    end
    if UI.historyTab ~= "library" then
        UI.graphButton:SetText("Open")
        UI.graphButton.tip =
            "Open the full checkpoint workspace with readable titles and your selected node in view."
        UI.graphButton:SetScript("OnClick", function()
            UI.GraphDialog()
        end)
    end
    UI.historyEmpty:SetShown(count == 0)
    UI.historyScroll:SetContentHeight(
        count * (UI.historyTab == "graph" and 58 or UI.historyTab == "library" and 51 or 47)
    )
end
