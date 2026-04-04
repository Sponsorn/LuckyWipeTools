local ADDON_NAME, LWT = ...

-- Defer to Lantern's SummonHelper if loaded and enabled (roster is part of it)
local function LanternHandles()
    local Lantern = _G.Lantern
    if (Lantern and Lantern.modules and Lantern.modules["SummonHelper"]
        and Lantern.modules["SummonHelper"].enabled) then
        return true
    end
    return false
end

local RITUAL_OF_SUMMONING = 698
local PORTAL_DURATION = 120
local POLL_INTERVAL = 2

local ticker = nil
local portalExpiry = 0
local lastOutside = {}
local pendingSummons = {}

local frame, titleText, portalText
local rows = {}
local MAX_ROWS = 40

local function CreateRosterFrame()
    if frame then return end

    frame = CreateFrame("Frame", "LWT_RosterFrame", UIParent, "BackdropTemplate")
    frame:SetSize(180, 40)
    frame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -200, -200)
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

    -- Restore saved position
    local pos = GetDB().rosterPosition
    if pos and pos.point then
        frame:ClearAllPoints()
        frame:SetPoint(pos.point, UIParent, pos.point, pos.x, pos.y)
    end

    frame:Hide()

    titleText = frame:CreateFontString("LWT_RosterTitle", "OVERLAY", "GameFontNormalSmall")
    titleText:SetPoint("TOP", 0, -6)
    titleText:SetText("Outside")
    titleText:SetTextColor(1, 0.82, 0)

    portalText = frame:CreateFontString("LWT_RosterPortal", "OVERLAY", "GameFontNormalSmall")
    portalText:SetTextColor(0.6, 0.2, 1)
    portalText:Hide()

    for i = 1, MAX_ROWS do
        local row = CreateFrame("Button", "LWT_RosterRow_" .. i, frame, "SecureActionButtonTemplate")
        row:SetHeight(14)
        row:SetPoint("TOPLEFT", 8, -20 - (i - 1) * 14)
        row:SetPoint("RIGHT", frame, "RIGHT", -8, 0)
        row:RegisterForClicks("AnyUp")
        row:SetAttribute("type1", "target")

        row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.text:SetAllPoints()
        row.text:SetJustifyH("LEFT")

        row.highlight = row:CreateTexture(nil, "HIGHLIGHT")
        row.highlight:SetAllPoints()
        row.highlight:SetColorTexture(1, 1, 1, 0.08)

        row:Hide()
        rows[i] = row
    end
end

