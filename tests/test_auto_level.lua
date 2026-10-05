local Mock = dofile("tests/wow_mock.lua")
local FT = Mock.Load()
local M, S = FT.Model, FT.Store
local checks = 0
local function check(value, message)
    checks = checks + 1
    assert(value, message)
end

for _, cid in ipairs(FT.classOrder) do
    _G.ForeverTalentsDB = nil
    S.Init(cid, M.Class(cid).races[1], 20)
    local index = M.Index(cid)
    local first = M.Class(cid).trees[1].talents[1].id
    check(not S.AutoLevel())
    check(S.SetAutoLevel(true))
    check(S.AutoLevel() and S.Build().level == 1)
    check(S.Apply(M.Add, first))
    check(S.Build().level == 10)
    check(S.Undo())
    check(S.AutoLevel() and S.Build().level == 1)
    check(S.Redo())
    check(S.AutoLevel() and S.Build().level == 10)
    check(S.Apply(M.Remove, first))
    check(S.Build().level == 1)
    local locked
    for _, t in pairs(index) do
        if t.gate > 0 then
            locked = t.id
            break
        end
    end
    local before = FT.Copy(S.Build())
    local history = #S.Draft().undo
    check(not S.Apply(M.Add, locked), "auto bypassed a row gate")
    check(
        M.Same(before, S.Build()) and history == #S.Draft().undo,
        "rejected auto edit changed the draft"
    )
    while #S.Build().order < 51 do
        local chosen
        for _, tree in ipairs(M.Class(cid).trees) do
            for _, t in ipairs(tree.talents) do
                if M.CanAdd(S.PlanningView(), t.id) then
                    chosen = t.id
                    break
                end
            end
            if chosen then
                break
            end
        end
        check(chosen, "cannot finish an auto build for class " .. cid)
        check(S.Apply(M.Add, chosen))
        check(S.Build().level == #S.Build().order + 9)
        check(M.Validate(S.Build()))
        local decoded = FT.Codec.Decode(FT.Codec.Encode(S.Build()))
        check(decoded and M.Same(decoded, S.Build()), "auto build share round trip failed")
    end
    check(S.Build().level == 60)
    before = FT.Copy(S.Build())
    check(not S.Apply(M.Add, first))
    check(M.Same(before, S.Build()), "auto bypassed the 51-point cap")
    local profile = S.CreateProfile("Auto path")
    check(profile and profile.nodes[1].build.level == 60)
    S.Preview(5)
    check(S.preview == 5)
    check(not S.SetAutoLevel(false))
    check(not S.Apply(M.Remove, first))
    check(S.BranchPreview())
    check(S.Build().level == 14 and #S.Build().order == 5)
    check(
        profile.nodes[1].build.level == 60 and #profile.nodes[1].build.order == 51,
        "auto changed a saved checkpoint"
    )
    check(S.Undo())
    check(S.AutoLevel() and S.Build().level == 60)
    local saved = FT.Copy(S.db)
    _G.ForeverTalentsDB = saved
    S.Init(cid, M.Class(cid).races[1])
    check(
        S.AutoLevel() and S.Build().level == 60 and S.Draft().manualLevel == 20,
        "auto preference did not survive reload"
    )
    check(S.Redo())
    check(S.Build().level == 14 and S.AutoLevel())
    check(S.SetAutoLevel(false))
    check(S.Build().level == 20)
    check(S.Undo())
    check(S.AutoLevel() and S.Build().level == 14)
    check(S.Redo())
    check(not S.AutoLevel() and S.Build().level == 20)
    check(S.Apply(M.Reset))
    check(S.Build().level == 20, "manual reset changed the target")
    local manual = M.New(cid, M.Class(cid).races[1], 10)
    check(S.Edit(manual))
    check(S.Apply(M.Add, first))
    check(not S.Apply(M.Add, first), "manual point budget was bypassed")
    check(S.SetAutoLevel(true))
    check(S.Apply(M.Add, first, true))
    check(S.Build().level == #S.Build().order + 9)
    check(S.Apply(M.Remove, first, true))
    check(S.Build().level == 1)
    check(S.Undo())
    check(S.AutoLevel() and S.Build().level == #S.Build().order + 9)
    check(S.Apply(M.Reset, M.Class(cid).trees[1].id))
    check(S.Build().level == 1)
    check(S.Undo())
    check(S.Build().level == #S.Build().order + 9)
    local imported = FT.Copy(S.Build())
    imported.level = 60
    check(S.Import(imported))
    check(
        not S.AutoLevel() and S.Build().level == 60,
        "explicit import must keep its shared target level"
    )
    check(S.Undo())
    check(S.AutoLevel(), "Undo must restore the previous Auto mode")
    check(S.Redo())
    check(not S.AutoLevel() and S.Build().level == 60)
    check(S.SetAutoLevel(false))
    check(S.Build().level >= M.RequiredLevel(S.Build()) and M.Validate(S.Build()))
end

print(string.format("Auto level: %d assertions passed across all nine classes", checks))
