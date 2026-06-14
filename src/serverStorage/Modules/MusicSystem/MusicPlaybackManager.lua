local TweenService = game:GetService("TweenService")
local ServerMusicAudioHandler = require(script.Parent.ServerMusicAudioHandler)

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
	AUTO_DURATION_TIMEOUT = 6, -- Maximum wait time for duration detection
}

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

	self.audioHandler = ServerMusicAudioHandler.new()

	self.autoNextCallback = nil
	self.endedConnection = nil
	self.progressLoopRunning = false -- Optimized: flag instead of connection
	self.lastProgressBroadcast = 0

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
-- AUTO DURATION DETECTION (FIXED)
-- ====================================
function MusicPlaybackManager:TryDetectDuration(soundId, playbackSpeed)
	local success, detectedDuration = pcall(function()
		local sound = self.audioHandler:GetSound()
		if not sound then return nil end

		local startTime = tick()
		local timeout = CONFIG.AUTO_DURATION_TIMEOUT

		-- Wait for TimeLength to be available
		while sound.TimeLength == 0 and (tick() - startTime) < timeout do
			task.wait(0.1)
		end

		if sound.TimeLength > 0 then
			-- ✅ FIX: sound.TimeLength is ALREADY adjusted by Roblox based on PlaybackSpeed
			return sound.TimeLength
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

	self.endedConnection = sound.Ended:Connect(function()
		if self.autoNextCallback and self.isPlaying then
			task.spawn(function()
				task.wait(1.5)
				pcall(self.autoNextCallback)
			end)
		end
	end)
end

-- ====================================
-- OPTIMIZED: Progress Broadcast with task.wait()
-- More efficient than RunService.Heartbeat
-- ====================================
function MusicPlaybackManager:StartProgressBroadcast(remotes)
	-- Stop any existing loop
	self.progressLoopRunning = false
	task.wait(0.1) -- Wait for previous loop to stop

	self.progressLoopRunning = true

	task.spawn(function()
		while self.progressLoopRunning and self.isPlaying do
			task.wait(CONFIG.PROGRESS_BROADCAST_INTERVAL)

			-- Double check we're still playing
			if self.progressLoopRunning and self.isPlaying then
				self:UpdateProgress(remotes)
			end
		end
	end)
end

function MusicPlaybackManager:StopProgressBroadcast()
	-- Simply set flag to false, loop will stop naturally
	self.progressLoopRunning = false
end

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
-- PLAY METHOD (FIXED - BLOCKING DETECTION)
-- ====================================
function MusicPlaybackManager:Play(remotes, songData, uploaderName, isFromPlaylist)
	-- Cleanup previous playback
	if self.endedConnection then
		self.endedConnection:Disconnect()
		self.endedConnection = nil
	end
	self:StopProgressBroadcast()
	self:CancelFade()

	local musicData = songData.musicData or songData
	local baseDuration = songData.Duration or musicData.Duration or self.config.DEFAULT_SONG_DURATION
	local playbackSpeed = musicData.PlaybackSpeed or CONFIG.DEFAULT_PLAYBACK_SPEED

	if baseDuration <= 0 then
		return false, "Invalid song duration"
	end

	playbackSpeed = math.clamp(playbackSpeed, 0.1, 2.0)

	local coverImage = musicData.sampul
	if isFromPlaylist and (not coverImage or coverImage == "") then
		coverImage = CONFIG.DEFAULT_COVER
	end

	local displayMusicData = {
		id = musicData.id,
		judul = musicData.judul,
		sampul = coverImage,
		album = musicData.album,
		Duration = baseDuration,
		PlaybackSpeed = playbackSpeed
	}

	-- ====================================
	-- 🔥 ARCHITECT FIX 2: THE PERFECT SYNC BUFFER
	-- ====================================
	-- Ambil nilai PitchOctave dari musicData (jika ada)
	local pitchOctave = musicData.PitchOctave or 1.0

	-- 2. TEKAN PLAY SERENTAK dengan parameter tambahan pitchOctave
	local success = self.audioHandler:Play(musicData.id, 0, playbackSpeed, pitchOctave)

	if not success then
		self:Stop(remotes)
		return false, "Failed to play audio"
	end

	-- 3. SETELAH LAGU BENAR-BENAR BUNYI, BARU KITA CATAT WAKTUNYA!
	self.currentSong = displayMusicData
	self.currentUploader = uploaderName or "System"
	self.songStartTime = workspace:GetServerTimeNow() -- Waktu absolut serentak
	self.songDuration = baseDuration
	self.adjustedDuration = baseDuration -- Gunakan base duration dulu agar UI langsung update
	self.isPlaylistMode = isFromPlaylist or false

	-- Success - setup playback instantly!
	self.isPlaying = true

	-- Connect ended event
	self:ConnectEndedEvent()

	-- Start progress broadcast immediately
	self:StartProgressBroadcast(remotes)

	-- 📡 BROADCAST INSTAN: Agar UI pemain langsung ganti tanpa delay (menggunakan durasi sementara)
	self:BroadcastSongUpdate(remotes, displayMusicData, uploaderName, self.adjustedDuration, playbackSpeed)

	-- ⏳ DETEKSI DURASI ASLI DI BACKGROUND: Jangan nge-block script utama
	task.spawn(function()
		local detectedDuration = self:TryDetectDuration(musicData.id, playbackSpeed)
		
		-- 🚨 BATALKAN JIKA LAGU SUDAH BERGANTI
		if not self.currentSong or self.currentSong.id ~= displayMusicData.id then
			return
		end

		local isActuallyPlaying = self.audioHandler:IsPlaying()

		if (detectedDuration and detectedDuration > 0) or isActuallyPlaying then
			if detectedDuration and detectedDuration > 0 then
				self.adjustedDuration = detectedDuration
				debugPrint(string.format("Duration corrected for '%s': %.1fs", displayMusicData.judul, self.adjustedDuration))
				
				-- 📡 BROADCAST KOREKSI: Update durasi yang benar ke UI pemain
				self:BroadcastSongUpdate(remotes, displayMusicData, uploaderName, self.adjustedDuration, playbackSpeed)
			end
		else
			-- 🚨 SISTEM AUTO-SKIP ANTI-BAN BEKERJA!
			debugWarn("LAGU ERROR/BANNED TERDETEKSI! Auto-skipping: " .. (displayMusicData.judul or "Unknown"))
			
			if self.autoNextCallback then
				pcall(self.autoNextCallback)
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
	self:StopProgressBroadcast()
	self:CancelFade()

	self.audioHandler:Stop()

	self.currentSong = nil
	self.currentUploader = nil
	self.isPlaying = false
	self.isPlaylistMode = false
	-- 🔥 ARCHITECT FIX 1: HAPUS BARIS 'self.autoNextCallback = nil' DI SINI! (Ini yang bikin queue stuck)

	self:BroadcastStopMusic(remotes)
end

function MusicPlaybackManager:Cleanup()
	if self.endedConnection then
		self.endedConnection:Disconnect()
		self.endedConnection = nil
	end
	self:StopProgressBroadcast()
	self:CancelFade()
	self.audioHandler:Cleanup()
	-- 🔥 ARCHITECT FIX 1: HAPUS JUGA DI SINI!
end

-- ====================================
-- BROADCAST METHODS (UI ONLY - NO AUDIO SYNC)
-- ====================================

function MusicPlaybackManager:BroadcastStopMusic(remotes)
	pcall(function()
		remotes.MusicBroadcast:FireAllClients("StopMusic", {
			IsPlaying = false
		})
	end)
end

function MusicPlaybackManager:BroadcastSongUpdate(remotes, musicData, uploaderName, duration, playbackSpeed)
	pcall(function()
		remotes.MusicBroadcast:FireAllClients("SongUpdate", {
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
			WasDetected = (musicData.Duration ~= duration) 
		})
	end)
end

function MusicPlaybackManager:UpdateProgress(remotes)
	if not self.isPlaying then return end

	local elapsed = self.audioHandler:GetTimePosition()

	pcall(function()
		remotes.MusicBroadcast:FireAllClients("Progress", {
			Current = elapsed,
			Duration = self.adjustedDuration,
			IsPlaying = true,

			-- 🔥 FIX: Samakan dengan ServerTime Absolut
			ServerTime = workspace:GetServerTimeNow()
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