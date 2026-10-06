local _, FT = ...
local A = { cache = {} }
FT.Skills = A

local function normalize(text)
    return (text or "")
        :lower()
        :gsub("’", "'")
        :gsub("‘", "'")
        :gsub("[^%w]+", " ")
        :gsub("^%s+", "")
        :gsub("%s+$", "")
end

local function mentions(text, name)
    text, name = " " .. normalize(text) .. " ", normalize(name)
    return name ~= "" and text:find(" " .. name .. " ", 1, true) ~= nil
end

local function rankText(skill)
    local out = {}
    for _, rank in ipairs(skill.ranks or {}) do
        out[#out + 1] = rank.text or ""
    end
    return table.concat(out, " ")
end

local schools = { "Arcane", "Fire", "Frost", "Holy", "Nature", "Shadow" }
local function firstLiveRank(skill)
    for _, rank in ipairs(skill.ranks or {}) do
        if
            rank.live
            and (not rank.toLevel or rank.toLevel >= math.max(rank.level, rank.fromLevel or 1))
        then
            return rank
        end
    end
end

local function relation(skill, talent)
    local text, ttext = rankText(skill), talent.ranks[#talent.ranks].text
    if skill.unlock and skill.unlock.id == talent.id then
        return "Unlocked by this talent.", "unlock"
    end
    if mentions(ttext, skill.name) then
        return "Talent description names " .. skill.name .. ".", "direct"
    end
    if mentions(text, talent.name) then
        return "Skill description names " .. talent.name .. ".", "direct"
    end
    -- School-wide modifiers also interact with individual damaging/healing
    -- spells. Label this contextual evidence separately from explicit links.
    local low, tlow = text:lower(), ttext:lower()
    local healing = low:find("heals", 1, true)
        or (low:find("restores", 1, true) and low:find("health", 1, true))
    local damage = low:find("damage", 1, true)
        and not low:find("absorbs", 1, true)
        and (
            low:find("deals", 1, true)
            or low:find("causes", 1, true)
            or low:find("causing", 1, true)
            or low:find("burns", 1, true)
            or low:find("inflicts", 1, true)
            or low:find("bleed", 1, true)
            or low:find("weapon damage", 1, true)
            or low:find("melee damage", 1, true)
            or low:find("shoots", 1, true)
            or low:find("fires", 1, true)
        )
    local periodic = low:find(" over ", 1, true)
        or low:find(" every ", 1, true)
        or low:find("per second", 1, true)
        or low:find("bleed", 1, true)
    if tlow:find("periodic", 1, true) and not periodic then
        return
    end
    if
        healing and (tlow:find("healing spells", 1, true) or tlow:find("healing done by", 1, true))
    then
        return "General healing spell modifier described by this talent.", "general"
    end
    local numeric = tlow:find("damage", 1, true)
        or tlow:find("critical", 1, true)
        or tlow:find("mana cost", 1, true)
        or tlow:find("cast time", 1, true)
    if
        damage
        and numeric
        and (
            tlow:find("your spells", 1, true)
            or tlow:find("all your spells", 1, true)
            or tlow:find("with spells", 1, true)
            or tlow:find("damaging spells", 1, true)
        )
    then
        return "General spell modifier described by this talent.", "general"
    end
    local physical = damage
        and not (
            low:find("fire damage", 1, true)
            or low:find("frost damage", 1, true)
            or low:find("nature damage", 1, true)
            or low:find("arcane damage", 1, true)
            or low:find("holy damage", 1, true)
            or low:find("shadow damage", 1, true)
        )
    if
        physical
        and numeric
        and (
            tlow:find("melee abilities", 1, true)
            or tlow:find("your abilities", 1, true)
            or tlow:find("physical damage", 1, true)
        )
    then
        return "General physical ability modifier described by this talent.", "general"
    end
    for _, school in ipairs(schools) do
        local s = school:lower()
        local isDamage = damage and low:find(s .. " damage", 1, true) ~= nil
        local isSchoolSpell = isDamage
            or (healing and skill.icon:find("spell_" .. s .. "_", 1, true))
        if
            isSchoolSpell
            and (tlow:find(s .. " spells", 1, true) or tlow:find(s .. " spell", 1, true) or (tlow:find(
                s,
                1,
                true
            ) and tlow:find("spells", 1, true)))
            and (
                tlow:find("damage", 1, true)
                or tlow:find("critical", 1, true)
                or tlow:find("mana cost", 1, true)
                or tlow:find("cast time", 1, true)
            )
        then
            return school .. " spell interaction described by this talent.", "school"
        end
    end
end

function A.Prepare(classID)
    if A.cache[classID] then
        return A.cache[classID]
    end
    local c = FT.Model.Class(classID)
    local index = FT.Model.Index(classID)
    local list, byName = {}, {}
    for _, s in ipairs(c.skills) do
        if firstLiveRank(s) then
            local skill = FT.Copy(s)
            skill.kind, skill.related = "trained", {}
            list[#list + 1], byName[skill.name] = skill, skill
        end
    end
    for _, tree in ipairs(c.trees) do
        for _, t in ipairs(tree.talents) do
            local skill = byName[t.name]
            if skill then
                skill.unlock, skill.kind = t, "talent"
                local first = firstLiveRank(skill)
                local firstNumber = tonumber((first.label or ""):match("^Rank (%d+)$"))
                -- Upgrade lists omit the rank granted by the talent itself.
                -- A recorded Rank 1 may use a cast-spell alias (e.g. Mutilate).
                if t.max == 1 and firstNumber and firstNumber > 1 then
                    local unlockLevel = 10 + t.gate
                    table.insert(skill.ranks, 1, {
                        spellID = t.ranks[1].spellID,
                        label = "Rank 1",
                        level = unlockLevel,
                        fromLevel = unlockLevel,
                        toLevel = math.max(first.level, first.fromLevel or 1) - 1,
                        live = true,
                        talentGranted = true,
                        text = t.ranks[1].text,
                    })
                end
            elseif t.max == 1 then
                skill = {
                    name = t.name,
                    icon = t.icon,
                    kind = "talent",
                    unlock = t,
                    related = {},
                    ranks = {
                        {
                            spellID = t.ranks[1].spellID,
                            label = "Talent",
                            level = 10 + t.gate,
                            live = true,
                            talentGranted = true,
                            text = t.ranks[1].text,
                        },
                    },
                }
                list[#list + 1], byName[t.name] = skill, skill
            end
        end
    end
    for _, skill in ipairs(list) do
        for _, tree in ipairs(c.trees) do
            for _, t in ipairs(tree.talents) do
                local why, kind = relation(skill, t)
                if why then
                    skill.related[#skill.related + 1] = { id = t.id, reason = why, kind = kind }
                end
            end
        end
        skill.firstLevel = skill.ranks[1].level
        skill.search = normalize(
            skill.name
                .. " "
                .. rankText(skill)
                .. " "
                .. (skill.unlock and skill.unlock.treeName or "")
        )
    end
    table.sort(list, function(a, b)
        if a.firstLevel == b.firstLevel then
            return a.name < b.name
        end
        return a.firstLevel < b.firstLevel
    end)
    local result = { list = list, byName = byName, index = index }
    A.cache[classID] = result
    return result
end

function A.CurrentRank(skill, level, points)
    if skill.unlock and (points[skill.unlock.id] or 0) == 0 then
        return nil
    end
    local current
    for _, rank in ipairs(skill.ranks) do
        if
            rank.live
            and rank.level <= level
            and (not rank.fromLevel or rank.fromLevel <= level)
            and (not rank.toLevel or rank.toLevel >= level)
            and (not rank.talentRank or (points[skill.unlock.id] or 0) >= rank.talentRank)
        then
            current = rank
        end
    end
    return current
end

function A.List(build, level, query, filter, includeRacials)
    local prepared = A.Prepare(build.classID)
    local list, points = {}, FT.Model.Counts(build)
    query = normalize(query)
    for _, skill in ipairs(prepared.list) do
        local rank = A.CurrentRank(skill, level, points)
        if
            (query == "" or skill.search:find(query, 1, true))
            and (
                not filter
                or filter == "all"
                or (filter == "now" and rank)
                or (filter == "talent" and skill.unlock)
            )
        then
            list[#list + 1] = { skill = skill, current = rank }
        end
    end
    if
        includeRacials ~= false
        and (not filter or filter == "all" or filter == "racial" or filter == "now")
    then
        for _, r in ipairs(FT.Data.racials[build.classID][build.raceID] or {}) do
            if query == "" or normalize(r.name .. " " .. r.text):find(query, 1, true) then
                list[#list + 1] = {
                    skill = {
                        name = r.name,
                        icon = r.icon,
                        kind = "racial",
                        firstLevel = 1,
                        related = {},
                        ranks = {
                            {
                                spellID = r.spellID,
                                label = "Racial",
                                level = 1,
                                live = true,
                                text = r.text,
                            },
                        },
                    },
                    current = { spellID = r.spellID, level = 1, label = "Racial", text = r.text },
                }
            end
        end
    end
    return list
end

-- The compact view derives its progression from the same live rank records.
function A.Levels(skill)
    local levels = {}
    local unlockLevel = skill.unlock and (10 + skill.unlock.gate)
    for _, rank in ipairs(skill.ranks) do
        if rank.live then
            local talentLevel = unlockLevel and (unlockLevel + (rank.talentRank or 1) - 1) or 1
            local level = math.max(rank.level, rank.fromLevel or 1, talentLevel)
            if not rank.toLevel or rank.toLevel >= level then
                levels[#levels + 1] = {
                    label = rank.label ~= "" and rank.label or "Ability",
                    level = level,
                    toLevel = rank.toLevel,
                    talentRank = rank.talentRank,
                    talentGranted = rank.talentGranted,
                }
            end
        end
    end
    return levels, unlockLevel
end

function A.SearchTalent(talent, query)
    query = normalize(query)
    if query == "" then
        return true
    end
    local texts = { talent.name, talent.treeName }
    for _, rank in ipairs(talent.ranks) do
        texts[#texts + 1] = rank.text
    end
    return normalize(table.concat(texts, " ")):find(query, 1, true) ~= nil
end

function A.TalentSkills(classID, talentID)
    local list = {}
    for _, skill in ipairs(A.Prepare(classID).list) do
        for _, link in ipairs(skill.related) do
            if link.id == talentID then
                list[#list + 1] = skill.name
                break
            end
        end
    end
    return list
end
