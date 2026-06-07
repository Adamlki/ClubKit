local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local RoleSystem = require(ServerStorage.Modules.RoleSystem)

local MusicPlayerManager = {}
MusicPlayerManager.__index = MusicPlayerManager

function MusicPlayerManager.new(config, managers, dispatcher)
	local self = setmetatable({}, MusicPlayerManager)

	self.config = config
	self.queueManager = managers.queueManager
	self.skipVoteManager = managers.skipVoteManager
	self.favoriteManager = managers.favoriteManager
	self.playbackManager = managers.playbackManager
	self.dispatcher = dispatcher
	self.systemState = managers.systemState
	self.cooldownService = managers.cooldownService

	return self
end

-- ====================================
-- PLAYER VALIDATION (SIMPLE)
-- ====================================
local function validatePlayer(player)
	return player and player:IsDescendantOf(Players)
end

-- ====================================
-- PLAYER ADDED
-- ====================================
function MusicPlayerManager:OnPlayerAdded(player)
	RoleSystem:InitializePlayer(player)

	-- Load player favorites
	task.spawn(function()
		self.favoriteManager:LoadPlayerFavorites(player.UserId)
	end)

	task.wait(1)
	if validatePlayer(player) then
		self.dispatcher:SyncToPlayer(player)

		if not self.systemState.InitialPreloadComplete then
			self.dispatcher:Notify(player, "Music system is loading, please wait...")
		else
			self.dispatcher:Notify(player, "Welcome! Music playing from server.")
		end
	end

	-- Character respawn handler
	player.CharacterAdded:Connect(function(character)
		local hrp = character:WaitForChild("HumanoidRootPart", 5)
		if not hrp then return end

		task.wait(0.5)

		if validatePlayer(player) then
			self.dispatcher:SyncToPlayer(player)
		end
	end)

	-- Admin commands
	self:SetupAdminCommands(player)
end

-- ====================================
-- PLAYER REMOVING
-- ====================================
function MusicPlayerManager:OnPlayerRemoving(player)
	local userId = player.UserId

	self.queueManager:RemoveUserSongs(userId)
	self.skipVoteManager:UpdateVoteOnPlayerLeave(userId, self.dispatcher)
	self.favoriteManager:CleanupPlayer(userId)
	self.cooldownService:CleanupPlayer(userId)

	self.dispatcher:SyncQueueOnly()
end

-- ====================================
-- ADMIN COMMANDS
-- ====================================
function MusicPlayerManager:SetupAdminCommands(player)
	player.Chatted:Connect(function(message)
		local role = RoleSystem:GetPlayerRole(player)

		if role == "Admin" or role == "Owner" or role == "Moderator" then
			local lowerMsg = string.lower(message)

			-- Retry Player (UI sync only)
			if lowerMsg:match("^/retryplayer%s+") or lowerMsg:match("^;retryplayer%s+") then
				local targetName = lowerMsg:match("^/retryplayer%s+(.+)") or lowerMsg:match("^;retryplayer%s+(.+)")
				self:HandleRetryPlayer(player, targetName)
			end

			-- Retry All (UI sync only)
			if lowerMsg == "/retryall" or lowerMsg == ";retryall" then
				self:HandleRetryAll(player)
			end
		end
	end)
end

-- ====================================
-- RETRY PLAYER (UI SYNC ONLY - NO AUDIO RELOAD)
-- ====================================
function MusicPlayerManager:HandleRetryPlayer(player, targetName)
	local targetPlayer = self:FindPlayerByName(targetName)

	if not targetPlayer then
		self.dispatcher:Notify(player, "Player not found! Use DisplayName or first 3+ letters (e.g. /retryplayer Eld)")
		return
	end

	self.dispatcher:Notify(player, string.format("Syncing UI for %s...", targetPlayer.DisplayName))

	-- Simply sync UI state to target player
	self.dispatcher:SyncToPlayer(targetPlayer)

	task.delay(0.5, function()
		self.dispatcher:Notify(player, string.format("%s's UI has been synced!", targetPlayer.DisplayName))
		self.dispatcher:Notify(targetPlayer, string.format("Admin %s synced your music UI", player.DisplayName))
	end)
end

-- ====================================
-- RETRY ALL (UI SYNC ONLY - NO AUDIO RELOAD)
-- ====================================
function MusicPlayerManager:HandleRetryAll(player)
	local playerCount = #Players:GetPlayers()

	self.dispatcher:Notify(player, string.format("Syncing UI for %d players...", playerCount))

	-- Sync state to all players
	self.dispatcher:SyncState()

	task.delay(0.5, function()
		self.dispatcher:NotifyAll(string.format("Admin %s synced music UI for all players!", player.DisplayName))
		self.dispatcher:Notify(player, "UI synced successfully!")
	end)
end

-- ====================================
-- UTILITY: FIND PLAYER BY NAME
-- ====================================
function MusicPlayerManager:FindPlayerByName(targetName)
	local targetPlayer = nil
	local matches = {}
	local lowerTarget = targetName:lower()

	for _, plr in ipairs(Players:GetPlayers()) do
		local lowerDisplay = plr.DisplayName:lower()

		if lowerDisplay == lowerTarget then
			targetPlayer = plr
			break
		end

		if #lowerTarget >= 3 and lowerDisplay:sub(1, #lowerTarget) == lowerTarget then
			table.insert(matches, plr)
		end
	end

	if not targetPlayer then
		if #matches == 1 then
			targetPlayer = matches[1]
		elseif #matches > 1 then
			return nil
		end
	end

	return targetPlayer
end

return MusicPlayerManager