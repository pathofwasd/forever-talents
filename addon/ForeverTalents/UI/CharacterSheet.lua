local _, FT = ...
local UI, W, S, C = FT.UI, FT.UI.W, FT.Store, FT.Character
local function fmt(value)
    return string.format("%.1f", value or 0):gsub("%.0$", "")
end
function UI.CharacterSheet()
    local f, first = UI.Dialog("characterSheet", "Character • simulator workspace", 920, 686)
    if first then
        f.identity = W.Text(f, "", 22, -63, 600, 18, W.colors.gold)
        f.name = W.Edit(f, "Character name", 668, -60, 230, function(text, user)
            if user and not f.updating then
                f.sheet.name = text
                f.save()
            end
        end, 48)
        f.modeButtons = {}
        for i, mode in ipairs({
            { "gear", "Base + custom gear" },
            { "manual", "Overall stats" },
            { "captured", "Live capture" },
        }) do
            f.modeButtons[mode[1]] = W.Button(f, mode[2], 22 + (i - 1) * 294, -100, 282, function()
                local ok, why = C.SetMode(S.View(), mode[1])
                if not ok then
                    UI.Status(why)
                    return
                end
                f.sheet = C.Get(S.View())
                f.populate()
            end)
        end
        local gear = W.Panel(f, 22, -146, 280, 424, { 0.045, 0.060, 0.075 })
        local crest = gear:CreateTexture(nil, "ARTWORK")
        crest:SetPoint("TOPLEFT", 76, -8)
        crest:SetSize(128, 256)
        crest:SetTexture("Interface\\AddOns\\ForeverTalents\\Media\\Character.tga")
        f.gearButtons = {}
        for i, slot in ipairs(C.slots) do
            local x, y =
                i <= 7 and 8 or i <= 14 and 182 or 8 + (i - 15) * 90,
                i <= 7 and -16 - (i - 1) * 48 or i <= 14 and -16 - (i - 8) * 48 or -360
            local b = W.Button(gear, slot.name, x, y, i <= 14 and 90 or 84, function()
                UI.GearDialog(slot.key)
            end, false, 38)
            f.gearButtons[slot.key] = b
        end
        f.summary = W.Text(f, "", 22, -587, 280, 12, W.colors.teal)
        f.form = W.Button(gear, "Caster form", 100, -282, 80, function()
            local nextForm = { caster = "cat", cat = "bear", bear = "caster" }
            f.sheet.form = nextForm[f.sheet.form]
            f.save()
            f.populate()
        end)
        f.scroll = W.Scroll(f, 320, -146, 578, 470)
        local content = f.scroll.content
        f.source = W.Text(content, "", 0, 0, 548, 12, W.colors.teal)
        f.fields, f.totals, f.labels = {}, {}, {}
        for i, field in ipairs(C.fields) do
            local x, y = ((i - 1) % 3) * 186, -68 - math.floor((i - 1) / 3) * 66
            f.labels[field.key] = W.Text(content, field.label, x, y, 176, 11, W.colors.muted)
            local e = W.Edit(content, "0", x, y - 19, 120, function(text, user)
                if user and not f.updating and f.sheet.mode ~= "captured" and tonumber(text) then
                    f.sheet.stats[field.key] = tonumber(text)
                    f.save()
                end
            end, 12)
            e.hideClear = true
            e.clear:Hide()
            e:HookScript("OnEnter", function(self)
                W.Tooltip(self, field.label, {
                    f.sheet.mode == "gear"
                            and "Additional bonuses beyond the reference base and gear slots."
                        or f.sheet.mode == "captured" and "Captured totals; use Overall stats or custom gear to create an editable plan."
                        or "Your overall value before the modeled talent and racial passives. See the resulting total on the right.",
                })
            end)
            e:HookScript("OnLeave", function()
                GameTooltip:Hide()
            end)
            f.fields[field.key] = e
            f.totals[field.key] = W.Text(content, "", x + 128, y - 27, 48, 11, W.colors.gold)
        end
        local weaponY = -68 - math.ceil(#C.fields / 3) * 66
        f.notesY = weaponY - 48
        f.weaponType = W.Button(content, "Weapon type", 0, weaponY, 548, function()
            local pos = 1
            for i, v in ipairs(C.weaponTypes) do
                if v.key == f.sheet.weaponType then
                    pos = i
                end
            end
            f.sheet.weaponType = C.weaponTypes[pos % #C.weaponTypes + 1].key
            f.save()
            f.populate()
        end)
        f.notes = W.Text(content, "", 0, f.notesY, 548, 12, W.colors.muted)
        f.save = function()
            local ok, why = C.Save(S.View(), f.sheet)
            if not ok then
                UI.Status(why)
                return
            end
            f.refresh()
        end
        f.refresh = function()
            local result = C.Compute(S.View(), f.sheet)
            f.identity:SetText(
                FT.Data.races[S.View().raceID].name
                    .. " "
                    .. FT.Model.Class(S.View().classID).name
                    .. " • level "
                    .. S.View().level
            )
            f.source:SetText(
                result.source
                    .. "\n"
                    .. (
                        f.sheet.mode == "gear"
                            and "Inputs = extra bonuses. Gold values = resulting totals."
                        or f.sheet.mode == "captured" and "Reported totals are kept; gear slots are reference only."
                        or "Inputs = before modeled passives. Gold values = resulting totals."
                    )
            )
            for key, label in pairs(f.totals) do
                label:SetText(fmt(result.totals[key]))
            end
            f.labels.power:SetText(
                f.sheet.mode == "gear" and "Spell / healing power" or "Spell power"
            )
            f.labels.healing:SetText(
                f.sheet.mode == "gear" and "Healing-only bonus" or "Healing power"
            )
            f.labels.attackPower:SetText(
                f.sheet.mode == "gear" and "Attack power (both)" or "Melee AP"
            )
            f.labels.rangedAP:SetText(f.sheet.mode == "gear" and "Ranged-only AP" or "Ranged AP")
            for key, button in pairs(f.modeButtons) do
                button:SetActive(key == f.sheet.mode)
            end
            f.modeButtons.captured:SetEnabled(f.sheet.capture ~= nil)
            for _, slot in ipairs(C.slots) do
                local item = f.sheet.gear[slot.key]
                f.gearButtons[slot.key]:SetActive(item ~= nil)
                f.gearButtons[slot.key].tip = slot.name
                    .. "\n"
                    .. (item and item.name or "Empty • click to create custom gear.")
                    .. (
                        f.sheet.mode == "captured"
                            and "\nCaptured equipment is reference only; totals already include it."
                        or ""
                    )
            end
            f.summary:SetText(
                "Health "
                    .. fmt(result.totals.health)
                    .. "\nMana "
                    .. fmt(result.totals.mana)
                    .. "\nCentral stats feed every skill."
            )
            f.form:SetShown(S.View().classID == 11)
            f.form:SetText(
                f.sheet.form == "cat" and "Cat form"
                    or f.sheet.form == "bear" and "Bear form"
                    or "Caster form"
            )
            local typeName = "Unspecified"
            for _, v in ipairs(C.weaponTypes) do
                if v.key == f.sheet.weaponType then
                    typeName = v.name
                end
            end
            f.weaponType:SetText("Overall weapon type: " .. typeName)
            f.notes:SetText(
                "Applied stat passives: "
                    .. (#result.passives.included > 0 and table.concat(
                        result.passives.included,
                        ", "
                    ) or "None; skill-specific bonuses appear in the simulator.")
                    .. "\n\n"
                    .. table.concat(result.warnings, "\n\n")
                    .. "\n\nSkill simulations can override these values temporarily. Closing or resetting a skill leaves this character unchanged."
            )
            f.scroll:SetContentHeight(-f.notesY + 8 + f.notes:GetStringHeight())
        end
        f.populate = function()
            f.updating = true
            f.name:SetText(f.sheet.name)
            for key, edit in pairs(f.fields) do
                edit:SetText(tostring(f.sheet.stats[key] or (key == "hit" and 100 or 0)))
                edit:EnableMouse(f.sheet.mode ~= "captured")
                edit:SetAlpha(f.sheet.mode == "captured" and 0.55 or 1)
                edit:SetScript("OnEditFocusGained", function(self)
                    if f.sheet.mode == "captured" then
                        self:ClearFocus()
                    end
                end)
            end
            f.updating = false
            f.refresh()
        end
        f.capture = W.Button(f, "Capture stats & equipment", 320, -634, 280, function()
            local profile = FT.ReadPlayerStats()
            if profile.classID ~= S.View().classID then
                UI.Status("Select your logged-in character's class before capturing its stats.")
                return
            end
            local gear = FT.ReadPlayerEquipment and FT.ReadPlayerEquipment() or {}
            f.sheet = C.FromSnapshot(profile, gear)
            f.save()
            f.populate()
        end, true, 30)
        W.Button(f, "Copy / paste character", 614, -634, 284, function()
            UI.CharacterDialog()
        end, false, 30)
        W.Button(f, "Import my talents & skills", 22, -634, 280, function()
            W.Result(FT.ImportPlayerCharacter())
            f.sheet = FT.Copy(C.Get(S.View()))
            f.populate()
        end, true, 30)
        f.onReturn = function()
            f.sheet = FT.Copy(C.Get(S.View()))
            f.populate()
        end
    end
    f.sheet, f.classID = C.Get(S.View()), S.View().classID
    f.populate()
    f.scroll:ScrollTo(0)
end

function UI.GearDialog(slotKey)
    local slot
    for _, s in ipairs(C.slots) do
        if s.key == slotKey then
            slot = s
        end
    end
    if not slot then
        return
    end
    local sheet = C.Get(S.View())
    local f, first = UI.Dialog("gear", "Custom gear", 750, 648)
    if first then
        f.name = W.Edit(f, "Item name", 22, -65, 706, nil, 80)
        f.scroll = W.Scroll(f, 22, -108, 706, 432)
        f.fields = {}
        for i, field in ipairs(C.gearFields) do
            local x, y = ((i - 1) % 3) * 230, -math.floor((i - 1) / 3) * 66
            W.Text(f.scroll.content, field.label, x, y, 212, 11, W.colors.muted)
            f.fields[field.key] = W.Edit(f.scroll.content, "0", x, y - 21, 212, nil, 12)
            f.fields[field.key].hideClear = true
        end
        f.weaponFields, f.weaponLabels = {}, {}
        for i, v in ipairs({
            { "low", "Raw weapon damage · low" },
            { "high", "Raw weapon damage · high" },
            { "speed", "Weapon speed (sec)" },
        }) do
            f.weaponLabels[v[1]] =
                W.Text(f.scroll.content, v[2], (i - 1) * 230, -480, 212, 11, W.colors.muted)
            f.weaponFields[v[1]] = W.Edit(f.scroll.content, "0", (i - 1) * 230, -501, 212, nil, 12)
            f.weaponFields[v[1]].hideClear = true
        end
        f.type = W.Button(f.scroll.content, "Weapon type", 0, -550, 672, function()
            local pos = 1
            for i, t in ipairs(C.weaponTypes) do
                if t.key == f.item.weaponType then
                    pos = i
                end
            end
            f.item.weaponType = C.weaponTypes[pos % #C.weaponTypes + 1].key
            for _, t in ipairs(C.weaponTypes) do
                if t.key == f.item.weaponType then
                    f.type:SetText(t.name)
                end
            end
        end)
        f.scroll:SetContentHeight(592)
        f.info = W.Text(
            f,
            "Listed bonuses only; item procs and set bonuses need explicit assumptions. Raw weapon damage excludes AP.",
            22,
            -557,
            706,
            11,
            W.colors.muted
        )
        f.equip = W.Button(f, "Equip custom item", 22, -601, 338, function()
            f.item.name, f.item.stats = f.name:GetText(), {}
            for key, edit in pairs(f.fields) do
                f.item.stats[key] = tonumber(edit:GetText()) or 0
            end
            for key, edit in pairs(f.weaponFields) do
                f.item[key] = tonumber(edit:GetText()) or 0
            end
            f.sheet.gear[f.slot] = f.item
            if f.sheet.mode == "captured" then
                UI.Status(
                    "Captured gear is reference only. Choose Base + custom gear to calculate from item bonuses."
                )
            end
            local ok, why = C.Save(S.View(), f.sheet)
            if ok then
                UI.CharacterSheet()
            else
                f.info:SetText(why)
            end
        end, true, 30)
        W.Button(f, "Remove item", 376, -601, 352, function()
            f.sheet.gear[f.slot] = nil
            C.Save(S.View(), f.sheet)
            UI.CharacterSheet()
        end, false, 30)
    end
    f.sheet, f.slot, f.item =
        sheet, slotKey, FT.Copy(sheet.gear[slotKey] or {
            name = "Custom " .. slot.name,
            stats = {},
            low = 0,
            high = 0,
            speed = 0,
            weaponType = "none",
        })
    f.heading:SetText("Custom gear • " .. slot.name)
    f.name:SetText(f.item.name)
    for key, edit in pairs(f.fields) do
        edit:SetText(tostring(f.item.stats[key] or 0))
    end
    for key, edit in pairs(f.weaponFields) do
        edit:SetText(tostring(f.item[key] or 0))
    end
    for _, edit in pairs(f.weaponFields) do
        edit:SetShown(slot.weapon)
    end
    for _, label in pairs(f.weaponLabels) do
        label:SetShown(slot.weapon)
    end
    f.type:SetShown(slot.weapon)
    f.type:SetText(f.item.weaponType or "Unspecified")
    f.scroll:ScrollTo(0)
end
