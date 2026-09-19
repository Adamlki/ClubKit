local TweenService = game:GetService("TweenService")
local ServerMusicAudioHandler = require(script.Parent.ServerMusicAudioHandler)
local BridgeNet = require(game:GetService("ReplicatedStorage"):WaitForChild("BridgeNet"))
local MusicModule = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("MusicModule"))
local musicBroadcastBridge = BridgeNet.CreateBridge("MusicBroadcast")

local MusicPlaybackManager = {}
MusicPlaybackManager.__index = MusicPlaybackManager

-- ====================================
-- CONFIG & DEBUG SETTINGS
-- ====================================
local DEBUG_ENABLED = false -- Ubah ke 'true' untuk melihat log durasi & error, 'false' saat rilis
local DEBUG_PREFIX = "[PlaybackManager]"

local function debugPrint(...)
	if DEBUG_ENABLED then print(DEBUG_PREFIX, ...) end
end

local function debugWarn(...)
	if DEBUG_ENABLED then warn(DEBUG_PREFIX, ...) end
end

local CONFIG = {
	PROGRESS_BROADCAST_INTERVAL = 2, -- Optimized: 2 seconds instead of 1
	DEFAULT_COVER = "rbxassetid://88574818940840",
	DEFAULT_PLAYBACK_SPEED = 1.0,
	AUTO_DURATION_TIMEOUT = 12, -- Waktu aman 12 detik agar audio buffer tanpa false-positive skip
}

-- 🛑 SESSION BLACKLIST: Menyimpan ID lagu yang gagal dimuat (502 / Banned)
-- agar saat playlist berputar ulang, server langsung skip tanpa delay atau spam CDN
local failedSongCache = {}

function MusicPlaybackManager.new(config)
	local self = setmetatable({}, MusicPlaybackManager)

	self.config = config
	self.currentSong = nil
	self.currentUploader = nil
	self.isPlaying = false
	self.songStartTime = 0
	self.songDuration = 0
	self.adjustedDuration = 0 -- Duration adjusted for playback speed
	self.isPlaylistMode = false
	self.consecutiveFailures = 0 -- Circuit breaker counter

	self.audioHandler = ServerMusicAudioHandler.new()

	self.autoNextCallback = nil
	self.onSongFailed = nil -- Callback jika lagu error/rusak untuk notifikasi
	self.endedConnection = nil
	self.watchdogThread = nil
	self._playbackGeneration = 0

	self.volumeTween = nil
	self.originalVolume = 0.5

	return self
end

-- ====================================
-- STATE GETTERS
-- ====================================
function MusicPlaybackManager:GetState()
	return {
		currentSong = self.currentSong,
		currentUploader = self.currentUploader,
		isPlaying = self.isPlaying,
		isPaused = false,
		startTime = self.songStartTime,
		duration = self.adjustedDuration, -- Return adjusted duration
		isPlaylistMode = self.isPlaylistMode,
		elapsedTime = self:GetElapsedTime()
	}
end

function MusicPlaybackManager:IsPlaying()
	return self.isPlaying and self.audioHandler:IsPlaying()
end

function MusicPlaybackManager:GetCurrentSong()
	return self.currentSong
end

function MusicPlaybackManager:GetElapsedTime()
	if self.isPlaying then
		return self.audioHandler:GetTimePosition()
	end
	return 0
end

function MusicPlaybackManager:GetRemainingTime()
	if not self.isPlaying then return 0 end
	local elapsed = self:GetElapsedTime()
	return math.max(0, self.adjustedDuration - elapsed)
end

function MusicPlaybackManager:IsFromPlaylist()
	return self.isPlaylistMode
end

