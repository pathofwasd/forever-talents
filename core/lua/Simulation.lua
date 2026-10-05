local _, FT = ...
local Sim = {}
FT.Simulation = Sim

-- Numeric facts from the Forever 1.60.1.69893 SpellEffect comparison, 2026-09-17:
-- https://github.com/gunba/wow-forever-sim/blob/forever/docs/spell-data-2026-09-17.md
-- These are older-beta observations, not promises about a later client build.
local coefficients = {
    [133] = 0.429,
    [143] = 0.571,
    [145] = 0.714,
    [3140] = 0.857,
    [25306] = 1,
    [116] = 0.407,
    [205] = 0.489,
    [837] = 0.597,
    [686] = 0.486,
    [695] = 0.629,
    [705] = 0.8,
    [25307] = 0.857,
    [5176] = 0.429,
    [5177] = 0.486,
    [5178] = 0.571,
    [403] = 0.429,
    [529] = 0.571,
    [548] = 0.714,
    [915] = 0.714,
    [943] = 0.714,
    [6041] = 0.714,
    [10391] = 0.714,
    [10392] = 0.714,
    [15207] = 0.714,
    [15208] = 0.714,
    [421] = 0.571,
    [930] = 0.571,
    [2860] = 0.517,
    [10605] = 0.571,
    [585] = 0.429,
    [591] = 0.571,
    [598] = 0.714,
    [2136] = 0.429,
    [2137] = 0.429,
    [8042] = 0.386,
    [8044] = 0.386,
    [8045] = 0.386,
    [8092] = 0.429,
    [8102] = 0.429,
}

function Sim.Defaults()
    return {
        power = 0,
        attackPower = 0,
        weaponMin = 40,
        weaponMax = 60,
        crit = 5,
        hit = 100,
        reduction = 0,
        extra = 0,
        bleeding = false,
        frozen = false,
        cooldowns = false,
    }
end

local function number(text)
    return tonumber(text) or 0
