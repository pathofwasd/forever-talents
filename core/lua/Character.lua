local _, FT = ...
local C, M, Sim = {}, FT.Model, FT.Simulation
FT.Character = C
C.slots = {
    { key = "head", name = "Head", id = 1 },
    { key = "neck", name = "Neck", id = 2 },
    { key = "shoulder", name = "Shoulders", id = 3 },
    { key = "back", name = "Back", id = 15 },
    { key = "chest", name = "Chest", id = 5 },
    { key = "wrist", name = "Wrists", id = 9 },
    { key = "hands", name = "Hands", id = 10 },
    { key = "waist", name = "Waist", id = 6 },
    { key = "legs", name = "Legs", id = 7 },
    { key = "feet", name = "Feet", id = 8 },
    { key = "finger1", name = "Ring 1", id = 11 },
    { key = "finger2", name = "Ring 2", id = 12 },
    { key = "trinket1", name = "Trinket 1", id = 13 },
    { key = "trinket2", name = "Trinket 2", id = 14 },
    { key = "mainHand", name = "Main hand", id = 16 },
    { key = "offHand", name = "Off hand", id = 17 },
    { key = "ranged", name = "Ranged", id = 18 },
}
C.weaponTypes = {
    { key = "none", name = "Unspecified" },
    { key = "dagger", name = "Dagger" },
    { key = "sword", name = "One-hand sword" },
    { key = "axe", name = "One-hand axe" },
    { key = "mace", name = "One-hand mace" },
    { key = "fist", name = "Fist weapon" },
    { key = "twoSword", name = "Two-hand sword" },
    { key = "twoAxe", name = "Two-hand axe" },
    { key = "twoMace", name = "Two-hand mace" },
    { key = "staff", name = "Staff" },
    { key = "polearm", name = "Polearm" },
    { key = "bow", name = "Bow" },
    { key = "gun", name = "Gun" },
    { key = "crossbow", name = "Crossbow" },
}
C.fields = {
    { key = "strength", label = "Strength", group = "Attributes" },
    { key = "agility", label = "Agility", group = "Attributes" },
    { key = "stamina", label = "Stamina", group = "Attributes" },
    { key = "intellect", label = "Intellect", group = "Attributes" },
    { key = "spirit", label = "Spirit", group = "Attributes" },
    { key = "power", label = "Spell power", group = "Combat" },
    { key = "healing", label = "Healing power", group = "Combat" },
    { key = "damagePower", label = "Damage-only bonus", group = "Combat" },
    { key = "attackPower", label = "Melee AP", group = "Combat" },
    { key = "rangedAP", label = "Ranged AP", group = "Combat" },
    { key = "meleeCrit", label = "Melee / ranged crit (%)", group = "Combat", max = 100 },
    { key = "spellCrit", label = "Spell / healing crit (%)", group = "Combat", max = 100 },
    { key = "hit", label = "Chance to land (%)", group = "Combat", max = 100 },
    { key = "health", label = "Health", group = "Resources" },
    { key = "mana", label = "Mana", group = "Resources" },
    { key = "armor", label = "Armor", group = "Resources" },
    { key = "weaponMin", label = "Melee hit · low", group = "Weapons" },
    { key = "weaponMax", label = "Melee hit · high", group = "Weapons" },
    { key = "rangedMin", label = "Ranged hit · low", group = "Weapons" },
    { key = "rangedMax", label = "Ranged hit · high", group = "Weapons" },
    { key = "weaponSpeed", label = "Weapon speed (sec)", group = "Weapons", max = 10 },
    { key = "rangedSpeed", label = "Ranged speed (sec)", group = "Weapons", max = 10 },
}
local attributes = { "strength", "agility", "stamina", "intellect", "spirit" }
local function number(v, max, fallback)
    return Sim.Bounded(v, 0, max or 100000, fallback or 0)
end
function C.WeaponType(value)
    for _, t in ipairs(C.weaponTypes) do
        if value == t.key then
            return value
        end
    end
    return "none"
end
function C.New()
    return {
        schema = 1,
        mode = "gear",
        name = "My character",
        stats = {},
        gear = {},
        plans = {},
        form = "caster",
        weaponType = "none",
    }
