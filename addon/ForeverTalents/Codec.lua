local _, FT = ...
local C = {}
FT.Codec = C
C.WebURL = "https://pathofwasd.github.io/forever-talents/"
local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
local values = {}
for i = 1, #alphabet do
    values[alphabet:sub(i, i)] = i - 1
end

local function base64(text)
    local out, acc, bits = {}, 0, 0
    for i = 1, #text do
        acc, bits = acc * 256 + text:byte(i), bits + 8
        while bits >= 6 do
            bits = bits - 6
            local v = math.floor(acc / 2 ^ bits)
            out[#out + 1] = alphabet:sub(v + 1, v + 1)
            acc = acc % 2 ^ bits
        end
    end
    if bits > 0 then
        local v = acc * 2 ^ (6 - bits)
        out[#out + 1] = alphabet:sub(v + 1, v + 1)
    end
    return table.concat(out)
end

local function unbase64(text)
    local out, acc, bits = {}, 0, 0
    for i = 1, #text do
        local value = values[text:sub(i, i)]
        if not value then
            return nil
        end
        acc, bits = acc * 64 + value, bits + 6
        if bits >= 8 then
            bits = bits - 8
            out[#out + 1] = string.char(math.floor(acc / 2 ^ bits))
            acc = acc % 2 ^ bits
        end
    end
    local result = table.concat(out)
    if base64(result) ~= text then
        return nil
    end
    return result
end

function C.Checksum(text)
    local a, b = 1, 0
    for i = 1, #text do
        a = (a + text:byte(i)) % 65521
        b = (b + a) % 65521
    end
    return string.format("%08x", b * 65536 + a)
end

function C.Encode(build)
    local ok, why = FT.Model.Preserve(build)
    if not ok then
        return nil, why
    end
    local index, order = FT.Model.Index(build.classID), {}
    for _, id in ipairs(build.order) do
        local ordinal = index[id].index
        if ordinal > 64 then
            return nil, "This class needs a newer sharing format."
        end
        order[#order + 1] = alphabet:sub(ordinal, ordinal)
    end
    local name = FT.SafeText(build.name, 48)
    local body = table.concat({
        "FT1",
        build.legacyTag or FT.Data.meta.tag,
        build.classID,
        build.raceID,
        build.level,
        table.concat(order),
        base64(name),
    }, ":")
    return body .. ":" .. C.Checksum(body)
end

function C.BuildLink(build)
    local code, why = C.Encode(build)
    return code and (C.WebURL .. "#build=" .. code) or nil, why
end

function C.LinkCode(input, kind)
    local prefix = C.WebURL .. "#" .. (kind or "build") .. "="
    if input:sub(1, #prefix) ~= prefix then
        return nil, "Paste a Forever Talents build link or build string."
    end
    local code = input:sub(#prefix + 1)
    -- Accept browsers' percent-escaped fragments without changing the FT1 format.
    local invalid = false
    code = code:gsub("%%(..)", function(pair)
        local byte = pair:match("^%x%x$") and tonumber(pair, 16)
        if not byte then
            invalid = true
            return ""
        end
        return string.char(byte)
    end)
    if invalid or code:find("%%") then
        return nil, "The build link is incomplete or damaged. Copy the entire link again."
    end
    return code
end

function C.Decode(input)
    if type(input) == "string" and input:match("^%s*https?://") then
        if #input > 2048 then
            return nil, "Build links must be at most 2048 characters."
        end
        local why
        input, why = C.LinkCode(input:match("^%s*(.-)%s*$"))
        if not input then
            return nil, why
        end
    end
    if type(input) ~= "string" or #input > 512 then
        return nil, "Paste a Forever Talents build string (at most 512 characters)."
    end
    local text = input:match("^%s*(.-)%s*$")
    local version, tag, class, race, level, order, encodedName, checksum =
        text:match("^(FT%d+):([%x]+):(%d+):(%d+):(%d+):([%w_-]*):([%w_-]*):([%x]+)$")
    if not version then
        return nil, "This is not a complete Forever Talents build string."
    end
    if version ~= "FT1" then
        return nil, "This build needs a newer version of Forever Talents."
    end
    if not FT.Model.AcceptTag(tag) then
        return nil,
            "This build uses a different talent dataset. Both players need the same Forever Talents version."
    end
    local body = text:match("^(.*):[^:]+$")
    if #checksum ~= 8 or C.Checksum(body) ~= checksum then
        return nil, "The build string is incomplete or damaged. Copy the entire string again."
    end
    class, race, level = tonumber(class), tonumber(race), tonumber(level)
    if not FT.Model.Class(class) then
        return nil, "Unknown class in this build."
    end
    if #order > 51 then
        return nil, "A build can contain at most 51 points."
    end
    local name = unbase64(encodedName)
    if not name or #name > 48 or FT.SafeText(name, 48) ~= name then
        return nil, "Invalid build title."
    end
    local build = {
        classID = class,
        raceID = race,
        level = level,
        name = name ~= "" and name or "Untitled build",
        order = {},
    }
    local _, byOrdinal = FT.Model.Index(class)
    for i = 1, #order do
        local n = values[order:sub(i, i)]
        local t = n and byOrdinal[n + 1]
        if not t then
            return nil, "Unknown talent in the point order."
        end
        build.order[#build.order + 1] = t.id
    end
    local ok, why = FT.Model.Preserve(build, tag)
    if not ok then
        return nil, why
    end
    return build
end

-- Allocations carry class and ordered points only; destination context stays local.
function C.EncodeTalents(build)
    local code, why = C.Encode(build)
    if not code then
        return nil, why
    end
    local order = code:match("^FT1:[^:]+:%d+:%d+:%d+:([^:]*):")
    local tag = code:match("^FT1:([^:]+):")
    local body = "FA1:" .. tag .. ":" .. build.classID .. ":" .. order
    return body .. ":" .. C.Checksum(body)
end

function C.DecodeTalents(input)
    if type(input) ~= "string" or #input > 512 then
        return nil, "Paste a complete talents-only string (at most 512 characters)."
    end
    input = input:match("^%s*(.-)%s*$")
    local version, tag, classID, order, checksum =
        input:match("^(FA%d+):([%x]+):(%d+):([%w_-]*):([%x]+)$")
    if not version then
        return nil, "This is not a talents-only string. Use Copy talents in either app."
    end
    if version ~= "FA1" then
        return nil, "These talents need a newer version of Forever Talents."
    end
    if not FT.Model.AcceptTag(tag) then
        return nil,
            "These talents use a different dataset. Both players need the same data version."
    end
    local body = input:match("^(.*):[^:]+$")
    if #checksum ~= 8 or C.Checksum(body) ~= checksum then
        return nil, "The talents string is incomplete or damaged. Copy the entire string again."
    end
    classID = tonumber(classID)
    local class = FT.Model.Class(classID)
    if not class then
        return nil, "Unknown class in these talents."
    end
    -- The existing build decoder owns ordinal lookup and legal order validation.
    local full = table.concat({ "FT1", tag, classID, class.races[1], 60, order, "" }, ":")
    local build, why = C.Decode(full .. ":" .. C.Checksum(full))
    return build and {
        classID = classID,
        order = build.order,
        legacyTag = build.legacyTag,
        recovery = build.recovery,
    } or nil,
        why
end

function C.EncodeOriginal(build)
    if not build or not build.recovery then
        return nil, "This build has no migration backup."
    end
    return C.Encode(FT.Copy(build.recovery))
end

-- Shared envelope codecs use the same canonical URL-safe encoding.
C.Base64, C.Unbase64 = base64, unbase64