end
function Sim.Parse(rank, skill)
    local description, source = FT.Description(rank)
    local text = description:gsub("%(([%d%.]+)%s*%*%s*1%)", "%1")
    local low = text:lower()
    if low:find("absorbs", 1, true) and not low:find("heals", 1, true) then
        return nil,
            "Absorption is a utility effect, not damage dealt. Choose a damaging/healing skill, or enter a manual base in Advanced."
    end
    local result = {
        kind = low:find("heals", 1, true) and "healing" or "damage",
        school = "Physical",
        min = 0,
        max = 0,
        periodic = 0,
        duration = 0,
        weapon = 0,
        ap = 0,
        descriptionSource = source,
    }
    local minimum, maximum, school = text:match("([%d%.]+)%s+to%s+([%d%.]+)%s+(%a+)%s+damage")
    if minimum then
        result.min, result.max, result.school = number(minimum), number(maximum), school
    end
    if not minimum then
        local amount, s = text:match("[Dd]eals%s+([%d%.]+)%s+(%a+)%s+damage")
        if not amount then
            amount, s = text:match("[Cc]auses%s+([%d%.]+)%s+(%a+)%s+damage")
        end
        if amount and not low:find("damage over", 1, true) then
            result.min, result.max, result.school = number(amount), number(amount), s
        end
    end
    if result.kind == "healing" then
        minimum, maximum = text:match("for%s+([%d%.]+)%s+to%s+([%d%.]+)")
        if minimum then
            result.min, result.max = number(minimum), number(maximum)
        else
            local amount = text:match("for%s+([%d%.]+)[%.%s]")
            if amount then
                result.min, result.max = number(amount), number(amount)
            end
        end
        result.school = "Healing"
        if skill and skill.icon then
            for _, s in ipairs({ "Holy", "Nature", "Shadow", "Arcane", "Fire", "Frost" }) do
                if skill.icon:find("spell_" .. s:lower() .. "_", 1, true) then
                    result.school = s
                    break
                end
            end
        end
    end
    local dot, duration = text:match("([%d%.]+)%s+%a+%s+damage%s+over%s+([%d%.]+)%s+sec")
    if not dot then
        dot, duration = text:match("([%d%.]+)%s+damage%s+over%s+([%d%.]+)%s+sec")
    end
    if not dot and result.kind == "healing" then
        dot, duration = text:match("for%s+([%d%.]+)%s+over%s+([%d%.]+)%s+sec")
    end
    if dot then
        result.periodic, result.duration = number(dot), number(duration)
        if result.kind == "healing" and not maximum then
            result.min, result.max = 0, 0
        end
        if result.school == "Physical" then
            for _, s in ipairs({ "Arcane", "Fire", "Frost", "Holy", "Nature", "Shadow" }) do
                if text:find(s .. " damage", 1, true) then
                    result.school = s
                    break
                end
            end
        end
    end
    local weapon = text:match("([%d%.]+)%%%s+normal%s+weapon%s+damage")
        or text:match("([%d%.]+)%%%s+weapon%s+damage")
    if weapon then
        result.weapon = number(weapon) / 100
    end
    if
        low:find("normal weapon damage", 1, true)
        or low:find("weapon damage plus", 1, true)
        or low:find("ranged weapon damage", 1, true)
        or low:find("increases ranged damage", 1, true)
        or low:find("increases melee damage", 1, true)
    then
        result.weapon = result.weapon ~= 0 and result.weapon or 1
    end
    local bonus = text:match("increases melee damage by%s+([%d%.]+)")
        or text:match("increases ranged damage by%s+([%d%.]+)")
        or text:match("causes%s+([%d%.]+)%s+damage in addition")
        or text:match("weapon damage plus%s+([%d%.]+)")
    if bonus then
        result.min, result.max = number(bonus), number(bonus)
    end
    local ap = text:match("([%d%.]+)%%%s+of your Attack Power")
    if ap then
        result.ap = number(ap) / 100
    end
    if
        result.min == 0
        and result.max == 0
        and result.periodic == 0
        and result.weapon == 0
        and result.ap == 0
    then
        return nil,
            "This tooltip has no unambiguous damage or healing amount. Use Advanced to enter a base value, or choose another skill."
    end
    if result.max < result.min then
        return nil, "The source range is not a simple numeric amount."
    end
    return result
end

function Sim.Coefficient(rank, parsed)
    if coefficients[rank.spellID] then
        return coefficients[rank.spellID],
            "Older Forever beta data (Sept 17); editable in Advanced."
    end
    if parsed.school == "Physical" or parsed.min == 0 then
        return 0, "No spell-power scaling assumed. Enter a coefficient in Advanced if known."
    end
    local info, cast
    if C_Spell and C_Spell.GetSpellInfo then
        local ok, v = pcall(C_Spell.GetSpellInfo, rank.spellID)
        if ok then
            info = v
            cast = info and info.castTime
        end
    elseif GetSpellInfo then
        local ok, _, _, _, v = pcall(GetSpellInfo, rank.spellID)
        if ok then
            cast = v
        end
    end
    if type(cast) == "number" and cast > 0 then
        return math.min(1, cast / 3500),
            "Approximation from client cast time / 3.5 sec. Talent-modified cast times may differ."
    end
    return 0,
        "Scaling coefficient is unknown; this estimate uses only the captured base amount. Set it in Advanced."
end

local function names(text, name)
    return (" " .. text:lower() .. " "):find(name:lower(), 1, true) ~= nil