local function UpdateDisplay(outside)
    if not frame then CreateRosterFrame() end

    local locked = InCombatLockdown()
    for i = 1, MAX_ROWS do
        rows[i]:Hide()
        if not locked then
            rows[i]:SetAttribute("unit", nil)
        end
    end
    portalText:Hide()

    if #outside == 0 then
        frame:Hide()
        return
    end

    titleText:SetText("Outside (" .. #outside .. ")")

    for i, info in ipairs(outside) do
        if i > MAX_ROWS then break end
        local color = info.class and C_ClassColor.GetClassColor(info.class)
        local nameText = color and color:WrapTextInColorCode(info.name) or info.name

        -- Append status indicator
        if info.offline then
            nameText = nameText .. "  |cff666666Offline|r"
        elseif info.summonStatus == Enum.SummonStatus.Pending then
            nameText = nameText .. "  |cffffcc00Summoning...|r"
        elseif info.summonStatus == Enum.SummonStatus.Accepted then
            nameText = nameText .. "  |cff00ff00Accepted|r"
        elseif info.summonStatus == Enum.SummonStatus.Declined then
            nameText = nameText .. "  |cffff2020Declined|r"
        end

        rows[i].text:SetText(nameText)
        if not locked then
            rows[i]:SetAttribute("unit", info.unit)
        end
        rows[i]:Show()
    end

    local rowCount = math.min(#outside, MAX_ROWS)
    local height = 24 + rowCount * 14

    -- Portal status
    if GetTime() < portalExpiry then
        portalText:SetText("Portal up! Click to summon")
        portalText:SetPoint("TOPLEFT", 8, -20 - rowCount * 14)
        portalText:Show()
        height = height + 16
    end

    frame:SetHeight(height)
    frame:Show()
end

local function GetDB()
    return LWT.db and LWT.db.summon or {}
end

local function Scan()
    if LanternHandles() then
        if frame then frame:Hide() end
        return
    end

    local db = GetDB()
    if not db.enabled then
        if frame then frame:Hide() end
        return
    end

    if not IsInRaid() then
        return
    end

    local db = GetDB()
    if db.showRoster == false then
        if frame then frame:Hide() end
        return
    end

    local playerMap = C_Map.GetBestMapForUnit("player")
    if not playerMap then return end

    local outside = {}

    for i = 1, GetNumGroupMembers() do
        local unit = "raid" .. i
        if UnitExists(unit) and not UnitIsUnit(unit, "player") then
            local name = UnitName(unit)
            if name and not issecretvalue(name) then
                local connected = UnitIsConnected(unit)
                local isOutside = false
                local isOffline = not connected

                if isOffline then
                    isOutside = true
                else
                    local memberMap = C_Map.GetBestMapForUnit(unit)
                    if not memberMap then
                        isOutside = true
                    elseif not issecretvalue(memberMap) and memberMap ~= playerMap then
                        isOutside = true
                    end
                end

                if isOutside then
                    local _, className = UnitClass(unit)
                    local summonStatus = C_IncomingSummon.IncomingSummonStatus(unit)
                    table.insert(outside, {
                        name = name,
                        class = className,
                        unit = unit,
                        summonStatus = summonStatus,
                        offline = isOffline,
                    })
                end
            end
        end
    end

    lastOutside = outside
    UpdateDisplay(outside)
end

-- Summon tracking (merged from summon.lua)
local function ScanSummons()
    if LanternHandles() then return end
    local db = GetDB()
    if not db.enabled then return end

    local prefix, count
    if IsInRaid() then
        prefix, count = "raid", GetNumGroupMembers()
    elseif IsInGroup() then
        prefix, count = "party", GetNumSubgroupMembers()
    else
        return
    end

    for i = 1, count do
        local unit = prefix .. i
        if UnitExists(unit) then
            local hasSum = C_IncomingSummon.HasIncomingSummon(unit)
            local status = C_IncomingSummon.IncomingSummonStatus(unit)

            local db = GetDB()
            if hasSum and status == Enum.SummonStatus.Pending and not pendingSummons[unit] then
                pendingSummons[unit] = true
            elseif not hasSum or status ~= Enum.SummonStatus.Pending then
                if pendingSummons[unit] then
                    local name = UnitName(unit)
                    if name and not issecretvalue(name) and db.showStatus ~= false and LWT.summonAlert then
                        if status == Enum.SummonStatus.Accepted then
                            LWT.summonAlert:Fire("|cff00ff00" .. name .. " accepted the summon.|r")
                        elseif status == Enum.SummonStatus.Declined then
                            LWT.summonAlert:Fire("|cffff2020" .. name .. " declined the summon.|r")
                        end
                    end
                end
                pendingSummons[unit] = nil
            end
        end
    end
end

-- Mover mode for roster frame
local rosterMoverBg = nil

function LWT:EnableRosterMover()
    if not frame then CreateRosterFrame() end

    frame:ClearAllPoints()
    local pos = GetDB().rosterPosition
    if pos and pos.point then
        frame:SetPoint(pos.point, UIParent, pos.point, pos.x, pos.y)
    else
        frame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -200, -200)
    end

    -- Show placeholder content
    for i = 1, MAX_ROWS do rows[i]:Hide() end
    portalText:Hide()
    titleText:SetText("|cffff9900Drag to move|r")
    frame:SetHeight(40)
    frame:Show()

    if not rosterMoverBg then
        rosterMoverBg = frame:CreateTexture("LWT_RosterMoverBg", "BACKGROUND")
        rosterMoverBg:SetAllPoints()
        rosterMoverBg:SetColorTexture(0, 0, 0, 0.4)
    end
    rosterMoverBg:Show()
end

function LWT:DisableRosterMover()
    if not frame then return end
    if rosterMoverBg then rosterMoverBg:Hide() end
    frame:Hide()
    -- Trigger a scan to restore normal state if in a raid
    Scan()
end

local rosterFrame = CreateFrame("Frame", "LWT_RosterEventFrame")
rosterFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
rosterFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
rosterFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
rosterFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
rosterFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
rosterFrame:RegisterEvent("INCOMING_SUMMON_CHANGED")

rosterFrame:SetScript("OnEvent", function(_, event, ...)
    if LanternHandles() then
        if frame then frame:Hide() end
        return
    end

    if event == "PLAYER_REGEN_DISABLED" then
        -- Stop polling but keep roster visible with last-known data
        if ticker then ticker:Cancel(); ticker = nil end
        return
    elseif event == "PLAYER_REGEN_ENABLED" then
        if IsInRaid() then
            if not ticker then
                ticker = C_Timer.NewTicker(POLL_INTERVAL, Scan)
            end
            Scan()
        end
        return
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local _, _, spellID = ...
        if spellID == RITUAL_OF_SUMMONING then
            portalExpiry = GetTime() + PORTAL_DURATION
            local db = GetDB()
            if db.showPortalPlaced ~= false then
                local unit = ...
                local caster = UnitName(unit)
                if caster and not issecretvalue(caster) and LWT.summonAlert then
                    LWT.summonAlert:Fire("|cff9b59b6" .. caster .. " placed a summoning portal!|r")
                end
            end
            UpdateDisplay(lastOutside)
        end
        return
    elseif event == "INCOMING_SUMMON_CHANGED" then
        ScanSummons()
        Scan()
        return
    end

    if not IsInRaid() then
        if ticker then ticker:Cancel(); ticker = nil end
        if frame then frame:Hide() end
        return
    end

    if not ticker and not InCombatLockdown() then
        ticker = C_Timer.NewTicker(POLL_INTERVAL, Scan)
    end
    Scan()
end)
