-- Browser platform adapter. Domain logic remains in core/lua, unchanged.
local S, M, A, C = FT.Store, FT.Model, FT.Skills, FT.Codec
local message = ""
FT.Print = function(text)
    message = text
end
FT.UI.Status = function(text)
    message = text
end
FT.UI.Refresh = function() end

-- The host supplies JSON parsing. Recursively copy incoming JS values into
-- ordinary Lua tables, converting numeric object keys used by SavedVariables.
local function plain(value)
    if type(value) ~= "table" then
        return value
    end
    local result = {}
    for key, item in pairs(value) do
        result[tonumber(key) or key] = plain(item)
    end
    return result
end
local function jsonEscape(value)
    return '"'
        .. value:gsub('[%z\1-\31\\"]', function(c)
            if c == '"' then
                return '\\"'
            elseif c == "\\" then
                return "\\\\"
            end
            return string.format("\\u%04x", c:byte())
        end)
        .. '"'
end
local function json(value)
    if value == nil then
        return "null"
    end
    local kind = type(value)
    if kind == "boolean" or kind == "number" then
        return tostring(value)
    end
    if kind == "string" then
        return jsonEscape(value)
    end
    -- Keep numeric-key maps (checkpoint IDs, ranks, talent IDs) distinct from
    -- JS zero-based arrays. The host's list() reads Lua sequences explicitly.
    local parts = {}
    for key, item in pairs(value) do
        parts[#parts + 1] = jsonEscape(tostring(key)) .. ":" .. json(item)
    end
    return "{" .. table.concat(parts, ",") .. "}"
end
local function state()
    local p, node = S.ActiveProfile()
    return {
        build = S.Build(),
        view = S.View(),
        viewLevel = S.ViewLevel(),
        counts = M.Counts(S.View()),
        requiredLevel = M.RequiredLevel(S.View()),
        treeCounts = select(2, M.Counts(S.View())),
        budget = M.Budget(S.PlanningView().level),
        scenario = S.db.settings.scenario,
        statsProfile = S.db.settings.statsProfile,
        auto = S.AutoLevel(),
        simpleView = S.SimpleView(),
        checkTraining = S.CheckTraining(),
        preview = S.preview,
        undo = #S.Draft().undo,
        redo = #S.Draft().redo,
        profiles = S.db.profiles,
        profileOrder = S.db.profileOrder,
        activeProfile = p and p.id,
        activeNode = node and node.id,
        dirty = S.Dirty(),
        message = message,
        readOnly = S.readOnly,
    }
end
local function catalog()
    local classes = {}
    for id, c in pairs(FT.Data.classes) do
        classes[id] = {
            id = id,
            name = c.name,
            slug = c.slug,
            icon = c.icon,
            races = c.races,
            trees = c.trees,
        }
    end
    return {
        meta = FT.Data.meta,
        classes = classes,
        races = FT.Data.races,
        perks = FT.Data.perks,
        pets = FT.Data.pets,
        classOrder = FT.classOrder,
        version = FT.version,
        buildURL = C.WebURL,
        highlightPalette = A.highlightPalette,
    }
end
local function decode(p)
    if p.profileOnly then
        return FT.Library.DecodeProfile(p.code)
    end
    if p.buildOnly then
        local build, why = C.Decode(p.code)
        return build and { kind = "build", build = build } or nil, why
    end
    if type(p.code) == "string" and p.code:match("^%s*FL1:") then
        return FT.Library.Decode(p.code)
    end
    return FT.Snapshot.Decode(p.code)
end
local commands = {
    highlightColor = function(p)
        return A.NextHighlightColor(plain(p.assignments))
    end,
    highlights = function(p)
        return A.HighlightMap(plain(p.selections))
    end,
    state = function()
        return state()
    end,
    catalog = catalog,
    database = function()
        return S.db
    end,
    switch = function(p)
        return S.SwitchClass(p.classID)
    end,
    race = function(p)
        local b = FT.Copy(S.Build())
        b.raceID = p.raceID
        return S.Edit(b)
    end,
    level = function(p)
        local b = FT.Copy(S.Build())
        b.level = p.level
        return S.Edit(b)
    end,
    auto = function(p)
        return S.SetAutoLevel(p.enabled)
    end,
    simpleView = function(p)
        return S.SetSimpleView(p.enabled)
    end,
    checkTraining = function(p)
        return S.SetCheckTraining(p.enabled)
    end,
    add = function(p)
        return S.Apply(M.Add, p.id, p.fill)
    end,
    remove = function(p)
        return S.Apply(M.Remove, p.id, p.all)
    end,
    reset = function(p)
        return S.Apply(M.Reset, p.treeID)
    end,
    reorder = function(p)
        return S.Apply(M.Reorder, p.from, p.to)
    end,
    undo = S.Undo,
    redo = S.Redo,
    preview = function(p)
        S.Preview(p.count)
        return true
    end,
    branch = S.BranchPreview,
    save = function(p)
        return S.CreateProfile(p.title)
    end,
    checkpoint = function(p)
        return S.Checkpoint(p.title)
    end,
    load = function(p)
        return S.LoadNode(p.profileID, p.nodeID)
    end,
    subtree = function(p)
        local ids, count = S.NodeSubtree(p.profileID, p.nodeID)
        return { ids = ids, count = count }
    end,
    deleteNode = function(p)
        return S.DeleteNode(p.profileID, p.nodeID)
    end,
    rename = function(p)
        return S.RenameProfile(p.profileID, p.title)
    end,
    deleteProfile = function(p)
        return S.DeleteProfile(p.profileID)
    end,
    share = function()
        return C.Encode(S.ExportView())
    end,
    decode = decode,
    import = function(p)
        local snap, why = decode(p)
        if not snap then
            return nil, why
        end
        if snap.kind == "library" then
            return FT.Library.Merge(snap, p.includeDrafts)
        end
        return FT.Snapshot.Apply(snap)
    end,
    export = function(p)
        if p.kind == "profileLink" or p.kind == "profile" then
            local id = p.profileID or (S.ActiveProfile() and S.ActiveProfile().id)
            if p.kind == "profileLink" then
                return FT.Library.ProfileLink(id)
            end
            return FT.Library.EncodeProfile(id)
        end
        if p.kind == "link" then
            return C.BuildLink(S.ExportView())
        end
        if p.kind == "library" then
            return FT.Library.Encode()
        end
        if p.kind == "build" then
            return C.Encode(S.ExportView())
        end
        local profile = p.profile or FT.Snapshot.Current(S.ExportView(), p.skillName, p.state)
        if p.kind == "stats" then
            return FT.Snapshot.EncodeStats(profile)
        end
        return FT.Snapshot.EncodeCharacter(S.ExportView(), profile)
    end,
    scenario = function(p)
        S.db.settings.scenario = FT.Simulation.State(p.state)
        S.db.settings.scenarioSkill = p.name
        if p.manual then
            S.db.settings.statsProfile = nil
        end
        return true
    end,
    character = function()
        return FT.Character.View(S.View())
    end,
    characterMode = function(p)
        return FT.Character.SetMode(S.View(), p.mode)
    end,
    characterSave = function(p)
        return FT.Character.Save(S.View(), plain(p.sheet))
    end,
    simulationInputs = function(p)
        for _, entry in ipairs(A.List(S.View(), 60, "", "all")) do
            if entry.skill.name == p.name then
                local rank = entry.skill.ranks[p.rank or #entry.skill.ranks]
                if not rank then
                    return nil, "Choose a valid skill rank."
                end
                return FT.Simulation.ImportInputs(S.View(), entry.skill, rank, p.code)
            end
        end
        return nil, "Choose a valid skill."
    end,
    statsForSkill = function(p)
        local skill
        for _, entry in ipairs(A.List(S.View(), 60, "", "all")) do
            if entry.skill.name == p.name then
                skill = entry.skill
                break
            end
        end
        if not skill or not skill.ranks[p.rank or #skill.ranks] then
            return nil, "Choose a valid skill rank."
        end
        local rank = skill.ranks[p.rank or #skill.ranks]
        local state, character, note = FT.Character.ForSkill(
            S.View(),
            skill,
            rank,
            nil,
            nil,
            p.overrides and p.overrides.effectMode
        )
        for key, value in pairs(p.overrides or {}) do
            state[key] = value
        end
        return {
            state = state,
            note = note,
            character = character,
            inputs = FT.Simulation.Inputs(S.View(), skill, rank, state),
            parsed = FT.Simulation.Parse(rank, skill, S.View().level),
        }
    end,
    talentSkills = function(p)
        return A.TalentSkills(S.Build().classID, p.id)
    end,
    talents = function(p)
        local out = {}
        for id, t in pairs(M.Index(S.Build().classID)) do
            local ok, why = M.CanAdd(S.PlanningView(), id)
            out[id] = { available = ok, reason = why, match = A.SearchTalent(t, p.query) }
        end
        return out
    end,
    skills = function(p)
        return A.List(S.View(), S.ViewLevel(), p.query, p.filter, not S.SimpleView())
    end,
    skillLevels = function(p)
        local skill = A.Prepare(S.Build().classID).byName[p.name]
        if not skill then
            return nil, "Class skill not found."
        end
        local ranks, unlockLevel = A.Levels(skill)
        return { ranks = ranks, unlockLevel = unlockLevel }
    end,
    training = function(p)
        local capture = FT.Character.Get(S.View()).trainedSkills
        local skill = A.Prepare(S.View().classID).byName[p.name]
        return { capture = capture, rank = skill and A.TrainedRank(skill, capture) }
    end,
    trainingReport = function()
        return A.TrainingReport(S.View(), S.ViewLevel())
    end,
    skill = function(p)
        for _, entry in ipairs(A.List(S.View(), 60, "", "all")) do
            if entry.skill.name == p.name then
                return entry.skill
            end
        end
        return nil, "Skill not found."
    end,
    canAdd = function(p)
        return M.CanAdd(S.PlanningView(), p.id)
    end,
    searchTalent = function(p)
        return A.SearchTalent(M.Index(S.Build().classID)[p.id], p.query)
    end,
    simulate = function(p)
        local skill
        for _, entry in ipairs(A.List(S.View(), 60, "", "all")) do
            if entry.skill.name == p.name then
                skill = entry.skill
                break
            end
        end
        if not skill then
            return nil, "Skill not found."
        end
        local rank = skill.ranks[p.rank or #skill.ranks]
        if not rank then
            return nil, "Choose a valid skill rank."
        end
        if p.state then
            return FT.Simulation.Calculate(S.View(), skill, rank, p.state, p.withTalents)
        end
        return FT.Simulation.Run(S.View(), skill, rank, p.overrides, p.withTalents)
    end,
}
function webInit(saved)
    _G.ForeverTalentsDB = type(saved) == "table" and plain(saved) or nil
    S.Init(11, 4, 60)
    return json(state())
end
function webCall(name, payload)
    local fn = commands[name]
    if not fn then
        return json({ ok = false, error = "Unknown operation." })
    end
    local ok, result, why = pcall(fn, plain(payload or {}))
    if not ok then
        return json({ ok = false, error = tostring(result) })
    end
    return json({
        ok = result ~= false and result ~= nil,
        value = result,
        error = (result == false or result == nil) and why or nil,
    })
end
