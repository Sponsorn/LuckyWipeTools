local ADDON_NAME, LWT = ...

local COMM_PREFIX = "LanternCA"
local COMM_VERSION = 1

-- Defer display to Lantern's ConsumableAlerts if loaded and enabled
local function LanternHandles()
    local Lantern = _G.Lantern
    if (Lantern and Lantern.modules and Lantern.modules["ConsumableAlerts"]
        and Lantern.modules["ConsumableAlerts"].enabled) then
        return true
    end
    return false
end

-- Tracked consumable spell IDs -> display labels
local CONSUMABLE_SPELLS = {
    -- Feasts
    [1259656] = "a Blooming Feast. Eat up!",
    [1259657] = "a Quel'dorei Medley. Eat up!",
    [1259658] = "a Harandar Celebration. Eat up!",
    [1259659] = "a Silvermoon Parade. Eat up!",
    [1278909] = "a Hearty Blooming Feast. Eat up!",
    [1278915] = "a Hearty Quel'dorei Medley. Eat up!",
    [1278929] = "a Hearty Harandar Celebration. Eat up!",
    [1278895] = "a Hearty Silvermoon Parade. Eat up!",
    -- Cauldrons
    [1240019] = "a Cauldron of Sin'dorei Flasks. Flask up!",
    [1240225] = "a Voidlight Potion Cauldron. Grab your potions!",
    -- Warlock
    [29893]   = "a Soulwell. Come get your cookies!",
    -- Repair
    [199109]  = "an Auto-Hammer. Repair up!",
    [67826]   = "Jeeves. Repair up!",
}

local activeMessages = {}

local function GetDB()
    return LWT.db and LWT.db.consumables or {}
end

local function ShowMessages()
    if #activeMessages == 0 then return end
    local text = table.concat(activeMessages, "\n")
    if LWT.consumablesAlert then
        LWT.consumablesAlert:Fire(text)
    end
end

local function ClearMessages()
    wipe(activeMessages)
end

local function AddMessage(msg)
    table.insert(activeMessages, msg)
    ShowMessages()
end

-------------------------------------------------------------------------------
-- Addon Communication
-------------------------------------------------------------------------------

local function BroadcastConsumable(spellID)
    if not IsInGroup() then return end
    local channel = IsInRaid() and "RAID" or "PARTY"
    C_ChatInfo.SendAddonMessage(COMM_PREFIX, tostring(COMM_VERSION) .. ":" .. tostring(spellID), channel)
end

local function OnSpellCastSucceeded(unit, castGUID, spellID)
    if not spellID or issecretvalue(spellID) then return end
    if unit ~= "player" then return end

    local db = GetDB()
    if not db.enabled then return end
    if not IsInGroup() then return end

    local label = CONSUMABLE_SPELLS[spellID]
    if not label then return end
    if LanternHandles() then return end

    BroadcastConsumable(spellID)
end

local function OnAddonMessage(prefix, message, channel, sender)
    if prefix ~= COMM_PREFIX then return end

    local db = GetDB()
    if not db.enabled then return end
    if LanternHandles() then return end

    -- Parse message: "version:spellID"
    local version, spellIDStr = strsplit(":", message, 2)
    if not version or not spellIDStr then return end
    if tonumber(version) ~= COMM_VERSION then return end

    local spellID = tonumber(spellIDStr)
    if not spellID then return end

    local label = CONSUMABLE_SPELLS[spellID]
    if not label then return end

    local caster = Ambiguate(sender, "short")

    AddMessage(caster .. " placed " .. label)
end

-------------------------------------------------------------------------------
-- Event Frame
-------------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame", "LWT_ConsumablesEventFrame")
eventFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
eventFrame:RegisterEvent("CHAT_MSG_ADDON")

eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        OnSpellCastSucceeded(...)
    elseif event == "CHAT_MSG_ADDON" then
        OnAddonMessage(...)
    end
end)

-- Clear stacked messages when the alert fades/hides
-- Hook into the alert system's fade completion after it's created
local hookFrame = CreateFrame("Frame", "LWT_ConsumablesClearHook")
hookFrame:RegisterEvent("PLAYER_LOGIN")
hookFrame:SetScript("OnEvent", function()
    if LWT.consumablesAlert then
        -- Poll: if alert is hidden and we have messages, clear them
        C_Timer.NewTicker(0.5, function()
            if #activeMessages > 0 then
                local alertFrame = _G["LWT_AlertFrame_consumables"]
                if alertFrame and not alertFrame:IsShown() then
                    ClearMessages()
                end
            end
        end)
    end
    hookFrame:UnregisterEvent("PLAYER_LOGIN")
end)
