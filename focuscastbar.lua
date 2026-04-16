local ADDON_NAME, LWT = ...

local INTERRUPT_SPELLS = LWT.INTERRUPT_SPELLS

local DEFAULT_FONT = "Fonts\\FRIZQT__.TTF"

-- Defer to Lantern's FocusCastBar if loaded and enabled
local function LanternHandles()
    local Lantern = _G.Lantern
    if (Lantern and Lantern.modules and Lantern.modules["FocusCastBar"]
        and Lantern.modules["FocusCastBar"].enabled) then
        return true
    end
    return false
end

-------------------------------------------------------------------------------
-- State
-------------------------------------------------------------------------------

local castBarFrame
local progressBar, interruptBar
local iconFrame, shieldIcon, textFrame
local spellNameText, timeText
local tickTexture
local borderFrame
local resizeHandle

local isCasting = false
local isChanneling = false
local isImportantCast = false
local castEndTime = 0
local castStartTime = 0
local castDuration = 0
local instanceAllowed = false

local cachedInterruptSpellId = nil
local cachedSpecId = nil

local UPDATE_INTERVAL = 1 / 30
local lastUpdate = 0

-------------------------------------------------------------------------------
-- Helpers
-------------------------------------------------------------------------------

local function GetDB()
    return LWT.db and LWT.db.focusCastBar
end

local function GetInterruptSpellId()
    local specId = GetSpecializationInfo(GetSpecialization() or 0)
    if not specId then
        cachedInterruptSpellId = nil
        cachedSpecId = nil
        return nil
    end
    if specId == cachedSpecId and cachedInterruptSpellId ~= nil then
        return cachedInterruptSpellId
    end
    cachedSpecId = specId
    local _, class = UnitClass("player")
    local classTable = INTERRUPT_SPELLS and INTERRUPT_SPELLS[class]
    cachedInterruptSpellId = classTable and classTable[specId] or false
    return cachedInterruptSpellId or nil
end

-------------------------------------------------------------------------------
-- Frame Creation
-------------------------------------------------------------------------------

local function UpdateLayout(db)
    if not castBarFrame then return end

    local w = db.width or 250
    local h = db.height or 24
    local showIc = db.showIcon ~= false

    castBarFrame:SetSize(w + (showIc and h or 0), h)

    -- Background
    castBarFrame.bg:SetVertexColor(db.bgColor.r, db.bgColor.g, db.bgColor.b, db.bgAlpha or 0.8)

    -- Bar texture
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    local texturePath = "Interface\\TargetingFrame\\UI-StatusBar"
    if db.barTexture and LSM then
        texturePath = LSM:Fetch("statusbar", db.barTexture) or texturePath
    end
    progressBar:SetStatusBarTexture(texturePath)

    -- Progress bar
    progressBar:ClearAllPoints()
    if showIc then
        progressBar:SetPoint("TOPLEFT", castBarFrame, "TOPLEFT", h, 0)
        progressBar:SetPoint("BOTTOMRIGHT", castBarFrame, "BOTTOMRIGHT", 0, 0)
    else
        progressBar:SetPoint("TOPLEFT", castBarFrame, "TOPLEFT", 0, 0)
        progressBar:SetPoint("BOTTOMRIGHT", castBarFrame, "BOTTOMRIGHT", 0, 0)
    end

    -- Interrupt bar (same size as progress bar)
    interruptBar:ClearAllPoints()
    interruptBar:SetAllPoints(progressBar)

    -- Icon
    if showIc then
        iconFrame:SetSize(h, h)
        iconFrame:ClearAllPoints()
        iconFrame:SetPoint("RIGHT", progressBar, "LEFT", 0, 0)
        iconFrame:Show()
    else
        iconFrame:Hide()
    end

    -- Shield icon
    shieldIcon:SetSize(h * 0.6, h * 0.6)
    shieldIcon:ClearAllPoints()
    shieldIcon:SetPoint("TOP", castBarFrame, "BOTTOM", 0, -2)

    -- Border
    borderFrame:ClearAllPoints()
    borderFrame:SetAllPoints(progressBar)

    -- Text
    local fontName = db.fontName or "Roboto"
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    local fontPath = DEFAULT_FONT
    if LSM then
        fontPath = LSM:Fetch("font", fontName) or DEFAULT_FONT
    end
    local fontSize = db.fontSize or 11
    spellNameText:SetFont(fontPath, fontSize, "OUTLINE")
    timeText:SetFont(fontPath, fontSize, "OUTLINE")

    local tc = db.textColor
    spellNameText:SetTextColor(tc.r, tc.g, tc.b)
    timeText:SetTextColor(tc.r, tc.g, tc.b)

    spellNameText:SetShown(db.showSpellName ~= false)
    timeText:SetShown(db.showTimeRemaining ~= false)

    -- Tick texture
    local tkc = db.tickColor
    tickTexture:SetColorTexture(tkc.r, tkc.g, tkc.b, 1)
    tickTexture:SetSize(2, h)

    -- Resize handle
    if resizeHandle then
        resizeHandle:SetSize(12, 12)
        resizeHandle:ClearAllPoints()
        resizeHandle:SetPoint("BOTTOMRIGHT", castBarFrame, "BOTTOMRIGHT", 0, 0)
    end
