local ADDON_NAME, LWT = ...

-- =========================================================
-- Dimensions & Colors
-- =========================================================
local PANEL_WIDTH = 600
local PANEL_HEIGHT = 500
local SIDEBAR_WIDTH = 140

local FLAT = "Interface\\Buttons\\WHITE8x8"
local BG_COLOR = { 0.05, 0.05, 0.07, 0.92 }
local BORDER_COLOR = { 0.15, 0.15, 0.18, 1 }
local SIDEBAR_BG = { 0.04, 0.04, 0.06, 1 }
local SIDEBAR_SEL = { 1, 0.82, 0, 0.08 }
local SIDEBAR_HL = { 1, 1, 1, 0.03 }
local ACCENT = { 1, 0.82, 0 }
local TEXT_DIM = { 0.55, 0.55, 0.55 }
local HEADER_COLOR = { 1, 0.82, 0 }

-- =========================================================
-- Flat backdrop helper
-- =========================================================
local function FlatBackdrop(frame, bg, border)
    frame:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1 })
    frame:SetBackdropColor(unpack(bg or BG_COLOR))
    frame:SetBackdropBorderColor(unpack(border or BORDER_COLOR))
end

-- =========================================================
-- Widget: Flat button
-- =========================================================
local function CreateButton(name, parent, width, height)
    local btn = CreateFrame("Button", name, parent, "BackdropTemplate")
    btn:SetSize(width, height)
    FlatBackdrop(btn, { 0.12, 0.12, 0.14, 1 }, { 0.25, 0.25, 0.28, 1 })

    btn.text = btn:CreateFontString(nil, "OVERLAY", "LWT_Body")
    btn.text:SetPoint("CENTER")

    btn.SetText = function(self, str) self.text:SetText(str) end
    btn.GetText = function(self) return self.text:GetText() end

    btn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.18, 0.18, 0.20, 1)
        self:SetBackdropBorderColor(0.4, 0.4, 0.45, 1)
    end)
    btn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.12, 0.12, 0.14, 1)
        self:SetBackdropBorderColor(0.25, 0.25, 0.28, 1)
    end)

    return btn
end

-- =========================================================
-- Widget: Flat checkbox (custom drawn)
-- =========================================================
local checkboxCount = 0
local function CreateCheckbox(parent, label, x, y, getFunc, setFunc)
    checkboxCount = checkboxCount + 1

    local btn = CreateFrame("Button", "LWT_Check_" .. checkboxCount, parent)
    btn:SetSize(200, 20)
    btn:SetPoint("TOPLEFT", x, y)

    -- Box
    local box = CreateFrame("Frame", nil, btn, "BackdropTemplate")
    box:SetSize(16, 16)
    box:SetPoint("LEFT", 0, 0)
    FlatBackdrop(box, { 0.08, 0.08, 0.10, 1 }, { 0.3, 0.3, 0.35, 1 })
    btn.box = box

    -- Checkmark
    local check = box:CreateTexture(nil, "OVERLAY")
    check:SetSize(12, 12)
    check:SetPoint("CENTER")
    check:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 1)
    check:Hide()
    btn.check = check

    -- Label
    local text = btn:CreateFontString(nil, "OVERLAY", "LWT_Body")
    text:SetPoint("LEFT", box, "RIGHT", 6, 0)
    text:SetText(label)
    btn.label = text

    local function Refresh()
        if getFunc() then
            check:Show()
            box:SetBackdropBorderColor(ACCENT[1], ACCENT[2], ACCENT[3], 0.6)
        else
            check:Hide()
            box:SetBackdropBorderColor(0.3, 0.3, 0.35, 1)
        end
    end

    btn:SetScript("OnShow", Refresh)
    btn:SetScript("OnClick", function()
        setFunc(not getFunc())
        Refresh()
    end)

    btn:SetScript("OnEnter", function()
        box:SetBackdropColor(0.12, 0.12, 0.15, 1)
    end)
    btn:SetScript("OnLeave", function()
        box:SetBackdropColor(0.08, 0.08, 0.10, 1)
    end)

    return btn
end

-- =========================================================
-- Widget: Flat slider
-- =========================================================
local sliderCount = 0
local function CreateSlider(parent, label, x, y, minVal, maxVal, step, getFunc, setFunc)
    sliderCount = sliderCount + 1

    local wrapper = CreateFrame("Frame", nil, parent)
    wrapper:SetSize(280, 40)
    wrapper:SetPoint("TOPLEFT", x, y)

    local title = wrapper:CreateFontString(nil, "OVERLAY", "LWT_Body")
    title:SetPoint("TOPLEFT", 0, 0)
    title:SetText(label)

    local valueText = wrapper:CreateFontString(nil, "OVERLAY", "LWT_Body")
    valueText:SetPoint("TOPRIGHT", 0, 0)
    valueText:SetTextColor(ACCENT[1], ACCENT[2], ACCENT[3])

    local slider = CreateFrame("Slider", "LWT_Slider_" .. sliderCount, wrapper, "BackdropTemplate")
    slider:SetSize(280, 16)
    slider:SetPoint("TOPLEFT", 0, -14)
    FlatBackdrop(slider, { 0.08, 0.08, 0.10, 1 }, { 0.25, 0.25, 0.28, 1 })
    slider:SetOrientation("HORIZONTAL")
    slider:EnableMouse(true)
    slider:SetMinMaxValues(minVal, maxVal)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)
    slider:SetHitRectInsets(0, 0, -6, -6)

    -- Thumb
    local thumb = slider:CreateTexture(nil, "OVERLAY")
    thumb:SetSize(14, 18)
    thumb:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 0.9)
    slider:SetThumbTexture(thumb)

    slider:SetScript("OnShow", function(self)
        local val = getFunc()
        self:SetValue(val)
        valueText:SetText(val)
    end)
    slider:SetScript("OnValueChanged", function(self, val)
        val = math.floor(val / step + 0.5) * step
        valueText:SetText(val)
        setFunc(val)
    end)

    -- Mouse wheel support
    slider:EnableMouseWheel(true)
    slider:SetScript("OnMouseWheel", function(self, delta)
        local val = self:GetValue() + (delta * step)
        val = math.max(minVal, math.min(maxVal, val))
        self:SetValue(val)
    end)

    return wrapper