end
function C.Normalize(raw, strict)
    if type(raw) ~= "table" or (raw.schema and raw.schema ~= 1) then
        return nil, "Invalid character sheet."
    end
    local c = C.New()
    if
        raw.mode ~= nil
        and raw.mode ~= "gear"
        and raw.mode ~= "manual"
        and raw.mode ~= "captured"
    then
        return nil, "Unknown character mode."
    end
    c.mode = raw.mode or "gear"
    c.name = FT.SafeText(raw.name, 48)
    if c.name == "" then
        c.name = "My character"
    end
    c.form = raw.form == "cat" and "cat" or raw.form == "bear" and "bear" or "caster"
    c.weaponType = C.WeaponType(raw.weaponType)
    if
        strict
        and (
            (raw.form and c.form ~= raw.form) or (raw.weaponType and c.weaponType ~= raw.weaponType)
        )
    then
        return nil, "Invalid character form or weapon type."
    end
    local function stats(values)
        if type(values) ~= "table" then
            return nil, "Invalid character stats."
        end
        local out = {}
        for _, field in ipairs(C.fields) do
            if values[field.key] ~= nil then
                local v = values[field.key]
                if
                    strict and (type(v) ~= "number" or v ~= v or v < 0 or v > (field.max or 100000))
                then
                    return nil, "Invalid " .. field.label .. "."
                end
                out[field.key] = number(v, field.max)
            end
        end
        return out
    end
    c.plans = {}
    if raw.plans and type(raw.plans) ~= "table" then
        return nil, "Invalid character input presets."
    end
    for _, mode in ipairs({ "gear", "manual" }) do
        if raw.plans and raw.plans[mode] then
            c.plans[mode] = stats(raw.plans[mode])
            if not c.plans[mode] then
                return nil, "Invalid character input preset."
            end
        end
    end
    c.stats = stats(raw.stats or {})
    if not c.stats then
        return nil, "Invalid character stats."
    end
    if type(raw.gear or {}) ~= "table" then
        return nil, "Invalid gear slots."
    end
    for _, slot in ipairs(C.slots) do
        local item = (raw.gear or {})[slot.key]
        if item then
            if type(item) ~= "table" then
                return nil, "Invalid item in " .. slot.name .. "."
            end
            local values, err = stats(item.stats or {})
            if not values then
                return nil, err
            end
            if strict then
                for _, key in ipairs({ "low", "high", "speed", "itemID" }) do
                    local v, maximum =
                        item[key], key == "speed" and 10 or key == "itemID" and 10000000 or 100000
                    if v ~= nil and (type(v) ~= "number" or v ~= v or v < 0 or v > maximum) then
                        return nil, "Invalid item " .. key .. "."
                    end
                end
                if item.weaponType and C.WeaponType(item.weaponType) ~= item.weaponType then
                    return nil, "Invalid item weapon type."
                end
            end
            c.gear[slot.key] = {
                name = FT.SafeText(item.name, 80),
                stats = values,
                weaponType = C.WeaponType(item.weaponType),
                low = number(item.low),
                high = number(item.high),
                speed = number(item.speed, 10),
                itemID = math.floor(number(item.itemID, 10000000)),
                link = FT.SafeText(item.link, 512),
                captured = item.captured == true,
            }
            if c.gear[slot.key].high < c.gear[slot.key].low then
                return nil, "Item weapon maximum must be at least the minimum."
            end
        end
    end
    if raw.capture then
        if type(raw.capture) ~= "table" or type(raw.capture.state) ~= "table" then
            return nil, "Invalid live capture."
        end
        local capture = FT.Copy(raw.capture)
        capture.character = nil
        if
            not M.Class(capture.classID)
            or not M.RaceAllowed(capture.classID, capture.raceID)
            or type(capture.level) ~= "number"
            or capture.level % 1 ~= 0
            or capture.level < 1
            or capture.level > 60
        then
            return nil, "Invalid captured character identity."
        end
        if capture.raw ~= nil then
            if type(capture.raw) ~= "table" then
                return nil, "Invalid reported stats."
            end
            for _, key in ipairs({
                "healing",
                "rangedAP",
                "rangedMin",
                "rangedMax",
                "rangedSpeed",
                "meleeCrit",
                "rangedCrit",
            }) do
                local v = capture.raw[key]
                local maximum = key:find("Crit") and 100 or key == "rangedSpeed" and 10 or 100000
                if v ~= nil and (type(v) ~= "number" or v ~= v or v < 0 or v > maximum) then
                    return nil, "Invalid reported " .. key .. "."
                end
            end
            for _, key in ipairs({ "power", "crit" }) do
                if capture.raw[key] ~= nil and type(capture.raw[key]) ~= "table" then
                    return nil, "Invalid reported school stats."
                end
                for i, v in pairs(capture.raw[key] or {}) do
                    if
                        type(i) ~= "number"
                        or i % 1 ~= 0
                        or i < 1
                        or i > 7
                        or type(v) ~= "number"
                        or v ~= v
                        or v < 0
                        or v > (key == "crit" and 100 or 100000)
                    then
                        return nil, "Invalid reported school stats."
                    end
                end
            end
        end
        local state = Sim.State(capture.state)
        if strict then
            for key, value in pairs(capture.state) do
                if state[key] ~= nil and state[key] ~= value then
                    return nil, "Invalid captured stat: " .. key
                end
            end
        end
        capture.state = state
        capture.note = FT.SafeText(capture.note, 256)
        if capture.learnedCode then
            local learned = FT.Codec.Decode(capture.learnedCode)
            if
                not learned
                or learned.classID ~= capture.classID
                or learned.raceID ~= capture.raceID
                or learned.level ~= capture.level
            then
                return nil, "Invalid captured talents."
            end
        end
        c.capture = capture
    end
    if c.mode == "captured" and not c.capture then
        return nil, "Captured totals require their source snapshot."
    end
    return c
