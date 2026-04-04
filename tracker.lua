local ADDON_NAME, LWT = ...

-- Private aura test — watches all aura slots for any private aura on player
-- Shows alert when a private aura appears, hides when it's removed

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
                LWT:Print("Private aura detected (slot " .. i .. ")")
                if LWT.gatewayAlert then
                    LWT.gatewayAlert:Show("PRIVATE AURA - Slot " .. i)
                end
            elseif not childNow and hasChild then
                hasChild = false
                LWT:Print("Private aura removed (slot " .. i .. ")")
                if LWT.gatewayAlert then
                    LWT.gatewayAlert:Hide()
                end
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

local frame = CreateFrame("Frame", "LWT_PATestFrame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        RegisterAnchors()
        LWT:Print("Private aura test active — watching " .. MAX_AURA_SLOTS .. " slots")
    elseif event == "PLAYER_REGEN_ENABLED" then
        frame:UnregisterEvent("PLAYER_REGEN_ENABLED")
        RegisterAnchors()
    end
end)