end

-- =========================================================
-- Widget: Flat dropdown picker
-- =========================================================
local pickerCount = 0
local activePicker = nil

local function CreateDropdown(parent, label, x, y, getItemsFunc, getFunc, setFunc)
    pickerCount = pickerCount + 1
    local id = pickerCount

    local wrapper = CreateFrame("Frame", nil, parent)
    wrapper:SetSize(280, 38)
    wrapper:SetPoint("TOPLEFT", x, y)

    local title = wrapper:CreateFontString(nil, "OVERLAY", "LWT_Body")
    title:SetPoint("TOPLEFT", 0, 0)
    title:SetText(label)

    local btn = CreateFrame("Button", "LWT_Drop_" .. id, wrapper, "BackdropTemplate")
    btn:SetSize(280, 22)
    btn:SetPoint("TOPLEFT", 0, -14)
    FlatBackdrop(btn, { 0.08, 0.08, 0.10, 1 }, { 0.25, 0.25, 0.28, 1 })

    btn.text = btn:CreateFontString(nil, "OVERLAY", "LWT_Body")
    btn.text:SetPoint("LEFT", 8, 0)
    btn.text:SetPoint("RIGHT", -20, 0)
    btn.text:SetJustifyH("LEFT")

    -- Arrow
    local arrow = btn:CreateFontString(nil, "OVERLAY", "LWT_Body")
    arrow:SetPoint("RIGHT", -6, 0)
    arrow:SetText("v")
    arrow:SetTextColor(0.5, 0.5, 0.5)

    -- Popup
    local popup = CreateFrame("Frame", "LWT_DropPopup_" .. id, UIParent, "BackdropTemplate")
    popup:SetSize(280, 200)
    FlatBackdrop(popup, { 0.06, 0.06, 0.08, 0.98 }, BORDER_COLOR)
    popup:SetFrameStrata("FULLSCREEN_DIALOG")
    popup:SetClampedToScreen(true)
    popup:Hide()

    local scrollFrame = CreateFrame("ScrollFrame", "LWT_DropScroll_" .. id, popup, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 2, -2)
    scrollFrame:SetPoint("BOTTOMRIGHT", -20, 2)

    local scrollChild = CreateFrame("Frame", "LWT_DropChild_" .. id, scrollFrame)
    scrollChild:SetWidth(256)
    scrollFrame:SetScrollChild(scrollChild)

    local rowPool = {}

    local function Populate()
        for _, row in ipairs(rowPool) do row:Hide() end
        if not LWT.db then return end
        local items = getItemsFunc()
        local current = getFunc()
        local rowHeight = 20

        for i, item in ipairs(items) do
            local row = rowPool[i]
            if not row then
                row = CreateFrame("Button", nil, scrollChild)
                row:SetHeight(rowHeight)
                row:SetPoint("TOPLEFT", 0, -(i - 1) * rowHeight)
                row:SetPoint("RIGHT")

                row.text = row:CreateFontString(nil, "OVERLAY", "LWT_Body")
                row.text:SetPoint("LEFT", 8, 0)
                row.text:SetPoint("RIGHT", -8, 0)
                row.text:SetJustifyH("LEFT")

                row.hl = row:CreateTexture(nil, "HIGHLIGHT")
                row.hl:SetAllPoints()
                row.hl:SetColorTexture(1, 1, 1, 0.06)

                row.sel = row:CreateTexture(nil, "BACKGROUND")
                row.sel:SetAllPoints()
                row.sel:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 0.12)

                rowPool[i] = row
            end

            row.text:SetText(item.name)
            row.sel:SetShown(item.name == current)

            row:SetScript("OnClick", function()
                setFunc(item.name)
                btn.text:SetText(item.name)
                popup:Hide()
                activePicker = nil
            end)

            row:Show()
        end

        scrollChild:SetHeight(#items * rowHeight)
    end

    btn:SetScript("OnClick", function()
        if activePicker and activePicker ~= popup then
            activePicker:Hide()
        end
        if popup:IsShown() then
            popup:Hide()
            activePicker = nil
        else
            popup:ClearAllPoints()
            popup:SetPoint("TOPLEFT", btn, "BOTTOMLEFT", 0, -1)
            Populate()
            popup:Show()
            activePicker = popup
        end
    end)

    btn:SetScript("OnShow", function()
        btn.text:SetText(getFunc() or "Default")
    end)

    btn:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(0.4, 0.4, 0.45, 1)
    end)
    btn:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(0.25, 0.25, 0.28, 1)
    end)

    parent:HookScript("OnHide", function()
        popup:Hide()
        activePicker = nil
    end)

    return wrapper
end

-- =========================================================
-- Widget: Color picker
-- =========================================================
local colorPickerCount = 0
local function CreateColorPicker(parent, label, x, y, getFunc, setFunc)
    colorPickerCount = colorPickerCount + 1

    local wrapper = CreateFrame("Frame", nil, parent)
    wrapper:SetSize(280, 24)
    wrapper:SetPoint("TOPLEFT", x, y)

    local title = wrapper:CreateFontString(nil, "OVERLAY", "LWT_Body")
    title:SetPoint("LEFT", 0, 0)
    title:SetText(label)

    local swatch = CreateFrame("Button", "LWT_ColorSwatch_" .. colorPickerCount, wrapper, "BackdropTemplate")
    swatch:SetSize(20, 16)
    swatch:SetPoint("LEFT", title, "RIGHT", 8, 0)
    FlatBackdrop(swatch, { 0.08, 0.08, 0.10, 1 }, { 0.3, 0.3, 0.35, 1 })

    local color = swatch:CreateTexture(nil, "OVERLAY")
    color:SetPoint("TOPLEFT", 2, -2)
    color:SetPoint("BOTTOMRIGHT", -2, 2)
    swatch.color = color

    local function Refresh()
        if not LWT.db then return end
        local c = getFunc()
        color:SetColorTexture(c.r or 1, c.g or 1, c.b or 1)
    end

    swatch:SetScript("OnShow", Refresh)
    swatch:SetScript("OnClick", function()
        if not LWT.db then return end
        local c = getFunc()
        local info = {}
        info.r = c.r or 1
        info.g = c.g or 1
        info.b = c.b or 1
        info.swatchFunc = function()
            local r, g, b = ColorPickerFrame:GetColorRGB()
            setFunc({ r = r, g = g, b = b })
            Refresh()
        end
        info.cancelFunc = function()
            setFunc({ r = info.r, g = info.g, b = info.b })
            Refresh()
        end
        ColorPickerFrame:SetupColorPickerAndShow(info)
    end)

    Refresh()
    return wrapper
