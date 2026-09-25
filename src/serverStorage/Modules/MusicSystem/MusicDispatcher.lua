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
	self.playlistManager = managers.playlistManager

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
	self:SendToAll("QUEUE_UPDATE", {
		queue = self.queueManager:GetQueue(),
		totalCount = self.queueManager:GetSize()
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

	if self.systemState.IsUIBlocked then
		if roleHierarchy < roleSystem.Config.RoleHierarchy.Moderator then
			self:SendToClient(player, "ADMIN_BLOCK_ACTIVATED", {})
		else
			-- 💡 FIX: Beritahu Admin baru bahwa sistem sedang terblokir!
			self:SendToClient(player, "ADMIN_BUTTON_UPDATE", {text = "Unblock"})
		end
	end

	-- 🚀 SMART BACKGROUND BUFFER: Beritahu client lagu berikutnya untuk di-preload
	task.defer(function()
		if not validatePlayer(player) then return end
		local nextSongId = nil
		local queue = self.queueManager:GetQueue()
		if queue and #queue > 0 and queue[1] then
			local queued = queue[1]
			local mData = queued.musicData or queued
			nextSongId = mData.id
		elseif self.playlistManager then
			local playlistSong = self.playlistManager:PeekNextSong()
			if playlistSong then
				nextSongId = playlistSong.id
			end
		end

		if nextSongId and tostring(nextSongId) ~= "" then
			self:SendToClient(player, "PRELOAD_SONG", {
				soundId = tostring(nextSongId)
			})
		end
	end)
end

return MusicDispatcher
