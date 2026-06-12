local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local MarketplaceService = game:GetService("MarketplaceService")

local RoleSystem = require(ServerStorage.Modules.RoleSystem)
local MusicModule = require(ReplicatedStorage.Modules:WaitForChild("MusicModule"))

local MusicActionHandler = {}
MusicActionHandler.__index = MusicActionHandler

-- ====================================
-- OPTIMIZED: SONG TITLE CACHE
-- Cache hasil dari MarketplaceService untuk menghindari HTTP call berulang
-- ====================================
local SONG_TITLE_CACHE = {}
local CACHE_DURATION = 3600 -- 1 jam cache

local function getCachedSongTitle(musicId)
	local cached = SONG_TITLE_CACHE[musicId]
	if cached and (tick() - cached.timestamp) < CACHE_DURATION then
		return cached.title
	end
	return nil
end

local function setCachedSongTitle(musicId, title)
	SONG_TITLE_CACHE[musicId] = {
		title = title,
		timestamp = tick()
	}
end

function MusicActionHandler.new(config, managers, dispatcher)
	local self = setmetatable({}, MusicActionHandler)

	self.config = config
	self.queueManager = managers.queueManager
	self.playbackManager = managers.playbackManager
	self.cooldownService = managers.cooldownService
	self.skipVoteManager = managers.skipVoteManager
	self.favoriteManager = managers.favoriteManager
	self.dispatcher = dispatcher
	self.systemState = managers.systemState
	self.playNextCallback = managers.playNextCallback

	return self
end

-- ====================================
-- PLAYER VALIDATION (SIMPLE)
-- ====================================
local function validatePlayer(player)
	return player and player:IsDescendantOf(game:GetService("Players"))
end

-- ====================================
-- ✅ FIXED: CHECK IF PLAYER IS BLOCKED (WITH DEBUG)
-- ====================================
function MusicActionHandler:IsPlayerBlocked(player)
	if not self.systemState.IsUIBlocked then
		return false -- System not blocked
	end

	local role = RoleSystem:GetPlayerRole(player)
	local roleHierarchy = RoleSystem.Config.RoleHierarchy[role] or 0

	-- ✅ DEBUG: Print untuk debugging
	print(string.format("[Block Check] Player: %s | Role: %s | Hierarchy: %d | IsUIBlocked: %s", 
		player.DisplayName, role, roleHierarchy, tostring(self.systemState.IsUIBlocked)))

	-- Moderator+ (hierarchy >= 4) are never blocked
	if roleHierarchy >= 4 then
		print(string.format("[Block Check] %s is Moderator+ - NOT BLOCKED", player.DisplayName))
		return false
	end

	-- Non-moderators are blocked
	print(string.format("[Block Check] %s is blocked (hierarchy %d < 4)", player.DisplayName, roleHierarchy))
	return true
end

-- ====================================
-- OPTIMIZED: AUTO DETECT SONG TITLE WITH CACHE
-- ====================================
local function detectSongTitle(musicId)
	-- Check cache first (instant return)
	local cachedTitle = getCachedSongTitle(musicId)
	if cachedTitle then
		return cachedTitle
	end

	-- Not in cache, fetch from MarketplaceService
	local success, info = pcall(function()
		return MarketplaceService:GetProductInfo(tonumber(musicId))
	end)

	if success and info and info.Name then
		-- Cache the result
		setCachedSongTitle(musicId, info.Name)
		return info.Name
	end

	-- Cache the fallback result too
	setCachedSongTitle(musicId, "Custom Music")
	return "Custom Music"
end