end

-- =========================================================
-- Widget: Section header
-- =========================================================
local function CreateHeader(parent, text, x, y)
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", x, y - 6)
    line:SetPoint("RIGHT", parent, "RIGHT", -8, 0)
    line:SetColorTexture(HEADER_COLOR[1], HEADER_COLOR[2], HEADER_COLOR[3], 0.2)

    local label = parent:CreateFontString(nil, "OVERLAY", "LWT_Heading")
    label:SetPoint("TOPLEFT", x, y - 10)
    label:SetText(text)
    label:SetTextColor(HEADER_COLOR[1], HEADER_COLOR[2], HEADER_COLOR[3])

    return label
end

-- =========================================================
-- Main frame
-- =========================================================
local settingsFrame = CreateFrame("Frame", "LWT_SettingsFrame", UIParent, "BackdropTemplate")
settingsFrame:SetSize(PANEL_WIDTH, PANEL_HEIGHT)
settingsFrame:SetPoint("CENTER")
FlatBackdrop(settingsFrame, BG_COLOR, BORDER_COLOR)
settingsFrame:SetMovable(true)
settingsFrame:EnableMouse(true)
settingsFrame:RegisterForDrag("LeftButton")
settingsFrame:SetClampedToScreen(true)
settingsFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
settingsFrame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
settingsFrame:SetFrameStrata("DIALOG")
settingsFrame:Hide()

tinsert(UISpecialFrames, "LWT_SettingsFrame")

-- Title bar
local titleBar = CreateFrame("Frame", nil, settingsFrame)
titleBar:SetHeight(28)
titleBar:SetPoint("TOPLEFT", 1, -1)
titleBar:SetPoint("TOPRIGHT", -1, -1)

local titleBg = titleBar:CreateTexture(nil, "BACKGROUND")
titleBg:SetAllPoints()
titleBg:SetColorTexture(0.08, 0.08, 0.10, 1)

local title = titleBar:CreateFontString("LWT_SettingsTitle", "OVERLAY", "LWT_Title")
title:SetPoint("LEFT", 12, 0)
title:SetText("LuckyWipeTools")
title:SetTextColor(ACCENT[1], ACCENT[2], ACCENT[3])

-- Close button
local closeBtn = CreateFrame("Button", "LWT_SettingsCloseBtn", titleBar)
closeBtn:SetSize(28, 28)
closeBtn:SetPoint("RIGHT", -2, 0)
closeBtn.text = closeBtn:CreateFontString(nil, "OVERLAY", "LWT_Title")
closeBtn.text:SetPoint("CENTER", 0, 0)
closeBtn.text:SetText("x")
closeBtn.text:SetTextColor(0.5, 0.5, 0.5)
closeBtn:SetScript("OnEnter", function(self) self.text:SetTextColor(1, 0.3, 0.3) end)
closeBtn:SetScript("OnLeave", function(self) self.text:SetTextColor(0.5, 0.5, 0.5) end)
closeBtn:SetScript("OnClick", function() settingsFrame:Hide() end)

-- =========================================================
-- Sidebar
-- =========================================================
local sidebar = CreateFrame("Frame", "LWT_Sidebar", settingsFrame, "BackdropTemplate")
sidebar:SetPoint("TOPLEFT", 1, -29)
sidebar:SetPoint("BOTTOMLEFT", 1, 1)
sidebar:SetWidth(SIDEBAR_WIDTH)
sidebar:SetBackdrop({ bgFile = FLAT })
sidebar:SetBackdropColor(unpack(SIDEBAR_BG))

-- Separator
local sep = settingsFrame:CreateTexture("LWT_SidebarSep", "ARTWORK")
sep:SetWidth(1)
sep:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 0, 0)
sep:SetPoint("BOTTOMLEFT", sidebar, "BOTTOMRIGHT", 0, 0)
sep:SetColorTexture(BORDER_COLOR[1], BORDER_COLOR[2], BORDER_COLOR[3], 1)

-- =========================================================
-- Page system
-- =========================================================
local pages = {}
local sidebarButtons = {}
local currentPage = nil
local currentKey = nil

local CONTENT_WIDTH = PANEL_WIDTH - SIDEBAR_WIDTH - 24
local CONTENT_HEIGHT = PANEL_HEIGHT - 30

local function CreatePage(key)
    local container = CreateFrame("Frame", "LWT_Page_" .. key, settingsFrame)
    container:SetPoint("TOPLEFT", sep, "TOPRIGHT", 8, -8)
    container:SetSize(CONTENT_WIDTH + 8, CONTENT_HEIGHT - 8)
    container:Hide()

    local scroll = CreateFrame("ScrollFrame", "LWT_PageScroll_" .. key, container, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 0, 0)
    scroll:SetPoint("BOTTOMRIGHT", -24, 0)

    local content = CreateFrame("Frame", "LWT_PageContent_" .. key, scroll)
    content:SetWidth(CONTENT_WIDTH - 8)
    scroll:SetScrollChild(content)

    container.content = content
    container.scroll = scroll
    container.SetContentHeight = function(_, h)
        content:SetHeight(math.max(h, CONTENT_HEIGHT - 8))
    end

    pages[key] = container
    return container
end

local function ShowPage(key)
    if currentPage then currentPage:Hide() end
    currentPage = pages[key]
    currentKey = key
    if currentPage then currentPage:Show() end
    for k, btn in pairs(sidebarButtons) do
        if k == key then
            btn.bg:SetColorTexture(SIDEBAR_SEL[1], SIDEBAR_SEL[2], SIDEBAR_SEL[3], SIDEBAR_SEL[4])
            btn.text:SetTextColor(ACCENT[1], ACCENT[2], ACCENT[3])
            btn.indicator:Show()
        else
            btn.bg:SetColorTexture(0, 0, 0, 0)
            btn.text:SetTextColor(0.7, 0.7, 0.7)
            btn.indicator:Hide()
        end
    end
