local ADDON_NAME, LWT = ...

-- =========================================================
-- Nameplate target tracker — shows who enemy mobs are targeting
-- Works by scanning nameplate units for their targets
-- =========================================================

local SCAN_INTERVAL = 0.1
local VORASIUS_ENCOUNTER = 3177
local FONT_PATH = "Interface\\AddOns\\LuckyWipeTools\\Fonts\\Roboto-Bold.ttf"

local scanTicker = nil
local inEncounter = false
local nameplateTexts = {} -- [nameplate frame] = fontString
local wasFixated = false

local function GetDB()
    return LWT.db and LWT.db.tracker or {}
end

-- Get or create a font string for a nameplate frame
local function GetOrCreateText(nameplate)
    if nameplateTexts[nameplate] then
        return nameplateTexts[nameplate]
    end

    local text = nameplate:CreateFontString(nil, "OVERLAY")
    text:SetFont(FONT_PATH, 14, "OUTLINE")
    text:SetPoint("BOTTOM", nameplate, "TOP", 0, 2)
    text:Hide()

    nameplateTexts[nameplate] = text
    return text
end

-- Hide all nameplate texts
local function HideAll()
    for nameplate, text in pairs(nameplateTexts) do
        text:Hide()
    end
end

local function ScanNameplates()
    local db = GetDB()
    if not db.enabled then return end

    -- Hide all first, then show active ones
    HideAll()

    local playerFixated = false

    for i = 1, 40 do
        local unit = "nameplate" .. i
        if UnitExists(unit) and not UnitIsFriend("player", unit) then
            local target = unit .. "target"
            if UnitExists(target) then
                local targetName = UnitName(target)
                if targetName and not issecretvalue(targetName) then
                    local nameplate = C_NamePlate.GetNamePlateForUnit(unit)
                    if nameplate then
                        local text = GetOrCreateText(nameplate)
                        local classBase = UnitClassBase(target)
                        local classColor = classBase and C_ClassColor.GetClassColor(classBase)
                        local colored = classColor and classColor:WrapTextInColorCode(targetName) or targetName
                        text:SetText(colored)
                        text:Show()
                    end

                    -- Check if targeting the player
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

-- Event frame
local frame = CreateFrame("Frame", "LWT_TrackerFrame")
frame:RegisterEvent("ENCOUNTER_START")
frame:RegisterEvent("ENCOUNTER_END")

frame:SetScript("OnEvent", function(_, event, ...)
    if event == "ENCOUNTER_START" then
        local encounterID = ...
        if encounterID == VORASIUS_ENCOUNTER then
            local db = GetDB()
            if db.enabled then
                inEncounter = true
                StartScanning()
            end
        end
    elseif event == "ENCOUNTER_END" then
        inEncounter = false
        StopScanning()
    end
end)
