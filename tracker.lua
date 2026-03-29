local ADDON_NAME, LWT = ...

local trackerFrame = CreateFrame("Frame", "LWT_TrackerFrame")
local anchorIDs = {}  -- track registered anchors for cleanup
local soundIDs = {}   -- track registered sounds for cleanup

-- Create a hidden anchor frame for each private aura
-- When WoW applies the aura, it shows the anchor frame, which triggers our OnShow
local function CreateAuraAnchor(config)
    local anchorFrame = CreateFrame("Frame", "LWT_AuraAnchor_" .. config.spellID, UIParent)
    anchorFrame:SetSize(1, 1)
    anchorFrame:SetPoint("CENTER")
    anchorFrame:Hide()

    -- When WoW shows this frame (private aura applied), fire the alert
    anchorFrame:SetScript("OnShow", function()
        if not LWT:IsEncounterEnabled(config.key) then return end
        local text = config.getText()
        LWT:FireAlert(text)
    end)

    return anchorFrame
end

function LWT:RegisterAuras()
    self:UnregisterAuras() -- clean up any existing

    for _, config in ipairs(self.privateAuras) do
        -- Visual alert via anchor (OnShow fires our custom text)
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
        end

        -- Sound alert via AddPrivateAuraSounds (proven reliable, used by BigWigs/NSRT)
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
            end
        end
    end
end

function LWT:UnregisterAuras()
    for _, entry in ipairs(anchorIDs) do
        C_UnitAuras.RemovePrivateAuraAnchor(entry.id)
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
        -- Defer until out of combat
        trackerFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end
    self:RegisterAuras()
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
