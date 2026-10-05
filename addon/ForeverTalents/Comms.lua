local _, FT = ...
local C = { prefix = "FTALENTS1", lastReceived = {}, pending = {} }
FT.Comms = C

local function send(message, recipient)
    local fn = C_ChatInfo and C_ChatInfo.SendAddonMessage or SendAddonMessage
    if not fn then
        return false, "This client cannot send addon whispers. Use the copyable build string."
    end
    if
        C_ChatInfo
        and C_ChatInfo.AreOutgoingAddonChatMessagesRestricted
        and C_ChatInfo.AreOutgoingAddonChatMessagesRestricted()
    then
        return false,
            "Addon messages are restricted on this realm. Use Copy string or Text whisper."
    end
    local ok, result = pcall(fn, C.prefix, message, "WHISPER", recipient)
    local success = Enum and Enum.SendAddonMessageResult and Enum.SendAddonMessageResult.Success
        or 0
    if not ok or result == false or (type(result) == "number" and result ~= success) then
        return false, "The whisper could not be sent. Check the player name or copy the string."
    end
    return true
end

function C.Init()
    local register = C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix
        or RegisterAddonMessagePrefix
    if register then
        pcall(register, C.prefix)
    end
    if SetItemRef and not C.hooked then
        local original = SetItemRef
        -- Intercept only our locally rendered link. Never send a custom link to
        -- the server or pass an unsupported link to the Blizzard item tooltip.
        SetItemRef = function(link, text, button, chatFrame)
            if type(link) == "string" and link:sub(1, 15) == "forevertalents:" then
                local code = link:sub(16)
                if FT.UI.ImportDialog then
                    FT.UI.ImportDialog(code)
                end
                return
            end
            return original(link, text, button, chatFrame)
        end
        C.hooked = true
    end
end

function C.Link(build, code)
    local class = FT.Model.Class(build.classID)
    local label = FT.SafeText(build.name, 48)
        .. " · "
        .. class.name
        .. " · "
        .. #build.order
        .. " pts"
    return "|cffeba85b|Hforevertalents:" .. code .. "|h[" .. label .. "]|h|r"
end

function C.Send(build, recipient)
    recipient = FT.SafeText(recipient, 64)
    if recipient == "" or recipient:find("[%s:%[%]]") then
        return false, "Enter a player name, optionally followed by -Realm."
    end
    local clock = GetTime and GetTime() or FT.Now()
    if C.lastSend and clock - C.lastSend < 2 then
        return false, "Wait two seconds before sending another build."
    end
    local code, why = FT.Codec.Encode(build)
    if not code then
        return false, why
    end
    if #code + 2 > 240 then
        return false, "Use Copy string for this build."
    end
    local ok, errorText = send("B:" .. code, recipient)
    if not ok then
        return false, errorText
    end
    C.lastSend = clock
    local key = FT.Codec.Checksum(code)
    C.pending[key] = { recipient = recipient, sent = clock }
    if C_Timer and C_Timer.After then
        C_Timer.After(10, function()
            if C.pending[key] and C.pending[key].sent == clock then
                C.pending[key] = nil
                FT.Print(
                    "No receipt from "
                        .. recipient
                        .. ". They may be offline or missing the addon. Copy the build string to share it anywhere."
                )
            end
        end)
    end
    return true, "Sent to " .. recipient .. ". Waiting for their addon receipt."
end

function C.Receive(prefix, message, channel, sender)
    if
        prefix ~= C.prefix
        or channel ~= "WHISPER"
        or type(message) ~= "string"
        or #message > 240
        or type(sender) ~= "string"
    then
        return
    end
    if message:sub(1, 2) == "A:" then
        local key = message:sub(3)
        local pending = C.pending[key]
        local function short(n)
            return n:match("^[^-]+") or n
        end
        if
            pending
            and short(pending.recipient):lower() == short(sender):lower()
            and (
                not pending.recipient:find("-", 1, true)
                or pending.recipient:lower() == sender:lower()
            )
        then
            C.pending[key] = nil
            FT.Print(FT.SafeText(sender, 64) .. " received your build.")
            if FT.UI.Status then
                FT.UI.Status("Build delivered to " .. FT.SafeText(sender, 64) .. ".")
            end
        end
        return
    end
    if message:sub(1, 2) ~= "B:" then
        return
    end
    local clock = GetTime and GetTime() or FT.Now()
    if C.lastReceived[sender] and clock - C.lastReceived[sender] < 2 then
        return
    end
    local code = message:sub(3)
    local build = FT.Codec.Decode(code)
    if not build then
        return
    end
    C.lastReceived[sender] = clock
    local added = FT.Store.AddInbox(code, sender)
    if added then
        FT.Print(
            FT.SafeText(sender, 64)
                .. " shared "
                .. C.Link(build, code)
                .. "  |cff9caeb5Click to preview; also saved in Library → Received.|r"
        )
        if FT.UI.RefreshHistory then
            FT.UI.RefreshHistory()
        end
    end
    send("A:" .. FT.Codec.Checksum(code), sender)
end
