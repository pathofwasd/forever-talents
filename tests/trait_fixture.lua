-- Structured C_Traits records shaped like the Forever client API. Node, entry
-- and definition IDs deliberately differ from catalog IDs and list order.
return function(FT, build)
    local fixture = {
        configID = 202,
        group = 2,
        treeID = 501,
        nodes = {},
        entries = {},
        definitions = {},
        ids = {},
        points = #build.order,
        staged = false,
    }
    local ranks = FT.Model.Counts(build)
    for _, tree in ipairs(FT.Model.Class(build.classID).trees) do
        for _, talent in ipairs(tree.talents) do
            local id = 70000 + #fixture.ids
            table.insert(fixture.ids, 1, id)
            fixture.nodes[id] = {
                ID = id,
                posX = id * 13,
                posY = id * 7,
                entryIDs = { id + 1000 },
                isVisible = true,
                ranksPurchased = ranks[talent.id] or 0,
                activeRank = (ranks[talent.id] or 0) + 1,
                maxRanks = talent.max,
            }
            fixture.entries[id + 1000] = { definitionID = id + 2000, maxRanks = talent.max }
            fixture.definitions[id + 2000] =
                { spellID = talent.ranks[1].spellID, overrideName = "Localized talent" }
        end
    end
    UnitClass = function()
        return "Localized class", "CLASS", build.classID
    end
    UnitRace = function()
        return "Localized race", "RACE", build.raceID
    end
    UnitLevel = function()
        return build.level
    end
    GetTalentInfo = function()
        error("Deprecated talent reader must not run")
    end
    C_SpecializationInfo = {
        GetActiveSpecGroup = function()
            return fixture.group
        end,
        GetCombatConfigIDForSpecGroup = function(group)
            assert(group == fixture.group, "Import queried an inactive specialization")
            return fixture.configID
        end,
        GetTalentInfo = function()
            error("Deprecated Classic query must not run")
        end,
    }
    C_ClassTalents = {
        GetActiveConfigID = function()
            return 999
        end,
    }
    C_Traits = {
        ConfigHasStagedChanges = function(configID)
            assert(configID == fixture.configID)
            return fixture.staged
        end,
        GetConfigInfo = function(configID)
            assert(configID == fixture.configID)
            return { ID = configID, type = 4, treeIDs = { fixture.treeID } }
        end,
        GetTreeNodes = function(treeID)
            assert(treeID == fixture.treeID)
            return fixture.ids
        end,
        GetNodeInfo = function(configID, nodeID)
            assert(configID == fixture.configID)
            return fixture.nodes[nodeID]
        end,
        GetEntryInfo = function(configID, entryID)
            assert(configID == fixture.configID)
            return fixture.entries[entryID]
        end,
        GetDefinitionInfo = function(definitionID)
            return fixture.definitions[definitionID]
        end,
        GetTreeCurrencyInfo = function(configID, treeID, excludeStagedChanges)
            assert(
                configID == fixture.configID
                    and treeID == fixture.treeID
                    and excludeStagedChanges == true
            )
            return {
                {
                    traitCurrencyID = 901,
                    spent = fixture.points,
                    spentInTree = fixture.points,
                    quantity = 51 - fixture.points,
                },
            }
        end,
    }
    return fixture
end
