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
        for cid, draft in pairs(db.drafts) do
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
