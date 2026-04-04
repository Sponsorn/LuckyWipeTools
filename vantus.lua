local ADDON_NAME, LWT = ...

local BUFF_SCAN_INTERVAL = 5
local TRADE_DISTANCE = 2 -- CheckInteractDistance type for trade

-- Difficulty IDs
local HEROIC_DIFF = 15
local MYTHIC_DIFF = 16

-- State
local rosterData = {}    -- [playerName] = { name, class, unit, requested, noBuff }
local pendingRequest = false
local commQueue = {}
local commsRestricted = false
local tradeTarget = nil

local frame, titleText
local rows = {}
local MAX_ROWS = 40
local buffTicker = nil
local rosterMoverBg = nil

local function GetDB()
    return LWT.db and LWT.db.vantus or {}
end

-- =========================================================
-- Comm restriction handling
-- =========================================================
local function IsCommRestricted()
    if C_RestrictedActions and C_RestrictedActions.IsAddOnRestrictionActive then
        for restrictionType = 1, 2 do
            if C_RestrictedActions.IsAddOnRestrictionActive(restrictionType) then
                return true
            end
        end
    end
    return false
end

local function FlushCommQueue()
    for _, msg in ipairs(commQueue) do
        C_ChatInfo.SendAddonMessage("LWT", msg, "RAID")
    end
    wipe(commQueue)
end

local function SendComm(message)
    if IsCommRestricted() then
        table.insert(commQueue, message)
        return
    end
    C_ChatInfo.SendAddonMessage("LWT", message, "RAID")
end

-- =========================================================
-- Buff scanning
-- =========================================================
local function HasVantusBuff(unit)
    for i = 1, 40 do
        local aura = C_UnitAuras.GetBuffDataByIndex(unit, i)
        if not aura then break end
        if aura.name and aura.name:find("Vantus Rune") then
            return true
        end
    end
    return false
end

local function ScanBuffs()
    local db = GetDB()
    if not db.enabled or not db.showRoster then return end
    if not IsInRaid() then return end

    local _, _, difficultyID = GetInstanceInfo()
    local validDifficulty = (difficultyID == HEROIC_DIFF and db.difficulties.heroic)
        or (difficultyID == MYTHIC_DIFF and db.difficulties.mythic)
    if not validDifficulty then return end

    local changed = false

    local inRaid = {}
    for i = 1, GetNumGroupMembers() do
        local unit = "raid" .. i
        if UnitExists(unit) and not UnitIsUnit(unit, "player") then
            local name = UnitName(unit)
            if name and not issecretvalue(name) then
                inRaid[name] = true
                local hasBuff = HasVantusBuff(unit)

                if hasBuff then
                    if rosterData[name] then
                        rosterData[name] = nil
                        changed = true
                    end
                else
                    if rosterData[name] then
                        if not rosterData[name].noBuff then
                            rosterData[name].noBuff = true
                            rosterData[name].unit = unit
                            changed = true
                        end
                    else
                        local _, class = UnitClass(unit)
                        rosterData[name] = {
                            name = name,
                            class = class,
                            unit = unit,
                            requested = false,
                            noBuff = true,
                        }
                        changed = true
                    end
                end
            end
        end
    end

    local selfName = UnitName("player")
    if selfName and HasVantusBuff("player") and rosterData[selfName] then
        rosterData[selfName] = nil
        changed = true
    end

    for name in pairs(rosterData) do
        if not inRaid[name] and name ~= selfName then
            rosterData[name] = nil
            changed = true
        end
    end

    if changed then
        LWT:UpdateVantusRoster()
    end
end

-- =========================================================
-- Comm receiving
-- =========================================================
local function OnAddonMessage(prefix, message, channel, sender)
    if prefix ~= "LWT" then return end

    local db = GetDB()
    if not db.enabled then return end

    local shortName = Ambiguate(sender, "short")

    if message == "VANTUS:REQUEST" then
        -- Ignore if player already has the buff
        local unit
        for i = 1, GetNumGroupMembers() do
            local u = "raid" .. i
            if UnitExists(u) then
                local name = UnitName(u)
                if name and not issecretvalue(name) and name == shortName then
                    unit = u
                    break
                end
            end
        end
        if unit and HasVantusBuff(unit) then return end

        if rosterData[shortName] then
            rosterData[shortName].requested = true
        else
            local class
            if unit then
                _, class = UnitClass(unit)
            end
            rosterData[shortName] = {
                name = shortName,
                class = class,
                unit = unit,
                requested = true,
                noBuff = false,
            }
        end
        LWT:UpdateVantusRoster()

    elseif message == "VANTUS:CANCEL" then
        if rosterData[shortName] then
            rosterData[shortName].requested = false
            if not rosterData[shortName].noBuff then
                rosterData[shortName] = nil
            end
        end
        LWT:UpdateVantusRoster()

    elseif message == "VANTUS:CLEAR" then
        wipe(rosterData)
        pendingRequest = false
        LWT:UpdateVantusRoster()
    end
