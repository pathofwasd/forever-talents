local _, FT = ...
local A = { cache = {} }
FT.Skills = A

-- Client base values are reference tooltips, not a live cooldown timer or a
-- prediction after talents, haste, gear and temporary effects.
function A.AbilityDetails(rank)
    local snapshot = FT.Data.spellDetails
    local detail = snapshot and snapshot.spells[rank.spellID]
    if not detail then
        return "Base cast time and cooldown are not recorded for this spell."
    end
    if detail.passive then
        return detail.procCooldown
                and ("Passive • Proc interval: " .. string.format("%g", detail.procCooldown) .. " sec")
            or "Passive"
    end
    local function seconds(value)
        return string.format("%g", value) .. " sec"
    end
    local lines = {}
    if detail.channel then
        lines[#lines + 1] = detail.channelDuration
                and ("Channeled • " .. seconds(detail.channelDuration))
            or "Channeled"
    elseif detail.cast then
        lines[#lines + 1] = detail.cast == 0 and "Instant" or (seconds(detail.cast) .. " cast")
    else
        lines[#lines + 1] = "Cast time not recorded"
    end
    if detail.cooldown and detail.cooldown > 0 then
        lines[#lines + 1] = "Cooldown: " .. seconds(detail.cooldown)
    else
        lines[#lines + 1] = "No ability cooldown recorded"
    end
    if detail.procCooldown then
        lines[#lines + 1] = "Proc interval: " .. seconds(detail.procCooldown)
    end
    if detail.manaCost then
        lines[#lines + 1] = string.format("%g", detail.manaCost) .. " Mana"
    end
    if detail.globalCooldown and detail.globalCooldown > 0 then
        lines[#lines + 1] = "Global cooldown: " .. seconds(detail.globalCooldown)
    end
    if detail.rangeMax and detail.rangeMax > 0 then
        lines[#lines + 1] = detail.range == "Combat Range" and "Melee range"
            or (string.format("%g", detail.rangeMax) .. " yd range")
    elseif detail.range == "Self Only" then
        lines[#lines + 1] = "Self"
    end
    return table.concat(lines, " • ")
end

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
        or low:find("healing to an ally", 1, true)
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
        healing
        and (
            tlow:find("healing spells", 1, true)
            or tlow:find("healing done by", 1, true)
            or tlow:find("spell healing", 1, true)
        )
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
            skill.ranks, skill.aliases = {}, {}
            for _, rank in ipairs(s.ranks) do
                if rank.aliasOf then
                    skill.aliases[rank.spellID] = rank.aliasOf
                elseif not rank.referenceOnly then
                    skill.ranks[#skill.ranks + 1] = FT.Copy(rank)
                end
            end
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
                        textLevel = t.ranks[1].textLevel,
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
                            textLevel = t.ranks[1].textLevel,
                        },
                    },
                }
                list[#list + 1], byName[t.name] = skill, skill
            end
        end
    end
    for _, skill in ipairs(list) do
        for _, rank in ipairs(skill.ranks) do
            rank.abilityDetails = A.AbilityDetails(rank)
        end
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

-- Spellbook snapshots stay separate from a planned build's level and talents.
function A.NormalizeTraining(raw)
    if
        type(raw) ~= "table"
        or raw.schema ~= 1
        or not FT.Model.Class(raw.classID)
        or not FT.Model.RaceAllowed(raw.classID, raw.raceID)
        or type(raw.level) ~= "number"
        or raw.level % 1 ~= 0
        or raw.level < 1
        or raw.level > 60
        or type(raw.spellIDs) ~= "table"
    then
        return nil, "Invalid trained-skill snapshot."
    end
    local ids, seen, count = {}, {}, 0
    for key, id in pairs(raw.spellIDs) do
        count = count + 1
        if
            count > 2048
            or type(key) ~= "number"
            or key % 1 ~= 0
            or key < 1
            or key > 2048
            or type(id) ~= "number"
            or id % 1 ~= 0
            or id < 1
            or id > 10000000
            or seen[id]
        then
            return nil, "Invalid trained spell IDs."
        end
        seen[id], ids[key] = true, id
    end
    for i = 1, count do
        if not ids[i] then
            return nil, "Incomplete trained spell list."
        end
    end
    if count == 0 then
        return nil, "The spellbook is empty or not ready. Open Spellbook and retry."
    end
    table.sort(ids)
    return {
        schema = 1,
        classID = raw.classID,
        raceID = raw.raceID,
        level = raw.level,
        spellIDs = ids,
    }
end

function A.TrainedRank(skill, snapshot)
    if not snapshot then
        return nil
    end
    local known, current = {}, nil
    for _, id in ipairs(snapshot.spellIDs) do
        known[id] = true
    end
    for id, target in pairs(skill.aliases or {}) do
        if known[id] then
            known[target] = true
        end
    end
    -- Captures retain their original IDs. Presentation and training comparison
    -- resolve verified cosmetic/helper aliases to the player-facing rank.
    for _, rank in ipairs(skill.ranks) do
        if known[rank.spellID] and rank.aliasOf then
            known[rank.aliasOf] = true
        end
    end
    for _, rank in ipairs(skill.ranks) do
        if
            known[rank.spellID]
            and not rank.aliasOf
            and not rank.referenceOnly
            and (not current or rank.level >= current.level)
        then
            current = rank
        end
    end
    return current
end

local function rankNumber(rank)
    return rank and tonumber((rank.label or ""):match("^Rank (%d+)$"))
end

local function coversRank(trained, rank)
    if not trained then
        return false
    end
    if trained.spellID == rank.spellID then
        return true
    end
    local known, wanted = rankNumber(trained), rankNumber(rank)
    if known and wanted then
        return known >= wanted
    end
    return trained.level > rank.level
end

local function unlockLevel(skill, rank)
    return math.max(
        rank.level,
        rank.fromLevel or 1,
        skill.unlock and (10 + skill.unlock.gate + (rank.talentRank or 1) - 1) or 1
    )
end

-- Progression follows the rank actually displayed, independently of training comparison.
function A.Progression(skill, shownRank, level)
    if skill.kind == "racial" then
        return nil
    end
    local ranks, shown = {}, nil
    for _, rank in ipairs(skill.ranks) do
        local level = unlockLevel(skill, rank)
        if rank.live and (not rank.toLevel or rank.toLevel >= level) then
            ranks[#ranks + 1] = { rank = rank, level = level }
            if shownRank and rank.spellID == shownRank.spellID then
                shown = #ranks
            end
        end
    end
    if #ranks == 0 then
        return nil
    end
    local function describe(result)
        result.unlockLevel = ranks[1].level
        result.level = shown and ranks[shown].level
        result.rankLabel = shownRank and (shownRank.label ~= "" and shownRank.label or "Available")
            or skill.unlock and "Requires talent"
            or "Not yet available"
        if result.max and rankNumber(shownRank) then
            result.rankLabel = "Max rank " .. rankNumber(shownRank)
        end
        result.summary = "Lv. "
            .. result.unlockLevel
            .. " · "
            .. result.rankLabel
            .. (result.level and (" Lv. " .. result.level) or "")
        result.secondary = result.next
                and ((result.next.label ~= "" and result.next.label or "Unlock") .. " Lv. " .. result.nextLevel)
            or not result.max and result.label
            or nil
        result.nextLocked = result.nextLevel and level and result.nextLevel > level or false
        return result
    end
    if shownRank and not shown then
        return describe({ label = "No current rank match" })
    end
    local upcoming = ranks[(shown or 0) + 1]
    if upcoming then
        local number = rankNumber(upcoming.rank)
        local prefix = shown and (number and "Next rank " .. number or "Next upgrade")
            or skill.unlock and "Talent unlock"
            or (number and "Unlock rank " .. number or "Unlock")
        return describe({
            next = upcoming.rank,
            nextLevel = upcoming.level,
            label = prefix .. " · level " .. upcoming.level,
        })
    end
    local number = rankNumber(shownRank)
    return describe({
        max = true,
        label = number and "Max rank " .. number or "No rank upgrades",
    })
end

local function grantedRank(skill, rank)
    return rank.talentGranted or rank.talentRank or (skill.unlock and rank == firstLiveRank(skill))
end

local function compareTraining(skill, level, points, snapshot)
    local current = A.CurrentRank(skill, level, points)
    local trained = A.TrainedRank(skill, snapshot)
    local result = { trained = trained, current = current }
    local nextRank, nextLevel
    if skill.unlock and (points[skill.unlock.id] or 0) == 0 then
        result.status, result.label = "talent", "Requires talent"
        nextRank = firstLiveRank(skill)
        nextLevel = nextRank and unlockLevel(skill, nextRank)
        result.requiresTalent = skill.unlock.name
    elseif current and not grantedRank(skill, current) and not coversRank(trained, current) then
        result.needsTraining = true
        result.status = trained and "upgrade" or "new"
        result.label = (trained and "Train " or "New ")
            .. (current.label ~= "" and current.label or "skill")
        nextRank, nextLevel = current, unlockLevel(skill, current)
    else
        result.status = trained and "trained" or current and "granted" or "future"
        result.label = trained
                and ((trained.label ~= "" and trained.label or "Skill") .. " trained")
            or current and "Talent granted"
            or "Not yet available"
        for _, rank in ipairs(skill.ranks) do
            local at = unlockLevel(skill, rank)
            if
                rank.live
                and (not rank.toLevel or rank.toLevel >= at)
                and at > level
                and not coversRank(trained, rank)
                and not grantedRank(skill, rank)
                and (not nextLevel or at < nextLevel)
            then
                nextRank, nextLevel = rank, at
            end
        end
    end
    if nextRank then
        result.next = nextRank
        result.nextLevel = nextLevel
        result.levelsAway = math.max(0, nextLevel - level)
        result.progress = "↑" .. result.levelsAway
        result.hint = (nextRank.label ~= "" and nextRank.label or "Skill")
            .. " • level "
            .. nextLevel
            .. " • "
            .. result.levelsAway
            .. (result.levelsAway == 1 and " more level" or " more levels")
        if result.requiresTalent then
            result.hint = result.hint
                .. ". Requires "
                .. result.requiresTalent
                .. "; level alone does not unlock it."
        elseif result.needsTraining then
            result.hint = result.hint .. ". Available to train now."
        end
    else
        result.hint = "No later rank is recorded in the current catalog."
    end
    result.hint = result.hint
        .. (
            trained
                and (" Imported: " .. (trained.label ~= "" and trained.label or "ability") .. ".")
            or " Not in the imported spellbook."
        )
    return result
end

-- Compare the displayed plan with a dated spellbook; never infer an empty capture.
function A.TrainingReport(build, level)
    local report = {
        enabled = FT.Store and FT.Store.db and FT.Store.CheckTraining() or false,
        skills = {},
        total = 0,
        new = 0,
        upgrades = 0,
        level = level,
    }
    if not report.enabled then
        return report
    end
    local snapshot = FT.Character.Get(build).trainedSkills
    if not snapshot or snapshot.classID ~= build.classID then
        report.caption = "Import character skills first"
        report.note =
            "No matching imported spellbook. Use Character → Import my talents & skills in the addon, or import its character string."
        return report
    end
    report.capturedLevel = snapshot.level
    local prepared, points = A.Prepare(build.classID), FT.Model.Counts(build)
    local recognized = false
    for _, skill in ipairs(prepared.list) do
        if A.TrainedRank(skill, snapshot) then
            recognized = true
            break
        end
    end
    if not recognized then
        report.caption = "Imported skills do not match"
        report.note =
            "No imported class skill matches this catalog. Update both versions and capture your character again."
        return report
    end
    report.ready = true
    for _, skill in ipairs(prepared.list) do
        local comparison = compareTraining(skill, level, points, snapshot)
        report.skills[skill.name] = comparison
        if comparison.needsTraining then
            report.total = report.total + 1
            if comparison.status == "new" then
                report.new = report.new + 1
            else
                report.upgrades = report.upgrades + 1
            end
        end
    end
    report.caption = report.total .. " need training • level " .. level
    report.note = report.new
        .. " new skills, "
        .. report.upgrades
        .. " rank upgrades. Imported at level "
        .. snapshot.level
        .. ". Uses the displayed level and talents. Racials and talent-granted ranks do not need training. Some skills require quests or items. Re-import after learning skills."
    return report
end

A.highlightPalette = {
    { name = "Sky", hex = "59d9ff", 0.35, 0.85, 1 },
    { name = "Gold", hex = "f4c363", 0.96, 0.76, 0.39 },
    { name = "Violet", hex = "bf9cff", 0.75, 0.61, 1 },
    { name = "Mint", hex = "66e2ad", 0.40, 0.89, 0.68 },
    { name = "Coral", hex = "ff8f96", 1, 0.56, 0.59 },
    { name = "Orange", hex = "ffaa66", 1, 0.67, 0.40 },
}
function A.NextHighlightColor(assignments)
    local counts = { 0, 0, 0, 0, 0, 0 }
    for _, n in pairs(assignments or {}) do
        if counts[n] then
            counts[n] = counts[n] + 1
        end
    end
    local best = 1
    for i = 2, #counts do
        if counts[i] < counts[best] then
            best = i
        end
    end
    return best
end
function A.HighlightMap(selections)
    local result = {}
    for _, selection in ipairs(selections) do
        local n = selection.color
        if A.highlightPalette[n] then
            for _, link in ipairs(selection.skill.related or {}) do
                result[link.id] = result[link.id] or {}
                result[link.id][n] = true
            end
        end
    end
    return result
end

function A.List(build, level, query, filter, includeRacials)
    local prepared = A.Prepare(build.classID)
    local list, points = {}, FT.Model.Counts(build)
    local training = FT.Character and FT.Store.db and FT.Character.Get(build).trainedSkills
    if training and training.classID ~= build.classID then
        training = nil
    end
    query = normalize(query)
    local report = A.TrainingReport(build, level)
    for _, skill in ipairs(prepared.list) do
        local rank = A.CurrentRank(skill, level, points)
        local trained = A.TrainedRank(skill, training)
        local comparison = report.skills[skill.name]
        if
            (query == "" or skill.search:find(query, 1, true))
            and (
                not filter
                or filter == "all"
                or (filter == "now" and rank)
                or (filter == "talent" and skill.unlock)
                or (filter == "trained" and trained)
                or (filter == "needsTraining" and comparison and comparison.needsTraining)
            )
        then
            local shownRank = trained or rank
            if comparison then
                if comparison.status == "talent" or comparison.status == "future" then
                    shownRank = nil
                elseif comparison.needsTraining then
                    shownRank = rank
                end
            end
            list[#list + 1] = {
                skill = skill,
                current = rank,
                trained = trained,
                shownTrained = trained ~= nil and shownRank == trained,
                comparison = comparison,
                progression = A.Progression(skill, shownRank, level),
            }
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
                                abilityDetails = A.AbilityDetails(r),
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
