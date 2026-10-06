local addonName = ...
local messageCheckDuplicate

---------------------------------------------------------------------
-- Settings (saved in MoonscarletsChatScannerDB - see .toc note)
---------------------------------------------------------------------
local defaults = {
    enabled = true,
    mute = false,
    master = false,
    flash = false,
    minimap = true,
    minimapAngle = 215,
}
local settings = {}
for k, v in pairs(defaults) do settings[k] = v end

local RefreshUI, ToggleGUI, InitUI

---------------------------------------------------------------------
-- GUI
---------------------------------------------------------------------
local FRAME_W, FRAME_H = 440, 480
local ACCENT = { 0.36, 0.57, 1.0 }
local BACKDROP_TEMPLATE = BackdropTemplateMixin and "BackdropTemplate" or nil

local mainFrame, headerToggle, minimapButton
local panels, tabs = {}, {}
local settingsRefreshers = {}

local function SkinFrame(f, r, g, b, a)
    if not f.SetBackdrop then return end
    f:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    f:SetBackdropColor(r, g, b, a)
    f:SetBackdropBorderColor(0.25, 0.25, 0.3, 1)
end

StaticPopupDialogs["MCS_CONFIRM_CLEAR"] = {
    text = "%s",
    button1 = YES,
    button2 = NO,
    OnAccept = function(self, data) if data then data() end end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

-- Builds a list tab (used for both the keyword list and the ignored players list)
local function CreateListPanel(parent, cfg)
    local panel = CreateFrame("Frame", nil, parent)
    panel:SetAllPoints()

    local tip = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    tip:SetPoint("TOPLEFT", 16, -10)
    tip:SetWidth(FRAME_W - 32)
    tip:SetJustifyH("LEFT")
    tip:SetSpacing(2)
    tip:SetText(cfg.tip)

    local eb = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    eb:SetPoint("TOPLEFT", 22, -56)
    eb:SetSize(296, 22)
    eb:SetAutoFocus(false)
    eb:SetMaxLetters(100)

    local placeholder = eb:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    placeholder:SetPoint("LEFT", 2, 0)
    placeholder:SetText(cfg.placeholder)
    eb:SetScript("OnTextChanged", function(self)
        placeholder:SetShown(self:GetText() == "")
    end)
    eb:SetScript("OnEscapePressed", eb.ClearFocus)

    local addBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    addBtn:SetSize(80, 22)
    addBtn:SetPoint("LEFT", eb, "RIGHT", 8, 0)
    addBtn:SetText("Add")

    local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 14, -90)
    scroll:SetPoint("BOTTOMRIGHT", -32, 44)
    local listBg = CreateFrame("Frame", nil, panel, BACKDROP_TEMPLATE)
    listBg:SetPoint("TOPLEFT", scroll, -4, 4)
    listBg:SetPoint("BOTTOMRIGHT", scroll, 24, -4)
    listBg:SetFrameLevel(scroll:GetFrameLevel() - 1)
    SkinFrame(listBg, 0.04, 0.04, 0.06, 0.8)

    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(FRAME_W - 46, 1)
    scroll:SetScrollChild(child)

    local empty = scroll:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    empty:SetPoint("TOP", scroll, "TOP", 0, -40)
    empty:SetText(cfg.empty)

    local countText = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    countText:SetPoint("BOTTOMLEFT", 16, 16)

    local clearBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    clearBtn:SetSize(100, 22)
    clearBtn:SetPoint("BOTTOMRIGHT", -14, 12)
    clearBtn:SetText("Clear all")

    local rows = {}
    local ROW_H = 24

    local function Refresh()
        local list = cfg.get()
        for i = 1, math.max(#list, #rows) do
            local row = rows[i]
            if i <= #list then
                if not row then
                    row = CreateFrame("Frame", nil, child)
                    row:SetSize(FRAME_W - 46, ROW_H)
                    row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
                    row.bg = row:CreateTexture(nil, "BACKGROUND")
                    row.bg:SetAllPoints()
                    row.num = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                    row.num:SetPoint("LEFT", 8, 0)
                    row.num:SetWidth(24)
                    row.num:SetJustifyH("LEFT")
                    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                    row.text:SetPoint("LEFT", 36, 0)
                    row.text:SetWidth(FRAME_W - 46 - 36 - 34)
                    row.text:SetJustifyH("LEFT")
                    row.text:SetWordWrap(false)
                    row.del = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
                    row.del:SetSize(22, 18)
                    row.del:SetPoint("RIGHT", -6, 0)
                    row.del:SetText("X")
                    rows[i] = row
                end
                row.bg:SetColorTexture(1, 1, 1, i % 2 == 0 and 0.05 or 0.0)
                row.num:SetText(i)
                row.text:SetText(list[i])
                row.del:SetScript("OnClick", function()
                    table.remove(cfg.get(), i)
                    RefreshUI()
                end)
                row:Show()
            elseif row then
                row:Hide()
            end
        end
        child:SetHeight(math.max(#list * ROW_H, 1))
        empty:SetShown(#list == 0)
        countText:SetText(#list .. " " .. (#list == 1 and cfg.single or cfg.plural))
        clearBtn:SetEnabled(#list > 0)
    end

    local function DoAdd()
        local text = strtrim(eb:GetText() or "")
        if text == "" then return end
        if cfg.transform then text = cfg.transform(text) end
        if text == "" then return end
        table.insert(cfg.get(), text)
        eb:SetText("")
        RefreshUI()
    end
    addBtn:SetScript("OnClick", DoAdd)
    eb:SetScript("OnEnterPressed", DoAdd)

    clearBtn:SetScript("OnClick", function()
        StaticPopup_Show("MCS_CONFIRM_CLEAR", cfg.confirm, nil, function()
            cfg.clear()
            RefreshUI()
        end)
    end)

    panel.Refresh = Refresh
    return panel
end

local function CreateCheckbox(parent, y, label, desc, get, set)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", 16, y)
    cb:SetSize(26, 26)
    local t = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    t:SetPoint("LEFT", cb, "RIGHT", 4, 1)
    t:SetText(label)
    local d = cb:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    d:SetPoint("TOPLEFT", cb, "BOTTOMLEFT", 30, 3)
    d:SetText(desc)
    cb:SetScript("OnClick", function(self)
        set(self:GetChecked() and true or false)
        RefreshUI()
    end)
    table.insert(settingsRefreshers, function() cb:SetChecked(get()) end)
    return cb
end

local function CreateSettingsPanel(parent)
    local panel = CreateFrame("Frame", nil, parent)
    panel:SetAllPoints()

    CreateCheckbox(panel, -16, "Enable scanning",
        "Master switch. Turn this off to stop all notifications.",
        function() return settings.enabled end,
        function(v) settings.enabled = v end)

    CreateCheckbox(panel, -66, "Play a sound when a match is found",
        "Uncheck for silent chat alerts only.",
        function() return not settings.mute end,
        function(v) settings.mute = not v end)

    CreateCheckbox(panel, -116, "Play sound even if game sound is muted",
        "Uses the Master volume channel so you never miss an alert.",
        function() return settings.master end,
        function(v) settings.master = v end)

    CreateCheckbox(panel, -166, "Flash the WoW icon in the taskbar",
        "Helpful when the game is minimized or in the background.",
        function() return settings.flash end,
        function(v) settings.flash = v end)

    CreateCheckbox(panel, -216, "Show minimap button",
        "Left-click opens this window, right-click toggles scanning.",
        function() return settings.minimap end,
        function(v)
            settings.minimap = v
            if minimapButton then minimapButton:SetShown(v) end
        end)

    local test = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    test:SetSize(140, 24)
    test:SetPoint("TOPLEFT", 20, -276)
    test:SetText("Test notification")
    test:SetScript("OnClick", function()
        DEFAULT_CHAT_FRAME:AddMessage("|cAAFF0000FOUND 1 (|r|cff92ff58TEST|r|cffFF0000): |r|cff5892ff\n[Test]|r |cffffffff[Someone]|r|cff5892ff: This is what a match looks like!|r")
        if not settings.mute then
            if settings.master then PlaySound(4041, "Master") else PlaySound(4041) end
        end
        if settings.flash and FlashClientIcon then FlashClientIcon() end
    end)

    local tipText = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    tipText:SetPoint("TOPLEFT", test, "BOTTOMLEFT", 2, -14)
    tipText:SetWidth(FRAME_W - 40)
    tipText:SetJustifyH("LEFT")
    tipText:SetSpacing(2)
    tipText:SetText("Tip: put Trade / LFG / World channels in a separate chat tab and let this addon alert you in your main tab only when something you care about is posted.")

    panel.Refresh = function()
        for _, fn in ipairs(settingsRefreshers) do fn() end
    end
    return panel
end

local function SelectTab(index)
    for i, tab in ipairs(tabs) do
        local active = (i == index)
        panels[i]:SetShown(active)
        tab.underline:SetShown(active)
        if active then tab.text:SetTextColor(1, 1, 1) else tab.text:SetTextColor(0.6, 0.6, 0.65) end
    end
    mainFrame.selected = index
end

local function CreateMinimapButton()
    local b = CreateFrame("Button", "MoonscarletsChatScannerMinimapButton", Minimap)
    b:SetSize(31, 31)
    b:SetFrameStrata("MEDIUM")
    b:SetFrameLevel(8)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:RegisterForDrag("LeftButton")

    local icon = b:CreateTexture(nil, "BACKGROUND")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER", 0, 1)
    icon:SetTexture("Interface\\Icons\\INV_Misc_Note_01")
    local border = b:CreateTexture(nil, "OVERLAY")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local function UpdatePos()
        local a = math.rad(settings.minimapAngle or 215)
        b:ClearAllPoints()
        b:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * 80, math.sin(a) * 80)
    end
    UpdatePos()

    b:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local px, py = GetCursorPosition()
            local s = Minimap:GetEffectiveScale()
            px, py = px / s, py / s
            settings.minimapAngle = math.deg((math.atan2 or math.atan)(py - my, px - mx))
            UpdatePos()
        end)
    end)
    b:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)

    b:SetScript("OnClick", function(_, button)
        if button == "RightButton" then
            settings.enabled = not settings.enabled
            print("-- Chat Scanner " .. (settings.enabled and "enabled" or "disabled"))
            RefreshUI()
        else
            ToggleGUI()
        end
    end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("Chat Scanner")
        GameTooltip:AddLine("Scanning: " .. (settings.enabled and "|cff00ff00ON|r" or "|cffff4040OFF|r"), 1, 1, 1)
        GameTooltip:AddLine("Left-click: open window", 0.7, 0.7, 0.7)
        GameTooltip:AddLine("Right-click: toggle scanning", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", GameTooltip_Hide)
    b:SetShown(settings.minimap)
    return b
end

local function CreateMainFrame()
    local f = CreateFrame("Frame", "MoonscarletsChatScannerFrame", UIParent, BACKDROP_TEMPLATE)
    f:SetSize(FRAME_W, FRAME_H)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    SkinFrame(f, 0.07, 0.07, 0.10, 0.96)
    f:Hide()
    tinsert(UISpecialFrames, "MoonscarletsChatScannerFrame")

    -- header
    local bar = f:CreateTexture(nil, "ARTWORK")
    bar:SetPoint("TOPLEFT", 1, -1)
    bar:SetPoint("TOPRIGHT", -1, -1)
    bar:SetHeight(30)
    bar:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 0.18)

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 14, -8)
    title:SetText("Chat Scanner")

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 1)

    headerToggle = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    headerToggle:SetSize(110, 20)
    headerToggle:SetPoint("TOPRIGHT", -36, -6)
    headerToggle:SetScript("OnClick", function()
        settings.enabled = not settings.enabled
        RefreshUI()
    end)

    -- tabs
    local names = { "Keywords", "Ignored Players", "Settings" }
    local content = CreateFrame("Frame", nil, f)
    content:SetPoint("TOPLEFT", 0, -64)
    content:SetPoint("BOTTOMRIGHT", 0, 0)

    local divider = f:CreateTexture(nil, "ARTWORK")
    divider:SetPoint("TOPLEFT", 1, -63)
    divider:SetPoint("TOPRIGHT", -1, -63)
    divider:SetHeight(1)
    divider:SetColorTexture(0.25, 0.25, 0.3, 1)

    local x = 10
    for i, name in ipairs(names) do
        local tab = CreateFrame("Button", nil, f)
        tab:SetSize(name == "Ignored Players" and 120 or 90, 26)
        tab:SetPoint("TOPLEFT", x, -36)
        x = x + tab:GetWidth() + 4
        tab.text = tab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        tab.text:SetPoint("CENTER")
        tab.text:SetText(name)
        tab.underline = tab:CreateTexture(nil, "OVERLAY")
        tab.underline:SetPoint("BOTTOMLEFT", 4, -1)
        tab.underline:SetPoint("BOTTOMRIGHT", -4, -1)
        tab.underline:SetHeight(2)
        tab.underline:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 1)
        tab:SetScript("OnClick", function() SelectTab(i) end)
        tab:SetScript("OnEnter", function(self) self.text:SetTextColor(1, 1, 1) end)
        tab:SetScript("OnLeave", function(self)
            if mainFrame.selected ~= i then self.text:SetTextColor(0.6, 0.6, 0.65) end
        end)
        tabs[i] = tab
    end

    mainFrame = f

    panels[1] = CreateListPanel(content, {
        get = function() return whitelistedStringTable end,
        clear = function() whitelistedStringTable = {} end,
        tip = "Type words or phrases to watch for in Guild, Say, Yell and channel chat (Trade, LFG, World...). Use |cff92ff58|||r between words when ALL must appear (e.g. |cff92ff58dps|scholo|r) and put |cff92ff58-|r in front of a word to exclude it (e.g. |cff92ff58LFM Molten Core|-gold|r).",
        placeholder = "e.g. LFM Molten Core",
        empty = "No keywords yet - add one above!",
        single = "keyword", plural = "keywords",
        confirm = "Remove ALL keywords from your watch list?",
    })
    panels[2] = CreateListPanel(content, {
        get = function() return whitelistedStringTablePlayersChat end,
        clear = function() whitelistedStringTablePlayersChat = {} end,
        transform = function(t) return (t:gsub("-.*", "")) end,
        tip = "Players on this list are ignored by the scanner - handy for spammers who keep matching your keywords. This does not affect the normal in-game ignore list.",
        placeholder = "Player name",
        empty = "Nobody is ignored. Nice!",
        single = "player", plural = "players",
        confirm = "Remove ALL players from the ignore list?",
    })
    panels[3] = CreateSettingsPanel(content)

    SelectTab(1)
