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
