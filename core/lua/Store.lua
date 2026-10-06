local _, FT = ...
local S = {}
FT.Store = S
local MAX_HISTORY = 100

local function fresh()
    return {
        schema = 1,
        tag = FT.Data.meta.tag,
        drafts = {},
        profiles = {},
        profileOrder = {},
        nextID = 1,
        inbox = {},
        settings = { minimap = true, scale = 1 },
    }
end

local function validBuild(build)
    return FT.Model.Validate(build)
end
local function snapshot(draft)
    return {
        build = FT.Copy(draft.build),
        profileID = draft.profileID,
        nodeID = draft.nodeID,
        autoLevel = draft.autoLevel,
        manualLevel = draft.manualLevel,
    }
end
local function restore(draft, entry)
    draft.build, draft.profileID, draft.nodeID = FT.Copy(entry.build), entry.profileID, entry.nodeID
    draft.autoLevel, draft.manualLevel = entry.autoLevel == true, entry.manualLevel
end
local function validManualLevel(level)
    return type(level) == "number" and level % 1 == 0 and level >= 1 and level <= 60
end
local function historyClean(list, classID)
    local out = {}
    if type(list) == "table" then
        for _, entry in ipairs(list) do
            local build = type(entry) == "table" and (entry.build or entry)
            if validBuild(build) and build.classID == classID then
                out[#out + 1] = {
                    build = build,
                    profileID = entry.profileID,
                    nodeID = entry.nodeID,
                    autoLevel = entry.autoLevel == true,
                    manualLevel = validManualLevel(entry.manualLevel) and entry.manualLevel or nil,
                }
            end
        end
    end
    while #out > MAX_HISTORY do
        table.remove(out, 1)
    end
    return out
end