-- ====================================
-- ADD TO QUEUE (✅ FIXED WITH BLOCK CHECK)
-- ====================================
function MusicActionHandler:HandleAddToQueue(player, data)
	if not validatePlayer(player) then return end

	-- ✅ CHECK ADMIN BLOCK FIRST
	if self:IsPlayerBlocked(player) then
		self.dispatcher:Notify(player, "🔒 Music access is currently blocked by Admin!")
		return
	end

	local musicId = data.musicId
	local isFromPlaylist = data.isFromPlaylist

	if type(musicId) ~= "string" or type(isFromPlaylist) ~= "boolean" then
		return
	end

	-- Check role permission
	local role = RoleSystem:GetPlayerRole(player)
	if RoleSystem.Config.RoleHierarchy[role] < RoleSystem.Config.RoleHierarchy.VIP then
		self.dispatcher:Notify(player, "Minimum rank VIP required to add songs!")
		return
	end

	-- Check cooldown
	local canAdd, cooldownMsg = self.cooldownService:CheckCooldown(player, self.config.COOLDOWNS)
	if not canAdd then
		self.dispatcher:Notify(player, cooldownMsg)
		return
	end

	-- Check if system is ready
	if not self.systemState.InitialPreloadComplete then
		self.dispatcher:Notify(player, "System is preloading music library, please wait...")
		return
	end

	task.spawn(function()
		local musicData

		if isFromPlaylist then
			-- From playlist - get directly from module
			musicData = MusicModule:GetMusicById(musicId)
			if not musicData then
				self.dispatcher:Notify(player, "Song not found in playlist!")
				return
			end
		else
			-- Custom music ID - try module first, then accept as external
			local moduleMusic = MusicModule:GetMusicById(musicId)

			if moduleMusic then
				musicData = moduleMusic
				self.dispatcher:Notify(player, string.format("Found '%s' in library!", moduleMusic.judul))
			else
				-- External music ID - try to detect title (OPTIMIZED with cache)
				-- Use "Custom Music" as default first for instant response
				musicData = {
					id = musicId,
					judul = "Custom Music",
					sampul = "rbxassetid://88574818940840",
					Duration = self.config.DEFAULT_SONG_DURATION,
					PlaybackSpeed = 1.0
				}

				-- Notify immediately (non-blocking)
				self.dispatcher:Notify(player, "Adding custom music ID...")

				-- Try to detect title in background (will update queue display later)
				task.spawn(function()
					local detectedTitle = detectSongTitle(musicId)
					if detectedTitle ~= "Custom Music" then
						-- Update the musicData title
						musicData.judul = detectedTitle
						-- Notify player with detected title
						self.dispatcher:Notify(player, string.format("Detected: '%s'", detectedTitle))
						-- Sync queue to show updated title
						self.dispatcher:SyncQueueOnly()
					end
				end)
			end
		end

		-- Ensure Duration exists
		if not musicData.Duration or musicData.Duration <= 0 then
			musicData.Duration = self.config.DEFAULT_SONG_DURATION
		end

		-- Ensure PlaybackSpeed exists
		if not musicData.PlaybackSpeed then
			musicData.PlaybackSpeed = 1.0
		end

		-- Add to queue (NOW WITH ROLE PARAMETER)
		local success, errorMsg = self.queueManager:AddToQueue(musicData, player.DisplayName, player.UserId, role)

		if not success then
			self.dispatcher:Notify(player, errorMsg)
			return
		end

		-- Update cooldown
		self.cooldownService:UpdateCooldown(player)

		-- Sync to player immediately
		self.dispatcher:SyncToPlayer(player)

		-- Broadcast queue update to all
		self.dispatcher:SyncQueueOnly()

		local queuePosition = self.queueManager:GetSize()
		self.dispatcher:Notify(player, string.format("'%s' added to queue (Position: #%d)", musicData.judul, queuePosition))

		-- Auto-play if nothing is playing
		if not self.playbackManager:IsPlaying() then
			task.delay(0.5, self.playNextCallback)
		end
	end)
end

-- ====================================
-- CONTROL NEXT (SKIP) - ✅ FIXED WITH BLOCK CHECK (VIP/VVIP CAN SKIP)
-- ====================================
function MusicActionHandler:HandleControlNext(player, data)
	if not validatePlayer(player) then return end

	-- ✅ CHECK ADMIN BLOCK FIRST
	if self:IsPlayerBlocked(player) then
		self.dispatcher:Notify(player, "🔒 Music access is currently blocked by Admin!")
		return
	end

	local role = RoleSystem:GetPlayerRole(player)
	local roleHierarchy = RoleSystem.Config.RoleHierarchy[role] or 0

	-- Check minimum role
	if roleHierarchy < RoleSystem.Config.RoleHierarchy.VIP then
		self.dispatcher:Notify(player, "Minimum rank VIP required to skip!")
		return
	end

	-- Moderator+ can force skip
	if roleHierarchy >= 4 then
		local currentSong = self.playbackManager:GetCurrentSong()
		if currentSong then
			self.dispatcher:NotifyAll(string.format("%s (%s) skipped: %s", player.DisplayName, role, currentSong.judul or "Unknown"))
			self.playNextCallback()
		else
			self.dispatcher:Notify(player, "No song is currently playing!")
		end
		return
	end

	-- Regular skip vote for VIP/VVIP
	local currentSong = self.playbackManager:GetCurrentSong()
	if not currentSong then 
		self.dispatcher:Notify(player, "No song is currently playing!")
		return 
	end

	-- Cannot skip auto-playlist songs
	if self.playbackManager:IsFromPlaylist() then
		self.dispatcher:Notify(player, "Cannot skip auto-playlist songs! Wait for user-added songs.")
		return
	end

	-- ✅ FIX: Check rate limit to prevent vote spamming
	if not self.skipVoteManager:CheckRateLimit(player) then
		self.dispatcher:Notify(player, "Please wait before starting another vote!")
		return
	end

	-- Start skip vote
	local success, msg = self.skipVoteManager:StartVote(player, currentSong, self.dispatcher)
	if not success then
		self.dispatcher:Notify(player, msg)
	else
		self.dispatcher:NotifyAll(string.format("%s started a skip vote for: %s", player.DisplayName, currentSong.judul or "Unknown"))
	end
