local _, FT = ...
local UI, W, S, Sim = FT.UI, FT.UI.W, FT.Store, FT.Simulation
local function fmt(n)
    return string.format("%.1f", n or 0):gsub("%.0$", "")
end
local function range(a, b)
    return fmt(a) .. (math.abs(a - b) > 0.05 and " – " .. fmt(b) or "")
end
local function choices(key, options)
    if options then
        return options
    end
    if key == "weaponType" or key == "racialWeaponType" then
        return FT.Character.weaponTypes
    end
    if key == "form" then
        return {
            { key = "caster", name = "Caster" },
            { key = "cat", name = "Cat" },
            { key = "bear", name = "Bear" },
        }
    end
    if key == "effectMode" then
        return { { key = "damage", name = "Damage" }, { key = "healing", name = "Healing" } }
    end
    return {
        { key = "other", name = "Other creature" },
        { key = "beast", name = "Beast" },
        { key = "elemental", name = "Elemental" },
        { key = "humanoid", name = "Humanoid" },
        { key = "giant", name = "Giant" },
    }
end
function UI.SimulationDialog(skill, rank, overrides)
    local f, first = UI.Dialog("simulation", "Simulator", 920, 668)
    if first then
        local character = W.Panel(f, 22, -62, 876, 96)
        f.portrait = W.Icon(character, "class_druid", 14, -16, 58)
        f.character = W.Text(character, "", 86, -13, 562, 16, W.colors.gold)
        f.characterStats = W.Text(character, "", 86, -39, 562, 12, W.colors.muted)
        f.characterSource = W.Text(character, "", 86, -65, 562, 10, W.colors.muted)
        W.Button(character, "Character sheet", 660, -13, 202, UI.CharacterSheet, false, 30)
        f.stats = W.Button(character, "Capture my character", 660, -52, 202, nil, false, 30)
        f.scroll = W.Scroll(f, 22, -174, 876, 470)
        local content = f.scroll.content
        f.title = W.Text(content, "", 0, 0, 840, 19, W.colors.gold)
        f.rank = W.Text(content, "", 0, -29, 840, 12, W.colors.muted)
        f.overrideHint = W.Text(
            content,
            "Temporary changes below affect this skill only. Your character sheet is kept.",
            0,
            -53,
            840,
            11,
            W.colors.teal
        )
        f.fields, f.labels, f.choiceButtons, f.toggles = {}, {}, {}, {}
        f.overrides, f.choiceOptions = {}, {}
        f.cards = {}
        for i, title in ipairs({
            "Non-critical total",
            "If every eligible effect crits",
            "Expected total",
        }) do
            local p = W.Panel(content, (i - 1) * 286, 0, 270, 90, { 0.047, 0.066, 0.083 })
            W.Text(p, title, 12, -12, 246, 11, W.colors.muted)
            f.cards[i] = {
                panel = p,
                value = W.Text(p, "—", 12, -33, 246, 26, W.colors.gold),
                detail = W.Text(p, "", 12, -67, 246, 10, W.colors.muted),
            }
        end
        f.compare = W.Text(content, "", 0, 0, 846, 13, W.colors.teal)
        f.status = W.Text(content, "", 0, 0, 846, 11, W.colors.gold)
        f.advancedButton = W.Button(content, "Advanced", 0, 0, 176, function()
            f.advanced = not f.advanced
            f.update()
        end)
        f.how = W.Button(content, "Calculation & sources", 188, 0, 232, function()
            UI.SimulationHelp(f.result)
        end)
        f.reset = W.Button(content, "Reset skill overrides", 432, 0, 232, function()
            f.overrides = {}
            f.update()
            f.populate()
        end)
        f.share = W.Button(content, "Copy / paste", 676, 0, 170, function()
            local profile = FT.Snapshot.Stats(
                f.state,
                S.ExportView(),
                f.skill.name,
                "Temporary simulator inputs; character sheet is separate."
            )
            UI.SimulationInputsDialog(
                f.skill,
                f.selectedRank,
                FT.Snapshot.EncodeStats(profile),
                f.overrides
            )
        end)
        f.advancedPanel = W.Panel(content, 0, 0, 846, 30)
        f.manual = W.Button(content, "Use manual amounts", 0, 0, 270, function()
            f.overrides.manual = not f.state.manual
            if f.overrides.manual then
                f.overrides.baseMin = f.parsed and f.parsed.min or 0
                f.overrides.baseMax = f.parsed and f.parsed.max or 0
                f.overrides.periodicBase = f.parsed and f.parsed.periodic or 0
            end
            f.update()
            f.populate()
        end)
        f.notes = W.Text(content, "", 0, 0, 846, 12, W.colors.muted)
        f.populate = function()
            f.updating = true
            for key, e in pairs(f.fields) do
                local value = f.state and f.state[key]
                e:SetText(value ~= nil and tostring(value) or "")
                e.clear:Hide()
            end
            f.updating = false
        end
        local function create(spec)
            f.choiceOptions[spec.key] = spec.choices
            local key = spec.key
            if spec.type == "boolean" or spec.type == "choice" then
                if not f.choiceButtons[key] then
                    f.choiceButtons[key] = W.Button(content, spec.label, 0, 0, 270, function()
                        if spec.type == "boolean" then
                            f.overrides[key] = not f.state[key]
                        else
                            local list, pos = choices(key, f.choiceOptions[key]), 1
                            for i, choice in ipairs(list) do
                                if choice.key == f.state[key] then
                                    pos = i
                                end
                            end
                            f.overrides[key] = list[pos % #list + 1].key
                        end
                        f.update()
                    end)
                    f.toggles[key] = f.choiceButtons[key]
                end
                local b = f.choiceButtons[key]
                b.tip = spec.help
                b:SetActive(f.state[key] == true)
                if spec.type == "choice" then
                    local value = f.state[key]
                    for _, choice in ipairs(choices(key, spec.choices)) do
                        if choice.key == value then
                            value = choice.name
                        end
                    end
                    b:SetText(spec.label .. ": " .. (value or "Choose"))
                end
                return b
            end
            if not f.fields[key] then
                f.labels[key] = W.Text(content, spec.label, 0, 0, 270, 11, W.colors.muted)
                local e = W.Edit(content, "Automatic", 0, 0, 270, function(text, user)
                    if user and not f.updating then
                        if text ~= "" and not tonumber(text) then
                            return
                        end
                        f.overrides[key] = text ~= "" and tonumber(text) or nil
                        f.update()
                    end
                end, 12)
                e.clear:Hide()
                e.hideClear = true
                e:HookScript("OnEnter", function(self)
                    W.Tooltip(self, spec.label, { self.tip })
                end)
                e:HookScript("OnLeave", function()
                    GameTooltip:Hide()
                end)
                f.fields[key] = e
            end
            f.fields[key].tip = spec.help .. " This is a temporary override."
            return f.fields[key]
        end
        f.update = function()
            f.parsed = Sim.Parse(f.selectedRank, f.skill, S.View().level)
            local result, why = Sim.Run(S.View(), f.skill, f.selectedRank, f.overrides)
            f.result = result
            f.statsNote = result and result.statsNote
            local state, character = FT.Character.ForSkill(
                S.View(),
                f.skill,
                f.selectedRank,
                nil,
                nil,
                f.overrides.effectMode
            )
            for key, value in pairs(f.overrides) do
                state[key] = value
            end
            f.state = result and result.state or Sim.State(state)
            f.portrait:SetTexture(
                "Interface\\AddOns\\ForeverTalents\\Media\\Icons\\"
                    .. FT.Model.Class(S.View().classID).icon
                    .. ".tga"
            )
            f.character:SetText(
                character.sheet.name
                    .. " • "
                    .. FT.Data.races[S.View().raceID].name
                    .. " "
                    .. FT.Model.Class(S.View().classID).name
                    .. " • level "
                    .. S.View().level
            )
            f.characterStats:SetText(
                "Power "
                    .. fmt(character.totals.power)
                    .. " • Healing "
                    .. fmt(character.totals.healing)
                    .. " • Melee AP "
                    .. fmt(character.totals.attackPower)
                    .. " • Ranged AP "
                    .. fmt(character.totals.rangedAP)
            )
            f.characterSource:SetText(
                character.source .. " • Edit the central sheet to keep changes for every skill."
            )
            local specs = result and result.inputs
                or Sim.Inputs(S.View(), f.skill, f.selectedRank, f.state, f.parsed)
            for key, e in pairs(f.fields) do
                e:Hide()
                f.labels[key]:Hide()
            end
            for _, b in pairs(f.choiceButtons) do
                b:Hide()
            end
            local y = -86
            local function group(name)
                local count = 0
                for _, spec in ipairs(specs) do
                    if spec.group == name then
                        local control = create(spec)
                        local col, row = count % 3, math.floor(count / 3)
                        local height = name == "condition" and 40 or 64
                        local top = y - row * height
                        control:ClearAllPoints()
                        control:SetPoint(
                            "TOPLEFT",
                            col * 286,
                            top - (spec.type == "number" and 20 or 0)
                        )
                        control:Show()
                        if spec.type == "number" then
                            if not control:HasFocus() or f.overrides[spec.key] == nil then
                                f.updating = true
                                control:SetText(
                                    f.state[spec.key] ~= nil and tostring(f.state[spec.key]) or ""
                                )
                                f.updating = false
                            end
                            local label = f.labels[spec.key]
                            label:ClearAllPoints()
                            label:SetPoint("TOPLEFT", col * 286, top)
                            label:Show()
                        end
                        count = count + 1
                    end
                end
                if count > 0 then
                    y = y - math.ceil(count / 3) * (name == "condition" and 40 or 64) - 10
                end
            end
            group("character")
            group("target")
            group("condition")
            for _, card in ipairs(f.cards) do
                card.panel:ClearAllPoints()
                card.panel:SetPoint("TOPLEFT", (_ - 1) * 286, y)
            end
            if result then
                f.cards[1].value:SetText(range(result.normalMin, result.normalMax))
                f.cards[2].value:SetText(
                    result.critEligible and range(result.criticalMin, result.criticalMax)
                        or "Cannot crit"
                )
                f.cards[3].value:SetText(fmt(result.expected))
                f.cards[1].detail:SetText(
                    (result.parsed.displayKind or result.parsed.kind)
                        .. " • one target, full duration"
                )
                f.cards[2].detail:SetText("Each eligible tick/hit crits; an upper scenario")
                f.cards[3].detail:SetText(
                    fmt(result.crit) .. "% crit • " .. fmt(result.hit) .. "% lands"
                )
                local baseline = Sim.Run(S.View(), f.skill, f.selectedRank, f.overrides, false)
                f.compare:SetText(
                    "Without selected talents "
                        .. fmt(baseline.expected)
                        .. " → this build "
                        .. fmt(result.expected)
                        .. (
                            baseline.expected > 0
                                and string.format(
                                    " (%+.1f%%)",
                                    (result.expected / baseline.expected - 1) * 100
                                )
                            or ""
                        )
                )
                f.status:SetText(result.confidence .. " • " .. result.source)
            else
                for _, card in ipairs(f.cards) do
                    card.value:SetText("—")
                    card.detail:SetText("No supported numeric model")
                end
                f.compare:SetText(
                    why or "Choose a supported skill, or supply manual amounts in Advanced."
                )
                f.status:SetText("Utility or unsupported effect • your character sheet is kept")
            end
            y = y - 108
            f.compare:ClearAllPoints()
            f.compare:SetPoint("TOPLEFT", 0, y)
            y = y - math.max(28, f.compare:GetStringHeight() + 8)
            f.status:ClearAllPoints()
            f.status:SetPoint("TOPLEFT", 0, y)
            y = y - 36
            for _, b in ipairs({ f.advancedButton, f.how, f.reset, f.share }) do
                local x = b == f.advancedButton and 0
                    or b == f.how and 188
                    or b == f.reset and 432
                    or 676
                b:ClearAllPoints()
                b:SetPoint("TOPLEFT", x, y)
            end
            f.advancedButton:SetActive(f.advanced == true)
            y = y - 46
            f.advancedPanel:SetShown(f.advanced == true)
            f.manual:SetShown(f.advanced == true)
            if f.advanced then
                f.advancedPanel:ClearAllPoints()
                f.advancedPanel:SetPoint("TOPLEFT", 0, y)
                f.advancedPanel:SetHeight(34)
                f.manual:ClearAllPoints()
                f.manual:SetPoint("TOPLEFT", 10, y - 3)
                f.manual:SetActive(f.state.manual)
                y = y - 50
                group("advanced")
            end
            local text = result
                    and ("Included talents: " .. (table.concat(result.modifiers.included, ", ") ~= "" and table.concat(
                        result.modifiers.included,
                        ", "
                    ) or "None affect this modeled amount.") .. "\nIncluded racials: " .. (table.concat(
                        result.racials,
                        ", "
                    ) ~= "" and table.concat(result.racials, ", ") or "None apply to this use.") .. (#result.modifiers.omitted > 0 and "\nOther interactions: " .. table.concat(
                        result.modifiers.omitted,
                        ", "
                    ) or "") .. "\n\n" .. table.concat(result.warnings, "\n") .. "\n\n" .. result.limits)
                or why
                or ""
            f.notes:SetText(text)
            f.notes:ClearAllPoints()
            f.notes:SetPoint("TOPLEFT", 0, y)
            f.scroll:SetContentHeight(-y + f.notes:GetStringHeight() + 20)
        end
        f.stats:SetScript("OnClick", function()
            local profile = FT.ReadPlayerStats()
            local gear = FT.ReadPlayerEquipment and FT.ReadPlayerEquipment() or {}
            local ok, why = FT.Character.Save(S.View(), FT.Character.FromSnapshot(profile, gear))
            if not ok then
                UI.Status(why)
                return
            end
            f.overrides = {}
            f.update()
            f.populate()
        end)
    end
    f.skill, f.selectedRank, f.classID = skill, rank, S.Build().classID
    f.overrides, f.state = FT.Copy(overrides or {}), Sim.Defaults()
    f.title:SetText(skill.name)
    f.rank:SetText(
        (rank.label or "Ability")
            .. (rank.talentGranted and " • granted by talent from level " or " • learned at level ")
            .. (rank.level or 1)
            .. " • displayed build • one use"
    )
    f.update()
    f.populate()
    f.scroll:ScrollTo(0)
