local ADDON_NAME, LWT = ...

local trackerFrame = CreateFrame("Frame", "LWT_TrackerFrame")
local anchorIDs = {}  -- track registered anchors for cleanup
local soundIDs = {}   -- track registered sounds for cleanup
local debugLog = {}   -- debug log entries

-- How many private aura slots to watch
local MAX_AURA_SLOTS = 6

local function DebugLog(msg)
    local timestamp = GetTime()
    table.insert(debugLog, string.format("[%.1f] %s", timestamp, msg))
end

-- Build a set of tracked spell IDs for fast lookup
local function GetTrackedSpellIDs()
    local spells = {}
    for _, config in ipairs(LWT.privateAuras) do
        if LWT:IsEncounterEnabled(config.key) then
            spells[config.spellID] = config
        end
    end
    return spells
end

function LWT:RegisterAuras()
    self:UnregisterAuras() -- clean up any existing

    local trackedSpells = GetTrackedSpellIDs()

    -- Register private aura anchors by SLOT INDEX (not spell ID)
    -- Blizzard fills slots 1..N with whatever private auras are active
    -- We watch each slot and check the child icon's spell via OnUpdate
    for i = 1, MAX_AURA_SLOTS do
        local anchorFrame = CreateFrame("Frame", "LWT_AuraAnchor_" .. i, UIParent)
        anchorFrame:SetSize(1, 1)
        anchorFrame:SetPoint("CENTER")
        anchorFrame:SetFrameStrata("HIGH")
        anchorFrame:Show()

        local hasChild = false
        local alerted = false

        -- Detect when Blizzard creates/removes the child icon
        anchorFrame:SetScript("OnUpdate", function(self)
            local childCount = select("#", self:GetChildren())
            local childNow = childCount > 0

            if childNow and not hasChild then
                hasChild = true
                DebugLog("Slot " .. i .. " child appeared (count=" .. childCount .. ")")

                -- We can't read which spell this is from the child,
                -- but if ANY private aura slot activates, fire alerts
                -- for all tracked spells (the sound system handles per-spell)
                for spellID, config in pairs(trackedSpells) do
                    if not alerted then
                        alerted = true
                        local text = config.getText()
                        LWT:FireAlert(text)
                        DebugLog("Fired alert for " .. config.key)
                    end
                end
            elseif not childNow and hasChild then
                hasChild = false
                alerted = false
                DebugLog("Slot " .. i .. " child removed")
            end
        end)

        -- Also log other events for debugging
        anchorFrame:SetScript("OnShow", function()
            DebugLog("Slot " .. i .. " OnShow fired")
        end)
        anchorFrame:SetScript("OnSizeChanged", function(self, w, h)
            DebugLog("Slot " .. i .. " OnSizeChanged: " .. w .. "x" .. h)
        end)

        local anchorID = C_UnitAuras.AddPrivateAuraAnchor({
            unitToken = "player",
            auraIndex = i,
            parent = anchorFrame,
            showCountdownFrame = false,
            showCountdownNumbers = false,
            iconInfo = {
                iconAnchor = {
                    point = "CENTER",
                    relativeTo = anchorFrame,
                    relativePoint = "CENTER",
                    offsetX = 0,
                    offsetY = 0,
                },
                iconWidth = 1,
                iconHeight = 1,
            },
        })

        if anchorID then
            table.insert(anchorIDs, { id = anchorID, frame = anchorFrame })
            DebugLog("Registered anchor slot " .. i .. " anchorID=" .. anchorID)
        else
            DebugLog("FAILED to register anchor slot " .. i)
            anchorFrame:Hide()
        end
    end

    -- Sound alerts via AddPrivateAuraSounds (per spell ID — proven reliable)
    for _, config in ipairs(self.privateAuras) do
        local soundFile = self:GetSoundFile()
        if soundFile then
            local soundID
            if type(soundFile) == "string" then
                soundID = C_UnitAuras.AddPrivateAuraAppliedSound({
                    spellID = config.spellID,
                    unitToken = "player",
                    soundFileName = soundFile,
                    outputChannel = "master",
                })
            elseif type(soundFile) == "number" then
                soundID = C_UnitAuras.AddPrivateAuraAppliedSound({
                    spellID = config.spellID,
                    unitToken = "player",
                    soundFileID = soundFile,
                    outputChannel = "master",
                })
            end
            if soundID then
                table.insert(soundIDs, soundID)
                DebugLog("Registered sound for " .. config.key .. " (spell " .. config.spellID .. ")")
            end
        end
    end
end

function LWT:UnregisterAuras()
    for _, entry in ipairs(anchorIDs) do
        C_UnitAuras.RemovePrivateAuraAnchor(entry.id)
        entry.frame:SetScript("OnUpdate", nil)
        entry.frame:SetScript("OnShow", nil)
        entry.frame:SetScript("OnSizeChanged", nil)
        entry.frame:Hide()
    end
    wipe(anchorIDs)

    for _, id in ipairs(soundIDs) do
        C_UnitAuras.RemovePrivateAuraAppliedSound(id)
    end
    wipe(soundIDs)
end

-- Re-register when sound settings change
function LWT:RefreshAuras()
    if InCombatLockdown() then
        trackerFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end
    self:RegisterAuras()
end

-- Print debug log
function LWT:PrintDebugLog()
    if #debugLog == 0 then
        self:Print("Debug log is empty. No events detected.")
        return
    end
    self:Print("--- Debug Log (" .. #debugLog .. " entries) ---")
    for _, entry in ipairs(debugLog) do
        self:Print(entry)
    end
    self:Print("--- End ---")
end

function LWT:ClearDebugLog()
    wipe(debugLog)
    self:Print("Debug log cleared.")
end

-- Register auras on login (must be done outside combat)
trackerFrame:RegisterEvent("PLAYER_LOGIN")
trackerFrame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        LWT:RegisterAuras()
    elseif event == "PLAYER_REGEN_ENABLED" then
        trackerFrame:UnregisterEvent("PLAYER_REGEN_ENABLED")
        LWT:RegisterAuras()
    end
end)
