local Mock = dofile("tests/wow_mock.lua")
local FT = Mock.Load()
local S, M, C = FT.Store, FT.Model, FT.Codec
local checks = 0
local function check(value, message)
    checks = checks + 1
    assert(value, message)
end
local function fresh()
    _G.ForeverTalentsDB = nil
    S.Init(5, 1, 40)
    return S.CreateProfile("Shadow leveling")
end
local function code(build)
    return assert(C.Encode(build or S.Build()))
end
local first = M.Class(5).trees[1].talents[1].id
local p = fresh()
check(S.Apply(M.Add, first))
local second = assert(S.Checkpoint("Second checkpoint"))
local original = code(second.build)
check(S.Apply(M.Add, first))
local edited = code()
local graph = FT.Library.Pack(p)
check(S.LoadNode(p.id, 1))
check(#p.order == 2 and FT.Library.Pack(p) == graph, "navigation created or changed a node")
check(S.Draft().nodeID == 1 and not S.Dirty())
check(S.Undo() and code() == edited and S.Draft().nodeID == second.id)
check(S.Redo() and S.Draft().nodeID == 1)
check(S.LoadNode(p.id, second.id) and code() == original)
check(S.Apply(M.Add, first))
FT.UI.Create()
FT.UI.historyTab = "graph"
FT.UI.RefreshHistory()
local items = FT.UI.ProfileNodes(p)
check(#items == 2 and not items[2].node.working, "UI created a draft node")
check(FT.UI.historyRows[2].active, "edited checkpoint lost its active highlight")
FT.UI.GraphDialog()
check(FT.UI.dialogs.graph.rows[2].active)
check(FT.UI.dialogs.graph.rows[2].detail:GetText():find("ACTIVE", 1, true))
check(FT.UI.dialogs.graph.summary:GetText():find("UNSAVED CHANGES", 1, true))
check(S.LoadNode(p.id, second.id) and code() == original and #p.order == 2)
check(S.Undo() and code() == edited)
local saved = assert(S.Checkpoint("Explicit branch"))
check(saved.parent == second.id and code(saved.build) == edited and #p.order == 3)
local decoded = assert(FT.Library.Decode(assert(FT.Library.Encode())))
_G.ForeverTalentsDB = FT.Copy(S.db)
S.Init(5, 1, 40)
p = S.db.profiles[p.id]
check(
    not S.db.recovered
        and FT.Library.Pack(S.db.profiles) == FT.Library.Pack(decoded.database.profiles)
)
check(S.DeleteNode(p.id, second.id) and not p.nodes[saved.id])
-- Loading works even when saving is unavailable or the graph is at capacity.
p = fresh()
for i = 2, 400 do
    check(S.Checkpoint("Checkpoint " .. i))
end
check(S.Apply(M.Add, first))
local before = FT.Library.Pack(p)
S.readOnly = true
check(S.LoadNode(p.id, 1) and FT.Library.Pack(p) == before and #p.order == 400)
check(S.Undo() and #S.Build().order == 1)
S.readOnly = false
check(not S.Checkpoint("At capacity"))
-- Other class edits remain working allocations, never implicit graph nodes.
p = fresh()
check(S.Apply(M.Add, first))
local priest = code()
check(S.SwitchClass(8))
local mage = assert(S.CreateProfile("Mage"))
local mageFirst = M.Class(8).trees[1].talents[1].id
check(S.Apply(M.Add, mageFirst))
local mageEdits = code()
check(S.LoadNode(p.id, 1) and #p.order == 1 and #mage.order == 1)
check(S.SwitchClass(8) and code() == mageEdits)
check(S.LoadNode(p.id, 1) and S.Undo() and code() == priest)

-- Exact reported Auto conflict: loading the snapshot restores its level, skills,
-- clean state and context. Undo/Redo retain the corresponding level mode.
_G.ForeverTalentsDB = nil
S.Init(8, 2, 60)
local fireball = M.Class(8).trees[2].talents[3].id
for _ = 1, 5 do
    check(S.Apply(M.Add, fireball))
end
p = assert(S.CreateProfile("Level 60, five points"))
original = code()
check(S.SetAutoLevel(true))
check(S.Build().level == 14 and S.AutoLevel())
local status
local changed = FT.Changed
FT.Changed = function(message)
    status = message
end
check(S.LoadNode(p.id, 1))
check(code() == original and S.Build().level == 60 and not S.AutoLevel() and not S.Dirty())
check(status:find("Auto turned off to restore saved level 60.", 1, true))
check(S.Undo() and S.Build().level == 14 and S.AutoLevel())
check(S.Redo() and code() == original and not S.AutoLevel() and not S.Dirty())
FT.Changed = changed
local persisted = FT.Copy(S.db)
_G.ForeverTalentsDB = persisted
S.Init(8, 2, 60)
check(code() == original and not S.AutoLevel() and not S.Dirty())
FT.UI.historyTab = "graph"
FT.UI.RefreshHistory()
check(
    FT.UI.historyRows[1].detail:GetText():find("Lv. 60", 1, true),
    "sidebar shows required level instead of saved target"
)
FT.UI.GraphDialog()
check(
    FT.UI.dialogs.graph.rows[1].detail:GetText():find("Lv. 60", 1, true),
    "expanded graph shows wrong checkpoint level"
)

-- A successful save starts a new continuation: old Redo must never detach it.
_G.ForeverTalentsDB = nil
S.Init(8, 2, 60)
check(S.Apply(M.Add, fireball) and S.Undo())
check(#S.Draft().redo == 1 and #S.Build().order == 0)
before = assert(FT.Library.Encode())
check(not S.CreateProfile("") and assert(FT.Library.Encode()) == before)
S.readOnly = true
check(not S.CreateProfile("Blocked") and assert(FT.Library.Encode()) == before)
S.readOnly = false
p = assert(S.CreateProfile("New saved profile"))
check(#S.Draft().redo == 0 and not S.Redo())
check(S.Build().name == p.name and S.Draft().profileID == p.id and not S.Dirty())
check(#S.Build().order == 0 and #p.nodes[1].build.order == 0)
check(S.Apply(M.Add, fireball) and S.Undo() and #S.Draft().redo == 1)
second = assert(S.Checkpoint("Empty branch"))
check(#S.Draft().redo == 0 and not S.Redo() and S.Draft().nodeID == second.id)
check(S.Apply(M.Add, fireball) and S.Undo() and S.Redo())
check(S.Build().name == p.name and S.Draft().profileID == p.id and S.Draft().nodeID == second.id)
_G.ForeverTalentsDB = FT.Copy(S.db)
S.Init(8, 2, 60)
check(S.Draft().profileID == p.id and S.Draft().nodeID == second.id and #S.Draft().redo == 0)

-- Updating a selected checkpoint changes only its saved snapshot, never its graph.
p = fresh()
check(S.Apply(M.Add, first))
second = assert(S.Checkpoint("Alternate"))
check(S.Apply(M.Add, first))
local child = assert(S.Checkpoint("Child"))
check(S.LoadNode(p.id, 1))
local sibling = assert(S.Checkpoint("Sibling"))
check(S.LoadNode(p.id, second.id))
local metadata = FT.Copy(second)
local branches = FT.Library.Pack({ child, sibling, p.nodes[1], p.order, p.nextNode })
check(S.Apply(M.Add, first))
local leveled = FT.Copy(S.Build())
leveled.level = 50
check(S.Edit(leveled))
local updated = code()
check(S.Dirty() and code(second.build) ~= updated)
check(S.UpdateCheckpoint() == second and not S.Dirty())
check(code(second.build) == updated)
check(second.id == metadata.id and second.parent == metadata.parent)
check(second.title == metadata.title and second.created == metadata.created)
check(FT.Library.Pack({ child, sibling, p.nodes[1], p.order, p.nextNode }) == branches)
check(S.LoadNode(p.id, 1) and #p.order == 4)
check(S.LoadNode(p.id, second.id) and code() == updated and not S.Dirty())
check(S.Apply(M.Add, first))
check(S.UpdateCheckpoint())
check(S.Undo() and S.Dirty())
check(S.UpdateCheckpoint() and #S.Draft().redo == 0 and not S.Redo())
check(#p.order == 4)
check(S.Apply(M.Add, first))
local beforeUpdate = FT.Library.Pack(S.db)
S.Preview(0)
check(not S.UpdateCheckpoint() and FT.Library.Pack(S.db) == beforeUpdate)
S.Preview(nil)
S.readOnly = true
check(not S.UpdateCheckpoint() and FT.Library.Pack(S.db) == beforeUpdate)
S.readOnly = false
local intact = FT.Library.Pack(p)
local draft = FT.Copy(S.Draft().build)
S.Draft().build.level = 0
check(not S.UpdateCheckpoint() and FT.Library.Pack(p) == intact)
S.Draft().build = M.New(8, 2, 60)
check(not S.UpdateCheckpoint() and FT.Library.Pack(p) == intact)
S.Draft().build = draft
check(S.UpdateCheckpoint())
local share = assert(FT.Library.EncodeProfile(p.id))
check(assert(FT.Library.DecodeProfile(share)).nodes == 4)
check(S.Apply(M.Add, first))
check(assert(FT.Library.EncodeProfile(p.id)) == share, "draft changed saved-profile link")
check(S.UpdateCheckpoint() and assert(FT.Library.EncodeProfile(p.id)) ~= share)
updated = code()
_G.ForeverTalentsDB = FT.Copy(S.db)
S.Init(5, 1, 40)
p = S.db.profiles[p.id]
check(not S.db.recovered and not S.Dirty() and code() == updated and #p.order == 4)
check(
    assert(FT.Library.Decode(assert(FT.Library.Encode()))).database.profiles[p.id].nodes[second.id]
)
check(S.DeleteNode(p.id, second.id))
check(not p.nodes[second.id] and not p.nodes[child.id] and p.nodes[sibling.id])
_G.ForeverTalentsDB = nil
S.Init(5, 1, 40)
check(not S.UpdateCheckpoint())

print(string.format("Checkpoint navigation: %d assertions passed", checks))