end
function UI.SimulationHelp(result)
    local f, first = UI.Dialog("simulationHelp", "Simulator • calculation & evidence", 880, 626)
    if first then
        f.scroll = W.Scroll(f, 22, -64, 836, 536)
        f.text = W.Text(f.scroll.content, "", 0, 0, 808, 13)
    end
    local lines = {
        "Expected total averages random critical effects and unsuccessful casts. It is not a guaranteed hit or rotation DPS.",
        "\nFor each effect: (base + power × coefficient + AP × ratio + weapon + resource) × bonuses × damage remaining.",
        "Expected effect = mean non-critical total × (1 + crit chance × (crit multiplier − 1)) × chance to land.",
        "Periodic coefficients are stored per tick; a manual periodic override is a total coefficient across all ticks. Eligible ticks roll critical effects independently. Shields do not crit.",
    }
    if result then
        lines[#lines + 1] = "\n" .. result.confidence .. " • " .. result.source
        for _, b in ipairs(result.breakdown) do
            lines[#lines + 1] = "\n" .. b.label .. " • spell " .. (b.sourceSpell or 0)
            lines[#lines + 1] = b.formula
            lines[#lines + 1] = b.averageFormula
            lines[#lines + 1] = "Power scaling "
                .. fmt(b.coefficient * 100)
                .. "% • AP scaling "
                .. fmt((b.apCoefficient or 0) * 100)
                .. "%"
                .. (b.part == "periodic" and " per tick" or " direct")
            if b.part == "periodic" then
                lines[#lines + 1] = b.ticks
                    .. " ticks"
                    .. (
                        b.interval > 0 and " every " .. b.interval .. " seconds"
                        or " • timing unknown"
                    )
            end
            lines[#lines + 1] = b.critEligible
                    and (fmt(b.crit) .. "% crit • multiplier " .. fmt(b.critMultiplier))
                or "This effect cannot crit."
        end
        for _, e in ipairs(result.modifiers.evidence) do
            lines[#lines + 1] = "\n" .. e.name .. " rank " .. e.rank .. ": " .. e.text
        end
        lines[#lines + 1] = "\n" .. table.concat(result.warnings, "\n")
        lines[#lines + 1] = "\n" .. result.limits
        for _, source in ipairs(result.sources) do
            lines[#lines + 1] = "\n" .. source.label .. "\n" .. source.url
        end
    else
        lines[#lines + 1] =
            "\nChoose a skill to see its numeric substitutions, included talents, sources and missing mechanics."
    end
    f.text:SetText(table.concat(lines, "\n"))
    f.scroll:SetContentHeight(f.text:GetStringHeight() + 16)
    f.scroll:ScrollTo(0)
end

function UI.SimulationInputsDialog(skill, rank, code, previous)
    local f, first =
        UI.Dialog("simulationInputs", "Simulator • copy / paste temporary inputs", 860, 514)
    if first then
        f.info = W.Text(f, "", 22, -64, 816, 13, W.colors.muted)
        f.scroll = W.Scroll(f, 22, -120, 816, 210)
        f.output = W.Edit(f.scroll.content, "FS1 / FS2:…", 0, 0, 790, nil, 65536)
        f.output:SetHeight(210)
        f.output:SetMultiLine(true)
        f.output:SetTextInsets(12, 28, 10, 10)
        f.summary = W.Text(f, "", 22, -350, 816, 12, W.colors.teal)
        f.load = W.Button(f, "Use temporary inputs", 22, -444, 390, function()
            local inputs, why = Sim.ImportInputs(S.View(), f.skill, f.rank, f.output:GetText())
            if inputs then
                UI.SimulationDialog(f.skill, f.rank, inputs)
            else
                f.summary:SetText(why)
            end
        end, true, 32)
        W.Button(f, "Back to simulator", 428, -444, 410, function()
            UI.SimulationDialog(f.skill, f.rank, f.previous)
        end, false, 32)
        f.output:SetScript("OnTextChanged", function()
            f.scroll:SetContentHeight(math.max(210, f.output:GetNumLines() * 16 + 24))
            local inputs, why = Sim.ImportInputs(S.View(), f.skill, f.rank, f.output:GetText())
            f.load:SetEnabled(inputs ~= nil)
            f.summary:SetText(
                inputs
                        and "Ready • Ctrl+C copies the entire selected string. Pasted inputs affect this skill only."
                    or why
                    or "Paste a stats string."
            )
        end)
    end
    f.skill, f.rank, f.previous = skill, rank, FT.Copy(previous or {})
    f.info:SetText(
        "Copy these inputs or paste an FS1 / FS2 stats string for "
            .. skill.name
            .. ".\nThe central character sheet, equipment and talent build stay unchanged."
    )
    f.output:SetText(code or "")
    f.output:SetFocus()
    f.output:HighlightText()
    f.scroll:ScrollTo(0)
end
