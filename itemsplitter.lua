local ADDON_NAME, LWT = ...

local FLAT = "Interface\\Buttons\\WHITE8x8"
local ACCENT = { 1, 0.82, 0 }

local GUILD_BANK_SLOTS_PER_TAB = 98

local popup = nil
local splitState = nil -- { source, bag, slot, tab, itemID, stackCount, targetSize, created, phase }
local guildBankOpen = false
local guildBankButton = nil

-- =========================================================
-- Slot helpers
-- =========================================================
local function ResetSlot()
    if not popup then return end
    popup.dropIcon:Hide()
    popup.dropPlus:Show()
    popup.itemName:SetText("")
    popup.stackInfo:SetText("Drag an item here")
    popup.status:SetText("")
    popup.inputBox:SetText("1")
    popup.qtyBox:SetText("0")
    splitState = nil
end

local function PopulateSlot(source, bag, slot, tab)
    if not popup then return end
    local itemID, stackCount, icon

    if source == "guildbank" then
        local texture, count = GetGuildBankItemInfo(tab, slot)
        if not texture or count == 0 then return end
        icon = texture
        stackCount = count
        -- Get itemID from guild bank item link
        local link = GetGuildBankItemLink(tab, slot)
        if link then
            itemID = tonumber(link:match("item:(%d+)"))
        end
    else
        local info = C_Container.GetContainerItemInfo(bag, slot)
        if not info then return end
        itemID = info.itemID
        stackCount = info.stackCount
        icon = info.iconFileID
    end

    if not itemID or stackCount <= 1 then
        LWT:Print("That item cannot be split.")
        ClearCursor()
        return
    end

    popup.dropIcon:SetTexture(icon)
    popup.dropIcon:Show()
    popup.dropPlus:Hide()

    local name = C_Item.GetItemNameByID(itemID) or ("Item " .. itemID)
    popup.itemName:SetText(name)
    popup.stackInfo:SetText("Stack: " .. stackCount)
    popup.status:SetText("")

    splitState = {
        source = source,
        bag = bag,
        slot = slot,
        tab = tab,
        itemID = itemID,
        stackCount = stackCount,
    }

    -- Show destination toggle when source is guild bank
    if source == "guildbank" then
        popup.destLabel:Show()
        popup.destValue:Show()
        popup.destBtn:Show()
        popup.splitToBags = true
        popup.destValue:SetText("My Bags")
        -- Shift split button and status down
        popup.splitBtn:SetPoint("TOPLEFT", 12, -150)
        popup.status:SetPoint("TOPLEFT", 12, -182)
    else
        popup.destLabel:Hide()
        popup.destValue:Hide()
        popup.destBtn:Hide()
        -- Shift split button and status up (no dest row)
        popup.splitBtn:SetPoint("TOPLEFT", 12, -134)
        popup.status:SetPoint("TOPLEFT", 12, -166)
    end

    ClearCursor()
end

-- =========================================================
-- Empty slot finder
-- =========================================================
local function FindEmptyBagSlot(excludeSlots)
    for bag = 0, 4 do
        local numSlots = C_Container.GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            local key = bag .. ":" .. slot
            if not excludeSlots[key] then
                local info = C_Container.GetContainerItemInfo(bag, slot)
                if not info then
                    return bag, slot
                end
            end
        end
    end
    return nil, nil
end

local function FindEmptyGuildBankSlot(tab, startSlot, excludeSlots)
    for slot = startSlot, GUILD_BANK_SLOTS_PER_TAB do
        local key = tab .. ":" .. slot
        if not excludeSlots[key] then
            local texture = GetGuildBankItemInfo(tab, slot)
            if not texture then
                return slot
            end
        end
    end
    return nil
end

-- =========================================================
-- Coroutine split loop
-- =========================================================
local MAX_ITERATIONS = 200
local splitCoroutine = nil

