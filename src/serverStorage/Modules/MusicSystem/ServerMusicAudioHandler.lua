local ServerMusicAudioHandler = {}
ServerMusicAudioHandler.__index = ServerMusicAudioHandler

local CONFIG = {
	Audio = {
		DefaultVolume = 1,
		DefaultPlaybackSpeed = 1.0
	}
}

-- ====================================
-- OPTIMIZED: Removed MIRROR SOUND
-- Mirror sound was not being used (no PlaybackLoudness detection)
-- This saves memory by not creating duplicate sound objects
-- ====================================

function ServerMusicAudioHandler.new()
	local self = setmetatable({}, ServerMusicAudioHandler)

	self.serverSound  = nil
	-- OPTIMIZED: Removed mirrorSound - was not being used
	self.musicGroup   = nil
	self.currentSoundId = nil
	self.isPlaying    = false
	self.isPaused     = false

	-- Setup proper order
	self:CreateMusicGroup()
	self:CreateServerSound()

	return self
end

function ServerMusicAudioHandler:CreateMusicGroup()
	local soundService = game:GetService("SoundService")

	-- Create or get MusicGroup
	local musicGroup = soundService:FindFirstChild("MusicGroup")
	if not musicGroup then
		musicGroup = Instance.new("SoundGroup")
		musicGroup.Name = "MusicGroup"
		musicGroup.Parent = soundService
		musicGroup.Volume = 1
	end
	self.musicGroup = musicGroup

	return musicGroup
end

function ServerMusicAudioHandler:CreateServerSound()
	-- Ensure MusicGroup exists
	if not self.musicGroup then
		self:CreateMusicGroup()
	end

	local soundService = game:GetService("SoundService")

	-- Check existing sound
	local existingSound = soundService:FindFirstChild("ServerMusicSound")
	if not existingSound or not existingSound:IsA("Sound") then
		-- Create new sound if it doesn't exist
		existingSound = Instance.new("Sound")
		existingSound.Name = "ServerMusicSound"
		existingSound.Volume = CONFIG.Audio.DefaultVolume
		existingSound.Looped = false
		existingSound.PlaybackSpeed = CONFIG.Audio.DefaultPlaybackSpeed
		existingSound.Parent = soundService
	end

	-- Ensure connected to SoundGroup
	existingSound.SoundGroup = self.musicGroup
	self.serverSound = existingSound

	-- ====================================
	-- 🎛️ AUDIO ENGINEERING: CONCERT FX CHAIN
	-- ====================================

	-- 1. COMPRESSOR (Loudness Normalization / Perata Volume)
	-- Ini akan menekan lagu yang terlalu berisik dan mengangkat lagu yang pelan.
	local compressor = existingSound:FindFirstChild("ConcertCompressor")
	if not compressor then
		compressor = Instance.new("CompressorSoundEffect")
		compressor.Name = "ConcertCompressor"
		compressor.Attack = 0.01      -- Bereaksi instan saat ada suara menghentak
		compressor.Release = 0.15     -- Waktu pemulihan standar
		compressor.Ratio = 4          -- Skala penekanan 4:1
		compressor.Threshold = -8     -- Menangkap puncak (peak) suara keras agar tidak clip
		compressor.GainMakeup = 0     -- DITURUNKAN: +5dB bikin snare/gitar pecah (clipping), 0 lebih natural
		compressor.Parent = existingSound
	end

	-- 2. EQUALIZER (Concert Acoustics / Bass Boost)
	local eq = existingSound:FindFirstChild("ConcertEQ")
	if not eq then
		eq = Instance.new("EqualizerSoundEffect")
		eq.Name = "ConcertEQ"
		eq.LowGain = 10    -- DITURUNKAN: Bass +12 dB terlalu besar & bikin pecah/clipping saat lagu dilambatkan (+4 dB aman)
		eq.MidGain = -5    -- Dinormalkan ke 0 dB agar gitar tidak mendem/pecah
		eq.HighGain = 1   -- DITURUNKAN: High +5 dB terlalu tajam, bikin snare/cymbal pecah (+1 dB lebih aman)
		eq.Parent = existingSound
	end

	-- 3. REVERB (Stadium Ambience / Gema Ruangan)
	local reverb = existingSound:FindFirstChild("ConcertReverb")
	if not reverb then
		reverb = Instance.new("ReverbSoundEffect")
		reverb.Name = "ConcertReverb"
		reverb.DecayTime = 2.5   -- Durasi gema layaknya stadion besar
		reverb.Density = 0.8     -- Kepadatan gema
		reverb.DryLevel = 0      -- Volume asli tidak disentuh (0 dB)
		reverb.WetLevel = -12    -- Volume gema diatur agak pelan agar lagu tetap jelas (-12 dB)
		reverb.Parent = existingSound
	end

	-- 4. ECHO (Slapback / Pantulan Suara Panggung)
	local echo = existingSound:FindFirstChild("ConcertEcho")
	if not echo then
		echo = Instance.new("EchoSoundEffect")
		echo.Name = "ConcertEcho"
		echo.Delay = 0.15    -- Pantulan terjadi sangat cepat setelah suara asli
		echo.Feedback = 0.1      -- Tidak memantul berkali-kali (hanya 1-2 kali)
		echo.DryLevel = 0        -- Volume asli aman (0 dB)
		echo.WetLevel = -18      -- Pantulan bersembunyi tipis di background (-18 dB)
		echo.Parent = existingSound
	end
	
	-- 5. PITCH SHIFT (Anti-Pecah & Koreksi Vokal)
	local pitchShift = existingSound:FindFirstChild("ConcertPitchShift")
	if not pitchShift then
		pitchShift = Instance.new("PitchShiftSoundEffect")
		pitchShift.Name = "ConcertPitchShift"
		pitchShift.Octave = 1 -- Default normal
		pitchShift.Parent = existingSound
	end

	return existingSound
