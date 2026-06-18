local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")
local BridgeNet = require(game:GetService("ReplicatedStorage"):WaitForChild("BridgeNet"))

local UIManager = require(script.Parent.UIManager)

local MusicPlayer = {}
MusicPlayer.__index = MusicPlayer

-- ====================================
-- CONFIGURATION
-- ====================================
local CONFIG = {
	DEFAULT_VOLUME = 1,
	DEFAULT_COVER = "rbxassetid://88574818940840"
}

-- ====================================
-- INITIALIZATION
-- ====================================
function MusicPlayer.new()
	local self = setmetatable({}, MusicPlayer)

	self.player = Players.LocalPlayer
	self.remotes = self:WaitForRemotes()

	-- Setup volume control via SoundGroup
	self.musicGroup = nil
	self:SetupVolumeControl()

	-- UI setup
	local playerGui = self.player:WaitForChild("PlayerGui",30)
	local musicGui = playerGui:WaitForChild("MusicPlayer",60)
	self.uiManager = UIManager.new(musicGui)

	-- State
	self.currentVolume = CONFIG.DEFAULT_VOLUME
	self.isMuted = false
	self.previousVolume = CONFIG.DEFAULT_VOLUME

	-- ✅ NEW: Track block state
	self.isBlocked = false

	-- ✅ NEW: Track player role hierarchy for client-side checks
	self.playerRoleHierarchy = 1 -- Default to Player

	-- Setup
	self:SetupUICallbacks()
	self:SetupRemoteListeners()
	self:SetupToggleKey()
	self:SetupChatCommands()
	self:SetupRoleWatcher() -- ✅ NEW: Watch for role changes

	-- Set initial volume
	self.uiManager:SetVolume(self.currentVolume * 100)
	self:UpdateVolume(self.currentVolume)
	
	-- ✅ PERBAIKAN: JABAT TANGAN (Handshake)
	-- Beritahu Server bahwa UI sudah siap dan minta sinkronisasi data sekarang juga!
	task.spawn(function()
		self:SendAction("REQUEST_SYNC", {})
	end)

	return self
end

-- ====================================
-- WAIT FOR REMOTES
-- ====================================
function MusicPlayer:WaitForRemotes()
	local remoteFolder = ReplicatedStorage:WaitForChild("MusicRemotes", 10)
	if not remoteFolder then
		warn("[MusicPlayer] Failed to find MusicRemotes folder!")
		return nil
	end

	return {
		DispatchEvent = remoteFolder:WaitForChild("DispatchEvent"),
		MusicAction = remoteFolder:WaitForChild("MusicAction"),
		MusicBroadcast = remoteFolder:WaitForChild("MusicBroadcast"),
		MusicUpdate = remoteFolder:WaitForChild("MusicUpdate"),
	}
end

-- ====================================
-- ✅ NEW: SETUP ROLE WATCHER
-- ====================================
function MusicPlayer:SetupRoleWatcher()
	local function updateRoleHierarchy()
		local roleValue = self.player:FindFirstChild("Role")
		if roleValue and roleValue:IsA("StringValue") then
			local role = roleValue.Value

			-- Role hierarchy (same as server)
			local roleHierarchyMap = {
				Owner = 6,
				Admin = 5,
				Moderator = 4,
				VVIP = 3,
				VIP = 2,
				Player = 1
			}

			self.playerRoleHierarchy = roleHierarchyMap[role] or 1
		end
	end

	-- Initial check
	updateRoleHierarchy()

	-- Watch for role changes
	local roleValue = self.player:FindFirstChild("Role")
	if roleValue and roleValue:IsA("StringValue") then
		roleValue.Changed:Connect(updateRoleHierarchy)
	else
		-- Wait for Role to be created
		self.player.ChildAdded:Connect(function(child)
			if child.Name == "Role" and child:IsA("StringValue") then
				updateRoleHierarchy()
				child.Changed:Connect(updateRoleHierarchy)
			end
		end)
	end
end