end

RefreshUI = function()
    if not mainFrame then return end
    if settings.enabled then
        headerToggle:SetText("Scanning: |cff00ff00ON|r")
    else
        headerToggle:SetText("Scanning: |cffff4040OFF|r")
    end
    for _, p in ipairs(panels) do p.Refresh() end
end

ToggleGUI = function()
    if not mainFrame then return end
    if mainFrame:IsShown() then
        mainFrame:Hide()
    else
        RefreshUI()
        mainFrame:Show()
    end
end

InitUI = function()
    CreateMainFrame()
    minimapButton = CreateMinimapButton()
    RefreshUI()
end

---------------------------------------------------------------------
-- Load / save
---------------------------------------------------------------------
local frameScanner = CreateFrame("FRAME")
frameScanner:RegisterEvent("ADDON_LOADED")

function frameScanner:OnEvent(event, arg1)
    if event == "ADDON_LOADED" and (arg1 == addonName or arg1 == "MoonscarletsChatScanner") then
        if whitelistedStringTable == nil then
            whitelistedStringTable = {}
        end
        if whitelistedStringTablePlayersChat == nil then
            whitelistedStringTablePlayersChat = {}
        end
        MoonscarletsChatScannerDB = MoonscarletsChatScannerDB or {}
        for k, v in pairs(defaults) do
            if MoonscarletsChatScannerDB[k] == nil then
                MoonscarletsChatScannerDB[k] = v
            end
        end
        settings = MoonscarletsChatScannerDB
        InitUI()
    end
