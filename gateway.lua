local ADDON_NAME, LWT = ...

-- Defer to Lantern's GatewayReady if loaded and enabled
local function LanternHandles()
    local Lantern = _G.Lantern
    if (Lantern and Lantern.modules and Lantern.modules["GatewayReady"]
        and Lantern.modules["GatewayReady"].enabled) then
        return true
    end
    return false
end

local POLL_INTERVAL = 0.1
local ticker = nil
local lastUsable = false

local function ShowGatewayAlert()
    local sys = LWT.gatewayAlert
    if not sys then return end
    sys:UpdateFont()
    sys:Show("|cff9b59b6GATEWAY READY|r")
end

local function HideGatewayAlert()
    local sys = LWT.gatewayAlert
    if not sys then return end
    sys:Hide()
end

local function CheckGateway()
    if LanternHandles() then
        if lastUsable then HideGatewayAlert() end
        lastUsable = false
        return
    end

    local db = LWT.db
    if not db or not db.gateway.enabled then
        if lastUsable then HideGatewayAlert() end
        lastUsable = false
        return
    end

    -- Must have the item
    local count = C_Item.GetItemCount(LWT.GATEWAY_ITEM_ID)
    if count == 0 then
        if lastUsable then HideGatewayAlert() end
        lastUsable = false
        return
    end

    -- Combat-only check
    if db.gateway.combatOnly and not InCombatLockdown() then
        if lastUsable then HideGatewayAlert() end
        lastUsable = false
        return
    end

    local isUsable = C_Item.IsUsableItem(LWT.GATEWAY_ITEM_ID)

    if isUsable and not lastUsable then
        ShowGatewayAlert()
    elseif not isUsable and lastUsable then
        HideGatewayAlert()
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
    if lastUsable then HideGatewayAlert() end
    lastUsable = false
end

-- Check if player has the Gateway item
function LWT:HasGatewayItem()
    return C_Item.GetItemCount(self.GATEWAY_ITEM_ID) > 0
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
        if LWT.db.gateway.enabled then
            StartPolling()
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
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
