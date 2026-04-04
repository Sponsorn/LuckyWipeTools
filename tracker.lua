local ADDON_NAME, LWT = ...

-- =========================================================
-- Nameplate target tracker — shows who enemy mobs are targeting
-- Works by scanning nameplate units for their targets
-- Supports Plater and default Blizzard nameplates
-- =========================================================

local SCAN_INTERVAL = 0.1
local FONT_PATH = "Interface\\AddOns\\LuckyWipeTools\\Fonts\\Roboto-Bold.ttf"

local scanTicker = nil
local inEncounter = false
local nameplateTexts = {} -- [nameplate frame] = fontString
local wasFixated = false
local usePlater = false

local function GetDB()
    return LWT.db and LWT.db.tracker or {}
end

-- Detect Plater at runtime
local function CheckPlater()
    usePlater = (_G.Plater and C_AddOns.IsAddOnLoaded("Plater")) and true or false
end

-- Get the best frame to anchor text to for a nameplate unit
local function GetAnchorFrame(unit)
    local baseFrame = C_NamePlate.GetNamePlateForUnit(unit)
    if not baseFrame then return nil end

    -- Plater: use its unitFrame which renders on top
    if usePlater and baseFrame.unitFrame then
        return baseFrame.unitFrame
    end

    return baseFrame
end

-- Get or create a font string for a nameplate frame
local function GetOrCreateText(anchorFrame)
    if nameplateTexts[anchorFrame] then
        return nameplateTexts[anchorFrame]
    end

    local text = anchorFrame:CreateFontString(nil, "OVERLAY")
    text:SetFont(FONT_PATH, 14, "OUTLINE")
    text:SetPoint("BOTTOM", anchorFrame, "TOP", 0, 2)
    text:SetDrawLayer("OVERLAY", 7)
    text:Hide()

    nameplateTexts[anchorFrame] = text
    return text
end

-- Hide all nameplate texts
local function HideAll()
    for _, text in pairs(nameplateTexts) do
        text:Hide()
    end
end

local function ScanNameplates()
    if not testMode then
        local db = GetDB()
        if not db.enabled then return end
    end

    HideAll()

    local playerFixated = false

    for i = 1, 40 do
        local unit = "nameplate" .. i
        if UnitExists(unit) and not UnitIsFriend("player", unit) then
            local target = unit .. "target"
            if UnitExists(target) then
                local targetName = UnitName(target)
                if targetName and not issecretvalue(targetName) then
                    local anchorFrame = GetAnchorFrame(unit)
                    if anchorFrame then
                        local text = GetOrCreateText(anchorFrame)
                        local classBase = UnitClassBase(target)
                        local classColor = classBase and C_ClassColor.GetClassColor(classBase)
                        local colored = classColor and classColor:WrapTextInColorCode(targetName) or targetName
                        text:SetText(colored)
                        text:Show()
                    end

                    if UnitIsUnit(target, "player") then
                        playerFixated = true
                    end
                end
            end
        end
    end

    -- Show/hide persistent alert based on fixate state
    if LWT.trackerAlert then
        if playerFixated and not wasFixated then
            LWT.trackerAlert:Show("FIXATED ON YOU!")
        elseif not playerFixated and wasFixated then
            LWT.trackerAlert:Hide()
        end
    end
    wasFixated = playerFixated
end

local function StartScanning()
    if scanTicker then return end
    CheckPlater()
    scanTicker = C_Timer.NewTicker(SCAN_INTERVAL, ScanNameplates)
end

local function StopScanning()
    if scanTicker then
        scanTicker:Cancel()
        scanTicker = nil
    end
    HideAll()
    if wasFixated and LWT.trackerAlert then
        LWT.trackerAlert:Hide()
    end
    wasFixated = false
end

-- Test mode toggle
local testMode = false
function LWT:ToggleTrackerTest()
    if testMode then
        testMode = false
        StopScanning()
        self:Print("Tracker test stopped.")
    else
        testMode = true
        StartScanning()
        self:Print("Tracker test started — target names shown above enemy nameplates. Type /lwt test tracker to stop.")
    end
end

-- Event frame
local frame = CreateFrame("Frame", "LWT_TrackerFrame")
frame:RegisterEvent("ENCOUNTER_START")
frame:RegisterEvent("ENCOUNTER_END")

frame:SetScript("OnEvent", function(_, event, ...)
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