end

local sidebarY = 4
local function AddSidebarButton(key, label)
    local btn = CreateFrame("Button", "LWT_SideBtn_" .. key, sidebar)
    btn:SetSize(SIDEBAR_WIDTH, 26)
    btn:SetPoint("TOPLEFT", 0, -sidebarY)

    btn.bg = btn:CreateTexture(nil, "BACKGROUND")
    btn.bg:SetAllPoints()
    btn.bg:SetColorTexture(0, 0, 0, 0)

    -- Left accent indicator
    btn.indicator = btn:CreateTexture(nil, "OVERLAY")
    btn.indicator:SetSize(2, 16)
    btn.indicator:SetPoint("LEFT", 2, 0)
    btn.indicator:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 1)
    btn.indicator:Hide()

    btn.text = btn:CreateFontString(nil, "OVERLAY", "LWT_Body")
    btn.text:SetPoint("LEFT", 12, 0)
    btn.text:SetText(label)
    btn.text:SetJustifyH("LEFT")
    btn.text:SetTextColor(0.7, 0.7, 0.7)

    btn:SetScript("OnEnter", function(self)
        if currentKey ~= key then
            self.bg:SetColorTexture(SIDEBAR_HL[1], SIDEBAR_HL[2], SIDEBAR_HL[3], SIDEBAR_HL[4])
        end
    end)
    btn:SetScript("OnLeave", function(self)
        if currentKey ~= key then
            self.bg:SetColorTexture(0, 0, 0, 0)
        end
    end)
    btn:SetScript("OnClick", function() ShowPage(key) end)

    sidebarButtons[key] = btn
    sidebarY = sidebarY + 26
    return btn
end

-- =========================================================
-- Helper: Add alert display settings to a page
-- =========================================================
local function AddAlertDisplayWidgets(c, y, dbFunc, alertSystemFunc, testText, prefix, opts)
    opts = opts or {}
    CreateHeader(c, "Display", 4, y)
    y = y - 24

    if not opts.noDuration then
        CreateSlider(c, "Duration (seconds)", 8, y, 1, 10, 0.5,
            function() return dbFunc().duration end,
            function(val) dbFunc().duration = val end
        )
        y = y - 52
    end

    CreateSlider(c, "Font Size", 8, y, 16, 72, 2,
        function() return dbFunc().fontSize end,
        function(val)
            dbFunc().fontSize = val
            local sys = alertSystemFunc()
            if sys then sys:UpdateFont() end
        end
    )
    y = y - 52

    CreateColorPicker(c, "Color", 8, y,
        function() return dbFunc().color or { r = 1, g = 0.82, b = 0 } end,
        function(val)
            dbFunc().color = val
            local sys = alertSystemFunc()
            if sys then sys:UpdateFont() end
        end
    )
    y = y - 30

    CreateDropdown(c, "Font", 8, y,
        function() return LWT:GetFontList() end,
        function() return dbFunc().fontName end,
        function(name)
            dbFunc().fontName = name
            local sys = alertSystemFunc()
            if sys then sys:UpdateFont() end
        end
    )
    y = y - 48

    CreateDropdown(c, "Sound", 8, y,
        function() return LWT:GetSoundList() end,
        function() return dbFunc().soundName or "None" end,
        function(name)
            local db = dbFunc()
            if name == "None" then
                db.sound = false
                db.soundName = nil
            else
                db.sound = true
                db.soundName = name
            end
            -- Preview sound
            if db.sound and db.soundName then
                local sounds = LWT:GetSoundList()
                for _, entry in ipairs(sounds) do
                    if entry.name == db.soundName and entry.path then
                        PlaySoundFile(entry.path, "Master")
                        break
                    end
                end
            end
        end
    )
    y = y - 56

    CreateHeader(c, "Position", 4, y)
    y = y - 24

    local moverActive = false
    local moveBtn = CreateButton("LWT_" .. prefix .. "MoveBtn", c, 130, 24)
    moveBtn:SetPoint("TOPLEFT", 8, y)
    moveBtn:SetText("Unlock Position")

    local testBtn = CreateButton("LWT_" .. prefix .. "TestBtn", c, 130, 24)
    testBtn:SetPoint("LEFT", moveBtn, "RIGHT", 8, 0)
    testBtn:SetText("Test")

    moveBtn:SetScript("OnClick", function()
        local sys = alertSystemFunc()
        if not sys then return end
        if moverActive then
            sys:DisableMover()
            moveBtn:SetText("Unlock Position")
            moverActive = false
        else
            sys:EnableMover()
            moveBtn:SetText("Lock Position")
            moverActive = true
        end
    end)

    testBtn:SetScript("OnClick", function()
        local sys = alertSystemFunc()
        if not sys then return end
        if moverActive then
            sys:DisableMover()
            moveBtn:SetText("Unlock Position")
            moverActive = false
        end
        sys:Fire(testText)
    end)

    y = y - 34

    -- Returns y and a cleanup function for OnHide
    return y, function()
        if moverActive then
            local sys = alertSystemFunc()
            if sys then sys:DisableMover() end
            moveBtn:SetText("Unlock Position")
            moverActive = false
        end
    end
end

