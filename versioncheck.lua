local ADDON_NAME, LWT = ...

local myVersion = C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version") or "0.0.0"

local function ParseVersion(ver)
    local major, minor, patch = ver:match("(%d+)%.(%d+)%.(%d+)")
    return tonumber(major) or 0, tonumber(minor) or 0, tonumber(patch) or 0
end

local function IsNewer(theirVersion)
    local myMajor, myMinor, myPatch = ParseVersion(myVersion)
    local theirMajor, theirMinor, theirPatch = ParseVersion(theirVersion)
    if theirMajor > myMajor then return true end
    if theirMajor == myMajor and theirMinor > myMinor then return true end
    if theirMajor == myMajor and theirMinor == myMinor and theirPatch > myPatch then return true end
    return false
end

local function SendVersionToGuild()
    if IsInGuild() then
        C_ChatInfo.SendAddonMessage("LWT", "VERSION:" .. myVersion, "GUILD")
    end
end

local function OnVersionReceived(theirVersion, sender)
    -- Ignore own messages
    local myName = UnitName("player")
    if sender and myName and Ambiguate(sender, "short") == myName then return end

    if IsNewer(theirVersion) then
        local db = LWT.db
        if not db then return end
        local today = date("%Y-%m-%d")
        if db.lastVersionCheck == today then return end
        db.lastVersionCheck = today
        LWT:Print("A newer version (" .. theirVersion .. ") is available. Please update!")
    end
end

-- Event frame
local eventFrame = CreateFrame("Frame", "LWT_VersionCheckFrame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("CHAT_MSG_ADDON")

eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LOGIN" then
        -- Delay slightly so guild info is available
        C_Timer.After(5, SendVersionToGuild)
    elseif event == "CHAT_MSG_ADDON" then
        local prefix, message, channel, sender = ...
        if prefix ~= "LWT" then return end
        -- Respond to version broadcasts
        local ver = message:match("^VERSION:(.+)$")
        if ver then
            OnVersionReceived(ver, sender)
            -- Reply with our version so they can check too
            if channel == "GUILD" then
                -- Don't reply to avoid message storms — the initial broadcast is enough
            end
        end
    end
end)