-- ====================================
-- SETUP VOLUME CONTROL (LIGHTWEIGHT - WAIT ONCE)
-- ====================================
function MusicPlayer:SetupVolumeControl()
	-- Simple wait with timeout
	local musicGroup = SoundService:WaitForChild("MusicGroup", 10)

	if not musicGroup then
		warn("[MusicPlayer] MusicGroup not found after 10s! Creating fallback...")
		musicGroup = Instance.new("SoundGroup")
		musicGroup.Name = "MusicGroup"
		musicGroup.Parent = SoundService
	end

	self.musicGroup = musicGroup
	self.musicGroup.Volume = CONFIG.DEFAULT_VOLUME

end

-- ====================================
-- UPDATE VOLUME (LIGHTWEIGHT - CHECK ON DEMAND)
-- ====================================
function MusicPlayer:UpdateVolume(volumePercent)
	-- Quick check: MusicGroup masih ada?
	if not self.musicGroup or not self.musicGroup.Parent then
		-- Reconnect only when needed
		self.musicGroup = SoundService:FindFirstChild("MusicGroup")

		if not self.musicGroup then
			warn("[MusicPlayer] MusicGroup missing! Recreating...")
			self.musicGroup = Instance.new("SoundGroup")
			self.musicGroup.Name = "MusicGroup"
			self.musicGroup.Parent = SoundService
		end
	end

	if self.musicGroup then
		self.musicGroup.Volume = volumePercent
	end
end

-- ====================================
-- RETRY AUDIO (RELOAD SOUNDSERVICE SOUND)
-- ====================================
function MusicPlayer:RetryAudio()
	local soundService = game:GetService("SoundService")

	-- Cari sound di SoundService
	local serverSound = soundService:FindFirstChild("ServerMusicSound")

	if not serverSound or not serverSound:IsA("Sound") then
		self.uiManager:ShowNotification("No active music found!")
		return
	end

	-- Store current state
	local currentSoundId = serverSound.SoundId
	local currentTimePosition = serverSound.TimePosition
	local currentPlaybackSpeed = serverSound.PlaybackSpeed
	local wasPlaying = serverSound.IsPlaying

	if currentSoundId == "" then
		self.uiManager:ShowNotification("No music loaded!")
		return
	end

	self.uiManager:ShowNotification("Reloading audio...")

	-- Stop and reload
	task.spawn(function()
		pcall(function()
			serverSound:Stop()
		end)

		task.wait(0.2)

		pcall(function()
			-- Reload sound
			serverSound.SoundId = ""
			task.wait(0.1)
			serverSound.SoundId = currentSoundId
			serverSound.PlaybackSpeed = currentPlaybackSpeed

			-- Re-link to MusicGroup if needed
			if self.musicGroup and serverSound.SoundGroup ~= self.musicGroup then
				serverSound.SoundGroup = self.musicGroup
			end

			-- Wait for sound to load
			local startTime = tick()
			while serverSound.TimeLength == 0 and (tick() - startTime) < 5 do
				task.wait(0.1)
			end

			if wasPlaying then
				serverSound.TimePosition = currentTimePosition
				serverSound:Play()
				self.uiManager:ShowNotification("Audio reloaded!")
			else
				self.uiManager:ShowNotification("Audio reloaded (paused)")
			end

			-- Apply current volume
			self:UpdateVolume(self.currentVolume)
		end)
	end)
end

-- ====================================
-- ✅ FIXED: CHECK IF PLAYER CAN PERFORM ACTION (SERVER-AUTHORITATIVE)
-- ====================================
function MusicPlayer:CanPerformAction(actionType)
	-- ✅ MODERATOR+ (hierarchy >= 4) ALWAYS ALLOWED
	if self.playerRoleHierarchy >= 4 then
		return true
	end

	-- Allowed actions during block for non-moderators
	local allowedDuringBlock = {
		"SKIP_VOTE_YES",
		"SKIP_VOTE_NO",
		"TOGGLE_FAVORITE",
		"ADMIN_TOGGLE_BLOCK",
		"RETRY_ALL"
	}

	-- Check if action is allowed during block
	for _, allowed in ipairs(allowedDuringBlock) do
		if actionType == allowed then
			return true
		end
	end

	-- If not blocked, allow all actions
	if not self.isBlocked then
		return true
	end

	-- Blocked and action not allowed
	return false
