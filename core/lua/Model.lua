local _, FT = ...
local M = {}
FT.Model = M

function M.Class(id)
    return FT.Data.classes[id]
end
function M.RaceAllowed(classID, raceID)
    local class = M.Class(classID)
    if not class then
        return false
    end
    for _, id in ipairs(class.races) do
        if id == raceID then
            return true
        end
    end
    return false
end

function M.Index(classID)
    local c = M.Class(classID)
    if not c then
        return nil
    end
    if not c.index then
        c.index, c.byOrdinal, c.treeByID = {}, {}, {}
        for ti, tree in ipairs(c.trees) do
            c.treeByID[tree.id] = tree
            for _, t in ipairs(tree.talents) do
                t.treeID, t.treeIndex, t.treeName = tree.id, ti, tree.name
                c.index[t.id], c.byOrdinal[t.index] = t, t
            end
        end
    end
    return c.index, c.byOrdinal
end

function M.New(classID, raceID, level, name)
    local c = M.Class(classID) or M.Class(11)
    return {
        classID = c.id,
        raceID = M.RaceAllowed(c.id, raceID) and raceID or c.races[1],
        level = level or 60,
        name = FT.SafeText(name or "Untitled build"),
        order = {},
    }
end

function M.Budget(level)
    return math.min(51, math.max(0, level - 9))
end
function M.RequiredLevel(build)
    return #build.order > 0 and #build.order + 9 or 1
end

function M.Counts(build, count)
    local points, trees = {}, {}
    local index = M.Index(build.classID)
    for i = 1, math.min(count or #build.order, #build.order) do
        local id, t = build.order[i], index[build.order[i]]
        if t then
            points[id] = (points[id] or 0) + 1
            trees[t.treeID] = (trees[t.treeID] or 0) + 1
        end
    end
    return points, trees
end

local function canAdd(build, id, points, trees, spent)
    local index = M.Index(build.classID)
    local t = index and index[id]
    if not t then
        return false, "That talent does not belong to this class."
    end
    if spent >= M.Budget(build.level) then
        return false,
            "No points left at level "
                .. build.level
                .. ". Raise the target level to keep planning."
    end
    if (points[id] or 0) >= t.max then
        return false, "This talent is already at its maximum rank."
    end
    if (trees[t.treeID] or 0) < t.gate then
        return false, "Spend " .. t.gate .. " points in " .. t.treeName .. " to unlock this row."
    end
    for _, req in ipairs(t.requires) do
        if (points[req.id] or 0) < req.points then
            return false,
                "Requires " .. req.points .. " / " .. index[req.id].max .. " " .. req.name .. "."
        end
    end
    return true
end

function M.CanAdd(build, id)
    local points, trees = M.Counts(build)
    return canAdd(build, id, points, trees, #build.order)
end

function M.Validate(build)
    if type(build) ~= "table" or not M.Class(build.classID) then
        return false, "Unknown class."
    end
    if not M.RaceAllowed(build.classID, build.raceID) then
        return false, "That race cannot play this class in Forever."
    end
    if
        type(build.level) ~= "number"
        or build.level % 1 ~= 0
        or build.level < 1
        or build.level > 60
    then
        return false, "Target level must be between 1 and 60."
    end
    if type(build.order) ~= "table" or #build.order > 51 then
        return false, "A build can contain at most 51 points."
    end
    local n = 0
    for k in pairs(build.order) do
        if type(k) ~= "number" or k % 1 ~= 0 or k < 1 or k > #build.order then
            return false, "Invalid point order."
        end
        n = n + 1
    end
    if n ~= #build.order then
        return false, "The point order contains a gap."
    end
    local points, trees, index = {}, {}, M.Index(build.classID)
    for i, id in ipairs(build.order) do
        local ok, why = canAdd(build, id, points, trees, i - 1)
        if not ok then
            return false, "Point " .. i .. ": " .. why
        end
        local t = index[id]
        points[id], trees[t.treeID] = (points[id] or 0) + 1, (trees[t.treeID] or 0) + 1
    end
    return true
end

function M.Add(build, id, fill)
    local nextBuild, added = FT.Copy(build), 0
    repeat
        local ok, why = M.CanAdd(nextBuild, id)
        if not ok then
            if added == 0 then
                return nil, why
            end
            break
        end
        nextBuild.order[#nextBuild.order + 1] = id
        added = added + 1
    until not fill
    return nextBuild
end

function M.Remove(build, id, all)
    local result, found = FT.Copy(build), false
    for i = #result.order, 1, -1 do
        if result.order[i] == id then
            table.remove(result.order, i)
            found = true
            if not all then
                break
            end
        end
    end
    if not found then
        return nil, "No points are spent in this talent."
    end
    -- Replaying the retained order proves both the final allocation and every
    -- leveling step remain legal. Never pop an unrelated last point.
    local ok, why = M.Validate(result)
    if not ok then
        return nil, "Remove dependent points first. " .. why
    end
    return result
end

function M.Reset(build, treeID)
    local nextBuild, index = FT.Copy(build), M.Index(build.classID)
    nextBuild.order = {}
    if treeID then
        for _, id in ipairs(build.order) do
            if index[id].treeID ~= treeID then
                nextBuild.order[#nextBuild.order + 1] = id
            end
        end
    end
    return nextBuild
end

function M.Prefix(build, count)
    local result = FT.Copy(build)
    while #result.order > count do
        table.remove(result.order)
    end
    return result
end

function M.Same(a, b)
    if
        not a
        or not b
        or a.classID ~= b.classID
        or a.raceID ~= b.raceID
        or a.level ~= b.level
        or a.name ~= b.name
        or #a.order ~= #b.order
    then
        return false
    end
    for i, id in ipairs(a.order) do
        if b.order[i] ~= id then
            return false
        end
    end
    return true
end

function M.Reorder(build, from, to)
    if from < 1 or from > #build.order or to < 1 or to > #build.order then
        return nil, "Choose a point in the order."
    end
    local result = FT.Copy(build)
    local id = table.remove(result.order, from)
    table.insert(result.order, to, id)
    local ok, why = M.Validate(result)
    if not ok then
        return nil, "That move breaks the leveling order. " .. why
    end
    return result
end

function M.FromRanks(classID, raceID, level, ranks, name)
    local build = M.New(classID, raceID, level, name)
    local index = M.Index(classID)
    for id, rank in pairs(ranks) do
        if
            not index[id]
            or type(rank) ~= "number"
            or rank % 1 ~= 0
            or rank < 0
            or rank > index[id].max
        then
            return nil, "The client's talents differ from this dataset."
        end
    end
    -- Client APIs do not expose historical spend order; derive a legal one.
    local progress = true
    while progress do
        progress = false
        local counts = M.Counts(build)
        for _, tree in ipairs(M.Class(classID).trees) do
            for _, t in ipairs(tree.talents) do
                if (counts[t.id] or 0) < (ranks[t.id] or 0) and M.CanAdd(build, t.id) then
                    build.order[#build.order + 1] = t.id
                    progress = true
                    counts[t.id] = (counts[t.id] or 0) + 1
                end
            end
        end
    end
    local points = M.Counts(build)
    for id, rank in pairs(ranks) do
        if (points[id] or 0) ~= rank then
            return nil, "These talents cannot form a legal build with the captured data."
        end
    end
    return build
end