end

local function ShowPreview(db)
    if not castBarFrame then return end
    UpdateLayout(db)

    isCasting = false
    isChanneling = false

    progressBar:SetMinMaxValues(0, 1)
    progressBar:SetValue(0.55)
    interruptBar:SetMinMaxValues(0, 1)
    interruptBar:SetValue(0)

    local rR, rG, rB = db.barReadyColor.r, db.barReadyColor.g, db.barReadyColor.b
    progressBar:SetStatusBarColor(rR, rG, rB)

    if db.showIcon ~= false then
        iconFrame.tex:SetTexture(136243)
        iconFrame:Show()
    end

    if db.showSpellName ~= false then
        spellNameText:SetText("Preview Cast")
    end
    if db.showTimeRemaining ~= false then
        timeText:SetText("1.5")
    end

    shieldIcon:SetAlpha(0)
    tickTexture:Hide()
    castBarFrame:Show()
end

local function CreateCastBarFrame()
    if castBarFrame then return end

    local db = GetDB()
    if not db then return end

    -- Main container
    castBarFrame = CreateFrame("Frame", "LWT_FocusCastBar", UIParent)
    castBarFrame:SetSize(db.width + db.height, db.height)
    castBarFrame:SetPoint("CENTER", UIParent, "CENTER", 0, -150)
    castBarFrame:SetFrameStrata("MEDIUM")
    castBarFrame:SetClampedToScreen(true)
    castBarFrame:Hide()

    -- Background
    castBarFrame.bg = castBarFrame:CreateTexture("LWT_FocusCastBar_BG", "BACKGROUND")
    castBarFrame.bg:SetAllPoints(castBarFrame)
    castBarFrame.bg:SetColorTexture(db.bgColor.r, db.bgColor.g, db.bgColor.b, db.bgAlpha)

    -- Progress bar (StatusBar)
    progressBar = CreateFrame("StatusBar", "LWT_FocusCastBar_Progress", castBarFrame)
    progressBar:SetMinMaxValues(0, 1)
    progressBar:SetValue(0)
    progressBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    progressBar:SetStatusBarColor(0.18, 0.54, 0.18)

    -- Interrupt bar (invisible, used for tick positioning)
    interruptBar = CreateFrame("StatusBar", "LWT_FocusCastBar_Interrupt", castBarFrame)
    interruptBar:SetMinMaxValues(0, 1)
    interruptBar:SetValue(0)
    interruptBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    interruptBar:SetAlpha(0)

    -- Tick texture (anchored to interrupt bar fill edge)
    tickTexture = interruptBar:CreateTexture("LWT_FocusCastBar_Tick", "OVERLAY")
    tickTexture:SetColorTexture(1, 1, 1, 1)
    tickTexture:SetSize(2, db.height)
    tickTexture:SetPoint("LEFT", interruptBar:GetStatusBarTexture(), "RIGHT", 0, 0)
    tickTexture:Hide()

    -- Icon frame (always LEFT)
    iconFrame = CreateFrame("Frame", "LWT_FocusCastBar_Icon", castBarFrame)
    iconFrame:SetSize(db.height, db.height)
    iconFrame.tex = iconFrame:CreateTexture("LWT_FocusCastBar_IconTex", "ARTWORK")
    iconFrame.tex:SetAllPoints()
    iconFrame.tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    -- Shield icon (non-interruptible indicator)
    shieldIcon = castBarFrame:CreateTexture("LWT_FocusCastBar_Shield", "OVERLAY")
    shieldIcon:SetAtlas("nameplates-InterruptShield")
    shieldIcon:SetSize(14, 14)
    shieldIcon:SetPoint("TOP", castBarFrame, "BOTTOM", 0, -2)
    shieldIcon:Hide()

    -- Border frame
    borderFrame = CreateFrame("Frame", "LWT_FocusCastBar_Border", castBarFrame, "BackdropTemplate")
    borderFrame:SetBackdrop({
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    borderFrame:SetBackdropBorderColor(0, 0, 0, 0.6)

    -- Important cast glow (colored border, hidden by default)
    local importantGlow = CreateFrame("Frame", "LWT_FocusCastBar_ImportantGlow", castBarFrame, "BackdropTemplate")
    importantGlow:SetPoint("TOPLEFT", -2, 2)
    importantGlow:SetPoint("BOTTOMRIGHT", 2, -2)
    importantGlow:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 2,
    })
    importantGlow:SetFrameLevel(borderFrame:GetFrameLevel() - 1)
    importantGlow:Hide()
    castBarFrame._importantGlow = importantGlow

    -- Text frame (overlay on progress bar)
    textFrame = CreateFrame("Frame", "LWT_FocusCastBar_Text", progressBar)
    textFrame:SetAllPoints()
    textFrame:SetFrameLevel(progressBar:GetFrameLevel() + 2)

    spellNameText = textFrame:CreateFontString("LWT_FocusCastBar_SpellName", "OVERLAY", "LWT_Body")
    spellNameText:SetPoint("LEFT", textFrame, "LEFT", 4, 0)
    spellNameText:SetPoint("RIGHT", textFrame, "RIGHT", -50, 0)
    spellNameText:SetJustifyH("LEFT")
    spellNameText:SetWordWrap(false)

    timeText = textFrame:CreateFontString("LWT_FocusCastBar_TimeText", "OVERLAY", "LWT_Body")
    timeText:SetPoint("RIGHT", textFrame, "RIGHT", -4, 0)
    timeText:SetJustifyH("RIGHT")

    -- Drag support
    castBarFrame:SetMovable(true)
    castBarFrame:EnableMouse(false)
    castBarFrame:RegisterForDrag("LeftButton")
    castBarFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    castBarFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, _, x, y = self:GetPoint()
        local fcbDb = GetDB()
        if fcbDb then
            fcbDb.pos = { point = point, x = x, y = y }
        end
    end)

    -- Resize support
    castBarFrame:SetResizable(true)
    castBarFrame:SetResizeBounds(100, 16, 500, 48)

    resizeHandle = CreateFrame("Frame", "LWT_FocusCastBar_Resize", castBarFrame)
    resizeHandle:SetSize(12, 12)
    resizeHandle:SetPoint("BOTTOMRIGHT", castBarFrame, "BOTTOMRIGHT", 0, 0)
    resizeHandle:EnableMouse(false)
    resizeHandle:SetFrameLevel(castBarFrame:GetFrameLevel() + 5)
    resizeHandle:Hide()

    local resizeTex = resizeHandle:CreateTexture("LWT_FocusCastBar_ResizeTex", "OVERLAY")
    resizeTex:SetAllPoints()
    resizeTex:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")

    resizeHandle:SetScript("OnMouseDown", function()
        castBarFrame:StartSizing("BOTTOMRIGHT")
    end)
    resizeHandle:SetScript("OnMouseUp", function()
        castBarFrame:StopMovingOrSizing()
        local fcbDb = GetDB()
        if fcbDb then
            local w = math.floor(castBarFrame:GetWidth() + 0.5)
            local h = math.floor(castBarFrame:GetHeight() + 0.5)
            local showIc = fcbDb.showIcon ~= false
            fcbDb.width = showIc and (w - h) or w
            fcbDb.height = h
        end
        UpdateLayout(GetDB())
    end)

    -- Restore saved position
    local pos = db.pos
    if pos and pos.point then
        castBarFrame:ClearAllPoints()
        castBarFrame:SetPoint(pos.point, UIParent, pos.point, pos.x, pos.y)
    end

    -- OnUpdate for bar color, time text, tick position
    castBarFrame:SetScript("OnUpdate", function(_, elapsed)
        lastUpdate = lastUpdate + elapsed
        if lastUpdate < UPDATE_INTERVAL then return end
        lastUpdate = 0

        if not isCasting and not isChanneling then return end

        local udb = GetDB()
        if not udb then return end
        local now = GetTime()

        -- Update time remaining text
        if udb.showTimeRemaining ~= false then
            local remaining = castEndTime - now
            if remaining and remaining > 0 then
                timeText:SetText(string.format("%.1f", remaining))
            else
                timeText:SetText("")
            end
        end

        -- Update progress bar value
        if isCasting then
            local progress = (now - castStartTime) / castDuration
            progressBar:SetValue(math.min(progress, 1))
        elseif isChanneling then
            local progress = (castEndTime - now) / castDuration
            progressBar:SetValue(math.max(progress, 0))
        end

        -- Update important cast glow
        if castBarFrame._importantGlow then
            if isImportantCast and udb.highlightImportant then
                local c = udb.importantColor
                if c then
                    castBarFrame._importantGlow:SetBackdropBorderColor(c.r, c.g, c.b, 1)
                else
                    castBarFrame._importantGlow:SetBackdropBorderColor(0.0, 0.8, 0.8, 1)
                end
                castBarFrame._importantGlow:Show()
            else
                castBarFrame._importantGlow:Hide()
            end
        end

        -- Update bar color based on interrupt cooldown
        local interruptSpellId = GetInterruptSpellId()
        if interruptSpellId then
            local cdDuration = C_Spell.GetSpellCooldownDuration(interruptSpellId)
            if cdDuration then
                local isReady = cdDuration:IsZero()
                if isReady then
                    local c = udb.barReadyColor
                    progressBar:SetStatusBarColor(c.r, c.g, c.b)
                else
                    local c = udb.barCdColor
                    progressBar:SetStatusBarColor(c.r, c.g, c.b)
                end

                -- Hide on CD option
                if udb.hideOnCooldown and not isReady then
                    castBarFrame:Hide()
                    return
                end
            end
        end

        -- Update interrupt tick
        if udb.showInterruptTick ~= false and interruptSpellId then
            local cdDuration = C_Spell.GetSpellCooldownDuration(interruptSpellId)
            if cdDuration and not cdDuration:IsZero() then
                local cdRemaining = cdDuration:GetSeconds()
                if castDuration > 0 and cdRemaining > 0 and cdRemaining < castDuration then
                    local tickProgress = cdRemaining / castDuration
                    interruptBar:SetValue(tickProgress)
                    tickTexture:Show()
                else
                    tickTexture:Hide()
                end
            else
                tickTexture:Hide()
            end
        else
            tickTexture:Hide()
        end
    end)

    UpdateLayout(db)