end

-- ====================================
-- SETUP UI CALLBACKS (✅ FIXED WITH PROPER BLOCK CHECK)
-- ====================================
function MusicPlayer:SetupUICallbacks()
	-- Music submit (from playlist or custom ID)
	self.uiManager:OnMusicSubmit(function(musicId: string)
		-- ✅ CLIENT-SIDE BLOCK CHECK (but allows Moderator+)
		if not self:CanPerformAction("ADD_TO_QUEUE") then
			self.uiManager:ShowNotification("🔒 Music access is currently blocked by Admin!")
			return
		end

		local isFromPlaylist = true

		-- Check if it's a custom music ID (numeric only)
		if musicId:match("^%d+$") and #musicId <= 20 then
			isFromPlaylist = false
		end

		self:SendAction("ADD_TO_QUEUE", {
			musicId = musicId,
			isFromPlaylist = isFromPlaylist
		})
	end)

	-- Next/Skip button
	self.uiManager:OnNext(function()
		-- ✅ CLIENT-SIDE BLOCK CHECK (but allows Moderator+)
		if not self:CanPerformAction("CONTROL_NEXT") then
			self.uiManager:ShowNotification("🔒 Music access is currently blocked by Admin!")
			return
		end

		self:SendAction("CONTROL_NEXT", {})
	end)

	-- Volume change (CLIENT-SIDE ONLY)
	self.uiManager:OnVolumeChange(function(percent)
		self.currentVolume = percent
		self.isMuted = false
		self:UpdateVolume(percent)
	end)

	-- Skip vote response (✅ ALLOWED DURING BLOCK)
	self.uiManager:OnSkipVoteResponse(function(voteType)
		if voteType == "yes" then
			self:SendAction("SKIP_VOTE_YES", {})
		else
			self:SendAction("SKIP_VOTE_NO", {})
		end
	end)

	-- Admin toggle block
	self.uiManager:OnAdminToggleBlock(function()
		self:SendAction("ADMIN_TOGGLE_BLOCK", {})
	end)

	-- Toggle favorite (✅ ALLOWED DURING BLOCK)
	self.uiManager:OnToggleFavorite(function(musicId)
		self:SendAction("TOGGLE_FAVORITE", {musicId = musicId})
	end)
end

-- ====================================
-- SETUP REMOTE LISTENERS
-- ====================================
function MusicPlayer:SetupRemoteListeners()
	-- Dispatch event (general events)
	self.remotes.DispatchEvent.OnClientEvent:Connect(function(data)
		self:HandleDispatchEvent(data)
	end)

	-- Music broadcast (playback events - UI ONLY)
	local musicBroadcastBridge = BridgeNet.CreateBridge("MusicBroadcast")
	musicBroadcastBridge:Connect(function(payload)
		if type(payload) == "table" and payload.eventType then
			self:HandleMusicBroadcast(payload.eventType, payload.data)
		end
	end)

	-- Music update (sync events - UI ONLY)
	self.remotes.MusicUpdate.OnClientEvent:Connect(function(eventType, payload)
		if eventType == "SyncMusic" then
			self:SyncMusicUI(payload)
		end
	end)
end

