local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

local ServerMusicAudioHandler = require(script.Parent.ServerMusicAudioHandler)
local BridgeNet = require(ReplicatedStorage:WaitForChild("BridgeNet"))
local MusicModule = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("MusicModule"))
local AssetConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("AssetConfig"))

local musicBroadcastBridge = BridgeNet.CreateBridge("MusicBroadcast")

local MusicPlaybackManager = {}
MusicPlaybackManager.__index = MusicPlaybackManager

local CONFIG = {
	PROGRESS_BROADCAST_INTERVAL = 2,
	DEFAULT_COVER = AssetConfig.Music.DefaultCover,
	DEFAULT_PLAYBACK_SPEED = 1.0,
	AUTO_DURATION_TIMEOUT = 12,
}

local bannedSongCache = {}
local temporaryCdnCooldown = {}
local assetInfoCache = {}
local ASSET_INFO_TTL = 600

local function getCachedAssetInfo(numericId)
	local now = os.clock()
	local cached = assetInfoCache[numericId]
	if cached and (now - cached.time) < ASSET_INFO_TTL then
		return cached.ok, cached.info
	end

	local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, numericId, Enum.InfoType.Asset)
	assetInfoCache[numericId] = { ok = ok, info = info, time = now }
	return ok, info
end

function MusicPlaybackManager.new(config)
	local self = setmetatable({}, MusicPlaybackManager)

	self.config = config
	self.currentSong = nil
	self.currentUploader = nil
	self.isPlaying = false
	self.songStartTime = 0
	self.songDuration = 0
	self.adjustedDuration = 0
	self.isPlaylistMode = false
	self.consecutiveFailures = 0

	self.audioHandler = ServerMusicAudioHandler.new()

	self.autoNextCallback = nil
	self.onSongFailed = nil
	self.endedConnection = nil
	self.watchdogThread = nil
	self._playbackGeneration = 0

	self.volumeTween = nil
	self.originalVolume = 0.5

	return self
end

function MusicPlaybackManager:GetState()
	return {
		currentSong = self.currentSong,
		currentUploader = self.currentUploader,
		isPlaying = self.isPlaying,
		isPaused = false,
		startTime = self.songStartTime,
		duration = self.adjustedDuration,
		isPlaylistMode = self.isPlaylistMode,
		elapsedTime = self:GetElapsedTime(),
	}
end

function MusicPlaybackManager:IsPlaying()
	return self.isPlaying and self.audioHandler:IsPlaying()
end

function MusicPlaybackManager:GetCurrentSong()
	return self.currentSong
end

function MusicPlaybackManager:GetElapsedTime()
	return self.isPlaying and self.audioHandler:GetTimePosition() or 0
end

function MusicPlaybackManager:GetRemainingTime()
	if not self.isPlaying then return 0 end
	return math.max(0, self.adjustedDuration - self:GetElapsedTime())
end

function MusicPlaybackManager:IsFromPlaylist()
	return self.isPlaylistMode
end

function MusicPlaybackManager:StartWatchdog(duration)
	self:CancelWatchdog()

	local songGeneration = self._playbackGeneration
	local currentSongId = self.currentSong and self.currentSong.id
	local timeout = (duration or self.adjustedDuration or 180) + 2

	self.watchdogThread = task.delay(timeout, function()
		if self._playbackGeneration == songGeneration and self.isPlaying and self.currentSong and self.currentSong.id == currentSongId then
			self:CancelWatchdog()
			if self.endedConnection then
				self.endedConnection:Disconnect()
				self.endedConnection = nil
			end
			if self.autoNextCallback then
				pcall(self.autoNextCallback)
			end
		end
	end)
end

function MusicPlaybackManager:CancelWatchdog()
	if self.watchdogThread then
		task.cancel(self.watchdogThread)
		self.watchdogThread = nil
	end
end

