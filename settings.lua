local ADDON_NAME, LWT = ...

-- =========================================================
-- Helper: create a styled button (dark, clean look)
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

local settingsFrame = CreateFrame("Frame", "LWT_SettingsFrame", UIParent, "BackdropTemplate")
settingsFrame:SetSize(340, 380)
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
-- Helper: create a checkbox
-- =========================================================
local function CreateCheckbox(parent, label, x, y, getFunc, setFunc)
    local cb = CreateFrame("CheckButton", "LWT_Check_" .. label:gsub("%W", ""), parent, "UICheckButtonTemplate")
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

-- =========================================================
-- Helper: create a slider
-- =========================================================
local function CreateSlider(parent, label, x, y, minVal, maxVal, step, getFunc, setFunc)
    local slider = CreateFrame("Slider", "LWT_Slider_" .. label:gsub("%W", ""), parent, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", x, y)
    slider:SetWidth(200)
    slider:SetMinMaxValues(minVal, maxVal)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)

    local sliderName = slider:GetName()
    _G[sliderName .. "Text"]:SetText(label)
    _G[sliderName .. "Low"]:SetText(minVal)
    _G[sliderName .. "High"]:SetText(maxVal)

    local valueText = slider:CreateFontString("LWT_SliderVal_" .. label:gsub("%W", ""), "OVERLAY", "GameFontHighlightSmall")
    valueText:SetPoint("TOP", slider, "BOTTOM", 0, 0)

    slider:SetScript("OnShow", function(self)
        local val = getFunc()
        self:SetValue(val)
        valueText:SetText(val)
    end)
    slider:SetScript("OnValueChanged", function(self, val)
        val = math.floor(val / step + 0.5) * step -- snap to step
        valueText:SetText(val)
        setFunc(val)
    end)

    return slider
end

-- =========================================================
-- Helper: create a scrollable picker (button + popup scroll list)
-- =========================================================
local pickerCount = 0
local activePicker = nil -- only one open at a time

local function CreateScrollPicker(parent, label, x, y, getItemsFunc, getFunc, setFunc)
    pickerCount = pickerCount + 1
    local id = pickerCount

    -- Label
    local pickerLabel = parent:CreateFontString("LWT_PickerLabel_" .. id, "OVERLAY", "GameFontNormal")
    pickerLabel:SetPoint("TOPLEFT", x, y)
    pickerLabel:SetText(label)

    -- Button showing current selection
    local btn = CreateStyledButton("LWT_PickerBtn_" .. id, parent, 200, 22)
    btn:SetPoint("TOPLEFT", x, y - 16)
    btn.text:SetJustifyH("LEFT")
    btn.text:ClearAllPoints()
    btn.text:SetPoint("LEFT", 8, 0)
    btn.text:SetPoint("RIGHT", -8, 0)

    -- Popup scroll frame
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

    -- Scroll frame inside popup
    local scrollFrame = CreateFrame("ScrollFrame", "LWT_PickerScroll_" .. id, popup, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 6, -6)
    scrollFrame:SetPoint("BOTTOMRIGHT", -28, 6)

    local scrollChild = CreateFrame("Frame", "LWT_PickerScrollChild_" .. id, scrollFrame)
    scrollChild:SetWidth(184)
    scrollFrame:SetScrollChild(scrollChild)

    -- Row pool
    local rowPool = {}

    local function Populate()
        -- Hide existing rows
        for _, row in ipairs(rowPool) do
            row:Hide()
        end

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

    -- Toggle popup on button click
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

    -- Update button text when settings panel shows
    btn:SetScript("OnShow", function()
        btn:SetText(getFunc() or "Default")
    end)

    -- Close popup when settings panel hides
    parent:HookScript("OnHide", function()
        popup:Hide()
        activePicker = nil
    end)

    return btn
end

-- =========================================================
-- Build the settings panel
-- =========================================================
local yOffset = -42

-- Section: Encounters
local encounterHeader = settingsFrame:CreateFontString("LWT_EncounterHeader", "OVERLAY", "GameFontNormal")
encounterHeader:SetPoint("TOPLEFT", 16, yOffset)
encounterHeader:SetText("|cffffcc00Encounter Alerts|r")
yOffset = yOffset - 10

for _, config in ipairs(LWT.privateAuras) do
    CreateCheckbox(settingsFrame, config.label, 14, yOffset - 22,
        function() return LWT:IsEncounterEnabled(config.key) end,
        function(val) LWT.db.encounters[config.key] = val end
    )
    yOffset = yOffset - 34
end

yOffset = yOffset - 20

-- Section: Alert Duration
CreateSlider(settingsFrame, "Alert Duration (seconds)", 24, yOffset, 1, 10, 0.5,
    function() return LWT.db.alert.duration end,
    function(val) LWT.db.alert.duration = val end
)
yOffset = yOffset - 62

-- Section: Font Size
CreateSlider(settingsFrame, "Font Size", 24, yOffset, 16, 72, 2,
    function() return LWT.db.alert.fontSize end,
    function(val)
        LWT.db.alert.fontSize = val
        LWT:UpdateAlertFont()
    end
)
yOffset = yOffset - 62

-- Section: Font
CreateScrollPicker(settingsFrame, "Font", 20, yOffset,
    function() return LWT:GetFontList() end,
    function() return LWT.db.alert.fontName end,
    function(name)
        LWT.db.alert.fontName = name
        LWT:UpdateAlertFont()
    end
)
yOffset = yOffset - 52

-- Section: Sound
CreateScrollPicker(settingsFrame, "Alert Sound", 20, yOffset,
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
        -- Preview the sound
        local soundPath = LWT:GetSoundFile()
        if soundPath then PlaySoundFile(soundPath, "Master") end
    end
)
yOffset = yOffset - 52

-- Section: Position
local moveBtn = CreateStyledButton("LWT_MoveBtn", settingsFrame, 130, 26)
moveBtn:SetPoint("TOPLEFT", 20, yOffset)
moveBtn:SetText("Unlock Alert")

local testBtn = CreateStyledButton("LWT_TestBtn", settingsFrame, 130, 26)
testBtn:SetPoint("LEFT", moveBtn, "RIGHT", 10, 0)
testBtn:SetText("Test Alert")

local moverActive = false

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

-- Lock mover when settings panel closes
settingsFrame:SetScript("OnHide", function()
    if moverActive then
        LWT:DisableMover()
        moveBtn:SetText("Unlock Alert")
        moverActive = false
    end
end)

-- Resize to fit content
settingsFrame:SetHeight(math.abs(yOffset) + 50)

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