local function RunSplit()
    if not splitState then return end

    local src = splitState
    local targetSize = tonumber(popup.inputBox:GetText()) or 1
    if targetSize < 1 then targetSize = 1 end

    local maxStacks = tonumber(popup.qtyBox:GetText()) or 0
    if maxStacks < 1 then maxStacks = nil end -- nil = unlimited

    local currentStack = src.stackCount
    if currentStack <= targetSize then
        popup.status:SetText("Nothing to split.")
        return
    end

    ClearCursor()
    local excluded = {}
    local created = 0

    while currentStack > targetSize and (not maxStacks or created < maxStacks) do
        -- Wait for source item to be unlocked
        for attempt = 1, MAX_ITERATIONS do
            if src.source == "guildbank" then
                local _, _, locked = GetGuildBankItemInfo(src.tab, src.slot)
                if not locked then break end
            else
                local info = C_Container.GetContainerItemInfo(src.bag, src.slot)
                if info and not info.isLocked then break end
            end
            coroutine.yield()
            if attempt == MAX_ITERATIONS then
                popup.status:SetText("|cffff3333Timed out waiting for item.|r")
                return
            end
        end

        -- Determine where split stacks go
        local splitToBags = popup.splitToBags
        local destIsBags = (src.source ~= "guildbank") or splitToBags

        -- Find destination
        local dstBag, dstSlot
        if destIsBags then
            dstBag, dstSlot = FindEmptyBagSlot(excluded)
            if not dstBag then
                popup.status:SetText("No empty bag slots. Split " .. created .. " stacks.")
                return
            end
            excluded[dstBag .. ":" .. dstSlot] = true
        else
            dstSlot = FindEmptyGuildBankSlot(src.tab, 1, excluded)
            if not dstSlot then
                popup.status:SetText("No empty slots in guild bank tab. Split " .. created .. " stacks.")
                return
            end
            excluded[src.tab .. ":" .. dstSlot] = true
        end

        -- Perform split
        local splitAmount = targetSize

        if src.source == "guildbank" then
            SplitGuildBankItem(src.tab, src.slot, splitAmount)
            if destIsBags then
                -- Guild bank -> personal bags
                C_Container.PickupContainerItem(dstBag, dstSlot)
            else
                -- Guild bank -> same tab
                PickupGuildBankItem(src.tab, dstSlot)
            end
        else
            C_Container.SplitContainerItem(src.bag, src.slot, splitAmount)
            C_Container.PickupContainerItem(dstBag, dstSlot)
        end

        -- Wait for stack to change
        local expectedStack = currentStack - splitAmount
        for attempt = 1, MAX_ITERATIONS do
            local nowCount
            if src.source == "guildbank" then
                local _, count = GetGuildBankItemInfo(src.tab, src.slot)
                nowCount = count or 0
            else
                local info = C_Container.GetContainerItemInfo(src.bag, src.slot)
                nowCount = info and info.stackCount or 0
            end

            if nowCount == expectedStack then
                currentStack = expectedStack
                break
            end
            coroutine.yield()
            if attempt == MAX_ITERATIONS then
                popup.status:SetText("|cffff3333Split stalled. Created " .. created .. " stacks.|r")
                return
            end
        end

        created = created + 1
        popup.status:SetText("Splitting... " .. created .. " stacks created")
    end

    popup.status:SetText("|cff00ff00Done!|r Created " .. created .. " stacks of " .. targetSize .. ".")
    splitState = nil
end

-- OnUpdate driver for coroutine
local tickFrame = CreateFrame("Frame", "LWT_SplitTick")
tickFrame:Hide()
tickFrame:SetScript("OnUpdate", function()
    if not splitCoroutine then
        tickFrame:Hide()
        return
    end
    local ok, err = coroutine.resume(splitCoroutine)
    if not ok then
        if popup then popup.status:SetText("|cffff3333Error: " .. tostring(err) .. "|r") end
        splitCoroutine = nil
        tickFrame:Hide()
    elseif coroutine.status(splitCoroutine) == "dead" then
        splitCoroutine = nil
        tickFrame:Hide()
    end
end)

