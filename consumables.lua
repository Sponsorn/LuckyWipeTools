local ADDON_NAME, LWT = ...

-- Tracked consumable keywords and their display labels
-- We match against the spell name from UNIT_SPELLCAST_SUCCEEDED
local CONSUMABLE_PATTERNS = {
    { pattern = "Hearty Harandar Celebration",  label = "a Hearty Harandar Celebration. Eat up!" },
    { pattern = "Harandar Celebration",         label = "a Harandar Celebration. Eat up!" },
    { pattern = "Voidlight Potion Cauldron",    label = "a Voidlight Potion Cauldron. Grab your potions!" },
    { pattern = "Cauldron of Sin'dorei Flasks", label = "a Cauldron of Sin'dorei Flasks. Flask up!" },
    { pattern = "Create Soulwell",              label = "a Soulwell. Come get your cookies!" },
    { pattern = "Soulwell",                    label = "a Soulwell. Come get your cookies!" },
}

-- Sort longest patterns first so "Hearty Harandar Celebration" matches before "Harandar Celebration"
table.sort(CONSUMABLE_PATTERNS, function(a, b)
    return #a.pattern > #b.pattern
end)

-- Fallback: known spell IDs for consumables that might not match by name
local SPELL_ID_LABELS = {
    [29893]  = "a Soulwell. Come get your cookies!",  -- Create Soulwell
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

local function MatchConsumable(spellID)
    -- Check spell ID directly first
    if SPELL_ID_LABELS[spellID] then
        return SPELL_ID_LABELS[spellID]
    end
    -- Then match by name
    local name = C_Spell.GetSpellName(spellID)
    if not name then return nil end
    for _, entry in ipairs(CONSUMABLE_PATTERNS) do
        if name:find(entry.pattern, 1, true) then
            return entry.label
        end
    end
    return nil
end

local function OnSpellCastSucceeded(unit, castGUID, spellID)
    if not spellID or issecretvalue(spellID) then return end

    local db = GetDB()
    if not db.enabled then return end
    if InCombatLockdown() then return end
    if not IsInRaid() then return end

    local label = MatchConsumable(spellID)
    if not label then return end

    local caster = UnitName(unit)
    if not caster or issecretvalue(caster) then return end

    AddMessage(caster .. " placed " .. label)
end

-- Event frame
local eventFrame = CreateFrame("Frame", "LWT_ConsumablesEventFrame")
eventFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")

eventFrame:SetScript("OnEvent", function(_, event, ...)
    OnSpellCastSucceeded(...)
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
