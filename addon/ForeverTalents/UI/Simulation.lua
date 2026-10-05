local _, FT = ...
local UI, W, S, Sim = FT.UI, FT.UI.W, FT.Store, FT.Simulation
local function rounded(n)
    return string.format("%.0f", n or 0)
end

function UI.SimulationDialog(skill, rank)
    local f, first = UI.Dialog("simulation", "What if? • one skill use", 900, 582)
    if first then
        f.title = W.Text(f, "", 22, -65, 636, 18, W.colors.gold)
        f.rank = W.Text(f, "", 22, -94, 856, 12, W.colors.muted)
        f.fields = {}
        f.state = Sim.Defaults()
        local function field(parent, key, label, x, y, width, tip)
            W.Text(parent, label, x, y, width, 11, W.colors.muted)
            local e = W.Edit(parent, "0", x, y - 21, width, function(text, user)
                if user and not f.updating then
                    S.db.settings.statsProfile = nil
                    f.state[key] = tonumber(text) or 0
                    if key == "crit" then
                        f.statsNote = nil
                    end
                    f.update()
                end
            end, 8)
            e:SetTextInsets(10, 10, 0, 0)
            e.clear:Hide()
            e.tip = tip
            e:HookScript("OnEnter", function(self)
                W.Tooltip(self, label, { tip })
            end)
            e:HookScript("OnLeave", function()
                GameTooltip:Hide()
            end)
            f.fields[key] = e
            return e
        end
        field(
            f,
            "power",
            "Bonus spell / healing power",
            22,
            -132,
            258,
            "Bonus power from gear and buffs. The coefficient determines how much this skill uses. For weapon skills, use the Advanced weapon and Attack Power fields."
        )
        field(
            f,
            "crit",
            "Base critical chance (%)",
            300,
            -132,
            176,
            "Chance before the modeled talent bonuses listed below. A 20% chance means one critical hit in five on average. Use my stats subtracts recognized general/school crit bonuses from your learned talents when readable. Periodic damage is treated as unable to crit."
        )
        field(
            f,
            "reduction",
            "Damage stopped (%)",
            496,
            -132,
            176,
            "An assumed total reduction from armor or resistances. 20 stops one fifth of damage. This does not reduce healing."
        )
        f.stats = W.Button(f, "Use my stats", 690, -153, 188, nil, false, 30)
        f.stats.tip =
            "Copy the logged-in character's reported power, attack power and weapon range. Recognized passive general/school crit bonuses are removed before your planned talent bonuses are added. Other reported values can include buffs: edit values to avoid including a bonus twice."
        f.toggles = {}
        for i, spec in ipairs({
            { "bleeding", "Target is bleeding" },
            { "frozen", "Target is frozen" },
            { "cooldowns", "Include active cooldowns" },
        }) do
            local key = spec[1]
            local b = W.Button(f, spec[2], 22 + (i - 1) * 286, -208, 270, function(self)
                f.state[key] = not f.state[key]
                self:SetActive(f.state[key])
                f.update()
            end)
            b.tip = key == "cooldowns"
                    and "Include simple learned cooldown bonuses such as Death Wish. Proc uptime and rotations remain outside this estimate."
                or "A hypothetical target state. Relevant simple talent bonuses are included only when this state is on."
            f.toggles[key] = b
        end
        f.cards = {}
        for i, title in ipairs({ "Normal use", "Critical use", "Expected average" }) do
            local p = W.Panel(f, 22 + (i - 1) * 286, -254, 270, 92, { 0.047, 0.066, 0.083 })
            W.Text(p, title, 14, -12, 242, 12, W.colors.muted)
            local value =
                W.Text(p, "—", 14, -36, 242, 25, i == 3 and W.colors.gold or W.colors.text)
            local detail = W.Text(p, "", 14, -69, 242, 10, W.colors.muted)
            f.cards[i] = { value = value, detail = detail }
        end
        f.compare = W.Text(f, "", 22, -366, 856, 14, W.colors.teal)
        f.advancedButton = W.Button(f, "Advanced  v", 22, -408, 176, function()
            f.advanced = not f.advanced
            f.advancedPanel:SetShown(f.advanced)
            f:SetHeight(f.advanced and 806 or 582)
            f.advancedButton:SetActive(f.advanced)
            f.advancedButton:SetText(f.advanced and "Advanced  ^" or "Advanced  v")
        end)
        W.Button(f, "How this works", 210, -408, 180, function()
            UI.SimulationHelp()
        end)
        f.notesScroll = W.Scroll(f, 22, -451, 856, 108)
        f.notes = W.Text(f.notesScroll.content, "", 0, 0, 824, 12, W.colors.muted)
        local function notes(text)
            f.notes:SetText(text)
            f.notesScroll:SetContentHeight(f.notes:GetStringHeight() + 4)
        end
        local advanced = W.Panel(f, 22, -578, 856, 204, { 0.047, 0.066, 0.083 })
        f.advancedPanel = advanced
        field(
            advanced,
            "attackPower",
            "Attack Power",
            12,
            -14,
            148,
            "Used for skills that explicitly scale from Attack Power, such as Bloodthirst. Weapon hit values already include their normal AP contribution."
        )
        field(
            advanced,
            "weaponMin",
            "Weapon hit • low",
            180,
            -14,
            148,
            "Normal weapon hit range including its usual Attack Power bonus. Weapon-based skills add their captured flat bonus to this range."
        )
        field(
            advanced,
            "weaponMax",
            "Weapon hit • high",
            348,
            -14,
            148,
            "Upper end of a normal weapon hit. Include AP in this value; no extra AP / 14 is added to weapon damage."
        )
        field(
            advanced,
            "coefficient",
            "Direct scaling (%)",
            516,
            -14,
            156,
            "Percent of bonus power used by the direct effect. 57 means 100 bonus power adds 57 damage or healing. Defaults come from an older Forever datamine, a cast-time approximation, or zero when unknown."
        )
        field(
            advanced,
            "dotCoefficient",
            "Over-time scaling (%)",
            692,
            -14,
            152,
            "Total bonus-power coefficient for the entire periodic effect, not per tick. Unknown periodic scaling defaults to zero. Enter a known total to include it."
        )
        field(
            advanced,
            "hit",
            "Chance to land (%)",
            12,
            -84,
            148,
            "A manual combined chance to land a damaging skill. It changes expected average, not the hit range. Healing always lands in this model."
        )
        field(
            advanced,
            "extra",
            "Other bonus (%)",
            180,
            -84,
            148,
            "A separate damage or healing multiplier for effects outside the modeled talent set. Do not include bonuses already listed as included."
        )
        field(
            advanced,
            "baseMin",
            "Manual base • low",
            348,
            -84,
            148,
            "A base damage or healing range you supply. Enable Manual base to replace the captured tooltip amount; periodic components are then omitted."
        )
        field(
            advanced,
            "baseMax",
            "Manual base • high",
            516,
            -84,
            156,
            "Upper end of your base range before power, talents, crit and reductions. Use the same value twice for a fixed amount."
        )
        f.manual = W.Button(advanced, "Manual base", 692, -105, 152, function(self)
            f.state.manual = not f.state.manual
            self:SetActive(f.state.manual)
            f.update()
        end)
        W.Text(
            advanced,
            "Hover any field for a plain-language explanation. Scaling and manual values can be reset below.",
            12,
            -154,
            832,
            11,
            W.colors.muted
        )
        W.Button(advanced, "Reset assumptions", 12, -174, 832, function()
            f.statsNote = nil
            f.state = Sim.Defaults()
            f.state.baseMin = f.parsed and f.parsed.min or 0
            f.state.baseMax = f.parsed and f.parsed.max or 0
            f.populate()
            f.update()
        end, false, 22)
        f.populate = function()
            f.updating = true
            local auto = f.parsed and select(1, Sim.Coefficient(f.selectedRank, f.parsed)) or 0
            for key, e in pairs(f.fields) do
                e:SetText(tostring(f.state[key] or (key == "coefficient" and auto * 100 or 0)))
                e.clear:Hide()
            end
            for key, b in pairs(f.toggles) do
                b:SetActive(f.state[key])
            end
            f.manual:SetActive(f.state.manual)
            f.updating = false
        end
        f.update = function()
            S.db.settings.scenario = Sim.State(f.state)
            S.db.settings.scenarioSkill = f.skill.name
            local result, why = Sim.Calculate(S.View(), f.skill, f.selectedRank, f.state)
            if not result then
                for _, c in ipairs(f.cards) do
                    c.value:SetText("—")
                    c.detail:SetText("No numeric estimate")
                end
                f.compare:SetText(
                    "Utility or complex skill • choose a damage/healing skill, or enter a manual base."
                )
                notes(
                    why
                        .. "\n\nThis panel models one skill use, with the build currently shown. It does not simulate a rotation."
                )
                return
            end
            local baseline = Sim.Calculate(S.View(), f.skill, f.selectedRank, f.state, false)
            local function range(a, b)
                return rounded(a) .. (math.abs(a - b) > 0.5 and " – " .. rounded(b) or "")
            end
            f.cards[1].value:SetText(
                range(result.min + result.periodic, result.max + result.periodic)
            )
            f.cards[2].value:SetText(
                range(result.critMin + result.periodic, result.critMax + result.periodic)
            )
            f.cards[3].value:SetText(rounded(result.expected))
            f.cards[1].detail:SetText(
                result.parsed.kind
                    .. (
                        result.periodic > 0 and " • includes full periodic effect"
                        or " • direct effect"
                    )
            )
            f.cards[2].detail:SetText("Direct part crits • periodic part does not")
            f.cards[3].detail:SetText(
                string.format("%.1f%% crit • %.1f%% lands", result.crit, result.hit)
            )
            local delta = baseline.expected > 0 and (result.expected / baseline.expected - 1) * 100
                or 0
            f.compare:SetText(
                "Without selected talents: "
                    .. rounded(baseline.expected)
                    .. "  →  This build: "
                    .. rounded(result.expected)
                    .. string.format("  (%+.1f%%)", delta)
            )
            local included = table.concat(result.modifiers.included, ", ")
            local omitted = table.concat(result.modifiers.omitted, ", ")
            notes(
                "Estimate • "
                    .. result.source
                    .. (result.parsed.descriptionSource == "client" and " Base amount supplied by your client; absent from the snapshot." or "")
                    .. "\nIncluded talents: "
                    .. (included ~= "" and included or "No simple numeric modifier applies.")
                    .. "\nOther interactions omitted: "
                    .. (omitted ~= "" and omitted or "None identified in this build.")
                    .. (result.periodic > 0 and "\nPeriodic total: " .. rounded(result.periodic) .. " over " .. result.duration .. " sec; unknown scaling defaults to zero." or "")
                    .. (f.statsNote and "\n" .. f.statsNote or "")
                    .. "\nProcs, forms, intrinsic conditional effects, haste, resource limits, target debuffs and rotations are omitted."
            )
        end
        f.stats:SetScript("OnClick", function()
            local profile = FT.ReadPlayerStats(f.skill, f.selectedRank)
            S.db.settings.statsProfile = profile
            f.state, f.statsNote = FT.Snapshot.ForSkill(profile, f.skill, f.selectedRank, S.View())
            f.populate()
            f.update()
        end)
        W.Button(f, "Copy / paste stats", 404, -408, 212, UI.CharacterDialog)
    end
    f.skill, f.selectedRank, f.parsed = skill, rank, Sim.Parse(rank, skill)
    f.classID = S.Build().classID
    f.statsNote = nil
    f.state = Sim.State(S.db.settings.scenario)
    f.state, f.statsNote =
        FT.Snapshot.ForSkill(FT.Snapshot.Current(S.View()), skill, rank, S.View())
    -- Reset spell-specific overrides; retain character stats and target conditions.
    if not S.db.settings.statsProfile or S.db.settings.statsProfile.skillName ~= skill.name then
        f.state.coefficient, f.state.dotCoefficient, f.state.manual = nil, nil, false
    end
    f.state.baseMin = f.parsed and f.parsed.min or 0
    f.state.baseMax = f.parsed and f.parsed.max or 0
    f.title:SetText(skill.name)
    f.rank:SetText(
        (rank.label ~= "" and rank.label .. " • " or "")
            .. "Learned at level "
            .. rank.level
            .. " • evaluating the currently shown build"
    )
    f.advancedPanel:SetShown(f.advanced == true)
    f:SetHeight(f.advanced and 806 or 582)
    f.populate()
    f.update()
