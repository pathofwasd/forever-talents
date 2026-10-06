local Mock = dofile("tests/wow_mock.lua")
local FT = Mock.Load()
local S, M, C, L, P = FT.Store, FT.Model, FT.Codec, FT.Library, FT.Snapshot
local checks = 0
local function check(value, message)
    checks = checks + 1
    assert(value, message)
end
local function buildCode(build)
    return assert(C.Encode(build or S.Build()))
end
_G.ForeverTalentsDB = nil
S.Init(8, 2, 60)
S.Import(dofile("tests/fixtures/mage_fire.lua"))
local p = S.CreateProfile("Shared Fire")
S.Checkpoint("Route A")
S.Apply(M.Remove, 105796)
local a = S.Checkpoint("Fire variation")
S.LoadNode(p.id, 1)
S.Apply(M.Remove, 105776)
local b = S.Checkpoint("Frost variation")
S.Apply(M.Add, 105776)
local draft = buildCode()
local working = buildCode(b.build)
S.SwitchClass(11)
S.CreateProfile("Private other build")
FT.Character.Save(S.Build(), { mode = "manual", stats = { power = 987 }, name = "Private stats" })
local original = assert(L.Encode())
local code = assert(L.EncodeProfile(p.id))
local link = assert(L.ProfileLink(p.id))
check(link == C.WebURL .. "#profile=" .. code)
check(assert(L.Encode()) == original, "sharing changed the source library")
check(assert(L.EncodeProfile(p.id)) == code, "saved-profile exports are unstable")
local snap = assert(P.Decode(link))
check(snap.kind == "profile" and snap.nodes == 4 and snap.selected == b.id)
check(snap.profile.nodes[a.id].parent == 2 and snap.profile.nodes[b.id].parent == 1)
check(not snap.profile.nodes[5] and working ~= draft, "unsaved draft leaked into profile")
check(buildCode(snap.build) == working)
check(#p.order == 4 and not p.nodes[5], "sharing saved a temporary node into the real profile")
check(not snap.stats and not snap.database and not snap.profile.characters)
local packed = L.Pack(snap)
check(not packed:find("Private other build", 1, true) and not packed:find("Private stats", 1, true))
for _, id in ipairs(p.order) do
    local actual = snap.profile.nodes[id]
    check(actual.title == p.nodes[id].title and actual.parent == p.nodes[id].parent)
    check(buildCode(actual.build) == buildCode(p.nodes[id].build))
end
check(assert(L.DecodeProfile(C.WebURL .. "#profile=" .. code:gsub(":", "%%3A"))).nodes == 4)
local function reject(input)
    check(not L.DecodeProfile(input))
    check(assert(L.Encode()) == original, "invalid preview mutated the library")
end
for _, bad in ipairs({
    link .. "!",
    link .. "%zz",
    code:sub(1, -2),
    "https://example.com/#profile=" .. code,
    C.WebURL .. "#profile=" .. buildCode(),
    false,
}) do
    reject(bad)
end
local raw = assert(L.Unpack(C.Unbase64(code:match("^FP1:[^:]+:([^:]+):"))))
local function malformed(change)
    local altered = FT.Copy(raw)
    change(altered)
    local body = "FP1:" .. FT.Data.meta.tag .. ":" .. C.Base64(L.Pack(altered))
    reject(body .. ":" .. C.Checksum(body))
end
malformed(function(w)
    w.profile.nodes[1].parent = 3
end)
malformed(function(w)
    w.profile.nodes[3].parent = 999
end)
malformed(function(w)
    w.profile.order[2] = 1
end)
malformed(function(w)
    w.profile.nodes[3].build = buildCode(M.New(1, 2, 60))
end)
malformed(function(w)
    w.profile.nodes[3].build = "FT1:bad"
end)
malformed(function(w)
    w.profile.nodes[99] = w.profile.nodes[1]
end)
malformed(function(w)
    w.selected = "5"
end)
malformed(function(w)
    w.selected = 999
end)
check(not C.Decode(link), "single-build import unexpectedly merged a profile")
check(not L.Decode(code), "profile mistaken for a full-library export")

-- Import opens every branch without importing other characters or replacing saved profiles.
_G.ForeverTalentsDB = nil
S.Init(8, 2, 60)
local own = S.CreateProfile("Keep my build")
check(S.SetAutoLevel(true))
check(S.Apply(M.Add, M.Class(8).trees[1].talents[1].id))
local prior = buildCode()
FT.Character.Save(S.Build(), { mode = "manual", name = "Keep stats", stats = { power = 123 } })
local character = FT.Library.Pack(S.db.settings.characters)
local result = assert(P.Apply(snap))
check(result.loaded and #S.db.profileOrder == 2 and result.profileID ~= own.id)
check(buildCode() == working and not S.AutoLevel(), "profile did not open at its shared level")
local imported = S.db.profiles[result.profileID]
check(#imported.order == 4 and imported.nodes[a.id].parent == 2)
check(assert(L.EncodeProfile(imported.id)) == code, "profile string changed across import")
check(assert(L.ProfileLink(imported.id)) == link)
check(FT.Library.Pack(S.db.settings.characters) == character)
check(#own.order == 1, "opening shared profile created an implicit checkpoint")
check(S.Undo() and buildCode() == prior and S.AutoLevel())
check(S.Redo() and buildCode() == working and not S.AutoLevel())
check(P.Apply(snap) and #S.db.profileOrder == 2, "re-import duplicated an identical profile")
local library = assert(L.Encode())
local decoded = assert(L.Decode(library))
_G.ForeverTalentsDB = FT.Copy(S.db)
S.Init(8, 2)
check(not S.db.recovered)
check(L.Pack(S.db.profiles) == L.Pack(decoded.database.profiles))
check(buildCode() == working)

-- Native copy/import controls use the same link and cannot whisper a partial profile.
FT.UI.Create()
FT.UI.ShareDialog()
local share = FT.UI.dialogs.share
share.profileLink:Click()
check(share.code:GetText() == assert(L.ProfileLink(imported.id)))
check(not share.send:IsEnabled() and not share.text:IsEnabled())
share.profileString:Click()
check(share.code:GetText() == assert(L.EncodeProfile(imported.id)))
share.link:Click()
check(share.code:GetText() == assert(C.BuildLink(S.ExportView())) and share.send:IsEnabled())
FT.UI.ImportDialog(link)
local dialog = FT.UI.dialogs.character
check(dialog.snapshot.kind == "profile" and dialog.snapshot.nodes == 4)
check(dialog.summary:GetText():find("4 checkpoints", 1, true) and not dialog.drafts:IsShown())
dialog.output:SetText(link .. "!")
check(not dialog.load:IsEnabled())
dialog.output:SetText(link)
dialog.load:Click()
check(#S.db.profileOrder == 2 and buildCode() == working)
check(S.DeleteNode(imported.id, 2))
check(not S.db.profiles[imported.id].nodes[3] and S.db.profiles[imported.id].nodes[4])

-- Large trees remain portable as strings/files; link limits fail clearly.
_G.ForeverTalentsDB = nil
S.Init(8, 2, 60)
S.Import(dofile("tests/fixtures/mage_fire.lua"))
p = S.CreateProfile("Large profile")
for i = 2, 400 do
    check(S.Checkpoint("Long checkpoint title for a large profile " .. i))
end
local large = assert(L.EncodeProfile(p.id))
check(assert(L.DecodeProfile(large)).nodes == 400)
local limited, why = L.ProfileLink(p.id)
check(not limited and why:find("too large for a link", 1, true))
print(string.format("Profile links: %d assertions passed", checks))
