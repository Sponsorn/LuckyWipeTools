local ADDON_NAME, LWT = ...

-- Instance types and difficulty IDs for settings UI
local INSTANCE_TYPES = {
    { key = "raid",    label = "Raids" },
    { key = "party",   label = "Dungeons" },
    { key = "arena",   label = "Arena" },
    { key = "pvp",     label = "Battlegrounds" },
    { key = "scenario", label = "Scenarios" },
}

local DIFFICULTIES = {
    -- Raids
    { key = "lfr",         label = "LFR",             difficultyID = 17, instanceType = "raid" },
    { key = "raidNormal",  label = "Normal Raid",     difficultyID = 14, instanceType = "raid" },
    { key = "raidHeroic",  label = "Heroic Raid",     difficultyID = 15, instanceType = "raid" },
    { key = "raidMythic",  label = "Mythic Raid",     difficultyID = 16, instanceType = "raid" },
    -- Dungeons
    { key = "dungeonNormal",  label = "Normal Dungeon",     difficultyID = 1,  instanceType = "party" },
    { key = "dungeonHeroic",  label = "Heroic Dungeon",     difficultyID = 2,  instanceType = "party" },
    { key = "dungeonMythic",  label = "Mythic0",             difficultyID = 23, instanceType = "party" },
    { key = "dungeonKeystone", label = "Mythic+",           difficultyID = 8,  instanceType = "party" },
    { key = "dungeonFollower", label = "Follower Dungeon",  difficultyID = 205, instanceType = "party" },
}

local isLogging = false

-- Build a unique key for the current instance + difficulty
local function GetInstanceKey()
    local _, _, difficultyID, _, _, _, _, instanceID = GetInstanceInfo()
    if not instanceID or instanceID == 0 then return nil end
    return instanceID .. ":" .. difficultyID
end

local function GetDB()
    return LWT.db and LWT.db.combatLog
end

-- Check if advancedCombatLogging CVar is enabled
local function CheckAdvancedLogging()
    local acl = C_CVar.GetCVar("advancedCombatLogging")
    if acl ~= "1" then
        LWT:Print("|cffff9900Advanced Combat Logging is disabled.|r Log data may be incomplete for WarcraftLogs.")
        LWT:Print("Enable it in System > Network > Advanced Combat Logging, or type: |cffffcc00/console advancedCombatLogging 1|r")
        return false
    end
    return true
end

-- Check if the instance type + difficulty passes the global filters
local function PassesGlobalFilters(instanceType, difficultyID)
    local db = GetDB()
    if not db then return false end

    -- Check instance type
    if not db.instanceTypes[instanceType] then return false end

    -- For raid/party, check difficulty filters
    if instanceType == "raid" or instanceType == "party" then
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
        end
    end

    return true
end

local function StartLogging()
    if not LoggingCombat() then
        CheckAdvancedLogging()
        LoggingCombat(true)
        LWT:Print("Combat log started.")
    end
    isLogging = true
end

local function StopLogging()
    if LoggingCombat() then
        LoggingCombat(false)
        LWT:Print("Combat log stopped.")
    end
    isLogging = false
end

local function UpdateLogging()
    local db = GetDB()
    if not db or not db.enabled then
        if isLogging then StopLogging() end
        return
    end

    local _, instanceType, difficultyID, difficultyName, _, _, _, instanceID = GetInstanceInfo()
    local zoneName = GetInstanceInfo() -- first return is name

    -- Outside an instance
    if not instanceType or instanceType == "none" then
        if isLogging then StopLogging() end
        return
    end

    -- Doesn't pass global type/difficulty filters
    if not PassesGlobalFilters(instanceType, difficultyID) then
        if isLogging then StopLogging() end
        return
    end

    local key = GetInstanceKey()
    if not key then return end

    db.instances = db.instances or {}
    local saved = db.instances[key]

    if saved and saved.enabled == true then
        -- Previously enabled for this instance
        StartLogging()
    elseif saved and saved.enabled == false then
        -- Previously disabled for this instance
        if isLogging then StopLogging() end
        -- Remind them how to re-enable
        local name = saved.name or zoneName or "this instance"
        local diff = saved.diffName or difficultyName or ""
        if diff ~= "" then name = name .. " (" .. diff .. ")" end
        LWT:Print("Combat logging is disabled for " .. name .. ". Type |cffffcc00/lwt log|r to enable.")
    else
        -- First time in this instance — auto-enable and remember
        db.instances[key] = {
            enabled = true,
            name = zoneName or "",
            diffName = difficultyName or "",
        }
        StartLogging()
        local name = zoneName or "Unknown"
        local diff = difficultyName or ""
        if diff ~= "" then name = name .. " (" .. diff .. ")" end
        LWT:Print("First time in " .. name .. " — combat logging enabled. Type |cffffcc00/lwt log|r to toggle.")
    end
end

-- Toggle logging for the current instance (called from /lwt log)
function LWT:ToggleInstanceLogging()
    local db = GetDB()
    if not db then
        self:Print("Combat log feature is not configured.")
        return
    end

    local key = GetInstanceKey()
    if not key then
        self:Print("Not in an instance.")
        return
    end

    local _, instanceType, difficultyID, difficultyName = GetInstanceInfo()
    local zoneName = GetInstanceInfo()

    db.instances = db.instances or {}
    local saved = db.instances[key]
    local wasEnabled = saved and saved.enabled

    db.instances[key] = {
        enabled = not wasEnabled,
        name = zoneName or (saved and saved.name) or "",
        diffName = difficultyName or (saved and saved.diffName) or "",
    }

    local name = db.instances[key].name
    local diff = db.instances[key].diffName
    if diff ~= "" then name = name .. " (" .. diff .. ")" end

    if db.instances[key].enabled then
        StartLogging()
        self:Print("Combat logging enabled for " .. name .. ".")
    else
        StopLogging()
        self:Print("Combat logging disabled for " .. name .. ".")
    end
end

local frame = CreateFrame("Frame", "LWT_CombatLogFrame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
frame:RegisterEvent("CHALLENGE_MODE_START")

frame:SetScript("OnEvent", function(_, event)
    local db = GetDB()
    if not db or not db.enabled then return end

    if event == "PLAYER_LOGIN" then
        -- Sync with manual /combatlog state
        isLogging = LoggingCombat()
        return
    end

    if event == "CHALLENGE_MODE_START" then
        -- M+ key started — force enable if feature is on
        if db then
            local key = GetInstanceKey()
            if key then
                db.instances = db.instances or {}
                local saved = db.instances[key]
                if not saved or saved.enabled ~= false then
                    StartLogging()
                end
            end
        end
        return
    end

    -- PLAYER_ENTERING_WORLD / ZONE_CHANGED_NEW_AREA
    -- Sync state first (user may have toggled /combatlog manually)
    isLogging = LoggingCombat()
    C_Timer.After(1, UpdateLogging)
end)

-- Expose for settings
LWT.combatLogInstanceTypes = INSTANCE_TYPES
LWT.combatLogDifficulties = DIFFICULTIES
