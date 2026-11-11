local addonName = ...
local messageCheckDuplicate

---------------------------------------------------------------------
-- Settings (saved in MoonscarletsChatScannerDB)
---------------------------------------------------------------------
local defaults = {
    enabled = true,             -- Scanner alerts switch
    filterEnabled = true,       -- Dedicated chat filter switch
    mute = false,
    master = false,
    flash = false,
    raidWarning = false,
    sound = 4041,
    color = "5892ff",
    chatFrame = 1,
    minimap = true,
    minimapAngle = 215,
    excludeFriendsGuild = true,
    logPosition = nil,
}
local settings = {}
for k, v in pairs(defaults) do settings[k] = v end

local sources = {
    { key = "guild", label = "Guild", desc = "Guild chat", default = true,
      events = { "CHAT_MSG_GUILD" } },
    { key = "say", label = "Say", desc = "Nearby players talking around you", default = true,
      events = { "CHAT_MSG_SAY" } },
    { key = "yell", label = "Yell", desc = "Players yelling in your zone", default = true,
      events = { "CHAT_MSG_YELL" } },
    { key = "channel", label = "Channels (Trade, LFG, World...)", desc = "Numbered chat channels, including custom ones", default = true,
      events = { "CHAT_MSG_CHANNEL" } },
    { key = "officer", label = "Officer", desc = "Guild officer chat", default = false,
      events = { "CHAT_MSG_OFFICER" } },
    { key = "party", label = "Party", desc = "Your party chat", default = false,
      events = { "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER" } },
    { key = "raid", label = "Raid", desc = "Your raid chat", default = false,
      events = { "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER" } },
    { key = "battleground", label = "Battleground / Instance", desc = "Battleground and instance group chat", default = false,
      events = { "CHAT_MSG_BATTLEGROUND", "CHAT_MSG_BATTLEGROUND_LEADER", "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER" } },
    { key = "whisper", label = "Whispers", desc = "Private messages sent to you", default = false,
      events = { "CHAT_MSG_WHISPER" } },
}
local eventSource = {}
for _, src in ipairs(sources) do
    for _, ev in ipairs(src.events) do eventSource[ev] = src.key end
end
local eventLabel = {
    CHAT_MSG_GUILD = "Guild", CHAT_MSG_OFFICER = "Officer", CHAT_MSG_SAY = "Say", CHAT_MSG_YELL = "Yell",
    CHAT_MSG_PARTY = "Party", CHAT_MSG_PARTY_LEADER = "Party", CHAT_MSG_RAID = "Raid", CHAT_MSG_RAID_LEADER = "Raid",
    CHAT_MSG_BATTLEGROUND = "Battleground", CHAT_MSG_BATTLEGROUND_LEADER = "Battleground",
    CHAT_MSG_INSTANCE_CHAT = "Instance", CHAT_MSG_INSTANCE_CHAT_LEADER = "Instance",
    CHAT_MSG_WHISPER = "Whisper",
}
local function EnsureSources(t)
    t.sources = t.sources or {}
    for _, src in ipairs(sources) do
        if t.sources[src.key] == nil then t.sources[src.key] = src.default end
    end
end
EnsureSources(settings)

---------------------------------------------------------------------
-- Guild & Friend Verification
---------------------------------------------------------------------
local guildMembersCache = {}
local function UpdateGuildCache()
    wipe(guildMembersCache)
    if not IsInGuild() then return end
    local n = GetNumGuildMembers()
    for i = 1, n do
        local name, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, memberGUID = GetGuildRosterInfo(i)
        if memberGUID then guildMembersCache[memberGUID] = true end
        if name then guildMembersCache[name:gsub("-.*", ""):lower()] = true end
    end
end

local function IsFriendOrGuildMember(sender, guid)
    if not settings.excludeFriendsGuild then return false end
    local player = sender and sender:gsub("-.*", ""):lower()

    if guid and C_FriendList and C_FriendList.IsFriend and C_FriendList.IsFriend(guid) then
        return true
    end
    if player and C_FriendList and C_FriendList.GetFriendInfo and C_FriendList.GetFriendInfo(player) then
        return true
    end
    if guid and C_BattleNet and C_BattleNet.GetGameAccountInfoByGUID then
        local bnet = C_BattleNet.GetGameAccountInfoByGUID(guid)
        if bnet and bnet.isFriend then return true end
    end

    if IsInGuild() then
        if (guid and guildMembersCache[guid]) or (player and guildMembersCache[player]) then
            return true
        end
    end

    return false
end

---------------------------------------------------------------------
-- Session Filtered Messages Log
---------------------------------------------------------------------
local MAX_FILTER_LOG = 150
local sessionFilteredLog = {}
local filterLogFrame
local filterLogButton
local UpdateFilterLogButton

---------------------------------------------------------------------
-- Alerts
---------------------------------------------------------------------
local sounds = {
    { id = 4041, name = "Cat" },
    { id = 8959, name = "Raid Warning" },
    { id = 8960, name = "Ready Check" },
    { id = 3081, name = "Whisper" },
    { id = 3175, name = "Map Ping" },
    { id = 5274, name = "Auction House" },
    { id = 878, name = "Quest Complete" },
    { id = 8459, name = "PvP Queue Ready" },
    { id = 12867, name = "Alarm Clock" },
    { id = 12197, name = "Boss Warning" },
    { id = 8474, name = "Screech" },
    { id = 6555, name = "Bell" },
    { id = 1431, name = "Lay on Hands" },
    { id = 1023, name = "Chicken" },
    { id = 1044, name = "Centaur" },
    { id = 3410, name = "Orca" },
    { id = 416, name = "Murloc" },
}

local function HexToRGB(hex)
    return tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255
end

local function RGBToHex(r, g, b)
    local function byte(v) return math.floor(math.min(math.max(v, 0), 1) * 255 + 0.5) end
    return string.format("%02x%02x%02x", byte(r), byte(g), byte(b))
end

local function PlayAlertSound()
    if settings.master then PlaySound(settings.sound, "Master") else PlaySound(settings.sound) end
end

local function ShowRaidWarning(text, r, g, b)
    local color = { r = r, g = g, b = b }
    if RaidWarningUtil and RaidWarningUtil.AddMessage then
        RaidWarningUtil.AddMessage(text, color)
    elseif RaidNotice_AddMessage and RaidWarningFrame then
        RaidNotice_AddMessage(RaidWarningFrame, text, color)
    end
end

local function AlertChatFrame()
    local i = settings.chatFrame
    if i ~= 1 and FCF_IsChatWindowIndexActive(i) then
        return _G["ChatFrame" .. i], i
    end
    return DEFAULT_CHAT_FRAME, 1
end

local function Notify(id, label, source, who, message)
    local hex = settings.color
    local body = "|cff" .. hex .. "[" .. source .. "]|r " .. who .. "|cff" .. hex .. ": " .. message .. "|r"

    AlertChatFrame():AddMessage("|cAAFF0000FOUND " .. id .. " (|r|cff92ff58" .. label .. "|r|cffFF0000):|r\n" .. body)

    if not settings.mute then
        PlayAlertSound()
    end

    if settings.raidWarning then
        ShowRaidWarning(body, HexToRGB(hex))
    end

    if settings.flash and FlashClientIcon then
        FlashClientIcon()
    end
end