end

frameScanner:SetScript("OnEvent", frameScanner.OnEvent)

---------------------------------------------------------------------
-- Slash commands (still available for power users)
---------------------------------------------------------------------
local function Refresh() if RefreshUI then RefreshUI() end end

local commands =
{
    ["help"] = function()
        print("Chat Scanner - type /CS to open the window. Commands:")
        print("/CS add [String] - add keyword (underscore = space, | = must match all, - = exclude)")
        print("/CS del [number] - remove keyword")
        print("/CS clear - clear keywords")
        print("/CS list - print keywords")
        print("/CS addplayer [Name] - ignore a player")
        print("/CS delplayer [number] - un-ignore a player")
        print("/CS clearplayers - clear ignored players")
        print("/CS players - print ignored players")
        print("/CS master - play sound even if muted")
        print("/CS mute - mute notification sound")
        print("/CS flash - flash the WoW taskbar icon")
        print("/CS enable | /CS disable - turn scanning on/off")
        print("/CS gui - open the window")
    end,

    ["gui"] = function() ToggleGUI() end,
    ["show"] = function() ToggleGUI() end,

    ["add"] = function(textstr)
        if not textstr or textstr == "" then
            print("Usage: /CS add [Keyword]")
            return
        end
        if whitelistedStringTable == nil then
            whitelistedStringTable = {}
        end
        textstr = textstr:gsub("_", " ")
        table.insert(whitelistedStringTable, textstr)
        print("-- Added: " .. textstr)
        Refresh()
    end,

    ["del"] = function(key)
        key = tonumber(key)
        if not key or not whitelistedStringTable or not whitelistedStringTable[key] then
            print("-- Invalid key number")
            return
        end
        print("-- Removed " .. key .. ": " .. whitelistedStringTable[key])
        table.remove(whitelistedStringTable, key)
        Refresh()
    end,

    ["clear"] = function()
        whitelistedStringTable = {}
        print("-- Watchlist Wiped")
        Refresh()
    end,

    ["master"] = function()
        settings.master = not settings.master
        print("-- master: " .. tostring(settings.master))
        Refresh()
    end,

    ["mute"] = function()
        settings.mute = not settings.mute
        print("-- mute: " .. tostring(settings.mute))
        Refresh()
    end,

    ["flash"] = function()
        settings.flash = not settings.flash
        print("-- flash: " .. tostring(settings.flash))
        Refresh()
    end,

    ["enable"] = function()
        settings.enabled = true
        print("-- Enabled")
        Refresh()
    end,

    ["disable"] = function()
        settings.enabled = false
        print("-- Disabled")
        Refresh()
    end,

    ["list"] = function()
        print("--")
        print("enabled: " .. tostring(settings.enabled))
        print("master: " .. tostring(settings.master))
        print("mute: " .. tostring(settings.mute))
        print("flash: " .. tostring(settings.flash))
        print("Watchlist:")
        if not whitelistedStringTable or #whitelistedStringTable == 0 then
            print("Watchlist is empty")
            return
        end
        for i, v in ipairs(whitelistedStringTable) do
            print(i, v)
        end
    end,

    ["addplayer"] = function(textstr)
        if not textstr or textstr == "" then
            print("Usage: /CS addplayer [PlayerName]")
            return
        end
        if whitelistedStringTablePlayersChat == nil then
            whitelistedStringTablePlayersChat = {}
        end
        table.insert(whitelistedStringTablePlayersChat, textstr)
        print("-- Added player: " .. textstr)
        Refresh()
    end,

    ["delplayer"] = function(key)
        key = tonumber(key)
        if not key or not whitelistedStringTablePlayersChat or not whitelistedStringTablePlayersChat[key] then
            print("-- Invalid player key number")
            return
        end
        print("-- Removed " .. key .. ": " .. whitelistedStringTablePlayersChat[key])
        table.remove(whitelistedStringTablePlayersChat, key)
        Refresh()
    end,

    ["clearplayers"] = function()
        whitelistedStringTablePlayersChat = {}
        print("-- Ignored players Wiped")
        Refresh()
    end,

    ["players"] = function()
        print("Ignored players:")
        if not whitelistedStringTablePlayersChat or #whitelistedStringTablePlayersChat == 0 then
            print("Ignore list is empty")
            return
        end
        for i, v in ipairs(whitelistedStringTablePlayersChat) do
            print(i, v)
        end
    end
}