-- ====================================
-- HANDLE DISPATCH EVENT (✅ FIXED WITH NEW EVENTS)
-- ====================================
function MusicPlayer:HandleDispatchEvent(data)
	if not data or not data.type then return end

	local eventType = data.type
	local payload = data.payload or {}

	if eventType == "NOTIFY" then
		self.uiManager:ShowNotification(payload.message)

	elseif eventType == "SYNC_STATE" then
		self:SyncState(payload)

	elseif eventType == "QUEUE_UPDATE" then
		self.uiManager:UpdateQueue(payload.queue or {})
		
		-- 🔥 PRELOAD AUDIO ANTRIAN: Agar transisi mulus dan tidak nge-lag/masuk di tengah-tengah
		if payload.queue and #payload.queue > 0 then
			task.spawn(function()
				local ContentProvider = game:GetService("ContentProvider")
				local soundsToPreload = {}
				
				-- Preload up to 2 next songs
				for i = 1, math.min(2, #payload.queue) do
					local item = payload.queue[i]
					if item and item.musicData and item.musicData.id then
						local sound = Instance.new("Sound")
						sound.SoundId = "rbxassetid://" .. item.musicData.id
						table.insert(soundsToPreload, sound)
					end
				end
				
				if #soundsToPreload > 0 then
					pcall(function()
						ContentProvider:PreloadAsync(soundsToPreload)
					end)
					-- Clean up temp sounds
					for _, sound in ipairs(soundsToPreload) do
						sound:Destroy()
					end
				end
			end)
		end

	elseif eventType == "SKIP_VOTE_START" then
		self.uiManager:ShowSkipVote(payload.initiator, payload.songTitle, payload.totalVoters)

	elseif eventType == "SKIP_VOTE_UPDATE" then
		self.uiManager:UpdateSkipVote(payload.yesVotes, payload.noVotes, payload.totalVoters)

	elseif eventType == "SKIP_VOTE_END" then
		local passed = payload.result == "passed"
		self.uiManager:HideSkipVote()
		self.uiManager:ShowSkipVoteResult(passed)

	elseif eventType == "ADMIN_BLOCK_ACTIVATED" then
		-- ✅ UPDATE LOCAL STATE
		self.isBlocked = true
		self.uiManager:ShowBlockFrame()

	elseif eventType == "ADMIN_BLOCK_DEACTIVATED" then
		-- ✅ UPDATE LOCAL STATE
		self.isBlocked = false
		self.uiManager:HideBlockFrame()

	elseif eventType == "ADMIN_BUTTON_UPDATE" then
		-- ✅ NEW EVENT: Update admin button text only
		self.uiManager:UpdateAdminButtonText(payload.text or "Block")

	elseif eventType == "FAVORITES_UPDATE" then
		self.uiManager:UpdateFavorites(payload.favoriteSongs or {})
		
	elseif eventType == "PRELOAD_AUDIO" then
		-- 🔥 Menerima instruksi dari server untuk memuat lagu otomatis (Auto-Playlist/Queue) berikutnya
		if payload.id then
			task.spawn(function()
				local ContentProvider = game:GetService("ContentProvider")
				local sound = Instance.new("Sound")
				sound.SoundId = "rbxassetid://" .. payload.id
				pcall(function()
					ContentProvider:PreloadAsync({sound})
				end)
				sound:Destroy()
			end)
		end
	end
end

-- ====================================
-- HANDLE MUSIC BROADCAST (UI UPDATE & AUDIO SYNC)
-- ====================================
function MusicPlayer:HandleMusicBroadcast(eventType, payload)
	if eventType == "SongUpdate" then
		-- Update UI
		self:UpdateMusicUI(payload)

		-- 🔥 SINKRONISASI AUDIO ABSOLUT!
		self:ForceAudioSync(payload)

	elseif eventType == "StopMusic" then
		self:StopMusicUI()

	elseif eventType == "Progress" then
		self:UpdateProgress(payload)
	end
end

-- ====================================
-- THE ABSOLUTE AUDIO SNAP (TIME-TRAVEL)
-- ====================================
function MusicPlayer:ForceAudioSync(payload)
	local serverSound = SoundService:WaitForChild("ServerMusicSound", 5)
	if not serverSound then return end

	-- Gunakan task.spawn agar tidak memblokir antarmuka UI
	task.spawn(function()
		local expectedAssetId = "rbxassetid://" .. payload.SoundId
		local timeout = tick() + 300 
		
		-- 0. Tunggu sampai SoundId benar-benar terupdate oleh Roblox Native Replication
		while serverSound.SoundId ~= expectedAssetId and tick() < timeout do
			task.wait(0.1)
		end

		-- 1. Tunggu chipset HP selesai mengunduh & mendecode audio (Tunggu hingga 60 detik untuk HP kentang/lag)
		while serverSound.TimeLength == 0 and tick() < timeout do
			task.wait(0.2)
		end

		-- 2. Pastikan lagu yang selesai didecode ini adalah lagu yang benar (belum di-skip)
		if serverSound.TimeLength > 0 and payload.ServerTime and serverSound.SoundId == expectedAssetId then

			-- 3. Hitung persis berapa detik HP ini tertinggal dari Server
			local exactPingDelay = workspace:GetServerTimeNow() - payload.ServerTime

			-- 4. Extrapolasi Hardware: Decoding Audio di HP lebih lambat dari render grafis.
			local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
			local hardwareAudioOffset = isMobile and 0.15 or 0.05 

			local speed = payload.PlaybackSpeed or 1.0

			-- 5. Kalkulasi posisi detik absolut
			local compensatedTime = (exactPingDelay + hardwareAudioOffset) * speed

			-- 6. EKSEKUSI SNAP MUTLAK: Potong lagu secara paksa!
			if compensatedTime > 0 and compensatedTime < serverSound.TimeLength then
				-- Hanya paksakan sinkronisasi jika melenceng jauh (cegah efek double di awal lagu)
				if math.abs(serverSound.TimePosition - compensatedTime) > 0.4 then
					serverSound.TimePosition = compensatedTime
				end
			end

			-- 🔥 FIX PENTING: Jika HP ngelag parah sampai Roblox native replication menyerah, PAKSA MAIN!
			if not serverSound.IsPlaying then
				serverSound:Play()
			end
		end
	end)
end
-- ====================================
-- SYNC STATE (? FIXED WITH BLOCK STATE & 🔥 LATE JOINER AUDIO SNAP)
-- ====================================
function MusicPlayer:SyncState(state)
	-- ? UPDATE BLOCK STATE
	self.isBlocked = state.isBlocked or false

	-- Update queue
	self.uiManager:UpdateQueue(state.queue or {})

	-- Update favorites
	if state.favoriteSongs then
		self.uiManager:UpdateFavorites(state.favoriteSongs)
	end

	-- Update now playing (without popup)
	if state.currentSong then
		self.uiManager:UpdateNowPlaying(state.currentSong, state.currentUploader, false)
		self.uiManager:UpdateSongDuration(
			state.duration or 0,
			state.currentSong.Duration,
			false
		)

		-- 🔥 ARCHITECT FIX: LATE JOINER AUDIO SNAP!
		-- Tarik pemain yang baru masuk ke Waktu Absolut 0 Delay!
		if state.isPlaying and state.startTime then
			-- Late joiner sync is handled by native Roblox replication for SoundService
		end
	end

	-- Update admin block state (only for non-moderators)
	if state.isBlocked and self.playerRoleHierarchy < 4 then
		self.uiManager:ShowBlockFrame()
	else
		self.uiManager:HideBlockFrame()
	end
end

-- ====================================
-- UPDATE MUSIC UI (NO AUDIO PLAYBACK)
-- ====================================
function MusicPlayer:UpdateMusicUI(data)
	-- Update UI with popup
	local musicData = {
		id = data.SoundId,
		judul = data.Title,
		sampul = data.AlbumCover or CONFIG.DEFAULT_COVER,
		Duration = data.Duration or 0
	}

	self.uiManager:UpdateNowPlaying(musicData, data.AddedBy, true) -- Show popup

	self.uiManager:UpdateSongDuration(
		data.DetectedDuration or data.Duration or 0,
		data.MetadataDuration,
		data.WasDetected or false
	)
end

-- ====================================
-- SYNC MUSIC UI (FOR /RETRY - NO AUDIO)
-- ====================================
function MusicPlayer:SyncMusicUI(data)
	-- Update UI without popup
	local musicData = {
		id = data.SoundId,
		judul = data.Title,
		sampul = data.AlbumCover or CONFIG.DEFAULT_COVER,
		Duration = data.Duration or 0
	}

	self.uiManager:UpdateNowPlaying(musicData, data.AddedBy, false) -- No popup
	self.uiManager:UpdateSongDuration(data.Duration or 0)
end

-- ====================================
-- STOP MUSIC UI
-- ====================================
function MusicPlayer:StopMusicUI()
	self.uiManager:ResetUI()
end

-- ====================================
-- UPDATE PROGRESS
-- ====================================
function MusicPlayer:UpdateProgress(data)
	if data.Duration and data.Duration > 0 then
		local progress = math.clamp(data.Current / data.Duration, 0, 1)
		self.uiManager:UpdateProgress(progress, data.Current, data.Duration)
		
		-- 🔥 SYNC AUDIO BERKELANJUTAN (SOFT SYNC)
		local serverSound = SoundService:FindFirstChild("ServerMusicSound")
		if serverSound and serverSound.IsPlaying and serverSound.TimeLength > 0 and data.ServerTime then
			local exactPingDelay = workspace:GetServerTimeNow() - data.ServerTime
			local expectedTime = data.Current + (exactPingDelay * (data.PlaybackSpeed or 1.0))
			
			-- Ekstrapolasi hardware HP lambat
			local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
			expectedTime = expectedTime + (isMobile and 0.15 or 0.05)
			
			-- Jika audio melenceng lebih dari 0.5 detik dari server, paksakan snap!
			if math.abs(serverSound.TimePosition - expectedTime) > 0.5 then
				if expectedTime > 0 and expectedTime < serverSound.TimeLength then
					serverSound.TimePosition = expectedTime
				end
			end
		end
	end
end

-- ====================================
-- SEND ACTION TO SERVER (✅ NO REDUNDANT CHECK - LET SERVER DECIDE)
-- ====================================
function MusicPlayer:SendAction(actionType, payload)
	if not self.remotes then return end

	-- ✅ CLIENT-SIDE CHECK ALREADY DONE IN CALLBACKS
	-- Server will do final authoritative check anyway

	pcall(function()
		self.remotes.MusicAction:FireServer({
			type = actionType,
			payload = payload or {}
		})
	end)
end

-- ====================================
-- TOGGLE KEY (M KEY)
-- ====================================
function MusicPlayer:SetupToggleKey()
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end

		if input.KeyCode == Enum.KeyCode.M then
			self.uiManager:ToggleMainFrame()
		end
	end)
