local ADDON_NAME, LWT = ...

-- =========================================================
-- Dimensions
-- =========================================================
local PANEL_WIDTH = 600
local PANEL_HEIGHT = 500
local SIDEBAR_WIDTH = 140

-- =========================================================
-- Helpers
-- =========================================================
local function CreateStyledButton(name, parent, width, height)
    local btn = CreateFrame("Button", name, parent, "BackdropTemplate")
    btn:SetSize(width, height)
    btn:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    btn:SetBackdropColor(0.2, 0.2, 0.2, 1)
    btn:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)

    local text = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("CENTER")
    btn.text = text

    btn.SetText = function(self, str) self.text:SetText(str) end
    btn.GetText = function(self) return self.text:GetText() end

    btn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.3, 0.3, 0.3, 1)
        self:SetBackdropBorderColor(0.7, 0.7, 0.7, 1)
    end)
    btn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.2, 0.2, 0.2, 1)
        self:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    end)

    return btn
end

local checkboxCount = 0
local function CreateCheckbox(parent, label, x, y, getFunc, setFunc)
    checkboxCount = checkboxCount + 1
    local cb = CreateFrame("CheckButton", "LWT_Check_" .. checkboxCount, parent, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", x, y)

    local text = cb:GetFontString() or cb:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    if not cb:GetFontString() then
        text:SetPoint("LEFT", cb, "RIGHT", 4, 0)
        cb:SetFontString(text)
    end
    text:SetText(label)
    text:SetFontObject("GameFontHighlight")

    cb:SetScript("OnShow", function(self) self:SetChecked(getFunc()) end)
    cb:SetScript("OnClick", function(self) setFunc(self:GetChecked()) end)

    return cb
end

local sliderCount = 0
local function CreateSlider(parent, label, x, y, minVal, maxVal, step, getFunc, setFunc)
    sliderCount = sliderCount + 1
    local slider = CreateFrame("Slider", "LWT_Slider_" .. sliderCount, parent, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", x, y)
    slider:SetWidth(200)
    slider:SetMinMaxValues(minVal, maxVal)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)

    local sliderName = slider:GetName()
    _G[sliderName .. "Text"]:SetText(label)
    _G[sliderName .. "Low"]:SetText(minVal)
    _G[sliderName .. "High"]:SetText(maxVal)

    local valueText = slider:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    valueText:SetPoint("TOP", slider, "BOTTOM", 0, 0)

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

    return slider
end

local pickerCount = 0
local activePicker = nil

local function CreateScrollPicker(parent, label, x, y, getItemsFunc, getFunc, setFunc)
    pickerCount = pickerCount + 1
    local id = pickerCount

    local pickerLabel = parent:CreateFontString("LWT_PickerLabel_" .. id, "OVERLAY", "GameFontNormal")
    pickerLabel:SetPoint("TOPLEFT", x, y)
    pickerLabel:SetText(label)

    local btn = CreateStyledButton("LWT_PickerBtn_" .. id, parent, 200, 22)
    btn:SetPoint("TOPLEFT", x, y - 16)
    btn.text:SetJustifyH("LEFT")
    btn.text:ClearAllPoints()
    btn.text:SetPoint("LEFT", 8, 0)
    btn.text:SetPoint("RIGHT", -8, 0)

    local popup = CreateFrame("Frame", "LWT_PickerPopup_" .. id, UIParent, "BackdropTemplate")
    popup:SetSize(220, 200)
    popup:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    popup:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
    popup:SetFrameStrata("FULLSCREEN_DIALOG")
    popup:SetClampedToScreen(true)
    popup:Hide()

    local scrollFrame = CreateFrame("ScrollFrame", "LWT_PickerScroll_" .. id, popup, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 6, -6)
    scrollFrame:SetPoint("BOTTOMRIGHT", -28, 6)

    local scrollChild = CreateFrame("Frame", "LWT_PickerScrollChild_" .. id, scrollFrame)
    scrollChild:SetWidth(184)
    scrollFrame:SetScrollChild(scrollChild)

    local rowPool = {}

    local function Populate()
        for _, row in ipairs(rowPool) do row:Hide() end
        if not LWT.db then return end
        local items = getItemsFunc()
        local current = getFunc()
        local rowHeight = 18

        for i, item in ipairs(items) do
            local row = rowPool[i]
            if not row then
                row = CreateFrame("Button", "LWT_PickerRow_" .. id .. "_" .. i, scrollChild)
                row:SetHeight(rowHeight)
                row:SetPoint("TOPLEFT", 0, -(i - 1) * rowHeight)
                row:SetPoint("RIGHT")

                row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                row.text:SetPoint("LEFT", 4, 0)
                row.text:SetPoint("RIGHT", -4, 0)
                row.text:SetJustifyH("LEFT")

                row.highlight = row:CreateTexture(nil, "HIGHLIGHT")
                row.highlight:SetAllPoints()
                row.highlight:SetColorTexture(1, 1, 1, 0.1)

                row.selected = row:CreateTexture(nil, "BACKGROUND")
                row.selected:SetAllPoints()
                row.selected:SetColorTexture(0.3, 0.6, 1, 0.2)

                rowPool[i] = row
            end

            row.text:SetText(item.name)
            row.selected:SetShown(item.name == current)

            row:SetScript("OnClick", function()
                setFunc(item.name)
                btn:SetText(item.name)
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
            popup:SetPoint("TOPLEFT", btn, "BOTTOMLEFT", 0, -2)
            Populate()
            popup:Show()
            activePicker = popup
        end
    end)

    btn:SetScript("OnShow", function()
        btn:SetText(getFunc() or "Default")
    end)

    parent:HookScript("OnHide", function()
        popup:Hide()
        activePicker = nil
    end)

    return btn
end

-- =========================================================
-- Main frame
-- =========================================================
local settingsFrame = CreateFrame("Frame", "LWT_SettingsFrame", UIParent, "BackdropTemplate")
settingsFrame:SetSize(PANEL_WIDTH, PANEL_HEIGHT)
settingsFrame:SetPoint("CENTER")
settingsFrame:SetBackdrop({
    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
})
settingsFrame:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
settingsFrame:SetMovable(true)
settingsFrame:EnableMouse(true)
settingsFrame:RegisterForDrag("LeftButton")
settingsFrame:SetClampedToScreen(true)
settingsFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
settingsFrame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
settingsFrame:SetFrameStrata("DIALOG")
settingsFrame:Hide()

tinsert(UISpecialFrames, "LWT_SettingsFrame")

-- Title
local title = settingsFrame:CreateFontString("LWT_SettingsTitle", "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOP", 0, -12)
title:SetText("LuckyWipeTools")

-- Close button
local closeBtn = CreateFrame("Button", "LWT_SettingsCloseBtn", settingsFrame, "UIPanelCloseButton")
closeBtn:SetPoint("TOPRIGHT", -4, -4)

-- =========================================================
-- Sidebar
-- =========================================================
local sidebar = CreateFrame("Frame", "LWT_Sidebar", settingsFrame)
sidebar:SetPoint("TOPLEFT", 8, -36)
sidebar:SetSize(SIDEBAR_WIDTH, PANEL_HEIGHT - 44)

-- Separator line
local sep = settingsFrame:CreateTexture("LWT_SidebarSep", "ARTWORK")
sep:SetColorTexture(0.3, 0.3, 0.3, 0.6)
sep:SetSize(1, PANEL_HEIGHT - 44)
sep:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 4, 0)

