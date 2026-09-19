local ServerMusicAudioHandler = {}
ServerMusicAudioHandler.__index = ServerMusicAudioHandler

local CONFIG = {
	Audio = {
		DefaultVolume = 0.85,
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
		musicGroup.Volume = 0.85
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
	-- 🎛️ AUDIO ENGINEERING: PREMIUM HI-FI / CLUB SOUND SYSTEM
	-- Filosofi: Bass Empuk & Bulat, Vokal Jernih, Treble Halus Anti-Cempreng, 100% Bebas Clipping
	-- ====================================

	-- 1. HAPUS REVERB & ECHO (Menghilangkan suara kaleng / cempreng / metallic secara total)
	-- Lagu-lagu Roblox sudah memiliki mastering dan reverb studio dari produsernya.
	-- Efek reverb dan delay di master bus hanya merusak fase frekuensi tinggi (comb filtering)
	-- yang menyebabkan suara terdengar cempreng, tipis, dan bergaung seperti di dalam kaleng.
	local oldReverb = existingSound:FindFirstChild("ConcertReverb")
	if oldReverb then
		oldReverb:Destroy()
	end

	local oldEcho = existingSound:FindFirstChild("ConcertEcho")
	if oldEcho then
		oldEcho:Destroy()
	end

	-- 2. EQUALIZER (Warm Bass & Smooth Highs - Anti-Cempreng Tuning)
	-- Bass empuk di low-end, vokal natural jernih di midrange, dan treble dipotong sedikit
	-- agar simbal & vokal sibilance ("s", "c", "t") tidak menusuk telinga.
	local eq = existingSound:FindFirstChild("ConcertEQ")
	if not eq then
		eq = Instance.new("EqualizerSoundEffect")
		eq.Name = "ConcertEQ"
		eq.Parent = existingSound
	end
	eq.Priority = 1
	eq.LowGain  = 3.5   -- Bass +3.5 dB: Dentuman sub-bass & kick empuk, bulat, nendang tapi tidak pecah
	eq.MidGain  = 0.0   -- Mid 0.0 dB: Vokal dan instrumen tetap jernih dan berartikulasi jelas
	eq.HighGain = -1.5  -- High -1.5 dB: Treble roll-off halus. Kunci utama mematikan suara cempreng/tajam!

	-- 3. COMPRESSOR / LIMITER (Transparan, Anti-Clipping & Anti-Pecah)
	-- Mencegah volume lagu yang di-upload terlalu keras agar tidak menabrak 0 dBFS (digital clipping).
	local compressor = existingSound:FindFirstChild("ConcertCompressor")
	if not compressor then
		compressor = Instance.new("CompressorSoundEffect")
		compressor.Name = "ConcertCompressor"
		compressor.Parent = existingSound
	end
	compressor.Priority   = 2
	compressor.Attack     = 0.04  -- Cukup cepat untuk menangkap spike keras, membiarkan transien kick lewat
	compressor.Release    = 0.15  -- Natural recovery, tanpa efek pumping yang mengganggu
	compressor.Ratio      = 2.2   -- Gentle mastering ratio (2.2:1), menjaga dinamika lagu tetap luas & hidup
	compressor.Threshold  = -8.0  -- Ambang batas aman hanya untuk merapikan lagu yang terlalu keras
	compressor.GainMakeup = 0.0   -- 0 dB makeup: MENJAMIN TIDAK ADA DISTORSI PECAH / DIGITAL CLIPPING!

	-- 4. PITCH SHIFT (Koreksi Nada/Vokal saat Speed Diubah)
	local pitchShift = existingSound:FindFirstChild("ConcertPitchShift")
	if not pitchShift then
		pitchShift = Instance.new("PitchShiftSoundEffect")
		pitchShift.Name = "ConcertPitchShift"
		pitchShift.Parent = existingSound
	end
	pitchShift.Priority = 3
	pitchShift.Octave   = 1.0 -- Normal (diatur dinamis oleh playlist saat lagu diputar)

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

	-- Jangan isi SoundId jika sudah sama. Jika beda, matikan yang lama.
	if self.serverSound.SoundId ~= assetId then
		self.serverSound:Stop()
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

	if self.serverSound.SoundId ~= assetId then
		self.serverSound:Stop()
		self.serverSound.SoundId = assetId
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