end

-------------------------------------------------------------------------------
-- Lock / Unlock
-------------------------------------------------------------------------------

local function SetLocked(locked)
    if not castBarFrame then return end
    local db = GetDB()
    if not db then return end

    db.locked = locked

    if locked then
        castBarFrame:EnableMouse(false)
        resizeHandle:EnableMouse(false)
        resizeHandle:Hide()
        -- If not casting, hide the bar
        if not isCasting and not isChanneling then
            castBarFrame:Hide()
        end
    else
        castBarFrame:EnableMouse(true)
        resizeHandle:EnableMouse(true)
        resizeHandle:Show()
        ShowPreview(db)
    end
end

-------------------------------------------------------------------------------
-- Cast Tracking
-------------------------------------------------------------------------------

local function StartCast()
    local db = GetDB()
    if not db or not db.enabled then return end
    if not db.locked then return end -- In preview/unlock mode
    if not instanceAllowed then return end
    if not castBarFrame then CreateCastBarFrame() end

    local name, text, texture, startTimeMs, endTimeMs, isTradeSkill, castID, notInterruptible, spellId = UnitCastingInfo("focus")
    if not name then return end

    -- Hide for friendly targets if option set
    if db.hideFriendlyCasts and UnitIsFriend("player", "focus") then return end

    local durationMs = UnitCastingDuration("focus")
    if not durationMs or issecretvalue(durationMs) or durationMs <= 0 then return end
    if issecretvalue(startTimeMs) or issecretvalue(endTimeMs) then return end
    local duration = durationMs / 1000

    isCasting = true
    isChanneling = false
    isImportantCast = spellId and not issecretvalue(spellId) and C_Spell.IsSpellImportant(spellId) or false
    castStartTime = startTimeMs / 1000
    castEndTime = endTimeMs / 1000
    castDuration = duration

    progressBar:SetMinMaxValues(0, 1)
    progressBar:SetValue(0)
    interruptBar:SetMinMaxValues(0, 1)
    interruptBar:SetValue(0)

    -- Icon
    if db.showIcon ~= false and texture then
        iconFrame.tex:SetTexture(texture)
        iconFrame:Show()
    else
        iconFrame:Hide()
    end

    -- Spell name
    if db.showSpellName ~= false then
        spellNameText:SetText(name)
    end

    -- Bar color default
    local rC = db.barReadyColor
    progressBar:SetStatusBarColor(rC.r, rC.g, rC.b)

    -- Shield icon & non-interruptible coloring
    -- notInterruptible is a SECRET value: pass directly, never store or compare
    if db.showShieldIcon then
        shieldIcon:SetAlphaFromBoolean(notInterruptible)
    else
        shieldIcon:SetAlpha(0)
    end

    if db.colorNonInterrupt then
        local nC = db.nonIntColor
        progressBar:GetStatusBarTexture():SetVertexColorFromBoolean(notInterruptible, nC.r, nC.g, nC.b, 1)
    end

    castBarFrame:Show()
