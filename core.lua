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

-- Private aura spell configs
LWT.privateAuras = {
    {
        key = "vorasiusFixate",
        label = "Vorasius - Fixate (Blistercreep)",
        spellID = 1254113,
        encounterID = 3177,
        getText = function()
            return "|cffff2020FIXATED ON YOU!|r"
        end,
    },
    {
        key = "chimaerusRift",
        label = "Chimaerus - Rift of Madness",
        spellID = 1264756,
        encounterID = 3306,
        getText = function()
            local role = GetSpecializationRole(GetSpecialization())
            if role == "HEALER" then
                return "|cff00ff00Go to Triangle|r"
            else
                return "|cffff2020Go to X|r"
            end
        end,
    },
}

-- Gateway Shard config
LWT.GATEWAY_ITEM_ID = 188152

-- DB setup
local defaults = {
    alert = {
        sound = false,
        soundName = nil, -- name from LibSharedMedia or fallback list
        duration = 3,
        fontSize = 36,
        fontName = "Friz Quadrata", -- saved by name so it survives list changes
        position = {},  -- { point, x, y }
    },
    gateway = {
        enabled = true,
        combatOnly = true,
    },
    encounters = {}, -- [key] = true/false, defaults to all enabled
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

function LWT:IsEncounterEnabled(key)
    -- Default to enabled if not explicitly set
    if self.db.encounters[key] == nil then return true end
    return self.db.encounters[key]
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
function LWT:RegisterAuras() end
function LWT:UnregisterAuras() end
function LWT:FireAlert() end
function LWT:UpdateAlertFont() end
function LWT:OpenSettings() end
function LWT:RefreshGateway() end

-- Main event frame
local frame = CreateFrame("Frame", "LuckyWipeToolsFrame")
frame:RegisterEvent("ADDON_LOADED")

frame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        LWT:SetupDB()
        LWT:Print("Loaded. Type /lwt for help.")
        frame:UnregisterEvent("ADDON_LOADED")
    end
end)

-- Slash commands
SLASH_LUCKYWIPETOOLS1 = "/lwt"
SlashCmdList["LUCKYWIPETOOLS"] = function(msg)
    msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")

    if msg == "test" then
        LWT:FireAlert("|cffff2020FIXATED ON YOU!|r")

    elseif msg == "test rift" then
        local role = GetSpecializationRole(GetSpecialization())
        local text = role == "HEALER" and "|cff00ff00Go to Triangle|r" or "|cffff2020Go to X|r"
        LWT:FireAlert(text)

    else
        LWT:OpenSettings()
    end
end