function MusicPlaybackManager:TryDetectDuration(soundId, playbackSpeed, customTimeout)
	local timeout = customTimeout or CONFIG.AUTO_DURATION_TIMEOUT
	local success, detectedDuration = pcall(function()
		local sound = self.audioHandler:GetSound()
		if not sound then return nil end

		local startTime = os.clock()
		while sound.TimeLength == 0 and not sound.IsLoaded and (os.clock() - startTime) < timeout do
			task.wait(0.1)
		end

		if sound.TimeLength > 0 then
			local speed = (playbackSpeed and playbackSpeed > 0) and playbackSpeed or 1
			return sound.TimeLength / speed
		end
		return nil
	end)

	if success and detectedDuration and detectedDuration > 0 then
		return detectedDuration
	end
	return nil
end

function MusicPlaybackManager:ConnectEndedEvent()
	if self.endedConnection then
		self.endedConnection:Disconnect()
		self.endedConnection = nil
	end

	local sound = self.audioHandler:GetSound()
	if not sound then return end

	local songGeneration = self._playbackGeneration
	self.endedConnection = sound.Ended:Connect(function()
		if self._playbackGeneration == songGeneration and self.autoNextCallback and self.isPlaying then
			self:CancelWatchdog()
			task.spawn(function()
				task.wait(1.5)
				if self._playbackGeneration == songGeneration then
					pcall(self.autoNextCallback)
				end
			end)
		end
	end)
end

function MusicPlaybackManager:CancelFade()
	if self.volumeTween then
		self.volumeTween:Cancel()
		self.volumeTween = nil
	end
end

local function tweenVolume(self, targetVolume, duration, easingDir)
	self:CancelFade()
	local sound = self.audioHandler:GetSound()
	if not sound or not sound.IsPlaying then return end

	if targetVolume > 0 then
		sound.Volume = 0
	end

	local tween = TweenService:Create(
		sound,
		TweenInfo.new(duration, Enum.EasingStyle.Linear, easingDir),
		{ Volume = targetVolume }
	)
	self.volumeTween = tween
	tween:Play()
	tween.Completed:Connect(function()
		if self.volumeTween == tween then
			self.volumeTween = nil
		end
	end)
end

function MusicPlaybackManager:FadeOut(duration)
	tweenVolume(self, 0, duration, Enum.EasingDirection.Out)
end

function MusicPlaybackManager:FadeIn(duration)
	tweenVolume(self, self.originalVolume, duration, Enum.EasingDirection.In)
end

