local Mock = dofile("tests/wow_mock.lua")
local FT = Mock.Load()
local S, M, A, C, P, UI = FT.Store, FT.Model, FT.Skills, FT.Character, FT.Snapshot, FT.UI
local checks = 0
local function check(value, message)
    checks = checks + 1
    assert(value, message)
end
local function click(text)
    for _, o in ipairs(Mock.objects) do
        if
            o.kind == "Button"
            and o:IsVisible()
            and o.fontString
            and o.fontString:GetText() == text
        then
            o:Click()
            return o
        end
    end
    error("Visible button missing: " .. text)
end
UI.Toggle()
UI.CharacterSheet()
click("Copy / paste character")
check(UI.dialogs.character:IsVisible(), "Real button callback must not pass a frame to SetText")
check(UI.dialogs.character.output:GetText() == "")
UI.dialogs.character.close:Click()
check(UI.dialogs.characterSheet:IsVisible() and UI.dialogOverlay:IsShown())
UI.GearDialog("waist")
UI.dialogs.gear.name:UserText("Discard this")
UI.dialogs.gear.fields.strength:UserText("999")
UI.dialogs.gear.close:Click()
check(UI.dialogs.characterSheet:IsVisible())
check(not C.Get(S.View()).gear.waist, "Closing gear committed an unfinished item")
local wrath = A.Prepare(11).byName.Wrath
UI.CloseDialog(true)
UI.SkillDialog(wrath)
UI.SimulationDialog(wrath, wrath.ranks[2], { power = 321 })
local sim = UI.dialogs.simulation
local result = sim.result
UI.SimulationHelp(result)
UI.dialogs.simulationHelp.close:Click()
check(sim:IsVisible() and sim.overrides.power == 321)
UI.SimulationHelp(result)
UI.dialogOverlay:Hide() -- UISpecialFrames Escape behavior.
check(sim:IsVisible() and UI.dialogOverlay:IsShown())
check(sim.overrides.power == 321)
UI.CloseDialog(true)

-- Read real spellbook slot IDs, ignoring future/flyout/off-spec entries.
GetNumSpellTabs = function()
    return 2
end
GetSpellTabInfo = function(i)
    return "Tab", 0, i == 1 and 0 or 5, i == 1 and 5 or 1, false, i == 1 and 0 or 99
end
GetSpellBookItemInfo = function(slot, bank)
    check(bank == "spell")
    local entries = {
        { "SPELL", 5177 },
        { "SPELL", 5185 },
        { "FUTURESPELL", 5178 },
        { "FLYOUT", 999 },
        { "SPELL", 5177 },
        { "SPELL", 5178 },
    }
    return unpack(entries[slot])