end

-- =========================================================
-- Request toggle
-- =========================================================
function LWT:ToggleVantusRequest()
    local db = GetDB()
    if not db.enabled then
        self:Print("Vantus Runes module is disabled.")
        return
    end

    if not IsInRaid() then
        self:Print("You must be in a raid to request a vantus rune.")
        return
    end

    if pendingRequest then
        SendComm("VANTUS:CANCEL")
        pendingRequest = false
        if self.vantusAlert then
            self.vantusAlert:Fire("|cffff9900Vantus rune request cancelled.|r")
        end
    else
        SendComm("VANTUS:REQUEST")
        pendingRequest = true
        if self.vantusAlert then
            self.vantusAlert:Fire("|cff00ff00Vantus rune requested.|r")
        end
    end
end

-- =========================================================
-- Roster frame
-- =========================================================
local function CreateVantusFrame()
    if frame then return end

    frame = CreateFrame("Frame", "LWT_VantusFrame", UIParent, "BackdropTemplate")
    frame:SetSize(200, 40)
    frame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -200, -300)
    frame:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    frame:SetBackdropColor(0.1, 0.1, 0.1, 0.85)
    frame:SetFrameStrata("MEDIUM")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetClampedToScreen(true)
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, _, x, y = self:GetPoint()
        local db = GetDB()
        db.rosterPosition = { point = point, x = x, y = y }
    end)

    local pos = GetDB().rosterPosition
    if pos and pos.point then
        frame:ClearAllPoints()
        frame:SetPoint(pos.point, UIParent, pos.point, pos.x, pos.y)
    end

    frame:Hide()

    titleText = frame:CreateFontString("LWT_VantusTitle", "OVERLAY", "GameFontNormalSmall")
    titleText:SetPoint("TOP", 0, -6)
    titleText:SetText("Vantus Runes")
    titleText:SetTextColor(1, 0.82, 0)

    for i = 1, MAX_ROWS do
        local row = CreateFrame("Button", "LWT_VantusRow_" .. i, frame)
        row:SetHeight(14)
        row:SetPoint("TOPLEFT", 8, -20 - (i - 1) * 14)
        row:SetPoint("RIGHT", frame, "RIGHT", -8, 0)
        row:RegisterForClicks("AnyUp")

        row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.text:SetPoint("LEFT")
        row.text:SetPoint("RIGHT", -14, 0)
        row.text:SetJustifyH("LEFT")

        row.range = row:CreateTexture(nil, "OVERLAY")
        row.range:SetSize(8, 8)
        row.range:SetPoint("RIGHT", 0, 0)

        row.highlight = row:CreateTexture(nil, "HIGHLIGHT")
        row.highlight:SetAllPoints()
        row.highlight:SetColorTexture(1, 1, 1, 0.08)

        row:SetScript("OnClick", function(self, button)
            if button == "RightButton" then
                local name = self.playerName
                if name then
                    rosterData[name] = nil
                    LWT:UpdateVantusRoster()
                end
            elseif button == "LeftButton" then
                local unit = self.unit
                if unit then
                    InitiateTrade(Ambiguate(UnitName(unit) or "", "short"))
                end
            end
        end)

        row:Hide()
        rows[i] = row
    end
end

