local _, FT = ...
local UI, W, S, P, L = FT.UI, FT.UI.W, FT.Store, FT.Snapshot, FT.Library
function UI.CharacterDialog(code)
    if not UI.frame then
        UI.Create()
    end
    UI.frame:Show()
    local f, first =
        UI.Dialog("character", "Character & library • addon ↔ web / mobile", 860, 650)
    if first then
        W.Text(
            f,
            "Copy a full character (FC1), simulation stats (FS1), or your whole library (FL1).\nPaste strings from the PWA or addon here. Builds still support the original FT1 format.",
            22,
            -65,
            816,
            13,
            W.colors.muted
        )
        f.codeScroll = W.Scroll(f, 22, -130, 816, 190)
        f.output = W.Edit(
            f.codeScroll.content,
            "Paste or generate a sharing string…",
            0,
            0,
            790,
            nil,
            3 * 1024 * 1024
        )
        f.output:SetHeight(190)
        f.output:SetMultiLine(true)
        f.output:SetTextInsets(12, 28, 10, 10)
        f.summary = W.Text(f, "", 22, -336, 816, 13, W.colors.gold)
        f.details = W.Text(f, "", 22, -366, 816, 11, W.colors.muted)
        local function export(code, why)
            if not code then
                f.summary:SetText(why or "Export failed.")
                return
            end
            f.output:SetText(code)
            f.output:SetFocus()
            f.output:HighlightText()
            f.summary:SetText("Ready to copy • Ctrl+C, then paste into the other version.")
        end
        W.Button(f, "Copy planned character", 22, -428, 260, function()
            local b = S.ExportView()
            local p = P.Current(b)
            export(P.EncodeCharacter(b, p))
        end)
        W.Button(f, "Copy simulation stats", 300, -428, 260, function()
            local sim = UI.dialogs.simulation
            local p = P.Current(S.ExportView(), sim and sim.skill and sim.skill.name or nil)
            export(P.EncodeStats(p))
        end)
        W.Button(f, "Copy whole library", 578, -428, 260, function()
            export(L.Encode())
        end)
        W.Button(f, "Read logged-in character", 22, -472, 400, function()
            local b, why = FT.ReadPlayerBuild()
            if not b then
                f.summary:SetText(why)
                return
            end
            local p = FT.ReadPlayerStats()
            p.classID, p.raceID, p.level = b.classID, b.raceID, b.level
            export(P.EncodeCharacter(b, p))
        end, true)
        W.Button(f, "Read only live stats", 438, -472, 400, function()
            export(P.EncodeStats(FT.ReadPlayerStats()))
        end)
        f.drafts = W.Checkbox(f, 22, -522, function(checked)
            f.includeDrafts = checked
        end)
        f.draftLabel = W.Text(
            f,
            "Library import: also replace class drafts (saved profiles are merged)",
            52,
            -526,
            782,
            12
        )
        f.load = W.Button(f, "Load snapshot / merge library", 22, -566, 816, function()
            if not f.snapshot then
                return
            end
            if f.snapshot.kind == "library" then
                W.Result(L.Merge(f.snapshot, f.includeDrafts))
            else
                W.Result(P.Apply(f.snapshot))
            end
            UI.CloseDialog()
        end, true, 34)
        local function update()
            local code = f.output:GetText()
            local snap, why
            if code:match("^%s*FL1:") then
                snap, why = L.Decode(code)
            else
                snap, why = P.Decode(code)
            end
            f.snapshot = snap
            f.load:SetEnabled(snap ~= nil)
            f.drafts:SetShown(snap and snap.kind == "library" or false)
            f.draftLabel:SetShown(snap and snap.kind == "library" or false)
            if not snap then
                f.summary:SetText(
                    code ~= "" and (why or "") or "Paste a sharing string to preview it."
                )
                f.details:SetText("")
                return
            end
            if snap.kind == "library" then
                f.summary:SetText(
                    snap.profiles
                        .. " saved profiles • "
                        .. snap.nodes
                        .. " checkpoints • "
                        .. snap.drafts
                        .. " class drafts"
                )
                f.details:SetText(
                    "Merge adds profiles and skips exact duplicates. Checked above: imported drafts replace existing class drafts.\nExport your current library first to keep a backup. Saved checkpoint titles, parents and orders are preserved."
                )
            else
                local b = snap.build or snap.stats
                f.summary:SetText(
                    FT.Model.Class(b.classID).name
                        .. " • "
                        .. FT.Data.races[b.raceID].name
                        .. " • level "
                        .. b.level
                        .. " • "
                        .. snap.kind
                )
                f.details:SetText(
                    snap.build
                            and (#snap.build.order .. " ordered talent points. Character imports also load simulation stats; stats-only keeps your talents.")
                        or "Simulation stats only: current talents, race and target level are kept."
                )
            end
        end
        f.output:HookScript("OnTextChanged", update)
    end
    f.includeDrafts = false
    f.drafts:SetChecked(false)
    f.output:SetText(code or "")
    if not code then
        f.summary:SetText("Paste a sharing string or choose a copy option below.")
    else
        f.output:SetFocus()
    end
end
