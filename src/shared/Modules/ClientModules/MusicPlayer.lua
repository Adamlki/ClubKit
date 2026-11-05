--!optimize 2
--!native

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ContentProvider = game:GetService("ContentProvider")
local BridgeNet = require(ReplicatedStorage:WaitForChild("BridgeNet"))

local MusicModule = require(ReplicatedStorage.Modules.MusicModule)
local AssetConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("AssetConfig"))
local UIManager = require(script.Parent.UIManager)

local MusicPlayer = {}
MusicPlayer.__index = MusicPlayer

local CONFIG = {
	DEFAULT_VOLUME = 1,
	DEFAULT_COVER = AssetConfig.Music.DefaultCover,
}

local ROLE_HIERARCHY_MAP = {
	Owner = 5,
	Admin = 4,
	Moderator = 3,
	VIP = 2,
	Player = 1,
}

local ALLOWED_DURING_BLOCK = {
	SKIP_VOTE_YES = true,
	SKIP_VOTE_NO = true,
	TOGGLE_FAVORITE = true,
	ADMIN_TOGGLE_BLOCK = true,
	RETRY_ALL = true,
}

local function buildMusicData(data)
	local songObj = MusicModule:GetMusicById(data.SoundId)
	local albumName = (songObj and songObj.album) or data.Album
	local albumCover = albumName and MusicModule:GetAlbumCover(albumName)
	local cover = albumCover or (songObj and songObj.sampul) or data.AlbumCover or CONFIG.DEFAULT_COVER

	return {
		id = data.SoundId,
		judul = data.Title,
		album = albumName,
		sampul = cover,
		Duration = data.Duration or 0,
	}
end

