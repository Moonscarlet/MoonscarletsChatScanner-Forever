local addonName = ...
local messageCheckDuplicate

local frameScanner = CreateFrame("FRAME")
frameScanner:RegisterEvent("ADDON_LOADED")
frameScanner:RegisterEvent("PLAYER_LOGOUT")
 
local enabled = true
local master = false
local mute = false
local flash = false

function frameScanner:OnEvent(event, arg1)
    if event == "ADDON_LOADED" and (arg1 == addonName or arg1 == "MoonscarletsChatScanner") then
        if whitelistedStringTable == nil then
            whitelistedStringTable = {}
        end
        if whitelistedStringTablePlayersChat == nil then
            whitelistedStringTablePlayersChat = {}
        end
    elseif event == "PLAYER_LOGOUT" then
        -- print("Player is logging out")
    end
end
 
frameScanner:SetScript("OnEvent", frameScanner.OnEvent)
 
local commands =
{
    ["help"] = function()
        print("Commands : ")
        print(" ")
        print("/CS add [String]")
        print('Description : Adds a string to whitelist (underscore for spaces - | for must match all - "-"to exclude a word)')
        print(" ")
        print("/CS del [key number]")
        print("Description : Removes string by number in the list")
        print(" ")
        print("/CS clear")
        print("Description : Clears the list")
        print(" ")
        print("/CS list")
        print("Description : Prints the watchlist")
        print(" ")
        print("/CS addplayer [String]")
        print('Description : Adds a player to blacklist')
        print(" ")
        print("/CS delplayer [key number]")
        print("Description : Removes a player by number from the blacklist")
        print(" ")
        print("/CS clearplayers")
        print("Description : Clears the blacklisted players list")
        print(" ")
        print("/CS players")
        print("Description : Prints the blacklisted players")
        print(" ")
        print("/CS master")
        print("Description : play notification even if muted")
        print(" ")
        print("/CS mute")
        print("Description : mute notification sound")
        print(" ")
        print("/CS flash")
        print("Description : flash wow window")
        print(" ")
        print("/CS enable")
        print("Description : Enables scanning")
        print(" ")
        print("/CS disable")
        print("Description : Disables scanning")
    end,
 
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
    end,
 
    ["del"] = function(key)
        key = tonumber(key)
        if not key or not whitelistedStringTable or not whitelistedStringTable[key] then
            print("-- Invalid key number")
            return
        end
        print("-- Removed " .. key.. ": " .. whitelistedStringTable[key])    
        table.remove(whitelistedStringTable, key)
    end,
    
    ["clear"] = function()
        whitelistedStringTable = {}
        print("-- Watchlist Wiped")
    end,
 
    ["master"] = function()
        master = not master
        print("-- master: " .. tostring(master))
    end,

    ["mute"] = function()
        mute = not mute
        print("-- mute: " .. tostring(mute))
    end,
    
    ["flash"] = function()
        flash = not flash
        print("-- flash: " .. tostring(flash))
    end,
    
    ["enable"] = function()
        enabled = true
        print("-- Enabled")
    end,

    ["disable"] = function()
        enabled = false
        print("-- Disabled")
    end,
    
    ["list"] = function()
        print("--")
        print("enabled: " .. tostring(enabled))
        print("master: " .. tostring(master))
        print("flash: " .. tostring(flash))
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
    end,
 
    ["delplayer"] = function(key)
        key = tonumber(key)
        if not key or not whitelistedStringTablePlayersChat or not whitelistedStringTablePlayersChat[key] then
            print("-- Invalid player key number")
            return
        end
        print("-- Removed " .. key.. ": " .. whitelistedStringTablePlayersChat[key])    
        table.remove(whitelistedStringTablePlayersChat, key)
    end,
    
    ["clearplayers"] = function()
        whitelistedStringTablePlayersChat = {}
        print("-- Ignored players Wiped")
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
        print("Command not recognized, showing help")
        commands.help()
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
                print("-- Not a ChatScanner command: " .. arg)
                return
            end
        end
    end
end
 
SLASH_CS1 = "/CS"
SlashCmdList.CS = HandleSlashCommands
 
local chatFrameScanner = CreateFrame("FRAME")
chatFrameScanner:RegisterEvent("CHAT_MSG_GUILD")
-- chatFrameScanner:RegisterEvent("CHAT_MSG_OFFICER")
--chatFrameScanner:RegisterEvent("CHAT_MSG_BATTLEGROUND")--NO
--chatFrameScanner:RegisterEvent("CHAT_MSG_BATTLEGROUND_LEADER")--NO
-- chatFrameScanner:RegisterEvent("CHAT_MSG_PARTY")
-- chatFrameScanner:RegisterEvent("CHAT_MSG_RAID_LEADER")
-- chatFrameScanner:RegisterEvent("CHAT_MSG_RAID")
-- chatFrameScanner:RegisterEvent("CHAT_MSG_WHISPER")
-- chatFrameScanner:RegisterEvent("CHAT_MSG_BN_WHISPER")
chatFrameScanner:RegisterEvent("CHAT_MSG_CHANNEL")
chatFrameScanner:RegisterEvent("CHAT_MSG_SAY")
chatFrameScanner:RegisterEvent("CHAT_MSG_YELL")

chatFrameScanner:SetScript("OnEvent", function(self, event, message, sender, chanString, chanNumber, chanName, _, _, _, _, _, _, guid)
    if not enabled then return end

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
            for w in string.gmatch(v:lower(), "([^\|]+)") do
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
                
                if not mute then
                    if master then
                        PlaySound(4041, "Master")
                    else
                        PlaySound(4041)
                    end
                end
                
                if flash and FlashClientIcon then
                    FlashClientIcon()
                end

                return
            end
        end
    end
end)