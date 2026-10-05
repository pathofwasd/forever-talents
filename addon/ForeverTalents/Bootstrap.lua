local _, FT = ...
local M = FT.Model
BINDING_HEADER_FOREVERTALENTS = "Forever Talents"
BINDING_NAME_FOREVERTALENTS_TOGGLE = "Open / close talent planner"

local function slash(message)
    local command, rest = (message or ""):match("^%s*(%S*)%s*(.-)%s*$")
    command = command:lower()
    if command == "help" then
        if not FT.UI.frame then
            FT.UI.Create()
        end
        FT.UI.frame:Show()
        FT.UI.HelpDialog()
    elseif command == "import" then
        FT.UI.ImportDialog(rest)
    elseif command == "share" then
        if not FT.UI.frame then
            FT.UI.Create()
        end
        FT.UI.frame:Show()
        FT.UI.ShareDialog()
    elseif command == "character" then
        if not FT.UI.frame then
            FT.UI.Create()
        end
        FT.UI.frame:Show()
        FT.UI.CharacterDialog()
    elseif command == "mine" then
        FT.UI.W.Result(FT.ImportPlayer())
    elseif command == "resetwindow" then
        FT.Store.db.settings.position = nil
        if FT.UI.frame then
            FT.UI.frame:ClearAllPoints()
            FT.UI.frame:SetPoint("CENTER")
            FT.UI.Fit()
        end
    elseif command == "minimap" then
        FT.Store.db.settings.minimap = not FT.Store.db.settings.minimap
        FT.UI.RefreshMinimap()
    else
        FT.UI.Toggle()
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("CHAT_MSG_ADDON")
events:RegisterEvent("DISPLAY_SIZE_CHANGED")
events:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if name ~= FT.name then
            return
        end
        local _, _, classID = UnitClass("player")
        local _, _, raceID = UnitRace("player")
        FT.Store.Init(classID, raceID, 60)
        SLASH_FOREVERTALENTS1 = "/ftc"
        SLASH_FOREVERTALENTS2 = "/forevertalents"
        SlashCmdList.FOREVERTALENTS = slash
        FT.Comms.Init()
    elseif event == "PLAYER_LOGIN" then
        FT.UI.RefreshMinimap()
    elseif event == "CHAT_MSG_ADDON" then
        if FT.Store.db then
            FT.Comms.Receive(...)
        end
    elseif event == "DISPLAY_SIZE_CHANGED" then
        FT.UI.Fit()
    end
end)
FT.events = events