-- ====================================
-- WATCHDOG SYSTEM (ANTI-STUCK / FALLBACK TIMER)
-- Menjamin server otomatis lanjut ke lagu berikutnya jika sound.Ended gagal terpanggil
-- ====================================
function MusicPlaybackManager:StartWatchdog(duration)
	self:CancelWatchdog()

	local songGeneration = self._playbackGeneration
	local currentSongId = self.currentSong and self.currentSong.id
	local timeout = (duration or self.adjustedDuration or 180) + 2

	self.watchdogThread = task.delay(timeout, function()
		if self._playbackGeneration == songGeneration and self.isPlaying and self.currentSong and self.currentSong.id == currentSongId then
			debugWarn("⏱️ Watchdog Timer: Durasi habis tanpa event Ended! Auto-skipping lagu:", self.currentSong.judul or "Unknown")
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

-- ====================================
-- AUTO DURATION DETECTION (FAST & NON-BLOCKING)
-- ====================================
function MusicPlaybackManager:TryDetectDuration(soundId, playbackSpeed, customTimeout)
	local timeout = customTimeout or CONFIG.AUTO_DURATION_TIMEOUT
	local success, detectedDuration = pcall(function()
		local sound = self.audioHandler:GetSound()
		if not sound then return nil end

		local startTime = os.clock()

		-- Wait for TimeLength or IsLoaded to be available
		while sound.TimeLength == 0 and not sound.IsLoaded and (os.clock() - startTime) < timeout do
			task.wait(0.1)
		end

		if sound.TimeLength > 0 then
			-- ✅ FIX: Convert to real-life duration by dividing by PlaybackSpeed
			local speed = playbackSpeed or 1
			if speed <= 0 then speed = 1 end
			return sound.TimeLength / speed
		end

		return nil
	end)

	if success and detectedDuration and detectedDuration > 0 then
		return detectedDuration
	end

	return nil
end

-- ====================================
-- EVENT CONNECTIONS
-- ====================================
function MusicPlaybackManager:ConnectEndedEvent()
	if self.endedConnection then
		self.endedConnection:Disconnect()
		self.endedConnection = nil
	end

	local sound = self.audioHandler:GetSound()
	if not sound then 
		debugWarn("No sound object to connect Ended event")
		return 
	end

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

-- ====================================
-- PROGRESS BROADCAST DELETED
-- ====================================

-- ====================================
-- FADE EFFECTS
-- ====================================
function MusicPlaybackManager:CancelFade()
	if self.volumeTween then
		self.volumeTween:Cancel()
		self.volumeTween = nil
	end
end

function MusicPlaybackManager:FadeOut(duration)
	self:CancelFade()

	local sound = self.audioHandler:GetSound()
	if not sound or not sound.IsPlaying then
		return
	end

	local tweenInfo = TweenInfo.new(
		duration,
		Enum.EasingStyle.Linear,
		Enum.EasingDirection.Out
	)

	self.volumeTween = TweenService:Create(sound, tweenInfo, {
		Volume = 0
	})

	self.volumeTween:Play()

	self.volumeTween.Completed:Connect(function()
		self.volumeTween = nil
	end)
end

function MusicPlaybackManager:FadeIn(duration)
	self:CancelFade()

	local sound = self.audioHandler:GetSound()
	if not sound or not sound.IsPlaying then
		return
	end

	sound.Volume = 0

	local tweenInfo = TweenInfo.new(
		duration,
		Enum.EasingStyle.Linear,
		Enum.EasingDirection.In
	)

	self.volumeTween = TweenService:Create(sound, tweenInfo, {
		Volume = self.originalVolume
	})

	self.volumeTween:Play()

	self.volumeTween.Completed:Connect(function()
		self.volumeTween = nil
	end)
end

-- ====================================
-- PLAY METHOD (FAST VALIDATION + WATCHDOG)
-- ====================================
function MusicPlaybackManager:Play(remotes, songData, uploaderName, isFromPlaylist)
	-- Cleanup previous playback
	if self.endedConnection then
		self.endedConnection:Disconnect()
		self.endedConnection = nil
	end
	self:CancelWatchdog()
	self:CancelFade()

	local musicData = songData.musicData or songData
	local songIdStr = tostring(musicData.id or "")

	-- 🛑 CEK SESSION BLACKLIST: Lewati langsung jika sudah diketahui rusak/banned
	if songIdStr ~= "" and failedSongCache[songIdStr] then
		debugWarn("⚠️ [PlaybackManager] Melewati lagu blacklisted (Error/502):", musicData.judul or songIdStr)
		if self.autoNextCallback then
			task.defer(self.autoNextCallback)
		end
		return false, "Song is blacklisted in this session"
	end

	local baseDuration = songData.Duration or musicData.Duration or self.config.DEFAULT_SONG_DURATION
	local playbackSpeed = musicData.PlaybackSpeed or CONFIG.DEFAULT_PLAYBACK_SPEED

	if baseDuration <= 0 then
		return false, "Invalid song duration"
	end

	playbackSpeed = math.clamp(playbackSpeed, 0.1, 2.0)

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
		PlaybackSpeed = playbackSpeed
	}

	-- Increment playback generation to discard stale callbacks
	self._playbackGeneration = (self._playbackGeneration or 0) + 1
	local currentGeneration = self._playbackGeneration

	-- PitchOctave parameter
	local pitchOctave = musicData.PitchOctave or 1.0

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

	-- Connect ended event & start watchdog timer
	self:ConnectEndedEvent()
	self:StartWatchdog(self.adjustedDuration)

	-- Broadcast initial song update to clients
	self:BroadcastSongUpdate(remotes, displayMusicData, uploaderName, self.adjustedDuration, playbackSpeed, false)

	-- ⏳ DETEKSI DURASI & VALIDASI LAGU DI BACKGROUND (DENGAN CIRCUIT BREAKER & ANTI FALSE-POSITIVE)
	task.spawn(function()
		local detectedDuration = self:TryDetectDuration(musicData.id, playbackSpeed, CONFIG.AUTO_DURATION_TIMEOUT)
		
		-- 🚨 BATALKAN JIKA LAGU SUDAH BERGANTI
		if self._playbackGeneration ~= currentGeneration or not self.currentSong or self.currentSong.id ~= displayMusicData.id then
			return
		end

		local sound = self.audioHandler:GetSound()
		local hasTimeLength = sound and sound.TimeLength > 0
		local isLoaded = sound and sound.IsLoaded
		local isActivelyPlaying = sound and (sound.TimePosition > 0 or sound.IsPlaying)

		-- Lagu valid jika memiliki TimeLength, IsLoaded, durasi terdeteksi, ATAU sedang aktif memutar audio
		if hasTimeLength or isLoaded or (detectedDuration and detectedDuration > 0) or isActivelyPlaying then
			self.consecutiveFailures = 0 -- Reset counter kegagalan karena lagu valid

			if detectedDuration and detectedDuration > 0 then
				self.adjustedDuration = detectedDuration
				-- Perbarui Watchdog timer dengan durasi yang akurat
				self:StartWatchdog(self.adjustedDuration)
				debugPrint(string.format("Duration corrected for '%s': %.1fs", displayMusicData.judul, self.adjustedDuration))
				
				-- Broadcast durasi yang benar ke UI
				self:BroadcastSongUpdate(remotes, displayMusicData, uploaderName, self.adjustedDuration, playbackSpeed, true)
			end
		else
			-- 🚨 SISTEM AUTO-SKIP: LAGU ERROR / BANNED / HTTP 502 TERDETEKSI!
			local failedIdStr = tostring(musicData.id or "")
			if failedIdStr ~= "" then
				failedSongCache[failedIdStr] = true -- Tandai ke session blacklist
			end

			self.consecutiveFailures = (self.consecutiveFailures or 0) + 1
			warn(string.format("[PlaybackManager] ⚠️ Lagu '%s' (ID: %s) tidak dapat dimuat (Error/Banned/HTTP 502). Kegagalan berturut-turut: %d. Melewati ke lagu berikutnya...", 
				displayMusicData.judul or "Unknown", tostring(musicData.id), self.consecutiveFailures))
			
			if self.onSongFailed then
				pcall(self.onSongFailed, displayMusicData.judul or "Unknown", "Song unplayable or banned")
			end

			-- Hentikan audio yang rusak dan bersihkan status
			self:CancelWatchdog()
			if self.endedConnection then
				self.endedConnection:Disconnect()
				self.endedConnection = nil
			end
			self.isPlaying = false
			self.audioHandler:Stop()

			-- 🛑 CIRCUIT BREAKER & COOLDOWN ADAPTIF:
			-- Mencegah banjir request ke CDN Roblox yang menyebabkan HTTP 502 Bad Gateway
			local backoffDelay = 2.0
			if self.consecutiveFailures == 2 then
				backoffDelay = 3.0
			elseif self.consecutiveFailures >= 3 then
				backoffDelay = 6.0
				warn("[PlaybackManager] 🛑 Circuit Breaker aktif: Cooldown 6 detik untuk CDN Roblox...")
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

-- ====================================
-- STOP METHOD
-- ====================================
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

-- ====================================
-- BROADCAST METHODS (UI ONLY - NO AUDIO SYNC)
-- ====================================

function MusicPlaybackManager:BroadcastStopMusic(remotes)
	pcall(function()
		musicBroadcastBridge:FireAll({
			eventType = "StopMusic",
			data = { IsPlaying = false }
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

				-- 🔥 FIX: Gunakan Waktu Absolut Server, BUKAN tick() lokal!
				ServerTime = workspace:GetServerTimeNow(), 

				MetadataDuration = musicData.Duration, 
				DetectedDuration = duration, 
				WasDetected = (musicData.Duration ~= duration),
				IsCorrection = isCorrection or false
			}
		})
	end)
end



function MusicPlaybackManager:SyncToPlayer(remotes, player)
	if not self.isPlaying or not self.currentSong then
		return
	end

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
			IsPaused = false
		})
	end)
end

-- ====================================
-- VOLUME & SPEED CONTROL
-- ====================================
function MusicPlaybackManager:SetVolume(volume)
	self.originalVolume = math.clamp(volume, 0, 1)
	self.audioHandler:SetVolume(self.originalVolume)
end

function MusicPlaybackManager:SetPlaybackSpeed(speed)
	self.audioHandler:SetPlaybackSpeed(speed)
end

-- ====================================
-- CLEANUP
-- ====================================
function MusicPlaybackManager:Reset(remotes)
	self:Stop(remotes)
end

return MusicPlaybackManager