local ADDON_NAME, LWT = ...

local POLL_INTERVAL = 0.1
local ticker = nil
local lastUsable = false

local function CheckGateway()
    local db = LWT.db
    if not db or not db.gateway.enabled then return end

    -- Must have the item
    local count = C_Item.GetItemCount(LWT.GATEWAY_ITEM_ID)
    if count == 0 then
        lastUsable = false
        return
    end

    -- Combat-only check
    if db.gateway.combatOnly and not InCombatLockdown() then
        lastUsable = false
        return
    end

    local isUsable = C_Item.IsUsableItem(LWT.GATEWAY_ITEM_ID)

    -- Alert on transition from not-usable to usable
    if isUsable and not lastUsable then
        if LWT.gatewayAlert then
            LWT.gatewayAlert:Fire("|cff9b59b6GATEWAY READY|r")
        end
    end

    lastUsable = isUsable
end

local function StartPolling()
    if ticker then return end
    ticker = C_Timer.NewTicker(POLL_INTERVAL, CheckGateway)
end

local function StopPolling()
    if ticker then
        ticker:Cancel()
        ticker = nil
    end
    lastUsable = false
end

-- Start/stop based on combat state and settings
local gatewayFrame = CreateFrame("Frame", "LWT_GatewayFrame")
gatewayFrame:RegisterEvent("PLAYER_LOGIN")
gatewayFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
gatewayFrame:RegisterEvent("PLAYER_REGEN_ENABLED")

gatewayFrame:SetScript("OnEvent", function(_, event)
    if not LWT.db then return end

    if event == "PLAYER_LOGIN" then
        if not LWT.db.gateway.combatOnly then
            StartPolling()
        end
    elseif event == "PLAYER_REGEN_DISABLED" then
        -- Entering combat
        if LWT.db.gateway.enabled then
            StartPolling()
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        -- Leaving combat
        if LWT.db.gateway.combatOnly then
            StopPolling()
        end
    end
end)

function LWT:RefreshGateway()
    StopPolling()
    if not self.db.gateway.enabled then return end
    if self.db.gateway.combatOnly and not InCombatLockdown() then return end
    StartPolling()
end