end

local function StartChannel()
    local db = GetDB()
    if not db or not db.enabled then return end
    if not db.locked then return end
    if not instanceAllowed then return end
    if not castBarFrame then CreateCastBarFrame() end

    local name, text, texture, startTimeMs, endTimeMs, isTradeSkill, notInterruptible, spellId, _, numStages = UnitChannelInfo("focus")
    if not name then return end

    -- Hide for friendly targets if option set
    if db.hideFriendlyCasts and UnitIsFriend("player", "focus") then return end

    local durationMs = UnitChannelDuration("focus")
    if not durationMs or issecretvalue(durationMs) or durationMs <= 0 then return end
    if issecretvalue(startTimeMs) or issecretvalue(endTimeMs) then return end
    local duration = durationMs / 1000

    isCasting = false
    isChanneling = true
    isImportantCast = spellId and not issecretvalue(spellId) and C_Spell.IsSpellImportant(spellId) or false
    castStartTime = startTimeMs / 1000
    castEndTime = endTimeMs / 1000
    castDuration = duration

    progressBar:SetMinMaxValues(0, 1)
    progressBar:SetValue(1)
    interruptBar:SetMinMaxValues(0, 1)
    interruptBar:SetValue(0)

    -- Icon
    if db.showIcon ~= false and texture then
        iconFrame.tex:SetTexture(texture)
        iconFrame:Show()
    else
        iconFrame:Hide()
    end

    -- Spell name
    if db.showSpellName ~= false then
        spellNameText:SetText(name)
    end

    -- Bar color default
    local rC = db.barReadyColor
    progressBar:SetStatusBarColor(rC.r, rC.g, rC.b)

    -- Shield icon & non-interruptible coloring (SECRET value)
    if db.showShieldIcon then
        shieldIcon:SetAlphaFromBoolean(notInterruptible)
    else
        shieldIcon:SetAlpha(0)
    end

    if db.colorNonInterrupt then
        local nC = db.nonIntColor
        progressBar:GetStatusBarTexture():SetVertexColorFromBoolean(notInterruptible, nC.r, nC.g, nC.b, 1)
    end

    castBarFrame:Show()
