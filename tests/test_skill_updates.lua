local Mock = dofile("tests/wow_mock.lua")
local FT = Mock.Load()
local A, M, Sim = FT.Skills, FT.Model, FT.Simulation
local checks = 0
local function check(value, message)
    checks = checks + 1
    assert(value, message)
end
local function near(a, b)
    check(math.abs(a - b) < 0.00001, tostring(a) .. " vs " .. tostring(b))
end

-- Talent unlocks and trainer upgrades are independent sources. Exercise the
-- restored boundary for every affected class, including the unavailable state.
local cases = {
    { 1, "Bloodthirst", 23881, 40, 48, 23892 },
    { 11, "Insect Swarm", 5570, 25, 30, 24974 },
    { 2, "Seal of Command", 20375, 20, 30, 20915 },
    { 3, "Counterattack", 19306, 25, 30, 1242634 },
    { 5, "Mind Flay", 15407, 20, 28, 17311 },
    { 7, "Riptide", 408521, 40, 50, 1239242 },
    { 8, "Pyroblast", 11366, 20, 24, 12505 },
    { 9, "Shadowburn", 17877, 20, 24, 18867 },
}
for _, case in ipairs(cases) do
    local cid, name, id, level, upgrade, nextID = unpack(case)
    local skill = assert(A.Prepare(cid).byName[name])
    local points = { [skill.unlock.id] = 1 }
    check(skill.ranks[1].spellID == id and skill.ranks[1].talentGranted)
    check(not A.CurrentRank(skill, level, {}), name .. " available without talent")
    check(not A.CurrentRank(skill, level - 1, points), name .. " available below unlock")
    check(A.CurrentRank(skill, level, points).spellID == id)
    check(A.CurrentRank(skill, upgrade - 1, points).spellID == id)
    check(A.CurrentRank(skill, upgrade, points).spellID == nextID)
    local levels, unlock = A.Levels(skill)
    check(unlock == level and levels[1].level == level and levels[1].talentGranted)
    check(levels[2].level == upgrade)
end

local restored = 0
for _, cid in ipairs(FT.classOrder) do
    for _, skill in ipairs(A.Prepare(cid).list) do
        if skill.ranks[1].label == "Rank 1" and skill.ranks[1].talentGranted then
            restored = restored + 1
            local first = skill.ranks[1]
            check(first.toLevel >= first.level, "invalid first-rank interval")
            check(first.spellID == skill.unlock.ranks[1].spellID)
            local occurrences = 0
            for _, rank in ipairs(skill.ranks) do
                if rank.live and rank.spellID == first.spellID then
                    occurrences = occurrences + 1
                end
            end
            check(occurrences == 1, "duplicate first rank")
        end
    end
end
check(restored == 31)
check(not A.Prepare(11).byName["Tiger's Fury"], "removed ability remains in skill browser")
check(#A.List(M.New(11), 60, "Tiger's Fury", "all") == 0)
local mutilate = A.Prepare(4).byName.Mutilate
check(not mutilate.ranks[1].talentGranted and mutilate.ranks[1].label == "Rank 1")
local lava = A.Prepare(7).byName["Lava Burst"]
check(A.CurrentRank(lava, 49, { [lava.unlock.id] = 1 }).spellID == 408490)
check(A.CurrentRank(lava, 50, { [lava.unlock.id] = 1 }).spellID == 1238299)
for _, rank in ipairs(A.Levels(lava)) do
    check(not rank.toLevel or rank.toLevel >= rank.level, "archived invalid interval shown")
end
local rage = A.Prepare(1).byName["Berserker Rage"]
check(not A.CurrentRank(rage, 29, {}) and A.CurrentRank(rage, 30, {}).spellID == 18499)

local blood = A.Prepare(1).byName.Bloodthirst
for _, rank in ipairs(blood.ranks) do
    check(rank.text:find("45% of your Attack Power", 1, true))
end
near(
    Sim.Calculate(M.New(1, nil, 40), blood, blood.ranks[1], { attackPower = 1000, crit = 0 }).expected,
    480
)
local preview = Sim.Calculate(M.New(1, nil, 40), blood, blood.ranks[1], { crit = 0 })
check(table.concat(preview.warnings, " "):find("talent is not learned", 1, true))
local riptide = A.Prepare(7).byName.Riptide
local healing =
    Sim.Calculate(M.New(7, nil, 40), riptide, riptide.ranks[1], { power = 100, crit = 0 })
near(healing.expected, 480 + 445 + 100 * (0.214 + 5 * 0.1))
check(healing.parsed.descriptionSource == "client-data")
near(Sim.Parse(lava.ranks[1], lava, 40).components[1].sp, 0.714)
for _, tree in ipairs(M.Class(1).trees) do
    for _, talent in ipairs(tree.talents) do
        if talent.id == 110858 then
            check(talent.ranks[1].text:find("1.5 sec", 1, true))
            check(talent.ranks[2].text:find("3.0 sec", 1, true))
        elseif talent.id == 105933 then
            check(not talent.ranks[5].text:find("Rage", 1, true))
        elseif talent.id == 105977 then
            check(
                talent.ranks[1].text
                    == "Reduces the Rage cost of your Cleave and Whirlwind abilities by 3."
            )
        end
    end
end

FT.UI.Toggle()
FT.Store.SwitchClass(1)
FT.UI.SkillDialog(blood)
check(FT.UI.dialogs.skill.rankRows[1].label:GetText():find("talent unlock", 1, true))
FT.UI.CloseDialog()
FT.Store.SetSimpleView(true)
FT.UI.SkillDialog(blood)
check(FT.UI.dialogs.skillLevels.levelRows[1]:GetText():find("Level 40–47", 1, true))
check(FT.UI.dialogs.skillLevels.levelRows[1]:GetText():find("talent unlock", 1, true))
print("Skill update regressions: " .. checks .. " assertions passed")
