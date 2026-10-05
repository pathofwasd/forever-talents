local _, FT = ...
local M, Sim, P = FT.Model, FT.Simulation, FT.Snapshot
local function safe(fn, ...)
    if type(fn) ~= "function" then
        return nil
    end
    local function capture(...)
        return { n = select("#", ...), ... }
    end
    local values = capture(pcall(fn, ...))
    if not values[1] then
        return nil
    end
    return unpack(values, 2, values.n)
end
function FT.ReadPlayerBuild()
    local modern = C_SpecializationInfo and C_SpecializationInfo.GetTalentInfo
    if not GetTalentInfo and not modern then
        return false,
            "Classic talent APIs are unavailable. Open the game's Talents window and try again, or paste a build string."
    end
    if
        C_SpecializationInfo
        and C_SpecializationInfo.IsInitialized
        and not safe(C_SpecializationInfo.IsInitialized)
    then
        return false,
            "Talent data is not ready. Open the game's Talents window, then try My character again."
    end
    local _, _, cid = UnitClass("player")
    local _, _, rid = UnitRace("player")
    local class = M.Class(cid)
    if not class then
        return false, "This character's class is outside this dataset."
    end
    local group = safe(C_SpecializationInfo and C_SpecializationInfo.GetActiveSpecGroup)
        or safe(GetActiveTalentGroup)
        or 1
    local tabs = safe(GetNumTalentTabs, false, false)
    if tabs and tabs ~= #class.trees then
        return false, "The client talent trees differ from this dataset."
    end
    local ranks, observed = {}, 0
    local function consume(tree, info)
        if
            not info
            or type(info.rank) ~= "number"
            or type(info.tier) ~= "number"
            or type(info.column) ~= "number"
        then
            return false,
                "Talent rank data is unavailable. Open Talents and retry; your draft is preserved."
        end
        local found
        for _, t in ipairs(tree.talents) do
            if t.row == info.tier - 1 and t.col == info.column - 1 and t.max == info.maxRank then
                found = t
                break
            end
        end
        if not found then
            return false,
                "The client's talent layout or ranks differ from the captured dataset. Import stopped; your draft is preserved."
        end
        if ranks[found.id] ~= nil then
            return false, "Client returned duplicate talent coordinates."
        end
        -- Coordinates and maximum rank work in localized clients too. Spell
        -- IDs/names are supplementary; IDs may change between beta builds.
        ranks[found.id] = info.rank
        observed = observed + 1
        return true
    end
    for tab, tree in ipairs(class.trees) do
        local count = safe(GetNumTalents, tab, false, false) or #tree.talents
        if count ~= #tree.talents then
            return false,
                "The client's talent count differs from this dataset. Update Forever Talents before importing."
        end
        local coordinateMode = false
        if modern then
            local first = safe(modern, {
                specializationIndex = tab,
                talentIndex = 1,
                isInspect = false,
                isPet = false,
                groupIndex = group,
            })
            coordinateMode = not first or type(first.rank) ~= "number"
        end
        if coordinateMode then
            for row = 1, 7 do
                for col = 1, 4 do
                    local info = safe(modern, {
                        specializationIndex = tab,
                        tier = row,
                        column = col,
                        isInspect = false,
                        isPet = false,
                        groupIndex = group,
                    })
                    if info and info.name and info.name ~= "" then
                        local ok, why = consume(tree, info)
                        if not ok then
                            return false, why
                        end
                    end
                end
            end
        else
            for n = 1, count do
                local info = modern
                    and safe(modern, {
                        specializationIndex = tab,
                        talentIndex = n,
                        isInspect = false,
                        isPet = false,
                        groupIndex = group,
                    })
                if not info and GetTalentInfo then
                    local name, icon, row, col, rank, max =
                        safe(GetTalentInfo, tab, n, false, false, group)
                    info = {
                        name = name,
                        icon = icon,
                        tier = row,
                        column = col,
                        rank = rank,
                        maxRank = max,
                    }
                end
                local ok, why = consume(tree, info)
                if not ok then
                    return false, why
                end
            end
        end
        local points = 0
        for _, t in ipairs(tree.talents) do
            if ranks[t.id] == nil then
                return false,
                    "Some client talents could not be read. Import stopped rather than loading an empty or partial build."
            end
            points = points + ranks[t.id]
        end
        if C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo then
            local values = {
                safe(
                    C_SpecializationInfo.GetSpecializationInfo,
                    tab,
                    false,
                    false,
                    nil,
                    nil,
                    group
                ),
            }
            if type(values[7]) == "number" and values[7] ~= points then
                return false,
                    "Read ranks do not match the client's spent-point total. Open Talents and retry."
            end
        end
    end
    local level = safe(UnitLevel, "player")
    if type(level) ~= "number" or level < 1 then
        return false, "Character level is not ready."
    end
    return M.FromRanks(cid, rid, math.min(60, level), ranks, "My " .. class.name .. " talents")