end

local function StopCast()
    isCasting = false
    isChanneling = false
    isImportantCast = false
    castEndTime = 0
    castStartTime = 0
    castDuration = 0
    if castBarFrame then
        castBarFrame:Hide()
        if castBarFrame._importantGlow then
            castBarFrame._importantGlow:Hide()
        end
    end
    if shieldIcon then
        shieldIcon:SetAlpha(0)
    end
    if tickTexture then
        tickTexture:Hide()
    end
end

local function CheckFocusCast()
    StopCast()
    if not UnitExists("focus") then return end

    local name = UnitCastingInfo("focus")
    if name then
        StartCast()
        return
    end

    name = UnitChannelInfo("focus")
    if name then
        StartChannel()
    end
end

-------------------------------------------------------------------------------
-- Instance Filtering
-------------------------------------------------------------------------------

local function UpdateInstanceFilter()
    local db = GetDB()
    if not db then return end
    local _, instanceType = GetInstanceInfo()
    local filter = db.showInInstances
    instanceAllowed = filter and filter[instanceType] or false

    if not instanceAllowed then
        StopCast()
    end
end

-------------------------------------------------------------------------------
-- Public API
-------------------------------------------------------------------------------

function LWT:UpdateFocusCastBar()
    local db = GetDB()
    if not db then return end
    if not castBarFrame then return end
    UpdateLayout(db)
    if not db.locked then
        ShowPreview(db)
    end