end
local function applicable(sentence, skill, parsed)
    local low = sentence:lower()
    if names(sentence, skill.name) then
        return true
    end
    if
        parsed.kind == "healing"
        and (low:find("healing spells", 1, true) or low:find("healing done by", 1, true))
    then
        return true
    end
    if parsed.kind == "damage" or parsed.kind == "healing" then
        if
            low:find(parsed.school:lower() .. " spells", 1, true)
            or low:find(parsed.school:lower() .. " damage", 1, true)
            or (low:find(parsed.school:lower(), 1, true) and low:find("spells", 1, true))
        then
            return true
        end
        if
            parsed.school ~= "Physical"
            and (
                low:find("your spells", 1, true)
                or low:find("all spells", 1, true)
                or low:find("with spells", 1, true)
            )
        then
            return true
        end
        if
            parsed.school == "Physical"
            and (
                low:find("melee abilities", 1, true)
                or low:find("your abilities", 1, true)
                or low:find("physical damage", 1, true)
                or low:find("melee attacks", 1, true)
            )
        then
            return true
        end
    end
    return false
end

function Sim.Modifiers(build, skill, parsed, state)
    local out = {
        damage = 0,
        periodic = 0,
        crit = 0,
        statsCrit = 0,
        critBonus = 0,
        included = {},
        omitted = {},
    }
    local points = FT.Model.Counts(build)
    local index = FT.Model.Index(build.classID)
    for id, rank in pairs(points) do
        local t = index[id]
        local text = t.ranks[rank].text
        local applied = false
        -- Preserve decimal percentages while splitting independent sentences.
        local protected = text:gsub("(%d)%.(%d)", "%1\001%2")
        for sentence in protected:gmatch("[^.!?]+") do
            sentence = sentence:gsub("\001", ".")
            local low = sentence:lower()
            local conditionOK = not (
                    low:find("bleeding targets", 1, true) and not state.bleeding
                )
                and not (low:find("frozen", 1, true) and not state.frozen)
                and not (low:find("when activated", 1, true) and not state.cooldowns)
            local conditional = low:find("chance to", 1, true)
                or low:find("stack", 1, true)
                or low:find("after", 1, true)
                or low:find("next ", 1, true)
                or low:find("below", 1, true)
                or low:find("while in", 1, true)
                or low:find("per combo", 1, true)
                or low:find("killing", 1, true)
            if
                conditionOK
                and not conditional
                and low:find("increases", 1, true)
                and applicable(sentence, skill, parsed)
            then
                local bonus =
                    tonumber(low:match("critical strike damage bonus[^%%]-by ([%d%.]+)%%"))
                local crit = tonumber(
                    low:match("critical strike chance[^%%]-by ([%d%.]+)%%")
                        or low:match("critical effect chance[^%%]-by ([%d%.]+)%%")
                )
                if bonus and parsed.kind == "damage" then
                    out.critBonus = out.critBonus + bonus
                    applied = true
                end
                if crit then
                    out.crit = out.crit + crit
                    applied = true
                    -- Reported school/melee crit includes passive general and
                    -- school bonuses, but not spell-specific or target bonuses.
                    if not names(sentence, skill.name) and not low:find("against", 1, true) then
                        out.statsCrit = out.statsCrit + crit
                    end
                end
                -- Remove the critical-damage clause before looking for normal
                -- damage. A talent can grant both damage and crit in one line.
                local normal = low:gsub("critical strike damage bonus[^%%]-by [%d%.]+%%", "")
                local pct = tonumber(
                    normal:match(
                        parsed.kind == "healing" and "healing[^%%]-by ([%d%.]+)%%"
                            or "damage[^%%]-by ([%d%.]+)%%"
                    )
                )
                local defensive = normal:find("damage taken", 1, true)
                    or normal:find("damage you take", 1, true)
                if pct and (not defensive or normal:find("physical damage done", 1, true)) then
                    if normal:find("periodic", 1, true) or normal:find("bleed damage", 1, true) then
                        if parsed.periodic > 0 then
                            out.periodic = out.periodic + pct
                            applied = true
                        end
                    else
                        out.damage = out.damage + pct
                        applied = true
                    end
                end
            end
        end
        if applied then
            out.included[#out.included + 1] = t.name .. " (rank " .. rank .. ")"
        else
            for _, r in ipairs(skill.related or {}) do
                if r.id == id then
                    out.omitted[#out.omitted + 1] = t.name
                    break
                end
            end
        end
    end
    table.sort(out.included)
    table.sort(out.omitted)
    return out
end

local function bounded(value, low, high, default)
    value = tonumber(value)
    if not value or value ~= value or value == math.huge or value == -math.huge then
        return default
    end
    return math.max(low, math.min(high, value))
end

function Sim.State(raw)
    raw = type(raw) == "table" and raw or {}
    local s = Sim.Defaults()
    for _, key in ipairs({ "power", "attackPower", "weaponMin", "weaponMax" }) do
        s[key] = bounded(raw[key], 0, 100000, s[key])
    end
    for _, key in ipairs({ "crit", "hit", "reduction" }) do
        s[key] = bounded(raw[key], 0, 100, s[key])
    end
    s.extra = bounded(raw.extra, -99, 1000, 0)
    for _, key in ipairs({ "bleeding", "frozen", "cooldowns", "manual" }) do
        s[key] = raw[key] == true
    end
    for _, key in ipairs({ "coefficient", "dotCoefficient" }) do
        if raw[key] ~= nil then
            s[key] = bounded(raw[key], 0, 1000, 0)
        end
    end
    for _, key in ipairs({ "baseMin", "baseMax" }) do
        if raw[key] ~= nil then
            s[key] = bounded(raw[key], 0, 100000, 0)
        end
    end
    return s
end

function Sim.Calculate(build, skill, rank, raw, withTalents)
    local state = Sim.State(raw)
    local parsed, why = Sim.Parse(rank, skill)
    if state.manual then
        parsed = parsed
            or {
                kind = skill.ranks[1].text:lower():find("heals", 1, true) and "healing" or "damage",
                school = "Manual",
            }
        parsed.min, parsed.max = state.baseMin or 0, state.baseMax or state.baseMin or 0
        parsed.periodic, parsed.duration, parsed.weapon, parsed.ap = 0, 0, 0, 0
        if parsed.max < parsed.min then
            return nil, "Manual base high must be at least the low value."
        end
    end
    if not parsed then
        return nil, why
    end
    local coefficient, source = Sim.Coefficient(rank, parsed)
    if state.coefficient ~= nil then
        coefficient = state.coefficient / 100
        source = "Your Advanced scaling coefficient."
    end
    local dots = state.dotCoefficient and state.dotCoefficient / 100 or 0
    local mod = withTalents == false
            and { damage = 0, periodic = 0, crit = 0, critBonus = 0, included = {}, omitted = {} }
        or Sim.Modifiers(build, skill, parsed, state)
    local min = parsed.min
        + state.power * coefficient
        + state.weaponMin * parsed.weapon
        + state.attackPower * parsed.ap
    local max = parsed.max
        + state.power * coefficient
        + state.weaponMax * parsed.weapon
        + state.attackPower * parsed.ap
    local multiplier = (1 + mod.damage / 100) * (1 + state.extra / 100)
    local mitigation = parsed.kind == "healing" and 1 or 1 - state.reduction / 100
    min, max = min * multiplier * mitigation, max * multiplier * mitigation
    local periodic = (parsed.periodic + state.power * dots)
        * multiplier
        * (1 + mod.periodic / 100)
        * mitigation
    local critBase = parsed.school == "Physical" and 1 or 0.5
    local critMultiplier = 1 + critBase * (1 + mod.critBonus / 100)
    local crit = math.min(100, state.crit + mod.crit) / 100
    local average = (min + max) / 2 * (1 + crit * (critMultiplier - 1)) + periodic
    local hitChance = parsed.kind == "healing" and 1 or state.hit / 100
    return {
        min = min,
        max = max,
        periodic = periodic,
        duration = parsed.duration,
        critMin = min * critMultiplier,
        critMax = max * critMultiplier,
        average = average,
        expected = average * hitChance,
        coefficient = coefficient,
        source = source,
        modifiers = mod,
        parsed = parsed,
        crit = crit * 100,
        hit = hitChance * 100,
    }
end
