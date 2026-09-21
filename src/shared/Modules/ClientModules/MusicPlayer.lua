local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ContentProvider = game:GetService("ContentProvider")
local BridgeNet = require(game:GetService("ReplicatedStorage"):WaitForChild("BridgeNet"))

local MusicModule = require(ReplicatedStorage.Modules.MusicModule)
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

	-- UI setup: ambil GUI dari PlayerGui (yang otomatis di-clone oleh Roblox dari StarterGui)
	local playerGui = self.player:WaitForChild("PlayerGui", 30)
	local musicGui = playerGui and (playerGui:FindFirstChild("MusicPlayer") or playerGui:WaitForChild("MusicPlayer", 30))
	if not musicGui then
		warn("[MusicPlayer] MusicPlayer GUI tidak ditemukan di PlayerGui!")
		return self
	end

	self.uiManager = UIManager.new(musicGui)

	-- State
	self.currentVolume = CONFIG.DEFAULT_VOLUME
	self.isMuted = false
	self.previousVolume = CONFIG.DEFAULT_VOLUME

	-- ✅ NEW: Track block state
	self.isBlocked = false

	-- ✅ NEW: Track player role hierarchy for client-side checks
	self.playerRoleHierarchy = 1 -- Default to Player
	
	-- 🔥 Variabel State
	self.expectedIsPlaying = false
	self.lastTimePosition = 0 
	self.absoluteStartTime = 0 -- ⏱️ THE HIVE MIND: Mencatat waktu absolut server
	self.expectedSoundId = "" -- 🔒 KUNCI ID LAGU
	self.expectedDuration = 180 -- Fallback durasi untuk UI progress bar
	self.lastSongChangeTime = 0 -- Catat kapan lagu terakhir berganti untuk toleransi transisi di HP
	self.lastAutoRecoveryTime = 0
	self._isAutoRecovering = false

	-- 🚀 SMART BACKGROUND AUDIO PRELOADER (ANTI-DELAY DI HP)
	self.preloadedCache = {}
	self.isPreloading = false
	self.preloadFolder = nil

	-- Setup
	self:SetupUICallbacks()
	self:SetupRemoteListeners()
	self:SetupToggleKey()
	self:SetupChatCommands()
	self:SetupRoleWatcher() -- ✅ NEW: Watch for role changes

	-- 🎧 LISTENER EVENT LOADED & SOUNDID (FIX HP / MOBILE STREAMING)
	local function bindServerSoundListeners()
		local serverSound = SoundService:FindFirstChild("ServerMusicSound")
		if not serverSound then return end

		if not self._soundLoadedConn then
			self._soundLoadedConn = serverSound.Loaded:Connect(function()
				if self.expectedIsPlaying then
					self:ForceAudioSync({
						ServerTime = self.absoluteStartTime,
						Duration = self.expectedDuration
					})
				end
			end)
		end

		if not self._soundIdConn then
			self._soundIdConn = serverSound:GetPropertyChangedSignal("SoundId"):Connect(function()
				if self.expectedIsPlaying then
					task.defer(function()
						if serverSound.IsLoaded then
							self:ForceAudioSync({
								ServerTime = self.absoluteStartTime,
								Duration = self.expectedDuration
							})
						end
					end)
				end
			end)
		end
	end

	bindServerSoundListeners()
	SoundService.ChildAdded:Connect(function(child)
		if child.Name == "ServerMusicSound" then
			task.wait(0.2)
			bindServerSoundListeners()
		end
	end)

	-- ⏱️ THE HIVE MIND: Watchdog Pengawas Audio & Anti-Drift 0ms (HP / Mobile Friendly)
	local timeSinceLastUpdate = 0
	RunService.Heartbeat:Connect(function(dt)
		timeSinceLastUpdate = timeSinceLastUpdate + dt
		
		-- Cek setiap 0.5 detik
		if timeSinceLastUpdate >= 0.5 then 
			timeSinceLastUpdate = 0
			
			local serverSound = SoundService:FindFirstChild("ServerMusicSound")
			if not serverSound then return end

			-- 🎛️ Pastikan SoundGroup selalu terhubung ke MusicGroup
			if self.musicGroup and serverSound.SoundGroup ~= self.musicGroup then
				serverSound.SoundGroup = self.musicGroup
			end

			-- 🔒 CEK KESESUAIAN ID DENGAN TOLERANSI TRANSISI 3 DETIK (Mencegah stop prematur di HP)
			local currentID = string.match(tostring(serverSound.SoundId), "%d+")
			local expectedID = string.match(tostring(self.expectedSoundId), "%d+")

			if expectedID and currentID and expectedID ~= "" then
				if currentID ~= expectedID then
					-- HANYA stop jika perbedaan ID bertahan lebih dari 3 detik (bukan lag jeda replikasi)
					if (os.clock() - (self.lastSongChangeTime or 0)) > 3.0 then
						if serverSound.IsPlaying then
							serverSound:Stop()
						end
					end
					return
				end
			end

			if self.expectedIsPlaying and self.absoluteStartTime > 0 then
				local currentServerTime = workspace:GetServerTimeNow()
				local realTimeElapsed = currentServerTime - self.absoluteStartTime
				local expectedTimePos = realTimeElapsed * (serverSound.PlaybackSpeed or 1)

				local maxDuration = serverSound.TimeLength
				if maxDuration <= 0 then
					maxDuration = self.expectedDuration or 180
				end
				
				-- Validasi jika lagu masih dalam batas durasi putar
				if maxDuration > 0 and expectedTimePos < maxDuration then
					-- Jika sound sudah dimuat (TimeLength > 0 dan IsLoaded)
					if serverSound.TimeLength > 0 and serverSound.IsLoaded then
						local currentPos = serverSound.TimePosition
						local desync = math.abs(currentPos - expectedTimePos)

						-- 🛡️ ANTI-KEPREK: JANGAN PERNAH micro-seek saat lagu sedang berputar normal!
						-- Toleransi dinaikkan dari 0.25s ke 2.5s agar tidak ada stutter/klik/pecah akibat micro-seek berulang
						if not serverSound.IsPlaying then
							pcall(function()
								serverSound.TimePosition = math.clamp(expectedTimePos, 0, maxDuration - 0.1)
								serverSound:Play()
							end)
						elseif desync > 2.5 then
							-- Hanya snap jika terjadi lag parah / app freeze (>2.5 detik)
							pcall(function()
								serverSound.TimePosition = math.clamp(expectedTimePos, 0, maxDuration - 0.1)
							end)
						end
					else
						-- 🚨 AUTO SELF-HEALING DI HP: Jika audio buffering/silent playback > 2.5s
						if not serverSound.IsPlaying and (os.clock() - (self.lastSongChangeTime or 0)) > 2.5 then
							if not self._isAutoRecovering and (os.clock() - (self.lastAutoRecoveryTime or 0)) > 6.0 then
								self.lastAutoRecoveryTime = os.clock()
								self._isAutoRecovering = true
								task.spawn(function()
									pcall(function()
										if not serverSound.IsPlaying then
											serverSound:Play()
										end
									end)
									task.wait(0.5)
									self._isAutoRecovering = false
								end)
							end
						end
					end
				end
				
				-- Update UI Progress Bar sesuai waktu absolut
				if maxDuration > 0 then
					local progress = math.clamp(expectedTimePos / maxDuration, 0, 1)
					self.uiManager:UpdateProgress(progress, expectedTimePos, maxDuration)
				end
			else
				-- Matikan secara absolut jika sistem disuruh stop
				if serverSound.IsPlaying then
					serverSound:Stop()
				end
			end
		end
	end)

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
		DispatchEvent = remoteFolder:WaitForChild("DispatchEvent", 10),
		MusicAction = remoteFolder:WaitForChild("MusicAction", 10),
		MusicBroadcast = remoteFolder:WaitForChild("MusicBroadcast", 10),
		MusicUpdate = remoteFolder:WaitForChild("MusicUpdate", 10),
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
				Owner = 5,
				Admin = 4,
				Moderator = 3,
				VIP = 2,
				Player = 1
			}

			self.playerRoleHierarchy = roleHierarchyMap[role] or 1
		end
	end

	-- Initial check
	updateRoleHierarchy()

	-- Watch for role changes
	task.spawn(function()
		local roleValue = self.player:WaitForChild("Role", 15)
		if roleValue and roleValue:IsA("StringValue") then
			updateRoleHierarchy()
			roleValue.Changed:Connect(updateRoleHierarchy)
		end
	end)
