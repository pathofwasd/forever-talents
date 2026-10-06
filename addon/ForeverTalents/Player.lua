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
local function integer(value, minimum, maximum)
    return type(value) == "number" and value % 1 == 0 and value >= minimum and value <= maximum
end
local function array(value, minimum, maximum)
    if type(value) ~= "table" or #value < minimum or #value > maximum then
        return false
    end
    local count = 0
    for key in pairs(value) do
        if not integer(key, 1, #value) then
            return false
        end
        count = count + 1
    end
    return count == #value
end
local function activeTraitConfig()
    if C_SpecializationInfo and C_SpecializationInfo.GetCombatConfigIDForSpecGroup then
        local group = safe(C_SpecializationInfo.GetActiveSpecGroup, false, false)
        return group and safe(C_SpecializationInfo.GetCombatConfigIDForSpecGroup, group)
    end
    return safe(C_ClassTalents and C_ClassTalents.GetActiveConfigID)
end
local function readTraitRanks(class)
    local api = C_Traits
    local configID = activeTraitConfig()
    if not integer(configID, 1, 2147483647) then
        return false,
            "Active talents are not ready. Open the game's Talents window and retry; your draft is preserved."
    end
    local staged = safe(api.ConfigHasStagedChanges, configID)
    if staged == nil then
        return false,
            "Talent configuration could not be checked. Open Talents and retry; your draft is preserved."
    elseif staged then
        return false,
            "Apply or cancel pending changes in the game's Talents window, then retry importing."
    end
    local config = safe(api.GetConfigInfo, configID)
    if not config or not array(config.treeIDs, 1, 16) then
        return false, "The active talent configuration is unavailable. Open Talents and retry."
    end
    local bySpell, expected = {}, 0
    for _, tree in ipairs(class.trees) do
        for _, talent in ipairs(tree.talents) do
            expected = expected + 1
            for _, rank in ipairs(talent.ranks) do
                bySpell[rank.spellID] = talent
            end
        end
    end
    local ranks, seenTrees, seenNodes, observed = {}, {}, {}, 0
    for _, treeID in ipairs(config.treeIDs) do
        if not integer(treeID, 1, 2147483647) or seenTrees[treeID] then
            return false,
                "The client returned invalid talent trees. Import stopped; your draft is preserved."
        end
        seenTrees[treeID] = true
        local nodes = safe(api.GetTreeNodes, treeID)
        if not array(nodes, 1, 1024) then
            return false,
                "Talent nodes are not ready. Open Talents and retry; your draft is preserved."
        end
        local points = 0
        for _, nodeID in ipairs(nodes) do
            if not integer(nodeID, 1, 2147483647) or seenNodes[nodeID] then
                return false,
                    "The client returned duplicate or invalid talent nodes. Import stopped."
            end
            seenNodes[nodeID] = true
            local node = safe(api.GetNodeInfo, configID, nodeID)
            if
                not node
                or not integer(node.ranksPurchased, 0, 51)
                or not array(node.entryIDs, 0, 16)
            then
                return false,
                    "A talent node could not be read. Open Talents and retry; your draft is preserved."
            end
            local talent
            for _, entryID in ipairs(node.entryIDs) do
                local entry = safe(api.GetEntryInfo, configID, entryID)
                local definition = entry and safe(api.GetDefinitionInfo, entry.definitionID)
                if not definition then
                    return false,
                        "A talent spell could not be read. Open Talents and retry; your draft is preserved."
                end
                local matched = bySpell[definition.spellID] or bySpell[definition.overriddenSpellID]
                if matched then
                    if talent and talent ~= matched then
                        return false,
                            "The client has talent choices outside this dataset. Update Forever Talents before importing."
                    end
                    talent = matched
                elseif node.isVisible ~= false or node.ranksPurchased > 0 then
                    return false,
                        "The client has talent spells outside this dataset. Update Forever Talents before importing."
                end
            end
            if talent then
                if
                    node.maxRanks ~= talent.max
                    or node.ranksPurchased > talent.max
                    or ranks[talent.id] ~= nil
                then
                    return false,
                        "The client's talent ranks differ from this dataset. Update Forever Talents before importing."
                end
                -- Purchased ranks are the allocated points. activeRank can also
                -- contain granted ranks; preview edits must never become a capture.
                ranks[talent.id] = node.ranksPurchased
                observed = observed + 1
                points = points + node.ranksPurchased
            elseif node.ranksPurchased > 0 then
                return false,
                    "A purchased talent could not be matched. Import stopped; your draft is preserved."
            end
        end
        if api.GetTreeCurrencyInfo then
            local currencies = safe(api.GetTreeCurrencyInfo, configID, treeID, true)
            if not array(currencies, 1, 16) then
                return false, "Talent point totals are not ready. Open Talents and retry."
            end
            local spent, complete = 0, true
            for _, currency in ipairs(currencies) do
                local amount = currency.spentInTree
                if amount == nil and #config.treeIDs == 1 then
                    amount = currency.spent
                end
                if integer(amount, 0, 51) then
                    spent = spent + amount
                else
                    complete = false
                end
            end
            if complete and spent ~= points then
                return false,
                    "Read talents do not match the client's spent-point total. Open Talents and retry."
            end
        end
    end
    if observed ~= expected then
        return false,
            string.format(
                "Read %d of %d talents. Open Talents and retry; your draft is preserved.",
                observed,
                expected
            )
    end
    if activeTraitConfig() ~= configID or safe(api.ConfigHasStagedChanges, configID) ~= false then
        return false,
            "Active talents changed during capture. Finish your changes, then retry importing."
    end
    return ranks
end
function FT.ReadPlayerBuild()
    local _, _, cid = UnitClass("player")
    local _, _, rid = UnitRace("player")
    local class = M.Class(cid)
    if not class then
        return false, "This character's class is outside this dataset."
    end
    local level = safe(UnitLevel, "player")
    if type(level) ~= "number" or level < 1 then
        return false, "Character level is not ready."
    end
    -- Forever (Camelot) uses a C_Traits combat configuration. The deprecated
    -- Classic namespace still exists but may return no records at all.
    if
        C_Traits
        and C_Traits.GetNodeInfo
        and (
            C_ClassTalents and C_ClassTalents.GetActiveConfigID
            or C_SpecializationInfo and C_SpecializationInfo.GetCombatConfigIDForSpecGroup
        )
    then
        local ranks, why = readTraitRanks(class)
        if not ranks then
            return false, why
        end
        return M.FromRanks(cid, rid, math.min(60, level), ranks, "My " .. class.name .. " talents")
    end
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
            "Talent data is not ready. Open the game's Talents window, then retry Import my talents & skills."
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
    return M.FromRanks(cid, rid, math.min(60, level), ranks, "My " .. class.name .. " talents")
end
function FT.ReadPlayerSkills()
    local _, _, cid = UnitClass("player")
    local _, _, rid = UnitRace("player")
    local ids, seen = {}, {}
    local modern = C_SpellBook
        and C_SpellBook.GetNumSpellBookSkillLines
        and C_SpellBook.GetSpellBookSkillLineInfo
        and C_SpellBook.GetSpellBookItemInfo
        and Enum
        and Enum.SpellBookItemType
        and Enum.SpellBookSpellBank
    local legacy = GetNumSpellTabs and GetSpellTabInfo and GetSpellBookItemInfo
    local tabs =
        safe(legacy and GetNumSpellTabs or (modern and C_SpellBook.GetNumSpellBookSkillLines))
    if type(tabs) ~= "number" or tabs < 1 or tabs > 32 then
        return nil,
            "Spellbook data is not ready. Open Spellbook and retry; your current capture is kept."
    end
    local visited = 0
    for tab = 1, tabs do
        local offset, count, offspec
        if legacy then
            local _, _, first, total, _, other = safe(GetSpellTabInfo, tab)
            offset, count, offspec = first, total, other
        else
            local info = safe(C_SpellBook.GetSpellBookSkillLineInfo, tab)
            if info then
                offset, count, offspec =
                    info.itemIndexOffset, info.numSpellBookItems, info.offSpecID
            end
        end
        if
            type(offset) ~= "number"
            or type(count) ~= "number"
            or offset < 0
            or count < 0
            or offset % 1 ~= 0
            or count % 1 ~= 0
            or offset + count > 4096
        then
            return nil, "Some spellbook tabs could not be read. Open Spellbook and retry."
        end
        if not offspec or offspec == 0 then
            for slot = offset + 1, offset + count do
                visited = visited + 1
                if visited > 4096 then
                    return nil, "Spellbook is unexpectedly large; capture stopped."
                end
                local kind, id, other
                if legacy then
                    kind, id = safe(GetSpellBookItemInfo, slot, BOOKTYPE_SPELL or "spell")
                    if not kind then
                        return nil, "A spellbook entry is not ready. Open Spellbook and retry."
                    end
                    kind = kind == "SPELL"
                else
                    local info =
                        safe(C_SpellBook.GetSpellBookItemInfo, slot, Enum.SpellBookSpellBank.Player)
                    if not info then
                        return nil, "A spellbook entry is not ready. Open Spellbook and retry."
                    end
                    kind, id, other =
                        info.itemType == Enum.SpellBookItemType.Spell, info.spellID, info.isOffSpec
                end
                if kind and not other then
                    if type(id) ~= "number" or id % 1 ~= 0 or id < 1 or id > 10000000 then
                        return nil,
                            "A learned spell ID could not be read. Open Spellbook and retry."
                    end
                    if not seen[id] then
                        ids[#ids + 1], seen[id] = id, true
                    end
                end
            end
        end
    end
    return FT.Skills.NormalizeTraining({
        schema = 1,
        classID = cid,
        raceID = rid,
        level = math.min(60, safe(UnitLevel, "player") or 0),
        spellIDs = ids,
    })
end

function FT.ReadPlayerSnapshot()
    local build, why = FT.ReadPlayerBuild()
    if not build then
        return nil, why
    end
    local trained
    trained, why = FT.ReadPlayerSkills()
    if not trained then
        return nil, why
    end
    local stats = FT.ReadPlayerStats()
    stats.character.trainedSkills = trained
    return { kind = "character", build = build, stats = stats }
end

function FT.ImportPlayerCharacter()
    local snapshot, why = FT.ReadPlayerSnapshot()
    if not snapshot then
        return false, why
    end
    local ok, message = P.Apply(snapshot)
    if ok then
        FT.UI.skillFilterKey = "trained"
        FT.UI.RefreshBrowser()
        message =
            "Imported talents, trained skills, level, stats and gear. Talent order is reconstructed."
        FT.UI.Status(message)
    end
    return ok, message
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
    profile.trainedSkills = FT.ReadPlayerSkills()
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
