local Mock = dofile("tests/wow_mock.lua")
local FT = Mock.Load()
time = function()
    return 1700000000
end
local f = assert(io.open("web/lua/bridge.lua"))
local bridge = f:read("*a")
f:close()
assert(loadstring("local FT=ForeverTalents\n" .. bridge))()
local M, C, S = FT.Model, FT.Codec, FT.Store
local b = M.New(1, 1, 60, "Legacy Impale fixture")
local t = M.Index(1)[105947]
local req = t.requires
t.requires = {}
while #b.order < 15 do
    for _, node in ipairs(M.Class(1).trees[1].talents) do
        if node.id ~= 105950 and node.id ~= 105947 and M.CanAdd(b, node.id) then
            b = assert(M.Add(b, node.id))
            break
        end
    end
end
b = assert(M.Add(b, 105947))
t.requires = req
local db = {
    schema = 1,
    tag = "7ba43a60",
    nextID = 2,
    currentClass = 1,
    settings = {},
    inbox = {},
    drafts = { [1] = { build = FT.Copy(b), profileID = "p1", nodeID = 2, undo = {}, redo = {} } },
    profiles = {
        p1 = {
            id = "p1",
            name = "Legacy branches",
            nextNode = 4,
            order = { 1, 2, 3 },
            nodes = {
                [1] = { id = 1, title = "Start", build = M.Prefix(b, 15), created = 1 },
                [2] = { id = 2, parent = 1, title = "Old Impale", build = FT.Copy(b), created = 2 },
                [3] = {
                    id = 3,
                    parent = 1,
                    title = "Other path",
                    build = M.Prefix(b, 10),
                    created = 3,
                },
            },
        },
    },
    profileOrder = { "p1" },
}
S.db = db
io.write(webCall("database", {}), "\n")
io.write(webInit(db), "\n")
for _, kind in ipairs({ "original", "build", "profile", "library", "character", "stats" }) do
    io.write(webCall("export", { kind = kind }), "\n")
end
io.write(webCall("copyTalents", {}), "\n")
io.write(webCall("updateCheckpoint", {}), "\n")