end

function UI.SimulationHelp()
    local f, first = UI.Dialog("simulationHelp", "Understand the estimate", 860, 604)
    if first then
        W.Text(f, "Start with three easy inputs", 22, -67, 816, 16, W.colors.gold)
        W.Text(
            f,
            "Bonus power is the number from your gear. Crit chance changes the average result.\nDamage stopped represents armor or resistance as a single percentage. Use my stats fills\nvalues from your current character; values stay editable when planning another character.",
            22,
            -100,
            816,
            13
        )
        W.Text(
            f,
            "The calculation is visible and deliberately small",
            22,
            -176,
            816,
            16,
            W.colors.gold
        )
        W.Text(
            f,
            "Normal effect = (captured base + bonus power × scaling + weapon / AP contribution)\n                        × simple talent bonuses × other bonus × damage remaining\nCritical effect = direct effect × crit multiplier + periodic total\nExpected average = (average direct effect including crits + periodic total) × chance to land\nSelected talent bonuses are summed within each modeled category. Other bonus multiplies separately.",
            22,
            -209,
            816,
            13
        )
        W.Text(f, "Scaling explained", 22, -310, 816, 16, W.colors.gold)
        W.Text(
            f,
            "57% direct scaling uses 57 of each 100 bonus power. Over-time scaling means the entire\nperiodic effect, not one tick. A small set of spells uses older Forever client observations.\nOther casts can use cast time / 3.5 sec as an approximation; unknown scaling uses zero.\nAdvanced lets you replace coefficients and the base range when you have better numbers.",
            22,
            -343,
            816,
            13
        )
        W.Text(f, "Read the Included and Omitted lines", 22, -437, 816, 16, W.colors.gold)
        W.Text(
            f,
            "Only simple, applicable damage/healing/crit modifiers are automatically modeled. Bleeding,\nfrozen and active-cooldown toggles enable the supported conditional bonuses. Proc chances,\nstacks, multi-hit targeting, resource limits, racial passives and rotations are omitted.\nThe tooltip snapshot can contain beta placeholders; a numeric estimate is a planning aid.",
            22,
            -470,
            816,
            13
        )
        W.Button(f, "Back to the skill", 22, -554, 816, function()
            local sim = UI.dialogs.simulation
            if sim then
                UI.SimulationDialog(sim.skill, sim.selectedRank)
            end
        end, true, 28)
    end
end