function MusicPlayer.new()
	local self = setmetatable({}, MusicPlayer)

	self.player = Players.LocalPlayer
	self.remotes = self:WaitForRemotes()
	self.musicGroup = nil
	self:SetupVolumeControl()

	local playerGui = self.player:WaitForChild("PlayerGui", 30)
	local musicGui = playerGui and (playerGui:FindFirstChild("MusicPlayer") or playerGui:WaitForChild("MusicPlayer", 30))
	if not musicGui then
		warn("[MusicPlayer] MusicPlayer GUI tidak ditemukan di PlayerGui!")
		return self
	end

	self.uiManager = UIManager.new(musicGui)

	self.currentVolume = CONFIG.DEFAULT_VOLUME
	self.isMuted = false
	self.previousVolume = CONFIG.DEFAULT_VOLUME
	self.isBlocked = false
	self.playerRoleHierarchy = 1

	self.expectedIsPlaying = false
	self.lastTimePosition = 0
	self.absoluteStartTime = 0
	self.expectedSoundId = ""
	self.expectedDuration = 180
	self.expectedPlaybackSpeed = 1.0
	self._hasSnappedCurrentSong = false
	self.lastSongChangeTime = 0
	self.lastAutoRecoveryTime = 0
	self._isAutoRecovering = false
	self._isAutoReloading = false
	self._lastAutoReloadTime = 0
	self._autoReloadAttempts = 0

	self.preloadedCache = {}
	self.isPreloading = false
	self.preloadFolder = nil

	self:SetupUICallbacks()
	self:SetupRemoteListeners()
	self:SetupToggleKey()
	self:SetupChatCommands()
	self:SetupRoleWatcher()

	local function bindServerSoundListeners()
		local serverSound = SoundService:FindFirstChild("ServerMusicSound")
		if not serverSound then return end

		if self._soundLoadedConn then
			self._soundLoadedConn:Disconnect()
			self._soundLoadedConn = nil
		end
		if self._soundIdConn then
			self._soundIdConn:Disconnect()
			self._soundIdConn = nil
		end

		self._soundLoadedConn = serverSound.Loaded:Connect(function()
			if self.expectedIsPlaying then
				self._hasSnappedCurrentSong = false
				self:ForceAudioSync({
					ServerTime = self.absoluteStartTime,
					Duration = self.expectedDuration,
				})
			end
		end)

		self._soundIdConn = serverSound:GetPropertyChangedSignal("SoundId"):Connect(function()
			self._hasSnappedCurrentSong = false
			if self.expectedIsPlaying then
				task.defer(function()
					if serverSound.IsLoaded then
						self:ForceAudioSync({
							ServerTime = self.absoluteStartTime,
							Duration = self.expectedDuration,
						})
					end
				end)
			end
		end)
	end

	bindServerSoundListeners()
	SoundService.ChildAdded:Connect(function(child)
		if child.Name == "ServerMusicSound" then
			task.wait(0.2)
			bindServerSoundListeners()
		end
	end)

	local timeSinceLastUpdate = 0
	RunService.Heartbeat:Connect(function(dt)
		timeSinceLastUpdate += dt
		if timeSinceLastUpdate < 0.25 then return end
		timeSinceLastUpdate = 0

		local serverSound = SoundService:FindFirstChild("ServerMusicSound")
		if not serverSound then return end

		if self.musicGroup and serverSound.SoundGroup ~= self.musicGroup then
			serverSound.SoundGroup = self.musicGroup
		end

		local rawSoundId = tostring(serverSound.SoundId)
		if self._cachedCurrentSoundIdRaw ~= rawSoundId then
			self._cachedCurrentSoundIdRaw = rawSoundId
			self._cachedCurrentID = string.match(rawSoundId, "%d+")
		end
		local currentID = self._cachedCurrentID

		local rawExpected = tostring(self.expectedSoundId)
		if self._cachedExpectedSoundIdRaw ~= rawExpected then
			self._cachedExpectedSoundIdRaw = rawExpected
			self._cachedExpectedID = string.match(rawExpected, "%d+")
		end
		local expectedID = self._cachedExpectedID

		if expectedID and currentID and expectedID ~= "" then
			if currentID ~= expectedID then
				if (os.clock() - (self.lastSongChangeTime or 0)) > 3.0 and serverSound.IsPlaying then
					serverSound:Stop()
				end
				return
			end
		end

		if self.expectedIsPlaying and self.absoluteStartTime > 0 then
			local currentServerTime = workspace:GetServerTimeNow()
			local realTimeElapsed = currentServerTime - self.absoluteStartTime
			local targetSpeed = self.expectedPlaybackSpeed or 1.0
			local expectedTimePos = realTimeElapsed * targetSpeed

			local rawLength = serverSound.TimeLength
			local maxSeek = rawLength > 0 and rawLength or ((self.expectedDuration or 180) * targetSpeed)
			local displayDuration = self.expectedDuration or (maxSeek / targetSpeed)

			if maxSeek > 0 and expectedTimePos < maxSeek then
				if rawLength > 0 and serverSound.IsLoaded then
					local currentPos = serverSound.TimePosition
					local diff = expectedTimePos - currentPos
					local absDiff = math.abs(diff)

					if not self._hasSnappedCurrentSong or not serverSound.IsPlaying then
						pcall(function()
							serverSound.TimePosition = math.clamp(expectedTimePos, 0, maxSeek - 0.1)
							serverSound.PlaybackSpeed = targetSpeed
							if not serverSound.IsPlaying then serverSound:Play() end
							self._hasSnappedCurrentSong = true
						end)
					elseif absDiff > 0.35 then
						pcall(function()
							serverSound.TimePosition = math.clamp(expectedTimePos, 0, maxSeek - 0.1)
							serverSound.PlaybackSpeed = targetSpeed
						end)
					elseif absDiff > 0.04 then
						serverSound.PlaybackSpeed = targetSpeed * (diff > 0 and 1.025 or 0.975)
					elseif serverSound.PlaybackSpeed ~= targetSpeed then
						serverSound.PlaybackSpeed = targetSpeed
					end
				elseif (os.clock() - (self.lastSongChangeTime or 0)) > 2.5 then
					self:PerformAutoReload("Watchdog_Unloaded_Or_Silent")
				end
			end

			if displayDuration > 0 then
				local progress = math.clamp(realTimeElapsed / displayDuration, 0, 1)
				self.uiManager:UpdateProgress(progress, realTimeElapsed, displayDuration)
			end
		elseif serverSound.IsPlaying then
			serverSound:Stop()
		end
	end)

	self.uiManager:SetVolume(self.currentVolume * 100)
	self:UpdateVolume(self.currentVolume)

	task.spawn(function()
		self:SendAction("REQUEST_SYNC", {})
	end)

	return self
end

