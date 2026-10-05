-- The same trusted bridge is compatible with the native target Lua 5.1.
-- Native references load actual TOC modules first, then adapt their outputs.
local Mock = dofile("tests/wow_mock.lua")
local FT = Mock.Load()
time = function()
    return 1700000000
end
local f = assert(io.open("web/lua/bridge.lua"))
local bridge = f:read("*a")
f:close()
assert(loadstring("local FT=ForeverTalents\n" .. bridge))()
webInit({})
local function output(name, p)
    io.write(webCall(name, p), "\n")
end
for _, cid in ipairs(FT.classOrder) do
    output("switch", { classID = cid })
    output("auto", { enabled = true })
    for _, tree in ipairs(FT.Model.Class(cid).trees) do
        output("add", { id = tree.talents[1].id, fill = true })
    end
    output("save", { title = "Parity " .. FT.Model.Class(cid).name })
    output("checkpoint", { title = "Branch fixture" })
    output("state")
    output("export", { kind = "build" })
    output("scenario", {
        state = {
            power = 175.25,
            crit = 14.5,
            attackPower = 260,
            weaponMin = 90,
            weaponMax = 120,
            bleeding = true,
            coefficient = 57.125,
        },
        name = "Wrath",
        manual = true,
    })
    output("export", { kind = "stats" })
    output("export", { kind = "character" })
    local skill = FT.Skills.Prepare(cid).list[1]
    output(
        "simulate",
        { name = skill.name, rank = 1, state = { power = 75, crit = 13, hit = 90, reduction = 10 } }
    )
    output("preview", { count = 3 })
    output("export", { kind = "character" })
    output("preview", {})
end
output("export", { kind = "library" })