-- =========================================================
-- Page: Gateway
-- =========================================================
AddSidebarButton("gateway", "Gateway")
local gatewayPage = CreatePage("gateway")
do
    local c = gatewayPage.content
    local y = -4

    local desc = c:CreateFontString(nil, "OVERLAY", "LWT_Body")
    desc:SetPoint("TOPLEFT", 8, y)
    desc:SetWidth(CONTENT_WIDTH - 24)
    desc:SetJustifyH("LEFT")
    desc:SetText("Shows a persistent alert while your Demonic Gateway is ready to use.")
    desc:SetTextColor(TEXT_DIM[1], TEXT_DIM[2], TEXT_DIM[3])
    y = y - (desc:GetStringHeight() + 14)

    -- Item check warning
    local noItemWarning = c:CreateFontString(nil, "OVERLAY", "LWT_Body")
    noItemWarning:SetPoint("TOPLEFT", 8, y)
    noItemWarning:SetWidth(CONTENT_WIDTH - 24)
    noItemWarning:SetJustifyH("LEFT")
    noItemWarning:SetText("|cffff9900You don't have a Gateway Shard in your inventory.|r")
    noItemWarning:Hide()

    gatewayPage:HookScript("OnShow", function()
        if LWT.HasGatewayItem and not LWT:HasGatewayItem() then
            noItemWarning:Show()
        else
            noItemWarning:Hide()
        end
    end)

    y = y - (noItemWarning:GetStringHeight() + 10)

    CreateCheckbox(c, "Enable", 4, y,
        function() return LWT.db.gateway.enabled end,
        function(val)
            LWT.db.gateway.enabled = val
            LWT:RefreshGateway()
        end
    )
    y = y - 26

    CreateCheckbox(c, "Combat only", 4, y,
        function() return LWT.db.gateway.combatOnly end,
        function(val)
            LWT.db.gateway.combatOnly = val
            LWT:RefreshGateway()
        end
    )
    y = y - 30

    local endY, gatewayCleanup = AddAlertDisplayWidgets(
        c, y,
        function() return LWT.db.gateway.alert end,
        function() return LWT.gatewayAlert end,
        "|cff9b59b6GATEWAY READY|r",
        "Gateway",
        { noDuration = true }
    )
    y = endY

    gatewayPage:HookScript("OnHide", gatewayCleanup)
    gatewayPage:SetContentHeight(math.abs(y) + 10)
end

-- =========================================================
-- Page: Summon Helper
-- =========================================================
AddSidebarButton("summon", "Summon Helper")
local summonPage = CreatePage("summon")
do
    local c = summonPage.content
    local y = -4

    local desc = c:CreateFontString(nil, "OVERLAY", "LWT_Body")
    desc:SetPoint("TOPLEFT", 8, y)
    desc:SetWidth(CONTENT_WIDTH - 24)
    desc:SetJustifyH("LEFT")
    desc:SetText("Tracks summoning portal placement and summon status for raid members. Shows a roster of players outside your zone.")
    desc:SetTextColor(TEXT_DIM[1], TEXT_DIM[2], TEXT_DIM[3])
    y = y - (desc:GetStringHeight() + 14)

    CreateCheckbox(c, "Enable", 4, y,
        function() return LWT.db.summon.enabled end,
        function(val) LWT.db.summon.enabled = val end
    )
    y = y - 30

    CreateHeader(c, "Notifications", 4, y)
    y = y - 24

    CreateCheckbox(c, "Portal placed", 4, y,
        function()
            return not LWT.db.summon or LWT.db.summon.showPortalPlaced ~= false
        end,
        function(val)
            LWT.db.summon = LWT.db.summon or {}
            LWT.db.summon.showPortalPlaced = val
        end
    )
    y = y - 24

    CreateCheckbox(c, "Accepted / Declined", 4, y,
        function()
            return not LWT.db.summon or LWT.db.summon.showStatus ~= false
        end,
        function(val)
            LWT.db.summon = LWT.db.summon or {}
            LWT.db.summon.showStatus = val
        end
    )
    y = y - 30

    CreateHeader(c, "Outside Roster", 4, y)
    y = y - 24

    CreateCheckbox(c, "Show roster frame", 4, y,
        function()
            return not LWT.db.summon or LWT.db.summon.showRoster ~= false
        end,
        function(val)
            LWT.db.summon = LWT.db.summon or {}
            LWT.db.summon.showRoster = val
        end
    )
    y = y - 30

    CreateHeader(c, "Roster Position", 4, y)
    y = y - 24

    local rosterMoverActive = false
    local rosterMoveBtn = CreateButton("LWT_RosterMoveBtn", c, 130, 24)
    rosterMoveBtn:SetPoint("TOPLEFT", 8, y)
    rosterMoveBtn:SetText("Unlock Position")

    rosterMoveBtn:SetScript("OnClick", function()
        if rosterMoverActive then
            LWT:DisableRosterMover()
            rosterMoveBtn:SetText("Unlock Position")
            rosterMoverActive = false
        else
            LWT:EnableRosterMover()
            rosterMoveBtn:SetText("Lock Position")
            rosterMoverActive = true
        end
    end)

    y = y - 34

    local endY, summonCleanup = AddAlertDisplayWidgets(
        c, y,
        function() return LWT.db.summon.alert end,
        function() return LWT.summonAlert end,
        "|cff9b59b6Portal placed! Click to summon|r",
        "Summon"
    )
    y = endY

    summonPage:HookScript("OnHide", function()
        if rosterMoverActive then
            LWT:DisableRosterMover()
            rosterMoveBtn:SetText("Unlock Position")
            rosterMoverActive = false
        end
        summonCleanup()
    end)

    summonPage:SetContentHeight(math.abs(y) + 10)
end

