-- A strict, deterministic WoW UI/API harness. Unknown methods fail instead of
-- silently succeeding. It records real addon widget geometry for visual QA.
local Mock = {
    objects = {},
    messages = {},
    sent = {},
    timers = {},
    clock = 100,
    ctrl = false,
    shift = false,
}
local methods = {}
local function object(kind, name, parent)
    local o = setmetatable({
        kind = kind,
        name = name,
        parent = parent,
        children = {},
        anchors = {},
        scripts = {},
        shown = true,
        enabled = true,
        width = 0,
        height = 0,
        mockScale = 1,
        alpha = 1,
    }, {
        __index = function(_, key)
            local m = methods[key]
            if m then
                return m
            end
            return nil
        end,
    })
    Mock.objects[#Mock.objects + 1] = o
    o.id = #Mock.objects
    if parent then
        parent.children[#parent.children + 1] = o
    end
    if name then
        _G[name] = o
    end
    return o
end
function methods:SetSize(w, h)
    self.width, self.height = w, h
end
function methods:SetWidth(w)
    self.width = w
end
function methods:SetHeight(h)
    self.height = h
end
function methods:GetWidth()
    return self.width
end
function methods:GetHeight()
    return self.height
end
function methods:SetPoint(...)
    self.anchors[#self.anchors + 1] = { ... }
end
function methods:GetPoint()
    return unpack(self.anchors[1] or { "CENTER", UIParent, "CENTER", 0, 0 })
end
function methods:ClearAllPoints()
    self.anchors = {}
end
function methods:SetAllPoints(relative)
    self.allPoints = relative or self.parent
end
function methods:GetParent()
    return self.parent
end
function methods:SetParent(parent)
    self.parent = parent
end
function methods:SetScale(s)
    self.mockScale = s
end
function methods:GetScale()
    return self.mockScale
end
function methods:GetEffectiveScale()
    return self.mockScale * (self.parent and self.parent:GetEffectiveScale() or 1)
end
function methods:GetCenter()
    return 640, 412
end
function methods:SetFrameStrata(s)
    self.strata = s
end
function methods:SetFrameLevel(l)
    self.level = l
end
function methods:GetFrameLevel()
    return self.level or 0
end
function methods:SetToplevel(v)
    self.toplevel = v
end
function methods:SetClampedToScreen(v)
    self.clamped = v
end
function methods:EnableMouse(v)
    self.mouse = v
end
function methods:EnableKeyboard(v)
    self.keyboard = v
end
function methods:EnableMouseWheel(v)
    self.wheel = v
end
function methods:SetMovable(v)
    self.movable = v
end
function methods:SetPropagateKeyboardInput(v)
    self.propagate = v
end
function methods:StartMoving()
    self.moving = true
end
function methods:StopMovingOrSizing()
    self.moving = false
end
function methods:RegisterForDrag(...)
    self.drag = { ... }
end
function methods:RegisterForClicks(...)
    self.clicks = { ... }
end
function methods:RegisterEvent(e)
    self.events = self.events or {}
    self.events[e] = true
end
function methods:SetScript(event, callback)
    self.scripts[event] = callback
end
function methods:GetScript(event)
    return self.scripts[event]
end
function methods:HookScript(event, callback)
    local before = self.scripts[event]
    self.scripts[event] = function(...)
        if before then
            before(...)
        end
        callback(...)
    end
end
function methods:Trigger(event, ...)
    if self.scripts[event] then
        return self.scripts[event](self, ...)
    end
end
function methods:Click(button)
    if self.enabled then
        if self.kind == "CheckButton" then
            self:SetChecked(not self:GetChecked())
        end
        return self:Trigger("OnClick", button or "LeftButton")
    end
end
function methods:SetChecked(value)
    assert(self.kind == "CheckButton", "SetChecked requires a CheckButton")
    self.mockChecked = not not value
    if self.checkedTexture then
        self.checkedTexture:SetShown(self.mockChecked)
    end
end
function methods:GetChecked()
    assert(self.kind == "CheckButton")
    return self.mockChecked or false
end
function methods:SetCheckedTexture(texture)
    assert(self.kind == "CheckButton" and texture.kind == "Texture")
    self.checkedTexture = texture
    texture:SetShown(self:GetChecked())
end
function methods:Show()
    local was = self.shown
    self.shown = true
    if not was then
        self:Trigger("OnShow")
    end
end
function methods:Hide()
    local was = self.shown
    self.shown = false
    if was then
        self:Trigger("OnHide")
    end
end
function methods:SetShown(v)
    if v then
        self:Show()
    else
        self:Hide()
    end
end
function methods:IsShown()
    return self.shown
end
function methods:IsVisible()
    return self.shown and (not self.parent or self.parent:IsVisible())
end
function methods:Enable()
    local before = self.enabled
    self.enabled = true
    if not before then
        self:Trigger("OnEnable")
    end
end
function methods:Disable()
    local before = self.enabled
    self.enabled = false
    if before then
        self:Trigger("OnDisable")
    end
end
function methods:SetEnabled(v)
    if v then
        self:Enable()
    else
        self:Disable()
    end
end
function methods:IsEnabled()
    return self.enabled
end
function methods:SetAlpha(a)
    self.alpha = a
end
function methods:GetAlpha()
    return self.alpha
end
function methods:SetBackdrop(v)
    self.backdrop = v
end
function methods:SetBackdropColor(...)
    self.bg = { ... }
end
function methods:SetBackdropBorderColor(...)
    self.border = { ... }
end
function methods:CreateTexture(name, layer, _, sublevel)
    local o = object("Texture", name, self)
    o.layer, o.sublevel = layer, sublevel
    return o
end
function methods:CreateFontString(name, layer)
    local o = object("FontString", name, self)
    o.layer = layer
    return o
end
function methods:CreateLine(name, layer)
    local o = object("Line", name, self)
    o.layer = layer
    return o
end
function methods:SetStartPoint(anchor, x, y)
    self.start = { anchor, x, y }
end
function methods:SetEndPoint(anchor, x, y)
    self.finish = { anchor, x, y }
end
function methods:SetThickness(t)
    self.thickness = t
end
function methods:SetTexture(t)
    self.texture = t
    return true
end
function methods:SetColorTexture(...)
    self.color = { ... }
end
function methods:SetVertexColor(...)
    self.vertex = { ... }
end
function methods:SetTexCoord(...)
    self.texcoord = { ... }
end
function methods:SetDesaturated(v)
    self.desaturated = v
end
function methods:SetFont(path, size, flags)
    self.font, self.fontSize, self.fontFlags = path, size, flags
    return true
end
function methods:SetFontObject(font)
    self.fontObject = font
    self.fontSize = 13
end
function methods:SetFontString(f)
    self.fontString = f
end
function methods:SetNormalFontObject() end
function methods:SetDisabledFontObject() end
function methods:SetText(text)
    self.mockText = tostring(text or "")
    if self.fontString then
        self.fontString:SetText(self.mockText)
    end
    self:Trigger("OnTextChanged", false)
end
function methods:GetText()
    return self.mockText or ""
end
function methods:UserText(text)
    self.mockText = tostring(text)
    self:Trigger("OnTextChanged", true)
end
function methods:SetTextColor(...)
    self.textColor = { ... }
end
function methods:SetJustifyH(v)
    self.justifyH = v
end
function methods:SetJustifyV(v)
    self.justifyV = v
end
function methods:SetWordWrap(v)
    self.wrap = v
end
function methods:GetStringWidth()
    return #self:GetText() * (self.fontSize or 13) * 0.52
end
function methods:GetStringHeight()
    return (self.fontSize or 13)
        * 1.18
        * math.max(1, math.ceil(self:GetStringWidth() / math.max(1, self.width)))
end
function methods:SetTextInsets(...)
    self.insets = { ... }
end
function methods:SetAutoFocus(v)
    self.autoFocus = v
end
function methods:SetMaxLetters(v)
    self.maxLetters = v
end
function methods:SetMultiLine(v)
    self.multiline = v
end
function methods:SetFocus()
    Mock.focus = self
end
function methods:ClearFocus()
    if Mock.focus == self then
        Mock.focus = nil
    end
end
function methods:HasFocus()
    return Mock.focus == self
end
function methods:HighlightText()
    self.selected = true
end
function methods:SetScrollChild(c)
    self.scrollChild = c
end
function methods:SetVerticalScroll(v)
    self.mockVertical = v
end
function methods:GetVerticalScroll()
    return self.mockVertical or 0
end
function methods:SetHorizontalScroll(v)
    self.mockHorizontal = v
end
function methods:SetOrientation(v)
    self.orientation = v
end
function methods:SetMinMaxValues(a, b)
    self.minimum, self.maximum = a, b
end
function methods:SetValueStep(s)
    self.step = s
end
function methods:SetThumbTexture(path)
    self.thumb = object("Texture", nil, self)
    self.thumb:SetTexture(path)
end
function methods:GetThumbTexture()
    return self.thumb
end
function methods:SetValue(v)
    local before = self.value
    self.value = v
    if before ~= v then
        self:Trigger("OnValueChanged", v)
    end
end
function methods:GetValue()
    return self.value or 0
end
function methods:SetOwner(owner, anchor)
    self.owner, self.tooltipAnchor = owner, anchor
    self.lines = {}
end
function methods:AddLine(text, ...)
    self.lines[#self.lines + 1] = { text = text, color = { ... } }
end
function methods:AddDoubleLine(a, b, ...)
    self.lines[#self.lines + 1] = { text = a .. "    " .. b, color = { ... } }
end
function methods:AddMessage(text)
    Mock.messages[#Mock.messages + 1] = text
end

function CreateFrame(kind, name, parent, template)
    local o = object(kind, name, parent)
    o.template = template
    return o
end
UIParent = CreateFrame("Frame", "UIParent")
UIParent:SetSize(1440, 1000)
Minimap = CreateFrame("Frame", "Minimap", UIParent)
Minimap:SetSize(140, 140)
GameTooltip = CreateFrame("GameTooltip", "GameTooltip", UIParent)
GameTooltip.lines = {}
GameTooltip:Hide()
DEFAULT_CHAT_FRAME = CreateFrame("Frame", "DEFAULT_CHAT_FRAME", UIParent)
GameFontHighlight = {}
UISpecialFrames = {}
SlashCmdList = {}
function UnitClass()
    return "Druid", "DRUID", 11
end
function UnitRace()
    return "Night Elf", "NightElf", 4
end
function UnitLevel()
    return 60
end
function GetTime()
    return Mock.clock
end
function time()
    return 1791174000
end
function IsControlKeyDown()
    return Mock.ctrl
end
function IsShiftKeyDown()
    return Mock.shift
end
function GetCurrentKeyBoardFocus()
    return Mock.focus and Mock.focus:IsVisible() and Mock.focus or nil
end
function InCombatLockdown()
    return false
end
function GetCursorPosition()
    return 640, 500
end
function SetItemRef(link)
    Mock.originalLink = link
end
function ChatFrame_OpenChat(text)
    Mock.chatDraft = text
end
function GetSpellBonusDamage()
    return 200
end
function GetSpellBonusHealing()
    return 300
end
function GetSpellCritChance()
    return 10
end
function GetCritChance()
    return 15
end
function UnitAttackPower()
    return 300, 50, 0
end
function UnitDamage()
    return 40, 60
end
C_Spell = {
    GetSpellInfo = function()
        return nil
    end,
}
C_Timer = {
    After = function(seconds, callback)
        Mock.timers[#Mock.timers + 1] = { at = Mock.clock + seconds, callback = callback }
    end,
}
C_ChatInfo = {
    RegisterAddonMessagePrefix = function(prefix)
        Mock.prefix = prefix
        return true
    end,
    AreOutgoingAddonChatMessagesRestricted = function()
        return false
    end,
    SendAddonMessage = function(prefix, message, channel, target)
        Mock.sent[#Mock.sent + 1] =
            { prefix = prefix, message = message, channel = channel, target = target }
        return 0
    end,
}
Enum = { SendAddonMessageResult = { Success = 0 } }

function Mock.Load()
    local FT = {}
    local toc = assert(io.open("addon/ForeverTalents/ForeverTalents.toc")):read("*a")
    for line in toc:gmatch("[^\r\n]+") do
        if line:match("%.lua$") then
            assert(loadfile("addon/ForeverTalents/" .. line:gsub("\\", "/")))("ForeverTalents", FT)
        end
    end
    FT.events:Trigger("OnEvent", "ADDON_LOADED", "ForeverTalents")
    FT.events:Trigger("OnEvent", "PLAYER_LOGIN")
    return FT
end

local function quote(text)
    return '"'
        .. text:gsub("\\", "\\\\")
            :gsub('"', '\\"')
            :gsub("\n", "\\n")
            :gsub("\r", "\\r")
            :gsub("\t", "\\t")
        .. '"'
end
function Mock.JSON(value)
    if type(value) == "string" then
        return quote(value)
    end
    if type(value) == "number" or type(value) == "boolean" then
        return tostring(value)
    end
    if value == nil then
        return "null"
    end
    local out = {}
    if #value > 0 then
        for _, v in ipairs(value) do
            out[#out + 1] = Mock.JSON(v)
        end
        return "[" .. table.concat(out, ",") .. "]"
    end
    for k, v in pairs(value) do
        out[#out + 1] = quote(tostring(k)) .. ":" .. Mock.JSON(v)
    end
    return "{" .. table.concat(out, ",") .. "}"
end

function Mock.Dump(path, root)
    local list = {}
    for _, o in ipairs(Mock.objects) do
        local a = o
        local belongs = false
        while a do
            if a == root then
                belongs = true
                break
            end
            a = a.parent
        end
        if belongs and o:IsVisible() then
            local anchors = {}
            for _, p in ipairs(o.anchors) do
                local point = {}
                for i, v in ipairs(p) do
                    point[i] = type(v) == "table" and { ref = v.id } or v
                end
                anchors[#anchors + 1] = point
            end
            list[#list + 1] = {
                id = o.id,
                parent = o.parent and o.parent.id,
                kind = o.kind,
                width = o.width,
                height = o.height,
                anchors = anchors,
                allPoints = o.allPoints and o.allPoints.id,
                bg = o.bg,
                border = o.border,
                texture = o.texture,
                color = o.color,
                vertex = o.vertex,
                alpha = o.alpha,
                text = o.mockText,
                textColor = o.textColor,
                fontSize = o.fontSize,
                justifyH = o.justifyH,
                justifyV = o.justifyV,
                wrap = o.wrap,
                scale = o.mockScale,
                level = o.level,
                strata = o.strata,
                layer = o.layer,
                sublevel = o.sublevel,
                desaturated = o.desaturated,
                start = o.start,
                finish = o.finish,
                thickness = o.thickness,
                vertical = o.mockVertical,
                horizontal = o.mockHorizontal,
                scrollChild = o.scrollChild and o.scrollChild.id,
                insets = o.insets,
            }
        end
    end
    local file = assert(io.open(path, "w"))
    file:write(Mock.JSON({ root = root.id, objects = list }))
    file:close()
end
return Mock
