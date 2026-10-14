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
	self.broadcastPreloadCallback = managers.broadcastPreloadCallback

	self.vipSkipData = {}     -- [userId] = { streak = number, lastSkipTime = number, cooldown = number }
	self.adminSkipTimes = {}  -- [userId] = timestamp (flat 5 detik per orang)

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

	-- Moderator+ (hierarchy >= Moderator / 3) are never blocked
	if roleHierarchy >= RoleSystem.Config.RoleHierarchy.Moderator then
		print(string.format("[Block Check] %s is Moderator+ - NOT BLOCKED", player.DisplayName))
		return false
	end

	-- Non-moderators are blocked
	print(string.format("[Block Check] %s is blocked (hierarchy %d < %d)", player.DisplayName, roleHierarchy, RoleSystem.Config.RoleHierarchy.Moderator))
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

	-- 🔥 FIX: Cek apakah ID musik murni angka (jika bukan dari playlist)
	if not isFromPlaylist and not tonumber(musicId) then
		self.dispatcher:Notify(player, "ID Lagu tidak valid!")
		return
	end

	-- Check role permission
	local role = RoleSystem:GetPlayerRole(player)
	if RoleSystem.Config.RoleHierarchy[role] < RoleSystem.Config.RoleHierarchy.VIP then
		self.dispatcher:Notify(player, "⭐ Upgrade ke VIP untuk dapat menambah lagu ke antrean!")
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

		-- Broadcast queue update to all (termasuk player yang menambah lagu)
		self.dispatcher:SyncQueueOnly()

		local queuePosition = self.queueManager:GetSize()
		self.dispatcher:Notify(player, string.format("'%s' added to queue (Position: #%d)", musicData.judul, queuePosition))

		-- 🚀 Jika lagu ini berada di posisi antrean #1 (upcoming), langsung picu preload ke semua client
		if queuePosition == 1 and self.broadcastPreloadCallback then
			self.broadcastPreloadCallback()
		end

		-- Auto-play if nothing is playing (Gunakan variabel isPlaying langsung, jangan method IsPlaying() untuk menghindari bias audio loading)
		if not self.playbackManager.isPlaying then
			task.delay(0.5, self.playNextCallback)
		end
	end)
end

-- ====================================
-- SKIP COOLDOWN TRACKING
-- PER-ORANG (PER-PLAYER), BUKAN SERVER-WIDE:
-- - VIP: Kelipatan 7 detik (Skip 1 = 7s, Skip 2 = 14s, Skip 3 = 21s, dst.)
-- - Jajaran Owner/Admin/Moderator: Flat 5 detik tiap klik skip
-- ====================================
function MusicActionHandler:CheckSkipCooldown(player, roleHierarchy)
	local userId = player.UserId
	local now = os.clock()

	-- Jajaran Owner / Admin / Moderator: Flat cooldown 5 detik per orang
	if roleHierarchy >= RoleSystem.Config.RoleHierarchy.Moderator then
		local lastSkip = self.adminSkipTimes[userId]
		if lastSkip and (now - lastSkip) < 5 then
			local remaining = math.ceil(5 - (now - lastSkip))
			return false, remaining
		end
		return true, 0
	end

	-- VIP: Cooldown kelipatan 7 detik per orang (Skip 1 = 7s, Skip 2 = 14s, Skip 3 = 21s, dst.)
	local data = self.vipSkipData[userId]
	if data and data.lastSkipTime and data.lastSkipTime > 0 then
		local elapsed = now - data.lastSkipTime
		if elapsed < data.cooldown then
			local remaining = math.ceil(data.cooldown - elapsed)
			return false, remaining
		end

		-- Jika sudah lewat cooldown + 45 detik tanpa skip baru, reset streak ke 0
		if elapsed > (data.cooldown + 45) then
			data.streak = 0
			data.cooldown = 0
		end
	end

	return true, 0
end

function MusicActionHandler:RecordAdminSkip(player)
	if not player then return end
	self.adminSkipTimes[player.UserId] = os.clock()
end

function MusicActionHandler:RecordVipSkip(player)
	if not player then return end
	self:RecordVipSkipById(player.UserId)
end

function MusicActionHandler:RecordVipSkipById(userId)
	if not userId then return end
	local data = self.vipSkipData[userId]
	if not data then
		data = { streak = 0, lastSkipTime = 0, cooldown = 0 }
		self.vipSkipData[userId] = data
	end

	data.streak = (data.streak or 0) + 1
	data.cooldown = data.streak * 7
	data.lastSkipTime = os.clock()
end

function MusicActionHandler:ResetAllSkipStreaks()
	self.vipSkipData = {}
end

function MusicActionHandler:ResetSkipStreak()
	self:ResetAllSkipStreaks()
end

function MusicActionHandler:CleanupPlayer(userId)
	if not userId then return end
	self.vipSkipData[userId] = nil
	self.adminSkipTimes[userId] = nil
end