-- =========================================================
-- Page: Vantus Runes
-- =========================================================
AddSidebarButton("vantus", "Vantus Runes")
local vantusPage = CreatePage("vantus")
do
    local c = vantusPage.content
    local y = -4

    local desc = c:CreateFontString(nil, "OVERLAY", "LWT_Body")
    desc:SetPoint("TOPLEFT", 8, y)
    desc:SetWidth(CONTENT_WIDTH - 24)
    desc:SetJustifyH("LEFT")
    desc:SetText("Request and distribute vantus runes in raid. Players type /lwt vantus to request. Distributors see a roster and click to trade.")
    desc:SetTextColor(TEXT_DIM[1], TEXT_DIM[2], TEXT_DIM[3])
    y = y - (desc:GetStringHeight() + 14)

    CreateCheckbox(c, "Enable", 4, y,
        function() return LWT.db.vantus.enabled end,
        function(val) LWT.db.vantus.enabled = val end
    )
    y = y - 30

    CreateHeader(c, "Difficulties", 4, y)
    y = y - 24

    CreateCheckbox(c, "Heroic", 16, y,
        function() return LWT.db.vantus.difficulties.heroic end,
        function(val) LWT.db.vantus.difficulties.heroic = val end
    )
    y = y - 24

    CreateCheckbox(c, "Mythic", 16, y,
        function() return LWT.db.vantus.difficulties.mythic end,
        function(val) LWT.db.vantus.difficulties.mythic = val end
    )
    y = y - 30

    CreateHeader(c, "Roster", 4, y)
    y = y - 24

    CreateCheckbox(c, "Show roster frame", 4, y,
        function() return LWT.db.vantus.showRoster end,
        function(val) LWT.db.vantus.showRoster = val end
    )
    y = y - 30

    CreateHeader(c, "Roster Position", 4, y)
    y = y - 24

    local vantusMoverActive = false
    local vantusMoveBtn = CreateButton("LWT_VantusMoveBtn", c, 130, 24)
    vantusMoveBtn:SetPoint("TOPLEFT", 8, y)
    vantusMoveBtn:SetText("Unlock Position")

    vantusMoveBtn:SetScript("OnClick", function()
        if vantusMoverActive then
            LWT:DisableVantusMover()
            vantusMoveBtn:SetText("Unlock Position")
            vantusMoverActive = false
        else
            LWT:EnableVantusMover()
            vantusMoveBtn:SetText("Lock Position")
            vantusMoverActive = true
        end
    end)

    y = y - 34

    local endY, vantusCleanup = AddAlertDisplayWidgets(
        c, y,
        function() return LWT.db.vantus.alert end,
        function() return LWT.vantusAlert end,
        "|cff00ff00Vantus rune requested.|r",
        "Vantus"
    )
    y = endY

    vantusPage:HookScript("OnHide", function()
        if vantusMoverActive then
            LWT:DisableVantusMover()
            vantusMoveBtn:SetText("Unlock Position")
            vantusMoverActive = false
        end
        vantusCleanup()
    end)

    vantusPage:SetContentHeight(math.abs(y) + 10)
end

-- =========================================================
-- Page: Consumables
-- =========================================================
AddSidebarButton("consumables", "Consumables")
local consumablesPage = CreatePage("consumables")
do
    local c = consumablesPage.content
    local y = -4

    local desc = c:CreateFontString(nil, "OVERLAY", "LWT_Body")
    desc:SetPoint("TOPLEFT", 8, y)
    desc:SetWidth(CONTENT_WIDTH - 24)
    desc:SetJustifyH("LEFT")
    desc:SetText("Notifies when a raid member places a feast or cauldron. Only triggers outside of combat in raid instances.")
    desc:SetTextColor(TEXT_DIM[1], TEXT_DIM[2], TEXT_DIM[3])
    y = y - (desc:GetStringHeight() + 14)

    CreateCheckbox(c, "Enable", 4, y,
        function() return LWT.db.consumables.enabled end,
        function(val) LWT.db.consumables.enabled = val end
    )
    y = y - 30

    local endY, consumablesCleanup = AddAlertDisplayWidgets(
        c, y,
        function() return LWT.db.consumables.alert end,
        function() return LWT.consumablesAlert end,
        "Playername placed Hearty Harandar Celebration",
        "Consumables"
    )
    y = endY

    consumablesPage:HookScript("OnHide", consumablesCleanup)
    consumablesPage:SetContentHeight(math.abs(y) + 10)
end

-- =========================================================
-- Page: Combat Log
-- =========================================================
AddSidebarButton("combatlog", "Combat Log")
local combatLogPage = CreatePage("combatlog")
do
    local c = combatLogPage.content
    local y = -4

    local desc = c:CreateFontString(nil, "OVERLAY", "LWT_Body")
    desc:SetPoint("TOPLEFT", 8, y)
    desc:SetWidth(CONTENT_WIDTH - 24)
    desc:SetJustifyH("LEFT")
    desc:SetText("Automatically starts and stops combat logging based on instance type and difficulty.")
    desc:SetTextColor(TEXT_DIM[1], TEXT_DIM[2], TEXT_DIM[3])
    y = y - (desc:GetStringHeight() + 14)

    CreateCheckbox(c, "Enable", 4, y,
        function() return LWT.db.combatLog.enabled end,
        function(val) LWT.db.combatLog.enabled = val end
    )
    y = y - 30

    CreateHeader(c, "Instance Types", 4, y)
    y = y - 24

    for _, itype in ipairs(LWT.combatLogInstanceTypes) do
        CreateCheckbox(c, itype.label, 16, y,
            function() return LWT.db.combatLog.instanceTypes[itype.key] end,
            function(val) LWT.db.combatLog.instanceTypes[itype.key] = val end
        )
        y = y - 24
    end

    y = y - 6
    CreateHeader(c, "Difficulties", 4, y)
    y = y - 24

    for _, diff in ipairs(LWT.combatLogDifficulties) do
        CreateCheckbox(c, diff.label, 16, y,
            function()
                local val = LWT.db.combatLog.difficulties[diff.key]
                if val == nil then return true end
                return val
            end,
            function(val) LWT.db.combatLog.difficulties[diff.key] = val end
        )
        y = y - 24
    end

    combatLogPage:SetContentHeight(math.abs(y) + 10)
end

