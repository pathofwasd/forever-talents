local FT = dofile("tests/wow_mock.lua").Load()
local A, M, S, C, Sim = FT.Skills, FT.Model, FT.Store, FT.Character, FT.Simulation
local checks = 0
local function check(value, message)
    checks = checks + 1
    assert(value, message)
end
local holy = A.Prepare(2).byName["Holy Light"]
for _, case in ipairs({
    { 46, 10328 },
    { 49, 10328 },
    { 50, 10328 },
    { 53, 10328 },
    { 54, 10329 },
    {
        60,
        25292,
    },
}) do
    local rank = A.CurrentRank(holy, case[1], {})
    check(rank.spellID == case[2], "Holy Light selected an auxiliary heal")
    check(Sim.Calculate(M.New(2, nil, case[1]), holy, rank, { crit = 0 }).normalMin > 800)
end
check(#A.Levels(holy) == 9)
check(A.Progression(holy, A.CurrentRank(holy, 50, {}), 50).nextLevel == 54)
for _, raw in ipairs(FT.Data.classes[2].skills) do
    if raw.name == "Holy Light" then
        for _, rank in ipairs(raw.ranks) do
            if rank.spellID == 1313352 then
                check(rank.referenceOnly and not Sim.Parse(rank, holy, 50))
            end
        end
    end
end
local cases = {
    { 4, "Mutilate", 1310706, 1310707, 30 },
    { 4, "Mutilate", 1241588, 1241582, 50 },
    { 4, "Mutilate", 1241590, 1241584, 60 },
    { 5, "Penance", 1240727, 1240720, 40 },
    { 5, "Penance", 1240730, 1240721, 50 },
    { 5, "Penance", 1316993, 1316995, 60 },
    { 8, "Polymorph", 28271, 12826, 60 },
    { 8, "Polymorph", 28272, 12826, 60 },
    { 2, "Seal of Righteousness", 21084, 20154, 1 },
}
for _, case in ipairs(cases) do
    local cid, name, captured, wanted, level = unpack(case)
    local skill = A.Prepare(cid).byName[name]
    local trained = A.TrainedRank(skill, { spellIDs = { captured } })
    check(trained and trained.spellID == wanted, name .. " capture alias failed")
    check(trained.text ~= "", name .. " helper description leaked into UI")
    for _, rank in ipairs(skill.ranks) do
        check(not rank.aliasOf and not rank.referenceOnly, "Auxiliary rank in player picker")
    end
    local points = skill.unlock and { [skill.unlock.id] = 1 } or {}
    check(A.CurrentRank(skill, level, points).spellID == wanted)
end
local bolt = A.Prepare(9).byName["Shadow Bolt"]
check(A.CurrentRank(bolt, 60, {}).spellID == 25307)
local oldBolt = A.TrainedRank(bolt, { spellIDs = { 11661 } })
check(oldBolt.spellID == 11661 and A.Progression(bolt, oldBolt, 60).next.spellID == 25307)
local poly = A.Prepare(8).byName.Polymorph
check(A.Progression(poly, A.CurrentRank(poly, 60, {}), 60).rankLabel == "Max rank 4")

S.SwitchClass(2)
check(S.Edit(M.New(2, nil, 50)))
local sheet = C.Get(S.Build())
sheet.trainedSkills =
    { schema = 1, classID = 2, raceID = S.Build().raceID, level = 50, spellIDs = { 10328 } }
check(C.Save(S.Build(), sheet))
S.SetCheckTraining(true)
check(not A.TrainingReport(S.Build(), 50).skills["Holy Light"].needsTraining)
check(A.TrainingReport(S.Build(), 54).skills["Holy Light"].needsTraining)

S.SwitchClass(8)
check(S.Edit(M.New(8, 7, 60)))
sheet = C.Get(S.Build())
sheet.trainedSkills = { schema = 1, classID = 8, raceID = 7, level = 60, spellIDs = { 28271 } }
check(C.Save(S.Build(), sheet))
local before = assert(FT.Library.Encode())
check(not A.TrainingReport(S.Build(), 60).skills.Polymorph.needsTraining)
check(C.Get(S.Build()).trainedSkills.spellIDs[1] == 28271, "Normalization changed captured IDs")
check(FT.Library.Encode() == before, "Rank presentation changed portable data")
local fire = A.Prepare(8).byName.Fireball
local rank = A.CurrentRank(fire, 60, {})
local off = Sim.Calculate(S.Build(), fire, rank, { crit = 0, cooldowns = false })
local on = Sim.Calculate(S.Build(), fire, rank, { crit = 0, cooldowns = true })
check(off.expected == on.expected and #on.racials == 0, "Unverified Eureka bonus was applied")
check(table.concat(on.warnings, " "):find("Eureka! is not modeled", 1, true))
check(on.confidence == "Partial estimate")
check(table.concat(off.warnings, " "):find("Eureka! is not modeled", 1, true))
for _, case in ipairs({ { 4, "Mutilate", 30 } }) do
    local skill = A.Prepare(case[1]).byName[case[2]]
    local rank = A.CurrentRank(skill, case[3], { [skill.unlock.id] = 1 })
    local result, why = Sim.Calculate(M.New(case[1], nil, case[3]), skill, rank, {})
    check(
        not result and why:find("not modeled", 1, true),
        "Scripted helper total presented as full cast"
    )
    check(
        Sim.Calculate(
            M.New(case[1], nil, case[3]),
            skill,
            rank,
            { manual = true, baseMin = 100, baseMax = 100, crit = 0 }
        ).confidence == "Manual estimate"
    )
end
FT.UI.Toggle()
FT.UI.PetDialog()
check(FT.UI.dialogs.pets.reference:GetText():find("Fox", 1, true))
check(FT.Data.meta.tag == "759c22c2" and FT.Model.AcceptTag("7ba43a60"))
print("Rank audit regressions: " .. checks .. " assertions passed")
