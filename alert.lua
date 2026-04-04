local ADDON_NAME, LWT = ...

-- Alert system factory — creates independent alert frames with their own config
-- Each alert system has: Fire, EnableMover, DisableMover, UpdateFont
function LWT:CreateAlertSystem(key, dbKeyFunc)
    local system = {}

    local alertFrame = CreateFrame("Frame", "LWT_AlertFrame_" .. key, UIParent)
    alertFrame:SetSize(400, 60)
    alertFrame:SetFrameStrata("HIGH")
    alertFrame:Hide()

    local alertText = alertFrame:CreateFontString("LWT_AlertText_" .. key, "OVERLAY")
    alertText:SetPoint("CENTER")

    local function GetDB()
        return dbKeyFunc()
    end

    local function LoadPosition()
        alertFrame:ClearAllPoints()
        local db = GetDB()
        local pos = db.position
        if pos and pos.point then
            alertFrame:SetPoint(pos.point, UIParent, pos.point, pos.x, pos.y)
        else
            alertFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 200)
        end
    end

    -- Fade animation
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

    -- Strip WoW color codes from text so DB color applies cleanly
    local function StripColorCodes(text)
        if not text then return text end
        text = text:gsub("|c%x%x%x%x%x%x%x%x", "")
        text = text:gsub("|r", "")
        return text
    end

    function system:UpdateFont()
        local db = GetDB()
        local fontName = db.fontName or "Friz Quadrata"
        local fonts = LWT:GetFontList()
        local fontPath = "Fonts\\FRIZQT__.TTF"
        for _, entry in ipairs(fonts) do
            if entry.name == fontName then
                fontPath = entry.path
                break
            end
        end
        local size = db.fontSize or 36
        alertText:SetFont(fontPath, size, "OUTLINE")
        local c = db.color
        if c then
            alertText:SetTextColor(c.r or 1, c.g or 0.82, c.b or 0)
        end
        LoadPosition()
    end

    function system:Fire(text)
        self:UpdateFont()
        fadeOut:Stop()

        alertText:SetText(StripColorCodes(text) or "ALERT!")
        alertFrame:SetAlpha(1)
        alertFrame:Show()

        -- Play sound
        local db = GetDB()
        if db.sound then
            local soundName = db.soundName
            if soundName then
                local sounds = LWT:GetSoundList()
                for _, entry in ipairs(sounds) do
                    if entry.name == soundName and entry.path then
                        PlaySoundFile(entry.path, "Master")
                        break
                    end
                end
            end
        end

        if fadeTimer then
            fadeTimer:Cancel()
            fadeTimer = nil
        end

        local duration = db.duration or 3
        fadeTimer = C_Timer.NewTimer(duration, function()
            fadeOut:Play()
            fadeTimer = nil
        end)
    end

    -- Persistent show/hide (no fade, no timer)
    function system:Show(text)
        self:UpdateFont()
        fadeOut:Stop()
        if fadeTimer then fadeTimer:Cancel(); fadeTimer = nil end

        alertText:SetText(StripColorCodes(text) or "ALERT!")
        alertFrame:SetAlpha(1)
        alertFrame:Show()

        -- Play sound on first show
        local db = GetDB()
        if db.sound then
            local soundName = db.soundName
            if soundName then
                local sounds = LWT:GetSoundList()
                for _, entry in ipairs(sounds) do
                    if entry.name == soundName and entry.path then
                        PlaySoundFile(entry.path, "Master")
                        break
                    end
                end
            end
        end
    end

    function system:Hide()
        fadeOut:Stop()
        if fadeTimer then fadeTimer:Cancel(); fadeTimer = nil end
        alertFrame:Hide()
        alertFrame:SetAlpha(1)
    end

    -- Mover mode
    local moverBg = nil

    function system:EnableMover()
        self:UpdateFont()
        fadeOut:Stop()
        if fadeTimer then fadeTimer:Cancel(); fadeTimer = nil end

        alertText:SetText("|cffff9900Drag to move|r")
        alertFrame:SetAlpha(1)
        alertFrame:Show()

        alertFrame:SetMovable(true)
        alertFrame:EnableMouse(true)
        alertFrame:RegisterForDrag("LeftButton")

        if not moverBg then
            moverBg = alertFrame:CreateTexture("LWT_MoverBg_" .. key, "BACKGROUND")
            moverBg:SetAllPoints()
            moverBg:SetColorTexture(0, 0, 0, 0.4)
        end
        moverBg:Show()

        alertFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
        alertFrame:SetScript("OnDragStop", function(self)
            self:StopMovingOrSizing()
            local point, _, _, x, y = self:GetPoint()
            local db = GetDB()
            db.position = { point = point, x = x, y = y }
        end)
    end

    function system:DisableMover()
        alertFrame:SetMovable(false)
        alertFrame:EnableMouse(false)
        alertFrame:SetScript("OnDragStart", nil)
        alertFrame:SetScript("OnDragStop", nil)
        if moverBg then moverBg:Hide() end
        alertFrame:Hide()
    end

    return system
end

-- Create alert systems after DB is ready
local initFrame = CreateFrame("Frame", "LWT_AlertInit")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function()
    LWT.gatewayAlert = LWT:CreateAlertSystem("gateway", function()
        return LWT.db.gateway.alert
    end)
    LWT.summonAlert = LWT:CreateAlertSystem("summon", function()
        return LWT.db.summon.alert
    end)
    LWT.gatewayAlert:UpdateFont()
    LWT.summonAlert:UpdateFont()
    LWT.vantusAlert = LWT:CreateAlertSystem("vantus", function()
        return LWT.db.vantus.alert
    end)
    LWT.vantusAlert:UpdateFont()
    LWT.consumablesAlert = LWT:CreateAlertSystem("consumables", function()
        return LWT.db.consumables.alert
    end)
    LWT.consumablesAlert:UpdateFont()
    LWT.trackerAlert = LWT:CreateAlertSystem("tracker", function()
        return LWT.db.tracker.alert
    end)
    LWT.trackerAlert:UpdateFont()
    initFrame:UnregisterEvent("PLAYER_LOGIN")
end)