function MusicPlayer:WaitForRemotes()
	local remoteFolder = ReplicatedStorage:WaitForChild("MusicRemotes", 10)
	if not remoteFolder then
		warn("[MusicPlayer] Failed to find MusicRemotes folder!")
		return nil
	end

	return {
		DispatchEvent = remoteFolder:WaitForChild("DispatchEvent", 10),
		MusicAction = remoteFolder:WaitForChild("MusicAction", 10),
		MusicBroadcast = remoteFolder:WaitForChild("MusicBroadcast", 10),
		MusicUpdate = remoteFolder:WaitForChild("MusicUpdate", 10),
	}
end

function MusicPlayer:SetupRoleWatcher()
	local function updateRoleHierarchy(role)
		self.playerRoleHierarchy = ROLE_HIERARCHY_MAP[role] or 1
	end

	local roleValue = self.player:FindFirstChild("Role")
	if roleValue and roleValue:IsA("StringValue") then
		updateRoleHierarchy(roleValue.Value)
		roleValue.Changed:Connect(updateRoleHierarchy)
	else
		updateRoleHierarchy("Player")
		task.spawn(function()
			local found = self.player:WaitForChild("Role", 15)
			if found and found:IsA("StringValue") then
				updateRoleHierarchy(found.Value)
				found.Changed:Connect(updateRoleHierarchy)
			end
		end)
	end
end

function MusicPlayer:SetupVolumeControl()
	local musicGroup = SoundService:WaitForChild("MusicGroup", 5)
	if musicGroup then
		self.musicGroup = musicGroup
		self.musicGroup.Volume = CONFIG.DEFAULT_VOLUME
	else
		warn("[MusicPlayer] Server gagal mengirim MusicGroup! Memicu pembuatan lokal...")
		self:UpdateVolume(CONFIG.DEFAULT_VOLUME)
	end
end

function MusicPlayer:UpdateVolume(volumePercent)
	if not self.musicGroup or not self.musicGroup.Parent then
		self.musicGroup = SoundService:FindFirstChild("MusicGroup")
		if not self.musicGroup then
			self.musicGroup = Instance.new("SoundGroup")
			self.musicGroup.Name = "MusicGroup"
			self.musicGroup.Parent = SoundService
		end
	end

	if self.musicGroup then
		self.musicGroup.Volume = volumePercent
	end
end

function MusicPlayer:PerformAutoReload(reason)
	local serverSound = SoundService:FindFirstChild("ServerMusicSound")
	if not serverSound or not serverSound:IsA("Sound") or not self.expectedIsPlaying then return end

	local soundId = self.expectedSoundId
	if not soundId or soundId == "" then
		soundId = string.match(tostring(serverSound.SoundId), "%d+")
	end
	if not soundId or soundId == "" then return end

	local now = os.clock()
	if self._isAutoReloading or (now - (self._lastAutoReloadTime or 0)) < 3.5 then return end

	self._autoReloadAttempts = (self._autoReloadAttempts or 0) + 1
	if self._autoReloadAttempts > 4 then return end

	self._isAutoReloading = true
	self._lastAutoReloadTime = now

	task.spawn(function()
		local assetId = "rbxassetid://" .. soundId
		local currentPlaybackSpeed = serverSound.PlaybackSpeed or 1

		pcall(serverSound.Stop, serverSound)
		task.wait(0.15)

		pcall(function()
			serverSound.SoundId = ""
			task.wait(0.1)
			serverSound.SoundId = assetId
			serverSound.PlaybackSpeed = currentPlaybackSpeed

			if self.musicGroup and serverSound.SoundGroup ~= self.musicGroup then
				serverSound.SoundGroup = self.musicGroup
			end

			local startWait = os.clock()
			while (not serverSound.IsLoaded or serverSound.TimeLength == 0) and (os.clock() - startWait) < 4.0 do
				task.wait(0.1)
			end

			if self.expectedIsPlaying and self.absoluteStartTime > 0 then
				local currentServerTime = workspace:GetServerTimeNow()
				local realTimeElapsed = currentServerTime - self.absoluteStartTime
				local targetSpeed = self.expectedPlaybackSpeed or serverSound.PlaybackSpeed or 1
				local expectedTimePos = realTimeElapsed * targetSpeed
				local maxDuration = serverSound.TimeLength > 0 and serverSound.TimeLength or (self.expectedDuration or 180)

				if expectedTimePos >= 0 and expectedTimePos < maxDuration then
					pcall(function()
						serverSound.TimePosition = math.clamp(expectedTimePos, 0, maxDuration - 0.1)
						serverSound.PlaybackSpeed = targetSpeed
						self._hasSnappedCurrentSong = true
					end)
				end

				pcall(serverSound.Play, serverSound)
				self:UpdateVolume(self.currentVolume)
			end
		end)

		self._isAutoReloading = false
	end)
