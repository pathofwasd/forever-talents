local _, FT = ...
local L, C, S = {}, FT.Codec, FT.Store
FT.Library = L
-- A length-prefixed, typed wire format. This parser never executes Lua.
-- Keys are sorted for deterministic exports and id-independent deduplication.
local LIMIT = 3 * 1024 * 1024
local function pack(value, depth)
    depth = depth or 0
    assert(depth < 48, "Library is nested too deeply.")
    local kind = type(value)
    if kind == "nil" then
        return "Z"
    end
    if kind == "boolean" then
        return value and "B1" or "B0"
    end
    if kind == "number" then
        assert(value == value and math.abs(value) < 1e15, "Invalid library number.")
        local str = string.format("%.14g", value)
        return "N" .. #str .. ":" .. str
    end
    if kind == "string" then
        return "S" .. #value .. ":" .. value
    end
    assert(kind == "table", "Invalid library type.")
    local keys = {}
    for key in pairs(value) do
        assert(type(key) == "number" or type(key) == "string", "Invalid key.")
        keys[#keys + 1] = key
    end
    table.sort(keys, function(a, b)
        if type(a) ~= type(b) then
            return type(a) < type(b)
        end
        return a < b
    end)
    local out = { "T" .. #keys .. ":" }
    for _, key in ipairs(keys) do
        out[#out + 1] = pack(key, depth + 1)
        out[#out + 1] = pack(value[key], depth + 1)
    end
    return table.concat(out)
end
local function unpackData(text)
    local pos, objects = 1, 0
    local function length()
        local stop = text:find(":", pos, true)
        assert(stop and stop - pos <= 8, "Invalid field length.")
        local value = text:sub(pos, stop - 1)
        assert(value:match("^%d+$"), "Invalid length.")
        local n = tonumber(value)
        assert(n <= LIMIT, "Library field is too large.")
        pos = stop + 1
        return n
    end
    local function read(depth)
        objects = objects + 1
        assert(objects <= 250000 and depth < 48, "Library is too complex.")
        local kind = text:sub(pos, pos)
        pos = pos + 1
        if kind == "Z" then
            return nil
        end
        if kind == "B" then
            local v = text:sub(pos, pos)
            pos = pos + 1
            assert(v == "1" or v == "0", "Invalid boolean.")
            return v == "1"
        end
        local n = length()
        if kind == "S" or kind == "N" then
            assert(pos + n - 1 <= #text, "Incomplete field.")
            local value = text:sub(pos, pos + n - 1)
            pos = pos + n
            if kind == "S" then
                return value
            end
            local num = tonumber(value)
            assert(num and num == num and math.abs(num) < 1e15, "Invalid number.")
            return num
        end
        assert(kind == "T" and n <= 100000, "Invalid table.")
        local result = {}
        for i = 1, n do
            local key = read(depth + 1)
            assert(type(key) == "string" or type(key) == "number", "Invalid key.")
            assert(result[key] == nil, "Duplicate key.")
            result[key] = read(depth + 1)
        end
        return result
    end
    local value = read(0)
    assert(pos == #text + 1, "Unexpected trailing data.")
    return value
end
local function portable(db)
    return {
        schema = db.schema,
        tag = db.tag,
        drafts = FT.Copy(db.drafts),
        profiles = FT.Copy(db.profiles),
        profileOrder = FT.Copy(db.profileOrder),
        nextID = db.nextID,
        currentClass = db.currentClass,
        settings = {
            scenario = FT.Copy(db.settings.scenario),
            scenarioSkill = db.settings.scenarioSkill,
            statsProfile = FT.Copy(db.settings.statsProfile),
            characters = FT.Copy(db.settings.characters),
        },
    }
end
function L.Encode()
    local ok, data = pcall(pack, portable(S.db))
    if not ok then
        return nil, "Could not export library: " .. tostring(data)
    end
    if #data > LIMIT * 0.72 then
        return nil, "Library exceeds the portable 3 MB limit. Export smaller individual profiles."
    end
    local body = "FL1:" .. FT.Data.meta.tag .. ":" .. C.Base64(data)
    return body .. ":" .. C.Checksum(body)
end
function L.Decode(code)
    if type(code) ~= "string" or #code > LIMIT then
        return nil, "Library strings must be at most 3 MB."
    end
    code = code:match("^%s*(.-)%s*$")
    local tag, payload, checksum = code:match("^FL1:([%x]+):([%w_-]+):([%x]+)$")
    if not tag then
        return nil, "Paste a complete FL1 library string."
    end
    if tag ~= FT.Data.meta.tag then
        return nil, "Library uses a different talent dataset. Update both versions first."
    end
    if #checksum ~= 8 or C.Checksum(code:match("^(.*):[^:]+$")) ~= checksum then
        return nil, "Library is incomplete or damaged."
    end
    local data = C.Unbase64(payload)
    if not data then
        return nil, "Invalid library encoding."
    end
    local ok, db = pcall(unpackData, data)
    if
        not ok
        or type(db) ~= "table"
        or db.schema ~= 1
        or db.tag ~= tag
        or type(db.profiles) ~= "table"
        or type(db.drafts) ~= "table"
        or type(db.profileOrder) ~= "table"
    then
        return nil, "Invalid library structure."
    end
    -- Validate through the store, rejecting any export that requires recovery.
    local old = {
        db = S.db,
        classID = S.classID,
        preview = S.preview,
        readOnly = S.readOnly,
        saved = _G.ForeverTalentsDB,
    }
    _G.ForeverTalentsDB = FT.Copy(db)
    local checked, err = pcall(S.Init, db.currentClass or 11, 4, 60)
    local valid = checked and S.db and not S.db.recovered and #S.db.profileOrder == #db.profileOrder
    local normalized = checked and S.db
    S.db, S.classID, S.preview, S.readOnly = old.db, old.classID, old.preview, old.readOnly
    _G.ForeverTalentsDB = old.saved
    if not valid then
        return nil, "Library contains invalid builds or checkpoints. Your library was kept."
    end
    local nodes, drafts = 0, 0
    for _, p in pairs(normalized.profiles) do
        nodes = nodes + #p.order
    end
    for _ in pairs(db.drafts) do
        drafts = drafts + 1
    end
    return {
        kind = "library",
        database = normalized,
        profiles = #normalized.profileOrder,
        nodes = nodes,
        drafts = drafts,
    }
end
local function identity(profile)
    local copy = FT.Copy(profile)
    copy.id = nil
    return pack(copy)
end

function L.IsProfileShare(input)
    if type(input) ~= "string" then
        return false
    end
    input = input:match("^%s*(.-)%s*$")
    return input:match("^FP%d+:") ~= nil or input:sub(1, #C.WebURL + 9) == C.WebURL .. "#profile="
end

function L.EncodeProfile(profileID)
    local profile, selected = S.ShareProfile(profileID)
    if not profile then
        return nil, selected
    end
    local wire =
        { name = profile.name, nextNode = profile.nextNode, order = profile.order, nodes = {} }
    for _, id in ipairs(profile.order) do
        local node = profile.nodes[id]
        local code, why = C.Encode(node.build)
        if not code then
            return nil, why
        end
        wire.nodes[id] =
            { parent = node.parent, title = node.title, created = node.created, build = code }
    end
    local payload = pack({ profile = wire, selected = selected })
    local body = "FP1:" .. FT.Data.meta.tag .. ":" .. C.Base64(payload)
    if #body + 9 > LIMIT then
        return nil, "Profile exceeds the portable 3 MB limit."
    end
    return body .. ":" .. C.Checksum(body)
end

function L.ProfileLink(profileID)
    local code, why = L.EncodeProfile(profileID)
    if not code then
        return nil, why
    end
    local link = C.WebURL .. "#profile=" .. code
    if #link > 65536 then
        return nil,
            "This checkpoint tree is too large for a link. Copy its profile string or save it to a file."
    end
    return link
end

function L.DecodeProfile(input)
    if type(input) ~= "string" or #input > LIMIT then
        return nil, "Profile strings must be at most 3 MB."
    end
    input = input:match("^%s*(.-)%s*$")
    if input:match("^https?://") then
        if #input > 65536 then
            return nil,
                "Profile links must be at most 65536 characters. Use a profile string or file instead."
        end
        local why
        input, why = C.LinkCode(input, "profile")
        if not input then
            return nil, why
        end
    end
    local version, tag, payload, checksum = input:match("^(FP%d+):([%x]+):([%w_-]+):([%x]+)$")
    if not version then
        return nil, "Paste a complete Forever Talents profile link or FP1 string."
    end
    if version ~= "FP1" then
        return nil, "This profile needs a newer version of Forever Talents."
    end
    if tag ~= FT.Data.meta.tag then
        return nil, "Profile uses a different talent dataset. Update both versions first."
    end
    if #checksum ~= 8 or C.Checksum(input:match("^(.*):[^:]+$")) ~= checksum then
        return nil, "The profile is incomplete or damaged. Copy the entire link or string again."
    end
    local data = C.Unbase64(payload)
    local ok, wire = pcall(unpackData, data or "")
    local raw = ok and type(wire) == "table" and wire.profile
    if type(raw) ~= "table" or type(raw.nodes) ~= "table" or type(raw.order) ~= "table" then
        return nil, "Invalid profile structure."
    end
    local profile =
        { id = "p1", name = raw.name, nextNode = raw.nextNode, order = raw.order, nodes = {} }
    for id, node in pairs(raw.nodes) do
        local build, why = type(node) == "table" and C.Decode(node.build)
        if not build then
            return nil, why or "Invalid checkpoint in this profile."
        end
        profile.nodes[id] = {
            id = id,
            parent = node.parent,
            title = node.title,
            created = node.created,
            build = build,
        }
    end
    local database = {
        schema = 1,
        tag = tag,
        profiles = { p1 = profile },
        profileOrder = { "p1" },
        nextID = 2,
        drafts = {},
        settings = {},
    }
    local packed = "FL1:" .. tag .. ":" .. C.Base64(pack(database))
    local checked, why = L.Decode(packed .. ":" .. C.Checksum(packed))
    if not checked then
        return nil, why
    end
    profile = checked.database.profiles.p1
    if type(wire.selected) ~= "number" or not profile.nodes[wire.selected] then
        return nil, "The selected checkpoint is missing from this profile."
    end
    return {
        kind = "profile",
        profile = profile,
        selected = wire.selected,
        nodes = #profile.order,
        build = profile.nodes[wire.selected].build,
    }
end

function L.ImportProfile(snapshot)
    if not snapshot or snapshot.kind ~= "profile" then
        return nil, "No profile to import."
    end
    local result, why = L.Merge({
        database = {
            profiles = { p1 = snapshot.profile },
            profileOrder = { "p1" },
        },
    }, false)
    if not result then
        return nil, why
    end
    local key = identity(snapshot.profile)
    for _, id in ipairs(S.db.profileOrder) do
        if identity(S.db.profiles[id]) == key then
            local draft = S.db.drafts[snapshot.build.classID]
            local autoDisabled = draft
                and draft.autoLevel
                and snapshot.build.level ~= FT.Model.RequiredLevel(snapshot.build)
            local loaded, reason = S.LoadNode(id, snapshot.selected)
            result.profileID, result.loaded = id, loaded
            FT.Changed(
                loaded
                        and ("Opened " .. snapshot.profile.name .. " with " .. snapshot.nodes .. " checkpoints." .. (autoDisabled and (" Auto turned off to restore saved level " .. snapshot.build.level .. ".") or ""))
                    or (
                        "Build added to Library. "
                        .. (reason or "Open it after saving your current draft.")
                    )
            )
            return result
        end
    end
end

function L.Merge(snapshot, includeDrafts)
    if S.readOnly then
        return false, "Saving is disabled to preserve newer saved data."
    end
    local db = snapshot and snapshot.database
    if type(db) ~= "table" then
        return false, "No library to merge."
    end
    local ids, seen, added, skipped = {}, {}, 0, 0
    for id, p in pairs(S.db.profiles) do
        seen[identity(p)] = id
    end
    for _, id in ipairs(db.profileOrder) do
        local p = db.profiles[id]
        local key = identity(p)
        local existing = seen[key]
        if existing then
            ids[id] = existing
            skipped = skipped + 1
        else
            local newID = "p" .. S.db.nextID
            while S.db.profiles[newID] do
                S.db.nextID = S.db.nextID + 1
                newID = "p" .. S.db.nextID
            end
            S.db.nextID = S.db.nextID + 1
            local copy = FT.Copy(p)
            copy.id = newID
            S.db.profiles[newID] = copy
            S.db.profileOrder[#S.db.profileOrder + 1] = newID
            ids[id] = newID
            seen[key] = newID
            added = added + 1
        end
    end
    if includeDrafts then
        local function context(entry)
            if entry.profileID then
                entry.profileID = ids[entry.profileID]
                if not entry.profileID then
                    entry.nodeID = nil
                end
            end
        end
        for cid, draft in pairs(db.drafts or {}) do
            local copy = FT.Copy(draft)
            context(copy)
            for _, entry in ipairs(copy.undo) do
                context(entry)
            end
            for _, entry in ipairs(copy.redo) do
                context(entry)
            end
            S.db.drafts[cid] = copy
        end
        S.preview = nil
    end
    if db.settings and db.settings.scenario then
        S.db.settings.statsProfile = FT.Copy(db.settings.statsProfile)
        if db.settings.characters then
            S.db.settings.characters = S.db.settings.characters or {}
            for cid, character in pairs(db.settings.characters) do
                S.db.settings.characters[cid] = FT.Copy(character)
            end
        end
        S.db.settings.scenario = FT.Simulation.State(db.settings.scenario)
        S.db.settings.scenarioSkill = FT.SafeText(db.settings.scenarioSkill, 80)
    end
    FT.Changed(
        "Library merged: "
            .. added
            .. " profiles added, "
            .. skipped
            .. " identical profiles skipped"
            .. (includeDrafts and "; class drafts replaced." or "; your working drafts are kept.")
    )
    return { added = added, skipped = skipped }
end
L.Pack = pack
L.Unpack = unpackData