function MusicPlaybackManager:Play(remotes, songData, uploaderName, isFromPlaylist)
	if self.endedConnection then
		self.endedConnection:Disconnect()
		self.endedConnection = nil
	end
	self:CancelWatchdog()
	self:CancelFade()

	local musicData = songData.musicData or songData
	local songIdStr = tostring(musicData.id or "")

	if songIdStr ~= "" then
		if bannedSongCache[songIdStr] then
			if self.autoNextCallback then task.defer(self.autoNextCallback) end
			return false, "Song is banned on Roblox"
		end

		local cooldownUntil = temporaryCdnCooldown[songIdStr]
		if cooldownUntil and os.clock() < cooldownUntil then
			if self.autoNextCallback then task.defer(self.autoNextCallback) end
			return false, "Song is in temporary CDN cooldown"
		end
	end

	local baseDuration = songData.Duration or musicData.Duration or self.config.DEFAULT_SONG_DURATION
	-- Baca speed dari field speed (default 1.0).
	local playbackSpeed = math.clamp(
		musicData.PlaybackSpeed or musicData.speed or CONFIG.DEFAULT_PLAYBACK_SPEED,
		0.1,
		2.0
	)

	if baseDuration <= 0 then
		return false, "Invalid song duration"
	end

	local albumName = musicData.album
	if (not albumName or albumName == "") and musicData.id then
		local songObj = MusicModule:GetMusicById(musicData.id)
		if songObj and songObj.album then
			albumName = songObj.album
		end
	end

	local playlistCover = albumName and MusicModule:GetAlbumCover(albumName)
	local coverImage = playlistCover or musicData.sampul or CONFIG.DEFAULT_COVER

	local displayMusicData = {
		id = musicData.id,
		judul = musicData.judul,
		sampul = coverImage,
		album = albumName,
		Duration = baseDuration,
		PlaybackSpeed = playbackSpeed,
	}

	self._playbackGeneration = (self._playbackGeneration or 0) + 1
	local currentGeneration = self._playbackGeneration

	local pitchOctave = musicData.PitchOctave or musicData.pitch or 1.0
	local success = self.audioHandler:Play(musicData.id, 0, playbackSpeed, pitchOctave)

	if not success then
		self:Stop(remotes)
		return false, "Failed to play audio"
	end

	self.currentSong = displayMusicData
	self.currentUploader = uploaderName or "System"
	self.songStartTime = workspace:GetServerTimeNow()
	self.songDuration = baseDuration
	self.adjustedDuration = baseDuration
	self.isPlaylistMode = isFromPlaylist or false
	self.isPlaying = true

	self:ConnectEndedEvent()
	-- Jangan pasang watchdog dengan durasi default 180 detik sebelum
	-- TimeLength diketahui; lagu yang lebih panjang bisa terpotong.
	-- Watchdog dipasang lagi setelah durasi terdeteksi di bawah.
	self:BroadcastSongUpdate(remotes, displayMusicData, uploaderName, self.adjustedDuration, playbackSpeed, false)

	task.spawn(function()
		local detectedDuration = self:TryDetectDuration(musicData.id, playbackSpeed, CONFIG.AUTO_DURATION_TIMEOUT)

		if self._playbackGeneration ~= currentGeneration or not self.currentSong or self.currentSong.id ~= displayMusicData.id then
			return
		end

		local sound = self.audioHandler:GetSound()
		local hasTimeLength = sound and sound.TimeLength > 0
		local isLoaded = sound and sound.IsLoaded
		local hasRealDuration = detectedDuration and detectedDuration > 0
		local hasPositionProgress = sound and sound.TimePosition > 0.2

		if not (hasTimeLength or isLoaded or hasRealDuration or hasPositionProgress) then
			for _ = 1, 2 do
				if self._playbackGeneration ~= currentGeneration then return end
				task.wait(1.0)
				if self._playbackGeneration ~= currentGeneration then return end

				pcall(function()
					sound.SoundId = ""
					task.wait(0.2)
					sound.SoundId = "rbxassetid://" .. tostring(musicData.id)
					sound.PlaybackSpeed = playbackSpeed
					sound:Play()
				end)

				local retryStart = os.clock()
				while (not sound.IsLoaded or sound.TimeLength == 0) and (os.clock() - retryStart) < 4.0 do
					task.wait(0.2)
				end

				hasTimeLength = sound and sound.TimeLength > 0
				isLoaded = sound and sound.IsLoaded
				hasPositionProgress = sound and sound.TimePosition > 0.2
				if hasTimeLength or isLoaded or hasPositionProgress then
					if hasTimeLength then
						detectedDuration = sound.TimeLength / (playbackSpeed > 0 and playbackSpeed or 1)
						hasRealDuration = true
					end
					break
				end
			end
		end

		if hasTimeLength or isLoaded or hasRealDuration or hasPositionProgress then
			self.consecutiveFailures = 0

			if detectedDuration and detectedDuration > 0 then
				self.adjustedDuration = detectedDuration
				self:StartWatchdog(self.adjustedDuration)
				self:BroadcastSongUpdate(remotes, displayMusicData, uploaderName, self.adjustedDuration, playbackSpeed, true)
			end
		else
			local numericId = tonumber(tostring(musicData.id):match("%d+"))
			local isTrulyBanned = false

			if numericId then
				local ok, assetInfo = getCachedAssetInfo(numericId)
				if not ok then
					local errStr = string.lower(tostring(assetInfo))
					if errStr:find("not approved") or errStr:find("forbidden") or errStr:find("403") or errStr:find("404") then
						isTrulyBanned = true
					end
				end
			end

			local failedIdStr = tostring(musicData.id or "")
			if isTrulyBanned then
				if failedIdStr ~= "" then bannedSongCache[failedIdStr] = true end
				warn(string.format("[PlaybackManager] 🚫 Lagu '%s' (ID: %s) diblokir moderasi/hak cipta Roblox.", displayMusicData.judul or "Unknown", tostring(musicData.id)))
			else
				if failedIdStr ~= "" then temporaryCdnCooldown[failedIdStr] = os.clock() + 45 end
				warn(string.format("[PlaybackManager] ⚠️ Lagu '%s' (ID: %s) gagal dimuat dari CDN Roblox.", displayMusicData.judul or "Unknown", tostring(musicData.id)))
			end

			self.consecutiveFailures = (self.consecutiveFailures or 0) + 1

			if self.onSongFailed then
				pcall(self.onSongFailed, displayMusicData.judul or "Unknown", isTrulyBanned and "Song is banned/unauthorized" or "Roblox CDN 502 Bad Gateway")
			end

			self:CancelWatchdog()
			if self.endedConnection then
				self.endedConnection:Disconnect()
				self.endedConnection = nil
			end
			self.isPlaying = false
			self.audioHandler:Stop()

			local backoffDelay = 2.0
			if self.consecutiveFailures == 2 then
				backoffDelay = 3.0
			elseif self.consecutiveFailures >= 3 then
				backoffDelay = 6.0
			end

			if self.autoNextCallback then
				task.wait(backoffDelay)
				if self._playbackGeneration == currentGeneration then
					pcall(self.autoNextCallback)
				end
			end
		end
	end)

	return true, nil
