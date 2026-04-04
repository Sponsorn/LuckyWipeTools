local ADDON_NAME, LWT = ...

-- =========================================================
-- Encounter tracker — alerts when an enemy mob targets you
-- Scans nameplate units for their targets during encounters
-- =========================================================

local SCAN_INTERVAL = 0.1

local scanTicker = nil
local inEncounter = false
local wasFixated = false

local function GetDB()
    return LWT.db and LWT.db.tracker or {}
end

local function ScanForFixate()
    for i = 1, 40 do
        local unit = "nameplate" .. i
        if UnitExists(unit) and not UnitIsFriend("player", unit) then
            local target = unit .. "target"
            if UnitExists(target) and UnitIsUnit(target, "player") then
                return true
            end
        end
    end
    return false
end

local function OnTick()
    local fixated = ScanForFixate()

    if LWT.trackerAlert then
        if fixated and not wasFixated then
            LWT.trackerAlert:Show("FIXATED ON YOU!")
        elseif not fixated and wasFixated then
            LWT.trackerAlert:Hide()
        end
    end
    wasFixated = fixated
end

local function StartScanning()
    if scanTicker then return end
    scanTicker = C_Timer.NewTicker(SCAN_INTERVAL, OnTick)
end

local function StopScanning()
    if scanTicker then
        scanTicker:Cancel()
        scanTicker = nil
    end
    if wasFixated and LWT.trackerAlert then
        LWT.trackerAlert:Hide()
    end
    wasFixated = false
end

-- Test mode
local testMode = false
function LWT:ToggleTrackerTest()
    if testMode then
        testMode = false
        StopScanning()
        self:Print("Tracker test stopped.")
    else
        testMode = true
        StartScanning()
        self:Print("Tracker test started — will alert if any mob targets you. Type /lwt test tracker to stop.")
    end
end

-- Event frame
local frame = CreateFrame("Frame", "LWT_TrackerFrame")
frame:RegisterEvent("ENCOUNTER_START")
frame:RegisterEvent("ENCOUNTER_END")

frame:SetScript("OnEvent", function(_, event)
    if event == "ENCOUNTER_START" then
        local db = GetDB()
        if db.enabled then
            inEncounter = true
            StartScanning()
        end
    elseif event == "ENCOUNTER_END" then
        inEncounter = false
        StopScanning()
    end
end)