-- =========================================================
-- Page: Item Splitter
-- =========================================================
AddSidebarButton("splitter", "Item Splitter")
local splitterPage = CreatePage("splitter")
do
    local c = splitterPage.content
    local y = -4

    local desc = c:CreateFontString(nil, "OVERLAY", "LWT_Body")
    desc:SetPoint("TOPLEFT", 8, y)
    desc:SetWidth(CONTENT_WIDTH - 24)
    desc:SetJustifyH("LEFT")
    desc:SetText("Split item stacks into smaller stacks for distribution. Works with personal bags and guild bank. A Split button also appears on the guild bank frame.")
    desc:SetTextColor(TEXT_DIM[1], TEXT_DIM[2], TEXT_DIM[3])
    y = y - (desc:GetStringHeight() + 14)

    CreateCheckbox(c, "Enable", 4, y,
        function() return LWT.db.itemSplitter.enabled end,
        function(val) LWT.db.itemSplitter.enabled = val end
    )
    y = y - 30

    CreateHeader(c, "Usage", 4, y)
    y = y - 24

    local usage = c:CreateFontString(nil, "OVERLAY", "LWT_Body")
    usage:SetPoint("TOPLEFT", 8, y)
    usage:SetWidth(CONTENT_WIDTH - 24)
    usage:SetJustifyH("LEFT")
    usage:SetText(
        "|cffffcc00/lwt split|r -- Open the splitter popup\n\n" ..
        "1. Drag an item stack onto the drop slot\n" ..
        "2. Enter the target stack size (e.g., 1 for individual items)\n" ..
        "3. Click Split to auto-split the entire stack\n\n" ..
        "A |cffffcc00Split|r button also appears on the guild bank frame."
    )
    usage:SetTextColor(0.7, 0.7, 0.7)
    y = y - (usage:GetStringHeight() + 14)

    local openBtn = CreateButton("LWT_OpenSplitter", c, 140, 26)
    openBtn:SetPoint("TOPLEFT", 8, y)
    openBtn:SetText("Open Splitter")
    openBtn:SetScript("OnClick", function()
        LWT:ToggleSplitter()
    end)
    y = y - 36

    splitterPage:SetContentHeight(math.abs(y) + 10)
end