-- =========================================================
-- Page system
-- =========================================================
local pages = {}
local sidebarButtons = {}
local currentPage = nil

local CONTENT_WIDTH = PANEL_WIDTH - SIDEBAR_WIDTH - 32
local CONTENT_HEIGHT = PANEL_HEIGHT - 44

local function CreatePage(key)
    -- Outer container
    local container = CreateFrame("Frame", "LWT_Page_" .. key, settingsFrame)
    container:SetPoint("TOPLEFT", sep, "TOPRIGHT", 8, 0)
    container:SetSize(CONTENT_WIDTH + 8, CONTENT_HEIGHT)
    container:Hide()

    -- Scroll frame
    local scroll = CreateFrame("ScrollFrame", "LWT_PageScroll_" .. key, container, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 0, 0)
    scroll:SetPoint("BOTTOMRIGHT", -24, 0)

    -- Scroll child (this is what content goes into)
    local content = CreateFrame("Frame", "LWT_PageContent_" .. key, scroll)
    content:SetWidth(CONTENT_WIDTH - 8)
    scroll:SetScrollChild(content)

    -- SetContentHeight must be called after populating
    container.content = content
    container.scroll = scroll
    container.SetContentHeight = function(_, h)
        content:SetHeight(math.max(h, CONTENT_HEIGHT))
    end

    pages[key] = container
    return container
