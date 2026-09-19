local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")

-- Managers
local MusicQueueManager = require(script.Parent.MusicQueueManager)
local MusicPlaybackManager = require(script.Parent.MusicPlaybackManager)
local MusicPlaylistManager = require(script.Parent.MusicPlaylistManager)
local MusicSkipVoteManager = require(script.Parent.MusicSkipVoteManager)
local MusicFavoriteManager = require(script.Parent.MusicFavoriteManager)
local MusicCooldownService = require(script.Parent.MusicCooldownService)
local MusicActionHandler = require(script.Parent.MusicActionHandler)
local MusicDispatcher = require(script.Parent.MusicDispatcher)
local MusicPlayerManager = require(script.Parent.MusicPlayerManager)

local RoleSystem = require(ServerStorage.Modules.RoleSystem)
local MusicModule = require(ReplicatedStorage.Modules:WaitForChild("MusicModule"))

local MusicSystem = {}
MusicSystem.__index = MusicSystem

-- ====================================
-- CONFIGURATION (SIMPLIFIED - NO DJ)
-- ====================================
local CONFIG = {
	-- Queue
	MAX_QUEUE_SIZE = 50,
	MAX_QUEUE_PER_USER = 10, -- Fallback default

	-- Queue Limits (per role)
	MAX_QUEUE_PER_ROLE = {
		Owner = 999,      -- No limit
		Admin = 999,      -- No limit
		Moderator = 999,  -- No limit
		VIP = 2,          -- 2 songs max
		Player = 0        -- Cannot add songs
	},

	-- Playback
	DEFAULT_SONG_DURATION = 180,

	-- Cooldowns (per role, in seconds)
	COOLDOWNS = {
		Owner = 0,
		Admin = 0,
		Moderator = 0,
		VIP = 120,
		Player = 30
	},

	-- Skip Vote
	SKIP_VOTE_DURATION = 30,
	SKIP_VOTE_COOLDOWN = 60,
}

-- ====================================
-- INITIALIZATION
-- ====================================
function MusicSystem.new()
	local self = setmetatable({}, MusicSystem)

	-- System state
	self.systemState = {
		InitialPreloadComplete = false,
		IsUIBlocked = false
	}
	self.isTransitioning = false

	-- Initialize managers
	self.queueManager = MusicQueueManager.new(CONFIG)
	self.playbackManager = MusicPlaybackManager.new(CONFIG)
	self.playlistManager = MusicPlaylistManager.new(CONFIG)
	self.skipVoteManager = MusicSkipVoteManager.new(CONFIG, RoleSystem)
	self.favoriteManager = MusicFavoriteManager.new()
	self.cooldownService = MusicCooldownService.new(CONFIG)

	-- Setup remotes
	self.remotes = self:SetupRemotes()

	-- Initialize dispatcher
	self.dispatcher = MusicDispatcher.new(self.remotes, CONFIG, {
		queueManager = self.queueManager,
		playbackManager = self.playbackManager,
		favoriteManager = self.favoriteManager,
		systemState = self.systemState,
		playlistManager = self.playlistManager
	})

	-- Initialize action handler
	self.actionHandler = MusicActionHandler.new(CONFIG, {
		queueManager = self.queueManager,
		playbackManager = self.playbackManager,
		cooldownService = self.cooldownService,
		skipVoteManager = self.skipVoteManager,
		favoriteManager = self.favoriteManager,
		dispatcher = self.dispatcher,
		systemState = self.systemState,
		playNextCallback = function() self:PlayNext() end,
		broadcastPreloadCallback = function() self:BroadcastPreloadNext() end
	}, self.dispatcher)

	-- Initialize player manager
	self.playerManager = MusicPlayerManager.new(CONFIG, {
		queueManager = self.queueManager,
		skipVoteManager = self.skipVoteManager,
		favoriteManager = self.favoriteManager,
		playbackManager = self.playbackManager,
		dispatcher = self.dispatcher,
		systemState = self.systemState,
		cooldownService = self.cooldownService
	}, self.dispatcher)

	-- Setup auto-next callback
	self.playbackManager.autoNextCallback = function()
		self:PlayNext()
	end

	-- Setup song failed callback (Anti-Stuck Notification)
	self.playbackManager.onSongFailed = function(songTitle, reason)
		pcall(function()
			self.dispatcher:NotifyAll(string.format("⚠️ Lagu '%s' tidak dapat diputar (Error/Banned). Melewati...", songTitle or "Unknown"))
		end)
	end

	return self
end

-- ====================================
-- SETUP REMOTES
-- ====================================
function MusicSystem:SetupRemotes()
	local remoteFolder = ReplicatedStorage:FindFirstChild("MusicRemotes")
	if not remoteFolder then
		remoteFolder = Instance.new("Folder")
		remoteFolder.Name = "MusicRemotes"
		remoteFolder.Parent = ReplicatedStorage
	end

	local function getOrCreateRemote(name, className)
		local remote = remoteFolder:FindFirstChild(name)
		if not remote then
			remote = Instance.new(className)
			remote.Name = name
			remote.Parent = remoteFolder
		end
		return remote
	end

	return {
		DispatchEvent = getOrCreateRemote("DispatchEvent", "RemoteEvent"),
		MusicAction = getOrCreateRemote("MusicAction", "RemoteEvent"),
		MusicBroadcast = getOrCreateRemote("MusicBroadcast", "RemoteEvent"),
		MusicUpdate = getOrCreateRemote("MusicUpdate", "RemoteEvent"),
	}
end