end

-- ====================================
-- CHAT COMMANDS
-- ====================================
function MusicPlayer:SetupChatCommands()
	self.player.Chatted:Connect(function(message)
		local lowerMsg = string.lower(message)

		-- Volume command: /vol 50
		if lowerMsg:match("^/vol%s+%d+") or lowerMsg:match("^;vol%s+%d+") then
			local volume = tonumber(lowerMsg:match("%d+"))
			if volume then
				volume = math.clamp(volume, 0, 100)
				self.currentVolume = volume / 100
				self.isMuted = false
				self.uiManager:SetVolume(volume)
				self:UpdateVolume(self.currentVolume)
				self.uiManager:ShowNotification(string.format("Volume set to %d%%", volume))
			end
		end

		-- Mute toggle
		if lowerMsg == "/mute" or lowerMsg == ";mute" then
			if self.isMuted then
				-- Unmute
				self.isMuted = false
				self.currentVolume = self.previousVolume
				self.uiManager:SetVolume(self.currentVolume * 100)
				self:UpdateVolume(self.currentVolume)
				self.uiManager:ShowNotification("Unmuted")
			else
				-- Mute
				self.isMuted = true
				self.previousVolume = self.currentVolume
				self.currentVolume = 0
				self.uiManager:SetVolume(0)
				self:UpdateVolume(0)
				self.uiManager:ShowNotification("Muted")
			end
		end

		-- Retry commands (reload SoundService audio)
		if lowerMsg == "/retry" or lowerMsg == ";retry" or lowerMsg == "/ret" or lowerMsg == ";ret" then
			self:RetryAudio()
		end

		-- RetryAll (server-side command)
		if lowerMsg == "/retryall" or lowerMsg == ";retryall" then
			self:SendAction("RETRY_ALL", {})
		end
	end)
end

return MusicPlayer