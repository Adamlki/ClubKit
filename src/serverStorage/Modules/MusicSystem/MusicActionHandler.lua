local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local MarketplaceService = game:GetService("MarketplaceService")

local RoleSystem = require(ServerStorage.Modules.RoleSystem)
local MusicModule = require(ReplicatedStorage.Modules:WaitForChild("MusicModule"))

local MusicActionHandler = {}
MusicActionHandler.__index = MusicActionHandler

local SONG_TITLE_CACHE = {}
local CACHE_DURATION = 3600

local ALLOWED_DURING_BLOCK = {
	SKIP_VOTE_YES = true,
	SKIP_VOTE_NO = true,
	TOGGLE_FAVORITE = true,
	ADMIN_TOGGLE_BLOCK = true,
	RETRY_ALL = true,
}

local ACTION_HANDLERS = {
	ADD_TO_QUEUE = "HandleAddToQueue",
	CONTROL_NEXT = "HandleControlNext",
	SKIP_VOTE_YES = "HandleSkipVoteYes",
	SKIP_VOTE_NO = "HandleSkipVoteNo",
	ADMIN_TOGGLE_BLOCK = "HandleAdminToggleBlock",
	TOGGLE_FAVORITE = "HandleToggleFavorite",
	RETRY_ALL = "HandleRetryAll",
}

local function getCachedSongTitle(musicId)
	local cached = SONG_TITLE_CACHE[musicId]
	-- os.time() (wall clock), bukan os.clock() (CPU time), supaya TTL 1 jam benar.
	if cached and (os.time() - cached.timestamp) < CACHE_DURATION then
		return cached.title
	end
	return nil
end

local function setCachedSongTitle(musicId, title)
	SONG_TITLE_CACHE[musicId] = {
		title = title,
		timestamp = os.time(),
	}
end

local function detectSongTitle(musicId)
	local cachedTitle = getCachedSongTitle(musicId)
	if cachedTitle then return cachedTitle end

	local numId = tonumber(musicId)
	if numId then
		local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, numId)
		if ok and info and info.Name then
			setCachedSongTitle(musicId, info.Name)
			return info.Name
		end
	end

	setCachedSongTitle(musicId, "Custom Music")
	return "Custom Music"
end

local function validatePlayer(player)
	return player and player:IsDescendantOf(Players)
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

	self.vipSkipData = {}
	self.adminSkipTimes = {}
	self._favoriteCooldowns = {}

	return self
end

function MusicActionHandler:IsPlayerBlocked(player)
	if not self.systemState.IsUIBlocked then return false end
	local role = RoleSystem:GetPlayerRole(player)
	local roleHierarchy = RoleSystem.Config.RoleHierarchy[role] or 0
	return roleHierarchy < RoleSystem.Config.RoleHierarchy.Moderator
end

function MusicActionHandler:HandleAddToQueue(player, data)
	if not validatePlayer(player) then return end

	if self:IsPlayerBlocked(player) then
		self.dispatcher:Notify(player, "🔒 Music access is currently blocked by Admin!")
		return
	end

	local musicId = data.musicId
	local isFromPlaylist = data.isFromPlaylist
	if type(musicId) ~= "string" or type(isFromPlaylist) ~= "boolean" then return end

	if not isFromPlaylist and not tonumber(musicId) then
		self.dispatcher:Notify(player, "ID Lagu tidak valid!")
		return
	end

	local role = RoleSystem:GetPlayerRole(player)
	if (RoleSystem.Config.RoleHierarchy[role] or 0) < RoleSystem.Config.RoleHierarchy.VIP then
		self.dispatcher:Notify(player, "⭐ Upgrade ke VIP untuk dapat menambah lagu ke antrean!")
		return
	end

	local canAdd, cooldownMsg = self.cooldownService:CheckCooldown(player, self.config.COOLDOWNS)
	if not canAdd then
		self.dispatcher:Notify(player, cooldownMsg)
		return
	end

	if not self.systemState.InitialPreloadComplete then
		self.dispatcher:Notify(player, "System is preloading music library, please wait...")
		return
	end

	task.spawn(function()
		local musicData

		if isFromPlaylist then
			musicData = MusicModule:GetMusicById(musicId)
			if not musicData then
				self.dispatcher:Notify(player, "Song not found in playlist!")
				return
			end
		else
			local moduleMusic = MusicModule:GetMusicById(musicId)
			if moduleMusic then
				musicData = moduleMusic
				self.dispatcher:Notify(player, string.format("Found '%s' in library!", moduleMusic.judul))
			else
				musicData = {
					id = musicId,
					judul = "Custom Music",
					sampul = "rbxassetid://88574818940840",
					Duration = self.config.DEFAULT_SONG_DURATION,
					PlaybackSpeed = 1.0,
				}
				self.dispatcher:Notify(player, "Adding custom music ID...")

				task.spawn(function()
					local detectedTitle = detectSongTitle(musicId)
					if detectedTitle ~= "Custom Music" then
						musicData.judul = detectedTitle
						self.dispatcher:Notify(player, string.format("Detected: '%s'", detectedTitle))
						self.dispatcher:SyncQueueOnly()
					end
				end)
			end
		end

		if not musicData.Duration or musicData.Duration <= 0 then
			musicData.Duration = self.config.DEFAULT_SONG_DURATION
		end
		-- MusicModule memakai nama field `speed`/`pitch`; normalisasi ke nama
		-- yang dipakai playback manager agar kecepatan tidak selalu 1.0x.
		musicData.PlaybackSpeed = musicData.PlaybackSpeed or musicData.speed or 1.0
		musicData.PitchOctave = musicData.PitchOctave or musicData.pitch or 1.0

		local success, errorMsg = self.queueManager:AddToQueue(musicData, player.DisplayName, player.UserId, role)
		if not success then
			self.dispatcher:Notify(player, errorMsg)
			return
		end

		self.cooldownService:UpdateCooldown(player)
		self.dispatcher:SyncQueueOnly()

		local queuePosition = self.queueManager:GetSize()
		self.dispatcher:Notify(player, string.format("'%s' added to queue (Position: #%d)", musicData.judul, queuePosition))

		if queuePosition == 1 and self.broadcastPreloadCallback then
			self.broadcastPreloadCallback()
		end

		if not self.playbackManager.isPlaying then
			task.delay(0.5, self.playNextCallback)
		end
	end)
