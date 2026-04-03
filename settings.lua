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

    btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
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
    local text = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
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

    local title = wrapper:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    title:SetPoint("TOPLEFT", 0, 0)
    title:SetText(label)

    local valueText = wrapper:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    valueText:SetPoint("TOPRIGHT", 0, 0)
    valueText:SetTextColor(ACCENT[1], ACCENT[2], ACCENT[3])

    local slider = CreateFrame("Slider", "LWT_Slider_" .. sliderCount, wrapper, "BackdropTemplate")
    slider:SetSize(280, 12)
    slider:SetPoint("TOPLEFT", 0, -16)
    FlatBackdrop(slider, { 0.08, 0.08, 0.10, 1 }, { 0.25, 0.25, 0.28, 1 })
    slider:SetMinMaxValues(minVal, maxVal)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)

    -- Thumb
    local thumb = slider:CreateTexture(nil, "OVERLAY")
    thumb:SetSize(14, 14)
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

    local title = wrapper:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    title:SetPoint("TOPLEFT", 0, 0)
    title:SetText(label)

    local btn = CreateFrame("Button", "LWT_Drop_" .. id, wrapper, "BackdropTemplate")
    btn:SetSize(280, 22)
    btn:SetPoint("TOPLEFT", 0, -14)
    FlatBackdrop(btn, { 0.08, 0.08, 0.10, 1 }, { 0.25, 0.25, 0.28, 1 })

    btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    btn.text:SetPoint("LEFT", 8, 0)
    btn.text:SetPoint("RIGHT", -20, 0)
    btn.text:SetJustifyH("LEFT")

    -- Arrow
    local arrow = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
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

                row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
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
-- Widget: Section header
-- =========================================================
local function CreateHeader(parent, text, x, y)
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", x, y - 6)
    line:SetPoint("RIGHT", parent, "RIGHT", -8, 0)
    line:SetColorTexture(HEADER_COLOR[1], HEADER_COLOR[2], HEADER_COLOR[3], 0.2)

    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
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

local title = titleBar:CreateFontString("LWT_SettingsTitle", "OVERLAY", "GameFontNormal")
title:SetPoint("LEFT", 12, 0)
title:SetText("LuckyWipeTools")
title:SetTextColor(ACCENT[1], ACCENT[2], ACCENT[3])

-- Close button
local closeBtn = CreateFrame("Button", "LWT_SettingsCloseBtn", titleBar)
closeBtn:SetSize(28, 28)
closeBtn:SetPoint("RIGHT", -2, 0)
closeBtn.text = closeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
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

    btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
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
-- Page: Alert Style
-- =========================================================
AddSidebarButton("alert", "Alert Style")
local alertPage = CreatePage("alert")
local moverActive = false
local moveBtn, testBtn
do
    local c = alertPage.content
    local y = -4

    CreateSlider(c, "Duration (seconds)", 8, y, 1, 10, 0.5,
        function() return LWT.db.alert.duration end,
        function(val) LWT.db.alert.duration = val end
    )
    y = y - 52

    CreateSlider(c, "Font Size", 8, y, 16, 72, 2,
        function() return LWT.db.alert.fontSize end,
        function(val)
            LWT.db.alert.fontSize = val
            LWT:UpdateAlertFont()
        end
    )
    y = y - 52

    CreateDropdown(c, "Font", 8, y,
        function() return LWT:GetFontList() end,
        function() return LWT.db.alert.fontName end,
        function(name)
            LWT.db.alert.fontName = name
            LWT:UpdateAlertFont()
        end
    )
    y = y - 48

    CreateDropdown(c, "Sound", 8, y,
        function() return LWT:GetSoundList() end,
        function() return LWT.db.alert.soundName or "None" end,
        function(name)
            if name == "None" then
                LWT.db.alert.sound = false
                LWT.db.alert.soundName = nil
            else
                LWT.db.alert.sound = true
                LWT.db.alert.soundName = name
            end
            local soundPath = LWT:GetSoundFile()
            if soundPath then PlaySoundFile(soundPath, "Master") end
            end
    )
    y = y - 56

    CreateHeader(c, "Position", 8, y)
    y = y - 24

    moveBtn = CreateButton("LWT_MoveBtn", c, 130, 24)
    moveBtn:SetPoint("TOPLEFT", 8, y)
    moveBtn:SetText("Unlock Position")

    testBtn = CreateButton("LWT_TestBtn", c, 130, 24)
    testBtn:SetPoint("LEFT", moveBtn, "RIGHT", 8, 0)
    testBtn:SetText("Test Alert")

    moveBtn:SetScript("OnClick", function()
        if moverActive then
            LWT:DisableMover()
            moveBtn:SetText("Unlock Position")
            moverActive = false
        else
            LWT:EnableMover()
            moveBtn:SetText("Lock Position")
            moverActive = true
        end
    end)

    testBtn:SetScript("OnClick", function()
        if moverActive then
            LWT:DisableMover()
            moveBtn:SetText("Unlock Position")
            moverActive = false
        end
        LWT:FireAlert("|cffff2020FIXATED ON YOU!|r")
    end)

    y = y - 34
    alertPage:SetContentHeight(math.abs(y) + 10)
end

-- =========================================================
-- Page: Gateway
-- =========================================================
AddSidebarButton("gateway", "Gateway")
local gatewayPage = CreatePage("gateway")
do
    local c = gatewayPage.content
    local y = -4
    CreateCheckbox(c, "Gateway Ready alert", 4, y,
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
    y = y - 26
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

    local desc = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", 8, y)
    desc:SetWidth(CONTENT_WIDTH - 24)
    desc:SetJustifyH("LEFT")
    desc:SetText("Tracks summoning portal placement and summon status for raid members. Shows a roster of players outside your zone.")
    desc:SetTextColor(TEXT_DIM[1], TEXT_DIM[2], TEXT_DIM[3])
    y = y - (desc:GetStringHeight() + 14)

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

    CreateCheckbox(c, "Summon started", 4, y,
        function()
            return not LWT.db.summon or LWT.db.summon.showSummonStarted ~= false
        end,
        function(val)
            LWT.db.summon = LWT.db.summon or {}
            LWT.db.summon.showSummonStarted = val
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
    y = y - 24

    summonPage:SetContentHeight(math.abs(y) + 10)
end

-- =========================================================
-- Page: Combat Log
-- =========================================================
AddSidebarButton("combatlog", "Combat Log")
local combatLogPage = CreatePage("combatlog")
do
    local c = combatLogPage.content
    local y = -4
    CreateCheckbox(c, "Auto-enable combat logging", 4, y,
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

    local desc = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", 8, y)
    desc:SetWidth(CONTENT_WIDTH - 24)
    desc:SetJustifyH("LEFT")
    desc:SetText("Split item stacks into smaller stacks for distribution. Works with personal bags and guild bank. A Split button also appears on the guild bank frame.")
    desc:SetTextColor(TEXT_DIM[1], TEXT_DIM[2], TEXT_DIM[3])
    y = y - (desc:GetStringHeight() + 14)

    CreateHeader(c, "Usage", 4, y)
    y = y - 24

    local usage = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
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
-- Events
-- =========================================================
settingsFrame:SetScript("OnHide", function()
    if moverActive then
        LWT:DisableMover()
        moveBtn:SetText("Unlock Position")
        moverActive = false
    end
end)

settingsFrame:SetScript("OnShow", function()
    if not currentPage then
        ShowPage("alert")
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