end

function MusicPlayer:RetryAudio()
	local serverSound = SoundService:FindFirstChild("ServerMusicSound")
	if not serverSound or not serverSound:IsA("Sound") then
		self.uiManager:ShowNotification("No active music found!")
		return
	end

	local currentSoundId = serverSound.SoundId
	if currentSoundId == "" and (not self.expectedSoundId or self.expectedSoundId == "") then
		self.uiManager:ShowNotification("No music loaded!")
		return
	end

	self.uiManager:ShowNotification("Reloading audio...")
	self._autoReloadAttempts = 0
	self._isAutoReloading = false
	self._lastAutoReloadTime = 0

	self:PerformAutoReload("User_Manual_Click")
end

function MusicPlayer:CanPerformAction(actionType)
	if self.playerRoleHierarchy >= 3 then return true end
	if ALLOWED_DURING_BLOCK[actionType] then return true end
	return not self.isBlocked
end

function MusicPlayer:SetupUICallbacks()
	local lastSubmitTime = 0
	self.uiManager:OnMusicSubmit(function(musicId: string)
		local now = os.clock()
		if now - lastSubmitTime < 0.3 then return end
		lastSubmitTime = now

		if self.playerRoleHierarchy < 2 then
			self.uiManager:ShowNotification("⭐ Upgrade ke VIP untuk dapat menambah lagu ke antrean!")
			return
		end

		if not self:CanPerformAction("ADD_TO_QUEUE") then
			self.uiManager:ShowNotification("🔒 Music access is currently blocked by Admin!")
			return
		end

		local isFromPlaylist = not (musicId:match("^%d+$") and #musicId <= 20)
		self:SendAction("ADD_TO_QUEUE", {
			musicId = musicId,
			isFromPlaylist = isFromPlaylist,
		})
	end)

	local lastNextTime = 0
	self.uiManager:OnNext(function()
		local now = os.clock()
		if now - lastNextTime < 0.3 then return end
		lastNextTime = now

		if self.playerRoleHierarchy < 2 then
			self.uiManager:ShowNotification("⭐ Upgrade ke VIP untuk dapat melakukan Vote Skip!")
			return
		end

		if not self:CanPerformAction("CONTROL_NEXT") then
			self.uiManager:ShowNotification("🔒 Music access is currently blocked by Admin!")
			return
		end

		self:SendAction("CONTROL_NEXT", {})
	end)

	local lastReloadTime = 0
	self.uiManager:OnReload(function()
		local now = os.clock()
		if now - lastReloadTime < 0.3 then return end
		lastReloadTime = now
		self:RetryAudio()
	end)

	self.uiManager:OnVolumeChange(function(percent)
		self.currentVolume = percent
		self.isMuted = false
		self:UpdateVolume(percent)
	end)

	local lastVoteTime = 0
	self.uiManager:OnSkipVoteResponse(function(voteType)
		local now = os.clock()
		if now - lastVoteTime < 0.3 then return end
		lastVoteTime = now

		self:SendAction(voteType == "yes" and "SKIP_VOTE_YES" or "SKIP_VOTE_NO", {})
	end)

	local lastAdminToggleTime = 0
	self.uiManager:OnAdminToggleBlock(function()
		local now = os.clock()
		if now - lastAdminToggleTime < 0.3 then return end
		lastAdminToggleTime = now
		self:SendAction("ADMIN_TOGGLE_BLOCK", {})
	end)

	local lastFavTime = 0
	self.uiManager:OnToggleFavorite(function(musicId)
		local now = os.clock()
		if now - lastFavTime < 0.3 then return end
		lastFavTime = now
		self:SendAction("TOGGLE_FAVORITE", { musicId = musicId })
	end)
end

function MusicPlayer:SetupRemoteListeners()
	self.remotes.DispatchEvent.OnClientEvent:Connect(function(data)
		self:HandleDispatchEvent(data)
	end)

	local musicBroadcastBridge = BridgeNet.CreateBridge("MusicBroadcast")
	musicBroadcastBridge:Connect(function(payload)
		if type(payload) == "table" and payload.eventType then
			self:HandleMusicBroadcast(payload.eventType, payload.data)
		end
	end)

	self.remotes.MusicUpdate.OnClientEvent:Connect(function(eventType, payload)
		if eventType == "SyncMusic" then
			self:SyncMusicUI(payload)
		end
	end)
end

function MusicPlayer:PreloadSong(soundId)
	if not soundId or soundId == "" then return end
	local idStr = string.match(tostring(soundId), "%d+")
	if not idStr or idStr == "" or self.preloadedCache[idStr] then return end

	self.preloadedCache[idStr] = true

	task.defer(function()
		if RunService:IsStudio() then
			task.wait(1.5)
		elseif self.isPreloading then
			task.wait(1)
		end

		self.isPreloading = true

		local ok = pcall(function()
			if not self.preloadFolder or not self.preloadFolder.Parent then
				local existing = SoundService:FindFirstChild("ClientAudioPreloadCache")
				if existing and existing:IsA("Folder") then
					self.preloadFolder = existing
				else
					local f = Instance.new("Folder")
					f.Name = "ClientAudioPreloadCache"
					f.Parent = SoundService
					self.preloadFolder = f
				end
			end

			local existingSound = self.preloadFolder:FindFirstChild("Preload_" .. idStr)
			if existingSound then
				self.isPreloading = false
				return
			end

			local existingSounds = self.preloadFolder:GetChildren()
			if #existingSounds >= 3 then
				local oldest = existingSounds[1]
				local evictedId = string.match(oldest.Name, "%d+")
				if evictedId then self.preloadedCache[evictedId] = nil end
				oldest:Destroy()
			end

			local preloadSound = Instance.new("Sound")
			preloadSound.Name = "Preload_" .. idStr
			preloadSound.SoundId = "rbxassetid://" .. idStr
			preloadSound.Volume = 0
			preloadSound.Parent = self.preloadFolder

			ContentProvider:PreloadAsync({ preloadSound })
		end)

		if not ok then
			self.preloadedCache[idStr] = nil
			pcall(function()
				if self.preloadFolder then
					local failedSound = self.preloadFolder:FindFirstChild("Preload_" .. idStr)
					if failedSound then failedSound:Destroy() end
				end
			end)
		end

		self.isPreloading = false
	end)
end

function MusicPlayer:HandleDispatchEvent(data)
	if not data or not data.type then return end

	local eventType = data.type
	local payload = data.payload or {}

	if eventType == "NOTIFY" then
		self.uiManager:ShowNotification(payload.message)
	elseif eventType == "PRELOAD_SONG" then
		if payload.soundId then self:PreloadSong(payload.soundId) end
	elseif eventType == "SYNC_STATE" then
		self:SyncState(payload)
	elseif eventType == "QUEUE_UPDATE" then
		local queue = payload.queue or {}
		self.uiManager:UpdateQueue(queue)
		if #queue > 0 and queue[1] then
			local nextItem = queue[1]
			local nextData = nextItem.musicData or nextItem
			if nextData and nextData.id then self:PreloadSong(nextData.id) end
		end
	elseif eventType == "SKIP_VOTE_START" then
		self.uiManager:ShowSkipVote(payload.initiator, payload.songTitle, payload.totalVoters, payload.requiredVotes, payload.yesVotes, payload.noVotes, payload.isInitiator)
	elseif eventType == "SKIP_VOTE_UPDATE" then
		self.uiManager:UpdateSkipVote(payload.yesVotes, payload.noVotes, payload.totalVoters, payload.requiredVotes)
	elseif eventType == "SKIP_VOTE_END" then
		self.uiManager:HideSkipVote()
		self.uiManager:ShowSkipVoteResult(payload.result == "passed")
	elseif eventType == "ADMIN_BLOCK_ACTIVATED" then
		self.isBlocked = true
		self.uiManager:ShowBlockFrame()
	elseif eventType == "ADMIN_BLOCK_DEACTIVATED" then
		self.isBlocked = false
		self.uiManager:HideBlockFrame()
	elseif eventType == "ADMIN_BUTTON_UPDATE" then
		self.uiManager:UpdateAdminButtonText(payload.text or "Block")
	elseif eventType == "FAVORITES_UPDATE" then
		self.uiManager:UpdateFavorites(payload.favoriteSongs or {})
	end
end

function MusicPlayer:HandleMusicBroadcast(eventType, payload)
	if eventType == "SongUpdate" then
		if payload.Duration and payload.Duration > 0 then
			self.expectedDuration = payload.Duration
		end

		self:UpdateMusicUI(payload)

		if not payload.IsCorrection then
			self.lastSongChangeTime = os.clock()
			self._autoReloadAttempts = 0
			self.absoluteStartTime = payload.ServerTime or workspace:GetServerTimeNow()
			self.expectedSoundId = payload.SoundId or payload.id or ""
			self.expectedPlaybackSpeed = payload.PlaybackSpeed or 1.0
			self._hasSnappedCurrentSong = false
			self.expectedIsPlaying = true
			self.lastTimePosition = 0

			self:ForceAudioSync(payload)
		end
	elseif eventType == "StopMusic" then
		self:StopMusicUI()
		self.expectedIsPlaying = false
		self.lastTimePosition = 0
	end
end

function MusicPlayer:ForceAudioSync(payload)
	local serverSound = SoundService:FindFirstChild("ServerMusicSound")
	if not serverSound then return end

	task.spawn(function()
		if not serverSound.IsLoaded or serverSound.TimeLength == 0 then
			local t = os.clock()
			while (not serverSound.IsLoaded or serverSound.TimeLength == 0) and (os.clock() - t) < 3.5 do
				task.wait(0.1)
			end
		end

		if not serverSound.IsLoaded or serverSound.TimeLength == 0 then
			self:PerformAutoReload("Initial_Load_HTTP502_Fallback")
			return
		end

		if not payload.ServerTime or not self.expectedIsPlaying then return end

		local currentServerTime = workspace:GetServerTimeNow()
		local realTimeElapsed = currentServerTime - payload.ServerTime
		local targetSpeed = self.expectedPlaybackSpeed or serverSound.PlaybackSpeed or 1.0
		local expectedTimePos = realTimeElapsed * targetSpeed
		local rawLength = serverSound.TimeLength
		local maxSeek = rawLength > 0 and rawLength or ((payload.Duration or 180) * targetSpeed)
		if maxSeek <= 0 then maxSeek = 9999 end

		if expectedTimePos >= 0 and expectedTimePos < maxSeek then
			pcall(function()
				local currentPos = serverSound.TimePosition
				local diff = math.abs(currentPos - expectedTimePos)
				if serverSound.IsPlaying and self._hasSnappedCurrentSong and diff < 0.35 then
					serverSound.PlaybackSpeed = targetSpeed
					return
				end

				serverSound.TimePosition = math.clamp(expectedTimePos, 0, maxSeek - 0.1)
				serverSound.PlaybackSpeed = targetSpeed
				if not serverSound.IsPlaying then serverSound:Play() end
				self._hasSnappedCurrentSong = true
			end)
		elseif serverSound.IsPlaying then
			pcall(serverSound.Stop, serverSound)
		end
	end)
end

function MusicPlayer:SyncState(state)
	self.isBlocked = state.isBlocked or false
	local queue = state.queue or {}
	self.uiManager:UpdateQueue(queue)

	if #queue > 0 and queue[1] then
		local nextItem = queue[1]
		local nextData = nextItem.musicData or nextItem
		if nextData and nextData.id then self:PreloadSong(nextData.id) end
	end

	if state.favoriteSongs then
		self.uiManager:UpdateFavorites(state.favoriteSongs)
	end

	if state.currentSong then
		self.expectedDuration = state.duration or state.currentSong.Duration or 180
		self.uiManager:UpdateNowPlaying(state.currentSong, state.currentUploader, false)
		self.uiManager:UpdateSongDuration(state.duration or 0, state.currentSong.Duration, false)

		self.expectedIsPlaying = state.isPlaying
		self.lastTimePosition = 0

		if state.isPlaying then
			self.absoluteStartTime = state.startTime or workspace:GetServerTimeNow()
			local newSoundId = state.currentSong.SoundId or state.currentSong.id or ""
			self.expectedSoundId = newSoundId
			self.expectedPlaybackSpeed = state.currentSong.PlaybackSpeed or 1.0

			local serverSound = SoundService:FindFirstChild("ServerMusicSound")
			local currentID = string.match(tostring(serverSound and serverSound.SoundId or ""), "%d+")
			local targetID = string.match(tostring(newSoundId), "%d+")

			if not serverSound or not serverSound.IsPlaying or currentID ~= targetID then
				self._hasSnappedCurrentSong = false
				self:ForceAudioSync({
					ServerTime = self.absoluteStartTime,
					Duration = state.duration or self.expectedDuration,
				})
			end
		end
	else
		self.expectedIsPlaying = false
		self.lastTimePosition = 0
	end

	if state.isBlocked and self.playerRoleHierarchy < 3 then
		self.uiManager:ShowBlockFrame()
	else
		self.uiManager:HideBlockFrame()
	end
end

function MusicPlayer:UpdateMusicUI(data)
	local musicData = buildMusicData(data)
	self.uiManager:UpdateNowPlaying(musicData, data.AddedBy, not data.IsCorrection)
	self.uiManager:UpdateSongDuration(
		data.DetectedDuration or data.Duration or 0,
		data.MetadataDuration,
		data.WasDetected or false
	)
end

function MusicPlayer:SyncMusicUI(data)
	local musicData = buildMusicData(data)
	self.uiManager:UpdateNowPlaying(musicData, data.AddedBy, false)
	self.uiManager:UpdateSongDuration(data.Duration or 0)

	if data.IsPlaying then
		self.expectedIsPlaying = true
		self.expectedSoundId = data.SoundId or ""
		self.expectedDuration = data.Duration or 180
		self.expectedPlaybackSpeed = data.PlaybackSpeed or 1.0

		if data.ServerTime then
			self.absoluteStartTime = data.ServerTime
		elseif data.TimePosition then
			self.absoluteStartTime = workspace:GetServerTimeNow() - (data.TimePosition / self.expectedPlaybackSpeed)
		end

		local serverSound = SoundService:FindFirstChild("ServerMusicSound")
		local currentID = string.match(tostring(serverSound and serverSound.SoundId or ""), "%d+")
		local targetID = string.match(tostring(data.SoundId or ""), "%d+")

		if not serverSound or not serverSound.IsPlaying or currentID ~= targetID then
			self._hasSnappedCurrentSong = false
			self:ForceAudioSync({
				ServerTime = self.absoluteStartTime,
				Duration = self.expectedDuration,
			})
		end
	end
end

function MusicPlayer:StopMusicUI()
	self.uiManager:ResetUI()
end

function MusicPlayer:SendAction(actionType, payload)
	if not self.remotes then return end

	local now = os.clock()
	self._lastActionTimes = self._lastActionTimes or {}
	if self._lastActionTimes[actionType] and (now - self._lastActionTimes[actionType]) < 0.3 then
		return
	end
	self._lastActionTimes[actionType] = now

	pcall(function()
		self.remotes.MusicAction:FireServer({
			type = actionType,
			payload = payload or {},
		})
	end)
end

function MusicPlayer:SetupToggleKey()
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if not gameProcessed and input.KeyCode == Enum.KeyCode.M then
			self.uiManager:ToggleMainFrame()
		end
	end)
