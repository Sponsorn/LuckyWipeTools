local ADDON_NAME, LWT = ...

-- Tracked consumable items (itemID -> label)
local CONSUMABLE_ITEMS = {
    [1259658] = "Harandar Celebration",
    [1278929] = "Hearty Harandar Celebration",
    [1240019] = "Flask Cauldron",
    [1240225] = "Potion Cauldron",
}

-- Resolved spell ID -> item label (built at runtime)
local spellToLabel = {}
local resolved = false

local function GetDB()
    return LWT.db and LWT.db.consumables or {}
end

-- Resolve item IDs to their "use" spell IDs
local function ResolveSpells()
    if resolved then return end
    local pending = 0
    for itemID, label in pairs(CONSUMABLE_ITEMS) do
        local spellName, spellID = C_Item.GetItemSpell(itemID)
        if spellID then
            spellToLabel[spellID] = label
        else
            -- Item not cached yet, request it
            pending = pending + 1
            C_Item.RequestLoadItemDataByID(itemID)
        end
    end
    if pending == 0 then
        resolved = true
    end
end

-- Retry resolution when item data arrives
local function OnItemDataLoaded(itemID)
    if not CONSUMABLE_ITEMS[itemID] then return end
    local spellName, spellID = C_Item.GetItemSpell(itemID)
    if spellID then
        spellToLabel[spellID] = CONSUMABLE_ITEMS[itemID]
    end
    -- Check if all resolved
    local allDone = true
    for id in pairs(CONSUMABLE_ITEMS) do
        local _, sid = C_Item.GetItemSpell(id)
        if not sid then
            allDone = false
            break
        end
    end
    resolved = allDone
end

local function OnSpellCastSucceeded(unit, castGUID, spellID)
    if not spellID or issecretvalue(spellID) then return end

    local db = GetDB()
    if not db.enabled then return end
    if InCombatLockdown() then return end
    if not IsInRaid() then return end

    local label = spellToLabel[spellID]
    if not label then return end

    local caster = UnitName(unit)
    if not caster or issecretvalue(caster) then return end

    if LWT.consumablesAlert then
        LWT.consumablesAlert:Fire(caster .. " placed " .. label)
    end
end

-- Event frame
local eventFrame = CreateFrame("Frame", "LWT_ConsumablesEventFrame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
eventFrame:RegisterEvent("ITEM_DATA_LOAD_RESULT")

eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LOGIN" then
        ResolveSpells()
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        OnSpellCastSucceeded(...)
    elseif event == "ITEM_DATA_LOAD_RESULT" then
        local itemID, success = ...
        if success then
            OnItemDataLoaded(itemID)
        end
    end
end)