end

local function ShowPage(key)
    if currentPage then currentPage:Hide() end
    currentPage = pages[key]
    if currentPage then currentPage:Show() end
    -- Update sidebar highlights
    for k, btn in pairs(sidebarButtons) do
        if k == key then
            btn:SetBackdropColor(0.3, 0.6, 1, 0.15)
            btn.text:SetTextColor(1, 0.82, 0)
        else
            btn:SetBackdropColor(0, 0, 0, 0)
            btn.text:SetTextColor(0.8, 0.8, 0.8)
        end
    end
end

local sidebarY = 0
local function AddSidebarButton(key, label)
    local btn = CreateFrame("Button", "LWT_SideBtn_" .. key, sidebar, "BackdropTemplate")
    btn:SetSize(SIDEBAR_WIDTH, 24)
    btn:SetPoint("TOPLEFT", 0, -sidebarY)
    btn:SetBackdrop({ bgFile = "Interface/Tooltips/UI-Tooltip-Background" })
    btn:SetBackdropColor(0, 0, 0, 0)

    btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    btn.text:SetPoint("LEFT", 8, 0)
    btn.text:SetText(label)
    btn.text:SetJustifyH("LEFT")

    btn:SetScript("OnEnter", function(self)
        if currentPage ~= pages[key] then
            self:SetBackdropColor(1, 1, 1, 0.05)
        end
    end)
    btn:SetScript("OnLeave", function(self)
        if currentPage ~= pages[key] then
            self:SetBackdropColor(0, 0, 0, 0)
        end
    end)
    btn:SetScript("OnClick", function() ShowPage(key) end)

    sidebarButtons[key] = btn
    sidebarY = sidebarY + 24
    return btn
end

