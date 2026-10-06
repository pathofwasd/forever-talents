local _, FT = ...
local W = {}
FT.UI.W = W
W.colors = {
    bg = { 0.055, 0.065, 0.077 },
    panel = { 0.078, 0.092, 0.108 },
    line = { 0.20, 0.24, 0.28 },
    muted = { 0.56, 0.63, 0.68 },
    gold = { 0.92, 0.66, 0.36 },
    text = { 0.89, 0.92, 0.94 },
    teal = { 0.32, 0.78, 0.74 },
}
local function color(c)
    return unpack(c)
end

function W.Skin(frame, c, border)
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    frame:SetBackdropColor(color(c or W.colors.panel))
    frame:SetBackdropBorderColor(color(border or W.colors.line))
end

function W.Panel(parent, x, y, width, height, c)
    local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    f:SetPoint("TOPLEFT", x, y)
    f:SetSize(width, height)
    W.Skin(f, c)
    return f
end

function W.Text(parent, text, x, y, width, size, c)
    local f = parent:CreateFontString(nil, "OVERLAY")
    f:SetFont("Fonts\\FRIZQT__.TTF", size or 13, "")
    f:SetPoint("TOPLEFT", x, y)
    f:SetWidth(width or 200)
    f:SetJustifyH("LEFT")
    f:SetJustifyV("TOP")
    f:SetTextColor(color(c or W.colors.text))
    f:SetText(text or "")
    return f
end

function W.Icon(parent, icon, x, y, size)
    local t = parent:CreateTexture(nil, "ARTWORK")
    t:SetPoint("TOPLEFT", x, y)
    t:SetSize(size, size)
    t:SetTexture(
        "Interface\\AddOns\\ForeverTalents\\Media\\Icons\\" .. (icon or "class_druid") .. ".tga"
    )
    t:SetTexCoord(0.05, 0.95, 0.05, 0.95)
    return t
end

function W.Button(parent, text, x, y, width, callback, primary, height)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetPoint("TOPLEFT", x, y)
    b:SetSize(width, height or 28)
    W.Skin(b)
    local padding = width < 40 and 2 or 7
    local label = W.Text(b, text, padding, -7, width - padding * 2, 12)
    label:ClearAllPoints()
    label:SetPoint("LEFT", padding, 0)
    label:SetPoint("RIGHT", -padding, 0)
    label:SetJustifyH("CENTER")
    label:SetJustifyV("MIDDLE")
    label:SetWordWrap(false)
    b:SetFontString(label)
    b.primary, b.active = primary, false
    function b:Paint(hover)
        if self.active or self.primary then
            self:SetBackdropColor(hover and 0.24 or 0.16, hover and 0.23 or 0.17, 0.12, 1)
            self:SetBackdropBorderColor(0.70, 0.46, 0.24, 1)
        else
            self:SetBackdropColor(
                hover and 0.15 or 0.105,
                hover and 0.18 or 0.126,
                hover and 0.21 or 0.15,
                1
            )
            self:SetBackdropBorderColor(color(W.colors.line))
        end
        label:SetTextColor(color(self:IsEnabled() and W.colors.text or W.colors.muted))
    end
    function b:SetActive(active)
        self.active = active
        self:Paint(false)
    end
    b:SetScript("OnEnter", function(self)
        self:Paint(true)
        if self.tip then
            W.Tooltip(self, self.tip)
        end
    end)
    b:SetScript("OnLeave", function(self)
        self:Paint(false)
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)
    b:SetScript("OnEnable", function(self)
        self:Paint(false)
    end)
    b:SetScript("OnDisable", function(self)
        self:Paint(false)
    end)
    b:SetScript("OnClick", function(self, button)
        if callback then
            callback(self, button)
        end
    end)
    b:Paint(false)
    return b
end

function W.Tooltip(owner, title, lines)
    if not GameTooltip then
        return
    end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetText(title, 0.94, 0.76, 0.50, 1, true)
    for _, line in ipairs(lines or {}) do
        GameTooltip:AddLine(line, 0.82, 0.87, 0.90, true)
    end
    GameTooltip:Show()