end

function LWT:SetFocusCastBarLocked(locked)
    SetLocked(locked)
end

function LWT:ResetFocusCastBarPosition()
    if not castBarFrame then return end
    local db = GetDB()
    if db then
        db.pos = nil
    end
    castBarFrame:ClearAllPoints()
    castBarFrame:SetPoint("CENTER", UIParent, "CENTER", 0, -150)
end

-------------------------------------------------------------------------------
-- Event Frame
-------------------------------------------------------------------------------

local loader = CreateFrame("Frame", "LWT_FocusCastBar_Events")
loader:RegisterEvent("PLAYER_LOGIN")
loader:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
loader:RegisterEvent("PLAYER_ENTERING_WORLD")
loader:RegisterEvent("PLAYER_FOCUS_CHANGED")
loader:RegisterUnitEvent("UNIT_SPELLCAST_START", "focus")
loader:RegisterUnitEvent("UNIT_SPELLCAST_STOP", "focus")
loader:RegisterUnitEvent("UNIT_SPELLCAST_FAILED", "focus")
loader:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", "focus")
loader:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", "focus")
loader:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", "focus")
loader:RegisterUnitEvent("UNIT_SPELLCAST_DELAYED", "focus")
loader:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_UPDATE", "focus")
loader:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTIBLE", "focus")
loader:RegisterUnitEvent("UNIT_SPELLCAST_NOT_INTERRUPTIBLE", "focus")
loader:RegisterUnitEvent("UNIT_SPELLCAST_EMPOWER_START", "focus")
loader:RegisterUnitEvent("UNIT_SPELLCAST_EMPOWER_STOP", "focus")
loader:RegisterUnitEvent("UNIT_SPELLCAST_EMPOWER_UPDATE", "focus")

loader:SetScript("OnEvent", function(_, event, ...)
    local db = GetDB()

    if event == "PLAYER_LOGIN" then
        if not db then return end
        CreateCastBarFrame()
        if not db.locked then
            ShowPreview(db)
        end
        UpdateInstanceFilter()
        return
    end

    if event == "PLAYER_SPECIALIZATION_CHANGED" then
        cachedInterruptSpellId = nil
        cachedSpecId = nil
        return
    end

    if event == "PLAYER_ENTERING_WORLD" then
        UpdateInstanceFilter()
        CheckFocusCast()
        return
    end

    if event == "PLAYER_FOCUS_CHANGED" then
        if not db or not db.enabled then return end
        if not db.locked then return end
        CheckFocusCast()
        return
    end

    -- All remaining events are UNIT_SPELLCAST_* for focus
    if not db or not db.enabled then return end
    if not db.locked then return end
    if not instanceAllowed then return end
    if LanternHandles() then
        if castBarFrame then castBarFrame:Hide() end
        return
    end

    if event == "UNIT_SPELLCAST_START" then
        StartCast()
    elseif event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_INTERRUPTED" then
        StopCast()
    elseif event == "UNIT_SPELLCAST_CHANNEL_START" then
        StartChannel()
    elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" then
        StopCast()
    elseif event == "UNIT_SPELLCAST_DELAYED" or event == "UNIT_SPELLCAST_CHANNEL_UPDATE" then
        CheckFocusCast()
    elseif event == "UNIT_SPELLCAST_INTERRUPTIBLE" or event == "UNIT_SPELLCAST_NOT_INTERRUPTIBLE" then
        if isCasting then
            StartCast()
        elseif isChanneling then
            StartChannel()
        end
    elseif event == "UNIT_SPELLCAST_EMPOWER_START" then
        StartChannel()
    elseif event == "UNIT_SPELLCAST_EMPOWER_STOP" then
        StopCast()
    elseif event == "UNIT_SPELLCAST_EMPOWER_UPDATE" then
        CheckFocusCast()
    end
end)