end

function MusicActionHandler:CheckSkipCooldown(player, roleHierarchy)
	local userId = player.UserId
	local now = os.clock()

	if roleHierarchy >= RoleSystem.Config.RoleHierarchy.Moderator then
		local lastSkip = self.adminSkipTimes[userId]
		if lastSkip and (now - lastSkip) < 5 then
			return false, math.ceil(5 - (now - lastSkip))
		end
		return true, 0
	end

	local data = self.vipSkipData[userId]
	if data and data.lastSkipTime and data.lastSkipTime > 0 then
		local elapsed = now - data.lastSkipTime
		if elapsed < data.cooldown then
			return false, math.ceil(data.cooldown - elapsed)
		end
		if elapsed > (data.cooldown + 45) then
			data.streak = 0
			data.cooldown = 0
		end
	end

	return true, 0
end

function MusicActionHandler:RecordAdminSkip(player)
	if player then self.adminSkipTimes[player.UserId] = os.clock() end
end

function MusicActionHandler:RecordVipSkip(player)
	if player then self:RecordVipSkipById(player.UserId) end
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
	self._favoriteCooldowns[userId] = nil
end

function MusicActionHandler:HandleControlNext(player, data)
	if not validatePlayer(player) then return end

	if self:IsPlayerBlocked(player) then
		self.dispatcher:Notify(player, "🔒 Music access is currently blocked by Admin!")
		return
	end

	local role = RoleSystem:GetPlayerRole(player)
	local roleHierarchy = RoleSystem.Config.RoleHierarchy[role] or 0

	if roleHierarchy < RoleSystem.Config.RoleHierarchy.VIP then
		self.dispatcher:Notify(player, "⭐ Upgrade ke VIP untuk dapat melakukan Vote Skip!")
		return
	end

	local currentSong = self.playbackManager:GetCurrentSong()
	if not currentSong then
		self.dispatcher:Notify(player, "Tidak ada lagu yang sedang diputar!")
		return
	end

	local canSkip, remainingSec = self:CheckSkipCooldown(player, roleHierarchy)
	if not canSkip then
		self.dispatcher:Notify(player, string.format("⏳ Cooldown skip aktif! Tunggu %d detik lagi sebelum skip berikutnya.", remainingSec))
		return
	end

	if roleHierarchy >= RoleSystem.Config.RoleHierarchy.Moderator then
		self:RecordAdminSkip(player)
		self.dispatcher:NotifyAll(string.format("⏭️ %s (%s) melewati lagu: %s", player.DisplayName, role, currentSong.judul or "Unknown"))
		task.wait(1.0)
		self.playNextCallback()
		return
	end

	local vipData = self.vipSkipData[player.UserId]
	local currentVipCooldown = (vipData and vipData.cooldown and vipData.cooldown > 0) and vipData.cooldown or 7
	local canVote, remainingVoteSec = self.skipVoteManager:CheckRateLimit(player, math.max(7, currentVipCooldown))
	if not canVote then
		self.dispatcher:Notify(player, string.format("⏳ Tunggu %d detik lagi sebelum memulai vote skip baru!", remainingVoteSec))
		return
	end

	local success, passedOrMsg = self.skipVoteManager:StartVote(player, currentSong, self.dispatcher)
	if not success then
		self.dispatcher:Notify(player, passedOrMsg)
	elseif passedOrMsg == true then
		self:RecordVipSkip(player)
		self.dispatcher:NotifyAll(string.format("⏭️ Vote skip disetujui (100%%)! Melewati lagu: %s", currentSong.judul or "Unknown"))
		self.playNextCallback()
		self.skipVoteManager:EndVote(self.dispatcher, true)
	else
		self.dispatcher:NotifyAll(string.format("📢 %s memulai vote skip untuk: %s (Butuh 80%% suara player)", player.DisplayName, currentSong.judul or "Unknown"))
	end