end

function MusicPlaybackManager:Stop(remotes)
	if self.endedConnection then
		self.endedConnection:Disconnect()
		self.endedConnection = nil
	end
	self:CancelWatchdog()
	self:CancelFade()

	self.audioHandler:Stop()

	self.currentSong = nil
	self.currentUploader = nil
	self.isPlaying = false
	self.isPlaylistMode = false

	self:BroadcastStopMusic(remotes)
end

function MusicPlaybackManager:Cleanup()
	if self.endedConnection then
		self.endedConnection:Disconnect()
		self.endedConnection = nil
	end
	self:CancelWatchdog()
	self:CancelFade()
	self.audioHandler:Cleanup()
end

function MusicPlaybackManager:BroadcastStopMusic(remotes)
	pcall(function()
		musicBroadcastBridge:FireAll({
			eventType = "StopMusic",
			data = { IsPlaying = false },
		})
	end)
end

function MusicPlaybackManager:BroadcastSongUpdate(remotes, musicData, uploaderName, duration, playbackSpeed, isCorrection)
	pcall(function()
		musicBroadcastBridge:FireAll({
			eventType = "SongUpdate",
			data = {
				SoundId = musicData.id,
				Title = musicData.judul or "Unknown",
				AlbumCover = musicData.sampul or CONFIG.DEFAULT_COVER,
				AddedBy = uploaderName or "Unknown",
				Duration = duration,
				PlaybackSpeed = playbackSpeed or 1.0,
				IsPlaying = true,
				ServerTime = workspace:GetServerTimeNow(),
				MetadataDuration = musicData.Duration,
				DetectedDuration = duration,
				WasDetected = (musicData.Duration ~= duration),
				IsCorrection = isCorrection or false,
			},
		})
	end)
end

function MusicPlaybackManager:SyncToPlayer(remotes, player)
	if not self.isPlaying or not self.currentSong then return end

	local elapsed = self.audioHandler:GetTimePosition()
	pcall(function()
		remotes.MusicUpdate:FireClient(player, "SyncMusic", {
			SoundId = self.currentSong.id,
			Title = self.currentSong.judul,
			AlbumCover = self.currentSong.sampul or CONFIG.DEFAULT_COVER,
			AddedBy = self.currentUploader,
			TimePosition = elapsed,
			Duration = self.adjustedDuration,
			PlaybackSpeed = self.currentSong.PlaybackSpeed or 1.0,
			IsPlaying = self.isPlaying,
			IsPaused = false,
			ServerTime = self.songStartTime or workspace:GetServerTimeNow(),
		})
	end)
end

function MusicPlaybackManager:SetVolume(volume)
	self.originalVolume = math.clamp(volume, 0, 1)
	self.audioHandler:SetVolume(self.originalVolume)
end

function MusicPlaybackManager:SetPlaybackSpeed(speed)
	self.audioHandler:SetPlaybackSpeed(speed)
end

function MusicPlaybackManager:Reset(remotes)
	self:Stop(remotes)
end

return MusicPlaybackManager
