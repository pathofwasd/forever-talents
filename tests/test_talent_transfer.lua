local Mock = dofile("tests/wow_mock.lua")
local FT = Mock.Load()
local S, M, C, L = FT.Store, FT.Model, FT.Codec, FT.Library
local checks = 0
local function check(value, message)
    checks = checks + 1
    assert(value, message)
end
for _, cid in ipairs(FT.classOrder) do
    _G.ForeverTalentsDB = nil
    local class = M.Class(cid)
    S.Init(cid, class.races[1], 60)
    local p = assert(S.CreateProfile("Destination"))
    local t = class.trees[1].talents[1].id
    check(S.Apply(M.Add, t))
    local code = assert(S.CopyTalents())
    local allocation = assert(C.DecodeTalents(code))
    check(allocation.classID == cid and #allocation.order == 1)
    check(not allocation.level and not allocation.raceID and not allocation.name)
    check(S.Checkpoint("Other route"))
    check(S.LoadNode(p.id, 1))
    local before, context = FT.Copy(S.Build()), FT.Copy(S.Draft())
    local graph = L.Pack(p)
    FT.Character.Save(
        S.Build(),
        { mode = "manual", name = "Keep character", stats = { power = 321 } }
    )
    local character = L.Pack(S.db.settings.characters)
    check(S.PasteTalents(code))
    check(
        S.Build().name == before.name
            and S.Build().level == before.level
            and S.Build().raceID == before.raceID
    )
    check(S.Draft().profileID == context.profileID and S.Draft().nodeID == context.nodeID)
    check(L.Pack(p) == graph and L.Pack(S.db.settings.characters) == character)
    check(S.Dirty() and S.Undo() and M.Same(S.Build(), before))
    check(S.Redo() and #S.Build().order == 1 and S.Draft().nodeID == 1)
    check(S.UpdateCheckpoint() and #p.order == 2 and not S.Dirty())
    local intact = assert(L.Encode())
    for _, bad in ipairs({
        code .. "!",
        code:sub(1, -2),
        "FT1:bad",
        false,
        code:gsub("FA1:", "FA2:", 1),
    }) do
        check(not S.PasteTalents(bad) and assert(L.Encode()) == intact)
    end
    local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
    local locked
    for _, candidate in ipairs(class.trees[1].talents) do
        if candidate.row > 1 then
            local ordinal = M.Index(cid)[candidate.id].index
            locked = alphabet:sub(ordinal, ordinal)
            break
        end
    end
    for _, body in ipairs({
        "FA1:" .. FT.Data.meta.tag .. ":99:A",
        "FA1:00000000:" .. cid .. ":A",
        "FA1:" .. FT.Data.meta.tag .. ":" .. cid .. ":_",
        "FA1:" .. FT.Data.meta.tag .. ":" .. cid .. ":" .. string.rep("A", 52),
        "FA1:" .. FT.Data.meta.tag .. ":" .. cid .. ":" .. string.rep(
            "A",
            class.trees[1].talents[1].max + 1
        ),
        "FA1:" .. FT.Data.meta.tag .. ":" .. cid .. ":" .. locked,
    }) do
        check(not S.PasteTalents(body .. ":" .. C.Checksum(body)) and assert(L.Encode()) == intact)
    end
    S.Preview(0)
    check(not S.PasteTalents(code))
    check(#assert(C.DecodeTalents(assert(S.CopyTalents()))).order == 0)
    S.Preview(nil)
    check(S.LoadNode(p.id, 2))
    local lower = FT.Copy(S.Build())
    lower.level = 1
    lower.order = {}
    check(S.Edit(lower))
    intact = assert(L.Encode())
    check(not S.PasteTalents(code) and assert(L.Encode()) == intact)
    check(S.SetAutoLevel(true) and S.PasteTalents(code) and S.Build().level == 10)
    check(S.UpdateCheckpoint() and not S.Dirty())
    _G.ForeverTalentsDB = FT.Copy(S.db)
    S.Init(cid, class.races[1], 60)
    check(not S.db.recovered and not S.Dirty() and #S.Build().order == 1)
end
local copied = assert(S.CopyTalents())
local other = S.Build().classID == 8 and 5 or 8
S.SwitchClass(other)
local intact = assert(L.Encode())
check(not S.PasteTalents(copied) and assert(L.Encode()) == intact)
UIParent:SetSize(1920, 1080)
FT.UI.Create()
FT.UI.copyTalents:Click()
local f = FT.UI.dialogs.talentTransfer
check(f.input:GetText() == assert(S.CopyTalents()) and not f.apply:IsShown())
FT.UI.CloseDialog()
FT.UI.pasteTalents:Click()
f.input:UserText("damaged")
check(not f.apply:IsEnabled())
local valid = assert(S.CopyTalents())
f.input:UserText(valid)
check(f.apply:IsEnabled())
f.apply:Click()
check(not f:IsShown())
print(string.format("Talent-only transfer: %d assertions passed", checks))
