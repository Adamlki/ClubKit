-- ===== CHAT BADGE CLIENT =====
-- ChatBadgeClient.lua
-- LocalScript (StarterPlayer > StarterPlayerScripts)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local Player = Players.LocalPlayer

-- ============================================
-- REFRESH COMMAND SUPPORT
-- ============================================
local refreshEvent = nil

local function initRefreshEvent()
	local remotefolder = ReplicatedStorage:WaitForChild("Remotes") -- Gunakan WaitForChild agar aman
	if remotefolder then
		refreshEvent = remotefolder:FindFirstChild("RefreshCharacterEvent")
	end
end

local function requestRefresh()
	if refreshEvent then
		refreshEvent:FireServer()
	end
end

-- ============================================
-- UTILITY FUNCTIONS
-- ============================================
local function colorToHex(color)
	if not color then return "FFFFFF" end
	local r = math.floor(color.R * 255)
	local g = math.floor(color.G * 255)
	local b = math.floor(color.B * 255)
	return string.format("%02X%02X%02X", r, g, b)
end

-- ============================================
-- MAIN CHAT MESSAGE HANDLER
-- ============================================
if TextChatService then
	initRefreshEvent()

	TextChatService.OnIncomingMessage = function(message: TextChatMessage)
		local properties = Instance.new("TextChatMessageProperties")
		local source = message.TextSource

		if not source then return properties end

		local player = Players:GetPlayerByUserId(source.UserId)
		if not player then return properties end

		-- ============================================
		-- COMMAND DETECTION (Hanya /re dan /refresh)
		-- ============================================
		if source.UserId == Player.UserId then
			local messageText = string.lower(message.Text)

			-- Menghapus ;re agar tidak terjadi double trigger/kepental
			if messageText == "/re" or messageText == "/refresh" then
				requestRefresh()
			end
		end

		-- ============================================
		-- BADGE DISPLAY
		-- ============================================
		local badgeText = player:GetAttribute("BadgeText")
		local badgeColor = player:GetAttribute("BadgeColor")

		if badgeText and badgeColor then
			local hex = colorToHex(badgeColor)
			properties.PrefixText = string.format(
				"<font color='#%s'><b>[%s]</b></font> %s: ",
				hex,
				badgeText,
				player.DisplayName
			)
		else
			properties.PrefixText = string.format("%s: ", player.DisplayName)
		end

		return properties
	end
end