end

-- ====================================
-- THE AAA NETWORK BUFFER (PRELOAD)
-- ====================================
function ServerMusicAudioHandler:Preload(soundId)
	if not self.serverSound or not self.serverSound.Parent then
		self:CreateServerSound()
	end

	local assetId = "rbxassetid://" .. soundId

	-- 🔥 ARCHITECT FIX 3: ANTI-STUTTERING
	-- Jangan isi SoundId jika sudah sama. Jika beda, matikan yang lama.
	if self.serverSound.SoundId ~= assetId then
		self.serverSound:Stop()
		self.serverSound.SoundId = ""
		task.wait()
		self.serverSound.SoundId = assetId
	end
end


-- ====================================
-- OPTIMIZED: Removed CreateMirrorSound and GetMirrorSound
-- These were not being used and wasted memory
-- ====================================

-- ====================================
-- AUTO DETECT SONG TITLE FROM SOUND
-- ====================================
function ServerMusicAudioHandler:TryDetectSongTitle()
	local success, title = pcall(function()
		if not self.serverSound then return nil end

		task.wait(0.5)

		local soundName = self.serverSound.Name
		if soundName and soundName ~= "ServerMusicSound" and soundName ~= "" then
			return soundName
		end

		return nil
	end)

	if success and title and title ~= "" then
		return title
	end

	return nil
end

-- ====================================
-- PLAYBACK WITH SPEED SUPPORT
-- ====================================
-- Tambahkan parameter 'pitchOctave' di ujungnya
function ServerMusicAudioHandler:Play(soundId, timePosition, playbackSpeed, pitchOctave)
	if not self.serverSound or not self.serverSound.Parent then
		self:CreateServerSound()
	end

	local assetId = "rbxassetid://" .. soundId

	-- ARCHITECT FIX 4: SMART LOADING WITH RETRY (Anti HTTP 502)
	local maxRetries = 3
	local isLoaded = false

	for attempt = 1, maxRetries do
		if self.serverSound.SoundId ~= assetId then
			self.serverSound:Stop()
			self.serverSound.SoundId = ""
			task.wait(0.1) -- Jeda sebentar untuk mereset cache jaringan
			self.serverSound.SoundId = assetId
		end

		-- Tunggu engine Roblox selesai mendownload lagu sebelum lanjut (Max 5 detik per percobaan)
		local startLoad = tick()
		while not self.serverSound.IsLoaded and (tick() - startLoad) < 5 do
			task.wait(0.1)
		end

		if self.serverSound.IsLoaded then
			isLoaded = true
			break
		else
			warn(string.format("[ServerAudio] Gagal memuat lagu %s (Attempt %d/%d). Mencoba ulang...", soundId, attempt, maxRetries))
			-- Kosongkan SoundId agar di loop berikutnya dipaksa unduh ulang
			self.serverSound.SoundId = ""
		end
	end

	if not isLoaded then
		warn("[ServerAudio] Gagal total memuat lagu setelah 3 kali percobaan: " .. soundId)
	end

	-- Atur Waktu dan Kecepatan
	self.serverSound.TimePosition = timePosition or 0
	self.serverSound.PlaybackSpeed = playbackSpeed or CONFIG.Audio.DefaultPlaybackSpeed

	-- Atur PitchShift (Koreksi Vokal)
	local pitchShift = self.serverSound:FindFirstChild("ConcertPitchShift")
	if pitchShift then
		-- Gunakan pitchOctave dari module, atau 1.0 (normal) jika tidak disetting
		pitchShift.Octave = pitchOctave or 1.0 
	end

	local success = pcall(function()
		self.serverSound:Play()
	end)

	if success then
		self.currentSoundId = soundId
		self.isPlaying = true
		self.isPaused = false
		return true
	else
		warn("[ServerAudio] Failed to play:", soundId)
		return false
	end