-- ====================================
-- PLAY NEXT SONG
-- ====================================
function MusicSystem:PlayNext()
	-- 🛡️ ANTI-DEADLOCK: Cek apakah lock transisi macet lebih dari 5 detik
	if self.isTransitioning then 
		if self._transitionStartTime and (os.clock() - self._transitionStartTime) > 5 then
			warn("[MusicSystem] ⚠️ Transition lock timeout (>5s). Me-reset paksa isTransitioning...")
			self.isTransitioning = false
		else
			-- Jadwalkan retry 1 detik lagi jika sistem sedang transisi agar panggilan auto-next tidak hilang
			task.delay(1, function()
				if not self.playbackManager:IsPlaying() and not self.isTransitioning then
					self:PlayNext()
				end
			end)
			return
		end
	end

	self.isTransitioning = true
	self._transitionStartTime = os.clock()

	local success, err = pcall(function()
		-- Check if there's a song in queue
		local nextSong = self.queueManager:GetNext()

		if nextSong then
			-- Play from queue
			local playSuccess, playErr = self.playbackManager:Play(
				self.remotes,
				nextSong,
				nextSong.uploader,
				false -- Not from playlist
			)

			if not playSuccess then
				warn("[MusicSystem] Failed to play queued song:", playErr)
				-- Try next song
				task.delay(1, function()
					self.isTransitioning = false
					self:PlayNext()
				end)
				return
			end

			-- Sync queue to all players
			self.dispatcher:SyncState()
			self.isTransitioning = false
			
			-- 🔥 BROADCAST PRELOAD UNTUK LAGU BERIKUTNYA
			self:BroadcastPreloadNext()

		else
			-- Queue is empty, play from auto-playlist
			local playlistSong = self.playlistManager:GetNextSong()

			if playlistSong then
				local playSuccess, playErr = self.playbackManager:Play(
					self.remotes,
					playlistSong,
					"Auto-Playlist",
					true -- From playlist
				)

				if not playSuccess then
					warn("[MusicSystem] Failed to play playlist song:", playErr)
					-- Try next song
					task.delay(1, function()
						self.isTransitioning = false
						self:PlayNext()
					end)
				else
					self.dispatcher:SyncState()
					self.isTransitioning = false
					
					-- 🔥 BROADCAST PRELOAD UNTUK LAGU BERIKUTNYA
					self:BroadcastPreloadNext()
				end
			else
				warn("[MusicSystem] No songs available in queue or playlist! Resetting playlist index...")
				self.playlistManager:ResetPlaylist()
				local retrySong = self.playlistManager:GetNextSong()
				if retrySong then
					local playSuccess, playErr = self.playbackManager:Play(
						self.remotes,
						retrySong,
						"Auto-Playlist",
						true
					)
					if playSuccess then
						self.dispatcher:SyncState()
					end
				else
					self.playbackManager:Stop(self.remotes)
				end
				self.isTransitioning = false
			end
		end
	end)

	if not success then
		warn("[MusicSystem] Error during PlayNext:", err)
		self.isTransitioning = false
	end
end

-- ====================================
-- BROADCAST PRELOAD NEXT SONG (SMART BACKGROUND BUFFER)
-- ====================================
function MusicSystem:BroadcastPreloadNext()
	local nextSongId = nil
	local nextSongTitle = nil

	-- 1. Cek antrean (Queue) terlebih dahulu
	local queue = self.queueManager:GetQueue()
	if queue and #queue > 0 and queue[1] then
		local queuedItem = queue[1]
		local musicData = queuedItem.musicData or queuedItem
		nextSongId = musicData.id
		nextSongTitle = musicData.judul
	else
		-- 2. Jika antrean kosong, intip lagu berikutnya dari auto-playlist
		local playlistSong = self.playlistManager:PeekNextSong()
		if playlistSong then
			nextSongId = playlistSong.id
			nextSongTitle = playlistSong.judul
		end
	end

	if nextSongId and tostring(nextSongId) ~= "" then
		local soundIdStr = tostring(nextSongId)
		self.dispatcher:SendToAll("PRELOAD_SONG", {
			soundId = soundIdStr,
			title = nextSongTitle or "Upcoming Track"
		})
	end
end

-- ====================================
-- START SYSTEM
-- ====================================
function MusicSystem:Start()
	-- Connect player events
	Players.PlayerAdded:Connect(function(player)
		self.playerManager:OnPlayerAdded(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		self.playerManager:OnPlayerRemoving(player)
	end)

	-- 🔥 FIX: BindToClose untuk mencegah Data Loss saat Server Shutdown/Restart
	game:BindToClose(function()
		print("[MusicSystem] Server shutting down, backing up all favorite data...")
		for _, player in ipairs(Players:GetPlayers()) do
			self.playerManager:OnPlayerRemoving(player)
		end
		task.wait(3) -- Beri waktu 3 detik agar proses save async (Datastore) selesai sebelum mati
	end)

	-- Handle existing players
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(function()
			self.playerManager:OnPlayerAdded(player)
		end)
	end

	local ServerScriptService = game:GetService("ServerScriptService")
	local RemoteEventManager = require(ServerScriptService:WaitForChild("Modules"):WaitForChild("RemoteEventManager"))

	self.remotes.MusicAction.OnServerEvent:Connect(function(player, action)
		if action.type == "REQUEST_SYNC" then
			if not RemoteEventManager.checkRateLimit(player, "musicSync") then return end
			self.playerManager:OnPlayerAdded(player)
		else
			if not RemoteEventManager.checkRateLimit(player, "musicAction") then return end
			self.actionHandler:DispatchAction(player, action)
		end
	end)

	-- Mark as ready
	task.delay(2, function()
		self.systemState.InitialPreloadComplete = true
		self:PlayNext()
	end)
end

return MusicSystem