end
local training = assert(FT.ReadPlayerSkills())
check(#training.spellIDs == 2 and training.spellIDs[1] == 5177)
local legacyTraining = FT.Copy(training)
GetNumSpellTabs, GetSpellTabInfo, GetSpellBookItemInfo = nil, nil, nil
Enum = {
    SpellBookSpellBank = { Player = 0 },
    SpellBookItemType = { Spell = 1, FutureSpell = 2, Flyout = 3 },
}
C_SpellBook = {
    GetNumSpellBookSkillLines = function()
        return 1
    end,
    GetSpellBookSkillLineInfo = function()
        return { itemIndexOffset = 0, numSpellBookItems = 4 }
    end,
    GetSpellBookItemInfo = function(slot, bank)
        check(bank == 0)
        return ({
            { itemType = 1, spellID = 5177 },
            { itemType = 1, spellID = 5185 },
            { itemType = 2, spellID = 5178 },
            { itemType = 1, spellID = 5178, isOffSpec = true },
        })[slot]
    end,
}
training = assert(FT.ReadPlayerSkills())
check(#training.spellIDs == #legacyTraining.spellIDs)
check(training.spellIDs[1] == legacyTraining.spellIDs[1])
C_SpecializationInfo = {
    IsInitialized = function()
        return true
    end,
    GetTalentInfo = function(q)
        for _, talent in ipairs(M.Class(11).trees[q.specializationIndex].talents) do
            if talent.row + 1 == q.tier and talent.col + 1 == q.column then
                return {
                    name = "Localized",
                    tier = q.tier,
                    column = q.column,
                    maxRank = talent.max,
                    rank = q.specializationIndex == 1 and talent.index == 1 and 3 or 0,
                }
            end
        end
    end,
}
local snapshot = assert(FT.ReadPlayerSnapshot())
check(#snapshot.build.order == 3)
check(snapshot.stats.character.trainedSkills.spellIDs[1] == 5177)
UI.ImportDialog()
click("Import my talents & trained skills")
check(#S.Build().order == 3 and UI.skillFilterKey == "trained")
check(not UI.dialogOverlay:IsShown())
local entries = A.List(S.View(), 60, "", "trained")
check(#entries == 2)
for _, entry in ipairs(entries) do
    check(entry.trained and entry.trained.spellID ~= 5178)
end
check(A.TrainedRank(wrath, training).label == "Rank 2")
check(
    A.CurrentRank(wrath, 60, M.Counts(S.View())).label ~= "Rank 2",
    "Trained skills confused with maximum available rank"
)
local code = assert(P.EncodeCharacter(S.ExportView(), P.Current(S.ExportView())))
local decoded = assert(P.Decode(code))
check(decoded.stats.character.trainedSkills.spellIDs[1] == 5177)
local statsCode = assert(P.EncodeStats(P.Current(S.ExportView())))
check(P.DecodeStats(statsCode).character.trainedSkills.spellIDs[1] == 5177)
local profile = assert(S.CreateProfile("Captured"))
local library = assert(FT.Library.Encode())
local restored = assert(FT.Library.Decode(library))
check(restored.database.settings.characters[11].trainedSkills.spellIDs[1] == 5177)
for _, bad in ipairs({ { 5177, 5177 }, { 0 }, { -1 }, { 1.5 }, { "5177" }, { [2] = 5177 } }) do
    local invalid = FT.Copy(training)
    invalid.spellIDs = bad
    check(not A.NormalizeTraining(invalid))
end
local invalid = FT.Copy(C.Get(S.View()))
invalid.trainedSkills.classID = 1
invalid.trainedSkills.raceID = 1
check(not C.Save(S.View(), invalid))
local originalCharacter = S.db.settings.characters[11]
S.db.settings.characters[11] = {
    schema = 1,
    mode = "manual",
    trainedSkills = { schema = 1, classID = 1, raceID = 1, level = 25, spellIDs = { 78 } },
}
local invalidLibrary = assert(FT.Library.Encode())
S.db.settings.characters[11] = originalCharacter
check(
    not FT.Library.Decode(invalidLibrary),
    "Library accepted training recorded under another class"
)
local before = assert(FT.Codec.Encode(S.Build()))
C_SpellBook.GetSpellBookItemInfo = function()
    return nil
end
check(not FT.ImportPlayerCharacter())
check(FT.Codec.Encode(S.Build()) == before, "Partial spellbook import overwrote build")
check(C.Get(S.View()).trainedSkills.spellIDs[1] == 5177)

-- Library creates an independent build; checkpoint mode alone creates a child.
UI.historyTab = "library"
UI.RefreshHistory()
check(UI.checkpointButton.fontString:GetText() == "+ New build")
UI.checkpointButton:Click()
check(UI.dialogs.save.heading:GetText() == "Save your build")
UI.dialogs.save.input:SetText("Independent")
UI.dialogs.save.save:Click()
check(#S.db.profileOrder == 2 and #profile.order == 1)
UI.historyTab = "graph"
UI.RefreshHistory()
check(UI.checkpointButton.fontString:GetText() == "+ Checkpoint")

-- Colors remain stable when another selection changes, and overlap shows both.
UI.ClearSkillHighlights()
local id = M.Class(11).trees[1].talents[1].id
for i = 1, 7 do
    UI.SetSkillHighlight(
        { name = "Selection " .. i, kind = "trained", related = { { id = id } } },
        true
    )
end
for i = 1, 6 do
    check(UI.highlightColors["skill:Selection " .. i] == i)
end
check(UI.highlightColors["skill:Selection 7"] == 1)
for i = 1, 6 do
    check(UI.highlight[id][i])
end
UI.SetSkillHighlight({ name = "Selection 2", kind = "trained" }, false)
check(UI.highlightColors["skill:Selection 3"] == 3)
check(not UI.highlight[id][2] and UI.highlight[id][3])
UI.ClearSkillHighlights()
check(not next(UI.highlightColors) and not next(UI.highlight))

-- Actual order-row and related-talent callbacks retain pinned selections.
local starfire = A.Prepare(11).byName.Starfire
UI.SetSkillHighlight(wrath, true)
UI.SetSkillHighlight(starfire, true)
local pinned = FT.Copy(UI.highlight)
local function checkPinnedOnly()
    for talentID, colors in pairs(UI.highlight) do
        for color in pairs(colors) do
            check(pinned[talentID] and pinned[talentID][color], "Temporary highlight remained")
        end
    end
    for talentID, colors in pairs(pinned) do
        for color in pairs(colors) do
            check(UI.highlight[talentID] and UI.highlight[talentID][color], "Pinned highlight lost")
        end
    end
end
local buildCode = assert(FT.Codec.Encode(S.Build()))
UI.historyTab = "order"
UI.RefreshHistory()
local row = UI.historyRows[1]
check(row and row:IsShown())
row:Trigger("OnEnter")
check(GameTooltip:IsShown() and UI.highlight[S.Build().order[1]][1])
for talentID, colors in pairs(pinned) do
    for color in pairs(colors) do
        check(UI.highlight[talentID][color], "Order hover lost a pinned highlight")
    end
end
check(UI.SkillHighlightKey(UI.hoverSkill) == nil)
UI.SetSkillHighlight(UI.hoverSkill, true)
check(UI.IsSkillHighlighted(wrath) and UI.IsSkillHighlighted(starfire))
row:Trigger("OnLeave")
check(not UI.hoverSkill and not GameTooltip:IsShown())
checkPinnedOnly()
check(FT.Codec.Encode(S.Build()) == buildCode, "Hover changed the build")
UI.SkillDialog(starfire)
UI.dialogs.skill.relatedRows[1]:Click()
check(not UI.dialogOverlay:IsShown())
check(UI.highlight[starfire.related[1].id][2], "Related-talent focus lost the skill's color")
UI.HighlightSkill(nil)
checkPinnedOnly()
S.SetSimpleView(true)
UI.HighlightSkill({ related = { { id = id } } })
check(not next(UI.highlight), "Classic mode displayed temporary highlights")
S.SetSimpleView(false)
UI.ClearSkillHighlights()
check(not next(UI.selectedSkills) and not next(UI.highlightColors) and not next(UI.highlight))
print("Character import and UI navigation: " .. checks .. " assertions passed")