-- =========================================================
-- Popup frame
-- =========================================================
local function CreatePopup()
    if popup then return popup end

    local f = CreateFrame("Frame", "LWT_ItemSplitter", UIParent, "BackdropTemplate")
    f:SetSize(220, 226)
    f:SetPoint("CENTER")
    f:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1 })
    f:SetBackdropColor(0.05, 0.05, 0.07, 0.95)
    f:SetBackdropBorderColor(0.15, 0.15, 0.18, 1)
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetClampedToScreen(true)
    f:Hide()

    tinsert(UISpecialFrames, "LWT_ItemSplitter")

    -- Cleanup on hide
    f:SetScript("OnHide", function()
        -- Abort any in-progress split
        if splitCoroutine then
            splitCoroutine = nil
            tickFrame:Hide()
        end
        ResetSlot()
    end)

    -- Title bar
    local titleBar = CreateFrame("Frame", nil, f)
    titleBar:SetHeight(24)
    titleBar:SetPoint("TOPLEFT", 1, -1)
    titleBar:SetPoint("TOPRIGHT", -1, -1)
    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function() f:StartMoving() end)
    titleBar:SetScript("OnDragStop", function()
        f:StopMovingOrSizing()
        local point, _, _, x, y = f:GetPoint()
        if LWT.db and LWT.db.itemSplitter then
            LWT.db.itemSplitter.popupPos = { point, x, y }
        end
    end)

    local titleBg = titleBar:CreateTexture(nil, "BACKGROUND")
    titleBg:SetAllPoints()
    titleBg:SetColorTexture(0.08, 0.08, 0.10, 1)

    local titleText = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    titleText:SetPoint("LEFT", 8, 0)
    titleText:SetText("Item Splitter")
    titleText:SetTextColor(ACCENT[1], ACCENT[2], ACCENT[3])

    -- Close button
    local closeBtn = CreateFrame("Button", nil, titleBar)
    closeBtn:SetSize(24, 24)
    closeBtn:SetPoint("RIGHT", -2, 0)
    closeBtn.text = closeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    closeBtn.text:SetPoint("CENTER")
    closeBtn.text:SetText("x")
    closeBtn.text:SetTextColor(0.5, 0.5, 0.5)
    closeBtn:SetScript("OnEnter", function(self) self.text:SetTextColor(1, 0.3, 0.3) end)
    closeBtn:SetScript("OnLeave", function(self) self.text:SetTextColor(0.5, 0.5, 0.5) end)
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    -- Drop slot (40x40 box)
    local dropSlot = CreateFrame("Button", "LWT_SplitDropSlot", f, "BackdropTemplate")
    dropSlot:SetSize(40, 40)
    dropSlot:SetPoint("TOPLEFT", 12, -32)
    dropSlot:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1 })
    dropSlot:SetBackdropColor(0.08, 0.08, 0.10, 1)
    dropSlot:SetBackdropBorderColor(0.25, 0.25, 0.28, 1)
    f.dropSlot = dropSlot

    local dropIcon = dropSlot:CreateTexture(nil, "ARTWORK")
    dropIcon:SetSize(36, 36)
    dropIcon:SetPoint("CENTER")
    dropIcon:Hide()
    f.dropIcon = dropIcon

    local dropPlus = dropSlot:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    dropPlus:SetPoint("CENTER")
    dropPlus:SetText("+")
    dropPlus:SetTextColor(0.5, 0.5, 0.5)
    f.dropPlus = dropPlus

    -- Drop slot interaction
    dropSlot:SetScript("OnReceiveDrag", function()
        local infoType, id, link = GetCursorInfo()
        if infoType ~= "item" then return end

        -- Detect source: check if guild bank is open and item came from there
        if guildBankOpen then
            local tab = GetCurrentGuildBankTab()
            -- Find which slot this item is in by scanning the tab
            for s = 1, GUILD_BANK_SLOTS_PER_TAB do
                local texture, count, locked = GetGuildBankItemInfo(tab, s)
                if texture and count > 0 then
                    local gbLink = GetGuildBankItemLink(tab, s)
                    if gbLink and gbLink == link then
                        PopulateSlot("guildbank", nil, s, tab)
                        return
                    end
                end
            end
        end

        -- Personal bag source -- find the bag/slot from item location
        for bag = 0, 4 do
            local numSlots = C_Container.GetContainerNumSlots(bag)
            for slot = 1, numSlots do
                local info = C_Container.GetContainerItemInfo(bag, slot)
                if info and info.itemID == id and info.isLocked then
                    PopulateSlot("bag", bag, slot, nil)
                    return
                end
            end
        end

        -- Fallback: scan unlocked slots matching itemID
        for bag = 0, 4 do
            local numSlots = C_Container.GetContainerNumSlots(bag)
            for slot = 1, numSlots do
                local info = C_Container.GetContainerItemInfo(bag, slot)
                if info and info.itemID == id then
                    PopulateSlot("bag", bag, slot, nil)
                    return
                end
            end
        end

        ClearCursor()
    end)
    dropSlot:SetScript("OnClick", dropSlot:GetScript("OnReceiveDrag"))

    dropSlot:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(ACCENT[1], ACCENT[2], ACCENT[3], 0.6)
    end)
    dropSlot:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(0.25, 0.25, 0.28, 1)
    end)

    -- Item name + stack info (right of drop slot)
    local itemName = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    itemName:SetPoint("LEFT", dropSlot, "RIGHT", 8, 6)
    itemName:SetPoint("RIGHT", f, "RIGHT", -8, 0)
    itemName:SetJustifyH("LEFT")
    f.itemName = itemName

    local stackInfo = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    stackInfo:SetPoint("LEFT", dropSlot, "RIGHT", 8, -8)
    stackInfo:SetTextColor(0.6, 0.6, 0.6)
    f.stackInfo = stackInfo

    -- "Split into stacks of:" label + input
    local splitLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    splitLabel:SetPoint("TOPLEFT", 12, -80)
    splitLabel:SetText("Split into stacks of:")
    f.splitLabel = splitLabel

    local inputBox = CreateFrame("EditBox", "LWT_SplitInput", f, "BackdropTemplate")
    inputBox:SetSize(50, 22)
    inputBox:SetPoint("LEFT", splitLabel, "RIGHT", 8, 0)
    inputBox:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1 })
    inputBox:SetBackdropColor(0.08, 0.08, 0.10, 1)
    inputBox:SetBackdropBorderColor(0.25, 0.25, 0.28, 1)
    inputBox:SetFontObject("GameFontHighlightSmall")
    inputBox:SetJustifyH("CENTER")
    inputBox:SetNumeric(true)
    inputBox:SetAutoFocus(false)
    inputBox:SetMaxLetters(5)
    inputBox:SetText("1")
    inputBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    inputBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    f.inputBox = inputBox

    -- Mouse wheel support on input
    inputBox:EnableMouseWheel(true)
    inputBox:SetScript("OnMouseWheel", function(self, delta)
        local val = (tonumber(self:GetText()) or 1) + delta
        if val < 1 then val = 1 end
        if splitState and val > splitState.stackCount then val = splitState.stackCount end
        self:SetText(val)
    end)

    -- "Quantity:" label + input (how many stacks to split off)
    local qtyLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    qtyLabel:SetPoint("TOPLEFT", 12, -106)
    qtyLabel:SetText("Quantity:")
    f.qtyLabel = qtyLabel

    local qtyBox = CreateFrame("EditBox", "LWT_SplitQty", f, "BackdropTemplate")
    qtyBox:SetSize(50, 22)
    qtyBox:SetPoint("LEFT", qtyLabel, "RIGHT", 8, 0)
    qtyBox:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1 })
    qtyBox:SetBackdropColor(0.08, 0.08, 0.10, 1)
    qtyBox:SetBackdropBorderColor(0.25, 0.25, 0.28, 1)
    qtyBox:SetFontObject("GameFontHighlightSmall")
    qtyBox:SetJustifyH("CENTER")
    qtyBox:SetNumeric(true)
    qtyBox:SetAutoFocus(false)
    qtyBox:SetMaxLetters(5)
    qtyBox:SetText("0")
    qtyBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    qtyBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    f.qtyBox = qtyBox

    local qtyHint = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    qtyHint:SetPoint("LEFT", qtyBox, "RIGHT", 6, 0)
    qtyHint:SetText("0 = all")
    qtyHint:SetTextColor(0.4, 0.4, 0.4)
    f.qtyHint = qtyHint

    qtyBox:EnableMouseWheel(true)
    qtyBox:SetScript("OnMouseWheel", function(self, delta)
        local val = (tonumber(self:GetText()) or 0) + delta
        if val < 0 then val = 0 end
        self:SetText(val)
    end)

    -- Destination toggle (only visible when source is guild bank)
    local destLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    destLabel:SetPoint("TOPLEFT", 12, -132)
    destLabel:SetText("Split to:")
    destLabel:SetTextColor(0.6, 0.6, 0.6)
    f.destLabel = destLabel

    local destValue = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    destValue:SetPoint("LEFT", destLabel, "RIGHT", 6, 0)
    destValue:SetText("My Bags")
    destValue:SetTextColor(ACCENT[1], ACCENT[2], ACCENT[3])
    f.destValue = destValue

    local destBtn = CreateFrame("Button", "LWT_SplitDestBtn", f)
    destBtn:SetSize(140, 16)
    destBtn:SetPoint("TOPLEFT", 12, -126)
    destBtn:SetHeight(18)
    f.destBtn = destBtn

    local splitToBags = true
    f.splitToBags = true

    destBtn:SetScript("OnClick", function()
        splitToBags = not splitToBags
        f.splitToBags = splitToBags
        destValue:SetText(splitToBags and "My Bags" or "Guild Bank")
    end)

    -- Hide destination row by default (shown when source is guild bank)
    destLabel:Hide()
    destValue:Hide()
    destBtn:Hide()

    -- Split button
    local splitBtn = CreateFrame("Button", "LWT_SplitBtn", f, "BackdropTemplate")
    splitBtn:SetSize(196, 26)
    splitBtn:SetPoint("TOPLEFT", 12, -150)
    splitBtn:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1 })
    splitBtn:SetBackdropColor(0.12, 0.12, 0.14, 1)
    splitBtn:SetBackdropBorderColor(0.25, 0.25, 0.28, 1)

    splitBtn.text = splitBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    splitBtn.text:SetPoint("CENTER")
    splitBtn.text:SetText("Split")

    splitBtn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.18, 0.18, 0.20, 1)
        self:SetBackdropBorderColor(0.4, 0.4, 0.45, 1)
    end)
    splitBtn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.12, 0.12, 0.14, 1)
        self:SetBackdropBorderColor(0.25, 0.25, 0.28, 1)
    end)
    f.splitBtn = splitBtn

    -- Split button click with validation
    splitBtn:SetScript("OnClick", function()
        if not splitState then
            popup.status:SetText("Drop an item first.")
            return
        end
        if splitCoroutine then
            popup.status:SetText("Already splitting...")
            return
        end

        local targetSize = tonumber(popup.inputBox:GetText()) or 1
        if targetSize < 1 then
            popup.status:SetText("Stack size must be at least 1.")
            return
        end
        if targetSize >= splitState.stackCount then
            popup.status:SetText("Target size must be less than stack size.")
            return
        end

        -- Verify item still exists
        if splitState.source == "guildbank" then
            if not guildBankOpen then
                popup.status:SetText("|cffff3333Guild bank is closed.|r")
                return
            end
            local _, count = GetGuildBankItemInfo(splitState.tab, splitState.slot)
            if not count or count == 0 then
                popup.status:SetText("|cffff3333Item no longer in that slot.|r")
                ResetSlot()
                return
            end
            splitState.stackCount = count
        else
            local info = C_Container.GetContainerItemInfo(splitState.bag, splitState.slot)
            if not info or info.itemID ~= splitState.itemID then
                popup.status:SetText("|cffff3333Item no longer in that slot.|r")
                ResetSlot()
                return
            end
            splitState.stackCount = info.stackCount
        end

        popup.stackInfo:SetText("Stack: " .. splitState.stackCount)
        splitCoroutine = coroutine.create(RunSplit)
        tickFrame:Show()
    end)

    -- Status text
    local status = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    status:SetPoint("TOPLEFT", 12, -182)
    status:SetPoint("RIGHT", f, "RIGHT", -12, 0)
    status:SetJustifyH("LEFT")
    status:SetTextColor(0.6, 0.6, 0.6)
    f.status = status

    popup = f
    return f
