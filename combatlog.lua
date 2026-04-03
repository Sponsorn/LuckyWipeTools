local ADDON_NAME, LWT = ...

-- Instance types and difficulty IDs we care about
local INSTANCE_TYPES = {
    { key = "raid",    label = "Raids" },
    { key = "party",   label = "Dungeons" },
    { key = "arena",   label = "Arena" },
    { key = "pvp",     label = "Battlegrounds" },
    { key = "scenario", label = "Scenarios" },
}

-- Difficulty filters (only shown for raid/party)
local DIFFICULTIES = {
    -- Raids
    { key = "lfr",         label = "LFR",             difficultyID = 17, instanceType = "raid" },
    { key = "raidNormal",  label = "Normal Raid",     difficultyID = 14, instanceType = "raid" },
    { key = "raidHeroic",  label = "Heroic Raid",     difficultyID = 15, instanceType = "raid" },
    { key = "raidMythic",  label = "Mythic Raid",     difficultyID = 16, instanceType = "raid" },
    -- Dungeons
    { key = "dungeonNormal",  label = "Normal Dungeon",     difficultyID = 1,  instanceType = "party" },
    { key = "dungeonHeroic",  label = "Heroic Dungeon",     difficultyID = 2,  instanceType = "party" },
    { key = "dungeonMythic",  label = "Mythic Dungeon",     difficultyID = 23, instanceType = "party" },
    { key = "dungeonKeystone", label = "Mythic Keystone",   difficultyID = 8,  instanceType = "party" },
    { key = "dungeonFollower", label = "Follower Dungeon",  difficultyID = 205, instanceType = "party" },
}

local wasLogging = false

local function ShouldLog()
    local db = LWT.db and LWT.db.combatLog
    if not db or not db.enabled then return false end

    local _, instanceType, difficultyID = GetInstanceInfo()

    -- Check if instance type is enabled
    if not db.instanceTypes[instanceType] then return false end

    -- For raid/party, check difficulty filters
    if instanceType == "raid" or instanceType == "party" then
        -- If no difficulties are configured yet, default to all enabled
        local hasDiffFilters = false
        for _, diff in ipairs(DIFFICULTIES) do
            if diff.instanceType == instanceType and db.difficulties[diff.key] ~= nil then
                hasDiffFilters = true
                break
            end
        end

        if hasDiffFilters then
            for _, diff in ipairs(DIFFICULTIES) do
                if diff.instanceType == instanceType and diff.difficultyID == difficultyID then
                    return db.difficulties[diff.key] ~= false
                end
            end
            -- Unknown difficulty for this type, allow it
            return true
        end
    end

    return true
end

local function UpdateLogging()
    if ShouldLog() then
        if not LoggingCombat() then
            LoggingCombat(true)
            LWT:Print("Combat log started.")
        end
        wasLogging = true
    else
        if wasLogging and LoggingCombat() then
            LoggingCombat(false)
            LWT:Print("Combat log stopped.")
        end
        wasLogging = false
    end
end

local frame = CreateFrame("Frame", "LWT_CombatLogFrame")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")

frame:SetScript("OnEvent", function()
    -- Short delay to let GetInstanceInfo() update
    C_Timer.After(1, UpdateLogging)
end)

-- Expose for settings
LWT.combatLogInstanceTypes = INSTANCE_TYPES
LWT.combatLogDifficulties = DIFFICULTIES
