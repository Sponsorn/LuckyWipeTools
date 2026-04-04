local ADDON_NAME, LWT = ...

-- =========================================================
-- Approach 1: Private Aura Anchors (watches aura slots on player)
-- =========================================================
local MAX_AURA_SLOTS = 6
local anchorIDs = {}

local function RegisterAnchors()
    for _, entry in ipairs(anchorIDs) do
        C_UnitAuras.RemovePrivateAuraAnchor(entry.id)
        entry.frame:SetScript("OnUpdate", nil)
        entry.frame:Hide()
    end
    wipe(anchorIDs)

    for i = 1, MAX_AURA_SLOTS do
        local anchorFrame = CreateFrame("Frame", "LWT_PATest_" .. i, UIParent)
        anchorFrame:SetSize(1, 1)
        anchorFrame:SetPoint("CENTER")
        anchorFrame:Show()

        local hasChild = false

        anchorFrame:SetScript("OnUpdate", function(self)
            local childCount = select("#", self:GetChildren())
            local childNow = childCount > 0

            if childNow and not hasChild then
                hasChild = true
                LWT:Print("|cff00ff00[ANCHOR]|r Private aura detected (slot " .. i .. ")")
            elseif not childNow and hasChild then
                hasChild = false
                LWT:Print("|cff00ff00[ANCHOR]|r Private aura removed (slot " .. i .. ")")
            end
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
        else
            anchorFrame:Hide()
        end
    end
end

-- =========================================================
-- Approach 2: UNIT_AURA event (watches aura changes on player)
-- =========================================================
local inEncounter = false

local function OnUnitAura(unit, updateInfo)
    if unit ~= "player" then return end
    if not updateInfo or not updateInfo.addedAuras then return end

    for _, auraData in ipairs(updateInfo.addedAuras) do
        local isHarmful = auraData.isHarmful
        local name = auraData.name
        local spellId = auraData.spellId
        local dispelName = auraData.dispelName
        local isSecret = spellId and issecretvalue(spellId)

        local nameStr = (name and not issecretvalue(name)) and name or "?"
        local idStr = isSecret and "SECRET" or tostring(spellId or "nil")
        local dispelStr = dispelName and tostring(dispelName) or "none"
        local harmStr = isHarmful and "HARMFUL" or "beneficial"

        LWT:Print("|cffff9900[AURA]|r " .. harmStr .. " '" .. nameStr .. "' id=" .. idStr .. " dispel=" .. dispelStr)
    end
end

-- =========================================================
-- Event frame
-- =========================================================
local frame = CreateFrame("Frame", "LWT_PATestFrame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("UNIT_AURA")
frame:RegisterEvent("ENCOUNTER_START")
frame:RegisterEvent("ENCOUNTER_END")

frame:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LOGIN" then
        RegisterAnchors()
        LWT:Print("Private aura test active:")
        LWT:Print("  |cff00ff00[ANCHOR]|r = AddPrivateAuraAnchor (slot detection)")
        LWT:Print("  |cffff9900[AURA]|r = UNIT_AURA event (aura metadata)")
    elseif event == "UNIT_AURA" then
        if inEncounter then
            OnUnitAura(...)
        end
    elseif event == "ENCOUNTER_START" then
        inEncounter = true
        LWT:Print("Encounter started — logging both approaches")
    elseif event == "ENCOUNTER_END" then
        inEncounter = false
        LWT:Print("Encounter ended")
    end
end)