end

-- ====================================
-- SETUP VOLUME CONTROL (LIGHTWEIGHT - WAIT ONCE)
-- ====================================
function MusicPlayer:SetupVolumeControl()
	-- 💡 FIX: Beri batas waktu 5 detik. Jika server ngelag/gagal, client tidak ikut mati.
	local musicGroup = SoundService:WaitForChild("MusicGroup", 5) 
	if musicGroup then
		self.musicGroup = musicGroup
		self.musicGroup.Volume = CONFIG.DEFAULT_VOLUME
	else
		warn("[MusicPlayer] Server gagal mengirim MusicGroup! Memicu pembuatan lokal...")
		self:UpdateVolume(CONFIG.DEFAULT_VOLUME)
	end
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
			local startTime = os.clock()
			while serverSound.TimeLength == 0 and (os.clock() - startTime) < 5 do
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

	-- Reload button
	self.uiManager:OnReload(function()
		self:RetryAudio()
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
-- 🚀 SMART BACKGROUND AUDIO PRELOADER (ANTI-DELAY DI HP)
-- ====================================
function MusicPlayer:PreloadSong(soundId)
	if not soundId or soundId == "" then return end
	local idStr = string.match(tostring(soundId), "%d+")
	if not idStr or idStr == "" then return end

	-- 1. Cek apakah sudah pernah di-preload (langsung tandai true agar tidak duplikat saat event masuk beruntun)
	if self.preloadedCache[idStr] then
		return
	end
	self.preloadedCache[idStr] = true

	-- 2. Jalankan secara asynchronous (task.defer) agar TIDAK MENYEBABKAN STUTTER / FREEZE
	task.defer(function()
		-- Hindari download bersamaan yang memberatkan koneksi HP
		if self.isPreloading then
			task.wait(1)
		end

		self.isPreloading = true

		pcall(function()
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

			-- Jangan buat jika sudah ada instance sound dengan ID yang sama
			local existingSound = self.preloadFolder:FindFirstChild("Preload_" .. idStr)
			if existingSound then
				self.isPreloading = false
				return
			end

			-- Batasi maksimal 3 sound cache agar hemat RAM di HP
			local existingSounds = self.preloadFolder:GetChildren()
			if #existingSounds >= 3 then
				existingSounds[1]:Destroy()
			end

			-- Buat sound instance tersembunyi & tanpa suara (Volume = 0)
			local preloadSound = Instance.new("Sound")
			preloadSound.Name = "Preload_" .. idStr
			preloadSound.SoundId = "rbxassetid://" .. idStr
			preloadSound.Volume = 0
			preloadSound.Parent = self.preloadFolder

			-- Minta ContentProvider memuat aset ke memori lokal di background
			ContentProvider:PreloadAsync({ preloadSound })
		end)

		self.isPreloading = false
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

	elseif eventType == "PRELOAD_SONG" then
		-- 🚀 Terima instruksi preload dari server
		if payload.soundId then
			self:PreloadSong(payload.soundId)
		end

	elseif eventType == "SYNC_STATE" then
		self:SyncState(payload)

	elseif eventType == "QUEUE_UPDATE" then
		self.uiManager:UpdateQueue(payload.queue or {})
		
		-- 🚀 SMART BACKGROUND AUDIO PRELOAD UNTUK ANTREAN #1
		local queue = payload.queue or {}
		if #queue > 0 and queue[1] then
			local nextItem = queue[1]
			local nextData = nextItem.musicData or nextItem
			if nextData and nextData.id then
				self:PreloadSong(nextData.id)
			end
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
	end
end

-- ====================================
-- HANDLE MUSIC BROADCAST (UI UPDATE & AUDIO SYNC)
-- ====================================
function MusicPlayer:HandleMusicBroadcast(eventType, payload)
	if eventType == "SongUpdate" then
		-- Simpan durasi yang dibroadcast server
		if payload.Duration and payload.Duration > 0 then
			self.expectedDuration = payload.Duration
		end

		-- Update UI
		self:UpdateMusicUI(payload)

		-- HANYA SINKRONISASI JIKA BUKAN KOREKSI DURASI
		if not payload.IsCorrection then
			self.lastSongChangeTime = os.clock()
			-- ⏱️ SIMPAN WAKTU SERVER SEBAGAI ACUAN UTAMA (Dengan Fallback)
			self.absoluteStartTime = payload.ServerTime or workspace:GetServerTimeNow()
			
			-- 🔒 CATAT ID LAGU BARU DENGAN AMAN
			self.expectedSoundId = payload.SoundId or payload.id or ""

			-- 🔥 SINKRONISASI AUDIO ABSOLUT!
			self:ForceAudioSync(payload)
			
			self.expectedIsPlaying = true
			self.lastTimePosition = 0 
		end

	elseif eventType == "StopMusic" then
		self:StopMusicUI()
		self.expectedIsPlaying = false
		self.lastTimePosition = 0

	end
end

-- ====================================
-- THE ABSOLUTE AUDIO SNAP (TIME-TRAVEL)
-- ====================================
function MusicPlayer:ForceAudioSync(payload)
	local serverSound = SoundService:FindFirstChild("ServerMusicSound")
	if not serverSound then return end

	task.spawn(function()
		-- 1. Tunggu audio selesai dimuat ke memori perangkat (mencegah error di HP)
		if not serverSound.IsLoaded then
			local t = os.clock()
			while not serverSound.IsLoaded and (os.clock() - t) < 8 do
				task.wait(0.1)
			end
		end

		if not payload.ServerTime or not self.expectedIsPlaying then return end

		-- 2. Hitung waktu absolut server
		local currentServerTime = workspace:GetServerTimeNow()
		local realTimeElapsed = currentServerTime - payload.ServerTime
		local expectedTimePos = realTimeElapsed * (serverSound.PlaybackSpeed or 1)

		local maxDuration = payload.Duration or serverSound.TimeLength
		if maxDuration <= 0 then maxDuration = 9999 end

		-- 3. Validasi apakah lagu masih dalam durasi putar
		if expectedTimePos >= 0 and expectedTimePos < maxDuration then
			local currentPos = serverSound.TimePosition
			local desync = math.abs(currentPos - expectedTimePos)

			pcall(function()
				-- Hanya set TimePosition jika lagu belum menyala atau desync sangat jauh (>2.5s)
				if (not serverSound.IsPlaying or desync > 2.5) and serverSound.IsLoaded and serverSound.TimeLength > 0 then
					serverSound.TimePosition = math.clamp(expectedTimePos, 0, maxDuration - 0.1)
				end

				-- Mainkan lagu jika belum menyala di sisi client
				if not serverSound.IsPlaying then
					serverSound:Play()
				end
			end)
		else
			-- Jika lagu sudah habis waktunya, pastikan dimatikan
			if serverSound.IsPlaying then
				pcall(function() serverSound:Stop() end)
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

	-- 🚀 SMART BACKGROUND AUDIO PRELOAD UNTUK ANTREAN #1
	local queue = state.queue or {}
	if #queue > 0 and queue[1] then
		local nextItem = queue[1]
		local nextData = nextItem.musicData or nextItem
		if nextData and nextData.id then
			self:PreloadSong(nextData.id)
		end
	end

	-- Update favorites
	if state.favoriteSongs then
		self.uiManager:UpdateFavorites(state.favoriteSongs)
	end

	-- Update now playing (without popup)
	if state.currentSong then
		self.expectedDuration = (state.currentSong and state.currentSong.Duration) or state.duration or 180
		self.uiManager:UpdateNowPlaying(state.currentSong, state.currentUploader, false)
		self.uiManager:UpdateSongDuration(
			state.duration or 0,
			state.currentSong.Duration,
			false
		)
		
		self.expectedIsPlaying = state.isPlaying
		self.lastTimePosition = 0 -- 🔥 RESET JUGA DI SINI

		-- ⏱️ THE HIVE MIND: LATE JOINER AUDIO SNAP!
		-- Tarik pemain yang baru masuk ke Waktu Absolut 0 Delay!
		if state.isPlaying then
			self.absoluteStartTime = state.startTime or workspace:GetServerTimeNow()
			self.expectedSoundId = state.currentSong.SoundId or state.currentSong.id or "" -- 🔒 CATAT ID
			
			self:ForceAudioSync({
				ServerTime = self.absoluteStartTime,
				Duration = state.currentSong.Duration
			})
		end
	else
		self.expectedIsPlaying = false
		self.lastTimePosition = 0
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
	local songObj = MusicModule:GetMusicById(data.SoundId)
	local albumName = (songObj and songObj.album) or data.Album
	local albumCover = albumName and MusicModule:GetAlbumCover(albumName)
	local cover = albumCover or (songObj and songObj.sampul) or data.AlbumCover or CONFIG.DEFAULT_COVER

	local musicData = {
		id = data.SoundId,
		judul = data.Title,
		album = albumName,
		sampul = cover,
		Duration = data.Duration or 0
	}

	-- HANYA MUNCULKAN POPUP JIKA BUKAN KOREKSI
	self.uiManager:UpdateNowPlaying(musicData, data.AddedBy, not data.IsCorrection)

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
	local songObj = MusicModule:GetMusicById(data.SoundId)
	local albumName = (songObj and songObj.album) or data.Album
	local albumCover = albumName and MusicModule:GetAlbumCover(albumName)
	local cover = albumCover or (songObj and songObj.sampul) or data.AlbumCover or CONFIG.DEFAULT_COVER

	local musicData = {
		id = data.SoundId,
		judul = data.Title,
		album = albumName,
		sampul = cover,
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