end

-- =========================================================
-- Guild bank button
-- =========================================================
local function CreateGuildBankButton()
    if LWT.db and LWT.db.itemSplitter and not LWT.db.itemSplitter.enabled then
        if guildBankButton then guildBankButton:Hide() end
        return
    end
    if guildBankButton then
        guildBankButton:Show()
        return
    end

    local parent = GuildBankFrame
    if not parent then return end

    local btn = CreateFrame("Button", "LWT_GuildBankSplitBtn", parent, "BackdropTemplate")
    btn:SetSize(60, 22)
    btn:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -60, -4)
    btn:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1 })
    btn:SetBackdropColor(0.12, 0.12, 0.14, 1)
    btn:SetBackdropBorderColor(0.25, 0.25, 0.28, 1)
    btn:SetFrameStrata("HIGH")

    btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    btn.text:SetPoint("CENTER")
    btn.text:SetText("Split")

    btn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.18, 0.18, 0.20, 1)
        self:SetBackdropBorderColor(ACCENT[1], ACCENT[2], ACCENT[3], 0.6)
    end)
    btn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.12, 0.12, 0.14, 1)
        self:SetBackdropBorderColor(0.25, 0.25, 0.28, 1)
    end)
    btn:SetScript("OnClick", function()
        LWT:ToggleSplitter()
    end)

    guildBankButton = btn
