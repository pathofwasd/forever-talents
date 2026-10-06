local _, FT = ...
local UI, W, S = FT.UI, FT.UI.W, FT.Store

function UI.SettingsDialog()
    local f, first = UI.Dialog("settings", "Make it comfortable", 600, 460)
    if first then
        W.Text(f, "Window size", 22, -72, 556, 16, W.colors.gold)
        f.classic = W.Checkbox(f, 22, -307, function(checked)
            W.Result(S.SetSimpleView(checked))
        end)
        W.Text(f, "Classic mode", 54, -310, 520, 15, W.colors.gold)
        W.Text(
            f,
            "Class, talents and skill levels only. Extra tools are hidden.\nTurn it off to restore them; your saved builds and character are kept.",
            22,
            -345,
            556,
            12,
            W.colors.muted
        )
        W.Text(
            f,
            "The window fits your screen automatically. Choose a comfortable scale.\nDrag the title bar to move it; the position is kept between sessions.",
            22,
            -102,
            556,
            13,
            W.colors.muted
        )
        f.scale = W.Text(f, "", 252, -160, 160, 13)
        W.Button(f, "Smaller", 22, -151, 210, function()
            S.db.settings.scale = math.max(0.65, S.db.settings.scale - 0.05)
            UI.Fit()
            f.scale:SetText(string.format("%.0f%%", S.db.settings.scale * 100))
        end)
        W.Button(f, "Larger", 420, -151, 158, function()
            S.db.settings.scale = math.min(1.3, S.db.settings.scale + 0.05)
            UI.Fit()
            f.scale:SetText(string.format("%.0f%%", S.db.settings.scale * 100))
        end)
        f.minimap = W.Button(f, "", 22, -211, 556, function()
            S.db.settings.minimap = not S.db.settings.minimap
            UI.RefreshMinimap()
            f.minimap:SetText(
                S.db.settings.minimap and "Minimap button: shown" or "Minimap button: hidden"
            )
        end)
        W.Button(f, "Reset window position", 22, -257, 556, function()
            S.db.settings.position = nil
            UI.frame:ClearAllPoints()
            UI.frame:SetPoint("CENTER")
            UI.Fit()
        end)
        W.Text(
            f,
            "Open with /ftc or /forevertalents. Assign a key under WoW's Key Bindings\nto open Forever Talents without reaching for the mouse.",
            22,
            -398,
            556,
            12,
            W.colors.muted
        )
    end
    f.scale:SetText(string.format("%.0f%%", S.db.settings.scale * 100))
    f.minimap:SetText(S.db.settings.minimap and "Minimap button: shown" or "Minimap button: hidden")
    f.classic:SetChecked(S.SimpleView())
end