end

function MusicPlayer:SetupChatCommands()
	self.player.Chatted:Connect(function(message)
		local lowerMsg = string.lower(message)

		local volStr = lowerMsg:match("^[;/]vol%s+(%d+)")
		if volStr then
			local volume = math.clamp(tonumber(volStr) or 100, 0, 100)
			self.currentVolume = volume / 100
			self.isMuted = false
			self.uiManager:SetVolume(volume)
			self:UpdateVolume(self.currentVolume)
			self.uiManager:ShowNotification(string.format("Volume set to %d%%", volume))
			return
		end

		if lowerMsg == "/mute" or lowerMsg == ";mute" then
			self.isMuted = not self.isMuted
			if self.isMuted then
				self.previousVolume = self.currentVolume > 0 and self.currentVolume or CONFIG.DEFAULT_VOLUME
				self.currentVolume = 0
			else
				self.currentVolume = self.previousVolume
			end
			self.uiManager:SetVolume(self.currentVolume * 100)
			self:UpdateVolume(self.currentVolume)
			self.uiManager:ShowNotification(self.isMuted and "Muted" or "Unmuted")
			return
		end

		if lowerMsg:match("^[;/]ret$") or lowerMsg:match("^[;/]retry$") then
			self:RetryAudio()
		elseif lowerMsg == "/retryall" or lowerMsg == ";retryall" then
			self:SendAction("RETRY_ALL", {})
		end
	end)
end

return MusicPlayer