end

function W.Checkbox(parent, x, y, changed)
    local b = CreateFrame("CheckButton", nil, parent, "BackdropTemplate")
    b:SetPoint("TOPLEFT", x, y)
    b:SetSize(20, 20)
    W.Skin(b, { 0.035, 0.05, 0.065 })
    local mark = b:CreateTexture(nil, "OVERLAY")
    mark:SetAllPoints()
    mark:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    mark:SetVertexColor(0.35, 0.85, 1, 1)
    b.mark = mark
    function b:SetHighlightColor(value)
        self.highlightColor = value
        mark:SetVertexColor(unpack(value or { 0.35, 0.85, 1, 1 }))
        self:Paint(false)
    end
    b:SetCheckedTexture(mark)
    b:SetChecked(false)
    function b:Paint(hover)
        if self:GetChecked() then
            self:SetBackdropBorderColor(unpack(self.highlightColor or { 0.35, 0.85, 1, 1 }))
        elseif hover then
            self:SetBackdropBorderColor(0.60, 0.70, 0.78, 1)
        else
            self:SetBackdropBorderColor(unpack(W.colors.line))
        end
    end
    b:SetScript("OnClick", function(self)
        if changed then
            changed(self:GetChecked())
        end
        self:Paint(true)
    end)
    b:SetScript("OnEnter", function(self)
        self:Paint(true)
        if self.tip then
            W.Tooltip(self, self.tip)
        end
    end)
    b:SetScript("OnLeave", function(self)
        self:Paint(false)
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)
    return b
end

function W.Edit(parent, placeholder, x, y, width, changed, limit)
    local e = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
    e:SetPoint("TOPLEFT", x, y)
    e:SetSize(width, 28)
    W.Skin(e, { 0.055, 0.069, 0.085 })
    e:SetAutoFocus(false)
    e:SetFontObject(GameFontHighlight)
    e:SetTextInsets(10, 25, 0, 0)
    e:SetMaxLetters(limit or 160)
    e.placeholder = W.Text(e, placeholder, 10, -8, width - 35, 12, W.colors.muted)
    e.clear = W.Button(e, "x", width - 23, -3, 20, function()
        e:SetText("")
        e:ClearFocus()
    end, false, 22)
    e:SetScript("OnTextChanged", function(self, user)
        self.placeholder:SetShown(self:GetText() == "")
        self.clear:SetShown(not self.hideClear and self:GetText() ~= "")
        if changed then
            changed(self:GetText(), user)
        end
    end)
    e:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    e:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
    end)
    e:SetScript("OnHide", function(self)
        self:ClearFocus()
    end)
    e.clear:Hide()
    return e
end

function W.Scroll(parent, x, y, width, height)
    local s = CreateFrame("ScrollFrame", nil, parent)
    s:SetPoint("TOPLEFT", x, y)
    s:SetSize(width - 12, height)
    s:EnableMouseWheel(true)
    local content = CreateFrame("Frame", nil, s)
    content:SetSize(width - 12, height)
    s:SetScrollChild(content)
    s.content, s.viewport, s.offset = content, height, 0
    local slider = CreateFrame("Slider", nil, parent)
    slider:SetPoint("TOPLEFT", x + width - 8, y)
    slider:SetSize(5, height)
    slider:SetOrientation("VERTICAL")
    slider:SetMinMaxValues(0, 1)
    slider:SetValueStep(24)
    slider:SetThumbTexture("Interface\\Buttons\\WHITE8X8")
    local thumb = slider:GetThumbTexture()
    thumb:SetSize(5, 40)
    thumb:SetVertexColor(0.38, 0.47, 0.53, 0.85)
    s.slider = slider
    function s:ScrollTo(value)
        self.offset = math.max(0, math.min(self.maximum or 0, value))
        self:SetVerticalScroll(self.offset)
        if slider:GetValue() ~= self.offset then
            slider:SetValue(self.offset)
        end
    end
    function s:Resize(w, h)
        height, self.viewport = h, h
        self:SetSize(w - 12, h)
        content:SetWidth(w - 12)
        slider:SetHeight(h)
        slider:ClearAllPoints()
        slider:SetPoint("TOPLEFT", self, "TOPRIGHT", 4, 0)
        self:SetContentHeight(content:GetHeight())
    end
    function s:SetContentHeight(h)
        content:SetHeight(math.max(height, h))
        self.maximum = math.max(0, h - height)
        slider:SetMinMaxValues(0, math.max(1, self.maximum))
        slider:SetShown(self.maximum > 0)
        self:ScrollTo(self.offset)
    end
    s:SetScript("OnMouseWheel", function(self, delta)
        self:ScrollTo(self.offset - delta * 42)
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)
    slider:SetScript("OnValueChanged", function(_, value)
        s:ScrollTo(value)
    end)
    return s
