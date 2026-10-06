local name, FT = ...
_G.ForeverTalents = FT
FT.name, FT.version = name, "1.2.8"
FT.UI = {}
FT.classOrder = { 11, 3, 8, 2, 5, 4, 7, 9, 1 }

function FT.Copy(value)
    if type(value) ~= "table" then
        return value
    end
    local out = {}
    for k, v in pairs(value) do
        out[k] = FT.Copy(v)
    end
    return out
end

function FT.SafeText(value, limit)
    local text = tostring(value or ""):gsub("|", ""):gsub("[%z\1-\31\127]", " ")
    text = text:match("^%s*(.-)%s*$") or ""
    if #text > (limit or 48) then
        text = text:sub(1, limit or 48)
        -- Do not leave a partial UTF-8 sequence when truncating a player's title.
        while #text > 0 and text:byte(-1) >= 128 and text:byte(-1) < 192 do
            text = text:sub(1, -2)
        end
        if #text > 0 and text:byte(-1) >= 192 then
            text = text:sub(1, -2)
        end
    end
    return text
end

function FT.Print(text)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cffeba85bForever Talents|r  " .. tostring(text))
    end
end

function FT.Description(record)
    if type(record.text) == "string" and record.text ~= "" then
        return record.text, "snapshot"
    end
    local read = C_Spell and C_Spell.GetSpellDescription or GetSpellDescription
    if read and record.spellID then
        local ok, text = pcall(read, record.spellID)
        if ok and type(text) == "string" and text ~= "" then
            return text, "client"
        end
    end
    return "No description was recorded for this spell in the collected snapshot.", "missing"
end

function FT.Now()
    return time and time() or os.time()
end

function FT.Changed(message)
    if FT.UI.Refresh then
        FT.UI.Refresh()
    end
    if message and FT.UI.Status then
        FT.UI.Status(message)
    end
end