end

function C.Get(build)
    local settings = FT.Store.db.settings
    settings.characters = settings.characters or {}
    local c = settings.characters[build.classID]
    if not c then
        c = C.New()
        local profile = settings.statsProfile
        if profile and profile.classID == build.classID then
            c = C.FromSnapshot(profile)
        elseif
            settings.scenario and (settings.scenario.power > 0 or settings.scenario.attackPower > 0)
        then
            c.mode = "manual"
            local s = settings.scenario
            c.stats = {
                power = s.power,
                healing = s.power,
                attackPower = s.attackPower,
                meleeCrit = s.crit,
                spellCrit = s.crit,
                hit = s.hit,
                weaponMin = s.weaponMin,
                weaponMax = s.weaponMax,
            }
        end
        settings.characters[build.classID] = c
    end
    return FT.Copy(c)
end
function C.Save(build, sheet)
    if FT.Store.readOnly then
        return false, "Saving is paused to protect newer saved data."
    end
    local c, why = C.Normalize(sheet, true)
    if not c then
        return false, why
    end
    FT.Store.db.settings.characters = FT.Store.db.settings.characters or {}
    if c.capture and c.capture.classID ~= build.classID then
        return false, "Captured stats belong to another class."
    end
    if c.mode ~= "captured" then
        c.plans[c.mode] = FT.Copy(c.stats)
    end
    FT.Store.db.settings.characters[build.classID] = c
    FT.Changed()
    return true
end
function C.FromSnapshot(profile, gear)
    if profile.character then
        return C.Normalize(profile.character) or C.New()
    end
    local c = C.New()
    c.mode, c.capture = "captured", FT.Copy(profile)
    c.capture.character = nil
    c.gear = gear or {}
    local s, raw = profile.state, profile.raw or {}
    c.stats = {
        power = s.power,
        healing = raw.healing or s.power,
        attackPower = s.attackPower,
        rangedAP = raw.rangedAP or s.attackPower,
        weaponMin = s.weaponMin,
        weaponMax = s.weaponMax,
        rangedMin = raw.rangedMin or s.weaponMin,
        rangedMax = raw.rangedMax or s.weaponMax,
        rangedSpeed = raw.rangedSpeed,
        meleeCrit = raw.meleeCrit or s.crit,
        spellCrit = raw.crit and raw.crit[7] or s.crit,
        hit = s.hit,
    }
    for i = 2, 7 do
        if raw.crit and raw.crit[i] then
            c.stats.spellCrit = math.min(c.stats.spellCrit, raw.crit[i])
        end
    end
    for key, value in pairs(profile.attributes or {}) do
        c.stats[key] = value
    end
    c.weaponType = C.WeaponType(profile.weaponType or s.weaponType)
    c.form = profile.form or s.form or "caster"
    c.stats.weaponSpeed = profile.weaponSpeed or s.weaponSpeed
    c.stats.rangedSpeed = raw.rangedSpeed or s.weaponSpeed
    local reported = profile.learnedCode or (profile.attributes and next(profile.attributes))
    -- Legacy manual strings decode with empty school tables, not reported API values.
    for _, value in pairs(raw) do
        if type(value) == "number" or (type(value) == "table" and next(value)) then
            reported = true
        end
    end
    if not reported then
        c.mode, c.capture = "manual", nil
    end
    return c
end

