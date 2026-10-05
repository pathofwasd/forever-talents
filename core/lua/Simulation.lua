local _, FT = ...
local Sim = {}
FT.Simulation = Sim

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
function Sim.ParseTooltip(rank, skill)
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

function Sim.Parse(rank, skill, level, effectMode)
    local model = FT.Data.simulation and FT.Data.simulation.spells[rank.spellID]
    if not model then
        local parsed, why = Sim.ParseTooltip(rank, skill)
        if parsed then
            parsed.components = {}
            if parsed.min > 0 or parsed.max > 0 or parsed.ap > 0 or parsed.weapon > 0 then
                parsed.components[1] = {
                    kind = parsed.kind,
                    part = "direct",
                    low = parsed.min,
                    high = parsed.max,
                    sp = nil,
                    ap = parsed.ap,
                    weapon = parsed.weapon,
                    crit = false,
                    ticks = 1,
                }
            end
            if parsed.periodic > 0 then
                parsed.components[#parsed.components + 1] = {
                    kind = parsed.kind,
                    part = "periodic",
                    low = parsed.periodic,
                    high = parsed.periodic,
                    sp = nil,
                    ap = 0,
                    weapon = 0,
                    crit = false,
                    ticks = 1,
                }
            end
            parsed.notes = {
                "Tooltip fallback: scaling, tick timing and critical eligibility are not verified.",
            }
            parsed.attack = parsed.school == "Physical" and "melee" or "spell"
            parsed.fallback = true
        end
        return parsed, why
    end
    local parsed = FT.Copy(model)
    local kinds, selected = {}, {}
    for _, component in ipairs(parsed.components) do
        kinds[component.selfDamage and "cost" or component.kind] = true
    end
    local count = 0
    for _ in pairs(kinds) do
        count = count + 1
    end
    if count > 1 then
        parsed.effectModes = {}
        for _, kind in ipairs({ "damage", "healing", "absorption", "cost" }) do
            if kinds[kind] then
                parsed.effectModes[#parsed.effectModes + 1] = {
                    key = kind,
                    name = kind == "healing" and "Healing"
                        or kind == "absorption" and "Shield"
                        or kind == "cost" and "Health cost"
                        or "Damage",
                }
            end
        end
        local kind = kinds[effectMode] and effectMode
            or (
                kinds.damage and "damage"
                or kinds.healing and "healing"
                or kinds.absorption and "absorption"
                or "cost"
            )
        for _, component in ipairs(parsed.components) do
            if (component.selfDamage and "cost" or component.kind) == kind then
                selected[#selected + 1] = component
            end
        end
        parsed.components = selected
        parsed.effectMode = kind
        parsed.notes[#parsed.notes + 1] =
            "Damage, healing and health cost are separate results. Only the selected effect is included; they are never added together."
    end
    parsed.min, parsed.max, parsed.periodic, parsed.weapon, parsed.ap = 0, 0, 0, 0, 0
    parsed.descriptionSource = "client-data"
    parsed.kind = parsed.components[1].kind
    parsed.selfDamage = parsed.components[1].selfDamage == true
    parsed.displayKind = parsed.selfDamage and "health cost" or parsed.kind
    level = math.max(rank.level or model.level, level or rank.level or model.level)
    parsed.effectiveLevel = model.maxLevel > 0 and math.min(level, model.maxLevel) or level
    for _, c in ipairs(parsed.components) do
        local growth = math.max(0, parsed.effectiveLevel - model.level) * (c.growth or 0)
        c.levelBonus = growth
        c.low, c.high = math.max(0, c.low + growth), math.max(0, c.high + growth)
        local ticks = c.ticks or 1
        if c.part == "periodic" then
            parsed.periodic = parsed.periodic + (c.low + c.high) / 2 * ticks
        else
            parsed.min, parsed.max = parsed.min + c.low, parsed.max + c.high
        end
        parsed.weapon, parsed.ap = parsed.weapon + c.weapon, parsed.ap + c.ap
    end
    return parsed
end

function Sim.Coefficient(rank, parsed)
    parsed = parsed or Sim.Parse(rank)
    local total, known = 0, true
    for _, c in ipairs(parsed and parsed.components or {}) do
        if c.part == "direct" then
            total = total + (c.sp or 0)
            known = known and c.scalingKnown == true
        end
    end
    return total,
        known and ("Captured client coefficient • " .. FT.Data.simulation.build)
            or "Direct scaling is unverified. No spell-power contribution is included without an override."
end
local function names(text, name)
    local escaped = name:lower():gsub("([^%w])", "%%%1")
    return text:lower():find("%f[%w]" .. escaped .. "%f[%W]") ~= nil
end
local function applicable(sentence, skill, parsed)
    local low = sentence:lower()
    if low:find("all attacks", 1, true) and parsed.kind == "damage" then
        return true
    end
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
                or low:find("all attacks", 1, true)
            )
        then
            return true
        end
    end
    return false
end

-- Reviewed scopes prevent a percentage in a proc, pet or defensive clause from
-- being applied as a permanent player damage bonus. Values come from each rank.
local modifierRules = {
    ["Improved Rend"] = { periodic = true, names = { "Rend" } },
    ["Improved Overpower"] = { crit = true, names = { "Overpower" } },
    ["Two-Handed Weapon Specialization"] = { damage = true, weapon = "two", attack = "melee" },
    ["One-Handed Weapon Specialization"] = { damage = true, weapon = "one", attack = "melee" },
    ["Impale"] = { critBonus = true, attack = "melee" },
    ["Death Wish"] = { damage = true, schools = { Physical = true }, condition = "cooldowns" },
    ["Arcane Power"] = {
        damage = true,
        attack = "spell",
        condition = "cooldowns",
        pattern = "deal ([%d%.]+)%% more damage",
    },
    ["Improved Revenge"] = { damage = true, names = { "Revenge" } },
    ["Genesis"] = { periodic = true, kind = "both" },
    ["Improved Moonfire"] = { damage = true, crit = true, names = { "Moonfire" } },
    ["Nature's Majesty"] = { crit = true, kind = "both", statsCrit = true },
    ["Vengeance"] = { critBonus = true, schools = { Arcane = true, Nature = true }, classID = 11 },
    ["Moonfury"] = { damage = true, schools = { Arcane = true, Nature = true } },
    ["Feral Instinct"] = { damage = true, names = { "Swipe" } },
    ["Savage Fury"] = { damage = true, names = { "Claw", "Rake", "Shred", "Maul", "Swipe" } },
    ["Sharpened Claws"] = { crit = true, attack = "melee", form = true, statsCrit = true },
    ["Predatory Instincts"] = { critBonus = true, attack = "melee" },
    ["Rend and Tear"] = { damage = true, attack = "melee", condition = "bleeding" },
    ["Gift of Nature"] = { damage = true, kind = "healing" },
    ["Improved Regrowth"] = { crit = true, kind = "healing", names = { "Regrowth" } },
    ["Improved Entangling Roots"] = { damage = true, names = { "Entangling Roots" } },
    ["Improved Seals"] = { damage = true, contains = { "Seal", "Judgement" } },
    ["Holy Power"] = { crit = true, kind = "both", special = "holyPower", statsCrit = true },
    ["Sacred Arbiter"] = { damage = true, names = { "Holy Strike" } },
    ["Lethal Attacks"] = { crit = true, statsCrit = true },
    ["Improved Stings"] = { damage = true, names = { "Serpent Sting" } },
    ["Mortal Shots"] = { critBonus = true, attack = "ranged" },
    ["Barrage"] = { damage = true, names = { "Multi-Shot", "Aimed Shot", "Volley" } },
    ["Ranged Weapon Specialization"] = { damage = true, attack = "ranged" },
    ["Savage Strikes"] = { crit = true, attack = "melee", statsCrit = true },
    ["Clever Traps"] = {
        damage = true,
        names = { "Immolation Trap", "Explosive Trap" },
        pattern = "damage.-by ([%d%.]+)%%",
    },
    ["Predator's Edge"] = { critBonus = true, attack = "melee" },
    ["Malice"] = { crit = true, statsCrit = true },
    ["Murder"] = { damage = true, creatures = { humanoid = true, giant = true } },
    ["Vile Poisons"] = { damage = true, contains = { "Poison" } },
    ["Lethality"] = {
        critBonus = true,
        names = {
            "Sinister Strike",
            "Gouge",
            "Backstab",
            "Mutilate",
            "Ghostly Strike",
            "Hemorrhage",
        },
    },
    ["Improved Eviscerate"] = { damage = true, names = { "Eviscerate" } },
    ["Puncturing Wounds"] = {
        crit = true,
        names = { "Backstab", "Mutilate" },
        special = "puncturing",
    },
    ["Aggression"] = { damage = true, names = { "Sinister Strike", "Backstab", "Eviscerate" } },
    ["Opportunity"] = { damage = true, names = { "Backstab", "Garrote", "Ambush", "Mutilate" } },
    ["Improved Ambush"] = { crit = true, names = { "Ambush" } },
    ["Twin Disciplines"] = { damage = true, kind = "both", instant = true },
    ["Improved Power Word: Shield"] = {
        damage = true,
        kind = "absorption",
        names = { "Power Word: Shield" },
    },
    ["Holy Specialization"] = {
        crit = true,
        kind = "both",
        schools = { Holy = true },
        statsCrit = true,
    },
    ["Searing Light"] = { damage = true, schools = { Holy = true } },
    ["Early Demise"] = { crit = true, names = { "Shadow Word: Death" }, condition = "executeRange" },
    ["Darkness"] = { damage = true, schools = { Shadow = true } },
    ["Inner Focus"] = {
        directCrit = true,
        kind = "both",
        attack = "spell",
        condition = "cooldowns",
        pattern = "critical.-by ([%d%.]+)%%",
    },
    ["Concussion"] = {
        damage = true,
        names = { "Lightning Bolt", "Chain Lightning", "Earth Shock" },
    },
    ["Call of Flame"] = {
        damage = true,
        names = { "Searing Totem", "Magma Totem", "Flame Shock", "Fire Nova", "Lava Burst" },
    },
    ["Improved Fire Nova"] = { damage = true, names = { "Fire Nova" } },
    ["Call of Thunder"] = { crit = true, names = { "Lightning Bolt", "Chain Lightning" } },
    ["Elemental Fury"] = {
        critBonus = true,
        schools = { Fire = true, Frost = true, Nature = true },
    },
    ["Improved Lightning Shield"] = { damage = true, names = { "Lightning Shield" } },
    ["Tidal Mastery"] = { crit = true, kind = "healing", statsCrit = true },
    ["Purification"] = { damage = true, kind = "healing" },
    ["Arcane Impact"] = { crit = true, schools = { Arcane = true }, statsCrit = true },
    ["Arcane Mind"] = { critBonus = true, schools = { Arcane = true } },
    ["Arcane Instability"] = { damage = true, crit = true, attack = "spell", statsCrit = true },
    ["Incineration"] = {
        crit = true,
        names = { "Fire Blast", "Ice Lance", "Arcane Blast", "Scorch" },
    },
    ["Improved Flamestrike"] = { crit = true, names = { "Flamestrike" } },
    ["Critical Mass"] = { crit = true, schools = { Fire = true }, statsCrit = true },
    ["Fire Power"] = { damage = true, schools = { Fire = true } },
    ["Ice Shards"] = { critBonus = true, schools = { Frost = true } },
    ["Piercing Ice"] = { damage = true, schools = { Frost = true } },
    ["Shatter"] = { crit = true, kind = "both", attack = "spell", condition = "frozen" },
    ["Improved Cone of Cold"] = { damage = true, names = { "Cone of Cold" } },
    ["Malediction"] = { periodic = true },
    ["Improved Drains"] = { damage = true, names = { "Drain Life", "Drain Soul", "Wrack" } },
    ["Improved Bane of Agony"] = { damage = true, names = { "Bane of Agony" } },
    ["Pandemic"] = {
        critBonus = true,
        names = {
            "Corruption",
            "Bane of Agony",
            "Bane of Doom",
            "Drain Soul",
            "Drain Life",
            "Siphon Life",
            "Wrack",
        },
    },
    ["Malevolence"] = { crit = true, kind = "both", schools = { Shadow = true }, statsCrit = true },
    ["Shadow Mastery"] = { damage = true, schools = { Shadow = true } },
    ["Aftermath"] = { direct = true, names = { "Immolate" } },
    ["Ruin"] = { critBonus = true, destruction = true },
    ["Agonizing Flames"] = { special = "agonizing", destruction = true },
    ["Fire and Brimstone"] = { crit = true, names = { "Conflagrate" } },
}
local destruction = {
    ["Shadow Bolt"] = true,
    Immolate = true,
    Conflagrate = true,
    ["Searing Pain"] = true,
    ["Soul Fire"] = true,
    Shadowburn = true,
    ["Rain of Fire"] = true,
    Hellfire = true,
}
local function ruleApplies(rule, build, skill, parsed, state, ignoreCondition)
    if rule.classID and rule.classID ~= build.classID then
        return false
    end
    if parsed.selfDamage then
        return false
    end
    if rule.kind == "both" then
        if parsed.kind ~= "healing" and parsed.kind ~= "damage" then
            return false
        end
    elseif parsed.kind ~= (rule.kind or "damage") then
        return false
    end
    local attack = parsed.attack or (parsed.school == "Physical" and "melee" or "spell")
    if rule.attack and attack ~= rule.attack then
        return false
    end
    if rule.schools and not rule.schools[parsed.school] then
        return false
    end
    if rule.names then
        local found = false
        for _, name in ipairs(rule.names) do
            if skill.name == name then
                found = true
            end
        end
        if not found then
            return false
        end
    end
    if rule.contains then
        local found = false
        for _, name in ipairs(rule.contains) do
            if skill.name:find(name, 1, true) then
                found = true
            end
        end
        if not found then
            return false
        end
    end
    if rule.destruction and not destruction[skill.name] then
        return false
    end
    if rule.instant and (parsed.cast ~= 0 or parsed.channel) then
        return false
    end
    if rule.periodic and parsed.periodic <= 0 then
        return false
    end
    if ignoreCondition then
        return true
    end
    if rule.condition and not state[rule.condition] then
        return false
    end
    if rule.creatures and not rule.creatures[state.targetType] then
        return false
    end
    if rule.form and state.form ~= "cat" and state.form ~= "bear" then
        return false
    end
    if rule.weapon then
        local weapon = state.weaponType or "none"
        local two = weapon == "twoSword"
            or weapon == "twoAxe"
            or weapon == "twoMace"
            or weapon == "staff"
            or weapon == "polearm"
        local one = weapon == "sword"
            or weapon == "axe"
            or weapon == "mace"
            or weapon == "dagger"
            or weapon == "fist"
        if not ((rule.weapon == "two" and two) or (rule.weapon == "one" and one)) then
            return false
        end
    end
    return true
end
function Sim.Modifiers(build, skill, parsed, state)
    local out = {
        damage = 0,
        direct = 0,
        periodic = 0,
        crit = 0,
        statsCrit = 0,
        directCrit = 0,
        periodicCrit = 0,
        critBonus = 0,
        included = {},
        omitted = {},
        evidence = {},
    }
    state = state or Sim.Defaults()
    local index = FT.Model.Index(build.classID)
    for id, rank in pairs(FT.Model.Counts(build)) do
        local talent, applied = index[id], false
        local text = talent.ranks[rank].text
        local rule = modifierRules[talent.name]
        if rule and ruleApplies(rule, build, skill, parsed, state) then
            local pattern = rule.pattern
                or (rule.critBonus and "critical.-by ([%d%.]+)%%" or "by ([%d%.]+)%%")
            local pct = tonumber(text:match(pattern))
            if rule.special == "puncturing" then
                pct = tonumber(text:match(skill.name .. " by ([%d%.]+)%%"))
            end
            if
                rule.special == "holyPower"
                and skill.name ~= "Holy Shock"
                and skill.name ~= "Holy Strike"
            then
                pct = tonumber(text:match("all other spells by ([%d%.]+)%%"))
            end
            if pct then
                local evidence = { name = talent.name, rank = rank, text = text }
                for _, key in ipairs({
                    "damage",
                    "direct",
                    "periodic",
                    "crit",
                    "critBonus",
                    "directCrit",
                }) do
                    if rule[key] then
                        out[key] = out[key] + pct
                        evidence[key] = pct
                        applied = true
                    end
                end
                if rule.special == "agonizing" then
                    local damage = tonumber(text:match("damage done.-by ([%d%.]+)%%")) or 0
                    out.damage, evidence.damage = out.damage + damage, damage
                    if skill.name == "Searing Pain" then
                        out.crit, evidence.crit = out.crit + pct, pct
                    end
                    applied = damage > 0 or skill.name == "Searing Pain"
                end
                local reported = FT.Data.simulation.statsCrit[talent.id]
                if rule.statsCrit and rule.crit and reported and reported[rank] then
                    local bonus = pct
                    if rule.special == "holyPower" then
                        bonus = tonumber(text:match("all other spells by ([%d%.]+)%%")) or 0
                    end
                    out.statsCrit = out.statsCrit + bonus
                end
                if applied then
                    out.included[#out.included + 1] = talent.name .. " (rank " .. rank .. ")"
                    out.evidence[#out.evidence + 1] = evidence
                end
            end
        end
        if not rule then
            local linked = applicable(text, skill, parsed)
            for _, relation in ipairs(skill.related or {}) do
                linked = linked or relation.id == id
            end
            if linked then
                out.omitted[#out.omitted + 1] = talent.name
            end
        end
    end
    table.sort(out.included)
    table.sort(out.omitted)
    table.sort(out.evidence, function(a, b)
        return a.name < b.name
    end)
    return out
end

local function bounded(value, low, high, default)
    value = tonumber(value)
    if not value or value ~= value or value == math.huge or value == -math.huge then
        return default
    end
    return math.max(low, math.min(high, value))
end
Sim.Bounded = bounded

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
    for _, key in ipairs({
        "coefficient",
        "dotCoefficient",
        "apCoefficient",
        "dotAPCoefficient",
        "baseMin",
        "baseMax",
        "periodicBase",
        "scalingFactor",
        "weaponSpeed",
        "comboPoints",
        "rage",
    }) do
        if raw[key] ~= nil then
            local high = ({
                coefficient = 1000,
                dotCoefficient = 1000,
                apCoefficient = 1000,
                dotAPCoefficient = 1000,
                scalingFactor = 100,
                comboPoints = 5,
                rage = 100,
                weaponSpeed = 10,
            })[key] or 100000
            s[key] = bounded(raw[key], 0, high, 0)
        end
    end
    s.weaponType = FT.Character and FT.Character.WeaponType(raw.weaponType) or "none"
    s.targetType = ({ beast = true, elemental = true, humanoid = true, giant = true })[raw.targetType]
            and raw.targetType
        or "other"
    s.form = raw.form == "cat" and "cat" or raw.form == "bear" and "bear" or "caster"
    s.executeRange = raw.executeRange == true
    if
        raw.effectMode == "damage"
        or raw.effectMode == "healing"
        or raw.effectMode == "absorption"
        or raw.effectMode == "cost"
    then
        s.effectMode = raw.effectMode
    end
    if raw.racialWeaponType then
        s.racialWeaponType = FT.Character.WeaponType(raw.racialWeaponType)
    end
    if s.comboPoints then
        s.comboPoints = math.max(1, math.floor(s.comboPoints))
    end
    return s
end

local function warning(out, text)
    for _, v in ipairs(out) do
        if v == text then
            return
        end
    end
    out[#out + 1] = text
end

local function display(n)
    return string.format("%.2f", n):gsub("0+$", ""):gsub("%.$", "")
end

local function racial(build, state, parsed)
    local out = { damage = 0, direct = 0, crit = 0, hit = 0, power = 1, ap = 1, included = {} }
    if parsed.selfDamage then
        return out
    end
    for _, trait in ipairs(FT.Data.racials[build.classID][build.raceID] or {}) do
        local text, name = trait.text:lower(), trait.name
        local weapon = state.racialWeaponType or state.weaponType or "none"
        local applies = (
            name == "Sword Specialization" and (weapon == "sword" or weapon == "twoSword")
        )
            or (name == "Axe Specialization" and (weapon == "axe" or weapon == "twoAxe"))
            or (name == "Mace Specialization" and (weapon == "mace" or weapon == "twoMace"))
        local pct = tonumber(text:match("by ([%d%.]+)%%") or text:match("increased by ([%d%.]+)%%"))
        if applies and pct then
            out.crit = out.crit + pct
        end
        if
            (name == "Beast Slaying" or name == "Big Game Hunter")
            and state.targetType == "beast"
        then
            out.damage, applies = out.damage + (pct or 5), true
        elseif name == "Elemental Insight" and state.targetType == "elemental" then
            out.damage, applies = out.damage + (pct or 5), true
        elseif name == "Endurance" and parsed.kind == "damage" then
            out.hit, applies = out.hit + 1, true
        elseif state.cooldowns and name == "Blood Fury" then
            out.power, out.ap, applies = 1.1, 1.1, true
        elseif state.cooldowns and name == "Elune's Light" then
            out.crit, applies = out.crit + 10, true
        end
        if applies then
            out.included[#out.included + 1] = name
        end
    end
    return out
end
Sim.Racial = racial

function Sim.Calculate(build, skill, rank, raw, withTalents)
    if type(rank) ~= "table" then
        return nil, "Choose a valid skill rank."
    end
    local state = Sim.State(raw)
    local parsed, why = Sim.Parse(rank, skill, build.level, state.effectMode)
    if parsed and parsed.effectModes then
        state.effectMode = parsed.effectMode
    end
    local warnings = {}
    if state.weaponMax < state.weaponMin then
        return nil, "Weapon maximum must be at least the minimum."
    end
    if state.manual then
        if (state.baseMax or state.baseMin or 0) < (state.baseMin or 0) then
            return nil, "Manual base high must be at least the low value."
        end
        parsed = parsed or { kind = "damage", school = "Manual", attack = "spell", notes = {} }
        parsed.components = {
            {
                kind = parsed.kind,
                part = "direct",
                low = state.baseMin or 0,
                high = state.baseMax or state.baseMin or 0,
                ticks = 1,
                sp = state.coefficient and state.coefficient / 100 or 0,
                ap = 0,
                weapon = 0,
                crit = parsed.kind ~= "absorption" and not parsed.selfDamage,
                selfDamage = parsed.selfDamage,
                scalingKnown = true,
            },
        }
        if (state.periodicBase or 0) > 0 then
            parsed.components[#parsed.components + 1] = {
                kind = parsed.kind,
                part = "periodic",
                low = state.periodicBase,
                high = state.periodicBase,
                ticks = 1,
                sp = state.dotCoefficient and state.dotCoefficient / 100 or 0,
                ap = 0,
                weapon = 0,
                crit = false,
                selfDamage = parsed.selfDamage,
                scalingKnown = true,
            }
        end
        parsed.min, parsed.max = state.baseMin or 0, state.baseMax or state.baseMin or 0
        parsed.periodic, parsed.weapon, parsed.ap = state.periodicBase or 0, 0, 0
        parsed.duration = 0
        parsed.notes = {
            "Manual model: supplied amounts replace captured effects. Periodic crit and tick timing are not assumed.",
        }
    end
    if not parsed then
        return nil, why
    end
    for _, note in ipairs(parsed.notes or {}) do
        warning(warnings, note)
    end
    if rank.level and build.level < rank.level then
        warning(
            warnings,
            "This rank is learned above the displayed level. Numbers are a rank preview, not a usable cast at this level."
        )
    end
    if not state.manual and (rank.level or 60) < 20 and build.level > (rank.level or 60) + 10 then
        local usesPower = false
        for _, c in ipairs(parsed.components) do
            usesPower = usesPower or (c.sp or 0) > 0
        end
        if usesPower and state.scalingFactor == nil then
            warning(
                warnings,
                "Very low ranks have a Forever downranking penalty. Its current curve is unverified; captured full scaling is shown and may overestimate. Set scaling retained in Advanced if measured."
            )
        end
    end
    local mod = withTalents == false
            and {
                damage = 0,
                direct = 0,
                periodic = 0,
                crit = 0,
                directCrit = 0,
                periodicCrit = 0,
                critBonus = 0,
                included = {},
                omitted = {},
                evidence = {},
            }
        or Sim.Modifiers(build, skill, parsed, state)
    local race = racial(build, state, parsed)
    local directCount, periodicCount = 0, 0
    for _, c in ipairs(parsed.components) do
        if c.part == "periodic" then
            periodicCount = periodicCount + 1
        else
            directCount = directCount + 1
        end
    end
    local result = {
        min = 0,
        max = 0,
        periodic = 0,
        periodicMax = 0,
        critMin = 0,
        critMax = 0,
        critPeriodic = 0,
        critPeriodicMax = 0,
        average = 0,
        expected = 0,
        duration = periodicCount > 0 and (parsed.duration or 0) or 0,
        coefficient = 0,
        dotCoefficient = 0,
        modifiers = mod,
        racials = race.included,
        parsed = parsed,
        warnings = warnings,
        breakdown = {},
        state = state,
        critEligible = false,
        inputs = {},
    }
    local source = FT.Data.simulation
    result.source = state.manual and "Manual amounts and scaling"
        or parsed.fallback and "Captured tooltip fallback"
        or "Client data "
            .. source.build
            .. " · reviewed "
            .. source.checked
            .. " · October 1 corrections"
    result.sources = {
        { label = "Client effects, coefficients and tick intervals", url = source.sources[1].url },
        { label = "Forever developer notes and corrections", url = source.patchSource },
    }
    local partial = parsed.fallback == true
    if
        state.coefficient ~= nil
        or state.dotCoefficient ~= nil
        or state.apCoefficient ~= nil
        or state.dotAPCoefficient ~= nil
    then
        partial = true
        warning(
            warnings,
            "Scaling overrides are supplied assumptions; confirm them against measured Forever behavior."
        )
    end
    for _, c in ipairs(parsed.components) do
        local periodic, ticks = c.part == "periodic", c.ticks or 1
        local coef = c.sp or 0
        local override = periodic and state.dotCoefficient
            or (not periodic and state.coefficient or nil)
        local apOverride = periodic and state.dotAPCoefficient
            or (not periodic and state.apCoefficient or nil)
        if override ~= nil then
            coef = override / 100 / ticks / (periodic and periodicCount or directCount)
        end
        coef = coef * (state.scalingFactor or 100) / 100
        if not c.scalingKnown and override == nil and apOverride == nil then
            partial = true
            warning(
                warnings,
                (periodic and "Periodic" or "Direct")
                    .. " power scaling is unverified; only its captured base and known modifiers are included."
            )
        end
        local combo = (c.combo or 0) * math.max(1, math.floor(state.comboPoints or 1))
        local rage = (c.rage or 0) * (state.rage or 0)
        local weaponLow, weaponHigh = state.weaponMin * c.weapon, state.weaponMax * c.weapon
        if race.ap ~= 1 and c.weapon > 0 then
            if (state.weaponSpeed or 0) > 0 then
                local bonus = state.attackPower * (race.ap - 1) / 14 * state.weaponSpeed * c.weapon
                weaponLow, weaponHigh = weaponLow + bonus, weaponHigh + bonus
            else
                partial = true
                warning(
                    warnings,
                    "Weapon speed is unavailable; the active Attack Power cooldown's weapon contribution is not modeled."
                )
            end
        end
        if c.normalized and c.weapon ~= 0 then
            local speeds = {
                dagger = 1.7,
                twoSword = 3.3,
                twoAxe = 3.3,
                twoMace = 3.3,
                staff = 3.3,
                polearm = 3.3,
                bow = 2.8,
                gun = 2.8,
                crossbow = 2.8,
                sword = 2.4,
                axe = 2.4,
                mace = 2.4,
                fist = 2.4,
            }
            local speed = parsed.attack == "ranged" and 2.8 or speeds[state.weaponType]
            if speed and (state.weaponSpeed or 0) > 0 then
                local adjustment = state.attackPower
                    * race.ap
                    / 14
                    * (speed - state.weaponSpeed)
                    * c.weapon
                weaponLow, weaponHigh = weaponLow + adjustment, weaponHigh + adjustment
            else
                partial = true
            end
        end
        if c.weapon > 0 and state.weaponMax == 0 then
            warning(
                warnings,
                "No weapon damage is configured. Enter a normal weapon hit or equip a custom weapon in Character."
            )
            partial = true
        end
        local power = state.power * race.power * coef
        local apRatio = apOverride ~= nil
                and apOverride / 100 / ticks / (periodic and periodicCount or directCount)
            or c.ap
        local ap = state.attackPower * race.ap * apRatio
        local low, high =
            math.max(0, c.low + power + ap + weaponLow + combo + rage),
            math.max(0, c.high + power + ap + weaponHigh + combo + rage)
        local talent = 1 + mod.damage / 100
        if periodic then
            talent = talent * (1 + mod.periodic / 100)
        else
            talent = talent * (1 + (mod.direct or 0) / 100)
        end
        local raceMultiplier = c.kind == "damage"
                and (1 + race.damage / 100) * (periodic and 1 or (1 + race.direct / 100))
            or 1
        local multiplier = c.selfDamage and 1 or talent * raceMultiplier * (1 + state.extra / 100)
        local mitigation = c.kind == "damage" and not c.selfDamage and (1 - state.reduction / 100)
            or 1
        low, high = low * multiplier * mitigation, high * multiplier * mitigation
        local crit = c.crit
                and math.min(
                    100,
                    state.crit
                        + mod.crit
                        + (periodic and mod.periodicCrit or mod.directCrit)
                        + race.crit
                ) / 100
            or 0
        local critBonus = (parsed.attack ~= "spell" and c.kind == "damage") and 1 or 0.5
        local critMultiplier = c.crit and (1 + critBonus * (1 + mod.critBonus / 100)) or 1
        local hit = c.kind == "damage"
                and not c.selfDamage
                and math.min(100, state.hit + race.hit) / 100
            or 1
        local average = (low + high) / 2 * ticks * (1 + crit * (critMultiplier - 1))
        local expected = average * hit
        local b = {
            label = c.selfDamage and "Health cost"
                or c.kind == "absorption" and "Shield capacity"
                or periodic and "Periodic " .. c.kind
                or "Direct " .. c.kind,
            part = c.part,
            kind = c.kind,
            ticks = ticks,
            interval = c.interval or 0,
            baseLow = c.low,
            baseHigh = c.high,
            levelBonus = c.levelBonus or 0,
            power = power,
            attackPower = ap,
            apCoefficient = apRatio,
            weaponLow = weaponLow,
            weaponHigh = weaponHigh,
            resource = combo + rage,
            coefficient = coef,
            multiplier = multiplier,
            mitigation = mitigation,
            low = low,
            high = high,
            totalLow = low * ticks,
            totalHigh = high * ticks,
            critLow = low * critMultiplier * ticks,
            critHigh = high * critMultiplier * ticks,
            crit = crit * 100,
            critMultiplier = critMultiplier,
            hit = hit * 100,
            expected = expected,
            critEligible = c.crit == true,
            sourceSpell = c.sourceSpell or rank.spellID,
        }
        b.formula = "("
            .. display(c.low)
            .. (c.high ~= c.low and "–" .. display(c.high) or "")
            .. " base + "
            .. display(power)
            .. " power + "
            .. display(ap)
            .. " AP + "
            .. display((weaponLow + weaponHigh) / 2)
            .. " weapon + "
            .. display(combo + rage)
            .. " resource) × "
            .. display(multiplier)
            .. " bonuses × "
            .. display(mitigation)
            .. " remaining"
            .. (periodic and " × " .. ticks .. " ticks" or "")
        b.averageFormula = "Mean non-critical total × (1 + "
            .. display(crit * 100)
            .. "% × ("
            .. display(critMultiplier)
            .. " − 1)) × "
            .. display(hit * 100)
            .. "% lands = "
            .. display(expected)
        result.breakdown[#result.breakdown + 1] = b
        result.average, result.expected = result.average + average, result.expected + expected
        result.critEligible = result.critEligible or c.crit == true
        if periodic then
            result.periodic, result.periodicMax =
                result.periodic + low * ticks, result.periodicMax + high * ticks
            result.critPeriodic, result.critPeriodicMax =
                result.critPeriodic + b.critLow, result.critPeriodicMax + b.critHigh
            result.dotCoefficient = result.dotCoefficient + coef * ticks
        else
            result.min, result.max = result.min + low, result.max + high
            result.critMin, result.critMax = result.critMin + b.critLow, result.critMax + b.critHigh
            result.coefficient = result.coefficient + coef
        end
        result.crit, result.hit = math.max(result.crit or 0, b.crit), b.hit
    end
    result.normalMin, result.normalMax =
        result.min + result.periodic, result.max + result.periodicMax
    result.criticalMin, result.criticalMax =
        result.critMin + result.critPeriodic, result.critMax + result.critPeriodicMax
    result.perSecond = result.duration > 0 and result.expected / result.duration or nil
    for _, note in ipairs(warnings) do
        if
            note:find("partial", 1, true)
            or note:find("unverified", 1, true)
            or note:find("not modeled", 1, true)
            or note:find("overestimate", 1, true)
        then
            partial = true
        end
    end
    result.confidence = state.manual and "Manual estimate"
        or partial and "Partial estimate"
        or "Client-data estimate"
    result.modelPartial = partial
    if #mod.omitted > 0 and not state.manual then
        result.confidence = "Partial estimate"
    end
    result.inputs = Sim.Inputs(build, skill, rank, state, parsed)
    result.limits =
        "One use, one target, full duration. No rotation, proc uptime, travel time, overhealing, target-level attack table, block, glancing blows or automatic armor/resistance calculation. Chance to land and damage reduction are explicit assumptions."
    return result
end

local inputDefinitions = {
    power = {
        "Bonus power",
        "Resolved spell damage or healing from your character. Includes modeled stat passives; used only by components with a known or supplied coefficient.",
        "character",
    },
    attackPower = {
        "Attack Power",
        "Used by an explicit AP ratio, or to normalize weapon damage.",
        "character",
    },
    weaponMin = {
        "Weapon hit · low",
        "Normal weapon damage including its ordinary AP bonus. Custom gear and live captures fill this for you.",
        "character",
    },
    weaponMax = {
        "Weapon hit · high",
        "Upper end of the normal weapon hit range. Must be at least the low value.",
        "character",
    },
    crit = {
        "Critical chance (%)",
        "Before modeled talent and racial crit bonuses. Only effects marked as able to crit use this value.",
        "character",
    },
    hit = {
        "Chance to land (%)",
        "Total chance to land after miss, dodge and parry. This changes the expected result, not a successful hit.",
        "target",
    },
    reduction = {
        "Damage reduction (%)",
        "Total damage prevented by the target. Armor and partial resistance are not inferred. Healing and shields ignore this.",
        "target",
    },
    comboPoints = {
        "Combo points",
        "Number of combo points used by the captured finisher. Scripted interactions may remain unverified.",
        "target",
        1,
        5,
    },
    rage = {
        "Extra Rage spent",
        "Rage consumed beyond Execute's cast cost, not your total Rage before casting.",
        "target",
        0,
        100,
    },
    bleeding = {
        "Target is bleeding",
        "Includes modeled bonuses that require an already bleeding target.",
        "condition",
    },
    frozen = {
        "Target is frozen",
        "Includes modeled bonuses that require a frozen target.",
        "condition",
    },
    cooldowns = {
        "Active cooldowns",
        "Assume the listed learned talent and racial cooldowns are active for this one use. No uptime is assumed.",
        "condition",
    },
    targetType = {
        "Target creature type",
        "Enables modeled damage bonuses against this creature type.",
        "condition",
    },
    executeRange = {
        "Target at or below 20% health",
        "Enables Early Demise for Shadow Word: Death. This is a target condition, not a saved character stat.",
        "condition",
    },
    form = {
        "Shapeshift form",
        "Starts from Character. Applies recognized form-specific stat/critical bonuses; temporary form changes here do not rebuild character AP. Change the central form for full stat changes.",
        "advanced",
    },
    coefficient = {
        "Direct power scaling (%)",
        "Total coefficient for the direct effect. Blank uses captured data. If it has multiple components, an override is split evenly among them. Zero explicitly disables scaling.",
        "advanced",
        0,
        1000,
    },
    dotCoefficient = {
        "Full periodic power scaling (%)",
        "Total coefficient across all periodic components and ticks. An override is divided evenly among components and their ticks, never applied in full to every tick.",
        "advanced",
        0,
        1000,
    },
    apCoefficient = {
        "Direct Attack Power scaling (%)",
        "Explicit total AP coefficient for direct effects. Blank uses captured data. Use a measured value when server-side scaling is unknown; do not copy coefficients from another WoW edition.",
        "advanced",
        0,
        1000,
    },
    dotAPCoefficient = {
        "Full periodic Attack Power scaling (%)",
        "Explicit total AP coefficient across every tick. Blank uses captured data. An override is split across periodic components and their ticks.",
        "advanced",
        0,
        1000,
    },
    scalingFactor = {
        "Scaling retained (%)",
        "Manual downranking factor: 50 retains half of the captured power contribution. Blank assumes full scaling; the current Forever penalty curve is not verified.",
        "advanced",
        0,
        100,
    },
    weaponSpeed = {
        "Weapon speed (seconds)",
        "Actual equipped weapon speed before haste. Used with weapon type for normalized strikes.",
        "advanced",
        0,
        10,
    },
    weaponType = {
        "Weapon type",
        "Determines normalized weapon speed and racial weapon-specialization bonuses.",
        "advanced",
    },
    racialWeaponType = {
        "Equipped racial weapon",
        "Equipped weapon used by your race's critical bonus. Separate from the ranged weapon used by this skill.",
        "advanced",
    },
    effectMode = {
        "Effect to simulate",
        "Damage, healing and shield capacity are separate results. Choose which effect this use should evaluate.",
        "target",
    },
    extra = {
        "Additional bonus (%)",
        "A separate multiplier for an unmodeled buff or debuff. Do not add a bonus already listed as included.",
        "advanced",
        -99,
        1000,
    },
    baseMin = {
        "Manual base · low",
        "Replaces the captured direct amount before power and bonuses.",
        "advanced",
    },
    baseMax = { "Manual base · high", "Upper end of the replacement direct amount.", "advanced" },
    periodicBase = {
        "Manual periodic total",
        "Replacement total over time. No tick timing or periodic crits are assumed in this manual component.",
        "advanced",
    },
}

function Sim.Inputs(build, skill, rank, raw, parsed)
    local state = Sim.State(raw)
    parsed = parsed or Sim.Parse(rank, skill, build.level, state.effectMode)
    local used = { extra = true }
    if parsed then
        if parsed.selfDamage then
            used.extra = nil
        end
        if parsed.effectModes then
            used.effectMode = true
        end
        for _, c in ipairs(parsed.components or {}) do
            used[c.part == "periodic" and "dotAPCoefficient" or "apCoefficient"] = true
            local periodic = c.part == "periodic"
            local coefficient = periodic and state.dotCoefficient
                or (not periodic and state.coefficient or nil)
            local effective = coefficient ~= nil and coefficient / 100 or (c.sp or 0)
            if effective > 0 and state.scalingFactor ~= 0 then
                used.power = true
            end
            local apOverride = c.part == "periodic" and state.dotAPCoefficient
                or (c.part ~= "periodic" and state.apCoefficient or nil)
            if
                (apOverride ~= nil and apOverride > 0)
                or (apOverride == nil and c.ap > 0)
                or c.normalized
            then
                used.attackPower = true
            end
            if c.weapon > 0 then
                used.weaponMin, used.weaponMax = true, true
            end
            if c.normalized then
                used.weaponSpeed = true
                if parsed.attack ~= "ranged" then
                    used.weaponType = true
                end
            end
            if c.crit then
                used.crit = true
            end
            if (c.combo or 0) ~= 0 then
                used.comboPoints = true
            end
            if (c.rage or 0) ~= 0 then
                used.rage = true
            end
            if c.kind == "damage" and not c.selfDamage then
                used.hit, used.reduction = true, true
            end
            if parsed.school ~= "Physical" and not c.selfDamage then
                used[periodic and "dotCoefficient" or "coefficient"] = true
            end
        end
        if used.power and (rank.level or 60) < 20 and build.level > (rank.level or 60) + 10 then
            used.scalingFactor = true
        end
        local points, index = FT.Model.Counts(build), FT.Model.Index(build.classID)
        for id in pairs(points) do
            local rule = modifierRules[index[id].name]
            if rule and ruleApplies(rule, build, skill, parsed, state, true) then
                if rule.condition then
                    used[rule.condition] = true
                end
                if rule.creatures then
                    used.targetType = true
                end
                if rule.form then
                    used.form = true
                end
                if rule.weapon then
                    used.weaponType = true
                end
            end
        end
        for _, trait in ipairs(FT.Data.racials[build.classID][build.raceID] or {}) do
            if
                trait.name:find("Specialization", 1, true)
                and trait.text:find("critical", 1, true)
                and used.crit
            then
                used[state.racialWeaponType and "racialWeaponType" or "weaponType"] = true
            end
            if
                trait.name == "Blood Fury" and (used.power or used.attackPower or used.weaponMin)
            then
                used.cooldowns = true
                if state.cooldowns and used.weaponMin then
                    used.attackPower, used.weaponSpeed = true, true
                end
            end
            if trait.name == "Elune's Light" and used.crit then
                used.cooldowns = true
            end
            if
                parsed.kind == "damage"
                and (
                    trait.name == "Beast Slaying"
                    or trait.name == "Big Game Hunter"
                    or trait.name == "Elemental Insight"
                )
            then
                used.targetType = true
            end
        end
    end
    if state.manual then
        used.baseMin, used.baseMax, used.periodicBase = true, true, true
    end
    local out = {}
    for _, key in ipairs({
        "effectMode",
        "power",
        "attackPower",
        "weaponMin",
        "weaponMax",
        "crit",
        "hit",
        "reduction",
        "comboPoints",
        "rage",
        "bleeding",
        "frozen",
        "executeRange",
        "cooldowns",
        "targetType",
        "coefficient",
        "dotCoefficient",
        "apCoefficient",
        "dotAPCoefficient",
        "scalingFactor",
        "weaponSpeed",
        "weaponType",
        "racialWeaponType",
        "form",
        "extra",
        "baseMin",
        "baseMax",
        "periodicBase",
    }) do
        if used[key] then
            local definition = inputDefinitions[key]
            local label = definition[1]
            if key == "power" then
                label = (
                    parsed.kind == "healing"
                    or (parsed.kind == "absorption" and skill.name == "Power Word: Shield")
                )
                        and "Healing power"
                    or "Spell power"
            end
            out[#out + 1] = {
                key = key,
                label = label,
                help = definition[2],
                group = definition[3],
                min = definition[4] or 0,
                max = definition[5]
                    or ((key == "crit" or key == "hit" or key == "reduction") and 100 or 100000),
                type = definition[3] == "condition" and key ~= "targetType" and "boolean"
                    or (key == "targetType" or key == "weaponType" or key == "racialWeaponType" or key == "effectMode" or key == "form") and "choice"
                    or "number",
                choices = key == "effectMode" and parsed.effectModes or nil,
                value = key == "effectMode" and parsed.effectMode or state[key],
            }
        end
    end
    return out
end
