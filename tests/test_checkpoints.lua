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
check(S.Dirty())
check(S.LoadNode(p.id, 1))
check(#p.order == 3, "navigation did not save a child checkpoint")
local saved = p.nodes[3]
check(saved.parent == second.id and saved.title == "Autosaved · Second checkpoint")
check(code(saved.build) == edited, "autosave lost allocation order or level")
check(code(second.build) == original, "autosave overwrote the saved checkpoint")
check(#S.Build().order == 0 and not S.Dirty())
check(S.Undo() and code() == edited and S.Draft().nodeID == saved.id)
check(S.Redo() and S.Draft().nodeID == 1 and #S.Build().order == 0)
check(S.LoadNode(p.id, saved.id) and code() == edited)
check(S.LoadNode(p.id, second.id) and code() == original)
check(#p.order == 3, "clean navigation created extra checkpoints")
check(S.Apply(M.Add, first))
check(S.LoadNode(p.id, 1) and #p.order == 3, "identical changes created a duplicate child")

-- Opening the same saved node also protects a changed draft before restoring it.
check(S.LoadNode(p.id, second.id))
check(S.Apply(M.Add, first))
check(S.Apply(M.Add, first))
edited = code()
check(S.LoadNode(p.id, second.id) and code() == original)
saved = p.nodes[p.order[#p.order]]
check(saved.parent == second.id and code(saved.build) == edited)

-- The sidebar and expanded graph distinguish the working allocation from saved nodes.
check(S.Apply(M.Add, first))
FT.UI.Create()
FT.UI.historyTab = "graph"
FT.UI.RefreshHistory()
local items = FT.UI.ProfileNodes(p)
local working
for _, item in ipairs(items) do
    if item.node.working then
        working = item.node
    end
end
check(working and working.id == 0 and working.parent == second.id)
check(code(working.build) == code())
local row
for _, candidate in ipairs(FT.UI.historyRows) do
    if candidate:IsShown() and candidate.title:GetText() == "Current draft" then
        row = candidate
    end
end
check(row and not row.delete:IsShown(), "draft can be mistaken for a removable saved node")
local count = #p.order
row:Click()
check(#p.order == count and S.Dirty(), "clicking current draft reset its edits")
FT.UI.GraphDialog()
local dialog = FT.UI.dialogs.graph
local draftRow
for _, candidate in ipairs(dialog.rows) do
    if candidate:IsShown() and candidate.title:GetText() == "Current draft" then
        draftRow = candidate
    end
end
check(draftRow and not draftRow.delete:IsShown())
draftRow:Click()
check(#p.order == count and S.Dirty())

-- Both source and destination class drafts survive loading another class's checkpoint.
edited = code()
S.SwitchClass(8)
local mage = S.CreateProfile("Mage alternate")
local mageFirst = M.Class(8).trees[1].talents[1].id
check(S.Apply(M.Add, mageFirst))
local mageEdits = code()
S.SwitchClass(5)
check(S.LoadNode(mage.id, 1))
check(code(mage.nodes[2].build) == mageEdits and mage.nodes[2].parent == 1)
saved = p.nodes[S.db.drafts[5].nodeID]
check(code(saved.build) == edited and saved.parent == second.id)
check(#S.Build().order == 0 and S.classID == 8)
local library = assert(FT.Library.Encode())
local decoded = assert(FT.Library.Decode(library))
check(decoded.database.profiles[p.id].nodes[saved.id].parent == second.id)
local db = FT.Copy(S.db)
_G.ForeverTalentsDB = db
S.Init(8, 1)
check(not S.db.recovered)
check(FT.Library.Pack(S.db.profiles) == FT.Library.Pack(decoded.database.profiles))
check(FT.Library.Pack(S.db.drafts) == FT.Library.Pack(decoded.database.drafts))
check(S.LoadNode(p.id, saved.id) and code() == edited)
check(S.DeleteNode(p.id, second.id))
check(not p.nodes[second.id] or not S.db.profiles[p.id].nodes[second.id])
check(not S.db.profiles[p.id].nodes[saved.id], "auto-saved descendants survived parent deletion")

-- Saving unavailable or at capacity: refuse navigation, preserving the entire draft/graph.
p = fresh()
for i = 2, 400 do
    check(S.Checkpoint("Checkpoint " .. i))
end
check(S.Apply(M.Add, first))
local before = assert(FT.Library.Encode())
local ok, why = S.LoadNode(p.id, 1)
check(not ok and why:find("400 checkpoints", 1, true))
check(assert(FT.Library.Encode()) == before and S.Dirty())
S.readOnly = true
ok, why = S.LoadNode(p.id, 1)
check(not ok and why:find("Saving is disabled", 1, true))
check(assert(FT.Library.Encode()) == before)
S.readOnly = false

S.SwitchClass(8)
mage = S.CreateProfile("Capacity preflight")
check(S.Apply(M.Add, mageFirst))
before = assert(FT.Library.Encode())
ok, why = S.LoadNode(p.id, 1)
check(not ok and why:find("400 checkpoints", 1, true))
check(
    #mage.order == 1 and assert(FT.Library.Encode()) == before,
    "partial cross-class autosave on failed navigation"
)

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

print(string.format("Checkpoint navigation: %d assertions passed", checks))