end
function FT.ReadPlayerStats(skill, rank)
    local _, _, cid = UnitClass("player")
    local _, _, rid = UnitRace("player")
    local build = M.New(cid, rid, math.min(60, math.max(1, safe(UnitLevel, "player") or 1)))
    local state = Sim.Defaults()
    local raw = { power = {}, crit = {} }
    for i = 1, 7 do
        raw.power[i] = safe(GetSpellBonusDamage, i)
        raw.crit[i] = safe(GetSpellCritChance, i)
    end
    local rangedBase, rangedPos, rangedNeg = safe(UnitRangedAttackPower, "player")
    if rangedBase then
        raw.rangedAP = rangedBase + (rangedPos or 0) + (rangedNeg or 0)
    end
    local rangedSpeed, rangedMin, rangedMax = safe(UnitRangedDamage, "player")
    raw.rangedMin, raw.rangedMax = rangedMin, rangedMax
    raw.rangedSpeed = rangedSpeed
    raw.healing = safe(GetSpellBonusHealing)
    raw.meleeCrit = safe(GetCritChance)
    raw.rangedCrit = safe(GetRangedCritChance)
    local base, pos, neg = safe(UnitAttackPower, "player")
    if base then
        state.attackPower = base + (pos or 0) + (neg or 0)
    end
    local low, high = safe(UnitDamage, "player")
    if low then
        state.weaponMin, state.weaponMax = low, high or low
    end
    state.power = raw.power[7] or 0
    state.crit = raw.meleeCrit or raw.crit[7] or 5
    local profile = P.Stats(
        state,
        build,
        skill and skill.name or "",
        "Live reported stats; gear and buffs can be included. Hit/reduction and target states remain assumptions."
    )
    profile.raw = raw
    profile.attributes = {}
    for i, key in ipairs({ "strength", "agility", "stamina", "intellect", "spirit" }) do
        local base, total = safe(UnitStat, "player", i)
        profile.attributes[key] = total or base
    end
    profile.attributes.health = safe(UnitHealthMax, "player")
    profile.attributes.mana = safe(UnitPowerMax, "player", 0)
    local baseArmor, effectiveArmor = safe(UnitArmor, "player")
    profile.attributes.armor = effectiveArmor or baseArmor
    local gear, pending = FT.ReadPlayerEquipment()
    profile.equipmentPending = pending
    local formID = safe(GetShapeshiftFormID)
    profile.form = cid == 11
            and ((formID == 1 and "cat") or ((formID == 5 or formID == 8) and "bear"))
        or "caster"
    profile.weaponType = gear.mainHand and gear.mainHand.weaponType or "none"
    profile.weaponSpeed = gear.mainHand and gear.mainHand.speed
    if pending > 0 then
        profile.note = FT.SafeText(
            profile.note .. " Some item data is loading; capture again after opening Character.",
            256
        )
    end
    local learned, why = FT.ReadPlayerBuild()
    if learned then
        profile.learnedCode = FT.Codec.Encode(learned)
    else
        profile.note = FT.SafeText(
            profile.note .. " Talents unreadable: crit bonuses may need manual adjustment.",
            256
        )
    end
    if skill and rank then
        profile.state, profile.note = P.ForSkill(profile, skill, rank, build)
    end
    profile.character = FT.Character.FromSnapshot(profile, gear)
    return profile
