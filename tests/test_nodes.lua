local Mock = dofile("tests/wow_mock.lua")
local FT = Mock.Load()
local S, M = FT.Store, FT.Model
local checks = 0
local function check(value, message)
    checks = checks + 1
    assert(value, message)
end
local function fresh()
    _G.ForeverTalentsDB = nil
    S.Init(11, 4)
    return S.CreateProfile("Branch deletion fixture")
end
local first = M.Class(11).trees[1].talents[1].id
local second = M.Class(11).trees[2].talents[1].id
local p = fresh()
S.Apply(M.Add, first)
local a = S.Checkpoint("A")
S.Apply(M.Add, first)
local a1 = S.Checkpoint("A child")
S.LoadNode(p.id, 1)
S.Apply(M.Add, second)
local b = S.Checkpoint("B")
S.Apply(M.Add, second)
local b1 = S.Checkpoint("B child")
S.LoadNode(p.id, a.id)
S.Apply(M.Add, first)
local a2 = S.Checkpoint("A later child")
local removed, count = S.NodeSubtree(p.id, a.id)
check(count == 3 and removed[a.id] and removed[a1.id] and removed[a2.id])
check(
    not removed[1] and not removed[b.id] and not removed[b1.id],
    "sibling branch included in deletion"
)
local working = FT.Copy(S.Build())
local sibling = FT.Copy(b1)
local nextID = p.nextNode
check(S.DeleteNode(p.id, a.id))
check(#p.order == 3 and not p.nodes[a.id] and not p.nodes[a1.id] and not p.nodes[a2.id])
check(p.order[1] == 1 and p.order[2] == b.id and p.order[3] == b1.id)
check(M.Same(p.nodes[b1.id].build, sibling.build) and p.nodes[b1.id].parent == sibling.parent)
check(
    M.Same(S.Build(), working) and S.Draft().nodeID == 1,
    "deleted active branch replaced the working talents"
)
check(p.nextNode == nextID, "deleted node IDs were made reusable")
local function checkContexts()
    for _, draft in pairs(S.db.drafts) do
        local entries = { draft }
        for _, entry in ipairs(draft.undo) do
            entries[#entries + 1] = entry
        end
        for _, entry in ipairs(draft.redo) do
            entries[#entries + 1] = entry
        end
        for _, entry in ipairs(entries) do
            if entry.profileID == p.id then
                check(p.nodes[entry.nodeID], "history references a deleted node")
            end
        end
    end
end
checkContexts()
check(S.Undo())
checkContexts()
check(S.Redo())
checkContexts()
local saved = FT.Copy(S.db)
_G.ForeverTalentsDB = saved
S.Init(11, 4)
p = S.db.profiles[p.id]
check(p and #p.order == 3 and not S.db.recovered, "valid pruned graph failed saved-data validation")
checkContexts()
local continued = S.Checkpoint("Continue surviving parent")
check(continued.id == nextID and continued.parent == 1)
S.LoadNode(p.id, b1.id)
working = FT.Copy(S.Build())
check(S.DeleteNode(p.id, b1.id))
check(S.Draft().nodeID == b.id and M.Same(S.Build(), working))
check(p.nodes[b.id] and p.nodes[continued.id])
local before = FT.Copy(S.db)
check(not S.DeleteNode(p.id, 999))
check(#p.order == #before.profiles[p.id].order)
S.readOnly = true
check(not S.DeleteNode(p.id, b.id))
S.readOnly = false
check(p.nodes[b.id])
local other = S.CreateProfile("Other profile")
S.LoadNode(p.id, 1)
working = FT.Copy(S.Build())
removed, count = S.NodeSubtree(p.id, 1)
check(count == #p.order)
local ok, deleted = S.DeleteNode(p.id, 1)
check(ok and deleted == count and not S.db.profiles[p.id])
check(not S.ActiveProfile() and M.Same(S.Build(), working))
check(S.db.profiles[other.id], "root deletion removed another profile")
for _, draft in pairs(S.db.drafts) do
    check(draft.profileID ~= p.id)
    for _, entry in ipairs(draft.undo) do
        check(entry.profileID ~= p.id)
    end
    for _, entry in ipairs(draft.redo) do
        check(entry.profileID ~= p.id)
    end
end
check(S.Undo())
check(not S.db.profiles[p.id], "Undo resurrected a deleted profile")
_G.ForeverTalentsDB = FT.Copy(S.db)
S.Init(11, 4)
check(S.db.profiles[other.id] and not S.db.profiles[p.id])

-- Every subtree of a mixed 80-node tree is checked against an independent
-- parent-chain walk. Creation order interleaves branches and includes depth.
p = fresh()
for i = 2, 80 do
    local parent = i % 3 == 0 and i - 1 or math.max(1, math.floor(i / 2))
    S.LoadNode(p.id, parent)
    S.Checkpoint("Node " .. i)
end
local baseline = FT.Copy(S.db)
for deletedID = 1, 80 do
    _G.ForeverTalentsDB = FT.Copy(baseline)
    S.Init(11, 4)
    local profile = S.db.profiles[p.id]
    local expected, affected = {}, 0
    for _, id in ipairs(profile.order) do
        local cursor = id
        while cursor and cursor ~= deletedID do
            cursor = profile.nodes[cursor].parent
        end
        expected[id] = cursor == deletedID
        if expected[id] then
            affected = affected + 1
        end
    end
    removed, count = S.NodeSubtree(profile.id, deletedID)
    check(count == affected)
    for id, contains in pairs(expected) do
        check((removed[id] == true) == contains)
    end
    working = FT.Copy(S.Build())
    ok, deleted = S.DeleteNode(profile.id, deletedID)
    check(ok and deleted == affected and M.Same(S.Build(), working))
    profile = S.db.profiles[profile.id]
    if deletedID == 1 then
        check(not profile)
    else
        check(#profile.order == 80 - affected)
        for id, node in pairs(profile.nodes) do
            check(not expected[id])
            check(not node.parent or profile.nodes[node.parent])
        end
    end
end
print(string.format("Checkpoint deletion: %d assertions passed", checks))