-- ====================================
-- CONTROL NEXT (SKIP)
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

	-- Check minimum role (Hanya VIP ke atas yang bisa skip / vote skip)
	if roleHierarchy < RoleSystem.Config.RoleHierarchy.VIP then
		self.dispatcher:Notify(player, "⭐ Upgrade ke VIP untuk dapat melakukan Vote Skip!")
		return
	end

	local currentSong = self.playbackManager:GetCurrentSong()
	if not currentSong then
		self.dispatcher:Notify(player, "Tidak ada lagu yang sedang diputar!")
		return
	end

	-- 🛡️ CEK COOLDOWN SKIP PER-ORANG
	-- Jajaran Owner/Admin: Flat 5s cooldown
	-- VIP: Cooldown kelipatan 7s (7s, 14s, 21s, dst.)
	local canSkip, remainingSec = self:CheckSkipCooldown(player, roleHierarchy)
	if not canSkip then
		self.dispatcher:Notify(player, string.format("⏳ Cooldown skip aktif! Tunggu %d detik lagi sebelum skip berikutnya.", remainingSec))
		return
	end

	-- Moderator+ (Moderator, Admin, Owner) dapat langsung skip (Force Skip tanpa vote, flat cooldown 5 detik per orang)
	if roleHierarchy >= RoleSystem.Config.RoleHierarchy.Moderator then
		self:RecordAdminSkip(player)
		self.dispatcher:NotifyAll(string.format("⏭️ %s (%s) melewati lagu: %s", player.DisplayName, role, currentSong.judul or "Unknown"))
		task.wait(1.0)
		self.playNextCallback()
		return
	end

	-- Regular skip vote untuk VIP
	-- Cek rate limit untuk mencegah spam vote (gunakan skip cooldown VIP saat ini atau minimal 7s)
	local vipData = self.vipSkipData[player.UserId]
	local currentVipCooldown = (vipData and vipData.cooldown and vipData.cooldown > 0) and vipData.cooldown or 7
	local voteCooldown = math.max(7, currentVipCooldown)
	local canVote, remainingVoteSec = self.skipVoteManager:CheckRateLimit(player, voteCooldown)
	if not canVote then
		self.dispatcher:Notify(player, string.format("⏳ Tunggu %d detik lagi sebelum memulai vote skip baru!", remainingVoteSec))
		return
	end

	-- Mulai skip vote (Vote dikirim ke seluruh player di server, butuh 80% suara)
	local success, passedOrMsg = self.skipVoteManager:StartVote(player, currentSong, self.dispatcher)
	if not success then
		self.dispatcher:Notify(player, passedOrMsg)
	elseif passedOrMsg == true then
		-- Langsung lolos jika ambang batas 80% terpenuhi seketika (contoh: pemain VIP sendirian di server)
		self:RecordVipSkip(player)
		self.dispatcher:NotifyAll(string.format("⏭️ Vote skip disetujui (100%%)! Melewati lagu: %s", currentSong.judul or "Unknown"))
		self.playNextCallback()
		self.skipVoteManager:EndVote(self.dispatcher, true)
	else
		self.dispatcher:NotifyAll(string.format("📢 %s memulai vote skip untuk: %s (Butuh 80%% suara player)", player.DisplayName, currentSong.judul or "Unknown"))
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
		self.dispatcher:Notify(player, "Gagal memilih. Vote tidak aktif atau Anda sudah memberikan suara!")
		return
	end

	if passed then
		local initiatorId = self.skipVoteManager.skipVote and self.skipVoteManager.skipVote.initiatorId
		if initiatorId then
			self:RecordVipSkipById(initiatorId)
		else
			self:RecordVipSkip(player)
		end
		local currentSong = self.playbackManager:GetCurrentSong()
		self.dispatcher:NotifyAll(string.format("⏭️ Vote skip lolos (80%% tercapai)! Melewati: %s", currentSong and currentSong.judul or "Unknown"))
		-- 🔥 FIX: Dihapus task.wait(1) untuk mencegah bug double-skip
		self.playNextCallback()
		self.skipVoteManager:EndVote(self.dispatcher, true)
	else
		self.dispatcher:Notify(player, "Suara YES Anda telah tercatat!")
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
		self.dispatcher:Notify(player, "Suara NO Anda telah tercatat!")
	else
		self.dispatcher:Notify(player, "Gagal memilih. Vote tidak aktif atau Anda sudah memberikan suara!")
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

	if roleHierarchy < RoleSystem.Config.RoleHierarchy.Moderator then
		self.dispatcher:Notify(player, "Hanya Moderator+ yang dapat menggunakan fitur reload audio!")
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

	if roleHierarchy < RoleSystem.Config.RoleHierarchy.Moderator then
		self.dispatcher:Notify(player, "Hanya Moderator+ yang dapat mengatur block sistem musik!")
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

			if plrHierarchy < RoleSystem.Config.RoleHierarchy.Moderator then
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

			if plrHierarchy < RoleSystem.Config.RoleHierarchy.Moderator then
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

	-- 🔥 FIX: Rate Limiter untuk mencegah spam dan lag server
	self._favoriteCooldowns = self._favoriteCooldowns or {}
	local lastReq = self._favoriteCooldowns[player.UserId] or 0
	if tick() - lastReq < 0.5 then
		self.dispatcher:Notify(player, "Tolong jangan spam tombol Favorite!")
		return
	end
	self._favoriteCooldowns[player.UserId] = tick()

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