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
local wasFixated = false

local function GetDB()
    return LWT.db and LWT.db.tracker or {}
end


-- Overlay pool — positioned manually each scan tick
local overlayPool = {}
local overlayCount = 0

local function GetOverlay(index)
    if overlayPool[index] then return overlayPool[index] end

    local db = GetDB()
    local fontSize = db.nameplateFontSize or 14

    local overlay = CreateFrame("Frame", "LWT_NPOverlay_" .. index, UIParent)
    overlay:SetSize(200, 20)
    overlay:SetFrameStrata("TOOLTIP")

    local text = overlay:CreateFontString(nil, "OVERLAY")
    text:SetFont(FONT_PATH, fontSize, "OUTLINE")
    text:SetPoint("CENTER")
    text:Show()

    overlay.text = text
    overlay:Hide()

    overlayPool[index] = overlay
    return overlay
end

-- Update font size on all existing overlays
local function RefreshFontSize()
    local db = GetDB()
    local fontSize = db.nameplateFontSize or 14
    for _, overlay in pairs(overlayPool) do
        overlay.text:SetFont(FONT_PATH, fontSize, "OUTLINE")
    end
end

function LWT:RefreshTrackerFontSize()
    RefreshFontSize()
end

-- Hide all overlays
local function HideAll()
    for _, overlay in pairs(overlayPool) do
        overlay:Hide()
    end
end

local function ScanNameplates()
    if not testMode then
        local db = GetDB()
        if not db.enabled then return end
    end

    HideAll()

    local playerFixated = false
    local found = 0
    local shown = 0

    for i = 1, 40 do
        local unit = "nameplate" .. i
        if UnitExists(unit) and not UnitIsFriend("player", unit) then
            found = found + 1
            local target = unit .. "target"
            local hasTarget = UnitExists(target)

            if hasTarget then
                local targetName = UnitName(target)
                if targetName and not issecretvalue(targetName) then
                    local baseFrame = C_NamePlate.GetNamePlateForUnit(unit)
                    if baseFrame then
                        shown = shown + 1
                        local overlay = GetOverlay(shown)
                        local classBase = UnitClassBase(target)
                        local classColor = classBase and C_ClassColor.GetClassColor(classBase)
                        local colored = classColor and classColor:WrapTextInColorCode(targetName) or targetName
                        overlay.text:SetText(colored)
                        overlay:ClearAllPoints()
                        overlay:SetPoint("BOTTOM", baseFrame, "TOP", 0, 0)
                        overlay:Show()
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
        LWT:Print("Tracker stopped")
    end
end)
