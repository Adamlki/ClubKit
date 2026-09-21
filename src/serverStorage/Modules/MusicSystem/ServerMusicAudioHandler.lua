local ServerMusicAudioHandler = {}
ServerMusicAudioHandler.__index = ServerMusicAudioHandler

local CONFIG = {
	Audio = {
		DefaultVolume = 0.60, -- Headroom aman (~ -4.4 dB) agar lagu keras tidak pernah menyentuh digital clipping / keprek
		DefaultPlaybackSpeed = 1.0
	},
	-- 🎧 ROBLOX CLUB MASTER AUDIO SYSTEM
	-- Standar sound system club/nightclub: bass empuk nendang, snare lembut anti-cempreng,
	-- compressor peak limiter anti-pecah/keprek, dan akustik ruang club yang megah.
	ClubAudio = {
		EQ = {
			LowGain  = 4.0,   -- +4.0 dB: Dentuman bass & sub-kick club bulat, padat, berbobot, dan hangat
			MidGain  = -4.0,  -- -4.0 dB: [ANTI-CEMPRENG] Cut frekuensi 1.5 - 4 kHz agar snare & clap empuk, tidak menusuk telinga
			HighGain = -15,  -- -4.5 dB: [ANTI-DESIS RESAMPLING] Cut frekuensi tinggi untuk meredam kresek & artefak tajam saat PlaybackSpeed dinaikkan (0.43x -> normal)
			Priority = 1,
		},
		Compressor = {
			Threshold  = -12.5, -- -12.5 dB: Menangkap lonjakan suara lebih awal sebelum menyentuh batas digital
			Ratio      = 7.0,   -- 7:1 [ANTI-PECAH & ANTI-KEPREK] Menjinakkan hentakan drum/bass keras agar tidak pernah digital clipping
			Attack     = 0.015, -- 15 ms: Reaksi ultra-cepat meredam pukulan tajam tanpa mematikan ketukan lagu
			Release    = 0.14,  -- 140 ms: Pelepasan alami dan halus tanpa efek suara kembang-kempis (pumping)
			GainMakeup = 0.0,   -- 0 dB: Menjaga sinyal audio selalu berada di bawah batas 0 dBFS
			Priority   = 2,
		},
		Reverb = {
			DecayTime = 1.6,    -- 1.6 detik: Akustik ruangan hall club yang megah dan luas
			Density   = 0.85,   -- Pantulan suara rapat, tebal, dan hangat
			Diffusion = 0.92,   -- Sebaran pantulan sangat halus merata tanpa efek gema berulang/echo kaleng
			DryLevel  = 0.0,    -- 0 dB: Vokal & musik asli tetap 100% jernih dan tegas di depan
			WetLevel  = -11.5,  -- -11.5 dB: Nuansa akustik ruang club terdengar nyata dan mewah membungkus lagu
			Priority  = 3,
		}
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

	-- 1. Matikan AmbientReverb global agar map outdoor tidak bergema/gema kaleng
	soundService.AmbientReverb = Enum.ReverbType.NoReverb

	-- Create or get MusicGroup
	local musicGroup = soundService:FindFirstChild("MusicGroup")
	if not musicGroup then
		musicGroup = Instance.new("SoundGroup")
		musicGroup.Name = "MusicGroup"
		musicGroup.Parent = soundService
		musicGroup.Volume = 0.85
	end

	-- Bersihkan efek distorsi/echo lama jika ada
	for _, child in ipairs(musicGroup:GetChildren()) do
		if child:IsA("EchoSoundEffect") or child:IsA("DistortionSoundEffect") or child:IsA("ChorusSoundEffect") or child:IsA("FlangeSoundEffect") then
			child:Destroy()
		end
	end

	-- =========================================================================
	-- 🎛️ EFEK MASTER CLUB AUDIO (ROBLOX NIGHTCLUB SOUND SYSTEM PRESET)
	-- Mengatasi:
	-- 1. Snare "Cempreng" -> Dipangkas lewat ClubEQ (MidGain -3.5 dB & HighGain -3.5 dB)
	-- 2. Suara Keras "Pecah / Keprek" -> Diredam lewat ClubCompressor (Peak Limiter)
	-- 3. Suara Kering/Kaku -> Dihaluskan lewat ClubReverb (Ambience Hall VIP Club)
	-- =========================================================================

	-- 1. CLUB EQUALIZER (V-Curve Tone: Bass Bulat Nendang, Snare Empuk Anti-Cempreng)
	local eq = musicGroup:FindFirstChild("ClubEQ")
	if not eq or not eq:IsA("EqualizerSoundEffect") then
		if eq then eq:Destroy() end
		eq = Instance.new("EqualizerSoundEffect")
		eq.Name = "ClubEQ"
		eq.Parent = musicGroup
	end
	eq.Priority = CONFIG.ClubAudio.EQ.Priority
	eq.LowGain  = CONFIG.ClubAudio.EQ.LowGain
	eq.MidGain  = CONFIG.ClubAudio.EQ.MidGain
	eq.HighGain = CONFIG.ClubAudio.EQ.HighGain
	eq.Enabled  = true

	-- 2. CLUB COMPRESSOR / PEAK TAMER (Anti-Pecah & Anti-Keprek saat Snare/Kick Keras)
	local comp = musicGroup:FindFirstChild("ClubCompressor")
	if not comp or not comp:IsA("CompressorSoundEffect") then
		if comp then comp:Destroy() end
		comp = Instance.new("CompressorSoundEffect")
		comp.Name = "ClubCompressor"
		comp.Parent = musicGroup
	end
	comp.Priority   = CONFIG.ClubAudio.Compressor.Priority
	comp.Threshold  = CONFIG.ClubAudio.Compressor.Threshold
	comp.Ratio      = CONFIG.ClubAudio.Compressor.Ratio
	comp.Attack     = CONFIG.ClubAudio.Compressor.Attack
	comp.Release    = CONFIG.ClubAudio.Compressor.Release
	comp.GainMakeup = CONFIG.ClubAudio.Compressor.GainMakeup
	comp.Enabled    = true

	-- 3. CLUB REVERB (Atmosfer Ruang Club Mewah & Menghaluskan Transien Snare)
	local reverb = musicGroup:FindFirstChild("ClubReverb")
	if not reverb or not reverb:IsA("ReverbSoundEffect") then
		if reverb then reverb:Destroy() end
		reverb = Instance.new("ReverbSoundEffect")
		reverb.Name = "ClubReverb"
		reverb.Parent = musicGroup
	end
	reverb.Priority  = CONFIG.ClubAudio.Reverb.Priority
	reverb.DecayTime = CONFIG.ClubAudio.Reverb.DecayTime
	reverb.Density   = CONFIG.ClubAudio.Reverb.Density
	reverb.Diffusion = CONFIG.ClubAudio.Reverb.Diffusion
	reverb.DryLevel  = CONFIG.ClubAudio.Reverb.DryLevel
	reverb.WetLevel  = CONFIG.ClubAudio.Reverb.WetLevel
	reverb.Enabled   = true

	self.musicGroup = musicGroup

	return musicGroup
end

function ServerMusicAudioHandler:CreateServerSound()
	-- Ensure MusicGroup exists
	if not self.musicGroup then
		self:CreateMusicGroup()
	end

	local soundService = game:GetService("SoundService")

	-- Pastikan AmbientReverb SoundService selalu NoReverb (Map Outdoor)
	soundService.AmbientReverb = Enum.ReverbType.NoReverb

	-- Check existing sound
	local existingSound = soundService:FindFirstChild("ServerMusicSound")
	if not existingSound or not existingSound:IsA("Sound") then
		-- Create new sound if it doesn't exist
		existingSound = Instance.new("Sound")
		existingSound.Name = "ServerMusicSound"
		existingSound.Looped = false
		existingSound.PlaybackSpeed = CONFIG.Audio.DefaultPlaybackSpeed
		existingSound.Parent = soundService
	end

	-- Pastikan Volume & SoundGroup selalu terkonfigurasi dengan headroom aman
	existingSound.Volume = CONFIG.Audio.DefaultVolume
	existingSound.SoundGroup = self.musicGroup
	self.serverSound = existingSound

	-- Bersihkan efek-efek lokal di Sound agar pemrosesan terpusat bersih & rapi di MusicGroup
	for _, child in ipairs(existingSound:GetChildren()) do
		if child:IsA("EqualizerSoundEffect") or child:IsA("CompressorSoundEffect")
			or child:IsA("ReverbSoundEffect") or child:IsA("EchoSoundEffect")
			or child:IsA("DistortionSoundEffect") or child:IsA("ChorusSoundEffect") or child:IsA("FlangeSoundEffect") then
			child:Destroy()
		end
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

	-- Pastikan SoundGroup selalu terhubung ke MusicGroup
	if self.serverSound.SoundGroup ~= self.musicGroup then
		self.serverSound.SoundGroup = self.musicGroup
	end

	-- Atur PitchShift (Hanya buat jika ada perubahan nada non-standar, hapus total jika nada normal 1.0)
	local pitchShift = self.serverSound:FindFirstChild("ConcertPitchShift")
	local octave = tonumber(pitchOctave) or 1.0
	if math.abs(octave - 1.0) > 0.005 then
		if not pitchShift then
			pitchShift = Instance.new("PitchShiftSoundEffect")
			pitchShift.Name = "ConcertPitchShift"
			pitchShift.Parent = self.serverSound
		end
		pitchShift.Octave = octave
		pitchShift.Enabled = true
	else
		if pitchShift then
			pitchShift:Destroy()
		end
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