end

function W.Line(parent, x1, y1, x2, y2, c, thickness)
    if parent.CreateLine then
        local l = parent:CreateLine(nil, "ARTWORK")
        l:SetStartPoint("TOPLEFT", x1, -y1)
        l:SetEndPoint("TOPLEFT", x2, -y2)
        l:SetThickness(thickness or 2)
        l:SetColorTexture(color(c or W.colors.line))
        return l
    end
    local t = parent:CreateTexture(nil, "ARTWORK")
    t:SetPoint("TOPLEFT", math.min(x1, x2), -math.min(y1, y2))
    t:SetSize(
        math.max(thickness or 2, math.abs(x2 - x1)),
        math.max(thickness or 2, math.abs(y2 - y1))
    )
    t:SetColorTexture(color(c or W.colors.line))
    return t
end

function W.PooledLine(pool, index, parent, x1, y1, x2, y2, c)
    local line = pool[index]
    if not line then
        line = W.Line(parent, x1, y1, x2, y2, c)
        pool[index] = line
    else
        if line.SetStartPoint then
            line:SetStartPoint("TOPLEFT", x1, -y1)
            line:SetEndPoint("TOPLEFT", x2, -y2)
        else
            line:ClearAllPoints()
            line:SetPoint("TOPLEFT", math.min(x1, x2), -math.min(y1, y2))
            line:SetSize(math.max(2, math.abs(x2 - x1)), math.max(2, math.abs(y2 - y1)))
        end
        line:SetColorTexture(unpack(c or W.colors.line))
        line:Show()
    end
    return line
end

function W.Menu(anchor, options, width)
    local f = FT.UI.menu
    if not f then
        f = CreateFrame("Frame", nil, FT.UI.frame, "BackdropTemplate")
        f:SetFrameStrata("TOOLTIP")
        f:SetFrameLevel(100)
        f:SetClampedToScreen(true)
        W.Skin(f, { 0.065, 0.080, 0.097 })
        f:EnableMouse(true)
        f.rows = {}
        local dismiss = CreateFrame("Button", nil, FT.UI.frame)
        dismiss:SetAllPoints()
        dismiss:SetFrameStrata("TOOLTIP")
        dismiss:SetFrameLevel(99)
        dismiss:SetScript("OnClick", function()
            f:Hide()
        end)
        f.dismiss = dismiss
        f:SetScript("OnHide", function()
            dismiss:Hide()
        end)
        FT.UI.menu = f
    end
    for _, row in ipairs(f.rows) do
        row:Hide()
    end
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -3)
    f:SetSize(width or 220, #options * 30 + 8)
    for i, option in ipairs(options) do
        local b = f.rows[i]
        if not b then
            b = W.Button(f, "", 4, -4 - (i - 1) * 30, (width or 220) - 8)
            f.rows[i] = b
        end
        b:SetWidth((width or 220) - 8)
        b:SetText(option.text)
        b:SetEnabled(option.enabled ~= false)
        b:Show()
        b:SetScript("OnClick", function()
            f:Hide()
            option.action()
        end)
        b.tip = option.tip
    end
    f.dismiss:Show()
    f:Show()
    return f
end

function W.Result(ok, why)
    if not ok and why then
        FT.UI.Status(why, true)
    end
    return ok
end