local function passives(build, attrs, form, enabled)
    local bonuses, effects = {}, { included = {}, omitted = {} }
    for _, key in ipairs(attributes) do
        bonuses[key] = 0
    end
    if enabled ~= false then
        local counts, index = M.Counts(build), M.Index(build.classID)
        local rules = {
            ["Divine Strength"] = "strength",
            ["Divine Intellect"] = "intellect",
            ["Mental Strength"] = "intellect",
            ["Ancestral Knowledge"] = "intellect",
            ["Arcane Mind"] = "intellect",
            ["Lightning Reflexes"] = "agility",
            ["Living Spirit"] = "spirit",
            ["Demonic Embrace"] = "stamina",
            ["Toughness"] = "stamina",
            ["Sacred Duty"] = "stamina",
        }
        for id, n in pairs(counts) do
            local talent, stat = index[id], rules[index[id].name]
            local text = talent.ranks[n].text
            if stat and text:lower():find(stat, 1, true) then
                local percent = tonumber(text:match("[Ii]ncreases your.-by ([%d%.]+)%%"))
                if percent then
                    bonuses[stat] = bonuses[stat] + percent
                    effects.included[#effects.included + 1] = talent.name
                end
            elseif talent.name == "Heart of the Wild" then
                bonuses.intellect = bonuses.intellect
                    + (tonumber(text:match("Intellect by ([%d%.]+)%%")) or 0)
                if form == "cat" then
                    bonuses.strength = bonuses.strength
                        + (tonumber(text:match("Strength is increased by ([%d%.]+)%%")) or 0)
                end
                if form == "bear" then
                    bonuses.stamina = bonuses.stamina
                        + (tonumber(text:match("Stamina is increased by ([%d%.]+)%%")) or 0)
                end
                effects.included[#effects.included + 1] = talent.name
            end
        end
    end
    for _, trait in ipairs(FT.Data.racials[build.classID][build.raceID] or {}) do
        if trait.name == "The Human Spirit" then
            bonuses.spirit = bonuses.spirit + 5
            effects.included[#effects.included + 1] = trait.name
        end
    end
    for _, key in ipairs(attributes) do
        attrs[key] = math.floor((attrs[key] or 0) * (1 + bonuses[key] / 100) + 0.0000001)
    end
    effects.bonuses = bonuses
    return effects
end

local function staminaHealth(n)
    return math.min(20, n) + math.max(0, n - 20) * 10
end
local function intellectMana(n)
    return math.min(20, n) + math.max(0, n - 20) * 15
end
local function generalCrit(build, attack, enabled, form)
    if enabled == false then
        return 0
    end
    local parsed = {
        kind = "damage",
        school = attack == "spell" and "Unspecified" or "Physical",
        attack = attack,
        periodic = 0,
    }
    return Sim.Modifiers(
        build,
        { name = "Character baseline", related = {} },
        parsed,
        { form = form }
    ).crit
end

local function captured(build, sheet, inputs, withTalents)
    local source = sheet.capture
    local learned = source.learnedCode and FT.Codec.Decode(source.learnedCode)
    local totals, warnings, effects = FT.Copy(inputs), {}, { included = {}, omitted = {} }
    local view = {
        sheet = sheet,
        totals = totals,
        inputs = inputs,
        base = {},
        passives = effects,
        warnings = warnings,
        source = "Live character totals",
        level = source.level,
        adjusted = false,
    }
    warnings[#warnings + 1] =
        "Live totals already include equipment and buffs. Captured equipment is reference only; it is not added a second time."
    if source.note and source.note ~= "" then
        warnings[#warnings + 1] = source.note
    end
    if not learned then
        warnings[#warnings + 1] =
            "Source talents were unreadable. Captured totals stay unchanged; talent stat bonuses cannot be normalized reliably. Re-capture with the game's Talents window open."
        return view
    end
    if source.level ~= build.level or source.raceID ~= build.raceID then
        warnings[#warnings + 1] =
            "Live totals remain anchored to the captured race and level. Re-capture that character, or use Base + gear to preview another race or level."
    end
    local attrs = FT.Copy(inputs)
    local oldBonuses = passives(learned, FT.Copy(attrs), sheet.form).bonuses
    for _, key in ipairs(attributes) do
        attrs[key] = (inputs[key] or 0) / (1 + (oldBonuses[key] or 0) / 100)
    end
    local template = C.New()
    template.mode, template.form, template.weaponType = "manual", sheet.form, sheet.weaponType
    for _, key in ipairs(attributes) do
        template.stats[key] = attrs[key]
    end
    local raceHealth, raceMana = 1, 1
    for _, trait in ipairs(FT.Data.racials[learned.classID][learned.raceID] or {}) do
        if trait.name == "Endurance" then
            raceHealth = 1.05
        end
        if trait.name == "Expansive Mind" and trait.text:find("Mana", 1, true) then
            raceMana = 1.05
        end
    end
    template.stats.health = math.max(
        0,
        inputs.health / raceHealth - staminaHealth(inputs.stamina) + staminaHealth(attrs.stamina)
    )
    template.stats.mana = math.max(
        0,
        inputs.mana / raceMana - intellectMana(inputs.intellect) + intellectMana(attrs.intellect)
    )
    -- Only differences in recognized talent passives are applied to reported totals.
    -- The original capture is preserved so later builds never compound these deltas.
    local target = FT.Copy(build)
    target.raceID, target.level = learned.raceID, learned.level
    local old, new = C.Compute(learned, template), C.Compute(target, template, withTalents)
    view.critAttributeDelta = {
        melee = new.totals.baseMeleeCrit - old.totals.baseMeleeCrit,
        spell = new.totals.baseSpellCrit - old.totals.baseSpellCrit,
    }
    local changed = false
    for _, field in ipairs(C.fields) do
        local key = field.key
        if field.group ~= "Weapons" and key ~= "hit" then
            local delta = new.totals[key] - old.totals[key]
            totals[key] = math.max(0, inputs[key] + delta)
            changed = changed or math.abs(delta) > 0.001
        end
    end
    for _, attack in ipairs({ "melee", "spell" }) do
        local key = attack == "melee" and "meleeCrit" or "spellCrit"
        local parsed = {
            kind = "damage",
            school = attack == "melee" and "Physical" or "Unspecified",
            attack = attack,
            periodic = 0,
        }
        local reported = Sim.Modifiers(
            learned,
            { name = "Character baseline", related = {} },
            parsed,
            { form = sheet.form }
        ).statsCrit
        totals[key] = totals[key] + generalCrit(learned, attack, true, sheet.form) - reported
    end
    local meleeDelta, rangedDelta =
        totals.attackPower - inputs.attackPower, totals.rangedAP - inputs.rangedAP
    local main, ranged = sheet.gear.mainHand, sheet.gear.ranged
    if main and main.speed > 0 then
        totals.weaponMin, totals.weaponMax =
            totals.weaponMin + meleeDelta / 14 * main.speed,
            totals.weaponMax + meleeDelta / 14 * main.speed
    end
    if ranged and ranged.speed > 0 then
        totals.rangedMin, totals.rangedMax =
            totals.rangedMin + rangedDelta / 14 * ranged.speed,
            totals.rangedMax + rangedDelta / 14 * ranged.speed
    end
    view.passives, view.adjusted = new.passives, changed
    if changed then
        view.source = "Live totals + modeled passive changes"
        warnings[#warnings + 1] =
            "Recognized talent-stat differences are estimated from the original capture. Buff stacking, integer rounding and unmodeled passives can change live results; re-capture to confirm them."
    end
    return view
end

function C.Compute(build, sheet, withTalents)
    sheet = C.Normalize(sheet or C.Get(build)) or C.New()
    local base = FT.Data.simulation.character.classes[build.classID]
    local race = FT.Data.simulation.character.races[build.raceID]
    local totals, inputs, warnings = {}, {}, {}
    local level = math.max(1, math.min(60, build.level))
    for _, field in ipairs(C.fields) do
        inputs[field.key] = sheet.stats[field.key] or 0
    end
    if sheet.stats.hit == nil then
        inputs.hit = 100
    end
    if sheet.mode == "captured" then
        return captured(build, sheet, inputs, withTalents)
    end
    if sheet.mode == "gear" then
        for _, stat in ipairs(attributes) do
            totals[stat] = base[stat][level] + (race[stat] or 0)
        end
        for _, item in pairs(sheet.gear) do
            for key, value in pairs(item.stats) do
                inputs[key] = (inputs[key] or 0) + value
            end
        end
    else
        for _, stat in ipairs(attributes) do
            totals[stat] = 0
        end
    end
    for _, stat in ipairs(attributes) do
        totals[stat] = totals[stat] + inputs[stat]
    end
    local before = FT.Copy(totals)
    local effects = passives(build, totals, sheet.form, withTalents)
    local strength, agility, intellect = totals.strength, totals.agility, totals.intellect
    local apStrength = ({
        [1] = 2,
        [2] = 2,
        [3] = 1,
        [4] = 1,
        [5] = 1,
        [7] = 2,
        [8] = 1,
        [9] = 1,
        [11] = 2,
    })[build.classID]
    local apLevel = ({
        [1] = 3 * level - 20,
        [2] = 3 * level - 20,
        [3] = 2 * level - 20,
        [4] = 2 * level - 20,
        [5] = -10,
        [7] = 2 * level - 20,
        [8] = -10,
        [9] = -10,
        [11] = -20,
    })[build.classID]
    if build.classID == 11 then
        apLevel = sheet.form == "cat" and 2 * level - 20
            or sheet.form == "bear" and 3 * level - 20
            or -20
    end
    local agilityAP = (build.classID == 4 or (build.classID == 11 and sheet.form == "cat"))
            and agility
        or 0
    totals.attackPower = inputs.attackPower
        + (sheet.mode == "gear" and math.max(0, apLevel + strength * apStrength + agilityAP) or 0)
    totals.rangedAP = inputs.rangedAP
        + (sheet.mode == "gear" and inputs.attackPower or 0)
        + (
            sheet.mode == "gear"
                and math.max(
                    0,
                    (build.classID == 3 and 2 * level or level)
                        - 20
                        + agility * (build.classID == 3 and 2 or 1)
                )
            or 0
        )
    totals.power, totals.damagePower = inputs.power + inputs.damagePower, inputs.damagePower
    totals.healing = inputs.healing + (sheet.mode == "gear" and inputs.power or 0)
    totals.meleeCrit = inputs.meleeCrit
        + (sheet.mode == "gear" and base.meleeCritBase + agility * base.meleeCritPerAgi[level] or 0)
    totals.spellCrit = inputs.spellCrit
        + (
            sheet.mode == "gear"
                and base.spellCritBase + intellect * base.spellCritPerInt[level]
            or 0
        )
    totals.hit = math.min(100, inputs.hit)
    totals.health = inputs.health
        + (
            sheet.mode == "gear"
                and base.baseHealth[level] + math.min(20, totals.stamina) + math.max(
                    0,
                    totals.stamina - 20
                ) * 10
            or 0
        )
    totals.mana = inputs.mana
        + (
            sheet.mode == "gear"
                and base.baseMana[level] + math.min(20, intellect) + math.max(0, intellect - 20) * 15
            or 0
        )
    if base.baseMana[level] == 0 then
        totals.mana = 0
    end
    totals.armor = inputs.armor + (sheet.mode == "gear" and agility * 2 or 0)
    if sheet.mode == "manual" then
        local dStrength, dAgility, dIntellect =
            strength - before.strength, agility - before.agility, intellect - before.intellect
        totals.attackPower = totals.attackPower
            + dStrength * apStrength
            + (
                (build.classID == 4 or (build.classID == 11 and sheet.form == "cat"))
                    and dAgility
                or 0
            )
        totals.rangedAP = totals.rangedAP + dAgility * (build.classID == 3 and 2 or 1)
        totals.meleeCrit = totals.meleeCrit + dAgility * base.meleeCritPerAgi[level]
        totals.spellCrit = totals.spellCrit + dIntellect * base.spellCritPerInt[level]
        totals.health = totals.health
            + staminaHealth(totals.stamina)
            - staminaHealth(before.stamina)
        totals.mana = totals.mana + intellectMana(intellect) - intellectMana(before.intellect)
        totals.armor = totals.armor + dAgility * 2
    end
    for _, trait in ipairs(FT.Data.racials[build.classID][build.raceID] or {}) do
        if trait.name == "Endurance" then
            totals.health = totals.health * 1.05
            totals.hit = math.min(100, totals.hit + 1)
        end
        if trait.name == "Expansive Mind" and trait.text:find("Mana", 1, true) then
            totals.mana = totals.mana * 1.05
        end
    end
    if withTalents ~= false then
        for id, n in pairs(M.Counts(build)) do
            local talent = M.Index(build.classID)[id]
            local text, applied = talent.ranks[n].text, false
            local percent = tonumber(text:match("([%d%.]+)%% of your Intellect"))
            if talent.name == "Careful Aim" or talent.name == "Mental Dexterity" then
                totals.attackPower = totals.attackPower + intellect * (percent or 0) / 100
                if talent.name == "Careful Aim" then
                    totals.rangedAP = totals.rangedAP + intellect * (percent or 0) / 100
                end
                applied = true
            elseif talent.name == "Champion of the Light" or talent.name == "Mental Quickness" then
                totals.power = totals.power + intellect * (percent or 0) / 100
                if talent.name == "Mental Quickness" then
                    totals.healing = totals.healing + intellect * (percent or 0) / 100
                end
                applied = true
            elseif talent.name == "Spiritual Guidance" then
                totals.healing = totals.healing
                    + totals.spirit
                        * (tonumber(text:match("healing by up to ([%d%.]+)%%")) or 0)
                        / 100
                totals.power = totals.power
                    + totals.spirit
                        * (tonumber(text:match("damage by up to ([%d%.]+)%%")) or 0)
                        / 100
                applied = true
            elseif talent.name == "Predatory Strikes" and sheet.form ~= "caster" then
                totals.attackPower = totals.attackPower
                    + level * (tonumber(text:match("([%d%.]+)%% of your level")) or 0) / 100
                applied = true
            elseif talent.name == "Arcane Resilience" then
                totals.armor = totals.armor
                    + intellect
                        * (tonumber(text:match("([%d%.]+)%% of your Intellect")) or 0)
                        / 100
                applied = true
            elseif
                talent.name == "Toughness"
                and text:find("armor value from items", 1, true)
                and sheet.mode == "gear"
            then
                local armor = 0
                for _, item in pairs(sheet.gear) do
                    armor = armor + (item.stats.armor or 0)
                end
                totals.armor = totals.armor
                    + armor * (tonumber(text:match("by ([%d%.]+)%%")) or 0) / 100
                applied = true
            end
            if applied then
                effects.included[#effects.included + 1] = talent.name
            end
        end
    end
    totals.baseMeleeCrit, totals.baseSpellCrit = totals.meleeCrit, totals.spellCrit
    totals.meleeCrit =
        math.min(100, totals.meleeCrit + generalCrit(build, "melee", withTalents, sheet.form))
    totals.spellCrit =
        math.min(100, totals.spellCrit + generalCrit(build, "spell", withTalents, sheet.form))
    if withTalents ~= false then
        local included = {}
        for _, name in ipairs(effects.included) do
            included[name] = true
        end
        for _, attack in ipairs({ "melee", "spell" }) do
            local scope = {
                kind = "damage",
                school = attack == "melee" and "Physical" or "Unspecified",
                attack = attack,
                periodic = 0,
            }
            local mods = Sim.Modifiers(
                build,
                { name = "Character baseline", related = {} },
                scope,
                { form = sheet.form }
            )
            for _, evidence in ipairs(mods.evidence) do
                if evidence.crit and not included[evidence.name] then
                    effects.included[#effects.included + 1] = evidence.name
                    included[evidence.name] = true
                end
            end
        end
    end
    local racialCrit = Sim.Racial(
        build,
        { weaponType = sheet.gear.mainHand and sheet.gear.mainHand.weaponType or sheet.weaponType },
        { kind = "damage" }
    ).crit
    totals.meleeCrit, totals.spellCrit =
        math.min(100, totals.meleeCrit + racialCrit), math.min(100, totals.spellCrit + racialCrit)
    local function weapon(slot, low, high, ap)
        local item = sheet.gear[slot]
        local speed = slot == "ranged" and inputs.rangedSpeed or inputs.weaponSpeed
        if slot == "mainHand" and sheet.mode == "gear" and sheet.form ~= "caster" then
            return inputs[low], inputs[high], speed, "none"
        end
        if sheet.mode == "gear" and item and item.high > 0 then
            local bonus = ap / 14 * item.speed
            return item.low + bonus, item.high + bonus, item.speed, item.weaponType
        end
        return inputs[low], inputs[high], speed, sheet.weaponType
    end
    totals.weaponMin, totals.weaponMax, totals.weaponSpeed, totals.weaponType =
        weapon("mainHand", "weaponMin", "weaponMax", totals.attackPower)
    totals.rangedMin, totals.rangedMax, totals.rangedSpeed, totals.rangedType =
        weapon("ranged", "rangedMin", "rangedMax", totals.rangedAP)
    if sheet.mode == "gear" then
        warnings[#warnings + 1] = FT.Data.simulation.character.source
        if sheet.form ~= "caster" then
            warnings[#warnings + 1] =
                "Feral base weapon hits are unverified. Enter measured form hit totals and speed, or capture the character in that form; equipped weapon damage is not used as claw damage."
        end
    end
    warnings[#warnings + 1] =
        "Custom gear adds listed stats only. Enchants, item procs, set bonuses, weapon skill and unmodeled passives need explicit totals or assumptions."
    table.sort(effects.included)
    return {
        sheet = sheet,
        totals = totals,
        inputs = inputs,
        base = { health = base.baseHealth[level], mana = base.baseMana[level] },
        passives = effects,
        warnings = warnings,
        source = sheet.mode == "gear" and "Reference base + custom gear"
            or "Your overall stats before modeled passives",
        level = level,
    }
end

function C.ForSkill(build, skill, rank, sheet, withTalents, effectMode)
    local character = C.Compute(build, sheet, withTalents)
    local parsed = Sim.Parse(rank, skill, build.level, effectMode)
    if character.sheet.mode == "captured" then
        local profile = FT.Copy(character.sheet.capture)
        profile.character = nil
        local state, note = FT.Snapshot.ForSkill(profile, skill, rank, build, effectMode)
        local ranged = parsed and parsed.attack == "ranged"
        local totals, inputs = character.totals, character.inputs
        local powerKey = parsed
                and (parsed.kind == "healing" or (parsed.kind == "absorption" and skill.name == "Power Word: Shield"))
                and "healing"
            or "power"
        state.power = math.max(0, state.power + totals[powerKey] - inputs[powerKey])
        state.attackPower = math.max(
            0,
            state.attackPower
                + totals[ranged and "rangedAP" or "attackPower"]
                - inputs[ranged and "rangedAP" or "attackPower"]
        )
        state.weaponMin = math.max(
            0,
            state.weaponMin
                + totals[ranged and "rangedMin" or "weaponMin"]
                - inputs[ranged and "rangedMin" or "weaponMin"]
        )
        state.weaponMax = math.max(
            0,
            state.weaponMax
                + totals[ranged and "rangedMax" or "weaponMax"]
                - inputs[ranged and "rangedMax" or "weaponMax"]
        )
        local item = character.sheet.gear[ranged and "ranged" or "mainHand"]
        state.weaponType = item and item.weaponType or character.sheet.weaponType
        state.weaponSpeed = item and item.speed > 0 and item.speed
            or character.sheet.stats[ranged and "rangedSpeed" or "weaponSpeed"]
        state.racialWeaponType = character.sheet.weaponType
        if character.critAttributeDelta then
            local attack = parsed
                    and parsed.attack ~= "spell"
                    and parsed.kind == "damage"
                    and "melee"
                or "spell"
            state.crit = math.max(0, state.crit + character.critAttributeDelta[attack])
        end
        state.effectMode = parsed and parsed.effectModes and parsed.effectMode or nil
        state.form = character.sheet.form
        return state, character, note
    end
    local totals = character.totals
    local ranged = parsed and parsed.attack == "ranged"
    local healing = parsed
        and (
            parsed.kind == "healing"
            or (parsed.kind == "absorption" and skill.name == "Power Word: Shield")
        )
    local state = Sim.State({
        power = healing and totals.healing or totals.power,
        attackPower = ranged and totals.rangedAP or totals.attackPower,
        weaponMin = ranged and totals.rangedMin or totals.weaponMin,
        weaponMax = ranged and totals.rangedMax or totals.weaponMax,
        weaponSpeed = ranged and totals.rangedSpeed or totals.weaponSpeed,
        weaponType = ranged and totals.rangedType or totals.weaponType,
        racialWeaponType = ranged and totals.weaponType or nil,
        effectMode = parsed and parsed.effectModes and parsed.effectMode or nil,
        form = character.sheet.form,
        crit = parsed
                and parsed.attack ~= "spell"
                and parsed.kind == "damage"
                and totals.baseMeleeCrit
            or totals.baseSpellCrit,
        hit = math.max(0, totals.hit - (build.raceID == 6 and 1 or 0)),
    })
    return state, character
end

function Sim.Run(build, skill, rank, overrides, withTalents)
    local state, character, note =
        C.ForSkill(build, skill, rank, nil, withTalents, overrides and overrides.effectMode)
    for key, value in pairs(overrides or {}) do
        state[key] = value
    end
    local result, why = Sim.Calculate(build, skill, rank, state, withTalents)
    if result then
        result.character, result.statsNote = character, note
        local applied = {}
        for _, name in ipairs(character.passives.included) do
            applied[name] = true
        end
        local omitted = {}
        for _, name in ipairs(result.modifiers.omitted) do
            if not applied[name] then
                omitted[#omitted + 1] = name
            end
        end
        result.modifiers.omitted = omitted
        result.overridden = {}
        for key in pairs(overrides or {}) do
            result.overridden[#result.overridden + 1] = key
        end
        table.sort(result.overridden)
        for _, text in ipairs(character.warnings) do
            result.warnings[#result.warnings + 1] = text
        end
        if not result.state.manual then
            result.confidence = (
                result.modelPartial
                or #omitted > 0
                or character.sheet.mode == "gear"
                or character.adjusted
            )
                    and "Partial estimate"
                or "Client-data estimate"
        end
    end
    return result, why
end

function Sim.ImportInputs(build, skill, rank, code)
    local profile, why = FT.Snapshot.DecodeStats(code)
    if not profile then
        return nil, why
    end
    if profile.classID ~= build.classID then
        return nil,
            "These inputs belong to another class. Import a full character in Character instead."
    end
    if profile.skillName ~= "" and profile.skillName ~= skill.name then
        return nil,
            "These skill-specific inputs were shared for "
                .. profile.skillName
                .. ". Open that skill's simulator first."
    end
    local state = FT.Snapshot.ForSkill(profile, skill, rank, build)
    return Sim.State(state)
end

C.gearFields = {}
for _, field in ipairs(C.fields) do
    if field.group ~= "Weapons" then
        local copy = FT.Copy(field)
        if copy.key == "hit" then
            copy.label = "Hit chance bonus (%)"
        end
        if copy.key == "power" then
            copy.label = "Spell / healing power"
        end
        if copy.key == "healing" then
            copy.label = "Healing-only bonus"
        end
        if copy.key == "attackPower" then
            copy.label = "Attack power (both)"
        end
        if copy.key == "rangedAP" then
            copy.label = "Ranged-only AP"
        end
        C.gearFields[#C.gearFields + 1] = copy
    end
end
for _, slot in ipairs(C.slots) do
    slot.weapon = slot.id >= 16
end
function C.SetMode(build, mode)
    if mode ~= "gear" and mode ~= "manual" and mode ~= "captured" then
        return false, "Invalid character mode."
    end
    local sheet = C.Get(build)
    if mode == "captured" and not sheet.capture then
        return false, "Capture or paste live totals first."
    end
    if sheet.mode ~= "captured" then
        sheet.plans[sheet.mode] = FT.Copy(sheet.stats)
    end
    if mode == "captured" then
        local restored = C.FromSnapshot(sheet.capture, sheet.gear)
        sheet.stats, sheet.weaponType = restored.stats, restored.weaponType
    else
        sheet.stats = FT.Copy(sheet.plans[mode] or {})
    end
    sheet.mode = mode
    return C.Save(build, sheet)
end
function C.View(build)
    local view = C.Compute(build)
    view.fields, view.slots, view.weaponTypes, view.gearFields =
        FT.Copy(C.fields), FT.Copy(C.slots), FT.Copy(C.weaponTypes), FT.Copy(C.gearFields)
    if view.sheet.mode == "gear" then
        for _, field in ipairs(view.fields) do
            if field.key == "attackPower" then
                field.label = "Attack power (both)"
            end
            if field.key == "rangedAP" then
                field.label = "Ranged-only AP"
            end
        end
    end
    view.identity = FT.Data.races[build.raceID].name .. " " .. M.Class(build.classID).name
    view.classIcon = M.Class(build.classID).icon
    view.forms = build.classID == 11
            and {
                { key = "caster", name = "Caster" },
                { key = "cat", name = "Cat" },
                { key = "bear", name = "Bear" },
            }
        or {}
    for _, field in ipairs(view.fields) do
        if field.key == "power" and view.sheet.mode == "gear" then
            field.label = "Spell / healing power"
        end
        if field.key == "healing" and view.sheet.mode == "gear" then
            field.label = "Healing-only bonus"
        end
        field.value = view.sheet.stats[field.key] or (field.key == "hit" and 100 or 0)
        field.total = view.totals[field.key]
        field.editable = view.sheet.mode ~= "captured"
    end
    return view
end