---------------------------------------------------------------------
-- Keyword & Pattern Utilities
---------------------------------------------------------------------
local function SplitTerms(str)
    local out = {}
    for piece in (str .. ","):gmatch("([^,]*),") do
        local clean = piece:gsub("|", "")
        if clean ~= "" then out[#out + 1] = clean end
    end
    return out
end

local function IsOff(v) return v and v:sub(1, 1) == "~" end
local function SetOff(v, off)
    local base = (v:gsub("^~+", ""))
    return off and ("~" .. base) or base
end

local function BuildKeyword(include, exclude, mode)
    if mode == "regex" then
        local pat = strtrim(include or ""):gsub("^~+", "")
        if pat == "" then return nil end
        return "regex:" .. pat
    end

    local parts = {}
    for _, term in ipairs(SplitTerms(include or "")) do
        local t = term:gsub("^[%-~]+", "")
        if t ~= "" then parts[#parts + 1] = t end
    end
    if #parts == 0 then return nil end
    for _, t in ipairs(SplitTerms(exclude or "")) do
        local clean = t:gsub("^[%-~]+", "")
        if clean ~= "" then parts[#parts + 1] = "-" .. clean end
    end
    return table.concat(parts, "|")
end

local function FormatKeyword(v)
    local off = IsOff(v)
    local raw = v:gsub("^~+", "")

    if raw:sub(1, 6) == "regex:" then
        local pat = raw:sub(7)
        if off then
            return "|cff777777[Regex] " .. pat .. " (off)|r"
        else
            return "|cff5892ff[Regex]|r |cffffd100" .. pat .. "|r"
        end
    end

    local inc, exc = {}, {}
    for w in raw:gmatch("([^|]+)") do
        if w:sub(1, 1) == "-" then exc[#exc + 1] = '"' .. w:sub(2) .. '"'
        else inc[#inc + 1] = '"' .. w .. '"' end
    end
    if off then
        local s = table.concat(inc, " + ")
        if #exc > 0 then s = s .. "   NOT " .. table.concat(exc, ", ") end
        return "|cff666666" .. s .. "  (off)|r"
    end
    local s = table.concat(inc, " |cff888888+|r ")
    if #exc > 0 then
        s = s .. "   |cffff6060NOT|r " .. table.concat(exc, ", ")
    end
    return s
end

local function ParseKeyword(v)
    local raw = v:gsub("^~+", "")
    if raw:sub(1, 6) == "regex:" then
        return raw:sub(7), "", "regex"
    end
    local inc, exc = {}, {}
    for w in raw:gmatch("([^|]+)") do
        if w:sub(1, 1) == "-" then exc[#exc + 1] = w:sub(2) else inc[#inc + 1] = w end
    end
    return table.concat(inc, ","), table.concat(exc, ","), "normal"
end

local function FoundLabel(v)
    local raw = v:gsub("^~+", "")
    if raw:sub(1, 6) == "regex:" then
        return "[REGEX] " .. raw:sub(7):sub(1, 50)
    end
    local inc, exc = {}, {}
    for w in raw:gmatch("([^|]+)") do
        if w:sub(1, 1) == "-" then exc[#exc + 1] = w:sub(2) else inc[#inc + 1] = w end
    end
    local s = table.concat(inc, " + ")
    if #exc > 0 then s = s .. " NOT " .. table.concat(exc, ", ") end
    return s:upper():sub(1, 60)
end

local function RegexToLuaPattern(pat)
    pat = pat:gsub("^\\b", "%%f[%%w]")
    pat = pat:gsub("\\b$", "%%f[%%W]")
    pat = pat:gsub("\\b([%w%%%a%d%[])", "%%f[%%w]%1")
    pat = pat:gsub("([%w%+%*%?%]%a%d])\\b", "%1%%f[%%W]")
    pat = pat:gsub("\\b", "%%f[%%w]")

    pat = pat:gsub("\\w", "%%w")
    pat = pat:gsub("\\W", "%%W")
    pat = pat:gsub("\\s", "%%s")
    pat = pat:gsub("\\S", "%%S")
    pat = pat:gsub("\\d", "%%d")
    pat = pat:gsub("\\D", "%%D")
    pat = pat:gsub("\\a", "%%a")
    pat = pat:gsub("\\A", "%%A")
    return pat
end

local function MakeCaseInsensitivePattern(pat)
    return (pat:gsub("(%%?)(%a)", function(prefix, letter)
        if prefix == "%" then
            return prefix .. letter
        else
            return letter:lower()
        end
    end))
end

local function CleanMessage(msg)
    msg = msg:gsub("{[Ss][Qq][Uu][Aa][Rr][Ee]}", "")
    msg = msg:gsub("{[sS][Kk][uU][Ll][lL]}", "")
    msg = msg:gsub("{[Mm][oO][Oo][nN]}", "")
    msg = msg:gsub("{[sS][Tt][aA][Rr]}", "")
    msg = msg:gsub("{[cC][rR][oO][sS][sS]}", "")
    msg = msg:gsub("{[Cc][Ii][rR][cC][Ll][eE]}", "")
    msg = msg:gsub("{[xX]}", "")
    msg = msg:gsub("{[tT][rR][iI][Aa][Nn][gG][lL][eE]}", "")
    msg = msg:gsub("{[dD][iI][aA][mM][oO][nN][dD]}", "")
    msg = msg:gsub("{[Gg][rR][eE][Ee][nN]}", "")
    msg = msg:gsub("{[rR][Ee][dD]}", "")
    msg = msg:gsub("{[bB][lL][uU][Ee]}", "")
    msg = msg:gsub("{[pP][uU][rR][pP][lL][Ee]}", "")
    msg = msg:gsub("{rt%d%d?}", "")
    msg = msg:gsub("░", "")
    msg = msg:gsub("%s+", " ")
    msg = msg:gsub("☺", "")
    return msg
end

local function TestMessageMatch(msgClean, keywordEntry)
    if not keywordEntry or keywordEntry == "" or IsOff(keywordEntry) then
        return false
    end

    local raw = keywordEntry:gsub("^~+", "")

    if raw:sub(1, 6) == "regex:" then
        local pattern = raw:sub(7)
        if pattern == "" then return false end

        pattern = RegexToLuaPattern(pattern)

        local insens = MakeCaseInsensitivePattern(pattern)
        local ok, found = pcall(string.find, msgClean:lower(), insens)
        if ok and found then return true end

        local ok2, found2 = pcall(string.find, msgClean, pattern)
        return (ok2 and found2 ~= nil)
    end

    for w in string.gmatch(raw:lower(), "([^|]+)") do
        local isExclude = (w:sub(1, 1) == "-")
        local needle = isExclude and w:sub(2) or w
        local found = (msgClean:lower():find(needle, 1, true) ~= nil)
        if (not isExclude and not found) or (isExclude and found) then
            return false
        end
    end

    return true
end

local function GetClassColorHex(guid)
    if not guid or type(guid) ~= "string" then return "FFFFFF" end
    local class = select(1, GetPlayerInfoByGUID(guid))
    if     class == "Druid"        then return "FF7D0A"
    elseif class == "Hunter"       then return "ABD473"
    elseif class == "Mage"         then return "69CCF0"
    elseif class == "Paladin"      then return "F58CBA"
    elseif class == "Priest"       then return "FFFFFF"
    elseif class == "Rogue"        then return "FFF569"
    elseif class == "Shaman"       then return "0070DE"
    elseif class == "Warlock"      then return "9482C9"
    elseif class == "Warrior"      then return "C79C6E"
    elseif class == "Death Knight" then return "C41E3A"
    elseif class == "Demon Hunter" then return "A330C9"
    elseif class == "Monk"         then return "00FF98"
    elseif class == "Evoker"       then return "33937F"
    end
    return "FFFFFF"
end

---------------------------------------------------------------------
-- GUI Helpers
---------------------------------------------------------------------
local FRAME_W, FRAME_H = 480, 420
local ACCENT = { 0.36, 0.57, 1.0 }
local BACKDROP_TEMPLATE = BackdropTemplateMixin and "BackdropTemplate" or nil

local mainFrame, headerToggle, minimapButton
local panels, tabs = {}, {}
local settingsRefreshers = {}
local RefreshUI, ToggleGUI, InitUI

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

local function AlignDropdownText(dd, yNudge)
    local fs = dd and dd:GetFontString()
    if fs then
        fs:ClearAllPoints()
        fs:SetPoint("LEFT", dd, "LEFT", 8, yNudge or 4)
        fs:SetPoint("RIGHT", dd, "RIGHT", -22, yNudge or 4)
    end
end

-- Confirmation Dialog: calls data or self.data reliably across all client versions
StaticPopupDialogs["MCS_CONFIRM_CLEAR"] = {
    text = "%s",
    button1 = YES,
    button2 = NO,
    OnAccept = function(self, data)
        local action = data or (self and self.data)
        if action then action() end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

local function CreateScrollContainer(parent)
    local scroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 0, -4)
    scroll:SetPoint("BOTTOMRIGHT", -26, 4)

    local child = CreateFrame("Frame", nil, scroll)
    child:SetPoint("TOPLEFT")
    child:SetWidth(FRAME_W - 26)
    child:SetHeight(1)
    scroll:SetScrollChild(child)

    scroll:SetScript("OnSizeChanged", function(self, w)
        child:SetWidth(w)
    end)
    return scroll, child
end

---------------------------------------------------------------------
-- Filter Log Window
---------------------------------------------------------------------
local function SaveLogWindowPosition()
    if not filterLogFrame then return end
    local point, _, relPoint, x, y = filterLogFrame:GetPoint()
    settings.logPosition = {
        point = point,
        relPoint = relPoint,
        x = math.floor(x + 0.5),
        y = math.floor(y + 0.5),
        w = math.floor(filterLogFrame:GetWidth() + 0.5),
        h = math.floor(filterLogFrame:GetHeight() + 0.5),
    }
end

local function EnsureMenuStrata()
    if DropDownList1 then DropDownList1:SetFrameStrata("TOOLTIP") end
    if DropDownList2 then DropDownList2:SetFrameStrata("TOOLTIP") end
end

local function CreateFilterLogFrame()
    local f = CreateFrame("Frame", "MoonscarletsChatScannerLogFrame", UIParent, BACKDROP_TEMPLATE)
    
    f:SetFrameStrata("DIALOG")
    f:SetToplevel(true)

    if settings.logPosition then
        local p = settings.logPosition
        f:SetSize(p.w or 520, p.h or 380)
        f:ClearAllPoints()
        f:SetPoint(p.point or "CENTER", UIParent, p.relPoint or "CENTER", p.x or 30, p.y or -20)
    else
        f:SetSize(520, 380)
        f:SetPoint("CENTER", 30, -20)
    end

    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SaveLogWindowPosition()
    end)
    f:SetResizable(true)
    if f.SetResizeBounds then
        f:SetResizeBounds(420, 240, 800, 700)
    elseif f.SetMinResize then
        f:SetMinResize(420, 240)
        f:SetMaxResize(800, 700)
    end
    SkinFrame(f, 0.07, 0.07, 0.10, 0.98)
    f:Hide()
    tinsert(UISpecialFrames, "MoonscarletsChatScannerLogFrame")

    local resizer = CreateFrame("Button", nil, f)
    resizer:SetSize(16, 16)
    resizer:SetPoint("BOTTOMRIGHT", -2, 2)
    resizer:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resizer:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resizer:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    resizer:SetScript("OnMouseDown", function() f:StartSizing("BOTTOMRIGHT") end)
    resizer:SetScript("OnMouseUp", function()
        f:StopMovingOrSizing()
        SaveLogWindowPosition()
        if f.Refresh then f.Refresh() end
    end)

    local bar = f:CreateTexture(nil, "ARTWORK")
    bar:SetPoint("TOPLEFT", 1, -1)
    bar:SetPoint("TOPRIGHT", -1, -1)
    bar:SetHeight(30)
    bar:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 0.18)

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 14, -8)
    title:SetText("Filtered Messages (Session)")

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 1)

    local sub = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    sub:SetPoint("TOPLEFT", 16, -36)
    sub:SetText("Messages blocked during this session (clears on reload/relog). Click to whisper, Shift-Click to query/link.")

    local clearBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    clearBtn:SetSize(100, 22)
    clearBtn:SetPoint("BOTTOMRIGHT", -14, 12)
    clearBtn:SetText("Clear Log")
    clearBtn:SetScript("OnClick", function()
        wipe(sessionFilteredLog)
        if f.Refresh then f.Refresh() end
        if UpdateFilterLogButton then UpdateFilterLogButton() end
    end)

    local countText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    countText:SetPoint("BOTTOMLEFT", 16, 16)

    local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 14, -54)
    scroll:SetPoint("BOTTOMRIGHT", -32, 42)

    local listBg = CreateFrame("Frame", nil, f, BACKDROP_TEMPLATE)
    listBg:SetPoint("TOPLEFT", scroll, -4, 4)
    listBg:SetPoint("BOTTOMRIGHT", scroll, 24, -4)
    listBg:SetFrameLevel(scroll:GetFrameLevel() - 1)
    SkinFrame(listBg, 0.04, 0.04, 0.06, 0.8)

    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(f:GetWidth() - 46, 1)
    scroll:SetScrollChild(child)

    scroll:SetScript("OnSizeChanged", function(self, w)
        child:SetWidth(w)
        if f.Refresh then f.Refresh() end
    end)

    local empty = scroll:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    empty:SetPoint("CENTER", scroll, "CENTER", 0, 0)
    empty:SetText("No messages have been filtered yet this session.")

    local rows = {}

    f.Refresh = function()
        local yOffset = 0
        local availWidth = child:GetWidth()
        local hex = settings.color or "5892ff"

        for i = 1, #sessionFilteredLog do
            local data = sessionFilteredLog[i]
            local row = rows[i]
            if not row then
                row = CreateFrame("Frame", nil, child)
                row.bg = row:CreateTexture(nil, "BACKGROUND")
                row.bg:SetAllPoints()

                row:EnableMouse(true)
                if row.SetHyperlinksEnabled then
                    row:SetHyperlinksEnabled(true)
                end

                -- Line 1: Header (Timestamp + Rule)
                row.header = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                row.header:SetPoint("TOPLEFT", 8, -4)
                row.header:SetPoint("RIGHT", -8, 0)
                row.header:SetJustifyH("LEFT")

                -- Line 2: Unified Chat Message FontString (continuous line)
                row.body = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                row.body:SetPoint("TOPLEFT", 8, -20)
                row.body:SetPoint("RIGHT", -8, 0)
                row.body:SetJustifyH("LEFT")
                row.body:SetWordWrap(true)
                row.body:SetSpacing(2)

                -- Hyperlink handlers for profession/item/spell and player links
                row:SetScript("OnHyperlinkEnter", function(self, link)
                    if link and link:sub(1, 7) ~= "player:" then
                        ShowUIPanel(GameTooltip)
                        GameTooltip:SetOwner(UIParent, "ANCHOR_CURSOR")
                        GameTooltip:SetHyperlink(link)
                        GameTooltip:Show()
                    end
                end)

                row:SetScript("OnHyperlinkLeave", function(self)
                    GameTooltip_Hide()
                end)

                row:SetScript("OnHyperlinkClick", function(self, link, text, button)
                    if link:sub(1, 7) == "player:" then
                        local rawSender = link:sub(8):match("^[^:]+") or link:sub(8)
                        if IsShiftKeyDown() then
                            local inserted = false
                            if ChatEdit_InsertLink and ChatEdit_InsertLink(rawSender) then
                                inserted = true
                            else
                                local editBox = ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow()
                                if editBox and editBox:IsVisible() then
                                    editBox:Insert(rawSender)
                                    inserted = true
                                end
                            end
                            if not inserted then
                                if C_FriendList and C_FriendList.SendWho then
                                    C_FriendList.SendWho(rawSender)
                                elseif SendWho then
                                    SendWho(rawSender)
                                end
                            end
                        elseif button == "RightButton" then
                            EnsureMenuStrata()
                            if SetItemRef then
                                pcall(SetItemRef, link, text, button, self)
                            end
                            EnsureMenuStrata()
                        else
                            ChatFrame_OpenChat("/w " .. rawSender .. " ")
                        end
                    else
                        if SetItemRef then
                            SetItemRef(link, text, button, self)
                        end
                    end
                end)

                rows[i] = row
            end

            row:SetWidth(availWidth)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", 0, -yOffset)
            row:SetPoint("TOPRIGHT", 0, -yOffset)
            row.bg:SetColorTexture(1, 1, 1, i % 2 == 0 and 0.04 or 0.0)

            -- Line 1: [Time] BLOCKED (RULE):
            row.header:SetText(string.format("|cff888888[%s]|r |cffff4040BLOCKED (|r|cff92ff58%s|r|cffff4040):|r",
                data.time or "", data.matchedLabel or ""))

            -- Line 2: [Channel] [Player]: message
            local who = data.player or "Unknown"
            local rawSender = data.rawSender or who
            local color = data.classColor or "FFFFFF"
            local channelStr = string.format("|cff%s[%s]|r", hex, data.source or "Chat")
            local playerLink = string.format("|cff%s|Hplayer:%s|h[%s]|h|r", color, rawSender, who)
            local msgStr = string.format("|cff%s: %s|r", hex, data.message or "")

            row.body:SetText(channelStr .. " " .. playerLink .. msgStr)

            local bodyHeight = math.ceil(row.body:GetStringHeight())
            local rowH = math.max(38, 20 + bodyHeight + 6)
            row:SetHeight(rowH)
            row:Show()

            yOffset = yOffset + rowH
        end

        for i = #sessionFilteredLog + 1, #rows do
            rows[i]:Hide()
        end

        child:SetHeight(math.max(yOffset, 1))
        empty:SetShown(#sessionFilteredLog == 0)
        countText:SetText(#sessionFilteredLog .. " blocked message" .. (#sessionFilteredLog == 1 and "" or "s"))
        clearBtn:SetEnabled(#sessionFilteredLog > 0)
    end

    return f
end

local function ToggleFilterLog()
    if not filterLogFrame then
        filterLogFrame = CreateFilterLogFrame()
    end
    if filterLogFrame:IsShown() then
        filterLogFrame:Hide()
    else
        filterLogFrame.Refresh()
        filterLogFrame:Show()
        filterLogFrame:Raise()
    end
end

UpdateFilterLogButton = function()
    if filterLogButton then
        filterLogButton:SetText(string.format("View Blocked (%d)", #sessionFilteredLog))
    end
end

---------------------------------------------------------------------
-- List Panel Builder with Drag & Drop Reordering
---------------------------------------------------------------------
local function CreateListPanel(parent, cfg)
    local panel = CreateFrame("Frame", nil, parent)
    panel:SetAllPoints()

    local tip = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    tip:SetPoint("TOPLEFT", 16, -10)
    tip:SetPoint("TOPRIGHT", -16, -10)
    tip:SetJustifyH("LEFT")
    tip:SetSpacing(2)
    tip:SetText(cfg.tip)

    local inputContainer = CreateFrame("Frame", nil, panel)
    inputContainer:SetPoint("TOPLEFT", tip, "BOTTOMLEFT", 0, -8)
    inputContainer:SetPoint("TOPRIGHT", tip, "BOTTOMRIGHT", 0, -8)
    inputContainer:SetHeight(cfg.placeholder2 and 106 or 54)

    local currentMode = "normal"
    local eb, eb2, label1, label2, pl1, pl2, modeDropdown, filterToggleBtn

    local function MakeBox(y, width, ph)
        local box = CreateFrame("EditBox", nil, inputContainer, "InputBoxTemplate")
        box:SetPoint("TOPLEFT", 6, y)
        box:SetSize(width, 22)
        box:SetAutoFocus(false)
        box:SetMaxLetters(150)
        local pl = box:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        pl:SetPoint("LEFT", 4, 0)
        pl:SetText(ph)
        box:SetScript("OnTextChanged", function(self) pl:SetShown(self:GetText() == "") end)
        return box, pl
    end

    local function MakeLabel(text)
        local l = inputContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        l:SetJustifyH("LEFT")
        l:SetText(text)
        return l
    end

    local addBtn = CreateFrame("Button", nil, inputContainer, "UIPanelButtonTemplate")
    addBtn:SetSize(66, 22)
    addBtn:SetText("Add")

    local cancelBtn = CreateFrame("Button", nil, inputContainer, "UIPanelButtonTemplate")
    cancelBtn:SetSize(66, 22)
    cancelBtn:SetText("Cancel")
    cancelBtn:SetPoint("LEFT", addBtn, "RIGHT", 4, 0)
    cancelBtn:Hide()

    local function SetDropdownText(text)
        if modeDropdown then
            modeDropdown:SetDefaultText(text)
            AlignDropdownText(modeDropdown, 4)
        end
    end

    local function UpdateModeView()
        if not cfg.hasMode then return end
        if currentMode == "regex" then
            SetDropdownText("Mode: Regex")
            label1:SetText("Pattern (Regex / Lua):")
            pl1:SetText(cfg.regexPlaceholder or "e.g. \\b\\w+e\\w+\\b   or   %d+%s*gold")
            if label2 then label2:Hide() end
            if eb2 then eb2:Hide() end
            eb:ClearAllPoints()
            eb:SetPoint("TOPLEFT", 6, -26)
            eb:SetPoint("RIGHT", addBtn, "LEFT", -6, 0)
            addBtn:ClearAllPoints()
            addBtn:SetPoint("TOPRIGHT", -72, -26)
            inputContainer:SetHeight(54)
        else
            SetDropdownText("Mode: Normal")
            label1:SetText(cfg.label or "Message contains:")
            pl1:SetText(cfg.placeholder or "e.g. LFM Molten Core    or    tank,healer")
            if label2 then label2:Show() end
            if eb2 then eb2:Show() end
            eb:ClearAllPoints()
            eb:SetPoint("TOPLEFT", 6, -26)
            eb:SetPoint("RIGHT", 0, -26)
            addBtn:ClearAllPoints()
            if eb2 then
                addBtn:SetPoint("LEFT", eb2, "RIGHT", 6, 0)
                inputContainer:SetHeight(106)
            else
                addBtn:SetPoint("TOPRIGHT", -72, -26)
                inputContainer:SetHeight(54)
            end
        end
    end

    if cfg.hasMode then
        modeDropdown = CreateFrame("DropdownButton", nil, inputContainer, "WowStyle1DropdownTemplate")
        modeDropdown:SetSize(135, 22)
        modeDropdown:SetPoint("TOPRIGHT", 0, 0)
        modeDropdown:SetupMenu(function(_, root)
            root:CreateRadio("Normal (words)", function() return currentMode == "normal" end, function()
                currentMode = "normal"
                UpdateModeView()
            end)
            root:CreateRadio("Regex (pattern)", function() return currentMode == "regex" end, function()
                currentMode = "regex"
                UpdateModeView()
            end)
        end)
    end

    if cfg.hasFilterToggle then
        filterToggleBtn = CreateFrame("Button", nil, inputContainer, "UIPanelButtonTemplate")
        filterToggleBtn:SetSize(96, 22)
        filterToggleBtn:SetPoint("RIGHT", modeDropdown, "LEFT", -6, 0)

        local function UpdateFilterToggleBtn()
            if settings.filterEnabled then
                filterToggleBtn:SetText("Filter: |cff00ff00ON|r")
            else
                filterToggleBtn:SetText("Filter: |cffff4040OFF|r")
            end
        end

        filterToggleBtn:SetScript("OnClick", function()
            settings.filterEnabled = not settings.filterEnabled
            UpdateFilterToggleBtn()
            print("-- Chat Filter " .. (settings.filterEnabled and "enabled" or "disabled"))
        end)

        UpdateFilterToggleBtn()
        table.insert(settingsRefreshers, UpdateFilterToggleBtn)
    end

    if cfg.placeholder2 then
        eb, pl1 = MakeBox(-26, 200, cfg.placeholder)
        label2 = MakeLabel(cfg.label2)
        label2:SetPoint("TOPLEFT", 6, -56)
        eb2, pl2 = MakeBox(-74, 270, cfg.placeholder2)
        addBtn:SetPoint("LEFT", eb2, "RIGHT", 6, 0)
        eb:SetScript("OnTabPressed", function() if eb2:IsShown() then eb2:SetFocus() end end)
        eb2:SetScript("OnTabPressed", function() eb:SetFocus() end)
    else
        eb, pl1 = MakeBox(-26, 270, cfg.placeholder)
        addBtn:SetPoint("LEFT", eb, "RIGHT", 6, 0)
    end

    label1 = MakeLabel(cfg.label or "")
    label1:SetPoint("BOTTOMLEFT", eb, "TOPLEFT", 0, 5)
    if filterToggleBtn then
        label1:SetPoint("RIGHT", filterToggleBtn, "LEFT", -6, 0)
    elseif modeDropdown then
        label1:SetPoint("RIGHT", modeDropdown, "LEFT", -6, 0)
    end

    UpdateModeView()

    local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", inputContainer, "BOTTOMLEFT", -2, -6)
    scroll:SetPoint("BOTTOMRIGHT", -32, 44)

    local listBg = CreateFrame("Frame", nil, panel, BACKDROP_TEMPLATE)
    listBg:SetPoint("TOPLEFT", scroll, -4, 4)
    listBg:SetPoint("BOTTOMRIGHT", scroll, 24, -4)
    listBg:SetFrameLevel(scroll:GetFrameLevel() - 1)
    SkinFrame(listBg, 0.04, 0.04, 0.06, 0.8)

    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(FRAME_W - 46, 1)
    scroll:SetScrollChild(child)

    local dropLine = child:CreateTexture(nil, "OVERLAY")
    dropLine:SetHeight(2)
    dropLine:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 1)
    dropLine:Hide()

    local dragGhost = CreateFrame("Frame", nil, UIParent, BACKDROP_TEMPLATE)
    dragGhost:SetFrameStrata("TOOLTIP")
    dragGhost:SetSize(220, 24)
    SkinFrame(dragGhost, ACCENT[1], ACCENT[2], ACCENT[3], 0.75)
    dragGhost.text = dragGhost:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    dragGhost.text:SetPoint("LEFT", 10, 0)
    dragGhost.text:SetPoint("RIGHT", -10, 0)
    dragGhost.text:SetJustifyH("LEFT")
    dragGhost:EnableMouse(false)
    dragGhost:Hide()

    scroll:SetScript("OnSizeChanged", function(self, w)
        child:SetWidth(w)
    end)

    local empty = scroll:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    empty:SetPoint("TOP", scroll, "TOP", 0, -30)
    empty:SetText(cfg.empty)

    local countText = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    countText:SetPoint("BOTTOMLEFT", 16, 16)

    local clearBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    clearBtn:SetSize(100, 22)
    clearBtn:SetPoint("BOTTOMRIGHT", -14, 12)
    clearBtn:SetText("Clear all")

    if cfg.extraButton then
        local extraBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        extraBtn:SetSize(cfg.extraButton.width or 130, 22)
        extraBtn:SetPoint("RIGHT", clearBtn, "LEFT", -6, 0)
        extraBtn:SetText(cfg.extraButton.text)
        extraBtn:SetScript("OnClick", cfg.extraButton.onClick)
        if cfg.extraButton.onInit then
            cfg.extraButton.onInit(extraBtn)
        end
    end

    local rows = {}
    local ROW_H = 24
    local editing
    local draggingIndex, targetDropIndex
    local Refresh
    local parse = cfg.parse or function(v) return v, "", "normal" end

    local function FinishDrag()
        if not draggingIndex then return end
        dragGhost:SetScript("OnUpdate", nil)
        dragGhost:Hide()
        dropLine:Hide()

        local list = cfg.get()
        if targetDropIndex and draggingIndex and targetDropIndex ~= draggingIndex then
            local item = table.remove(list, draggingIndex)
            local dest = targetDropIndex
            if dest > draggingIndex then
                dest = dest - 1
            end
            dest = math.max(1, math.min(#list + 1, dest))
            table.insert(list, dest, item)
            RefreshUI()
        end
        draggingIndex = nil
        targetDropIndex = nil
    end

    local function SetEditing(i)
        editing = i
        addBtn:SetText(i and "Save" or "Add")
        cancelBtn:SetShown(i ~= nil)
        if i then
            local t1, t2, mode = parse(cfg.get()[i])
            currentMode = mode or "normal"
            UpdateModeView()
            eb:SetText(t1 or "")
            if eb2 then eb2:SetText(t2 or "") end
            eb:SetFocus()
        else
            currentMode = "normal"
            UpdateModeView()
            eb:SetText("")
            if eb2 then eb2:SetText("") end
        end
        Refresh()
    end

    local function OnEscape(self)
        self:ClearFocus()
        if editing then SetEditing(nil) end
    end
    eb:SetScript("OnEscapePressed", OnEscape)
    if eb2 then eb2:SetScript("OnEscapePressed", OnEscape) end
    cancelBtn:SetScript("OnClick", function() SetEditing(nil) end)

    Refresh = function()
        local list = cfg.get()
        if editing and not list[editing] then
            editing = nil
            addBtn:SetText("Add")
            cancelBtn:Hide()
        end
        for i = 1, math.max(#list, #rows) do
            local row = rows[i]
            if i <= #list then
                if not row then
                    row = CreateFrame("Frame", nil, child)
                    row:SetHeight(ROW_H)
                    row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
                    row:SetPoint("TOPRIGHT", 0, -(i - 1) * ROW_H)
                    row.bg = row:CreateTexture(nil, "BACKGROUND")
                    row.bg:SetAllPoints()

                    row.grip = CreateFrame("Button", nil, row)
                    row.grip:SetSize(14, ROW_H)
                    row.grip:SetPoint("LEFT", 4, 0)
                    row.grip.text = row.grip:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
                    row.grip.text:SetPoint("CENTER", 0, 0)
                    row.grip.text:SetText("::")
                    row.grip:RegisterForDrag("LeftButton")

                    row.grip:SetScript("OnEnter", function(self)
                        self.text:SetTextColor(ACCENT[1], ACCENT[2], ACCENT[3], 1)
                        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                        GameTooltip:SetText("Drag to reorder", 1, 1, 1)
                        GameTooltip:Show()
                    end)
                    row.grip:SetScript("OnLeave", function(self)
                        self.text:SetTextColor(0.5, 0.5, 0.5, 1)
                        GameTooltip_Hide()
                    end)

                    row.num = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                    row.num:SetPoint("LEFT", row.grip, "RIGHT", 2, 0)
                    row.num:SetWidth(20)
                    row.num:SetJustifyH("LEFT")

                    row.del = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
                    row.del:SetSize(22, 18)
                    row.del:SetPoint("RIGHT", -6, 0)
                    row.del:SetText("X")

                    row.edit = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
                    row.edit:SetSize(40, 18)
                    row.edit:SetPoint("RIGHT", row.del, "LEFT", -4, 0)
                    row.edit:SetText("Edit")

                    if cfg.isOff then
                        row.toggle = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
                        row.toggle:SetSize(36, 18)
                        row.toggle:SetPoint("RIGHT", row.edit, "LEFT", -4, 0)
                    end

                    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                    row.text:SetPoint("LEFT", row.num, "RIGHT", 4, 0)
                    row.text:SetPoint("RIGHT", (row.toggle or row.edit), "LEFT", -6)
                    row.text:SetJustifyH("LEFT")
                    row.text:SetWordWrap(false)

                    rows[i] = row
                end

                row.grip:SetScript("OnDragStart", function()
                    draggingIndex = i
                    targetDropIndex = i
                    dragGhost.text:SetText(cfg.format and cfg.format(list[i]) or list[i])
                    dragGhost:SetWidth(math.min(row:GetWidth(), 260))
                    dragGhost:Show()
                    dropLine:Show()

                    dragGhost:SetScript("OnUpdate", function(self)
                        local cx, cy = GetCursorPosition()
                        local uiScale = UIParent:GetEffectiveScale()
                        self:ClearAllPoints()
                        self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cx / uiScale, cy / uiScale)

                        local childTop = child:GetTop()
                        local childScale = child:GetEffectiveScale()
                        if childTop then
                            local relY = childTop - (cy / childScale)
                            local slot = math.floor((relY + ROW_H * 0.5) / ROW_H) + 1
                            slot = math.max(1, math.min(#list + 1, slot))
                            targetDropIndex = slot

                            dropLine:ClearAllPoints()
                            dropLine:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -(slot - 1) * ROW_H)
                            dropLine:SetPoint("TOPRIGHT", child, "TOPRIGHT", 0, -(slot - 1) * ROW_H)
                        end
                    end)
                end)
                row.grip:SetScript("OnDragStop", FinishDrag)
                row.grip:SetScript("OnMouseUp", FinishDrag)

                if i == editing then
                    row.bg:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 0.25)
                else
                    row.bg:SetColorTexture(1, 1, 1, i % 2 == 0 and 0.05 or 0.0)
                end
                row.num:SetText(i)
                row.text:SetText(cfg.format and cfg.format(list[i]) or list[i])
                if row.toggle then
                    row.toggle:SetText(cfg.isOff(list[i]) and "|cffff6060Off|r" or "|cff40ff40On|r")
                    row.toggle:SetScript("OnClick", function()
                        local l = cfg.get()
                        l[i] = cfg.setOff(l[i], not cfg.isOff(l[i]))
                        RefreshUI()
                    end)
                end
                row.edit:SetScript("OnClick", function() SetEditing(i) end)
                row.del:SetScript("OnClick", function()
                    table.remove(cfg.get(), i)
                    if editing == i then
                        SetEditing(nil)
                    elseif editing and editing > i then
                        editing = editing - 1
                    end
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
        local value = cfg.build(eb:GetText() or "", eb2 and eb2:GetText() or "", currentMode)
        if not value then return end
        local list = cfg.get()
        if editing and list[editing] then
            if cfg.isOff and cfg.isOff(list[editing]) then value = cfg.setOff(value, true) end
            list[editing] = value
        else
            table.insert(list, value)
        end
        SetEditing(nil)
        RefreshUI()
    end
    addBtn:SetScript("OnClick", DoAdd)
    eb:SetScript("OnEnterPressed", DoAdd)
    if eb2 then eb2:SetScript("OnEnterPressed", DoAdd) end

    -- Wipes table in-place so database reference persists across relog/reload
    clearBtn:SetScript("OnClick", function()
        local action = function()
            cfg.clear()
            SetEditing(nil)
            RefreshUI()
        end
        local dialog = StaticPopup_Show("MCS_CONFIRM_CLEAR", cfg.confirm, nil, action)
        if dialog then
            dialog.data = action
        end
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

local function CreateDropdown(parent, y, generator)
    local dd = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
    dd:SetPoint("TOPRIGHT", -16, y - 1)
    dd:SetSize(170, 22)
    dd:SetupMenu(generator)
    AlignDropdownText(dd, 4)
    return dd
end

local function CreateSoundDropdown(parent, y)
    local function IsSelected(id) return settings.sound == id end
    local function SetSelected(id)
        settings.sound = id
        PlayAlertSound()
        return MenuResponse.Refresh
    end
    local dd = CreateDropdown(parent, y, function(_, root)
        for _, s in ipairs(sounds) do
            local name = s.id == defaults.sound and s.name .. " (default)" or s.name
            root:CreateRadio(name, IsSelected, SetSelected, s.id)
        end
    end)
    dd:SetDefaultText("Custom")
    AlignDropdownText(dd, 4)
    table.insert(settingsRefreshers, function() dd:SetEnabled(not settings.mute) end)
    return dd
end

local function CreateChatTabDropdown(parent, y)
    local t = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    t:SetPoint("LEFT", parent, "TOPLEFT", 46, y - 12)
    t:SetText("Show alerts in this chat tab")
    local d = parent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    d:SetPoint("TOPLEFT", 46, y - 23)
    d:SetText("If that tab gets closed, the first tab is used.")

    local function IsSelected(i) return select(2, AlertChatFrame()) == i end
    local function SetSelected(i) settings.chatFrame = i end
    return CreateDropdown(parent, y, function(_, root)
        FCF_IterateActiveChatWindows(function(frame, i)
            if not IsCombatLog(frame) then
                root:CreateRadio((FCF_GetChatWindowInfo(i)), IsSelected, SetSelected, i)
            end
        end)
    end)
end

local function CreateColorSwatch(parent, y, label, desc, key)
    local sw = CreateFrame("Button", nil, parent)
    sw:SetPoint("TOPLEFT", 21, y - 5)
    sw:SetSize(16, 16)
    sw:SetHitRectInsets(-5, -5, -5, -5)
    local border = sw:CreateTexture(nil, "BACKGROUND")
    border:SetPoint("TOPLEFT", -1, 1)
    border:SetPoint("BOTTOMRIGHT", 1, -1)
    border:SetColorTexture(0.6, 0.6, 0.65, 1)
    local color = sw:CreateTexture(nil, "ARTWORK")
    color:SetAllPoints()
    local t = sw:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    t:SetPoint("LEFT", sw, "RIGHT", 9, 1)
    t:SetText(label)
    local d = sw:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    d:SetPoint("TOPLEFT", sw, "BOTTOMLEFT", 25, -2)
    d:SetText(desc)

    local reset = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    reset:SetSize(60, 20)
    reset:SetPoint("TOPRIGHT", -16, y - 3)
    reset:SetText("Reset")

    local function Update()
        color:SetColorTexture(HexToRGB(settings[key]))
        reset:SetEnabled(settings[key] ~= defaults[key])
    end
    local function Set(hex)
        settings[key] = hex
        Update()
    end
    sw:SetScript("OnClick", function()
        local old = settings[key]
        local r, g, b = HexToRGB(old)
        ColorPickerFrame:SetupColorPickerAndShow({
            r = r, g = g, b = b,
            hasOpacity = false,
            swatchFunc = function() Set(RGBToHex(ColorPickerFrame:GetColorRGB())) end,
            cancelFunc = function() Set(old) end,
        })
    end)
    reset:SetScript("OnClick", function() Set(defaults[key]) end)
    table.insert(settingsRefreshers, Update)
    return sw
end

local function CreateSettingsPanel(parent)
    local panel = CreateFrame("Frame", nil, parent)
    panel:SetAllPoints()
    local scroll, content = CreateScrollContainer(panel)

    CreateCheckbox(content, -16, "Enable scanning",
        "Master switch for search notifications and sound alerts.",
        function() return settings.enabled end,
        function(v) settings.enabled = v end)

    CreateCheckbox(content, -60, "Play a sound when a match is found",
        "Uncheck for silent chat alerts only.",
        function() return not settings.mute end,
        function(v) settings.mute = not v end)
    CreateSoundDropdown(content, -60)

    CreateCheckbox(content, -104, "Play sound even if game sound is muted",
        "Uses the Master volume channel so you never miss an alert.",
        function() return settings.master end,
        function(v) settings.master = v end)

    CreateCheckbox(content, -148, "Show a raid warning style alert",
        "Also shows the match as big text in the middle of your screen.",
        function() return settings.raidWarning end,
        function(v) settings.raidWarning = v end)

    CreateCheckbox(content, -192, "Flash the WoW icon in the taskbar",
        "Helpful when the game is minimized or in the background.",
        function() return settings.flash end,
        function(v) settings.flash = v end)

    CreateChatTabDropdown(content, -236)

    CreateColorSwatch(content, -280, "Alert text color",
        "Click the swatch to change the color of matched messages.",
        "color")

    CreateCheckbox(content, -324, "Never filter friends or guild members",
        "Keep receiving chat from friends and guildies even if they match filter keywords.",
        function() return settings.excludeFriendsGuild end,
        function(v) settings.excludeFriendsGuild = v end)

    CreateCheckbox(content, -368, "Show minimap button",
        "Left-click opens this window, right-click toggles scanning.",
        function() return settings.minimap end,
        function(v)
            settings.minimap = v
            if minimapButton then minimapButton:SetShown(v) end
        end)

    local test = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    test:SetSize(140, 24)
    test:SetPoint("TOPLEFT", 20, -420)
    test:SetText("Test notification")
    test:SetScript("OnClick", function()
        Notify(1, "TEST", "Test", "|cffffffff[Someone]|r", "This is what a match looks like!")
    end)

    local tipText = content:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    tipText:SetPoint("TOPLEFT", test, "BOTTOMLEFT", 2, -14)
    tipText:SetPoint("RIGHT", content, "RIGHT", -20)
    tipText:SetJustifyH("LEFT")
    tipText:SetSpacing(2)
    tipText:SetText("Tip: put Trade / LFG / World channels in a separate chat tab and let this addon alert you in your main tab only when something you care about is posted.")

    content:SetHeight(520)

    panel.Refresh = function()
        for _, fn in ipairs(settingsRefreshers) do fn() end
    end
    return panel
end

local function CreateChannelsPanel(parent)
    local panel = CreateFrame("Frame", nil, parent)
    panel:SetAllPoints()
    local scroll, content = CreateScrollContainer(panel)

    local intro = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    intro:SetPoint("TOPLEFT", 16, -10)
    intro:SetPoint("RIGHT", content, "RIGHT", -16)
    intro:SetJustifyH("LEFT")
    intro:SetText("Choose which chats the scanner and filter listen to.")

    local y = -34
    local function Heading(text)
        local h = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        h:SetPoint("TOPLEFT", 18, y)
        h:SetText(text)
        y = y - 22
    end
    local function AddSources(wantDefault)
        for _, src in ipairs(sources) do
            if src.default == wantDefault then
                CreateCheckbox(content, y, src.label, src.desc,
                    function() return settings.sources[src.key] end,
                    function(v) settings.sources[src.key] = v end)
                y = y - 36
            end
        end
    end

    Heading("Scanned by default")
    AddSources(true)
    y = y - 6
    Heading("Other chats (off by default)")
    AddSources(false)

    content:SetHeight(math.abs(y) + 20)

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
        GameTooltip:AddLine("Moonscarlet's Chat Scanner")
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
    
    f:SetFrameStrata("HIGH")
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    SkinFrame(f, 0.07, 0.07, 0.10, 0.96)
    f:Hide()
    tinsert(UISpecialFrames, "MoonscarletsChatScannerFrame")

    f:SetResizable(true)
    if f.SetResizeBounds then
        f:SetResizeBounds(440, 280, 800, 700)
    elseif f.SetMinResize then
        f:SetMinResize(440, 280)
        f:SetMaxResize(800, 700)
    end

    local resizer = CreateFrame("Button", nil, f)
    resizer:SetSize(16, 16)
    resizer:SetPoint("BOTTOMRIGHT", -2, 2)
    resizer:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resizer:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resizer:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    resizer:SetScript("OnMouseDown", function() f:StartSizing("BOTTOMRIGHT") end)
    resizer:SetScript("OnMouseUp", function()
        f:StopMovingOrSizing()
        RefreshUI()
    end)

    local bar = f:CreateTexture(nil, "ARTWORK")
    bar:SetPoint("TOPLEFT", 1, -1)
    bar:SetPoint("TOPRIGHT", -1, -1)
    bar:SetHeight(30)
    bar:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 0.18)

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 14, -8)
    title:SetText("Moonscarlet's Chat Scanner")

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 1)

    headerToggle = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    headerToggle:SetSize(110, 20)
    headerToggle:SetPoint("TOPRIGHT", -36, -6)
    headerToggle:SetScript("OnClick", function()
        settings.enabled = not settings.enabled
        RefreshUI()
    end)

    local tabDefs = {
        { name = "Keywords", width = 74 },
        { name = "Filter", width = 60 },
        { name = "Ignored Players", width = 106 },
        { name = "Chats", width = 56 },
        { name = "Settings", width = 70 },
    }
    local content = CreateFrame("Frame", nil, f)
    content:SetPoint("TOPLEFT", 0, -64)
    content:SetPoint("BOTTOMRIGHT", 0, 0)

    local divider = f:CreateTexture(nil, "ARTWORK")
    divider:SetPoint("TOPLEFT", 1, -63)
    divider:SetPoint("TOPRIGHT", -1, -63)
    divider:SetHeight(1)
    divider:SetColorTexture(0.25, 0.25, 0.3, 1)

    local x = 10
    for i, def in ipairs(tabDefs) do
        local tab = CreateFrame("Button", nil, f)
        tab:SetSize(def.width, 26)
        tab:SetPoint("TOPLEFT", x, -36)
        x = x + def.width + 4
        tab.text = tab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        tab.text:SetPoint("CENTER")
        tab.text:SetText(def.name)
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

    -- 1. Keywords panel
    panels[1] = CreateListPanel(content, {
        hasMode = true,
        get = function() return whitelistedStringTable end,
        clear = function()
            wipe(whitelistedStringTable)
            if MoonscarletsChatScannerDB then MoonscarletsChatScannerDB.keywords = whitelistedStringTable end
        end,
        build = BuildKeyword,
        format = FormatKeyword,
        parse = ParseKeyword,
        isOff = IsOff,
        setOff = SetOff,
        tip = "Get alerted when player chat matches what you type below. Drag :: to reorder. Normal mode: comma = AND. Regex mode: supports \\b, \\w, \\s, \\d or Lua patterns.",
        label = "Message contains:",
        placeholder = "e.g. LFM Molten Core    or    tank,healer",
        label2 = "...but NOT any of these (optional):",
        placeholder2 = "e.g. gold,boost",
        regexPlaceholder = "e.g. \\b\\w+e\\w+\\b   or   %d+%s*gold",
        empty = "No keywords yet - add one above!",
        single = "keyword", plural = "keywords",
        confirm = "Remove ALL keywords from your watch list?",
    })

    -- 2. Filter panel (Includes dedicated Filter ON/OFF toggle and View Blocked button)
    panels[2] = CreateListPanel(content, {
        hasMode = true,
        hasFilterToggle = true,
        get = function() return filteredStringTable end,
        clear = function()
            wipe(filteredStringTable)
            if MoonscarletsChatScannerDB then MoonscarletsChatScannerDB.filters = filteredStringTable end
        end,
        build = BuildKeyword,
        format = FormatKeyword,
        parse = ParseKeyword,
        isOff = IsOff,
        setOff = SetOff,
        tip = "Messages matching any keyword or pattern below will be hidden from all chat tabs. Drag :: to reorder. Supports standard regex (\\b, \\w, \\d) and Lua patterns.",
        label = "Filter message containing:",
        placeholder = "e.g. boost,wts    or    g2g",
        label2 = "...but NOT any of these (optional):",
        placeholder2 = "e.g. guild,free",
        regexPlaceholder = "e.g. \\bboost\\b   or   wts.*run",
        empty = "No filters active. Add words or patterns above to hide them!",
        single = "filter", plural = "filters",
        confirm = "Remove ALL filters from your block list?",
        extraButton = {
            text = "View Blocked (0)",
            width = 135,
            onInit = function(btn)
                filterLogButton = btn
                UpdateFilterLogButton()
            end,
            onClick = function()
                ToggleFilterLog()
            end,
        },
    })

    -- 3. Ignored Players panel
    panels[3] = CreateListPanel(content, {
        hasMode = false,
        get = function() return whitelistedStringTablePlayersChat end,
        clear = function()
            wipe(whitelistedStringTablePlayersChat)
            if MoonscarletsChatScannerDB then MoonscarletsChatScannerDB.ignoredPlayers = whitelistedStringTablePlayersChat end
        end,
        build = function(t)
            t = strtrim(t)
            t = t:gsub("-.*", "")
            if t == "" then return nil end
            return t
        end,
        tip = "Players on this list are ignored by the scanner - handy for spammers who keep matching your keywords. Drag :: to reorder.",
        placeholder = "Player name",
        empty = "Nobody is ignored. Nice!",
        single = "player", plural = "players",
        confirm = "Remove ALL players from the ignore list?",
    })

    -- 4. Chats panel
    panels[4] = CreateChannelsPanel(content)

    -- 5. Settings panel
    panels[5] = CreateSettingsPanel(content)

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

ToggleGUI = function(tabIndex)
    if not mainFrame then return end
    if mainFrame:IsShown() and not tabIndex then
        mainFrame:Hide()
    else
        RefreshUI()
        if tabIndex then SelectTab(tabIndex) end
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
frameScanner:RegisterEvent("GUILD_ROSTER_UPDATE")
frameScanner:RegisterEvent("PLAYER_ENTERING_WORLD")

function frameScanner:OnEvent(event, arg1)
    if event == "ADDON_LOADED" and (arg1 == addonName or arg1 == "MoonscarletsChatScanner") then
        MoonscarletsChatScannerDB = MoonscarletsChatScannerDB or {}
        for k, v in pairs(defaults) do
            if MoonscarletsChatScannerDB[k] == nil then
                MoonscarletsChatScannerDB[k] = v
            end
        end
        settings = MoonscarletsChatScannerDB
        EnsureSources(settings)

        MoonscarletsChatScannerDB.keywords = MoonscarletsChatScannerDB.keywords or whitelistedStringTable or {}
        whitelistedStringTable = MoonscarletsChatScannerDB.keywords

        MoonscarletsChatScannerDB.filters = MoonscarletsChatScannerDB.filters or filteredStringTable or {}
        filteredStringTable = MoonscarletsChatScannerDB.filters

        MoonscarletsChatScannerDB.ignoredPlayers = MoonscarletsChatScannerDB.ignoredPlayers or whitelistedStringTablePlayersChat or {}
        whitelistedStringTablePlayersChat = MoonscarletsChatScannerDB.ignoredPlayers

        InitUI()
    elseif event == "GUILD_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD" then
        if IsInGuild() then
            UpdateGuildCache()
        end
    end
end

frameScanner:SetScript("OnEvent", frameScanner.OnEvent)

---------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------
local function Refresh() if RefreshUI then RefreshUI() end end

local commands = {}

local function HandleFilterCommand(arg)
    if not arg or arg == "" then
        ToggleGUI(2)
    elseif arg:lower() == "on" or arg:lower() == "enable" then
        settings.filterEnabled = true
        print("-- Chat Filter enabled")
        Refresh()
    elseif arg:lower() == "off" or arg:lower() == "disable" then
        settings.filterEnabled = false
        print("-- Chat Filter disabled")
        Refresh()
    else
        ToggleGUI(2)
    end
end

commands["help"] = function()
    print("Chat Scanner - type /CS to open the window. Commands:")
    print("/CS add [String] - add keyword (underscore = space, | = must match all, - = exclude)")
    print("/CS addregex [Pattern] - add regex keyword")
    print("/CS del [number] - remove keyword")
    print("/CS f | /CS filter [on|off] - open Filter tab, or turn filtering on/off")
    print("/CS log - open the Filtered Messages log")
    print("/CS toggle [number] [number] ... - turn keywords on/off")
    print("/CS clear - clear keywords")
    print("/CS clearfilters - clear filters")
    print("/CS list - print keywords, filters, and settings")
    print("/CS addplayer [Name] - ignore a player")
    print("/CS delplayer [number] - un-ignore a player")
    print("/CS clearplayers - clear ignored players")
    print("/CS players - print ignored players")
    print("/CS enable | /CS disable - turn scanner alerts on/off")
    print("/CS gui - open the window")
end

commands["gui"] = function() ToggleGUI() end
commands["show"] = function() ToggleGUI() end
commands["f"] = HandleFilterCommand
commands["filter"] = HandleFilterCommand
commands["log"] = function() ToggleFilterLog() end

commands["add"] = function(textstr)
    if not textstr or textstr == "" then
        print("Usage: /CS add [Keyword]")
        return
    end
    if whitelistedStringTable == nil then whitelistedStringTable = {} end
    textstr = textstr:gsub("_", " "):gsub("^~+", "")
    table.insert(whitelistedStringTable, textstr)
    print("-- Added: " .. FormatKeyword(textstr))
    Refresh()
end

commands["addregex"] = function(pat)
    if not pat or pat == "" then
        print("Usage: /CS addregex [Pattern]")
        return
    end
    if whitelistedStringTable == nil then whitelistedStringTable = {} end
    table.insert(whitelistedStringTable, "regex:" .. pat)
    print("-- Added regex: " .. FormatKeyword("regex:" .. pat))
    Refresh()
end

commands["del"] = function(key)
    key = tonumber(key)
    if not key or not whitelistedStringTable or not whitelistedStringTable[key] then
        print("-- Invalid key number")
        return
    end
    print("-- Removed " .. key .. ": " .. FormatKeyword(whitelistedStringTable[key]))
    table.remove(whitelistedStringTable, key)
    Refresh()
end

commands["toggle"] = function(...)
    local n = select("#", ...)
    if n == 0 then
        print("Usage: /CS toggle [number] [number] ...")
        return
    end
    for i = 1, n do
        local arg = select(i, ...)
        local key = tonumber(arg)
        local v = key and whitelistedStringTable and whitelistedStringTable[key]
        if not v then
            print("-- Invalid key number: " .. tostring(arg))
        else
            v = SetOff(v, not IsOff(v))
            whitelistedStringTable[key] = v
            print("-- " .. key .. ": " .. (IsOff(v) and "|cffff4040OFF|r " or "|cff00ff00ON|r ") .. FormatKeyword(v))
        end
    end
    Refresh()
end

commands["edit"] = function(key, textstr)
    key = tonumber(key)
    if not key or not whitelistedStringTable or not whitelistedStringTable[key] then
        print("-- Invalid key number")
        return
    end
    if not textstr or textstr == "" then
        print("Usage: /CS edit [number] [Keyword]")
        return
    end
    textstr = textstr:gsub("_", " "):gsub("^~+", "")
    if IsOff(whitelistedStringTable[key]) then textstr = "~" .. textstr end
    whitelistedStringTable[key] = textstr
    print("-- Edited " .. key .. ": " .. FormatKeyword(textstr))
    Refresh()
end

commands["clear"] = function()
    wipe(whitelistedStringTable)
    if MoonscarletsChatScannerDB then MoonscarletsChatScannerDB.keywords = whitelistedStringTable end
    print("-- Watchlist Wiped")
    Refresh()
end

commands["clearfilters"] = function()
    wipe(filteredStringTable)
    if MoonscarletsChatScannerDB then MoonscarletsChatScannerDB.filters = filteredStringTable end
    print("-- Filter list Wiped")
    Refresh()
end

commands["master"] = function()
    settings.master = not settings.master
    print("-- master: " .. tostring(settings.master))
    Refresh()
end

commands["mute"] = function()
    settings.mute = not settings.mute
    print("-- mute: " .. tostring(settings.mute))
    Refresh()
end

commands["flash"] = function()
    settings.flash = not settings.flash
    print("-- flash: " .. tostring(settings.flash))
    Refresh()
end

commands["enable"] = function()
    settings.enabled = true
    print("-- Scanner alerts enabled")
    Refresh()
end

commands["disable"] = function()
    settings.enabled = false
    print("-- Scanner alerts disabled")
    Refresh()
end

commands["list"] = function()
    print("--")
    print("Scanning: " .. (settings.enabled and "|cff00ff00ON|r" or "|cffff4040OFF|r"))
    print("Filtering: " .. (settings.filterEnabled and "|cff00ff00ON|r" or "|cffff4040OFF|r"))
    print("master: " .. tostring(settings.master))
    print("mute: " .. tostring(settings.mute))
    print("flash: " .. tostring(settings.flash))
    print("Watchlist:")
    if not whitelistedStringTable or #whitelistedStringTable == 0 then
        print("Watchlist is empty")
    else
        for i, v in ipairs(whitelistedStringTable) do
            print(i, FormatKeyword(v))
        end
    end
    print("Filters:")
    if not filteredStringTable or #filteredStringTable == 0 then
        print("Filter list is empty")
    else
        for i, v in ipairs(filteredStringTable) do
            print(i, FormatKeyword(v))
        end
    end
end

commands["addplayer"] = function(textstr)
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
end

commands["delplayer"] = function(key)
    key = tonumber(key)
    if not key or not whitelistedStringTablePlayersChat or not whitelistedStringTablePlayersChat[key] then
        print("-- Invalid player key number")
        return
    end
    print("-- Removed " .. key .. ": " .. whitelistedStringTablePlayersChat[key])
    table.remove(whitelistedStringTablePlayersChat, key)
    Refresh()
end

commands["clearplayers"] = function()
    wipe(whitelistedStringTablePlayersChat)
    if MoonscarletsChatScannerDB then MoonscarletsChatScannerDB.ignoredPlayers = whitelistedStringTablePlayersChat end
    print("-- Ignored players Wiped")
    Refresh()
end

commands["players"] = function()
    print("Ignored players:")
    if not whitelistedStringTablePlayersChat or #whitelistedStringTablePlayersChat == 0 then
        print("Ignore list is empty")
        return
    end
    for i, v in ipairs(whitelistedStringTablePlayersChat) do
        print(i, v)
    end
end

function HandleSlashCommands(str)
    if (#str == 0) then
        ToggleGUI()
        return
    end

    local args = {}
    for _, arg in ipairs({ string.split(' ', str) }) do
        if (#arg > 0) then table.insert(args, arg) end
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
-- Chat Filter Engine
---------------------------------------------------------------------
local lastFilteredLineID

local function ChatFilterHandler(self, event, message, sender, _, _, _, _, _, chanNumber, chanName, _, lineID, guid)
    if not settings.filterEnabled then return false end
    if not filteredStringTable or #filteredStringTable == 0 then return false end

    local sourceKey = eventSource[event]
    if sourceKey and settings.sources and not settings.sources[sourceKey] then
        return false
    end

    if issecretvalue and (issecretvalue(sender) or issecretvalue(message)) then
        return false
    end

    if not message or type(message) ~= "string" or message == "" then
        return false
    end

    if settings.excludeFriendsGuild and IsFriendOrGuildMember(sender, guid) then
        return false
    end

    local cleanMsg = CleanMessage(message)

    for _, filterEntry in ipairs(filteredStringTable) do
        if filterEntry and filterEntry ~= "" and not IsOff(filterEntry) then
            if TestMessageMatch(cleanMsg, filterEntry) then
                if not lineID or lineID ~= lastFilteredLineID then
                    lastFilteredLineID = lineID
                    local player = sender and sender:gsub("-.*", "") or "Unknown"
                    table.insert(sessionFilteredLog, 1, {
                        time = date("%H:%M:%S"),
                        source = eventLabel[event] or chanName or chanNumber or "Chat",
                        player = player,
                        rawSender = sender or player,
                        classColor = GetClassColorHex(guid),
                        message = message,
                        matchedLabel = FoundLabel(filterEntry),
                    })
                    if #sessionFilteredLog > MAX_FILTER_LOG then
                        table.remove(sessionFilteredLog)
                    end
                    UpdateFilterLogButton()
                    if filterLogFrame and filterLogFrame:IsShown() then
                        filterLogFrame.Refresh()
                    end
                end

                return true
            end
        end
    end

    return false
end

---------------------------------------------------------------------
-- Chat scanning & registration
---------------------------------------------------------------------
local chatFrameScanner = CreateFrame("FRAME")
for _, src in ipairs(sources) do
    for _, ev in ipairs(src.events) do
        pcall(chatFrameScanner.RegisterEvent, chatFrameScanner, ev)
        pcall(ChatFrame_AddMessageEventFilter, ev, ChatFilterHandler)
    end
end

chatFrameScanner:SetScript("OnEvent", function(self, event, message, sender, chanString, chanNumber, chanName, _, _, _, _, _, _, guid)
    if not settings.enabled then return end

    local sourceKey = eventSource[event]
    if sourceKey and not settings.sources[sourceKey] then return end

    if issecretvalue and (issecretvalue(sender) or issecretvalue(message) or issecretvalue(guid)) then
        return
    end

    if not guid or type(guid) ~= "string" or guid:sub(1, 7) ~= "Player-" then
        return
    end

    if not sender or type(sender) ~= "string" or sender == "" then return end
    if not message or type(message) ~= "string" or message == "" then return end
    if not whitelistedStringTable or #whitelistedStringTable == 0 then return end

    local myName = UnitName("player")
    local player = sender:gsub("-.*", "")

    if myName and player == myName then return end

    if whitelistedStringTablePlayersChat then
        for _, z in ipairs(whitelistedStringTablePlayersChat) do
            if z and z ~= "" and player:lower() == z:lower() then
                return
            end
        end
    end

    local cleanMsg = CleanMessage(message)

    if settings.filterEnabled and filteredStringTable then
        local isFriendGuild = settings.excludeFriendsGuild and IsFriendOrGuildMember(sender, guid)
        if not isFriendGuild then
            for _, fv in ipairs(filteredStringTable) do
                if fv and fv ~= "" and not IsOff(fv) then
                    if TestMessageMatch(cleanMsg, fv) then
                        return
                    end
                end
            end
        end
    end

    local classColor = GetClassColorHex(guid)

    for id, v in ipairs(whitelistedStringTable) do
        if v and v ~= "" and not IsOff(v) then
            if TestMessageMatch(cleanMsg, v) then
                if messageCheckDuplicate == message then
                    return
                else
                    messageCheckDuplicate = message
                end

                local source
                local playerLink
                local coloredPlayerLink

                if event ~= "CHAT_MSG_CHANNEL" then
                    source = eventLabel[event] or event
                    playerLink = string.format("|Hplayer:%s|h[%s]|h", sender, player)
                    coloredPlayerLink = string.format("|cff%s%s|r", classColor, playerLink)
                else
                    source = chanNumber or "Channel"
                    playerLink = "|Hplayer:" .. sender .. "|h" .. (chanName or sender) .. "|h"
                    coloredPlayerLink = "|cff" .. classColor .. "[" .. playerLink .. "]|r"
                end

                Notify(id, FoundLabel(v), source, coloredPlayerLink, message)
                return
            end
        end
    end
end)