function LWT:UpdateVantusRoster()
    if not frame then CreateVantusFrame() end

    local db = GetDB()
    if not db.enabled or not db.showRoster then
        frame:Hide()
        return
    end

    local _, _, difficultyID = GetInstanceInfo()
    local validDifficulty = (difficultyID == HEROIC_DIFF and db.difficulties.heroic)
        or (difficultyID == MYTHIC_DIFF and db.difficulties.mythic)
    if not validDifficulty then
        frame:Hide()
        return
    end

    local sorted = {}
    for _, info in pairs(rosterData) do
        table.insert(sorted, info)
    end
    table.sort(sorted, function(a, b)
        if a.requested ~= b.requested then return a.requested end
        return a.name < b.name
    end)

    for i = 1, MAX_ROWS do
        rows[i]:Hide()
        rows[i].playerName = nil
        rows[i].unit = nil
    end

    if #sorted == 0 then
        frame:Hide()
        return
    end

    titleText:SetText("Vantus Runes (" .. #sorted .. ")")

    for i, info in ipairs(sorted) do
        if i > MAX_ROWS then break end
        local color = info.class and C_ClassColor.GetClassColor(info.class)
        local nameText = color and color:WrapTextInColorCode(info.name) or info.name

        if info.requested then
            nameText = nameText .. "  |cffffcc00Requested|r"
        end

        rows[i].text:SetText(nameText)
        rows[i].playerName = info.name
        rows[i].unit = info.unit

        local inRange = info.unit and CheckInteractDistance(Ambiguate(info.name, "short"), TRADE_DISTANCE)
        if inRange then
            rows[i].range:SetColorTexture(0, 1, 0, 0.8)
        else
            rows[i].range:SetColorTexture(1, 0, 0, 0.5)
        end

        rows[i]:Show()
    end

    local rowCount = math.min(#sorted, MAX_ROWS)
    frame:SetHeight(24 + rowCount * 14)
    frame:Show()
end

-- =========================================================
-- Roster mover
-- =========================================================
function LWT:EnableVantusMover()
    if not frame then CreateVantusFrame() end

    frame:ClearAllPoints()
    local pos = GetDB().rosterPosition
    if pos and pos.point then
        frame:SetPoint(pos.point, UIParent, pos.point, pos.x, pos.y)
    else
        frame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -200, -300)
    end

    for i = 1, MAX_ROWS do rows[i]:Hide() end
    titleText:SetText("|cffff9900Drag to move|r")
    frame:SetHeight(40)
    frame:Show()

    if not rosterMoverBg then
        rosterMoverBg = frame:CreateTexture("LWT_VantusMoverBg", "BACKGROUND")
        rosterMoverBg:SetAllPoints()
        rosterMoverBg:SetColorTexture(0, 0, 0, 0.4)
    end
    rosterMoverBg:Show()
end

function LWT:DisableVantusMover()
    if not frame then return end
    if rosterMoverBg then rosterMoverBg:Hide() end
    frame:Hide()
    ScanBuffs()
end

-- =========================================================
-- Trade tracking
-- =========================================================
local function OnTradeShow()
    local target = TradeFrameRecipientNameText and TradeFrameRecipientNameText:GetText()
    if not target or target == "" then return end
    if target:find("%(%)") then
        target = target:sub(1, -4)
    end
    tradeTarget = Ambiguate(target, "short")
end

local function OnTradeComplete(msgID)
    if msgID ~= LE_GAME_ERR_TRADE_COMPLETE then return end
    if not tradeTarget then return end

    if rosterData[tradeTarget] then
        rosterData[tradeTarget] = nil
        LWT:UpdateVantusRoster()
    end
    tradeTarget = nil
end

local function OnTradeClosed()
    tradeTarget = nil
end

-- =========================================================
-- Encounter handling
-- =========================================================
local function OnEncounterEnd(encounterID, encounterName, difficultyID, groupSize, success)
    if success == 1 then
        SendComm("VANTUS:CLEAR")
        wipe(rosterData)
        pendingRequest = false
        LWT:UpdateVantusRoster()
    end
end

-- =========================================================
-- Event frame
-- =========================================================
local eventFrame = CreateFrame("Frame", "LWT_VantusEventFrame")
eventFrame:RegisterEvent("CHAT_MSG_ADDON")
eventFrame:RegisterEvent("TRADE_SHOW")
eventFrame:RegisterEvent("TRADE_CLOSED")
eventFrame:RegisterEvent("UI_INFO_MESSAGE")
eventFrame:RegisterEvent("ENCOUNTER_END")
eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("ADDON_RESTRICTION_STATE_CHANGED")

eventFrame:SetScript("OnEvent", function(_, event, ...)
    local db = GetDB()
    if not db.enabled then
        if frame then frame:Hide() end
        return
    end

    if event == "CHAT_MSG_ADDON" then
        OnAddonMessage(...)

    elseif event == "TRADE_SHOW" then
        OnTradeShow()

    elseif event == "TRADE_CLOSED" then
        OnTradeClosed()

    elseif event == "UI_INFO_MESSAGE" then
        OnTradeComplete(...)

    elseif event == "ENCOUNTER_END" then
        OnEncounterEnd(...)

    elseif event == "ADDON_RESTRICTION_STATE_CHANGED" then
        local restrictionType, state = ...
        if restrictionType == 1 or restrictionType == 2 then
            commsRestricted = IsCommRestricted()
            if not commsRestricted then
                FlushCommQueue()
            end
        end

    elseif event == "GROUP_ROSTER_UPDATE" then
        if not IsInRaid() then
            wipe(rosterData)
            pendingRequest = false
            if buffTicker then buffTicker:Cancel(); buffTicker = nil end
            if frame then frame:Hide() end
            return
        end
        if not buffTicker then
            buffTicker = C_Timer.NewTicker(BUFF_SCAN_INTERVAL, ScanBuffs)
        end
        ScanBuffs()

    elseif event == "ZONE_CHANGED_NEW_AREA" or event == "PLAYER_ENTERING_WORLD" then
        if IsInRaid() then
            if not buffTicker then
                buffTicker = C_Timer.NewTicker(BUFF_SCAN_INTERVAL, ScanBuffs)
            end
            ScanBuffs()
        else
            if buffTicker then buffTicker:Cancel(); buffTicker = nil end
            wipe(rosterData)
            pendingRequest = false
            if frame then frame:Hide() end
        end
    end
end)
