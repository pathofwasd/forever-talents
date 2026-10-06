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
    output("remove", { id = FT.Model.Class(cid).trees[1].talents[1].id })
    output("export", { kind = "profile" })
    output("copyTalents")
    output("talentsPreview", { code = FT.Store.CopyTalents() })
    output("pasteTalents", { code = FT.Store.CopyTalents() })
    output("updateCheckpoint")
    output("export", { kind = "profile" })
    output("state")
    output("export", { kind = "build" })
    output("export", { kind = "link" })
    output("decode", { code = FT.Codec.BuildLink(FT.Store.ExportView()), buildOnly = true })
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
    output("simpleView", { enabled = true })
    output("state")
    output("skills", { filter = "now" })
    output("skillLevels", { name = skill.name })
    output("simpleView", { enabled = false })
end
output("switch", { classID = 11 })
output("auto", { enabled = false })
output("level", { level = 25 })
output("characterMode", { mode = "gear" })
output("characterSave", {
    sheet = {
        schema = 1,
        mode = "gear",
        name = "Shared character",
        trainedSkills = {
            schema = 1,
            classID = 11,
            raceID = 4,
            level = 25,
            spellIDs = { 5185, 5177 },
        },
        form = "cat",
        weaponType = "none",
        stats = { power = 123.25, hit = 93 },
        gear = {
            mainHand = {
                name = "Dagger",
                stats = { strength = 10, intellect = 23, attackPower = 14 },
                low = 10,
                high = 20,
                speed = 1.8,
                weaponType = "dagger",
            },
        },
    },
})
output("character")
output("checkTraining", { enabled = true })
output("trainingReport")
output("skills", { filter = "needsTraining" })
output("level", { level = 29 })
output("trainingReport")
output("level", { level = 25 })
output("checkTraining", { enabled = false })
output("export", { kind = "stats" })
output("export", { kind = "character" })
output("statsForSkill", { name = "Wrath", rank = 4, overrides = { coefficient = 75 } })
output("simulate", { name = "Wrath", rank = 4, overrides = { power = 900, crit = 13 } })
output(
    "simulate",
    { name = "Wrath", rank = 4, overrides = { power = 900, crit = 13 }, withTalents = false }
)
output("character")
output("export", { kind = "library" })
output(
    "simulate",
    { name = "Wrath", rank = 4, overrides = { attackPower = 1000, apCoefficient = 20 } }
)
output("export", {
    kind = "stats",
    skillName = "Wrath",
    state = { attackPower = 1000, apCoefficient = 20, dotAPCoefficient = 30 },
})
output("switch", { classID = 1 })
output("skillLevels", { name = "Bloodthirst" })
output("simulate", { name = "Bloodthirst", rank = 1, state = { attackPower = 1000, crit = 0 } })
output("switch", { classID = 7 })
output("skillLevels", { name = "Lava Burst" })
output("skillLevels", { name = "Riptide" })
output("simulate", { name = "Riptide", rank = 1, state = { power = 100, crit = 0 } })
output("switch", { classID = 2 })
output("auto", { enabled = false })
for _, level in ipairs({ 49, 50, 53, 54, 60 }) do
    output("level", { level = level })
    output("skills", { query = "Holy Light", includeRacials = false })
end
output("simulate", { name = "Holy Light", rank = 7, state = { power = 100, crit = 0 } })
for _, cid in ipairs({ 4, 5, 8, 9 }) do
    output("switch", { classID = cid })
    output("level", { level = 60 })
    output("skills", { filter = "all" })
end
output("switch", { classID = 8 })
output("race", { raceID = 7 })
output("characterSave", {
    sheet = {
        schema = 1,
        mode = "gear",
        name = "Alias capture",
        trainedSkills = { schema = 1, classID = 8, raceID = 7, level = 60, spellIDs = { 28271 } },
        stats = {},
        gear = {},
    },
})
output("training", { name = "Polymorph" })
output("checkTraining", { enabled = true })
output("trainingReport")
output("export", { kind = "character" })
output("export", { kind = "library" })
output(
    "simulate",
    { name = "Fireball", rank = 12, state = { power = 100, crit = 0, cooldowns = true } }
)
output("import", { code = FT.Codec.Encode(dofile("tests/fixtures/mage_fire.lua")) })
output("auto", { enabled = true })
output("save", { title = "Removal parity" })
output("checkpoint", { title = "Frozen allocation" })
output("export", { kind = "build" })
output("remove", { id = 105796 })
output("state")
for _, kind in ipairs({ "build", "stats", "character", "library" }) do
    output("export", { kind = kind })
end
output("undo")
output("export", { kind = "build" })
output("redo")
output("export", { kind = "build" })
output("remove", { id = 105796 })
output("state")
output("remove", { id = 105796 })
output("export", { kind = "build" })
output("remove", { id = 105790 })
output("export", { kind = "library" })
local profileID = FT.Store.Draft().profileID
output("load", { profileID = profileID, nodeID = 1 })
output("state")
output("export", { kind = "library" })
output("undo")
output("export", { kind = "build" })
output("redo")
output("load", { profileID = profileID, nodeID = 3 })
output("export", { kind = "character" })
output("export", { kind = "library" })
output("remove", { id = 105776 })
output("export", { kind = "profile", profileID = profileID })
output("export", { kind = "profileLink", profileID = profileID })
output("decode", { code = FT.Library.ProfileLink(profileID), profileOnly = true })
output("import", { code = FT.Library.ProfileLink(profileID), profileOnly = true })
output("state")
output("export", { kind = "build" })
output("export", { kind = "library" })