end

-- ====================================
-- SKIP VOTE YES (✅ ALLOWED DURING BLOCK)
-- ====================================
function MusicActionHandler:HandleSkipVoteYes(player, data)
	if not validatePlayer(player) then return end

	-- ✅ SKIP VOTES ARE ALLOWED DURING BLOCK (democratic decision)

	local success, passed = self.skipVoteManager:CastVote(player, "yes", self.dispatcher)

	if not success then
		self.dispatcher:Notify(player, "Unable to cast vote. No active vote or you already voted!")
		return
	end

	if passed then
		local currentSong = self.playbackManager:GetCurrentSong()
		self.dispatcher:NotifyAll(string.format("Skip vote passed! Skipping: %s", currentSong and currentSong.judul or "Unknown"))
		task.wait(1)
		self.playNextCallback()
		self.skipVoteManager:EndVote(self.dispatcher, true)
	else
		self.dispatcher:Notify(player, "Your vote has been counted!")
	end
end

-- ====================================
-- SKIP VOTE NO (✅ ALLOWED DURING BLOCK)
-- ====================================
function MusicActionHandler:HandleSkipVoteNo(player, data)
	if not validatePlayer(player) then return end

	-- ✅ SKIP VOTES ARE ALLOWED DURING BLOCK (democratic decision)

	local success = self.skipVoteManager:CastVote(player, "no", self.dispatcher)

	if success then
		self.dispatcher:Notify(player, "Your vote has been counted!")
	else
		self.dispatcher:Notify(player, "Unable to cast vote. No active vote or you already voted!")
	end
end

-- ====================================
-- RETRY ALL (RELOAD AUDIO FOR ALL PLAYERS)
-- ====================================
function MusicActionHandler:HandleRetryAll(player, data)
	if not validatePlayer(player) then return end

	-- Only allow admins
	local role = RoleSystem:GetPlayerRole(player)
	local roleHierarchy = RoleSystem.Config.RoleHierarchy[role] or 0

	if roleHierarchy < 4 then
		self.dispatcher:Notify(player, "Only Moderator+ can use retry all!")
		return
	end

	-- Reload audio on server
	local audioHandler = self.playbackManager.audioHandler
	if audioHandler then
		self.dispatcher:NotifyAll(string.format("Admin %s is reloading audio for all players...", player.DisplayName))

		task.spawn(function()
			local success = audioHandler:Reload()

			if success then
				task.wait(0.5)
				self.dispatcher:NotifyAll("Audio reloaded successfully!")
			else
				self.dispatcher:Notify(player, "Failed to reload audio!")
			end
		end)
	else
		self.dispatcher:Notify(player, "Audio handler not available!")
	end
end