end

function MusicActionHandler:HandleSkipVoteYes(player, data)
	if not validatePlayer(player) then return end

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
		self.playNextCallback()
		self.skipVoteManager:EndVote(self.dispatcher, true)
	else
		self.dispatcher:Notify(player, "Suara YES Anda telah tercatat!")
	end
end

function MusicActionHandler:HandleSkipVoteNo(player, data)
	if not validatePlayer(player) then return end

	local success = self.skipVoteManager:CastVote(player, "no", self.dispatcher)
	if success then
		self.dispatcher:Notify(player, "Suara NO Anda telah tercatat!")
	else
		self.dispatcher:Notify(player, "Gagal memilih. Vote tidak aktif atau Anda sudah memberikan suara!")
	end
end

function MusicActionHandler:HandleRetryAll(player, data)
	if not validatePlayer(player) then return end

	local role = RoleSystem:GetPlayerRole(player)
	if (RoleSystem.Config.RoleHierarchy[role] or 0) < RoleSystem.Config.RoleHierarchy.Moderator then
		self.dispatcher:Notify(player, "Hanya Moderator+ yang dapat menggunakan fitur reload audio!")
		return
	end

	local audioHandler = self.playbackManager.audioHandler
	if not audioHandler then
		self.dispatcher:Notify(player, "Audio handler not available!")
		return
	end

	self.dispatcher:NotifyAll(string.format("Admin %s is reloading audio for all players...", player.DisplayName))
	task.spawn(function()
		if audioHandler:Reload() then
			task.wait(0.5)
			self.dispatcher:NotifyAll("Audio reloaded successfully!")
		else
			self.dispatcher:Notify(player, "Failed to reload audio!")
		end
	end)
end

function MusicActionHandler:HandleAdminToggleBlock(player, data)
	if not validatePlayer(player) then return end

	local role = RoleSystem:GetPlayerRole(player)
	if (RoleSystem.Config.RoleHierarchy[role] or 0) < RoleSystem.Config.RoleHierarchy.Moderator then
		self.dispatcher:Notify(player, "Hanya Moderator+ yang dapat mengatur block sistem musik!")
		return
	end

	self.systemState.IsUIBlocked = not self.systemState.IsUIBlocked
	local isBlocked = self.systemState.IsUIBlocked

	self.dispatcher:Notify(player, isBlocked and "🔒 Admin block activated! Non-moderators cannot add songs." or "🔓 Admin block deactivated! Players can now add songs.")
	self.dispatcher:NotifyAll(isBlocked and "⚠️ Admin mengambil alih akses musik" or "✅ Akses musik dikembalikan")

	local blockEvt = isBlocked and "ADMIN_BLOCK_ACTIVATED" or "ADMIN_BLOCK_DEACTIVATED"
	local btnText = isBlocked and "Unblock" or "Block"

	for _, plr in ipairs(Players:GetPlayers()) do
		local plrRole = RoleSystem:GetPlayerRole(plr)
		local isMod = (RoleSystem.Config.RoleHierarchy[plrRole] or 0) >= RoleSystem.Config.RoleHierarchy.Moderator
		if isMod then
			self.dispatcher:SendToClient(plr, "ADMIN_BUTTON_UPDATE", { text = btnText })
		else
			self.dispatcher:SendToClient(plr, blockEvt, {})
		end
	end
end

function MusicActionHandler:HandleToggleFavorite(player, data)
	if not validatePlayer(player) then return end

	local now = os.clock()
	local lastReq = self._favoriteCooldowns[player.UserId] or 0
	if now - lastReq < 0.5 then
		self.dispatcher:Notify(player, "Tolong jangan spam tombol Favorite!")
		return
	end
	self._favoriteCooldowns[player.UserId] = now

	local musicId = data.musicId
	if type(musicId) ~= "string" then return end

	local success, message = self.favoriteManager:ToggleFavorite(player.UserId, musicId)
	if success then
		local favorites = self.favoriteManager:GetPlayerFavorites(player.UserId)
		self.dispatcher:SendToClient(player, "FAVORITES_UPDATE", {
			favoriteSongs = favorites,
		})
	end
	self.dispatcher:Notify(player, message)
end

function MusicActionHandler:DispatchAction(player, action)
	if not validatePlayer(player) then return end
	if type(action) ~= "table" or type(action.type) ~= "string" then return end

	if not ALLOWED_DURING_BLOCK[action.type] and self:IsPlayerBlocked(player) then
		self.dispatcher:Notify(player, "🔒 Music access is currently blocked by Admin!")
		return
	end

	local methodName = ACTION_HANDLERS[action.type]
	if methodName and self[methodName] then
		pcall(self[methodName], self, player, action.payload or {})
	end
end

return MusicActionHandler