-- =========================================================
-- Page: Encounters
-- =========================================================
AddSidebarButton("encounters", "Encounters")
local encounterPage = CreatePage("encounters")
do
    local c = encounterPage.content
    local y = -4
    for _, config in ipairs(LWT.privateAuras) do
        CreateCheckbox(c, config.label, 4, y,
            function() return LWT:IsEncounterEnabled(config.key) end,
            function(val) LWT.db.encounters[config.key] = val end
        )
        y = y - 30
    end
    encounterPage:SetContentHeight(math.abs(y) + 10)
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
    CreateSlider(c, "Alert Duration (seconds)", 12, y, 1, 10, 0.5,
        function() return LWT.db.alert.duration end,
        function(val) LWT.db.alert.duration = val end
    )
    y = y - 60

    CreateSlider(c, "Font Size", 12, y, 16, 72, 2,
        function() return LWT.db.alert.fontSize end,
        function(val)
            LWT.db.alert.fontSize = val
            LWT:UpdateAlertFont()
        end
    )
    y = y - 60

    CreateScrollPicker(c, "Font", 8, y,
        function() return LWT:GetFontList() end,
        function() return LWT.db.alert.fontName end,
        function(name)
            LWT.db.alert.fontName = name
            LWT:UpdateAlertFont()
        end
    )
    y = y - 50

    CreateScrollPicker(c, "Alert Sound", 8, y,
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
            LWT:RefreshAuras()
        end
    )
    y = y - 60

    moveBtn = CreateStyledButton("LWT_MoveBtn", c, 120, 26)
    moveBtn:SetPoint("TOPLEFT", 8, y)
    moveBtn:SetText("Unlock Alert")

    testBtn = CreateStyledButton("LWT_TestBtn", c, 120, 26)
    testBtn:SetPoint("LEFT", moveBtn, "RIGHT", 10, 0)
    testBtn:SetText("Test Alert")

    moveBtn:SetScript("OnClick", function()
        if moverActive then
            LWT:DisableMover()
            moveBtn:SetText("Unlock Alert")
            moverActive = false
        else
            LWT:EnableMover()
            moveBtn:SetText("Lock Alert")
            moverActive = true
        end
    end)

    testBtn:SetScript("OnClick", function()
        if moverActive then
            LWT:DisableMover()
            moveBtn:SetText("Unlock Alert")
            moverActive = false
        end
        LWT:FireAlert("|cffff2020FIXATED ON YOU!|r")
    end)

    y = y - 36
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
    y = y - 30

    CreateCheckbox(c, "Combat only", 4, y,
        function() return LWT.db.gateway.combatOnly end,
        function(val)
            LWT.db.gateway.combatOnly = val
            LWT:RefreshGateway()
        end
    )
    y = y - 30
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
    desc:SetTextColor(0.6, 0.6, 0.6)
    y = y - (desc:GetStringHeight() + 12)

    local header1 = c:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header1:SetPoint("TOPLEFT", 4, y)
    header1:SetText("|cffffcc00Notifications|r")
    y = y - 20

    CreateCheckbox(c, "Portal placed notification", 4, y,
        function()
            return not LWT.db.summon or LWT.db.summon.showPortalPlaced ~= false
        end,
        function(val)
            LWT.db.summon = LWT.db.summon or {}
            LWT.db.summon.showPortalPlaced = val
        end
    )
    y = y - 28

    CreateCheckbox(c, "Summon started notification", 4, y,
        function()
            return not LWT.db.summon or LWT.db.summon.showSummonStarted ~= false
        end,
        function(val)
            LWT.db.summon = LWT.db.summon or {}
            LWT.db.summon.showSummonStarted = val
        end
    )
    y = y - 28

    CreateCheckbox(c, "Accepted / Declined notification", 4, y,
        function()
            return not LWT.db.summon or LWT.db.summon.showStatus ~= false
        end,
        function(val)
            LWT.db.summon = LWT.db.summon or {}
            LWT.db.summon.showStatus = val
        end
    )
    y = y - 34

    local header2 = c:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header2:SetPoint("TOPLEFT", 4, y)
    header2:SetText("|cffffcc00Outside Roster|r")
    y = y - 20

    CreateCheckbox(c, "Show roster frame", 4, y,
        function()
            return not LWT.db.summon or LWT.db.summon.showRoster ~= false
        end,
        function(val)
            LWT.db.summon = LWT.db.summon or {}
            LWT.db.summon.showRoster = val
        end
    )
    y = y - 28

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
    y = y - 34

    local clTypeLabel = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    clTypeLabel:SetPoint("TOPLEFT", 20, y)
    clTypeLabel:SetText("Instance types:")
    clTypeLabel:SetTextColor(0.7, 0.7, 0.7)
    y = y - 18

    for _, itype in ipairs(LWT.combatLogInstanceTypes) do
        CreateCheckbox(c, itype.label, 20, y,
            function() return LWT.db.combatLog.instanceTypes[itype.key] end,
            function(val) LWT.db.combatLog.instanceTypes[itype.key] = val end
        )
        y = y - 26
    end

    y = y - 8
    local clDiffLabel = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    clDiffLabel:SetPoint("TOPLEFT", 20, y)
    clDiffLabel:SetText("Difficulties:")
    clDiffLabel:SetTextColor(0.7, 0.7, 0.7)
    y = y - 18

    for _, diff in ipairs(LWT.combatLogDifficulties) do
        CreateCheckbox(c, diff.label, 20, y,
            function()
                local val = LWT.db.combatLog.difficulties[diff.key]
                if val == nil then return true end
                return val
            end,
            function(val) LWT.db.combatLog.difficulties[diff.key] = val end
        )
        y = y - 26
    end

    combatLogPage:SetContentHeight(math.abs(y) + 10)
end

-- =========================================================
-- Lock mover on close, default page
-- =========================================================
settingsFrame:SetScript("OnHide", function()
    if moverActive then
        LWT:DisableMover()
        moveBtn:SetText("Unlock Alert")
        moverActive = false
    end
end)

settingsFrame:SetScript("OnShow", function()
    if not currentPage then
        ShowPage("encounters")
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