function HandleSlashCommands(str)
    if (#str == 0) then
        ToggleGUI()
        return
    end

    local args = {}
    for _, arg in ipairs({ string.split(' ', str) }) do
        if (#arg > 0) then
            table.insert(args, arg)
        end
    end

    local path = commands

    for id, arg in ipairs(args) do
        if (#arg > 0) then
            arg = arg:lower()
            if (path[arg]) then
                if (type(path[arg]) == "function") then
                    path[arg](select(id + 1, unpack(args)))
                    return
                elseif (type(path[arg]) == "table") then
                    path = path[arg]
                end
            else
                print("-- Not a ChatScanner command: " .. arg .. " (try /CS help)")
                return
            end
        end
    end
end

SLASH_CS1 = "/CS"
SlashCmdList.CS = HandleSlashCommands

---------------------------------------------------------------------
-- Chat scanning
---------------------------------------------------------------------
local chatFrameScanner = CreateFrame("FRAME")
chatFrameScanner:RegisterEvent("CHAT_MSG_GUILD")
chatFrameScanner:RegisterEvent("CHAT_MSG_CHANNEL")
chatFrameScanner:RegisterEvent("CHAT_MSG_SAY")
chatFrameScanner:RegisterEvent("CHAT_MSG_YELL")

chatFrameScanner:SetScript("OnEvent", function(self, event, message, sender, chanString, chanNumber, chanName, _, _, _, _, _, _, guid)
    if not settings.enabled then return end

    -- 1. Guard against Secret Values (WoW Forever / 12.0+)
    if issecretvalue and (issecretvalue(sender) or issecretvalue(message) or issecretvalue(guid)) then
        return
    end

    -- 2. STRICT PLAYER CHECK: Drops NPCs, LocalDefense, system messages, and playerless broadcasts
    if not guid or type(guid) ~= "string" or guid:sub(1, 7) ~= "Player-" then
        return
    end

    -- 3. Guard against invalid sender or message
    if not sender or type(sender) ~= "string" or sender == "" then
        return
    end
    if not message or type(message) ~= "string" or message == "" then
        return
    end

    -- 4. Nothing to scan if the watchlist is empty
    if not whitelistedStringTable or #whitelistedStringTable == 0 then
        return
    end

    local myName = UnitName("player")
    local player = sender:gsub("-.*", "") -- Remove server name

    -- Don't scan messages from yourself
    if myName and player == myName then
        return
    end

    -- Check blacklisted / ignored players
    if whitelistedStringTablePlayersChat then
        for _, z in ipairs(whitelistedStringTablePlayersChat) do
            if z and z ~= "" and player:lower() == z:lower() then
                return
            end
        end
    end

    -- Sender Class Color
    local classColor = "FFFFFF"
    local class = select(1, GetPlayerInfoByGUID(guid))
    if     class == "Druid"        then classColor = "FF7D0A"
    elseif class == "Hunter"       then classColor = "ABD473"
    elseif class == "Mage"         then classColor = "69CCF0"
    elseif class == "Paladin"      then classColor = "F58CBA"
    elseif class == "Priest"       then classColor = "FFFFFF"
    elseif class == "Rogue"        then classColor = "FFF569"
    elseif class == "Shaman"       then classColor = "0070DE"
    elseif class == "Warlock"      then classColor = "9482C9"
    elseif class == "Warrior"      then classColor = "C79C6E"
    elseif class == "Death Knight" then classColor = "C41E3A"
    elseif class == "Demon Hunter" then classColor = "A330C9"
    elseif class == "Monk"         then classColor = "00FF98"
    elseif class == "Evoker"       then classColor = "33937F"
    end

    -- Clean up chat formatting and icons
    message = message:gsub("{[Ss][Qq][Uu][Aa][Rr][Ee]}", "")
    message = message:gsub("{[sS][Kk][uU][Ll][lL]}", "")
    message = message:gsub("{[Mm][oO][Oo][nN]}", "")
    message = message:gsub("{[sS][Tt][aA][Rr]}", "")
    message = message:gsub("{[cC][rR][oO][sS][sS]}", "")
    message = message:gsub("{[Cc][Ii][rR][cC][Ll][eE]}", "")
    message = message:gsub("{[xX]}", "")
    message = message:gsub("{[tT][rR][iI][Aa][Nn][gG][lL][eE]}", "")
    message = message:gsub("{[dD][iI][aA][mM][oO][nN][dD]}", "")
    message = message:gsub("{[Gg][rR][eE][Ee][nN]}", "")
    message = message:gsub("{[rR][Ee][dD]}", "")
    message = message:gsub("{[bB][lL][uU][Ee]}", "")
    message = message:gsub("{[pP][uU][rR][pP][lL][Ee]}", "")
    message = message:gsub("{rt%d%d?}", "")
    message = message:gsub("░", "")
    message = message:gsub("%s+", " ")
    message = message:gsub("☺", "")

    for id, v in ipairs(whitelistedStringTable) do
        if v and v ~= "" then
            local checkFound = true
            for w in string.gmatch(v:lower(), "([^|]+)") do
                local isExclude = (string.sub(w, 1, 1) == "-")
                local needle = isExclude and string.sub(w:lower(), 2) or w:lower()
                local found = (message:lower():find(needle, 1, true) ~= nil)

                if (not isExclude and not found) or (isExclude and found) then
                    checkFound = false
                    break
                end
            end

            if checkFound then
                if messageCheckDuplicate == message then
                    return
                else
                    messageCheckDuplicate = message
                end

                local msg
                local playerLink
                local coloredPlayerLink

                if event == "CHAT_MSG_GUILD" or event == "CHAT_MSG_SAY" or event == "CHAT_MSG_YELL" then
                    playerLink = string.format("|Hplayer:%s|h[%s]|h", sender, player)
                    coloredPlayerLink = string.format("|cff%s%s|r", classColor, playerLink)

                    local chatType = {
                        CHAT_MSG_GUILD = "Guild",
                        CHAT_MSG_SAY = "Say",
                        CHAT_MSG_YELL = "Yell"
                    }

                    msg = string.format("|cAAFF0000FOUND %d (|r|cff92ff58%s|r|cffFF0000):\n|cff5892ff[%s]|r |r%s|cff5892ff: %s|r",
                        id, v:upper():sub(1, 60), chatType[event] or event, coloredPlayerLink, message)
                else
                    playerLink = "|Hplayer:" .. sender .. "|h" .. (chanName or sender) .. "|h"
                    playerLink = "|cff" .. classColor .. "[" .. playerLink .. "]|r"
                    msg = "|cAAFF0000FOUND " .. id .. " (|r|cff92ff58" .. v:upper():sub(1, 60) .. "|r|cffFF0000): |r|cff5892ff\n[" .. (chanNumber or "Channel") .. "]|r " .. playerLink .. "|cff5892ff: " .. message .. "|r"
                end

                DEFAULT_CHAT_FRAME:AddMessage(msg)

                if not settings.mute then
                    if settings.master then
                        PlaySound(4041, "Master")
                    else
                        PlaySound(4041)
                    end
                end

                if settings.flash and FlashClientIcon then
                    FlashClientIcon()
                end

                return
            end
        end
    end
end)