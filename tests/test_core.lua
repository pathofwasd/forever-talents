local Mock = dofile("tests/wow_mock.lua")
local FT = Mock.Load()
local M, C, S, Sim = FT.Model, FT.Codec, FT.Store, FT.Simulation
local tests, assertions = 0, 0
local function check(value, message)
    assertions = assertions + 1
    if not value then
        error(message or "assertion failed", 2)
    end
end
local function test(name, run)
    tests = tests + 1
    run()
    print("PASS " .. name)
end
local function greedy(build, treeFirst)
    local result = FT.Copy(build)
    local trees = M.Class(build.classID).trees
    local order = {}
    if treeFirst then
        order[#order + 1] = trees[treeFirst]
    end
    for i, tree in ipairs(trees) do
        if i ~= treeFirst then
            order[#order + 1] = tree
        end
    end
    local guard = 0
    while #result.order < M.Budget(result.level) and guard < 100 do
        local added = false
        for _, tree in ipairs(order) do
            for _, t in ipairs(tree.talents) do
                if M.CanAdd(result, t.id) then
                    result = M.Add(result, t.id)
                    added = true
                    break
                end
            end
            if added then
                break
            end
        end
        if not added then
            break
        end
        guard = guard + 1
    end
    return result
end

test("all 27 trees, all budgets and point order", function()
    for _, classID in ipairs(FT.classOrder) do
        for tree = 1, 3 do
            for _, level in ipairs({ 1, 9, 10, 14, 19, 20, 39, 40, 59, 60 }) do
                local build = greedy(M.New(classID, nil, level), tree)
                check(M.Validate(build))
                check(#build.order == M.Budget(level), "could not spend budget")
                for n = 0, #build.order do
                    check(M.Validate(M.Prefix(build, n)))
                end
                if level >= 10 then
                    check(not M.Add(build, build.order[1]), "budget exceeded")
                end
                local code = C.Encode(build)
                local roundtrip, why = C.Decode(code)
                check(roundtrip, why)
                check(M.Same(roundtrip, build), "order changed in round trip")
            end
        end
    end
end)

test("exact grid, ranks, prerequisites and valid race combinations", function()
    local total = 0
    for _, cid in ipairs(FT.classOrder) do
        local class = M.Class(cid)
        M.Index(cid)
        for _, tree in ipairs(class.trees) do
            local cells = {}
            for _, t in ipairs(tree.talents) do
                check(t.row >= 0 and t.row <= 6 and t.col >= 0 and t.col <= 3)
                local cell = t.row .. ":" .. t.col
                check(not cells[cell])
                cells[cell] = true
                check(t.gate == t.row * 5 and #t.ranks == t.max)
                for _, r in ipairs(t.requires) do
                    check(class.index[r.id] and class.index[r.id].treeID == tree.id)
                end
                total = total + 1
            end
        end
        for _, race in ipairs(class.races) do
            check(M.Validate(M.New(cid, race)))
        end
    end
    check(total == 466)
    check(not M.RaceAllowed(11, 1))
    check(M.RaceAllowed(2, 5))
    check(M.RaceAllowed(7, 3))
    check(M.RaceAllowed(8, 95))
    check(not M.RaceAllowed(8, 96))
end)

test("invalid imports cannot bypass rules", function()
    local b = M.New(11)
    local t = M.Class(11).trees[1].talents[#M.Class(11).trees[1].talents]
    check(not M.Add(b, t.id))
    b.order = { t.id }
    check(not M.Validate(b))
    b = M.New(11)
    b.order = { 999 }
    check(not M.Validate(b))
    b = M.New(11)
    b.raceID = 1
    check(not M.Validate(b))
    b = M.New(11)
    b.level = 61
    check(not M.Validate(b))
    b = M.New(11)
    b.order = { [2] = M.Class(11).trees[1].talents[1].id }
    check(not M.Validate(b))
    local full = greedy(M.New(11))
    full.level = 59
    check(not M.Validate(full))
    local code = C.Encode(greedy(M.New(11)))
    check(not C.Decode(code:sub(1, -2)))
    check(not C.Decode(code:gsub("FT1", "FT2")))
    local corrupt = code:gsub(FT.Data.meta.tag, "aaaaaaaa")
    check(not C.Decode(corrupt))
    local body = "FT1:" .. FT.Data.meta.tag .. ":11:4:60:_:"
    check(not C.Decode(body .. ":" .. C.Checksum(body)))
    check(not C.Decode(string.rep("x", 513)))
end)

test("removal preserves legal order and refuses broken dependencies", function()
    local build = greedy(M.New(11))
    local points = M.Counts(build)
    local refused = 0
    for id in pairs(points) do
        local result = M.Remove(build, id)
        if result then
            check(M.Validate(result))
            check(#result.order == #build.order - 1)
            local expected = FT.Copy(build.order)
            for i = #expected, 1, -1 do
                if expected[i] == id then
                    table.remove(expected, i)
                    break
                end
            end
            local surviving = FT.Copy(build)
            surviving.order = expected
            if M.Validate(surviving) then
                for i, value in ipairs(expected) do
                    check(result.order[i] == value)
                end
            end
            local remaining = M.Counts(result)
            for talentID, rank in pairs(points) do
                check((remaining[talentID] or 0) == rank - (talentID == id and 1 or 0))
            end
        else
            refused = refused + 1
        end
    end
    check(refused > 0, "dependent removal was not refused")
    local split = M.New(11)
    local a = M.Class(11).trees[1].talents[1].id
    local b = M.Class(11).trees[2].talents[1].id
    split = M.Add(split, a)
    split = M.Add(split, b)
    split = M.Add(split, a)
    local out = M.Remove(split, b)
    check(out.order[1] == a and out.order[2] == a)
end)

test("race, level, reset, reorder and class drafts participate in undo/redo", function()
    _G.ForeverTalentsDB = nil
    S.Init(11, 4)
    local id = M.Class(11).trees[1].talents[1].id
    check(S.Apply(M.Add, id))
    local saved = FT.Copy(S.Build())
    check(S.Undo())
    check(#S.Build().order == 0)
    check(S.Redo())
    check(M.Same(S.Build(), saved))
    local b = FT.Copy(S.Build())
    b.raceID = 95
    check(S.Edit(b))
    check(S.Undo())
    check(S.Build().raceID == 4)
    check(S.Redo())
    check(S.Build().raceID == 95)
    check(S.Apply(M.Reset))
    check(S.Undo())
    check(#S.Build().order == 1)
    local draft = FT.Copy(S.Build())
    S.SwitchClass(8)
    check(#S.Build().order == 0)
    S.SwitchClass(11)
    check(M.Same(S.Build(), draft))
    S.Preview(0)
    check(not S.Apply(M.Add, id))
    check(S.preview == 0)
    check(S.Undo())
    check(S.preview == nil)
end)

test("checkpoint creation preserves snapshots and forms genuine branches", function()
    _G.ForeverTalentsDB = nil
    S.Init(11, 4)
    local root = S.CreateProfile("Moonkin journey")
    check(root)
    local id = M.Class(11).trees[1].talents[1].id
    S.Apply(M.Add, id)
    local a = S.Checkpoint("Path A")
    check(a.parent == 1)
    S.Apply(M.Add, id)
    local a2 = S.Checkpoint("More A")
    check(a2.parent == a.id)
    local old = FT.Copy(a2.build)
    check(S.LoadNode(root.id, 1))
    S.Apply(M.Add, M.Class(11).trees[2].talents[1].id)
    local branch = S.Checkpoint("Path B")
    check(branch.parent == 1 and branch.id ~= a.id)
    check(M.Same(a2.build, old))
    check(#root.order == 4)
    S.Build().order[#S.Build().order + 1] = id
    check(#branch.build.order == 1, "checkpoint aliases draft")
    S.LoadNode(root.id, branch.id)
    check(S.Dirty() == false)
    local persisted = FT.Copy(S.db)
    _G.ForeverTalentsDB = persisted
    S.Init(11, 4)
    check(#S.db.profiles[root.id].order == 4)
    check(S.Undo() and #S.Build().order == 2, "Undo lost unsaved edits after reload")
    check(S.Redo())
    check(M.Same(S.Build(), branch.build))
    check(S.RenameProfile(root.id, "Another title"))
    check(S.DeleteProfile(root.id))
    check(#S.Build().order == 1)
end)

test("history is bounded and malformed or newer saved data is preserved", function()
    _G.ForeverTalentsDB = nil
    S.Init(11, 4)
    for i = 1, 130 do
        local b = FT.Copy(S.Build())
        b.raceID = i % 2 == 0 and 4 or 95
        S.Edit(b)
    end
    check(#S.Draft().undo == 100)
    S.Draft().build.order = { 999 }
    S.Init(11, 4)
    check(#S.Build().order == 0)
    check(#S.db.recovered > 0)
    local newer = { schema = 999, privateValue = "keep me" }
    _G.ForeverTalentsDB = newer
    S.Init(11, 4)
    check(S.readOnly and _G.ForeverTalentsDB == newer)
    check(not S.CreateProfile("No overwrite"))
    check(newer.privateValue == "keep me")
    _G.ForeverTalentsDB = nil
    S.readOnly = nil
    S.Init(11, 4)
end)

test("all rank records, talent unlocks, racial filters and interactions", function()
    local ranks = 0
    for _, cid in ipairs(FT.classOrder) do
        for _, s in ipairs(M.Class(cid).skills) do
            ranks = ranks + #s.ranks
        end
        local p = FT.Skills.Prepare(cid)
        for _, s in ipairs(p.list) do
            for _, r in ipairs(s.related) do
                check(p.index[r.id])
            end
        end
    end
    check(ranks == 1519)
    local b = M.New(11, 4)
    local list = FT.Skills.List(b, 1, "Wrath", "all")
    check(#list >= 1)
    local wrath = FT.Skills.Prepare(11).byName.Wrath
    check(#wrath.related > 0)
    check(FT.Skills.CurrentRank(wrath, 1, {}))
    check(not FT.Skills.CurrentRank(wrath, 0, {}))
    local moonkin = FT.Skills.Prepare(11).byName["Moonkin Form"]
    check(moonkin and moonkin.unlock)
    check(not FT.Skills.CurrentRank(moonkin, 60, {}))
    local list = FT.Skills.List(b, 60, "", "racial")
    check(#list == 4 and list[1].skill.kind == "racial")
end)

test("share strings are compact, safe, UTF-8 capable and versioned", function()
    local b = greedy(M.New(8, nil, 60, "Feu –冰🔥 / friends"))
    local code = C.Encode(b)
    check(#code + 2 < 240)
    check(not code:find("|", 1, true))
    local out = C.Decode(code)
    check(M.Same(out, b))
    b.name = string.rep("x", 100)
    local code = C.Encode(b)
    local out = C.Decode(code)
    check(#out.name == 48)
    check(C.Checksum("Wikipedia") == "11e60398")
end)

test("addon whispers, receipts, throttling and chat links", function()
    Mock.sent = {}
    local build = greedy(M.New(11))
    local code = C.Encode(build)
    check(FT.Comms.Send(build, "Friend-Realm"))
    check(#Mock.sent == 1 and Mock.sent[1].channel == "WHISPER")
    check(not FT.Comms.Send(build, "Another"))
    check(not FT.Comms.Send(build, "/run evil"))
    local count = #S.db.inbox
    FT.Comms.Receive(FT.Comms.prefix, "B:" .. code, "WHISPER", "Friend-Realm")
    check(#S.db.inbox == count + 1)
    check(Mock.sent[#Mock.sent].message:sub(1, 2) == "A:")
    check(Mock.messages[#Mock.messages]:find("|Hforevertalents:", 1, true))
    FT.Comms.Receive(FT.Comms.prefix, "B:" .. code, "WHISPER", "Friend-Realm")
    check(#S.db.inbox == count + 1)
    FT.Comms.Receive(FT.Comms.prefix, "B:" .. code, "GUILD", "Other")
    check(#S.db.inbox == count + 1)
    local key = C.Checksum(code)
    FT.Comms.Receive(FT.Comms.prefix, "A:" .. key, "WHISPER", "Intruder-Realm")
    check(FT.Comms.pending[key])
    FT.Comms.Receive(FT.Comms.prefix, "A:" .. key, "WHISPER", "Friend-Realm")
    check(not FT.Comms.pending[key])
    local imported
    local original = FT.UI.ImportDialog
    FT.UI.ImportDialog = function(value)
        imported = value
    end
    SetItemRef("forevertalents:" .. code)
    check(imported == code)
    SetItemRef("item:1")
    check(Mock.originalLink == "item:1")
    FT.UI.ImportDialog = original
end)

test("skill estimates respect source ranges, states, crit, power and mitigation", function()
    local b = M.New(11)
    local skill = FT.Skills.Prepare(11).byName.Wrath
    local rank = skill.ranks[1]
    local result = Sim.Calculate(b, skill, rank, { power = 100, crit = 0, reduction = 0 })
    -- Rank-one client values grow through level five before bonus scaling.
    local minimum = 15 * (1 - 0.153846 / 2) + (5 - 1) * 0.2 + 100 * 0.429
    check(math.abs(result.min - minimum) < 0.01)
    local crit = Sim.Calculate(b, skill, rank, { power = 100, crit = 100 })
    check(math.abs(crit.expected - result.average * 1.5) < 0.01)
    local blocked = Sim.Calculate(b, skill, rank, { power = 100, crit = 0, reduction = 50 })
    check(math.abs(blocked.expected - result.expected * 0.5) < 0.01)
    local heal = {
        name = "Healing",
        icon = "spell_nature_healingtouch",
        ranks = { { text = "Heals a friendly target for 100 to 200.", spellID = 0 } },
        related = {},
    }
    local h = Sim.Calculate(b, heal, heal.ranks[1], { crit = 0, reduction = 99, hit = 0 })
    check(h.expected == 150)
    local utility = { text = "Increases Intellect by 10%.", spellID = 0 }
    check(not Sim.Parse(utility))
    local dot = Sim.Parse({ text = "Heals the target for 120 over 12 sec." })
    check(dot.min == 0 and dot.periodic == 120)
    local weapon = Sim.Parse({
        text = "A strong attack that increases melee damage by 11 and causes a high amount of threat.",
    })
    check(weapon.weapon == 1 and weapon.min == 11)
    local s = Sim.State({ crit = 999, reduction = -100, power = math.huge })
    check(s.crit == 100 and s.reduction == 0 and s.power == 0)
end)

print(string.format("%d core tests; %d assertions passed", tests, assertions))
