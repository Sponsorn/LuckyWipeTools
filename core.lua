local ADDON_NAME, LWT = ...
_G.LuckyWipeTools = LWT

LWT.name = ADDON_NAME

-- Fallback fonts (used when LibSharedMedia is not available)
LWT.fallbackFonts = {
    { name = "Friz Quadrata", path = "Fonts\\FRIZQT__.TTF" },
    { name = "Arial Narrow", path = "Fonts\\ARIALN.TTF" },
    { name = "Morpheus", path = "Fonts\\MORPHEUS.TTF" },
    { name = "Skurri", path = "Fonts\\skurri.TTF" },
}

-- Get sorted font list from LibSharedMedia or fallback
function LWT:GetFontList()
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    if LSM then
        local fonts = {}
        for _, name in ipairs(LSM:List("font")) do
            table.insert(fonts, { name = name, path = LSM:Fetch("font", name) })
        end
        return fonts
    end
    return self.fallbackFonts
end

-- Gateway Shard config
LWT.GATEWAY_ITEM_ID = 188152

-- DB setup
local ALERT_DEFAULTS = {
    sound = false,
    soundName = nil,
    duration = 3,
    fontSize = 36,
    fontName = "Friz Quadrata",
    position = {},
}

local defaults = {
    gateway = {
        enabled = true,
        combatOnly = true,
        alert = ALERT_DEFAULTS,
    },
    summon = {
        enabled = true,
        showPortalPlaced = true,
        showStatus = true,
        showRoster = true,
        rosterPosition = {},
        alert = ALERT_DEFAULTS,
    },
    itemSplitter = {
        enabled = true,
        popupPos = nil,
    },
    combatLog = {
        enabled = false,
        instanceTypes = {
            raid = true,
            party = true,
        },
        difficulties = {}, -- [key] = true/false, defaults to all enabled
        instances = {},     -- [instanceID:difficultyID] = { enabled, name, diffName }
    },
    vantus = {
        enabled = true,
        showRoster = true,
        difficulties = {
            heroic = true,
            mythic = true,
        },
        rosterPosition = {},
        alert = ALERT_DEFAULTS,
    },
}

local function DeepCopyDefaults(src, dst)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            DeepCopyDefaults(v, dst[k])
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
end

function LWT:SetupDB()
    if not _G.LuckyWipeToolsDB then
        _G.LuckyWipeToolsDB = {}
    end
    self.db = _G.LuckyWipeToolsDB
    DeepCopyDefaults(defaults, self.db)
end


function LWT:GetFont()
    local fontName = self.db.alert.fontName or "Friz Quadrata"
    local fonts = self:GetFontList()
    for _, entry in ipairs(fonts) do
        if entry.name == fontName then
            return entry.path
        end
    end
    return "Fonts\\FRIZQT__.TTF"
end

-- Get sorted sound list from LibSharedMedia or fallback
LWT.fallbackSounds = {
    { name = "None" },
    { name = "Raid Warning", path = "Sound\\Interface\\RaidWarning.ogg" },
}

function LWT:GetSoundList()
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    if LSM then
        local sounds = { { name = "None" } }
        for _, name in ipairs(LSM:List("sound")) do
            table.insert(sounds, { name = name, path = LSM:Fetch("sound", name) })
        end
        return sounds
    end
    return self.fallbackSounds
end

function LWT:GetSoundFile()
    if not self.db.alert.sound then return nil end
    local soundName = self.db.alert.soundName
    if not soundName then return nil end

    local sounds = self:GetSoundList()
    for _, entry in ipairs(sounds) do
        if entry.name == soundName then
            return entry.path
        end
    end
    return nil
end

-- Print helper
function LWT:Print(msg)
    print("|cff00ccffLuckyWipeTools:|r " .. tostring(msg))
end

-- Stub functions (overridden by other files as they load)
function LWT:OpenSettings() end
function LWT:RefreshGateway() end

-- Main event frame
local frame = CreateFrame("Frame", "LuckyWipeToolsFrame")
frame:RegisterEvent("ADDON_LOADED")

frame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        LWT:SetupDB()
        C_ChatInfo.RegisterAddonMessagePrefix("LWT")
        LWT:Print("Loaded. Type /lwt for help.")
        frame:UnregisterEvent("ADDON_LOADED")
    end
end)

-- Slash commands
SLASH_LUCKYWIPETOOLS1 = "/lwt"
SlashCmdList["LUCKYWIPETOOLS"] = function(msg)
    msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")

    if msg == "test" then
        if LWT.gatewayAlert then
            LWT.gatewayAlert:Fire("|cff9b59b6GATEWAY READY|r")
        end

    elseif msg == "test summon" then
        if LWT.summonAlert then
            LWT.summonAlert:Fire("|cff9b59b6Portal placed! Click to summon|r")
        end

    elseif msg == "split" then
        LWT:ToggleSplitter()

    elseif msg == "log" then
        LWT:ToggleInstanceLogging()

    elseif msg == "vantus" then
        LWT:ToggleVantusRequest()

    else
        LWT:OpenSettings()
    end
end
