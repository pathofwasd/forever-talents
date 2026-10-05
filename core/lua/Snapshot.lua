local _, FT = ...
local P, C, Sim, M = {}, FT.Codec, FT.Simulation, FT.Model
FT.Snapshot = P
local numeric = {
    "power",
    "attackPower",
    "weaponMin",
    "weaponMax",
    "crit",
    "hit",
    "reduction",
    "extra",
    "coefficient",
    "dotCoefficient",
    "baseMin",
    "baseMax",
}
local flags = { "bleeding", "frozen", "cooldowns", "manual" }
local function split(text, separator)
    local out = {}
    for value in (text .. separator):gmatch("(.-)" .. separator) do
        out[#out + 1] = value
    end
    return out
end
local function envelope(body)
    return body .. ":" .. C.Checksum(body)
end
local function verified(code, prefix)
    if type(code) ~= "string" or #code > 8192 then
        return nil, "Paste a complete sharing string (at most 8192 characters)."
    end
    code = code:match("^%s*(.-)%s*$")
    local body, check = code:match("^(.*):([%x]+)$")
    if not body or #check ~= 8 or C.Checksum(body) ~= check then
        return nil, "This string is incomplete or damaged. Copy the entire string again."
    end
    if body:sub(1, #prefix + 1) ~= prefix .. ":" then
        return nil, "This sharing format needs a newer Forever Talents version."
    end
    return body
end
local function num(value)
    if value == nil then
        return ""
    end
    if type(value) ~= "number" or value ~= value or math.abs(value) > 100000 then
        return nil
    end
    return string.format("%.6f", value):gsub("0+$", ""):gsub("%.$", "")
end
function P.Stats(state, build, skillName, note)
    return {
        state = Sim.State(state),
        classID = build.classID,
        raceID = build.raceID,
        level = build.level,
        skillName = FT.SafeText(skillName, 80),
        note = FT.SafeText(note, 256),
    }
end
function P.Current(build, skillName, state)
    local settings = FT.Store.db.settings
    local profile = not state and settings.statsProfile and FT.Copy(settings.statsProfile)
        or P.Stats(state or settings.scenario, build, skillName or settings.scenarioSkill)
    if profile.classID ~= build.classID then
        profile.raw, profile.learnedCode = nil, nil
    end
    profile.classID, profile.raceID, profile.level = build.classID, build.raceID, build.level
    if skillName then
        profile.skillName = FT.SafeText(skillName, 80)
    end
    return profile
end
function P.EncodeStats(profile)
    if type(profile) ~= "table" or type(profile.state) ~= "table" then
        return nil, "No simulation stats to share."
    end
    if
        not M.Class(profile.classID)
        or not M.RaceAllowed(profile.classID, profile.raceID)
        or type(profile.level) ~= "number"
        or profile.level % 1 ~= 0
        or profile.level < 1
        or profile.level > 60
    then
        return nil, "Invalid character identity or level."
    end
    local state = Sim.State(profile.state)
    local values = { profile.classID, profile.raceID, profile.level }
    for _, key in ipairs(numeric) do
        values[#values + 1] = num(state[key])
    end
    for _, key in ipairs(flags) do
        values[#values + 1] = state[key] and "1" or "0"
    end
    local raw = type(profile.raw) == "table" and profile.raw or {}
    for _, key in ipairs({ "healing", "meleeCrit", "rangedCrit" }) do
        values[#values + 1] = num(raw[key]) or ""
    end
    for i = 1, 7 do
        values[#values + 1] = num(raw.power and raw.power[i]) or ""
        values[#values + 1] = num(raw.crit and raw.crit[i]) or ""
    end
    for _, key in ipairs({ "rangedAP", "rangedMin", "rangedMax" }) do
        values[#values + 1] = num(raw[key]) or ""
    end
    if profile.learnedCode and not C.Decode(profile.learnedCode) then
        return nil, "Invalid source talents in stats."
    end
    return envelope(table.concat({
        "FS1",
        table.concat(values, "~"),
        C.Base64(FT.SafeText(profile.skillName, 80)),
        C.Base64(FT.SafeText(profile.note, 256)),
        C.Base64(profile.learnedCode or ""),
    }, ":"))
end
function P.DecodeStats(code)
    local body, why = verified(code, "FS1")
    if not body then
        return nil, why
    end
    local parts = split(body, ":")
    if #parts ~= 5 then
        return nil, "Invalid stats string."
    end
    local v = split(parts[2], "~")
    if #v ~= 36 and #v ~= 39 then
        return nil, "Invalid stats field count."
    end
    local class, race, level = tonumber(v[1]), tonumber(v[2]), tonumber(v[3])
    if
        not M.Class(class)
        or not M.RaceAllowed(class, race)
        or not level
        or level % 1 ~= 0
        or level < 1
        or level > 60
    then
        return nil, "Invalid character identity or level."
    end
    local state = {}
    local pos = 3
    local function read(lo, hi)
        pos = pos + 1
        if v[pos] == "" then
            return nil
        end
        local n = tonumber(v[pos])
        if not n or n ~= n or n < lo or n > hi then
            error("Invalid numeric stats value.")
        end
        return n
    end
    local ok, err = pcall(function()
        for _, key in ipairs(numeric) do
            local lo = key == "extra" and -99 or 0
            local hi = (key == "crit" or key == "hit" or key == "reduction") and 100
                or (
                    (key == "extra" or key == "coefficient" or key == "dotCoefficient") and 1000
                    or 100000
                )
            state[key] = read(lo, hi)
        end
        for _, key in ipairs(flags) do
            pos = pos + 1
            if v[pos] ~= "0" and v[pos] ~= "1" then
                error("Invalid stats toggle.")
            end
            state[key] = v[pos] == "1"
        end
    end)
    if not ok then
        return nil, "Invalid simulation stats: " .. tostring(err)
    end
    local raw = { power = {}, crit = {} }
    ok, err = pcall(function()
        raw.healing = read(0, 100000)
        raw.meleeCrit = read(0, 100)
        raw.rangedCrit = read(0, 100)
        for i = 1, 7 do
            raw.power[i] = read(0, 100000)
            raw.crit[i] = read(0, 100)
        end
        if #v == 39 then
            raw.rangedAP = read(0, 100000)
            raw.rangedMin = read(0, 100000)
            raw.rangedMax = read(0, 100000)
        end
    end)
    if not ok then
        return nil, "Invalid reported stats."
    end
    local skill, note, learned = C.Unbase64(parts[3]), C.Unbase64(parts[4]), C.Unbase64(parts[5])
    if
        not skill
        or not note
        or not learned
        or FT.SafeText(skill, 80) ~= skill
        or FT.SafeText(note, 256) ~= note
    then
        return nil, "Invalid stats text."
    end
    if learned ~= "" and not C.Decode(learned) then
        return nil, "Source talents use a different or invalid dataset."
    end
    return {
        state = Sim.State(state),
        classID = class,
        raceID = race,
        level = level,
        skillName = skill,
        note = note,
        raw = raw,
        learnedCode = learned ~= "" and learned or nil,
    }
end
function P.EncodeCharacter(build, profile)
    local code, why = C.Encode(build)
    if not code then
        return nil, why
    end
    local stats
    stats, why = P.EncodeStats(profile)
    if not stats then
        return nil, why
    end
    if
        profile.classID ~= build.classID
        or profile.raceID ~= build.raceID
        or profile.level ~= build.level
    then
        return nil, "Character stats identity must match the build."
    end
    return envelope("FC1:" .. C.Base64(code) .. ":" .. C.Base64(stats))
end
function P.Decode(code)
    if type(code) ~= "string" then
        return nil, "Paste a sharing string."
    end
    code = code:match("^%s*(.-)%s*$")
    if code:sub(1, 4) == "FT1:" then
        local b, why = C.Decode(code)
        return b and { kind = "build", build = b } or nil, why
    end
    if code:sub(1, 4) == "FS1:" then
        local p, why = P.DecodeStats(code)
        return p and { kind = "stats", stats = p } or nil, why
    end
    local body, why = verified(code, "FC1")
    if not body then
        return nil, why
    end
    local parts = split(body, ":")
    if #parts ~= 3 then
        return nil, "Invalid character string."
    end
    local bc, sc = C.Unbase64(parts[2]), C.Unbase64(parts[3])
    local b, err = C.Decode(bc)
    if not b then
        return nil, err
    end
    local p
    p, err = P.DecodeStats(sc)
    if not p then
        return nil, err
    end
    if p.classID ~= b.classID or p.raceID ~= b.raceID or p.level ~= b.level then
        return nil, "Character identity differs between talents and stats."
    end
    return { kind = "character", build = b, stats = p }
end
function P.ForSkill(profile, skill, rank, build)
    local state = Sim.State(profile and profile.state)
    if not profile then
        return state
    end
    local note = profile.note or ""
    local parsed = Sim.Parse(rank, skill)
    local raw = profile.raw
    local ranged = skill.name == "Auto Shot"
        or skill.name == "Aimed Shot"
        or skill.name == "Multi-Shot"
    if raw and ranged and profile.classID == build.classID then
        state.attackPower = raw.rangedAP or state.attackPower
        state.weaponMin = raw.rangedMin or state.weaponMin
        state.weaponMax = raw.rangedMax or state.weaponMax
        state.crit = raw.rangedCrit or state.crit
    end
    if raw and parsed and profile.classID == build.classID then
        local schools =
            { Physical = 1, Holy = 2, Fire = 3, Nature = 4, Frost = 5, Shadow = 6, Arcane = 7 }
        local school = schools[parsed.school] or 7
        if parsed.kind == "healing" and raw.healing then
            state.power = raw.healing
        elseif raw.power and raw.power[school] then
            state.power = raw.power[school]
        end
        local crit = parsed.school == "Physical" and (ranged and raw.rangedCrit or raw.meleeCrit)
            or (raw.crit and raw.crit[school])
        if crit then
            local learned = profile.learnedCode and C.Decode(profile.learnedCode)
            local bonus = learned
                    and Sim.Modifiers(learned, skill, parsed, Sim.Defaults()).statsCrit
                or 0
            state.crit = math.max(0, crit - bonus)
            note = string.format(
                "Reported crit %.1f%% minus %.1f%% recognized source-talent bonus. Reported power and weapon values can include buffs.",
                crit,
                bonus
            )
        end
    end
    if profile.skillName ~= "" and profile.skillName ~= skill.name then
        state.coefficient, state.dotCoefficient, state.manual = nil, nil, false
    end
    return state, note
end
function P.Apply(snapshot)
    if snapshot.build then
        local ok, why = FT.Store.Import(snapshot.build)
        if not ok then
            return false, why
        end
        -- Explicit character/build imports retain their target level, even if
        -- the previous draft was in Auto mode. Undo restores both states.
        if FT.Store.AutoLevel() then
            FT.Store.SetAutoLevel(false)
            local b = FT.Copy(FT.Store.Build())
            b.level = snapshot.build.level
            FT.Store.Edit(b)
        end
    end
    if snapshot.stats then
        FT.Store.db.settings.statsProfile = FT.Copy(snapshot.stats)
        FT.Store.db.settings.scenario = Sim.State(snapshot.stats.state)
    end
    FT.Changed(
        snapshot.kind == "stats" and "Simulation stats loaded. Your talents and level are kept."
            or "Snapshot loaded. Original live point-spending order is unavailable; live imports use a legal derived order."
    )
    return true
end