-- ====================================
-- ADMIN TOGGLE BLOCK (✅ FIXED - NO NOTIFICATION TO ADMINS)
-- ====================================
function MusicActionHandler:HandleAdminToggleBlock(player, data)
	if not validatePlayer(player) then return end

	local role = RoleSystem:GetPlayerRole(player)
	local roleHierarchy = RoleSystem.Config.RoleHierarchy[role] or 0

	if roleHierarchy < 4 then
		self.dispatcher:Notify(player, "Only Moderator+ can toggle UI block!")
		return
	end

	self.systemState.IsUIBlocked = not self.systemState.IsUIBlocked
	local isBlocked = self.systemState.IsUIBlocked

	-- ✅ DEBUG: Log toggle action
	print(string.format("[Admin Block] %s (%s) toggled block to: %s", 
		player.DisplayName, role, tostring(isBlocked)))

	if isBlocked then
		-- Notify admin who activated
		self.dispatcher:Notify(player, "🔒 Admin block activated! Non-moderators cannot add songs.")

		-- Notify all players
		self.dispatcher:NotifyAll("⚠️ Admin mengambil alih akses musik")

		-- Send UI block event ONLY to non-moderators
		for _, plr in ipairs(game.Players:GetPlayers()) do
			local plrRole = RoleSystem:GetPlayerRole(plr)
			local plrHierarchy = RoleSystem.Config.RoleHierarchy[plrRole] or 0

			if plrHierarchy < 4 then
				-- ✅ FIXED: Only send to non-moderators
				self.dispatcher:SendToClient(plr, "ADMIN_BLOCK_ACTIVATED", {})
				print(string.format("[Admin Block] Blocking %s (Role: %s, Hierarchy: %d)", 
					plr.DisplayName, plrRole, plrHierarchy))
			else
				-- Update admin button text only
				self.dispatcher:SendToClient(plr, "ADMIN_BUTTON_UPDATE", {text = "Unblock"})
				print(string.format("[Admin Block] NOT blocking %s (Role: %s, Hierarchy: %d)", 
					plr.DisplayName, plrRole, plrHierarchy))
			end
		end
	else
		-- Notify admin who deactivated
		self.dispatcher:Notify(player, "🔓 Admin block deactivated! Players can now add songs.")

		-- Notify all players
		self.dispatcher:NotifyAll("✅ Akses musik dikembalikan")

		-- Remove UI block from everyone
		for _, plr in ipairs(game.Players:GetPlayers()) do
			local plrRole = RoleSystem:GetPlayerRole(plr)
			local plrHierarchy = RoleSystem.Config.RoleHierarchy[plrRole] or 0

			if plrHierarchy < 4 then
				self.dispatcher:SendToClient(plr, "ADMIN_BLOCK_DEACTIVATED", {})
			else
				self.dispatcher:SendToClient(plr, "ADMIN_BUTTON_UPDATE", {text = "Block"})
			end
		end
	end
end

-- ====================================
-- TOGGLE FAVORITE (✅ ALLOWED DURING BLOCK)
-- ====================================
function MusicActionHandler:HandleToggleFavorite(player, data)
	if not validatePlayer(player) then return end

	-- ✅ FAVORITES ARE ALLOWED DURING BLOCK (personal preference)

	local musicId = data.musicId
	if type(musicId) ~= "string" then return end

	local success, message = self.favoriteManager:ToggleFavorite(player.UserId, musicId)

	if success then
		local favorites = self.favoriteManager:GetPlayerFavorites(player.UserId)

		self.dispatcher:SendToClient(player, "FAVORITES_UPDATE", {
			favoriteSongs = favorites
		})

		self.dispatcher:Notify(player, message)
	else
		self.dispatcher:Notify(player, message)
	end
end

-- ====================================
-- DISPATCH ACTION (✅ FIXED WITH CENTRALIZED BLOCK CHECK)
-- ====================================
function MusicActionHandler:DispatchAction(player, action)
	if not validatePlayer(player) then return end
	if type(action) ~= "table" or type(action.type) ~= "string" then return end

	-- ✅ CENTRALIZED BLOCK CHECK (except for allowed actions)
	local allowedDuringBlock = {
		"SKIP_VOTE_YES",      -- Democratic vote
		"SKIP_VOTE_NO",       -- Democratic vote
		"TOGGLE_FAVORITE",    -- Personal preference
		"ADMIN_TOGGLE_BLOCK", -- Admin control
		"RETRY_ALL"           -- Admin maintenance
	}

	local isAllowedDuringBlock = false
	for _, allowedAction in ipairs(allowedDuringBlock) do
		if action.type == allowedAction then
			isAllowedDuringBlock = true
			break
		end
	end

	-- Check if player is blocked and action is not allowed
	if not isAllowedDuringBlock and self:IsPlayerBlocked(player) then
		self.dispatcher:Notify(player, "🔒 Music access is currently blocked by Admin!")
		return
	end

	local handlers = {
		ADD_TO_QUEUE = function() self:HandleAddToQueue(player, action.payload or {}) end,
		CONTROL_NEXT = function() self:HandleControlNext(player, action.payload or {}) end,
		SKIP_VOTE_YES = function() self:HandleSkipVoteYes(player, action.payload or {}) end,
		SKIP_VOTE_NO = function() self:HandleSkipVoteNo(player, action.payload or {}) end,
		ADMIN_TOGGLE_BLOCK = function() self:HandleAdminToggleBlock(player, action.payload or {}) end,
		TOGGLE_FAVORITE = function() self:HandleToggleFavorite(player, action.payload or {}) end,
		RETRY_ALL = function() self:HandleRetryAll(player, action.payload or {}) end,
	}

	local handler = handlers[action.type]
	if handler then
		pcall(handler)
	end
end

return MusicActionHandler