local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

-- OPTIMIZED: Cache RoleSystem reference
local RoleSystem = nil
local function getRoleSystem()
	if not RoleSystem then
		RoleSystem = require(ServerStorage.Modules.RoleSystem)
	end
	return RoleSystem
end

local MusicDispatcher = {}
MusicDispatcher.__index = MusicDispatcher

function MusicDispatcher.new(remotes, config, managers)
	local self = setmetatable({}, MusicDispatcher)

	self.remotes = remotes
	self.config = config
	self.queueManager = managers.queueManager
	self.playbackManager = managers.playbackManager
	self.favoriteManager = managers.favoriteManager
	self.systemState = managers.systemState

	return self
end

-- ====================================
-- PLAYER VALIDATION (SIMPLE)
-- ====================================
local function validatePlayer(player)
	return player and player:IsDescendantOf(Players)
end

-- ====================================
-- BASIC COMMUNICATION
-- ====================================
function MusicDispatcher:SendToClient(player, eventType, payload)
	if not validatePlayer(player) then
		return
	end

	pcall(function()
		self.remotes.DispatchEvent:FireClient(player, {
			type = eventType,
			payload = payload
		})
	end)
end

function MusicDispatcher:SendToAll(eventType, payload)
	pcall(function()
		self.remotes.DispatchEvent:FireAllClients({
			type = eventType,
			payload = payload
		})
	end)
end

function MusicDispatcher:Notify(player, message)
	self:SendToClient(player, "NOTIFY", {message = message})
end

function MusicDispatcher:NotifyAll(message)
	self:SendToAll("NOTIFY", {message = message})
end

-- ====================================
-- QUEUE SYNC (DIRECT - NO BATCHING)
-- ====================================
function MusicDispatcher:SyncQueueOnly()
	local fullQueue = self.queueManager:GetQueue()
	local limitedQueue = {}

	-- Only send first 10 items to reduce network traffic
	for i = 1, math.min(10, #fullQueue) do
		table.insert(limitedQueue, fullQueue[i])
	end

	self:SendToAll("QUEUE_UPDATE", {
		queue = limitedQueue,
		totalCount = #fullQueue
	})
end

-- ====================================
-- STATE SYNC (DIRECT - NO BATCHING)
-- ====================================
function MusicDispatcher:SyncState()
	local playbackState = self.playbackManager:GetState()

	self:SendToAll("SYNC_STATE", {
		queue = self.queueManager:GetQueue(),
		currentSong = playbackState.currentSong,
		currentUploader = playbackState.currentUploader,
		isPlaying = playbackState.isPlaying,
		isPaused = playbackState.isPaused,
		startTime = playbackState.startTime,
		duration = playbackState.duration,
		isBlocked = self.systemState.IsUIBlocked
	})
end

-- ====================================
-- SYNC TO INDIVIDUAL PLAYER
-- ====================================
function MusicDispatcher:SyncToPlayer(player)
	if not validatePlayer(player) then
		return
	end

	local playbackState = self.playbackManager:GetState()
	local favorites = self.favoriteManager:GetPlayerFavorites(player.UserId)

	self:SendToClient(player, "SYNC_STATE", {
		queue = self.queueManager:GetQueue(),
		currentSong = playbackState.currentSong,
		currentUploader = playbackState.currentUploader,
		isPlaying = playbackState.isPlaying,
		isPaused = playbackState.isPaused,
		startTime = playbackState.startTime,
		duration = playbackState.duration,
		isBlocked = self.systemState.IsUIBlocked,
		favoriteSongs = favorites
	})

	-- Sync playback if music is playing
	if playbackState.isPlaying and playbackState.currentSong then
		pcall(function()
			self.playbackManager:SyncToPlayer(self.remotes, player)
		end)
	end

	-- Check if player is blocked (OPTIMIZED: single require)
	local roleSystem = getRoleSystem()
	local role = roleSystem:GetPlayerRole(player)
	local roleHierarchy = roleSystem.Config.RoleHierarchy[role] or 0

	if self.systemState.IsUIBlocked and roleHierarchy < 4 then
		self:SendToClient(player, "ADMIN_BLOCK_ACTIVATED", {})
	end
end

return MusicDispatcher
