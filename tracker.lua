local ADDON_NAME, LWT = ...

local trackerFrame = CreateFrame("Frame", "LWT_TrackerFrame")
local anchorIDs = {}  -- track registered anchors for cleanup
local soundIDs = {}   -- track registered sounds for cleanup
local debugLog = {}    -- debug log entries

local function DebugLog(msg)
    local timestamp = GetTime()
    table.insert(debugLog, string.format("[%.1f] %s", timestamp, msg))
end

-- Create an anchor frame for each private aura
-- The frame must be shown for the private aura system to work.
-- We try multiple detection methods and log which ones fire.
local function CreateAuraAnchor(config)
    local anchorFrame = CreateFrame("Frame", "LWT_AuraAnchor_" .. config.spellID, UIParent)
    anchorFrame:SetSize(1, 1)
    anchorFrame:SetPoint("CENTER")
    anchorFrame:Show()

    local hasAura = false
    local lastChildCount = 0

    -- Method 1: OnUpdate child detection
    anchorFrame:SetScript("OnUpdate", function(self)
        local childCount = select("#", self:GetChildren())

        if childCount ~= lastChildCount then
            DebugLog(config.key .. " child count changed: " .. lastChildCount .. " -> " .. childCount)
            lastChildCount = childCount
        end

        local auraActive = childCount > 0

        if auraActive and not hasAura then
            hasAura = true
            DebugLog(config.key .. " DETECTED via children")
            if LWT:IsEncounterEnabled(config.key) then
                local text = config.getText()
                LWT:FireAlert(text)
            end
        elseif not auraActive and hasAura then
            hasAura = false
            DebugLog(config.key .. " aura FADED (children removed)")
        end
    end)

    -- Method 2: OnShow (in case parent gets shown/hidden)
    anchorFrame:SetScript("OnShow", function()
        DebugLog(config.key .. " OnShow fired")
    end)

    -- Method 3: OnSizeChanged
    anchorFrame:SetScript("OnSizeChanged", function(self, w, h)
        DebugLog(config.key .. " OnSizeChanged: " .. w .. "x" .. h)
    end)

    -- Method 4: OnEvent — check if any child fires OnShow
    anchorFrame:HookScript("OnUpdate", function(self)
        local children = { self:GetChildren() }
        for i, child in ipairs(children) do
            if not child._lwtHooked then
                child._lwtHooked = true
                DebugLog(config.key .. " hooked child " .. i)
                child:HookScript("OnShow", function()
                    DebugLog(config.key .. " child " .. i .. " OnShow fired")
                end)
                child:HookScript("OnHide", function()
                    DebugLog(config.key .. " child " .. i .. " OnHide fired")
                end)
            end
        end
    end)

    return anchorFrame
end

function LWT:RegisterAuras()
    self:UnregisterAuras() -- clean up any existing

    for _, config in ipairs(self.privateAuras) do
        -- Visual alert via anchor
        local anchorFrame = CreateAuraAnchor(config)

        local anchorID = C_UnitAuras.AddPrivateAuraAnchor({
            unitToken = "player",
            auraIndex = config.spellID,
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
            DebugLog("Registered anchor for " .. config.key .. " (spell " .. config.spellID .. ") anchorID=" .. anchorID)
        else
            DebugLog("FAILED to register anchor for " .. config.key)
        end

        -- Sound alert via AddPrivateAuraSounds (proven reliable)
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
                DebugLog("Registered sound for " .. config.key .. " soundID=" .. soundID)
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
