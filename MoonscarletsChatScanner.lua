local messageCheckDuplicate


local frameScanner = CreateFrame("FRAME")
frameScanner:RegisterEvent("ADDON_LOADED"); -- Fired when saved variables are loaded
frameScanner:RegisterEvent("PLAYER_LOGOUT"); -- Fired when user is logging out
 
local enabled = true
-- local master = true
local master = false
local mute = false
local flash = false

function frameScanner:OnEvent(event)
    if event == "ADDON_LOADED" then
        --print("Addon loaded")
    elseif event == "PLAYER_LOGOUT" then
         print("Player is logging out")
    end
end
 
frameScanner:SetScript("OnEvent", frameScanner.OnEvent);
 
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
        if whitelistedStringTable == nil then
            print("--")
            print("No string table detected, creating a new, empty one")
            whitelistedStringTable = {nil}
        end
		textstr= textstr:gsub("_", " ")
        table.insert(whitelistedStringTable, textstr)
    end,
 
    ["del"] = function(key)
		print("--")
		print("Removed "..key)    
		table.remove(whitelistedStringTable, key)
    end,
	
    ["clear"] = function()
        wipe(whitelistedStringTable)
        print("--")
        print("Wiped")
    end,
 
    ["master"] = function()
		master= not master
        print("--")
        print("master: " .. tostring(master))
    end,

    ["mute"] = function()
		mute= not mute
        print("--")
        print("mute: " .. tostring(mute))
    end,
	
     ["flash"] = function()
		flash= not flash
        print("--")
        print("flash: " .. tostring(flash))
    end,
	
     ["enable"] = function()
		enabled= true
        print("--")
        print("Enabled")
    end,

     ["disable"] = function()
		enabled= false
        print("--")
        print("Disabled")
    end,
	
    ["list"] = function()
		print("--")
		print("enabled: " .. tostring(enabled))
		print("master: " .. tostring(master))
		print("flash: " .. tostring(flash))
        print("Watchlist:")
        if (whitelistedStringTable == nil) then
             print("Watchlist is empty")
			 return
        end
 
        for i,v in ipairs(whitelistedStringTable) do
            print(i,v)
        end
    end,

    ["addplayer"] = function(textstr)
        if whitelistedStringTablePlayersChat == nil then
            print("--")
            print("No string table detected, creating a new, empty one")
            whitelistedStringTablePlayersChat = {}
			table.insert(whitelistedStringTablePlayersChat, "")
        end
        table.insert(whitelistedStringTablePlayersChat, textstr)
    end,
 
    ["delplayer"] = function(key)
		print("--")
		print("Removed "..key)    
		table.remove(whitelistedStringTablePlayersChat, key)
    end,
	
    ["clearplayers"] = function()
        wipe(whitelistedStringTablePlayersChat)
        print("--")
        print("Wiped")
    end,
	
	["players"] = function()
        print("Ignored players:")
        if (whitelistedStringTablePlayersChat == nil) then
             print("Ignore list is empty")
			 return
        end
 
        for i,v in ipairs(whitelistedStringTablePlayersChat) do
            print(i,v)
        end
    end
	
}
 
 
function HandleSlashCommands(str)  
    if (#str == 0) then
        print("Command not recognized, showing help")
        commands.help()
        return;    
    end
   
    local args = {};
    for _, arg in ipairs({ string.split(' ', str) }) do
        if (#arg > 0) then
            table.insert(args, arg);
        end
    end
   
    local path = commands;
   
    for id, arg in ipairs(args) do
        if (#arg > 0) then
            arg = arg:lower();         
            if (path[arg]) then
                if (type(path[arg]) == "function") then            
                    path[arg](select(id + 1, unpack(args)));
                    return;                
                elseif (type(path[arg]) == "table") then               
                    path = path[arg];
                end
            else
                print("--")
                print("Not a ChatScanner command")
                print("Arguement numcount : " , #arg)
                print("Arguement : " , arg)
                return;
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
 
 function removeSquareBrackets(message)
    return message:gsub("{[Ss][Qq][Uu][Aa][Rr][Ee]}", "")
end

-- Example usage:



chatFrameScanner:SetScript("OnEvent", function(self,event,message,sender,chanString,chanNumber,chanName,_,_,_,_,_,_,guid)
	local class, _, _, _, _, _, _ = GetPlayerInfoByGUID(guid) --class of sender
	local player = sender:gsub("-.*", "")--REMOVE -server name from sender
	local myName,_ = UnitName("player") -- Get my name
	message =  message:gsub("{[Ss][Qq][Uu][Aa][Rr][Ee]}", "")--remove marks
	message =  message:gsub("{[sS][Kk][uU][Ll][lL]}", "")--remove marks
	message =  message:gsub("{[Mm][oO][Oo][nN]}", "")--remove marks
	message =  message:gsub("{[sS][Tt][aA][Rr]}", "")--remove marks
	message =  message:gsub("{[cC][rR][oO][sS][sS]}", "")--remove marks
	message =  message:gsub("{[Cc][Ii][rR][cC][Ll][eE]}", "")--remove marks
	message =  message:gsub("{[xX]}", "")--remove marks
	message =  message:gsub("{[tT][rR][iI][Aa][Nn][gG][lL][eE]}", "")--remove marks
	message =  message:gsub("{[dD][iI][aA][mM][oO][nN][dD]}", "")--remove marks
	message =  message:gsub("{[Gg][rR][eE][Ee][nN]}", "")--remove marks
	message =  message:gsub("{[rR][Ee][dD]}", "")--remove marks
	message =  message:gsub("{[bB][lL][uU][Ee]}", "")--remove marks
	message =  message:gsub("{[pP][uU][rR][pP][lL][Ee]}", "")--remove marks
	message =  message:gsub("{rt%d%d?}", "")
	
	message =  message:gsub("░", "")
	message =  message:gsub("%s+"," ")
	message =  message:gsub("☺", "")

	------------------CLASS COLORS
	local classColor
	if 	   class=="Druid" then classColor= "FF7D0A" 
	elseif class=="Hunter" then classColor= "ABD473"
	elseif class=="Mage" then classColor= "69CCF0"
	elseif class=="Paladin" then classColor= "F58CBA"
	elseif class=="Priest" then classColor= "FFFFFF"
	elseif class=="Rogue" then classColor= "FFF569"
	elseif class=="Shaman" then classColor= "0070DE"
	elseif class=="Warlock" then classColor= "9482C9"
	elseif class=="Warrior" then classColor= "C79C6E"
	elseif class=="Death Knight" then classColor= "C41E3A"
	elseif class=="Demon Hunter" then classColor= "A330C9"
	end
	-- print("messageCheckDuplicate:"..messageCheckDuplicate)
	-------------------------
	
	if enabled and player~= myName then
	-- if enabled then	--ONLY FOR TESTING
	
		if (whitelistedStringTablePlayersChat ~= nil) then
			for _, z in ipairs(whitelistedStringTablePlayersChat) do --if player is found in blacklist > return
				if player:lower() == z:lower() then 
					return 
				end
			end
		end
		
		for id, v in ipairs(whitelistedStringTable) do
			local checkFound = true
			for w in string.gmatch(v:lower(), "([^\|]+)") do
				if (string.sub(w, 1, 1)~= "-" and not message:lower():find(w:lower())) or (string.sub(w, 1, 1)== "-" and message:lower():find(string.sub(w:lower(), 2))) then 
				-- if keyword doesn't start with - and keyword not found in msg		OR 		keyword starts with - and keyword found in msg THEN ignore this msg
					checkFound= false
				end
			end
			
			if checkFound then
				if messageCheckDuplicate == message then --if same as previous message return
					-- print("msg ".. message)
					-- print("duplicate "..messageCheckDuplicate)
					return
				else
					-- print("setting new msg ".. message)
					messageCheckDuplicate = message
				end
				
				
				-- if event == "CHAT_MSG_GUILD" then
					-- playerLink = string.format("|Hplayer:%s|h[%s]|h", sender, player)
					-- coloredPlayerLink = string.format("|cff%s%s|r", classColor, playerLink)
					-- msg = string.format("|cAAFF0000FOUND %d (|r|cff92ff58%s|r|cffFF0000):\n|cff5892ff[Guild]|r |r%s|cff5892ff: %s|r", id, v:upper():sub(1, 60), coloredPlayerLink, message)
					
				-- elseif event == "CHAT_MSG_SAY" then
					-- playerLink = string.format("|Hplayer:%s|h[%s]|h", sender, player)
					-- coloredPlayerLink = string.format("|cff%s%s|r", classColor, playerLink)
					-- msg = string.format("|cAAFF0000FOUND %d (|r|cff92ff58%s|r|cffFF0000):\n|cff5892ff[Say]|r |r%s|cff5892ff: %s|r", id, v:upper():sub(1, 60), coloredPlayerLink, message)
					
				-- elseif event == "CHAT_MSG_YELL" then
					-- playerLink = string.format("|Hplayer:%s|h[%s]|h", sender, player)
					-- coloredPlayerLink = string.format("|cff%s%s|r", classColor, playerLink)
					-- msg = string.format("|cAAFF0000FOUND %d (|r|cff92ff58%s|r|cffFF0000):\n|cff5892ff[Yell]|r |r%s|cff5892ff: %s|r", id, v:upper():sub(1, 60), coloredPlayerLink, message)
					
				-- else
					-- playerLink= "|Hplayer:"..sender.."|h"..chanName.."|h" --GetPlayerLink(characterName,linkDisplayText)
					-- playerLink=  "|cff"..classColor.."["..playerLink.."]|r"-- Adding class color
					-- msg= "|cAAFF0000FOUND "..id.." (|r|cff92ff58"..v:upper():sub(1, 60).."|r|cffFF0000): |r|cff5892ff\n["..chanNumber.."]|r "..playerLink.."|cff5892ff: "..message.."|r"
				-- end
				
				if event == "CHAT_MSG_GUILD" or event == "CHAT_MSG_SAY" or event == "CHAT_MSG_YELL" then
					playerLink = string.format("|Hplayer:%s|h[%s]|h", sender, player)
					coloredPlayerLink = string.format("|cff%s%s|r", classColor, playerLink)
					
					local chatType = {
						CHAT_MSG_GUILD = "Guild",
						CHAT_MSG_SAY = "Say",
						CHAT_MSG_YELL = "Yell"
					}
					
					msg = string.format("|cAAFF0000FOUND %d (|r|cff92ff58%s|r|cffFF0000):\n|cff5892ff[%s]|r |r%s|cff5892ff: %s|r", 
						id, v:upper():sub(1, 60), chatType[event], coloredPlayerLink, message)
				else
					playerLink = "|Hplayer:" .. sender .. "|h" .. chanName .. "|h"
					playerLink = "|cff" .. classColor .. "[" .. playerLink .. "]|r"
					msg = "|cAAFF0000FOUND " .. id .. " (|r|cff92ff58" .. v:upper():sub(1, 60) .. "|r|cffFF0000): |r|cff5892ff\n[" .. chanNumber .. "]|r " .. playerLink .. "|cff5892ff: " .. message .. "|r"
				end		
				
				-- RaidNotice_AddMessage(RaidWarningFrame,msg, ChatTypeInfo["RAID_WARNING"])
				DEFAULT_CHAT_FRAME:AddMessage(msg);
				-- SELECTED_CHAT_FRAME:AddMessage(msg);
				-- ChatFrame8:AddMessage(msg);
				
				---- PlaySoundFile("Sound\\Interface\\RaidWarning.ogg")
				
				if not mute then
					if master then
						PlaySound(4041,"Master")--cat
					else
						PlaySound(4041)--cat
					end
				end
				
				if flash then
					FlashClientIcon()
				end
				---- PlaySound(1044)--centaur
				return--SHOW ONLY IF 1st is FOUND TO AVOID SPAM NOTIFICATIONS
			end
		end
	end
end)