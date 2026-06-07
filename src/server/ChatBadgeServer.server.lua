-- ====================================
-- CHAT BADGE SERVER (OPTIMIZED)
-- Script (ServerScriptService)
-- ====================================

local Players       = game:GetService("Players")
local Teams         = game:GetService("Teams")
local ServerStorage = game:GetService("ServerStorage")

local RoleSystem = require(ServerStorage:WaitForChild("Modules"):WaitForChild("RoleSystem"))

-- ====================================
-- CONFIGURATION
-- ====================================
local CONFIG = {
	BADGES = {
		Owner     = { text = "Owner",      color = Color3.fromRGB(255, 0,   0),    priority = 7 },
		Admin     = { text = "Head Staff", color = Color3.fromRGB(255, 85,  0),    priority = 6 },
		Moderator = { text = "Staff",      color = Color3.fromRGB(0,   170, 255),  priority = 5 },
		Sultan    = { text = "Sultan",     color = Color3.fromRGB(255, 215, 0),    priority = 4 }, -- [TAMBAH INI]
		VVIP      = { text = "VVIP",       color = Color3.fromRGB(150, 0,   200),  priority = 3 },
		VIP       = { text = "VIP",        color = Color3.fromRGB(0,   255, 0),    priority = 2 },
		Player    = { text = nil,          color = nil,                            priority = 1 },
	},
	DEBUG = false,
}

-- ====================================
-- INTERNAL
-- ====================================
local function debugLog(message)
	if CONFIG.DEBUG then print("[ChatBadge Debug]", message) end
end

local refreshBadge 

local refreshDebounce = {}
local DEBOUNCE_WAIT   = 0.3

local function refreshBadgeDebounced(player)
	local userId = player.UserId
	if refreshDebounce[userId] then return end

	refreshDebounce[userId] = true
	task.delay(DEBOUNCE_WAIT, function()
		refreshDebounce[userId] = nil
		if player and player.Parent then
			refreshBadge(player)
		end
	end)
end

refreshBadge = function(player)
	if not player or not player.Parent then return end

	local badgeText, badgeColor, badgePriority

	local team = player.Team
	if team then
		local teamName = team.Name

		local attrR = team:GetAttribute("ExactColorR")
		local attrG = team:GetAttribute("ExactColorG")
		local attrB = team:GetAttribute("ExactColorB")

		local teamColor
		if attrR and attrG and attrB then
			teamColor = Color3.fromRGB(attrR, attrG, attrB)
		else
			teamColor = team.TeamColor and team.TeamColor.Color or Color3.fromRGB(200, 200, 200)
		end

		if teamName == "Tamu" then
			badgeText  = nil
			badgeColor = nil
		else
			badgeText  = teamName
			badgeColor = teamColor
		end

		local role    = RoleSystem:GetPlayerRole(player)
		local roleCfg = CONFIG.BADGES[role] or CONFIG.BADGES.Player
		badgePriority = roleCfg.priority

		debugLog(string.format("Team badge: %s → [%s] | Role: %s", player.Name, tostring(badgeText), role))
	else
		local role    = RoleSystem:GetPlayerRole(player)
		local cfg     = CONFIG.BADGES[role] or CONFIG.BADGES.Player
		badgeText     = cfg.text
		badgeColor    = cfg.color
		badgePriority = cfg.priority

		debugLog(string.format("Role badge: %s → [%s] (no team)", player.Name, tostring(badgeText)))
	end

	-- Set Attributes
	player:SetAttribute("BadgeText",     badgeText)
	player:SetAttribute("BadgeColor",    badgeColor)
	player:SetAttribute("BadgePriority", badgePriority)
	player:SetAttribute("PlayerRole",    RoleSystem:GetPlayerRole(player))
end

-- ====================================
-- PLAYER ADDED
-- ====================================
Players.PlayerAdded:Connect(function(player)
	debugLog(string.format("Player joined: %s", player.Name))

	-- Beri badge saat masuk
	refreshBadge(player)

	-- EVENT-DRIVEN: Hanya update badge saat TEAM BERUBAH
	player:GetPropertyChangedSignal("Team"):Connect(function()
		debugLog(string.format("Team changed: %s → %s", player.Name, player.Team and player.Team.Name or "nil"))
		refreshBadgeDebounced(player)
	end)

	-- EVENT-DRIVEN: Refresh saat karakter hidup/respawn
	player.CharacterAdded:Connect(function()
		task.wait(0.5)
		refreshBadge(player)
	end)

	-- LOOP 2 DETIK DIHAPUS KARENA SUDAH TIDAK PERLU!
end)

-- ====================================
-- PLAYER REMOVING
-- ====================================
Players.PlayerRemoving:Connect(function(player)
	refreshDebounce[player.UserId] = nil
	-- Tidak perlu repot-repot menghapus Attribute, karena player-nya toh akan hancur dari game.
end)

-- ====================================
-- ROLE CHANGED
-- ====================================
RoleSystem.RoleChanged:Connect(function(player, oldRole, newRole)
	debugLog(string.format("Role changed: %s → %s → %s", player.Name, oldRole, newRole))
	-- EVENT-DRIVEN: Hanya update badge saat ROLE BERUBAH
	refreshBadgeDebounced(player)
end)

-- ====================================
-- GLOBAL HELPERS
-- ====================================
_G.ChatBadgeSystem = {
	RefreshPlayer = function(player)
		if player and player.Parent then
			refreshBadge(player)
			return true
		end
		return false
	end,
	RefreshAll = function()
		for _, p in ipairs(Players:GetPlayers()) do
			refreshBadge(p)
		end
		debugLog("Refreshed all players")
	end,
}