end

local gbFrame = CreateFrame("Frame", "LWT_GuildBankDetect")
gbFrame:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_SHOW")
gbFrame:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_HIDE")

gbFrame:SetScript("OnEvent", function(_, event, type)
    if type ~= 10 then return end -- 10 = guild bank
    if event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" then
        guildBankOpen = true
        C_Timer.After(0.1, CreateGuildBankButton)
    else
        guildBankOpen = false
        if guildBankButton then guildBankButton:Hide() end
        if popup and popup:IsShown() then
            popup:Hide()
        end
    end
end)

-- =========================================================
-- Public API
-- =========================================================
function LWT:ToggleSplitter()
    if self.db and self.db.itemSplitter and not self.db.itemSplitter.enabled then
        self:Print("Item Splitter is disabled. Enable it in /lwt settings.")
        return
    end
    local f = CreatePopup()
    if f:IsShown() then
        f:Hide()
    else
        ResetSlot()
        -- Restore position
        local pos = self.db and self.db.itemSplitter and self.db.itemSplitter.popupPos
        if pos then
            f:ClearAllPoints()
            f:SetPoint(pos[1], UIParent, pos[1], pos[2], pos[3])
        end
        f:Show()

        -- If cursor has an item, auto-populate
        if GetCursorInfo() == "item" then
            popup.dropSlot:GetScript("OnReceiveDrag")(popup.dropSlot)
        end
    end
end