-- =========================================================
-- Page: Focus Cast Bar
-- =========================================================
AddSidebarButton("focuscastbar", "Focus Cast Bar")
local fcbPage = CreatePage("focuscastbar")
do
    local c = fcbPage.content
    local y = -4

    local desc = c:CreateFontString(nil, "OVERLAY", "LWT_Body")
    desc:SetPoint("TOPLEFT", 8, y)
    desc:SetWidth(CONTENT_WIDTH - 24)
    desc:SetJustifyH("LEFT")
    desc:SetText("Tracks your focus target's casts. Bar color reflects whether your interrupt is ready.")
    desc:SetTextColor(TEXT_DIM[1], TEXT_DIM[2], TEXT_DIM[3])
    y = y - (desc:GetStringHeight() + 14)

    CreateCheckbox(c, "Enable", 4, y,
        function() return LWT.db.focusCastBar.enabled end,
        function(val)
            LWT.db.focusCastBar.enabled = val
        end
    )
    y = y - 26

    CreateCheckbox(c, "Unlock (show preview & allow moving/resizing)", 4, y,
        function() return not LWT.db.focusCastBar.locked end,
        function(val)
            LWT:SetFocusCastBarLocked(not val)
        end
    )
    y = y - 30

    -- APPEARANCE
    CreateHeader(c, "Appearance", 4, y)
    y = y - 24

    CreateSlider(c, "Bar Width", 8, y, 100, 500, 5,
        function() return LWT.db.focusCastBar.width or 250 end,
        function(val)
            LWT.db.focusCastBar.width = val
            LWT:UpdateFocusCastBar()
        end
    )
    y = y - 52

    CreateSlider(c, "Bar Height", 8, y, 12, 48, 1,
        function() return LWT.db.focusCastBar.height or 24 end,
        function(val)
            LWT.db.focusCastBar.height = val
            LWT:UpdateFocusCastBar()
        end
    )
    y = y - 52

    CreateColorPicker(c, "Ready Color", 8, y,
        function() return LWT.db.focusCastBar.barReadyColor end,
        function(val)
            LWT.db.focusCastBar.barReadyColor = val
            LWT:UpdateFocusCastBar()
        end
    )
    y = y - 30

    CreateColorPicker(c, "On Cooldown Color", 8, y,
        function() return LWT.db.focusCastBar.barCdColor end,
        function(val)
            LWT.db.focusCastBar.barCdColor = val
            LWT:UpdateFocusCastBar()
        end
    )
    y = y - 30

    CreateCheckbox(c, "Highlight Important Casts", 4, y,
        function() return LWT.db.focusCastBar.highlightImportant ~= false end,
        function(val) LWT.db.focusCastBar.highlightImportant = val end
    )
    y = y - 26

    CreateColorPicker(c, "Important Cast Color", 8, y,
        function() return LWT.db.focusCastBar.importantColor end,
        function(val)
            LWT.db.focusCastBar.importantColor = val
            LWT:UpdateFocusCastBar()
        end
    )
    y = y - 30

    CreateColorPicker(c, "Non-Interruptible Color", 8, y,
        function() return LWT.db.focusCastBar.nonIntColor end,
        function(val)
            LWT.db.focusCastBar.nonIntColor = val
            LWT:UpdateFocusCastBar()
        end
    )
    y = y - 30

    CreateColorPicker(c, "Background Color", 8, y,
        function() return LWT.db.focusCastBar.bgColor end,
        function(val)
            LWT.db.focusCastBar.bgColor = val
            LWT:UpdateFocusCastBar()
        end
    )
    y = y - 30

    CreateSlider(c, "Opacity", 8, y, 0, 100, 1,
        function() return math.floor((LWT.db.focusCastBar.bgAlpha or 0.8) * 100 + 0.5) end,
        function(val)
            LWT.db.focusCastBar.bgAlpha = val / 100
            LWT:UpdateFocusCastBar()
        end
    )
    y = y - 52

    CreateDropdown(c, "Bar Texture", 8, y,
        function()
            local items = {}
            local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
            if LSM then
                for _, name in ipairs(LSM:List("statusbar") or {}) do
                    table.insert(items, { name = name, path = name })
                end
            end
            return items
        end,
        function() return LWT.db.focusCastBar.barTexture or "Blizzard" end,
        function(val)
            LWT.db.focusCastBar.barTexture = val
            LWT:UpdateFocusCastBar()
        end
    )
    y = y - 40

    -- ICON & TEXT
    CreateHeader(c, "Icon & Text", 4, y)
    y = y - 24

    CreateCheckbox(c, "Show Icon", 4, y,
        function() return LWT.db.focusCastBar.showIcon ~= false end,
        function(val)
            LWT.db.focusCastBar.showIcon = val
            LWT:UpdateFocusCastBar()
        end
    )
    y = y - 26

    CreateCheckbox(c, "Show Spell Name", 4, y,
        function() return LWT.db.focusCastBar.showSpellName ~= false end,
        function(val)
            LWT.db.focusCastBar.showSpellName = val
            LWT:UpdateFocusCastBar()
        end
    )
    y = y - 26

    CreateCheckbox(c, "Show Time Remaining", 4, y,
        function() return LWT.db.focusCastBar.showTimeRemaining ~= false end,
        function(val)
            LWT.db.focusCastBar.showTimeRemaining = val
            LWT:UpdateFocusCastBar()
        end
    )
    y = y - 30

    CreateDropdown(c, "Font", 8, y,
        function() return LWT:GetFontList() end,
        function() return LWT.db.focusCastBar.fontName or "Roboto" end,
        function(name)
            LWT.db.focusCastBar.fontName = name
            LWT:UpdateFocusCastBar()
        end
    )
    y = y - 40

    CreateSlider(c, "Font Size", 8, y, 8, 24, 1,
        function() return LWT.db.focusCastBar.fontSize or 11 end,
        function(val)
            LWT.db.focusCastBar.fontSize = val
            LWT:UpdateFocusCastBar()
        end
    )
    y = y - 52

    -- BEHAVIOR
    CreateHeader(c, "Behavior", 4, y)
    y = y - 24

    CreateCheckbox(c, "Show Empower Stages", 4, y,
        function() return LWT.db.focusCastBar.showEmpowerStages ~= false end,
        function(val) LWT.db.focusCastBar.showEmpowerStages = val end
    )
    y = y - 26

    CreateCheckbox(c, "Hide Friendly Casts", 4, y,
        function() return LWT.db.focusCastBar.hideFriendlyCasts or false end,
        function(val) LWT.db.focusCastBar.hideFriendlyCasts = val end
    )
    y = y - 26

    CreateCheckbox(c, "Show Shield Icon (non-interruptible)", 4, y,
        function() return LWT.db.focusCastBar.showShieldIcon or false end,
        function(val)
            LWT.db.focusCastBar.showShieldIcon = val
            LWT:UpdateFocusCastBar()
        end
    )
    y = y - 26

    CreateCheckbox(c, "Color Non-Interruptible Casts", 4, y,
        function() return LWT.db.focusCastBar.colorNonInterrupt or false end,
        function(val) LWT.db.focusCastBar.colorNonInterrupt = val end
    )
    y = y - 26

    CreateCheckbox(c, "Hide When Kick On Cooldown", 4, y,
        function() return LWT.db.focusCastBar.hideOnCooldown or false end,
        function(val) LWT.db.focusCastBar.hideOnCooldown = val end
    )
    y = y - 26

    CreateCheckbox(c, "Show Interrupt Tick", 4, y,
        function() return LWT.db.focusCastBar.showInterruptTick ~= false end,
        function(val)
            LWT.db.focusCastBar.showInterruptTick = val
            LWT:UpdateFocusCastBar()
        end
    )
    y = y - 26

    CreateColorPicker(c, "Tick Color", 8, y,
        function() return LWT.db.focusCastBar.tickColor end,
        function(val)
            LWT.db.focusCastBar.tickColor = val
            LWT:UpdateFocusCastBar()
        end
    )
    y = y - 30

    -- ONLY SHOW IN
    CreateHeader(c, "Active In", 4, y)
    y = y - 24

    local function instanceGet(key, default)
        return function()
            local s = LWT.db.focusCastBar.showInInstances or {}
            if default then return s[key] ~= false end
            return s[key] or false
        end
    end
    local function instanceSet(key)
        return function(val)
            if not LWT.db.focusCastBar.showInInstances then
                LWT.db.focusCastBar.showInInstances = {}
            end
            LWT.db.focusCastBar.showInInstances[key] = val
        end
    end

    CreateCheckbox(c, "Dungeons & M+", 4, y, instanceGet("party", true), instanceSet("party"))
    y = y - 26
    CreateCheckbox(c, "Raids", 4, y, instanceGet("raid", true), instanceSet("raid"))
    y = y - 26
    CreateCheckbox(c, "Arenas", 4, y, instanceGet("arena", true), instanceSet("arena"))
    y = y - 26
    CreateCheckbox(c, "Battlegrounds", 4, y, instanceGet("pvp", false), instanceSet("pvp"))
    y = y - 26
    CreateCheckbox(c, "Scenarios / Delves", 4, y, instanceGet("scenario", false), instanceSet("scenario"))
    y = y - 26
    CreateCheckbox(c, "Open World", 4, y, instanceGet("none", false), instanceSet("none"))
    y = y - 30

    -- SOUND
    CreateHeader(c, "Sound", 4, y)
    y = y - 24

    CreateCheckbox(c, "Play Sound on Cast Start", 4, y,
        function() return LWT.db.focusCastBar.soundEnabled or false end,
        function(val) LWT.db.focusCastBar.soundEnabled = val end
    )
    y = y - 30

    CreateDropdown(c, "Sound", 8, y,
        function() return LWT:GetSoundList() end,
        function() return LWT.db.focusCastBar.soundName or "None" end,
        function(name)
            if name == "None" then
                LWT.db.focusCastBar.soundName = nil
            else
                LWT.db.focusCastBar.soundName = name
                -- Preview sound
                local sounds = LWT:GetSoundList()
                for _, entry in ipairs(sounds) do
                    if entry.name == name and entry.path then
                        PlaySoundFile(entry.path, "Master")
                        break
                    end
                end
            end
        end
    )
    y = y - 56

    fcbPage:SetContentHeight(math.abs(y) + 10)
end

-- =========================================================
-- Events
-- =========================================================
settingsFrame:SetScript("OnShow", function()
    if not currentPage then
        ShowPage("gateway")
    end
end)

settingsFrame:HookScript("OnHide", function()
    -- Re-lock focus cast bar when settings close
    if LWT.db and LWT.db.focusCastBar and not LWT.db.focusCastBar.locked then
        if LWT.SetFocusCastBarLocked then
            LWT:SetFocusCastBarLocked(true)
        end
    end
end)

-- =========================================================
-- Public API
-- =========================================================
function LWT:OpenSettings()
    if settingsFrame:IsShown() then
        settingsFrame:Hide()
    else
        settingsFrame:Show()
    end
end
