local FT = ForeverTalents or dofile("tests/wow_mock.lua").Load()
local M = FT.Model
local names = {}
for id, talent in pairs(M.Index(8)) do
    names[talent.name] = id
end
local build = M.New(8, 2, 60, "Fire removal regression")
-- 33 Fire / 8 Frost, with supporting ranks spent after an early gated point.
for _, entry in ipairs({
    { "Incineration", 3 },
    { "Improved Fireball", 5 },
    { "Flame Throwing", 2 },
    { "Impact", 3 },
    { "Pyroblast", 1 },
    { "Improved Flamestrike", 1 },
    { "Improved Scorch", 1 },
    { "Improved Fire Ward", 2 },
    { "Heating Up", 1 },
    { "Master of Elements", 2 },
    { "Improved Flamestrike", 2 },
    { "Critical Mass", 3 },
    { "Blast Wave", 1 },
    { "Fire Power", 5 },
    { "Combustion", 1 },
    { "Elemental Precision", 5 },
    { "Permafrost", 3 },
}) do
    for _ = 1, entry[2] do
        build = assert(M.Add(build, names[entry[1]]))
    end
end
if arg and arg[0] == "tests/fixtures/mage_fire.lua" then
    print(assert(FT.Codec.Encode(build)))
end
return build