function S.Init(classID, raceID, level)
    S.readOnly = false
    local saved = _G.ForeverTalentsDB
    if type(saved) == "table" and type(saved.schema) == "number" and saved.schema > 1 then
        S.db, S.readOnly = fresh(), true
        FT.Print(
            "Your saved builds were created by a newer addon. They are preserved; saving is disabled in this version."
        )
    else
        S.db = type(saved) == "table" and saved.schema == 1 and saved or fresh()
        if saved and S.db ~= saved then
            S.db.recovered = { FT.Copy(saved) }
        end
        _G.ForeverTalentsDB = S.db
    end
    local db = S.db
    for _, key in ipairs({ "drafts", "profiles", "profileOrder", "inbox", "settings" }) do
        if type(db[key]) ~= "table" then
            db[key] = {}
        end
    end
    db.nextID = type(db.nextID) == "number"
            and db.nextID == db.nextID
            and db.nextID < math.huge
            and math.max(1, math.floor(db.nextID))
        or 1
    db.settings.scale = type(db.settings.scale) == "number"
            and math.max(0.65, math.min(1.3, db.settings.scale))
        or 1
    if db.settings.minimap == nil then
        db.settings.minimap = true
    end
    db.settings.simpleView = db.settings.simpleView == true
    db.settings.scenario = FT.Simulation.State(db.settings.scenario)
    if db.settings.statsProfile and FT.Snapshot then
        local ok, code = pcall(FT.Snapshot.EncodeStats, db.settings.statsProfile)
        local normalized = ok and code and FT.Snapshot.DecodeStats(code)
        if normalized then
            db.settings.statsProfile = normalized
        else
            db.recovered = db.recovered or {}
            db.recovered[#db.recovered + 1] =
                { kind = "stats", value = FT.Copy(db.settings.statsProfile) }
            db.settings.statsProfile = nil
        end
    end
    if db.settings.characters ~= nil then
        local cleaned = {}
        if type(db.settings.characters) == "table" then
            for id, raw in pairs(db.settings.characters) do
                local character = FT.Character.Normalize(raw, true)
                if
                    FT.Model.Class(id)
                    and character
                    and (not character.capture or character.capture.classID == id)
                    and (not character.trainedSkills or character.trainedSkills.classID == id)
                then
                    cleaned[id] = character
                else
                    db.recovered = db.recovered or {}
                    db.recovered[#db.recovered + 1] =
                        { kind = "character", id = id, value = FT.Copy(raw) }
                end
            end
        else
            db.recovered = db.recovered or {}
            db.recovered[#db.recovered + 1] =
                { kind = "characters", value = FT.Copy(db.settings.characters) }
        end
        db.settings.characters = cleaned
    end
    for id, draft in pairs(db.drafts) do
        if type(draft) ~= "table" or not validBuild(draft.build) or draft.build.classID ~= id then
            db.recovered = db.recovered or {}
            db.recovered[#db.recovered + 1] = { kind = "draft", id = id, value = FT.Copy(draft) }
            db.drafts[id] = nil
        else
            draft.undo, draft.redo = historyClean(draft.undo, id), historyClean(draft.redo, id)
            draft.autoLevel = draft.autoLevel == true
            draft.manualLevel = validManualLevel(draft.manualLevel) and draft.manualLevel or nil
            if draft.autoLevel then
                draft.build.level = FT.Model.RequiredLevel(draft.build)
            end
        end
    end
    local goodProfiles, seen, profiles = {}, {}, {}
    for _, id in ipairs(db.profileOrder) do
        local p = db.profiles[id]
        if
            type(id) == "string"
            and not seen[id]
            and type(p) == "table"
            and type(p.nodes) == "table"
            and type(p.order) == "table"
        then
            local good, nodes = true, {}
            local classID
            for i, nid in ipairs(p.order) do
                local node = p.nodes[nid]
                if
                    type(nid) ~= "number"
                    or nid % 1 ~= 0
                    or nid < 1
                    or type(node) ~= "table"
                    or not validBuild(node.build)
                    or nodes[nid]
                    or (node.parent and not nodes[node.parent])
                    or (i > 1 and not node.parent)
                    or (classID and node.build.classID ~= classID)
                then
                    good = false
                    break
                end
                classID = node.build.classID
                nodes[nid] = true
                node.id = nid
                node.title = FT.SafeText(node.title or "Checkpoint", 48)
            end
            for nid in pairs(p.nodes) do
                if not nodes[nid] then
                    good = false
                end
            end
            if good and #p.order > 0 and #p.order <= 400 then
                goodProfiles[#goodProfiles + 1] = id
                seen[id] = true
                profiles[id] = p
                p.id = id
                p.name = FT.SafeText(p.name or "Recovered build", 48)
                p.nextNode = type(p.nextNode) == "number"
                        and p.nextNode == p.nextNode
                        and p.nextNode < math.huge
                        and math.max(1, math.floor(p.nextNode))
                    or #p.order + 1
            end
        end
    end
    for id, p in pairs(db.profiles) do
        if not profiles[id] then
            db.recovered = db.recovered or {}
            db.recovered[#db.recovered + 1] = { kind = "profile", id = id, value = FT.Copy(p) }
        end
    end
    db.profileOrder, db.profiles = goodProfiles, profiles
    local function cleanContext(entry)
        local p = db.profiles[entry.profileID]
        local node = p and p.nodes[entry.nodeID]
        if not node or node.build.classID ~= (entry.build and entry.build.classID) then
            entry.profileID, entry.nodeID = nil, nil
        end
    end
    for _, draft in pairs(db.drafts) do
        cleanContext(draft)
        for _, entry in ipairs(draft.undo) do
            cleanContext(entry)
        end
        for _, entry in ipairs(draft.redo) do
            cleanContext(entry)
        end
    end
    local inbox = {}
    for _, item in ipairs(db.inbox) do
        if type(item) == "table" and type(item.code) == "string" and FT.Codec.Decode(item.code) then
            inbox[#inbox + 1] = {
                code = item.code,
                sender = FT.SafeText(item.sender, 64),
                received = item.received or 0,
            }
        end
    end
    while #inbox > 20 do
        table.remove(inbox, 1)
    end
    db.inbox = inbox
    S.classID = FT.Model.Class(db.currentClass) and db.currentClass
        or (FT.Model.Class(classID) and classID or 11)
    if not db.drafts[S.classID] then
        db.drafts[S.classID] =
            { build = FT.Model.New(S.classID, raceID, level or 60), undo = {}, redo = {} }
    end
    S.preview = nil
end

function S.Draft()
    return S.db.drafts[S.classID]
end
function S.Build()
    return S.Draft().build
end
function S.View()
    return S.preview and FT.Model.Prefix(S.Build(), S.preview) or S.Build()
end
function S.ViewLevel()
    return S.preview and (S.preview > 0 and S.preview + 9 or 1) or S.Build().level
end
function S.ExportView()
    local build = FT.Copy(S.View())
    build.level = S.ViewLevel()
    return build
end
function S.AutoLevel()
    return S.Draft().autoLevel == true
end

function S.SimpleView()
    return S.db.settings.simpleView == true
end

function S.SetSimpleView(enabled)
    S.db.settings.simpleView = not not enabled
    -- Leave a read-only leveling preview when its navigation is being hidden.
    S.preview = nil
    FT.Changed(
        enabled and "Simple view enabled. Your builds and character settings are kept."
            or "Full view restored."
    )
    return true
end

function S.PlanningView()
    local build = S.View()
    if S.AutoLevel() and not S.preview then
        build = FT.Copy(build)
        build.level = 60
    end
    return build
end

local function pushUndo(draft)
    draft.undo[#draft.undo + 1] = snapshot(draft)
    while #draft.undo > MAX_HISTORY do
        table.remove(draft.undo, 1)
    end
    draft.redo = {}
end

function S.SetAutoLevel(enabled)
    if S.preview then
        return false, "Return to the full build before changing the level mode."
    end
    enabled = not not enabled
    if S.AutoLevel() == enabled then
        return true
    end
    local d = S.Draft()
    pushUndo(d)
    d.build = FT.Copy(d.build)
    if enabled then
        d.manualLevel = d.build.level
        d.autoLevel = true
        d.build.level = FT.Model.RequiredLevel(d.build)
    else
        d.autoLevel = false
        d.build.level = math.max(FT.Model.RequiredLevel(d.build), d.manualLevel or d.build.level)
        d.manualLevel = nil
    end
    FT.Changed(
        enabled and "Auto level: adding and removing talents adjusts your planned level."
            or "Manual target level restored. Use the number or − / + to change it."
    )
    return true
end

function S.Edit(build, message, profileID, nodeID, changeContext)
    if S.preview then
        return false, "Return to the full build before editing talents."
    end
    local ok, why = validBuild(build)
    if not ok then
        return false, why
    end
    if S.AutoLevel() then
        build = FT.Copy(build)
        build.level = FT.Model.RequiredLevel(build)
    end
    local d = S.Draft()
    if
        FT.Model.Same(d.build, build)
        and (not changeContext or (d.profileID == profileID and d.nodeID == nodeID))
    then
        return true
    end
    pushUndo(d)
    d.build, d.redo = FT.Copy(build), {}
    if changeContext then
        d.profileID, d.nodeID = profileID, nodeID
    end
    FT.Changed(message)
    return true
end

function S.Apply(action, ...)
    if S.preview then
        return false, "Return to the full build before editing talents."
    end
    local planning = S.Build()
    if S.AutoLevel() then
        planning = FT.Copy(planning)
        planning.level = 60
    end
    local build, why = action(planning, ...)
    if not build then
        return false, why
    end
    return S.Edit(build)
end

function S.Undo()
    local d = S.Draft()
    if #d.undo == 0 then
        return false, "Nothing to undo."
    end
    d.redo[#d.redo + 1] = snapshot(d)
    restore(d, table.remove(d.undo))
    S.preview = nil
    FT.Changed("Undone. Your checkpoint stays saved.")
    return true
end

function S.Redo()
    local d = S.Draft()
    if #d.redo == 0 then
        return false, "Nothing to redo."
    end
    d.undo[#d.undo + 1] = snapshot(d)
    restore(d, table.remove(d.redo))
    S.preview = nil
    FT.Changed("Redone.")
    return true
end

function S.SwitchClass(classID)
    if not FT.Model.Class(classID) then
        return false
    end
    if not S.db.drafts[classID] then
        S.db.drafts[classID] =
            { build = FT.Model.New(classID, S.Build().raceID), undo = {}, redo = {} }
    end
    S.classID, S.db.currentClass, S.preview = classID, classID, nil
    FT.Changed()
    return true
end

function S.Import(build)
    local ok, why = validBuild(build)
    if not ok then
        return false, why
    end
    S.SwitchClass(build.classID)
    local d = S.Draft()
    if not FT.Model.Same(d.build, build) or d.autoLevel or d.profileID then
        pushUndo(d)
        d.build, d.profileID, d.nodeID = FT.Copy(build), nil, nil
        d.autoLevel, d.manualLevel = false, nil
    end
    FT.Changed("Build loaded at its shared target level. Save it to keep a named profile.")
    return true
end

local function newID()
    local id = "p" .. S.db.nextID
    while S.db.profiles[id] do
        S.db.nextID = S.db.nextID + 1
        id = "p" .. S.db.nextID
    end
    S.db.nextID = S.db.nextID + 1
    return id
end

function S.CreateProfile(title)
    if S.readOnly then
        return nil, "Saving is disabled to preserve newer saved data."
    end
    title = FT.SafeText(title, 48)
    if title == "" then
        return nil, "Give this build a name."
    end
    local build = FT.Copy(S.Build())
    build.name = title
    local id = newID()
    local p = {
        id = id,
        name = title,
        nodes = {
            [1] = { id = 1, title = "Starting build", build = FT.Copy(build), created = FT.Now() },
        },
        order = { 1 },
        nextNode = 2,
    }
    S.db.profiles[id] = p
    S.db.profileOrder[#S.db.profileOrder + 1] = id
    local d = S.Draft()
    d.build, d.profileID, d.nodeID = build, id, 1
    S.preview = nil
    FT.Changed("Saved " .. title .. ". Checkpoint any alternate path from here.")
    return p
end

function S.ActiveProfile()
    local d = S.Draft()
    local p = S.db.profiles[d.profileID]
    if p and p.nodes[d.nodeID] then
        return p, p.nodes[d.nodeID]
    end
end

function S.Dirty()
    local p, node = S.ActiveProfile()
    return not p or not FT.Model.Same(S.Build(), node.build)
end

function S.Checkpoint(title)
    if S.readOnly then
        return nil, "Saving is disabled to preserve newer saved data."
    end
    local p, parent = S.ActiveProfile()
    if not p then
        return S.CreateProfile(title)
    end
    if #p.order >= 400 then
        return nil, "This profile has 400 checkpoints. Save a new profile to continue branching."
    end
    title = FT.SafeText(title, 48)
    if title == "" then
        return nil, "Give this checkpoint a title."
    end
    local id = p.nextNode or (#p.order + 1)
    while p.nodes[id] do
        id = id + 1
    end
    p.nextNode = id + 1
    p.nodes[id] = {
        id = id,
        parent = parent.id,
        title = title,
        build = FT.Copy(S.Build()),
        created = FT.Now(),
    }
    p.order[#p.order + 1] = id
    S.Draft().nodeID = id
    S.preview = nil
    FT.Changed("Checkpoint saved: " .. title .. ".")
    return p.nodes[id]
end

function S.LoadNode(profileID, nodeID)
    local p = S.db.profiles[profileID]
    local node = p and p.nodes[nodeID]
    if not node then
        return false, "Checkpoint not found."
    end
    S.SwitchClass(node.build.classID)
    return S.Edit(
        node.build,
        "Loaded "
            .. node.title
            .. ". New checkpoints branch from this node; Undo returns to your previous work.",
        profileID,
        nodeID,
        true
    )
end

function S.RenameProfile(id, title)
    if S.readOnly then
        return false, "Saving is disabled."
    end
    local p = S.db.profiles[id]
    title = FT.SafeText(title, 48)
    if not p or title == "" then
        return false, "Choose a profile and enter a name."
    end
    p.name = title
    FT.Changed("Profile renamed.")
    return true
end

local function removeNodeContexts(profileID, removed, fallback)
    local function clean(entry)
        if entry.profileID == profileID and (not removed or removed[entry.nodeID]) then
            if fallback then
                entry.nodeID = fallback
            else
                entry.profileID, entry.nodeID = nil, nil
            end
        end
    end
    for _, draft in pairs(S.db.drafts) do
        clean(draft)
        for _, entry in ipairs(draft.undo) do
            clean(entry)
        end
        for _, entry in ipairs(draft.redo) do
            clean(entry)
        end
    end
end

function S.NodeSubtree(profileID, nodeID)
    local p = S.db.profiles[profileID]
    if not p or not p.nodes[nodeID] then
        return nil, "Checkpoint not found."
    end
    local removed, count = { [nodeID] = true }, 1
    -- Parents precede children in creation order, including interleaved branches.
    for _, id in ipairs(p.order) do
        if id ~= nodeID and removed[p.nodes[id].parent] then
            removed[id] = true
            count = count + 1
        end
    end
    return removed, count
end

function S.DeleteNode(profileID, nodeID)
    if S.readOnly then
        return false, "Saving is disabled."
    end
    local removed, count = S.NodeSubtree(profileID, nodeID)
    if not removed then
        return false, count
    end
    local p = S.db.profiles[profileID]
    local parent = p.nodes[nodeID].parent
    if not parent then
        local ok, why = S.DeleteProfile(profileID)
        return ok, ok and count or why
    end
    local retained = {}
    for _, id in ipairs(p.order) do
        if removed[id] then
            p.nodes[id] = nil
        else
            retained[#retained + 1] = id
        end
    end
    p.order = retained
    removeNodeContexts(profileID, removed, parent)
    S.preview = nil
    FT.Changed(
        "Deleted "
            .. count
            .. " checkpoint"
            .. (count == 1 and "" or "s")
            .. ". Your working talents are kept."
    )
    return true, count
end

function S.DeleteProfile(id)
    if S.readOnly then
        return false, "Saving is disabled."
    end
    if not S.db.profiles[id] then
        return false, "Profile not found."
    end
    S.db.profiles[id] = nil
    for i = #S.db.profileOrder, 1, -1 do
        if S.db.profileOrder[i] == id then
            table.remove(S.db.profileOrder, i)
        end
    end
    removeNodeContexts(id)
    S.preview = nil
    FT.Changed("Profile deleted. The working draft is still here.")
    return true
end

function S.Preview(count)
    S.preview = count and math.max(0, math.min(#S.Build().order, count)) or nil
    FT.Changed()
end

function S.BranchPreview()
    if not S.preview then
        return false, "Choose a level in the order first."
    end
    local build = FT.Model.Prefix(S.Build(), S.preview)
    S.preview = nil
    return S.Edit(build, "Working from this level. Save a checkpoint to keep the branch.")
end

function S.AddInbox(code, sender)
    for _, item in ipairs(S.db.inbox) do
        if item.code == code and item.sender == sender then
            return false
        end
    end
    S.db.inbox[#S.db.inbox + 1] =
        { code = code, sender = FT.SafeText(sender, 64), received = FT.Now() }
    while #S.db.inbox > 20 do
        table.remove(S.db.inbox, 1)
    end
    return true
end