end
function FT.ImportPlayer()
    local build, why = FT.ReadPlayerBuild()
    if not build then
        return false, why
    end
    FT.UI.ImportDialog(FT.Codec.Encode(build))
    FT.UI.Status(
        "My talents reads a legal derived order. The client cannot report the original point-spending order."
    )
    return true
end

-- Equipped item capture stays native. Browser imports contain names/bonuses, not a game connection.
function FT.ReadPlayerEquipment()
    local gear, pending = {}, 0
    local fields = {
        ITEM_MOD_STRENGTH_SHORT = "strength",
        ITEM_MOD_AGILITY_SHORT = "agility",
        ITEM_MOD_STAMINA_SHORT = "stamina",
        ITEM_MOD_INTELLECT_SHORT = "intellect",
        ITEM_MOD_SPIRIT_SHORT = "spirit",
        ITEM_MOD_ATTACK_POWER_SHORT = "attackPower",
        ITEM_MOD_RANGED_ATTACK_POWER_SHORT = "rangedAP",
        ITEM_MOD_SPELL_POWER_SHORT = "power",
        ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = "damagePower",
        ITEM_MOD_SPELL_HEALING_DONE_SHORT = "healing",
        ITEM_MOD_HEALTH_SHORT = "health",
        ITEM_MOD_MANA_SHORT = "mana",
        RESISTANCE0_NAME = "armor",
    }
    local subclasses = {
        [0] = "axe",
        [1] = "twoAxe",
        [2] = "bow",
        [3] = "gun",
        [4] = "mace",
        [5] = "twoMace",
        [6] = "polearm",
        [7] = "sword",
        [8] = "twoSword",
        [10] = "staff",
        [13] = "fist",
        [15] = "dagger",
        [18] = "crossbow",
    }
    for _, slot in ipairs(FT.Character.slots) do
        local link = safe(GetInventoryItemLink, "player", slot.id)
        if link then
            local id = tonumber(link:match("item:(%d+)"))
            local name = safe(GetItemInfo, link)
            local readStats = C_Item and C_Item.GetItemStats or GetItemStats
            local stats = safe(readStats, link) or {}
            local values = {}
            for key, value in pairs(stats) do
                if fields[key] then
                    values[fields[key]] = (values[fields[key]] or 0) + value
                end
            end
            local instant = C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant
            local _, _, _, _, _, classID, subclassID = safe(instant, link)
            local item = {
                name = name or ("Item " .. (id or 0)),
                itemID = id,
                stats = values,
                weaponType = classID == 2 and subclasses[subclassID] or "none",
                captured = true,
            }
            local tooltip = C_TooltipInfo
                and safe(C_TooltipInfo.GetInventoryItem, "player", slot.id)
            if tooltip then
                for _, line in ipairs(tooltip.lines or {}) do
                    local text = ((line.leftText or "") .. " " .. (line.rightText or ""))
                        :gsub("|c%x%x%x%x%x%x%x%x", "")
                        :gsub("|r", "")
                    local low, high = text:match("([%d%.]+)%s*%-%s*([%d%.]+)%s+[Dd]amage")
                    if low then
                        item.low, item.high = tonumber(low), tonumber(high)
                    end
                    local speed = text:match("[Ss]peed%s+([%d%.]+)")
                    if speed then
                        item.speed = tonumber(speed)
                    end
                end
            end
            if not name then
                pending = pending + 1
                if C_Item and C_Item.RequestLoadItemDataByID and id then
                    pcall(C_Item.RequestLoadItemDataByID, id)
                end
            end
            gear[slot.key] = item
        end
    end
    return gear, pending
end
