local Mock = dofile("tests/wow_mock.lua")
local FT = Mock.Load()
local Sim, C, M, P, S = FT.Simulation, FT.Character, FT.Model, FT.Snapshot, FT.Store
local assertions = 0
local function check(value, message)
    assertions = assertions + 1
    assert(value, message)
end
local function near(a, b, message)
    check(
        math.abs(a - b) < 0.00001,
        (message or "numeric mismatch") .. ": " .. tostring(a) .. " vs " .. tostring(b)
    )
end
local function skill(cid, name, n)
    local sk = FT.Skills.Prepare(cid).byName[name]
    return sk, sk.ranks[n or 1]
end
local function result(cid, name, state, level, n)
    local sk, rank = skill(cid, name, n)
    return assert(Sim.Calculate(M.New(cid, nil, level or 60), sk, rank, state or { crit = 0 }))
end
local function inputs(r)
    local used = {}
    for _, input in ipairs(r.inputs) do
        used[input.key] = input
    end
    return used
end
local function talent(cid, name)
    for _, tr in ipairs(M.Class(cid).trees) do
        for _, t in ipairs(tr.talents) do
            if t.name == name then
                return t
            end
        end
    end
    error("Missing talent " .. name)
end
local function selected(cid, name, rank)
    local b, t = M.New(cid), talent(cid, name)
    for _ = 1, rank or t.max do
        b.order[#b.order + 1] = t.id
    end
    return b
end
local function legal(cid, name)
    local b, t = M.New(cid), talent(cid, name)
    while not M.CanAdd(b, t.id) do
        local added = false
        for _, tree in ipairs(M.Class(cid).trees) do
            if tree.id == t.treeID then
                for _, node in ipairs(tree.talents) do
                    if node.id ~= t.id and M.CanAdd(b, node.id) then
                        b = M.Add(b, node.id)
                        added = true
                        break
                    end
                end
            end
        end
        assert(added, "cannot reach test talent")
    end
    for _ = 1, t.max do
        b = M.Add(b, t.id)
    end
    assert(M.Validate(b))
    return b
end

-- Independent, hand-calculated reference cases from reviewed effect rows.
local sting = result(3, "Serpent Sting", { crit = 0, power = 514 }, 18, 3)
near(sting.normalMin, 60)
check(sting.confidence == "Partial estimate")
check(not inputs(sting).power and inputs(sting).crit and not inputs(sting).attackPower)
local scaled = result(3, "Serpent Sting", { crit = 0, power = 500, dotCoefficient = 20 }, 18, 3)
near(scaled.normalMin, 160)
near(scaled.dotCoefficient, 0.2)
local apSting =
    result(3, "Serpent Sting", { attackPower = 1000, dotAPCoefficient = 20, crit = 0 }, 18, 3)
near(apSting.expected, 260)
check(inputs(apSting).attackPower and not inputs(apSting).power)
near(result(1, "Bloodthirst", { attackPower = 1000, apCoefficient = 0, crit = 0 }).expected, 30)
check(not inputs(result(1, "Bloodthirst", { apCoefficient = 0 })).attackPower)
check(inputs(scaled).power)
near(result(3, "Serpent Sting", { crit = 100, dotCoefficient = 0 }, 18, 3).expected, 120)
local moon = result(11, "Moonfire", { crit = 0, power = 100 }, 4)
near(moon.min, 22)
near(moon.max, 24)
near(moon.periodic, 51)
near(moon.expected, 74)
local rejuv = result(11, "Rejuvenation", { crit = 100, power = 100, hit = 0, reduction = 100 }, 4)
near(rejuv.expected, (8 + 100 * 0.2) * 4 * 1.5)
check(not inputs(rejuv).hit and not inputs(rejuv).reduction and inputs(rejuv).crit)
local shield =
    result(5, "Power Word: Shield", { crit = 100, power = 100, hit = 0, reduction = 100 }, 6)
near(shield.expected, 54)
check(
    not shield.critEligible
        and not inputs(shield).crit
        and not inputs(shield).hit
        and shield.duration == 0
)
near(result(1, "Bloodthirst", { crit = 0, attackPower = 1000 }).expected, 480)
near(result(1, "Bloodthirst", { crit = 0, attackPower = 1000 }, 48, 2).expected, 487)
check(result(1, "Bloodthirst", { crit = 0 }).duration == 0)
near(result(11, "Swipe", { crit = 0, attackPower = 1000 }).expected, 48)
near(result(1, "Execute", { crit = 0, rage = 20 }).expected, 185)
local strike = result(4, "Sinister Strike", {
    crit = 0,
    weaponMin = 40,
    weaponMax = 60,
    weaponType = "dagger",
    weaponSpeed = 2,
    attackPower = 140,
})
near(strike.normalMin, 40)
near(strike.normalMax, 60) -- 3 flat + AP normalization of -3
local funnelHeal = result(9, "Health Funnel", { crit = 0, effectMode = "healing" }, 12)
local funnelDamage = result(9, "Health Funnel", { crit = 0, effectMode = "cost" }, 12)
near(funnelHeal.expected, 120)
near(funnelDamage.expected, 54.5)
check(
    funnelHeal.parsed.kind == "healing"
        and funnelDamage.parsed.kind == "damage"
        and inputs(funnelHeal).effectMode
)
check(not inputs(funnelHeal).crit)
local manualCost = result(9, "Health Funnel", {
    effectMode = "cost",
    manual = true,
    baseMin = 50,
    baseMax = 50,
    crit = 100,
    reduction = 100,
    hit = 0,
})
near(manualCost.expected, 50)
check(not inputs(manualCost).crit and not inputs(manualCost).hit)
local zeroScale = result(11, "Wrath", { power = 100, coefficient = 0, crit = 0 })
check(not inputs(zeroScale).power)
local fallback = Sim.Calculate(
    M.New(11),
    { name = "Unverified hot", related = {} },
    { text = "Heals the target for 120 over 12 sec." },
    { crit = 100 }
)
near(fallback.expected, 120)
check(not inputs(fallback).crit)
local manual = result(11, "Moonfire", {
    manual = true,
    baseMin = 100,
    baseMax = 100,
    periodicBase = 200,
    power = 100,
    coefficient = 50,
    dotCoefficient = 100,
    crit = 0,
})
near(manual.expected, 450)
check(manual.duration == 0 and manual.confidence == "Manual estimate")

-- Scope tests prevent percentage/proc clauses from silently affecting other skills.
local backstab, br = skill(4, "Backstab")
local mutilate, mr = skill(4, "Mutilate")
near(Sim.Calculate(selected(4, "Puncturing Wounds"), backstab, br, { crit = 0 }).crit, 30)
near(
    Sim.Calculate(
        selected(4, "Puncturing Wounds"),
        mutilate,
        mr,
        { crit = 0, manual = true, baseMin = 100, baseMax = 100 }
    ).crit,
    15
)
local immolate, ir = skill(9, "Immolate")
local base = Sim.Calculate(M.New(9), immolate, ir, { crit = 0 })
local after = Sim.Calculate(selected(9, "Aftermath"), immolate, ir, { crit = 0 })
near(after.min, base.min * 1.5)
near(after.periodic, base.periodic)
local renew, rr = skill(5, "Renew")
local inner = Sim.Calculate(selected(5, "Inner Focus"), renew, rr, { crit = 0, cooldowns = true })
near(inner.crit, 0)
local frost = skill(8, "Frostbolt")
local frozen =
    Sim.Calculate(selected(8, "Shatter"), frost, frost.ranks[1], { crit = 0, frozen = true })
near(frozen.crit, 50)
check(inputs(frozen).frozen)
local shadow, sr = skill(9, "Shadow Bolt")
local sacrifice = Sim.Calculate(selected(9, "Demonic Sacrifice"), shadow, sr, { crit = 0 })
local shadowBase = Sim.Calculate(M.New(9), shadow, sr, { crit = 0 })
near(sacrifice.expected, shadowBase.expected)
check(#sacrifice.modifiers.omitted > 0)
local gnome = M.New(8, 7)
local gnomeSpell, gr = skill(8, "Fireball")
near(
    Sim.Calculate(gnome, gnomeSpell, gr, { crit = 0, cooldowns = true }).expected,
    Sim.Calculate(gnome, gnomeSpell, gr, { crit = 0 }).expected
)
local holy = selected(2, "Holy Power")
local holySkill, hr = skill(2, "Holy Strike")
local hm = Sim.Modifiers(holy, holySkill, Sim.Parse(hr, holySkill), {})
near(hm.crit, 15)
near(hm.statsCrit, 0) -- spell modifier is not a reported character-sheet aura
local general = selected(11, "Nature's Majesty")
local wrath, wr = skill(11, "Wrath")
near(Sim.Modifiers(general, wrath, Sim.Parse(wr, wrath), {}).statsCrit, 4)

-- Central sheets: derived stats, scope isolation, presets, no capture double count.
local b = selected(2, "Divine Strength")
local sheet = C.New()
sheet.mode = "manual"
sheet.stats =
    { strength = 100, attackPower = 400, health = 1000, mana = 500, meleeCrit = 10, spellCrit = 5 }
local totals = C.Compute(b, sheet).totals
near(totals.strength, 110)
near(totals.attackPower, 420)
local armor = selected(2, "Toughness")
sheet.gear.chest =
    { name = "Mail", stats = { armor = 100 }, low = 0, high = 0, speed = 0, weaponType = "none" }
sheet.mode = "gear"
local plain, buffed = C.Compute(M.New(2), sheet), C.Compute(armor, sheet)
near(buffed.totals.stamina, plain.totals.stamina)
near(buffed.totals.armor - plain.totals.armor, 10)
local gear = C.New()
gear.gear.mainHand = {
    name = "Test dagger",
    stats = { attackPower = 14 },
    low = 10,
    high = 20,
    speed = 2,
    weaponType = "dagger",
}
local computed = C.Compute(M.New(4), gear).totals
local rangedPlan = C.New()
rangedPlan.gear.ranged = {
    name = "Test bow",
    stats = { attackPower = 14 },
    low = 10,
    high = 20,
    speed = 3,
    weaponType = "bow",
}
local rangedWithoutAP = C.Compute(M.New(3), C.New()).totals.rangedAP
local rangedComputed = C.Compute(M.New(3), rangedPlan).totals
near(rangedComputed.rangedAP, rangedWithoutAP + 14)
near(rangedComputed.rangedMin, 10 + rangedComputed.rangedAP / 14 * 3)
local formPlan = FT.Copy(gear)
formPlan.form = "cat"
formPlan.stats.weaponMin, formPlan.stats.weaponMax, formPlan.stats.weaponSpeed = 50, 80, 1
local formHits = C.Compute(M.New(11), formPlan).totals
near(formHits.weaponMin, 50)
near(formHits.weaponMax, 80)
local rangedManual = C.New()
rangedManual.mode = "manual"
rangedManual.stats.weaponSpeed, rangedManual.stats.rangedSpeed = 1.5, 3
near(C.Compute(M.New(3), rangedManual).totals.rangedSpeed, 3)
near(computed.weaponMin, 10 + computed.attackPower / 14 * 2)
check(computed.weaponType == "dagger")
gear.stats.power = 50
gear.stats.healing = 25
gear.stats.damagePower = 10
local common = C.Compute(M.New(4), gear).totals
near(common.power, 60)
near(common.healing, 75)
ForeverTalentsDB = nil
S.Init(11)
S.SwitchClass(11)
check(C.SetMode(S.Build(), "manual"))
sheet = C.Get(S.Build())
sheet.stats.power = 77
check(C.Save(S.Build(), sheet))
check(C.SetMode(S.Build(), "gear"))
check(C.SetMode(S.Build(), "manual"))
near(C.Get(S.Build()).stats.power, 77)
local inputsCode = assert(P.EncodeStats(P.Stats({ power = 555, crit = 10 }, S.Build(), "Wrath")))
local prior = FT.Library.Pack(S.db)
near(assert(Sim.ImportInputs(S.Build(), wrath, wr, inputsCode)).power, 555)
check(FT.Library.Pack(S.db) == prior, "pasted skill inputs changed the character")
check(not Sim.ImportInputs(S.Build(), wrath, wr, inputsCode .. "x"))
local database = FT.Library.Pack(S.db)
local estimate = Sim.Run(S.Build(), wrath, wr, { power = 999 })
check(estimate and FT.Library.Pack(S.db) == database, "temporary overrides changed saves")
near(C.Get(S.Build()).stats.power, 77)
local sourceBuild = legal(2, "Divine Strength")
local profile = P.Stats(
    { power = 100, attackPower = 420, weaponMin = 100, weaponMax = 120, crit = 10 },
    sourceBuild
)
profile.learnedCode = FT.Codec.Encode(sourceBuild)
profile.attributes = {
    strength = 110,
    agility = 30,
    intellect = 40,
    stamina = 50,
    spirit = 20,
    health = 1000,
    mana = 500,
}
profile.raw = { crit = { [7] = 10 }, meleeCrit = 10 }
local live = C.FromSnapshot(profile)
near(C.Compute(sourceBuild, live).totals.attackPower, 420)
near(C.Compute(M.New(2, sourceBuild.raceID, sourceBuild.level), live).totals.attackPower, 400)
near(live.stats.attackPower, 420) -- original never compounds

-- Portable formats preserve custom gear and all effect-specific choices.
S.SwitchClass(4)
gear.stats.power = 100
check(C.Save(S.Build(), gear))
local code = assert(P.EncodeStats(P.Current(S.Build())))
check(code:sub(1, 4) == "FS2:")
local portable = assert(P.DecodeStats(code))
check(portable.character.gear.mainHand.name == "Test dagger")
near(portable.character.gear.mainHand.low, 10)
local char = assert(P.EncodeCharacter(S.Build(), P.Current(S.Build())))
check(assert(P.Decode(char)).stats.character.gear.mainHand.weaponType == "dagger")
local temporary = P.Stats({
    effectMode = "damage",
    form = "cat",
    comboPoints = 3,
    targetType = "giant",
    executeRange = true,
    weaponSpeed = 1.7,
    dotAPCoefficient = 20,
}, S.Build(), "Test")
local imported = assert(P.DecodeStats(assert(P.EncodeStats(temporary))))
check(
    imported.state.effectMode == "damage"
        and imported.state.form == "cat"
        and imported.state.executeRange
)
near(imported.state.comboPoints, 3)
near(imported.state.dotAPCoefficient, 20)
local legacy = assert(P.EncodeStats(P.Stats({ power = 10, crit = 15 }, S.Build())))
check(legacy:sub(1, 4) == "FS1:" and P.DecodeStats(legacy))
local legacyCharacter = C.FromSnapshot(assert(P.DecodeStats(legacy)))
check(legacyCharacter.mode == "manual" and not legacyCharacter.capture)
near(legacyCharacter.stats.power, 10)
near(legacyCharacter.stats.spellCrit, 15)
local manualWeapon =
    C.FromSnapshot(P.Stats({ weaponSpeed = 1.7, weaponType = "dagger", form = "cat" }, S.Build()))
near(manualWeapon.stats.weaponSpeed, 1.7)
check(manualWeapon.weaponType == "dagger" and manualWeapon.form == "cat")
local bad = FT.Copy(portable.character)
bad.gear.mainHand.low = "bad"
check(not C.Normalize(bad, true))
bad = FT.Copy(live)
bad.capture.raw.crit = "bad"
check(not C.Normalize(bad, true))
check(not P.DecodeStats(code:sub(1, -2) .. "x"))
local library = assert(FT.Library.Encode())
ForeverTalentsDB = nil
S.Init(11)
check(FT.Library.Merge(assert(FT.Library.Decode(library)), true))
S.SwitchClass(4)
check(C.Get(S.Build()).gear.mainHand.name == "Test dagger")
S.SwitchClass(11)
near(C.Get(S.Build()).plans.manual.power, 77)
local saved = FT.Copy(S.db)
ForeverTalentsDB = saved
S.Init(4)
S.SwitchClass(4)
check(C.Get(S.Build()).gear.mainHand.name == "Test dagger")

-- Every captured model is finite and separates component kinds.
for id, model in pairs(FT.Data.simulation.spells) do
    local r = assert(
        Sim.Calculate(
            M.New(11),
            { name = "Coverage", related = {} },
            { spellID = id, level = model.level },
            { crit = 17, power = 123, attackPower = 456, weaponMin = 100, weaponMax = 200 }
        )
    )
    check(
        r.normalMin == r.normalMin
            and r.normalMin >= 0
            and r.normalMax >= r.normalMin
            and r.expected < math.huge,
        "non-finite model " .. id
    )
    for _, component in ipairs(r.breakdown) do
        check(component.kind == r.parsed.kind, "combined damage/healing model " .. id)
    end
end
print("Simulator and character workspace: " .. assertions .. " assertions passed")