end

function ServerMusicAudioHandler:Stop()
	if not self.serverSound then return end

	pcall(function()
		self.serverSound:Stop()
	end)

	-- OPTIMIZED: Removed mirror sound stop

	self.isPlaying = false
	self.isPaused = false
	self.currentSoundId = nil
end

function ServerMusicAudioHandler:Pause()
	if not self.serverSound then return end

	pcall(function()
		self.serverSound:Pause()
	end)

	-- OPTIMIZED: Removed mirror sound pause

	self.isPaused = true
end

function ServerMusicAudioHandler:Resume()
	if not self.serverSound then return end

	pcall(function()
		self.serverSound:Resume()
	end)

	-- OPTIMIZED: Removed mirror sound resume

	self.isPaused = false
end

-- ====================================
-- RELOAD AUDIO (FOR RETRY)
-- ====================================
function ServerMusicAudioHandler:Reload()
	if not self.serverSound or not self.currentSoundId then
		return false
	end

	local currentTimePosition = self.serverSound.TimePosition
	local currentPlaybackSpeed = self.serverSound.PlaybackSpeed
	local wasPlaying = self.isPlaying

	pcall(function()
		self.serverSound:Stop()
	end)

	task.wait(0.2)

	local assetId = "rbxassetid://" .. self.currentSoundId

	pcall(function()
		self.serverSound.SoundId = ""
		task.wait(0.1)
		self.serverSound.SoundId = assetId
		self.serverSound.PlaybackSpeed = currentPlaybackSpeed

		-- Ensure still connected
		if self.serverSound.SoundGroup ~= self.musicGroup then
			self.serverSound.SoundGroup = self.musicGroup
		end

		local startTime = tick()
		while self.serverSound.TimeLength == 0 and (tick() - startTime) < 5 do
			task.wait(0.1)
		end

		if wasPlaying then
			self.serverSound.TimePosition = currentTimePosition
			self.serverSound:Play()
			self.isPlaying = true

			-- OPTIMIZED: Removed mirror sound sync
		end
	end)

	return true
end

-- ====================================
-- VOLUME & SPEED CONTROL
-- ====================================
function ServerMusicAudioHandler:SetVolume(volume)
	if not self.serverSound then return end
	volume = math.clamp(volume, 0, 1)
	self.serverSound.Volume = volume
end

function ServerMusicAudioHandler:GetVolume()
	if not self.serverSound then return CONFIG.Audio.DefaultVolume end
	return self.serverSound.Volume
end

function ServerMusicAudioHandler:SetPlaybackSpeed(speed)
	if not self.serverSound then return end
	speed = math.clamp(speed, 0.1, 10)
	self.serverSound.PlaybackSpeed = speed
end

function ServerMusicAudioHandler:GetPlaybackSpeed()
	if not self.serverSound then return CONFIG.Audio.DefaultPlaybackSpeed end
	return self.serverSound.PlaybackSpeed
end

-- ====================================
-- STATE GETTERS
-- ====================================
function ServerMusicAudioHandler:IsPlaying()
	return self.isPlaying and self.serverSound and self.serverSound.IsPlaying
end

function ServerMusicAudioHandler:IsPaused()
	return self.isPaused
end

function ServerMusicAudioHandler:GetTimePosition()
	if not self.serverSound then return 0 end
	return self.serverSound.TimePosition
end

function ServerMusicAudioHandler:GetTimeLength()
	if not self.serverSound then return 0 end
	return self.serverSound.TimeLength
end

function ServerMusicAudioHandler:GetCurrentSoundId()
	return self.currentSoundId
end

function ServerMusicAudioHandler:GetSound()
	return self.serverSound
end

-- ====================================
-- CLEANUP
-- ====================================
function ServerMusicAudioHandler:Cleanup()
	if self.serverSound then
		pcall(function()
			self.serverSound:Stop()
			self.serverSound:Destroy()
		end)
		self.serverSound = nil
	end

	-- OPTIMIZED: Removed mirror sound cleanup
end

return ServerMusicAudioHandler