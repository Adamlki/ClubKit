local ServerMusicAudioHandler = {}
ServerMusicAudioHandler.__index = ServerMusicAudioHandler

local CONFIG = {
	Audio = {
		DefaultVolume = 0.60,
		DefaultPlaybackSpeed = 1.0
	},
	ClubAudio = {
		EQ = {
			LowGain  = 4.0,
			MidGain  = -4.0,
			HighGain = -15,
			Priority = 1,
		},
		Compressor = {
			Threshold  = -12.5,
			Ratio      = 7.0,
			Attack     = 0.015,
			Release    = 0.14,
			GainMakeup = 0.0,
			Priority   = 2,
		},
		Reverb = {
			DecayTime = 1.6,
			Density   = 0.85,
			Diffusion = 0.92,
			DryLevel  = 0.0,
			WetLevel  = -11.5,
			Priority  = 3,
		}
	}
}

function ServerMusicAudioHandler.new()
	local self = setmetatable({}, ServerMusicAudioHandler)

	self.serverSound  = nil
	self.musicGroup   = nil
	self.currentSoundId = nil
	self.isPlaying    = false
	self.isPaused     = false

	self:CreateMusicGroup()
	self:CreateServerSound()

	return self
end

function ServerMusicAudioHandler:CreateMusicGroup()
	local soundService = game:GetService("SoundService")

	soundService.AmbientReverb = Enum.ReverbType.NoReverb

	local musicGroup = soundService:FindFirstChild("MusicGroup")
	if not musicGroup then
		musicGroup = Instance.new("SoundGroup")
		musicGroup.Name = "MusicGroup"
		musicGroup.Parent = soundService
		musicGroup.Volume = 0.85
	end

	for _, child in ipairs(musicGroup:GetChildren()) do
		if child:IsA("EchoSoundEffect") or child:IsA("DistortionSoundEffect") or child:IsA("ChorusSoundEffect") or child:IsA("FlangeSoundEffect") then
			child:Destroy()
		end
	end

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
	if not self.musicGroup then
		self:CreateMusicGroup()
	end

	local soundService = game:GetService("SoundService")

	soundService.AmbientReverb = Enum.ReverbType.NoReverb

	local existingSound = soundService:FindFirstChild("ServerMusicSound")
	if not existingSound or not existingSound:IsA("Sound") then
		existingSound = Instance.new("Sound")
		existingSound.Name = "ServerMusicSound"
		existingSound.Looped = false
		existingSound.PlaybackSpeed = CONFIG.Audio.DefaultPlaybackSpeed
		existingSound.Parent = soundService
	end

	existingSound.Volume = CONFIG.Audio.DefaultVolume
	existingSound.SoundGroup = self.musicGroup
	self.serverSound = existingSound

	for _, child in ipairs(existingSound:GetChildren()) do
		if child:IsA("EqualizerSoundEffect") or child:IsA("CompressorSoundEffect")
			or child:IsA("ReverbSoundEffect") or child:IsA("EchoSoundEffect")
			or child:IsA("DistortionSoundEffect") or child:IsA("ChorusSoundEffect") or child:IsA("FlangeSoundEffect") then
			child:Destroy()
		end
	end

	return existingSound
end

function ServerMusicAudioHandler:Preload(soundId)
	if not self.serverSound or not self.serverSound.Parent then
		self:CreateServerSound()
	end

	local assetId = "rbxassetid://" .. soundId

	if self.serverSound.SoundId ~= assetId then
		self.serverSound:Stop()
		self.serverSound.SoundId = assetId
	end
end

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

function ServerMusicAudioHandler:Play(soundId, timePosition, playbackSpeed, pitchOctave)
	if not self.serverSound or not self.serverSound.Parent then
		self:CreateServerSound()
	end

	local assetId = "rbxassetid://" .. soundId

	if self.serverSound.SoundId ~= assetId then
		self.serverSound:Stop()
		self.serverSound.SoundId = assetId
	end

	self.serverSound.TimePosition = timePosition or 0
	self.serverSound.PlaybackSpeed = playbackSpeed or CONFIG.Audio.DefaultPlaybackSpeed

	if self.serverSound.SoundGroup ~= self.musicGroup then
		self.serverSound.SoundGroup = self.musicGroup
	end

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

	self.isPlaying = false
	self.isPaused = false
	self.currentSoundId = nil
end

function ServerMusicAudioHandler:Pause()
	if not self.serverSound then return end

	pcall(function()
		self.serverSound:Pause()
	end)

	self.isPaused = true
end

function ServerMusicAudioHandler:Resume()
	if not self.serverSound then return end

	pcall(function()
		self.serverSound:Resume()
	end)

	self.isPaused = false
end

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

		end
	end)

	return true
end

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

function ServerMusicAudioHandler:Cleanup()
	if self.serverSound then
		pcall(function()
			self.serverSound:Stop()
			self.serverSound:Destroy()
		end)
		self.serverSound = nil
	end

end

return ServerMusicAudioHandler
