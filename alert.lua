local ADDON_NAME, LWT = ...

local alertFrame = CreateFrame("Frame", "LWT_AlertFrame", UIParent)
alertFrame:SetSize(400, 60)
alertFrame:SetFrameStrata("HIGH")
alertFrame:Hide()

local alertText = alertFrame:CreateFontString("LWT_AlertText", "OVERLAY")
alertText:SetPoint("CENTER")

-- Position loading
local function LoadPosition()
    alertFrame:ClearAllPoints()
    local pos = LWT.db.alert.position
    if pos and pos.point then
        alertFrame:SetPoint(pos.point, UIParent, pos.point, pos.x, pos.y)
    else
        alertFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 200)
    end
end

-- Create animation group once and reuse
local fadeOut = alertFrame:CreateAnimationGroup()
local alphaAnim = fadeOut:CreateAnimation("Alpha")
alphaAnim:SetFromAlpha(1)
alphaAnim:SetToAlpha(0)
alphaAnim:SetDuration(0.5)
fadeOut:SetScript("OnFinished", function()
    alertFrame:Hide()
    alertFrame:SetAlpha(1)
end)

local fadeTimer = nil

function LWT:UpdateAlertFont()
    local font = self:GetFont()
    local size = self.db.alert.fontSize or 36
    alertText:SetFont(font, size, "OUTLINE")
    LoadPosition()
end

function LWT:FireAlert(text)
    -- Update font in case settings changed
    self:UpdateAlertFont()

    -- Stop any in-progress fade
    fadeOut:Stop()

    -- Set text and show
    alertText:SetText(text or "|cffff2020ALERT!|r")
    alertFrame:SetAlpha(1)
    alertFrame:Show()

    -- Play sound if enabled
    local soundFile = self:GetSoundFile()
    if soundFile then
        PlaySoundFile(soundFile, "Master")
    end

    -- Cancel existing fade timer
    if fadeTimer then
        fadeTimer:Cancel()
        fadeTimer = nil
    end

    -- Fade out after configured duration
    local duration = self.db.alert.duration or 3
    fadeTimer = C_Timer.NewTimer(duration, function()
        fadeOut:Play()
        fadeTimer = nil
    end)
end

-- Mover mode
local moverBg = nil

function LWT:EnableMover()
    self:UpdateAlertFont()
    fadeOut:Stop()
    if fadeTimer then fadeTimer:Cancel(); fadeTimer = nil end

    alertText:SetText("|cffff9900Drag to move|r")
    alertFrame:SetAlpha(1)
    alertFrame:Show()

    alertFrame:SetMovable(true)
    alertFrame:EnableMouse(true)
    alertFrame:RegisterForDrag("LeftButton")

    -- Add visible background so you can see the drag area
    if not moverBg then
        moverBg = alertFrame:CreateTexture("LWT_MoverBg", "BACKGROUND")
        moverBg:SetAllPoints()
        moverBg:SetColorTexture(0, 0, 0, 0.4)
    end
    moverBg:Show()

    alertFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    alertFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, _, x, y = self:GetPoint()
        LWT.db.alert.position = { point = point, x = x, y = y }
    end)
end

function LWT:DisableMover()
    alertFrame:SetMovable(false)
    alertFrame:EnableMouse(false)
    alertFrame:SetScript("OnDragStart", nil)
    alertFrame:SetScript("OnDragStop", nil)
    if moverBg then moverBg:Hide() end
    alertFrame:Hide()
end

-- Initial font setup after DB is ready
local initFrame = CreateFrame("Frame", "LWT_AlertInit")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function()
    LWT:UpdateAlertFont()
    initFrame:UnregisterEvent("PLAYER_LOGIN")
end)