function UI.PetDialog()
    local f, first = UI.Dialog("pets", "Hunter pet atlas", 900, 630)
    if first then
        W.Text(
            f,
            "Pet abilities, rank levels and tameable beasts from the collected Forever data.",
            22,
            -65,
            856,
            13,
            W.colors.muted
        )
        local notes = {}
        for _, note in ipairs(FT.Data.pets.notes or {}) do
            notes[#notes + 1] = note.title .. ": " .. note.text
        end
        f.reference = W.Text(f, table.concat(notes, "\n"), 22, -86, 856, 12, W.colors.muted)
        f.mode = "skills"
        f.page = 1
        f.search = W.Edit(f, "Search pet skills or beasts…", 22, -128, 350, function(text)
            f.query = text
            f.page = 1
            if f.refresh then
                f.refresh()
            end
        end)
        f.family = W.Button(f, "All pet families  v", 388, -128, 278, function(self)
            local options = {
                {
                    text = "All pet families",
                    action = function()
                        f.familyID = nil
                        f.page = 1
                        f.refresh()
                    end,
                },
            }
            for _, family in ipairs(FT.Data.pets.families) do
                options[#options + 1] = {
                    text = family.name,
                    action = function()
                        f.familyID = family.id
                        f.page = 1
                        f.refresh()
                    end,
                }
            end
            W.Menu(self, options, 278)
        end)
        f.switch = W.Button(f, "Show beasts", 682, -128, 196, function()
            f.mode = f.mode == "skills" and "beasts" or "skills"
            f.page = 1
            f.refresh()
        end)
        f.scroll = W.Scroll(f, 22, -176, 856, 369)
        f.rows = {}
        f.empty = W.Text(
            f.scroll.content,
            "No matches. Try another family or search.",
            12,
            -12,
            800,
            13,
            W.colors.muted
        )
        f.count = W.Text(f, "", 22, -563, 496, 12, W.colors.muted)
        f.prev = W.Button(f, "Previous", 552, -562, 154, function()
            f.page = math.max(1, f.page - 1)
            f.refresh()
        end)
        f.next = W.Button(f, "Next", 724, -562, 154, function()
            f.page = f.page + 1
            f.refresh()
        end)
        f.refresh = function()
            local list, query = {}, (f.query or ""):lower()
            local familyName = "All pet families"
            for _, family in ipairs(FT.Data.pets.families) do
                if family.id == f.familyID then
                    familyName = family.name
                end
            end
            f.family:SetText(familyName .. "  v")
            f.switch:SetText(f.mode == "skills" and "Show beasts" or "Show skills")
            local source = f.mode == "skills" and FT.Data.pets.skills or FT.Data.pets.tameable
            for _, entry in ipairs(source) do
                local matchesFamily = not f.familyID or entry.family == f.familyID
                if f.familyID and entry.families then
                    for _, id in ipairs(entry.families) do
                        if id == f.familyID then
                            matchesFamily = true
                        end
                    end
                end
                if
                    matchesFamily
                    and (
                        query == ""
                        or entry.name:lower():find(query, 1, true)
                        or (entry.text or ""):lower():find(query, 1, true)
                    )
                then
                    list[#list + 1] = entry
                end
            end
            local pages = math.max(1, math.ceil(#list / 40))
            f.page = math.min(pages, f.page)
            for _, row in ipairs(f.rows) do
                row:Hide()
            end
            local visible = math.min(40, #list - (f.page - 1) * 40)
            for i = 1, visible do
                local entry = list[(f.page - 1) * 40 + i]
                local row = f.rows[i]
                if not row then
                    row = W.Button(f.scroll.content, "", 0, -(i - 1) * 49, 840, nil, false, 45)
                    row.title = W.Text(row, "", 12, -8, 810, 13)
                    row.detail = W.Text(row, "", 12, -27, 810, 11, W.colors.muted)
                    f.rows[i] = row
                end
                row:Show()
                row.title:SetText(entry.name)
                local detail
                if f.mode == "skills" then
                    detail = "Level "
                        .. entry.level
                        .. " • "
                        .. (entry.label ~= "" and entry.label or "Unranked / passive")
                        .. " • spell "
                        .. entry.spellID
                else
                    local family = ""
                    for _, fam in ipairs(FT.Data.pets.families) do
                        if fam.id == entry.family then
                            family = fam.name
                        end
                    end
                    local zones = {}
                    for _, id in ipairs(entry.location or {}) do
                        zones[#zones + 1] = (FT.Data.pets.zones or {})[id] or ("Zone " .. id)
                    end
                    local levels = entry.minlevel
                            and ("Levels " .. entry.minlevel .. "–" .. (entry.maxlevel or entry.minlevel))
                        or "Level unrecorded"
                    detail = levels
                        .. " • "
                        .. family
                        .. " • "
                        .. (#zones > 0 and table.concat(zones, ", ") or "Location unrecorded")
                end
                row.detail:SetText(detail)
                local description = entry.spellID and FT.Description(entry) or detail
                row:SetScript("OnEnter", function(self)
                    self:Paint(true)
                    W.Tooltip(self, entry.name, {
                        description,
                        entry.spellID
                                and "Unlock levels come from the pet skill table; some passive entries use level 0."
                            or "Creature ID " .. entry.id,
                    })
                end)
                row:SetScript("OnLeave", function(self)
                    self:Paint(false)
                    GameTooltip:Hide()
                end)
                row:SetScript("OnClick", function()
                    W.Tooltip(row, entry.name, { description })
                end)
            end
            f.empty:SetShown(#list == 0)
            f.scroll:SetContentHeight(math.max(0, visible) * 49)
            f.scroll:ScrollTo(0)
            f.count:SetText(#list .. " matches • page " .. f.page .. " / " .. pages)
            f.prev:SetEnabled(f.page > 1)
            f.next:SetEnabled(f.page < pages)
        end
    end
    f.refresh()
end

function UI.PerkDialog()
    local f, first = UI.Dialog("perks", "Forever perk reference", 1000, 620)
    if first then
        W.Text(
            f,
            "These are the separate Forever legacy perks, with their own currency and 16-point budget.\nThey do not consume talent points. Hover a node to read every rank.",
            22,
            -64,
            956,
            13,
            W.colors.muted
        )
        f.panels = {}
        for i, tree in ipairs(FT.Data.perks) do
            local panel = W.Panel(f, 22 + (i - 1) * 322, -122, 312, 434, { 0.047, 0.066, 0.083 })
            W.Text(panel, tree.name, 14, -16, 284, 18, W.colors.gold)
            W.Text(panel, tree.blurb, 14, -46, 284, 12, W.colors.muted)
            for j, node in ipairs(tree.nodes) do
                local b = W.Button(panel, "", 12, -96 - (j - 1) * 35, 288, nil, false, 31)
                local icon = W.Icon(b, node.icon, 6, -4, 23)
                local title = W.Text(b, node.name, 37, -8, 243, 12)
                title:SetWordWrap(false)
                b:SetScript("OnEnter", function(self)
                    self:Paint(true)
                    local lines = {
                        "Max ranks: "
                            .. node.max
                            .. " • source gate: "
                            .. node.gate
                            .. " perk points",
                    }
                    for r, text in ipairs(node.ranks) do
                        lines[#lines + 1] = "Rank " .. r .. ": " .. text
                    end
                    W.Tooltip(self, node.name, lines)
                end)
                b:SetScript("OnLeave", function(self)
                    self:Paint(false)
                    GameTooltip:Hide()
                end)
            end
        end
        W.Text(
            f,
            "This atlas preserves the collected perk data as reference. Talent profiles and their checkpoint graph\ncover class talent trees; perk allocations use a separate system in the game.",
            22,
            -574,
            956,
            12,
            W.colors.muted
        )
    end
end
