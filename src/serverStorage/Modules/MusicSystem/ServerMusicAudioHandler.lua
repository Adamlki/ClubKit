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
	-- 🎛️ AUDIO ENGINEERING: CLUB FX CHAIN
	-- Filosofi: Jernih, Keras, Tidak Pecah, Vokal Jelas
	-- ====================================

	-- 1. COMPRESSOR (Perata Volume — Anti Pecah & Anti Pelan)
	-- Menekan bagian yang terlalu keras (anti clipping) dan mengangkat yang pelan.
	local compressor = existingSound:FindFirstChild("ConcertCompressor")
	if not compressor then
		compressor = Instance.new("CompressorSoundEffect")
		compressor.Name = "ConcertCompressor"
		compressor.Parent = existingSound
	end
	compressor.Attack    = 0.05  -- Cukup cepat menangkap hentak bass/snare, tapi tidak membunuh transient
	compressor.Release   = 0.15  -- Pemulihan sedang agar lagu tetap bernapas (tidak gepeng)
	compressor.Ratio     = 4     -- Penekanan 4:1 — standar industri musik untuk mastering
	compressor.Threshold = -15   -- Menangkap puncak suara keras di atas -15 dB
	compressor.GainMakeup = 3    -- Kompensasi +3 dB agar volume rata tanpa pecah

	-- 2. EQUALIZER (Keseimbangan Frekuensi — Anti Mendem)
	-- Bass cukup terasa, vokal jelas, instrumen tinggi berkilau.
	local eq = existingSound:FindFirstChild("ConcertEQ")
	if not eq then
		eq = Instance.new("EqualizerSoundEffect")
		eq.Name = "ConcertEQ"
		eq.Parent = existingSound
	end
	eq.LowGain  = 4   -- Bass +4 dB: cukup nendang tanpa mendem/clipping (sebelumnya +10, terlalu besar)
	eq.MidGain  = 2   -- Mid +2 dB: mengangkat vokal & gitar agar tidak tenggelam oleh bass
	eq.HighGain = 3   -- High +3 dB: menambah kejernihan/presence pada hi-hat, cymbal, vokal atas

	-- 3. REVERB (Nuansa Ruangan Club — Tipis Saja)
	local reverb = existingSound:FindFirstChild("ConcertReverb")
	if not reverb then
		reverb = Instance.new("ReverbSoundEffect")
		reverb.Name = "ConcertReverb"
		reverb.Parent = existingSound
	end
	reverb.DecayTime = 0.8   -- Gema pendek khas club indoor (bukan stadion)
	reverb.Density   = 0.5   -- Kepadatan gema sedang
	reverb.DryLevel  = 0     -- Suara asli utuh (0 dB)
	reverb.WetLevel  = -14   -- Gema sangat halus di background, tidak mengaburkan vokal

	-- 4. ECHO (Pantulan Halus — Hampir Tidak Terasa)
	local echo = existingSound:FindFirstChild("ConcertEcho")
	if not echo then
		echo = Instance.new("EchoSoundEffect")
		echo.Name = "ConcertEcho"
		echo.Parent = existingSound
	end
	echo.Delay    = 0.12  -- Pantulan sangat cepat (slapback khas club)
	echo.Feedback = 0.05  -- Hanya 1 kali pantul, tidak berulang
	echo.DryLevel = 0     -- Suara asli utuh (0 dB)
	echo.WetLevel = -22   -- Sangat tipis, hanya memberi kesan "ruangan hidup"

	-- 5. PITCH SHIFT (Koreksi Vokal saat Speed Diubah)
	local pitchShift = existingSound:FindFirstChild("ConcertPitchShift")
	if not pitchShift then
		pitchShift = Instance.new("PitchShiftSoundEffect")
		pitchShift.Name = "ConcertPitchShift"
		pitchShift.Parent = existingSound
	end
	pitchShift.Octave = 1 -- Normal (diubah otomatis oleh sistem saat PlaybackSpeed berubah)

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
		local startLoad = os.clock()
		while not self.serverSound.IsLoaded and (os.clock() - startLoad) < 5 do
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
		return false
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

		local startTime = os.clock()
		while self.serverSound.TimeLength == 0 and (os.clock() - startTime) < 5 do
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