-- ============================================
-- SINGLETON PROTECTION
-- Mencegah script berjalan ganda jika masih ada LocalScript di StarterGui.EmoteGui
-- ============================================
if _G.__EmoteHandlerClientLoaded then
	return
end
_G.__EmoteHandlerClientLoaded = true

local Players = game:GetService("Players")
local player = Players.LocalPlayer
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local updateFavoritedAnimationsEventRE = remotes:WaitForChild("updateFavoritedAnimationsEvent")
local startSyncRE = remotes:WaitForChild("startSync")
local changeSpeedRE = remotes:WaitForChild("changeSpeed")
local syncNotificationRE = remotes:WaitForChild("SyncNotification")
local animationStartRE = remotes:WaitForChild("animationStart")

local emotesFolder = ReplicatedStorage:WaitForChild("Emotes")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local AnimationPreloader = require(Modules:WaitForChild("AnimationPreloader"))
local AnimatorUtils = require(Modules:WaitForChild("AnimatorUtils"))
AnimatorUtils.AnimationPreloader = AnimationPreloader

-- 🔥 INTEGRASI MODULE ANIMASI
local UIAnimator = require(ReplicatedStorage:WaitForChild("UIAnimator"))

-- ============================================
-- GLOBAL CONNECTION TRACKER (ANTI MEMORY LEAK)
-- ============================================
local isScriptActive = true
local scriptConnections = {}
local fakeStartTimes = {} -- 🔥 THE HIVE MIND: Cache waktu mulai dinamis untuk Speed Sync

local function trackConnection(conn)
	table.insert(scriptConnections, conn)
	return conn
end

-- ============================================
-- GUI ELEMENTS (Mendukung StarterPlayerScripts & StarterGui)
-- ============================================
local playerGui = player:WaitForChild("PlayerGui")
local gui = script.Parent:IsA("ScreenGui") and script.Parent or playerGui:WaitForChild("EmoteGui")
gui.ResetOnSpawn = false

local mainframe = gui:WaitForChild("MainFrame")
local preloadLabel = Instance.new("TextLabel")
preloadLabel.Name = "PreloadStatus"
preloadLabel.Size = UDim2.new(1, 0, 1, 0)
preloadLabel.Position = UDim2.new(0, 0, 0, 0)
preloadLabel.AnchorPoint = Vector2.new(0, 0)
preloadLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
preloadLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
preloadLabel.Text = "Preloading animations..."
preloadLabel.TextSize = 14
preloadLabel.Font = Enum.Font.Montserrat
preloadLabel.Visible = false
preloadLabel.Parent = mainframe

-- 🖥️ PENYESUAIAN UKURAN PC (DANCE KEGEDEAN)
local isPC = not UserInputService.TouchEnabled or UserInputService.KeyboardEnabled
if isPC then
	local pcScale = mainframe:FindFirstChild("PCScale") or Instance.new("UIScale")
	pcScale.Name = "PCScale"
	pcScale.Scale = 0.85
	pcScale.Parent = mainframe
end

local containerframe = mainframe:WaitForChild("Container")
local controlframe = mainframe:WaitForChild("Control")
local unsyncframe = mainframe:WaitForChild("UnsyncFrame")
local containerlist = containerframe:WaitForChild("ContainerList")
local templateframe = containerlist:WaitForChild("TemplateBtn") 
local danceBtn = controlframe:WaitForChild("Dance")
local favoriteBtn = controlframe:WaitForChild("Favorite")
local poseBtn = controlframe:WaitForChild("Pose")
local unsyncBtn = unsyncframe:WaitForChild("UnsyncBtn")
local dancelabel = unsyncframe:WaitForChild("DanceLabel")
local searchBox = mainframe:WaitForChild("SearchBox")
local notifframe = gui:WaitForChild("NotificationFrame")
local notiflabel = notifframe:WaitForChild("NotificationText")

local speedFrame = mainframe:FindFirstChild("SpeedFrame")
local speedBar = speedFrame and speedFrame:FindFirstChild("speedBar")
local speedSlider = speedBar and speedBar:FindFirstChild("speedPosition")
local speedButton = speedSlider and speedSlider:FindFirstChild("Button")
local speedtext = speedFrame and speedFrame:FindFirstChild("TextLabel")

-- ============================================
-- VARIABLES & CONSTANTS
-- ============================================
local SPEED_MIN = 0.1
local SPEED_MAX = 3.0
local SPEED_DEFAULT = 1.0

-- 🔥 Smooth blend transition (0.5 detik) agar setiap pergantian dance mulus mengalir tanpa patah
local FADE_TIME = 0.5

local notificationQueue = {}
local isShowingNotification = false

local allButtons = {}
local emoteIdCache = {}
local favoritedAnimations = {}

local currentAnimation = nil
local currentCategory = "Dance"
local searchQuery = ""
local currentSpeed = SPEED_DEFAULT

local inputLock = false
local pendingRequest = false
local isSyncing = false
local setDrawer = nil
local updateLeaderDanceIndicator = nil
local currentLeaderName = nil
local localSyncTrack = nil
local localAnimTrack = nil
local syncUpdateConnection = nil

local savedLocalEmoteData = nil
local animationStarted -- Forward Declaration

local lastEmoteClickTime = 0 

-- ============================================
-- CORE ANIMATION & STATE CONTROL
-- ============================================
local function setAnimateEnabled(character, enabled)
	if not character then return end
	character:SetAttribute("AnimateDisabled", not enabled)
end

local function killGhostAnimation(animator, fade, excludeTrack)
	local f = fade or FADE_TIME
	pcall(function()
		if not animator or not animator.Parent then return end
		if animator.Parent.Parent ~= player.Character then return end 
		for _, t in ipairs(animator:GetPlayingAnimationTracks()) do
			if t ~= excludeTrack and t.Animation and emoteIdCache[t.Animation.AnimationId] then
				t:Stop(f)
			end
		end
	end)
end

local function suppressNativeAnimations(animator, fade)
	-- Fungsi ini sengaja dikosongkan sesuai revisi
end

local function freezeHumanoidForPose(character, freeze)
	if not character then return end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	if freeze then
		humanoid:ChangeState(Enum.HumanoidStateType.None)
	else
		if humanoid:GetState() == Enum.HumanoidStateType.None then
			humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
	end
end

local function isCurrentAnimPose()
	if not currentAnimation then return false end
	for _, data in ipairs(allButtons) do
		if data.button == currentAnimation and data.category == "Pose" then
			return true
		end
	end
	return false
end

local function restoreCharacterAnimations(character)
	if character ~= player.Character then return end

	if not character then return end
	setAnimateEnabled(character, true)
	freezeHumanoidForPose(character, false)

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")

	if animator then
		pcall(function()
			for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
				if track.Animation and not emoteIdCache[track.Animation.AnimationId] then
					track:AdjustSpeed(1)
					track:AdjustWeight(1)
				end
			end
		end)
	end

	if humanoid then
		task.defer(function()
			if character:GetAttribute("AnimateDisabled") then return end
			pcall(function()
				local state = humanoid:GetState()
				if state == Enum.HumanoidStateType.None then return end
				humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
				task.defer(function()
					pcall(function() humanoid:ChangeState(state) end)
				end)
			end)
		end)
	end
end

-- ============================================
-- GUI HELPER FUNCTIONS
-- ============================================
local function showNotification(message, duration, bgColor)
	table.insert(notificationQueue, { message = message, duration = duration or 3, bgColor = bgColor or Color3.fromRGB(50, 150, 255) })

	if not isShowingNotification then
		task.spawn(function()
			while #notificationQueue > 0 and isScriptActive do
				isShowingNotification = true
				local notif = table.remove(notificationQueue, 1)
				notiflabel.Text = notif.message
				notifframe.BackgroundColor3 = notif.bgColor

				notifframe.Position = UDim2.new(0.5, 0, 0.1, 0)
				UIAnimator.Open(notifframe)
				task.wait(notif.duration)
				UIAnimator.Close(notifframe)
				task.wait(0.3)
			end
			isShowingNotification = false
		end)
	end
end

trackConnection(syncNotificationRE.OnClientEvent:Connect(function(notifType, leaderName)
	if notifType == "sync_success" then
		local leaderPlayer = Players:FindFirstChild(leaderName)
		local displayName = leaderPlayer and leaderPlayer.DisplayName or leaderName
		showNotification("Coordinate dance are apply to " .. displayName, 2.5, Color3.fromRGB(0, 0, 0))
	elseif notifType == "unsync_success" then
		showNotification("Unsynced", 2, Color3.fromRGB(0, 0, 0))
	elseif notifType == "leader_left" then
		showNotification("LEAD " .. leaderName .. " meninggalkan server", 4, Color3.fromRGB(200, 30, 30))
		if player.Character then
			restoreCharacterAnimations(player.Character)
			if localSyncTrack then 
				localSyncTrack:Stop(FADE_TIME) 
				localSyncTrack = nil 
			end
		end
	elseif notifType == "leader_blocked" then
		showNotification("You are a Dance Leader!\nCannot sync to followers", 3, Color3.fromRGB(0, 0, 0))
	elseif notifType == "circular_blocked" then
		showNotification("Cannot create circular coordinate dance", 2.5, Color3.fromRGB(0, 0, 0))
	end
end))

local previousAnimation = nil
local function updateButtonVisuals()
	if previousAnimation then
		local originalColor = Color3.fromRGB(34, 34, 38)
		for _, data in ipairs(allButtons) do
			if data.button == previousAnimation then
				originalColor = data.originalColor
				break
			end
		end
		previousAnimation.BackgroundColor3 = originalColor
	end

	if currentAnimation then
		currentAnimation.BackgroundColor3 = Color3.fromRGB(50, 52, 60) 
	end

	previousAnimation = currentAnimation
end

local function loadSavedFavorites()
	local stringVal = player:WaitForChild("SavedFavoritedAnimations", 15)
	local savedData = stringVal and stringVal.Value or nil

	if savedData and typeof(savedData) == "string" then
		local ok, decoded = pcall(HttpService.JSONDecode, HttpService, savedData)
		favoritedAnimations = (ok and typeof(decoded) == "table") and decoded or {}
	else
		favoritedAnimations = {}
	end
end

local favoritesLoaded = false
task.spawn(function() loadSavedFavorites() favoritesLoaded = true end)

local function saveFavoritedAnimations() 
	updateFavoritedAnimationsEventRE:FireServer(HttpService:JSONEncode(favoritedAnimations)) 
end

local animByIdCache = {}
local function findAnimById(danceId)
	if not danceId or danceId == "" then return nil end
	if animByIdCache[danceId] then return animByIdCache[danceId] end

	local numId = tostring(danceId):match("%d+")

	for _, anim in ipairs(emotesFolder:GetChildren()) do
		if anim:IsA("Animation") and anim.AnimationId == danceId then 
			animByIdCache[danceId] = anim
			return anim 
		end
	end
	local poseFolder = emotesFolder:FindFirstChild("Pose")
	if poseFolder then
		for _, anim in ipairs(poseFolder:GetChildren()) do
			if anim:IsA("Animation") and anim.AnimationId == danceId then 
				animByIdCache[danceId] = anim
				return anim 
			end
		end
	end

	if numId then
		for _, anim in ipairs(emotesFolder:GetDescendants()) do
			if anim:IsA("Animation") and anim.AnimationId:match("%d+") == numId then
				animByIdCache[danceId] = anim
				return anim
			end
		end
	end

	-- Fallback instance agar sync tidak pernah gagal
	local fallbackAnim = Instance.new("Animation")
	fallbackAnim.Name = "DynamicSyncAnim"
	fallbackAnim.AnimationId = danceId
	animByIdCache[danceId] = fallbackAnim
	return fallbackAnim
end

-- ============================================
-- THE UNIVERSAL HIVE MIND (Observer Tunggal)
-- ============================================
local globalSyncListeners = setmetatable({}, { __mode = "k" })

local function applyDance(char, danceId, speed, startTime, leaderName, isSpam)
	if char ~= player.Character then return end 

	speed = speed or 1

	local animator = char:FindFirstChild("Humanoid") and char.Humanoid:FindFirstChild("Animator")
	if not animator then return end

	local applyTicket = (char:GetAttribute("ApplyTicket") or 0) + 1
	char:SetAttribute("ApplyTicket", applyTicket)

	-- ⚡ JIKA DANCE INI SUDAH SEDANG DIMAINKAN: Cukup update TimePosition & Speed tanpa stop/replay!
	if localSyncTrack and localSyncTrack.Animation and localSyncTrack.Animation.AnimationId == danceId and localSyncTrack.IsPlaying then
		if startTime and localSyncTrack.Length > 0 then
			local finalTime = workspace:GetServerTimeNow()
			local exactPos = ((finalTime - startTime) * speed) % localSyncTrack.Length
			pcall(function() localSyncTrack.TimePosition = exactPos end)
		end
		pcall(function() localSyncTrack:AdjustSpeed(speed) end)
		return
	end

	local actualFade = isSpam and 0 or FADE_TIME

	if updateLeaderDanceIndicator then
		updateLeaderDanceIndicator()
	end
	if dancelabel then
		if danceId and emoteIdCache[danceId] then
			dancelabel.Text = " " .. emoteIdCache[danceId]
		else
			local displayName = leaderName or "Leader"
			local lp = Players:FindFirstChild(leaderName or "")
			if lp then displayName = lp.DisplayName end
			dancelabel.Text = " " .. displayName .. "'s Dance"
		end
	end

	if not danceId or danceId == "" then
		if localSyncTrack then
			localSyncTrack:Stop(actualFade)
			localSyncTrack = nil
		end

		killGhostAnimation(animator, actualFade)
		restoreCharacterAnimations(char)

		if not isSyncing then
			if savedLocalEmoteData then
				local saved = savedLocalEmoteData
				savedLocalEmoteData = nil
				task.delay(0.05, function()
					if isScriptActive then animationStarted(saved.animation, saved.button) end
				end)
			end
		end
		return
	end

	local targetAnim = findAnimById(danceId)
	if not targetAnim then return end

	-- Matikan default animate Roblox agar pose berdiri tidak menyusup
	setAnimateEnabled(char, false)

	local oldSyncTrack = localSyncTrack
	if localAnimTrack then
		localAnimTrack:Stop(actualFade)
		localAnimTrack = nil
	end

	local track = AnimatorUtils.getOrCreateTrack(animator, targetAnim)
	if not track then setAnimateEnabled(char, true) return end

	localSyncTrack = track
	track.Priority = Enum.AnimationPriority.Action3

	-- 🔥 SET POSITION SEBELUM / SAAT PLAY AGAR LANGSUNG SINKRON DARI DETIK PERTAMA
	if startTime and track.Length > 0 then
		local exactPos = ((workspace:GetServerTimeNow() - startTime) * speed) % track.Length
		pcall(function() track.TimePosition = exactPos end)
	end

	-- Mulai putar animasi baru secara instan
	track:Play(actualFade, 1, speed)

	-- Hentikan track lama SETELAH track baru aktif berputar (Crossfade murni)
	if oldSyncTrack and oldSyncTrack ~= track then
		oldSyncTrack:Stop(actualFade)
	end
	killGhostAnimation(animator, actualFade, track)

	local capturedTicket = applyTicket
	task.spawn(function()
		local timeout = os.clock() + 3
		while track and track.Length == 0 and os.clock() < timeout do 
			if not isScriptActive then return end
			RunService.RenderStepped:Wait() 
		end
		if char:GetAttribute("ApplyTicket") ~= capturedTicket then return end

		if startTime and track.Length > 0 then
			local finalTime = workspace:GetServerTimeNow()
			local exactPos = ((finalTime - startTime) * speed) % track.Length
			if math.abs(track.TimePosition - exactPos) > 0.03 then
				pcall(function() track.TimePosition = exactPos end)
			end
		end

		track:AdjustSpeed(speed) 

		task.delay(actualFade + 0.02, function()
			if not isScriptActive or char:GetAttribute("ApplyTicket") ~= capturedTicket then return end
			suppressNativeAnimations(animator, 0)
		end)
	end)
end

local function monitorPlayerCharacter(targetPlayer)
	local function onCharacterAdded(char)
		if globalSyncListeners[char] then return end
		globalSyncListeners[char] = true

		local humanoid = char:WaitForChild("Humanoid", 10)
		if not humanoid then return end

		local animator = humanoid:WaitForChild("Animator", 10)
		if not animator then return end

		local function forceSnapCharacterDance(track)
			if not track or track.Length == 0 then return end

			-- 🔥 BACA FAKE WAKTU MULAI
			local startTime = fakeStartTimes[char] or char:GetAttribute("DanceStartTime")
			local speed = char:GetAttribute("DanceSpeed") or 1
			local currentDanceId = char:GetAttribute("CurrentDanceID")
			local syncingTo = char:GetAttribute("Syncing")

			-- 🔥 Jangan snap follower di sini: biarkan Anti-Drift loop yang menyelaraskan dengan catchUpSpeed secara mulus tanpa sentakan patah
			if syncingTo == player.Name then return end 

			if currentDanceId and track.Animation and track.Animation.AnimationId ~= currentDanceId then return end

			if syncingTo and syncingTo ~= "" then
				local leader = Players:FindFirstChild(syncingTo)
				if leader and leader.Character then
					startTime = fakeStartTimes[leader.Character] or leader.Character:GetAttribute("DanceStartTime") or startTime
					speed = leader.Character:GetAttribute("DanceSpeed") or speed
				end
			end

			if startTime then
				local elapsed = workspace:GetServerTimeNow() - startTime
				local exactPos = (elapsed * speed) % track.Length
				if exactPos > 0 and math.abs(track.TimePosition - exactPos) > 0.03 then
					pcall(function() track.TimePosition = exactPos end)
				end
			end

			pcall(function() track:AdjustSpeed(speed) end)
		end

		animator.AnimationPlayed:Connect(function(track)
			if char:GetAttribute("AnimateDisabled") then
				if not (track.Animation and emoteIdCache[track.Animation.AnimationId]) then
					local prio = track.Priority
					if prio == Enum.AnimationPriority.Core or prio == Enum.AnimationPriority.Idle or prio == Enum.AnimationPriority.Movement or prio == Enum.AnimationPriority.Action3 then
						track:AdjustWeight(0.001)
					end
				end
			end

			if char ~= player.Character and track.Animation and emoteIdCache[track.Animation.AnimationId] then
				task.spawn(function()
					local maxAttempts = 50
					local attempts = 0

					while track and track.Length == 0 and attempts < maxAttempts do 
						if not isScriptActive then return end
						attempts += 1
						task.wait(0.1) 
					end

					if track and track.Length > 0 then
						forceSnapCharacterDance(track)
					end
				end)
			end
		end)

		local function onAttributeChanged()
			if char == player.Character then return end
			for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
				if track.Animation and emoteIdCache[track.Animation.AnimationId] then
					forceSnapCharacterDance(track)
				end
			end
		end

		local function syncToLeader()
			local leaderName = char:GetAttribute("Syncing")
			if leaderName and leaderName ~= "" then
				local leaderPlayer = Players:FindFirstChild(leaderName)
				local leaderChar = leaderPlayer and leaderPlayer.Character
				if leaderChar then
					local danceId = leaderChar:GetAttribute("CurrentDanceID")
					local speed = leaderChar:GetAttribute("DanceSpeed") or 1
					local startTime = leaderChar:GetAttribute("DanceStartTime")
					applyDance(char, danceId, speed, startTime, leaderName, false)
				else
					applyDance(char, nil, 1, nil, leaderName, false)
				end
			else
				applyDance(char, nil, 1, nil, nil, false)
			end
		end

		local function broadcastLeaderState(isSpamTrigger)
			local danceId = char:GetAttribute("CurrentDanceID")
			local speed = char:GetAttribute("DanceSpeed") or 1
			local startTime = char:GetAttribute("DanceStartTime")

			if char == player.Character then return end
			for _, p in ipairs(Players:GetPlayers()) do
				if p.Character and p.Character:GetAttribute("Syncing") == char.Name then
					applyDance(p.Character, danceId, speed, startTime, char.Name, isSpamTrigger)
				end
			end
		end

		-- ============================================
		-- 🔥 REVISI MUTLAK: DISTRIBUSI SPEED MULUS KE SEMUA FOLLOWER!
		-- ============================================
		char:GetAttributeChangedSignal("DanceStartTime"):Connect(function()
			fakeStartTimes[char] = char:GetAttribute("DanceStartTime")
			onAttributeChanged()
			broadcastLeaderState(false)
		end)

		char:GetAttributeChangedSignal("CurrentDanceID"):Connect(function()
			onAttributeChanged()
			broadcastLeaderState(false)
		end)

		char:GetAttributeChangedSignal("Syncing"):Connect(function()
			onAttributeChanged()
			syncToLeader()
		end)

		char:GetAttributeChangedSignal("SpamNonce"):Connect(function() 
			broadcastLeaderState(true) 
		end)

		char:GetAttributeChangedSignal("DanceSpeed"):Connect(function()
			local newSpeed = char:GetAttribute("DanceSpeed") or 1
			local currentDanceId = char:GetAttribute("CurrentDanceID")

			if char == player.Character then 
				if localAnimTrack and localAnimTrack.IsPlaying and newSpeed > 0 then
					fakeStartTimes[char] = workspace:GetServerTimeNow() - (localAnimTrack.TimePosition / newSpeed)
				end
			else
				local charAnimator = char:FindFirstChild("Humanoid") and char.Humanoid:FindFirstChild("Animator")
				if charAnimator and currentDanceId then
					for _, track in ipairs(charAnimator:GetPlayingAnimationTracks()) do
						if track.Animation and track.Animation.AnimationId == currentDanceId then
							local currentPos = track.TimePosition
							if newSpeed > 0 then
								fakeStartTimes[char] = workspace:GetServerTimeNow() - (currentPos / newSpeed)
							end
							track:AdjustSpeed(newSpeed)
						end
					end
				end

				if player.Character and player.Character:GetAttribute("Syncing") == char.Name then
					if localSyncTrack and localSyncTrack.IsPlaying and newSpeed > 0 then
						fakeStartTimes[player.Character] = workspace:GetServerTimeNow() - (localSyncTrack.TimePosition / newSpeed)
						localSyncTrack:AdjustSpeed(newSpeed)

						if currentSpeed ~= newSpeed then
							currentSpeed = newSpeed
							if speedtext then 
								speedtext.Text = string.format("%.1fx", math.floor(currentSpeed * 10 + 0.5) / 10) 
							end
							if speedSlider and speedBar then
								local scale = (newSpeed - SPEED_MIN) / (SPEED_MAX - SPEED_MIN)
								speedSlider.Position = UDim2.fromScale(scale, 0.5)
							end
						end
					end
				end
			end

			for _, p in ipairs(Players:GetPlayers()) do
				local followerChar = p.Character
				if followerChar and followerChar ~= player.Character and followerChar:GetAttribute("Syncing") == char.Name then
					local followerAnimator = followerChar:FindFirstChild("Humanoid") and followerChar.Humanoid:FindFirstChild("Animator")
					if followerAnimator then
						for _, track in ipairs(followerAnimator:GetPlayingAnimationTracks()) do
							if track.Animation and (not currentDanceId or track.Animation.AnimationId == currentDanceId) then
								local currentPos = track.TimePosition
								if newSpeed > 0 then
									fakeStartTimes[followerChar] = workspace:GetServerTimeNow() - (currentPos / newSpeed)
								end
								track:AdjustSpeed(newSpeed)
							end
						end
					end
				end
			end
		end)

		char:GetAttributeChangedSignal("AnimateDisabled"):Connect(function()
			if char:GetAttribute("AnimateDisabled") then
				for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
					if track.Animation and emoteIdCache[track.Animation.AnimationId] then continue end
					local prio = track.Priority
					if prio == Enum.AnimationPriority.Core or prio == Enum.AnimationPriority.Idle or prio == Enum.AnimationPriority.Movement or prio == Enum.AnimationPriority.Action3 then
						if track.WeightCurrent > 0.01 then track:AdjustWeight(0.001) end
					end
				end
			end
		end)

		task.spawn(function()
			if char:GetAttribute("Syncing") and char:GetAttribute("Syncing") ~= "" then
				syncToLeader()
			elseif char:GetAttribute("CurrentDanceID") then
				broadcastLeaderState(false)
			end
		end)
	end
	if targetPlayer.Character then onCharacterAdded(targetPlayer.Character) end
	trackConnection(targetPlayer.CharacterAdded:Connect(onCharacterAdded))
end

for _, p in ipairs(Players:GetPlayers()) do monitorPlayerCharacter(p) end
trackConnection(Players.PlayerAdded:Connect(monitorPlayerCharacter))

-- ============================================
-- GUI & SYNC MANAGEMENT (FULL BLACK BLOCKING OVERLAY)
-- ============================================

local function getDanceNameFromId(danceId)
	if not danceId or danceId == "" then return nil end
	if emoteIdCache[danceId] then return emoteIdCache[danceId] end
	local numId = tostring(danceId):match("%d+")
	if numId then
		for cachedId, name in pairs(emoteIdCache) do
			if tostring(cachedId):match("%d+") == numId then
				return name
			end
		end
		for _, anim in ipairs(emotesFolder:GetDescendants()) do
			if anim:IsA("Animation") and anim.AnimationId:match("%d+") == numId then
				emoteIdCache[danceId] = anim.Name
				return anim.Name
			end
		end
	end
	return nil
end

-- 🛡️ KONFIGURASI OVERLAY BLOK FULL HITAM
unsyncframe.Size = UDim2.new(1, 0, 1, 0)
unsyncframe.Position = UDim2.new(0, 0, 0, 0)
unsyncframe.AnchorPoint = Vector2.new(0, 0)
unsyncframe.BackgroundColor3 = Color3.fromRGB(12, 12, 14)
unsyncframe.BackgroundTransparency = 0
unsyncframe.BorderSizePixel = 0
unsyncframe.ZIndex = 100
unsyncframe.Active = true
unsyncframe.Visible = false

local overlayCorner = unsyncframe:FindFirstChildOfClass("UICorner") or Instance.new("UICorner")
overlayCorner.CornerRadius = UDim.new(0, 12)
overlayCorner.Parent = unsyncframe

-- TULISAN SYNC TO SIAPA
local syncTitleLabel = unsyncframe:FindFirstChild("SyncTitle") or Instance.new("TextLabel")
syncTitleLabel.Name = "SyncTitle"
syncTitleLabel.Size = UDim2.new(1, -40, 0, 32)
syncTitleLabel.Position = UDim2.new(0.5, 0, 0.20, 0)
syncTitleLabel.AnchorPoint = Vector2.new(0.5, 0.5)
syncTitleLabel.BackgroundTransparency = 1
syncTitleLabel.Font = Enum.Font.MontserratBold
syncTitleLabel.TextSize = 20
syncTitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
syncTitleLabel.Text = "SYNC TO ..."
syncTitleLabel.ZIndex = 102
syncTitleLabel.Parent = unsyncframe

local syncSubtitleLabel = unsyncframe:FindFirstChild("SyncSubtitle") or Instance.new("TextLabel")
syncSubtitleLabel.Name = "SyncSubtitle"
syncSubtitleLabel.Size = UDim2.new(1, -40, 0, 20)
syncSubtitleLabel.Position = UDim2.new(0.5, 0, 0.27, 0)
syncSubtitleLabel.AnchorPoint = Vector2.new(0.5, 0.5)
syncSubtitleLabel.BackgroundTransparency = 1
syncSubtitleLabel.Font = Enum.Font.MontserratMedium
syncSubtitleLabel.TextSize = 14
syncSubtitleLabel.TextColor3 = Color3.fromRGB(160, 160, 160)
syncSubtitleLabel.Text = "@..."
syncSubtitleLabel.ZIndex = 102
syncSubtitleLabel.Parent = unsyncframe

-- KARTU INDIKATOR DANCE YANG LEAD PAKE
local danceCard = unsyncframe:FindFirstChild("DanceCard") or Instance.new("Frame")
danceCard.Name = "DanceCard"
danceCard.Size = UDim2.new(0.85, 0, 0, 95)
danceCard.Position = UDim2.new(0.5, 0, 0.50, 0)
danceCard.AnchorPoint = Vector2.new(0.5, 0.5)
danceCard.BackgroundColor3 = Color3.fromRGB(22, 22, 26)
danceCard.BackgroundTransparency = 0
danceCard.BorderSizePixel = 0
danceCard.ZIndex = 101
danceCard.Parent = unsyncframe

local cardCorner = danceCard:FindFirstChildOfClass("UICorner") or Instance.new("UICorner")
cardCorner.CornerRadius = UDim.new(0, 10)
cardCorner.Parent = danceCard

local cardStroke = danceCard:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke")
cardStroke.Color = Color3.fromRGB(55, 55, 60)
cardStroke.Thickness = 1
cardStroke.Parent = danceCard

local cardCaption = danceCard:FindFirstChild("CardCaption") or Instance.new("TextLabel")
cardCaption.Name = "CardCaption"
cardCaption.Size = UDim2.new(1, -20, 0, 20)
cardCaption.Position = UDim2.new(0.5, 0, 0.24, 0)
cardCaption.AnchorPoint = Vector2.new(0.5, 0.5)
cardCaption.BackgroundTransparency = 1
cardCaption.Font = Enum.Font.MontserratBold
cardCaption.TextSize = 11
cardCaption.TextColor3 = Color3.fromRGB(160, 160, 160)
cardCaption.Text = "LEADER'S CURRENT DANCE"
cardCaption.ZIndex = 102
cardCaption.Parent = danceCard

dancelabel.Size = UDim2.new(1, -20, 0, 40)
dancelabel.Position = UDim2.new(0.5, 0, 0.65, 0)
dancelabel.AnchorPoint = Vector2.new(0.5, 0.5)
dancelabel.BackgroundTransparency = 1
dancelabel.Font = Enum.Font.MontserratBold
dancelabel.TextSize = 16
dancelabel.TextColor3 = Color3.fromRGB(255, 255, 255)
dancelabel.TextScaled = true
dancelabel.ZIndex = 102
dancelabel.Parent = danceCard

-- TOMBOL UNSYNC (STOP SYNC)
unsyncBtn.Size = UDim2.new(0.75, 0, 0, 42)
unsyncBtn.Position = UDim2.new(0.5, 0, 0.82, 0)
unsyncBtn.AnchorPoint = Vector2.new(0.5, 0.5)
unsyncBtn.BackgroundColor3 = Color3.fromRGB(28, 28, 32)
unsyncBtn.BackgroundTransparency = 0
unsyncBtn.BorderSizePixel = 0
unsyncBtn.Font = Enum.Font.MontserratBold
unsyncBtn.TextSize = 14
unsyncBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
unsyncBtn.Text = "Stop Sync"
unsyncBtn.AutoButtonColor = false
unsyncBtn.ZIndex = 103
unsyncBtn.Parent = unsyncframe

local btnCorner = unsyncBtn:FindFirstChildOfClass("UICorner") or Instance.new("UICorner")
btnCorner.CornerRadius = UDim.new(0, 8)
btnCorner.Parent = unsyncBtn

local btnStroke = unsyncBtn:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke")
btnStroke.Color = Color3.fromRGB(140, 140, 140)
btnStroke.Thickness = 1
btnStroke.Parent = unsyncBtn

-- TOMBOL CLOSE OVERLAY AGAR PLAYER TETAP BISA MENUTUP MENU DANCE
local overlayCloseBtn = unsyncframe:FindFirstChild("OverlayCloseBtn") or Instance.new("TextButton")
overlayCloseBtn.Name = "OverlayCloseBtn"
overlayCloseBtn.Size = UDim2.new(0, 32, 0, 32)
overlayCloseBtn.Position = UDim2.new(1, -12, 0, 12)
overlayCloseBtn.AnchorPoint = Vector2.new(1, 0)
overlayCloseBtn.BackgroundTransparency = 1
overlayCloseBtn.Font = Enum.Font.MontserratBold
overlayCloseBtn.TextSize = 18
overlayCloseBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
overlayCloseBtn.Text = "✕"
overlayCloseBtn.AutoButtonColor = false
overlayCloseBtn.ZIndex = 105
overlayCloseBtn.Parent = unsyncframe

overlayCloseBtn.MouseButton1Click:Connect(function()
	if setDrawer then
		setDrawer(false)
	else
		mainframe.Visible = false
	end
end)

local leaderDanceConn = nil

updateLeaderDanceIndicator = function()
	if not isSyncing or not currentLeaderName then return end
	local leader = Players:FindFirstChild(currentLeaderName)
	local leaderChar = leader and leader.Character
	local danceId = leaderChar and leaderChar:GetAttribute("CurrentDanceID")

	if danceId and danceId ~= "" then
		local danceName = getDanceNameFromId(danceId)
		dancelabel.Text = "🕺 " .. (danceName or "Dancing...")
	else
		dancelabel.Text = "Idle (Not Dancing)"
	end
end

local function bindLeaderDanceListener(leaderPlayer)
	if leaderDanceConn then leaderDanceConn:Disconnect() leaderDanceConn = nil end
	if not leaderPlayer then return end

	local function onLeaderChar(char)
		if leaderDanceConn then leaderDanceConn:Disconnect() leaderDanceConn = nil end
		leaderDanceConn = char:GetAttributeChangedSignal("CurrentDanceID"):Connect(updateLeaderDanceIndicator)
		updateLeaderDanceIndicator()
	end

	if leaderPlayer.Character then onLeaderChar(leaderPlayer.Character) end
	trackConnection(leaderPlayer.CharacterAdded:Connect(onLeaderChar))
end

local function setMenuElementsBlocked(blocked)
	containerframe.Visible = not blocked
	controlframe.Visible = not blocked
	searchBox.Visible = not blocked
	local spFrame = mainframe:FindFirstChild("SpeedFrame")
	if spFrame then spFrame.Visible = not blocked end
end

local function updateUnsyncFrame()
	if not player.Character then 
		if unsyncframe.Visible then 
			unsyncframe.Visible = false
			setMenuElementsBlocked(false)
		end
		return 
	end

	local syncTarget = player.Character:GetAttribute("Syncing")
	if syncTarget and syncTarget ~= "" then
		isSyncing = true
		currentLeaderName = syncTarget
		local leaderPlayer = Players:FindFirstChild(syncTarget)
		local displayName = leaderPlayer and leaderPlayer.DisplayName or syncTarget

		syncTitleLabel.Text = "SYNC TO " .. string.upper(displayName)
		syncSubtitleLabel.Text = "@" .. syncTarget

		bindLeaderDanceListener(leaderPlayer)
		updateLeaderDanceIndicator()

		-- 🔥 BLOKIR SELURUH MENU DANCE: SEMBUNYIKAN MENU & TAMPILKAN OVERLAY HITAM
		setMenuElementsBlocked(true)
		unsyncframe.Visible = true
	else
		if leaderDanceConn then leaderDanceConn:Disconnect() leaderDanceConn = nil end
		
		-- 🔥 KEMBALIKAN MENU DANCE SEPERTI SEMULA
		unsyncframe.Visible = false
		setMenuElementsBlocked(false)

		isSyncing = false
		currentLeaderName = nil
		if localSyncTrack then 
			localSyncTrack:Stop(FADE_TIME) 
			localSyncTrack = nil 
		end
		if player.Character then
			restoreCharacterAnimations(player.Character)
		end
	end
end

-- Polling background untuk jaminan 100% update live
task.spawn(function()
	while isScriptActive do
		task.wait(0.25)
		if isSyncing and unsyncframe.Visible then
			updateLeaderDanceIndicator()
		end
	end
end)

unsyncBtn.MouseButton1Click:Connect(function()
	if inputLock or pendingRequest or not isSyncing or not currentLeaderName then return end
	inputLock = true
	local leaderPlayer = Players:FindFirstChild(currentLeaderName)
	if not leaderPlayer then
		if player.Character then player.Character:SetAttribute("Syncing", nil) end
		updateUnsyncFrame() inputLock = false return
	end
	if localSyncTrack then 
		localSyncTrack:Stop(FADE_TIME) 
		localSyncTrack = nil 
	end
	startSyncRE:FireServer(leaderPlayer, false)
	local clickSound = ReplicatedStorage:FindFirstChild("Sounds") and ReplicatedStorage.Sounds:FindFirstChild("minimal-pop-click-ui")
	if clickSound then clickSound:Play() end
	task.wait(0.1)
	updateUnsyncFrame()
	task.delay(0.3, function() inputLock = false end)
end)

local function setupSyncMonitoring()
	if syncUpdateConnection then syncUpdateConnection:Disconnect() syncUpdateConnection = nil end
	if not player.Character then player.CharacterAdded:Wait() end
	updateUnsyncFrame()

	syncUpdateConnection = player.Character:GetAttributeChangedSignal("Syncing"):Connect(function()
		updateUnsyncFrame()
		if isSyncing then
			if not savedLocalEmoteData and currentAnimation and localAnimTrack then
				local savedAnim = nil
				for _, data in ipairs(allButtons) do
					if data.button == currentAnimation then
						savedAnim = data.animation
						break
					end
				end
				if savedAnim then
					savedLocalEmoteData = {
						animation = savedAnim,
						button = currentAnimation,
						speed = currentSpeed,
					}
				end
			end
		end
	end)
end
setupSyncMonitoring()
trackConnection(player.CharacterAdded:Connect(function() task.wait(1) if isScriptActive then setupSyncMonitoring() end end))

-- ============================================
-- ANIMATION STARTED (Leader / Solo)
-- ============================================
function animationStarted(animation, button)
	if inputLock or pendingRequest then return end

	inputLock = true
	task.delay(0.01, function() inputLock = false end)

	local currentTime = os.clock()
	local character = player.Character
	local animator = character and character:FindFirstChild("Humanoid") and character.Humanoid:FindFirstChild("Animator")

	local timeSinceLastClick = currentTime - lastEmoteClickTime
	local isSpamming = (timeSinceLastClick < 0.7)

	if currentAnimation == button then
		if isSpamming then
			lastEmoteClickTime = os.clock()
			if animator then
				if localAnimTrack and localAnimTrack.Animation and localAnimTrack.Animation.AnimationId == animation.AnimationId then
					localAnimTrack.TimePosition = 0
				else
					local isPose = isCurrentAnimPose()
					local char = character
					setAnimateEnabled(character, false)

					local oldTrack = localAnimTrack
					localAnimTrack = AnimatorUtils.getOrCreateTrack(animator, animation)
					if localAnimTrack then
						localAnimTrack.TimePosition = 0
						localAnimTrack.Priority = Enum.AnimationPriority.Action3
						localAnimTrack:Play(0, 1, currentSpeed)

						if oldTrack and oldTrack ~= localAnimTrack then
							oldTrack:Stop(0)
						end

						local capturedTicket = (char:GetAttribute("ApplyTicket") or 0)
						task.spawn(function()
							task.wait(0.05)
							if not isScriptActive or char:GetAttribute("ApplyTicket") ~= capturedTicket then return end
							freezeHumanoidForPose(char, isPose)
						end)
					end
				end
			end
			animationStartRE:FireServer(animation.AnimationId, true, currentSpeed, 0, true, workspace:GetServerTimeNow())
		else
			currentAnimation = nil
			lastEmoteClickTime = 0
			updateButtonVisuals()
			savedLocalEmoteData = nil
			if animator and localAnimTrack then
				localAnimTrack:Stop(FADE_TIME)
				localAnimTrack = nil
			end
			restoreCharacterAnimations(character)
			animationStartRE:FireServer(animation.AnimationId, false, currentSpeed, 0, false, workspace:GetServerTimeNow())
		end
	else
		-- 🔥 GANTI DANCE KE PILIHAN BARU (Smooth crossfade tanpa patah, tanpa flicker pose berdiri)
		savedLocalEmoteData = nil
		currentAnimation = button
		lastEmoteClickTime = os.clock()
		updateButtonVisuals()

		local actualFade = FADE_TIME

		if animator then
			local isPose = isCurrentAnimPose()
			local char = character
			setAnimateEnabled(character, false)

			local oldAnimTrack = localAnimTrack
			localAnimTrack = AnimatorUtils.getOrCreateTrack(animator, animation)
			if localAnimTrack then
				localAnimTrack.Priority = Enum.AnimationPriority.Action3
				localAnimTrack:Play(actualFade, 1, currentSpeed)

				if oldAnimTrack and oldAnimTrack ~= localAnimTrack then
					oldAnimTrack:Stop(actualFade)
				end
				killGhostAnimation(animator, actualFade, localAnimTrack)

				local capturedTicket = (char:GetAttribute("ApplyTicket") or 0)
				task.spawn(function()
					task.wait(actualFade + 0.02)
					if not isScriptActive or char:GetAttribute("ApplyTicket") ~= capturedTicket then return end
					freezeHumanoidForPose(char, isPose)
				end)
			end
		end
		animationStartRE:FireServer(animation.AnimationId, true, currentSpeed, actualFade, false, workspace:GetServerTimeNow())
	end
end

-- ============================================
-- GUI & BUTTON BUILDER
-- ============================================

local updateDisplay 

local function toggleFavorite(animation, button, favoriteIcon)
	favoritedAnimations[animation.Name] = not favoritedAnimations[animation.Name]
	favoriteIcon.Text = "★"
	favoriteIcon.TextColor3 = favoritedAnimations[animation.Name] and Color3.fromRGB(218, 165, 32) or Color3.fromRGB(75, 75, 80)
	saveFavoritedAnimations()
	if currentCategory == "Favorite" then updateDisplay() end
end

local function createEmoteButton(animation, category)
	local newButton = templateframe:Clone()
	newButton.Name = animation.Name
	newButton.Visible = true

	local danceTitle = newButton:FindFirstChild("DanceTitle")
	local favoriteIcon = newButton:FindFirstChild("FavoriteBtn")
	local originalColor = newButton.BackgroundColor3

	if danceTitle then
		danceTitle.Text = string.upper(animation.Name)
	end

	if favoriteIcon then
		favoriteIcon.Text = "★"
		favoriteIcon.TextColor3 = favoritedAnimations[animation.Name] and Color3.fromRGB(218, 165, 32) or Color3.fromRGB(75, 75, 80)
		favoriteIcon.MouseButton1Click:Connect(function()
			if inputLock then return end
			inputLock = true
			toggleFavorite(animation, newButton, favoriteIcon)
			task.delay(0.2, function() inputLock = false end)
		end)
	end

	if newButton:IsA("GuiButton") then
		newButton.MouseButton1Click:Connect(function()
			animationStarted(animation, newButton)
		end)
	end

	newButton.Parent = containerlist
	table.insert(allButtons, { button = newButton, animation = animation, category = category, name = animation.Name, originalColor = originalColor })
	return newButton
end

function updateDisplay()
	pcall(function()
		containerlist.CanvasPosition = Vector2.new(0, 0)
		for _, data in ipairs(allButtons) do
			local shouldShow = (currentCategory == "Favorite") and (favoritedAnimations[data.name] == true) or (currentCategory == data.category)
			if shouldShow and searchQuery ~= "" then 
				shouldShow = string.find(string.lower(data.name), string.lower(searchQuery)) ~= nil 
			end
			data.button.Visible = shouldShow
		end
		updateButtonVisuals()
	end)
end

local function setActiveCategory(category)
	currentCategory = category
	-- Active tab: Dark/Black with pure white text. Inactive tabs: Medium gray pill with silver text.
	danceBtn.BackgroundColor3 = (category == "Dance") and Color3.fromRGB(15, 15, 18) or Color3.fromRGB(68, 70, 75)
	danceBtn.TextColor3 = (category == "Dance") and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(215, 215, 220)

	poseBtn.BackgroundColor3 = (category == "Pose") and Color3.fromRGB(15, 15, 18) or Color3.fromRGB(68, 70, 75)
	poseBtn.TextColor3 = (category == "Pose") and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(215, 215, 220)

	favoriteBtn.BackgroundColor3 = (category == "Favorite") and Color3.fromRGB(15, 15, 18) or Color3.fromRGB(68, 70, 75)
	favoriteBtn.TextColor3 = (category == "Favorite") and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(215, 215, 220)

	updateDisplay()
end

danceBtn.MouseButton1Click:Connect(function() setActiveCategory("Dance") end)
poseBtn.MouseButton1Click:Connect(function() setActiveCategory("Pose") end)
favoriteBtn.MouseButton1Click:Connect(function() setActiveCategory("Favorite") end)
searchBox:GetPropertyChangedSignal("Text"):Connect(function() searchQuery = searchBox.Text updateDisplay() end)

-- ============================================
-- SPEED SLIDER (MOBILE & MULTI-TOUCH FIX)
-- ============================================
if speedSlider and speedBar and speedtext and speedButton then
	local isDraggingSpeed = false
	local activeInput = nil
	local speedSendDebounce = false
	local lastSentSpeed = SPEED_DEFAULT
	speedSlider.AnchorPoint = Vector2.new(0.5, 0.5)

	local function scaleToSpeed(scale) return math.floor((SPEED_MIN + scale * (SPEED_MAX - SPEED_MIN)) * 100 + 0.5) / 100 end
	local function speedToScale(speed) return (speed - SPEED_MIN) / (SPEED_MAX - SPEED_MIN) end

	local function sendSpeedToServer(speed)
		if speed == lastSentSpeed or speedSendDebounce then return end
		speedSendDebounce = true
		lastSentSpeed = speed
		changeSpeedRE:FireServer(speed)
		task.delay(0.05, function()
			speedSendDebounce = false
			if currentSpeed ~= lastSentSpeed then changeSpeedRE:FireServer(currentSpeed) lastSentSpeed = currentSpeed end
		end)
	end

	local targetScale = speedToScale(SPEED_DEFAULT)
	local currentScale = targetScale

	local function updateSlider(input)
		local posX = input.Position.X
		targetScale = math.clamp((posX - speedBar.AbsolutePosition.X) / speedBar.AbsoluteSize.X, 0, 1)
	end

	speedBar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			if isSyncing then showNotification("Cannot change speed while syncing", 2, Color3.fromRGB(0, 0, 0)) return end
			isDraggingSpeed = true
			activeInput = input
			updateSlider(input)
		end
	end)

	speedButton.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			if isSyncing then showNotification("Cannot change speed while syncing", 2, Color3.fromRGB(0, 0, 0)) return end
			isDraggingSpeed = true
			activeInput = input
		end
	end)

	trackConnection(UserInputService.InputChanged:Connect(function(input)
		if isDraggingSpeed then
			if input == activeInput or input.UserInputType == Enum.UserInputType.MouseMovement then
				updateSlider(input)
			end
		end
	end))

	trackConnection(UserInputService.InputEnded:Connect(function(input) 
		if input == activeInput or input.UserInputType == Enum.UserInputType.MouseButton1 then
			isDraggingSpeed = false 
			activeInput = nil
		end
	end))

	trackConnection(RunService.RenderStepped:Connect(function(dt)
		if math.abs(currentScale - targetScale) > 0.001 then
			currentScale = currentScale + (targetScale - currentScale) * (12 * dt)
			speedSlider.Position = UDim2.fromScale(currentScale, 0.5)
			local newSpeed = scaleToSpeed(currentScale)
			if newSpeed ~= currentSpeed then
				currentSpeed = newSpeed
				speedtext.Text = string.format("%.1fx", math.floor(currentSpeed * 10 + 0.5) / 10)
				if not isSyncing then
					sendSpeedToServer(currentSpeed)
					if localAnimTrack then
						localAnimTrack:AdjustSpeed(currentSpeed)
					end
				end
			end
		else
			currentScale = targetScale
		end
	end))

	speedSlider.Position = UDim2.fromScale(targetScale, 0.5)
	speedtext.Text = string.format("%.1fx", SPEED_DEFAULT)
end

-- ============================================
-- PRELOAD & LOAD ANIMATIONS
-- ============================================
task.spawn(function()
	while #emotesFolder:GetChildren() == 0 and isScriptActive do task.wait(0.1) end
	if not isScriptActive then return end

	preloadLabel.Visible = true
	if not player.Character then player.CharacterAdded:Wait() end
	task.wait(2)
	local success = AnimationPreloader.preloadAnimations(emotesFolder)
	preloadLabel.Text = success and "Animations ready!" or "Preload failed"
	preloadLabel.BackgroundTransparency = 0
	task.wait(success and 1.5 or 3)
	preloadLabel.Visible = false
end)

task.spawn(function()
	while #emotesFolder:GetChildren() == 0 and isScriptActive do task.wait(0.1) end
	if not isScriptActive then return end
	repeat task.wait(0.1) until favoritesLoaded or not isScriptActive
	if not isScriptActive then return end

	for _, anim in ipairs(emotesFolder:GetChildren()) do
		if anim:IsA("Animation") then createEmoteButton(anim, "Dance") emoteIdCache[anim.AnimationId] = anim.Name end
	end
	local poseFolder = emotesFolder:FindFirstChild("Pose")
	if poseFolder then
		for _, anim in ipairs(poseFolder:GetChildren()) do
			if anim:IsA("Animation") then createEmoteButton(anim, "Pose") emoteIdCache[anim.AnimationId] = anim.Name end
		end
	end
	table.sort(allButtons, function(a, b) return a.name < b.name end)
	for i, data in ipairs(allButtons) do data.button.LayoutOrder = i end
	setActiveCategory("Dance")
end)

-- ============================================
-- ANTI-DRIFT BACKGROUND SYNC (OPTIMIZED + SMOOTH LERP)
-- ============================================
task.spawn(function()
	while isScriptActive do 
		task.wait(0.2)
		if not isScriptActive then break end 

		local myChar = player.Character
		local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
		if not myHrp then continue end

		local myReferenceTrack = localSyncTrack or localAnimTrack

		for _, p in ipairs(Players:GetPlayers()) do
			local char = p.Character
			if char and char ~= myChar then
				local targetHrp = char:FindFirstChild("HumanoidRootPart")

				if not targetHrp or (myHrp.Position - targetHrp.Position).Magnitude > 100 then 
					continue 
				end

				local animator = char:FindFirstChild("Humanoid") and char.Humanoid:FindFirstChild("Animator")
				if animator then
					local syncingTo = char:GetAttribute("Syncing")

					if syncingTo == player.Name then
						if myReferenceTrack and myReferenceTrack.IsPlaying then
							for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
								if track.Animation and track.Animation.AnimationId == myReferenceTrack.Animation.AnimationId then
									local exactPos = myReferenceTrack.TimePosition
									local diff = exactPos - track.TimePosition

									if track.Length > 0 then
										if diff > track.Length / 2 then diff = diff - track.Length end
										if diff < -track.Length / 2 then diff = diff + track.Length end

										-- 🔥 Toleransi SNAP 0.4 agar tidak glitch saat speed ekstrim
										if math.abs(diff) > 0.4 then
											pcall(function() track.TimePosition = exactPos end)
											pcall(function() track:AdjustSpeed(currentSpeed) end)
										elseif math.abs(diff) > 0.05 then
											local catchUpSpeed = currentSpeed + (diff * 2)
											catchUpSpeed = math.clamp(catchUpSpeed, 0.1, currentSpeed + 1.5)
											pcall(function() track:AdjustSpeed(catchUpSpeed) end)
										else
											pcall(function() track:AdjustSpeed(currentSpeed) end)
										end
									end
								end
							end
						end
						continue 
					end

					-- BACA FAKE WAKTU MULAI
					local startTime = fakeStartTimes[char] or char:GetAttribute("DanceStartTime")
					local speed = char:GetAttribute("DanceSpeed") or 1
					local currentDanceId = char:GetAttribute("CurrentDanceID")

					if syncingTo and syncingTo ~= "" then
						local leader = Players:FindFirstChild(syncingTo)
						if leader and leader.Character then
							startTime = fakeStartTimes[leader.Character] or leader.Character:GetAttribute("DanceStartTime") or startTime
							speed = leader.Character:GetAttribute("DanceSpeed") or speed
							currentDanceId = leader.Character:GetAttribute("CurrentDanceID") or currentDanceId
						end
					end

					if startTime and currentDanceId then
						for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
							if track.Animation and track.Animation.AnimationId == currentDanceId then
								local elapsed = workspace:GetServerTimeNow() - startTime
								local exactPos = (elapsed * speed) % track.Length

								if exactPos > 0 and track.Length > 0 then
									local diff = exactPos - track.TimePosition

									if diff > track.Length / 2 then diff = diff - track.Length end
									if diff < -track.Length / 2 then diff = diff + track.Length end

									if math.abs(diff) > 0.4 then
										pcall(function() track.TimePosition = exactPos end)
										pcall(function() track:AdjustSpeed(speed) end)
									elseif math.abs(diff) > 0.05 then
										local catchUpSpeed = speed + (diff * 2)
										catchUpSpeed = math.clamp(catchUpSpeed, 0.1, speed + 1.5)
										pcall(function() track:AdjustSpeed(catchUpSpeed) end)
									else
										pcall(function() track:AdjustSpeed(speed) end)
									end
								end
							end
						end
					end
				end
			end
		end
	end
end)

-- ============================================
-- THE ZOMBIE CLEANER
-- ============================================
trackConnection(player.CharacterAdded:Connect(function(newCharacter)
	task.spawn(function()
		local animScript = newCharacter:WaitForChild("Animate", 2)
		if animScript and animScript:IsA("LocalScript") then
			animScript.Disabled = false
		end
	end)

	if localSyncTrack then
		local oldTrack = localSyncTrack
		pcall(function() oldTrack:Stop() oldTrack:Destroy() end)
		localSyncTrack = nil
	end

	if localAnimTrack then
		local oldTrack = localAnimTrack
		pcall(function() oldTrack:Stop() oldTrack:Destroy() end)
		localAnimTrack = nil
	end

	isSyncing = false
	currentLeaderName = nil
	currentSpeed = 1
	currentAnimation = nil
	lastEmoteClickTime = 0
	savedLocalEmoteData = nil
	updateButtonVisuals()
end))

script.Destroying:Connect(function()
	isScriptActive = false 

	for _, conn in ipairs(scriptConnections) do
		if conn and conn.Connected then
			conn:Disconnect()
		end
	end
	table.clear(scriptConnections)

	if syncUpdateConnection then syncUpdateConnection:Disconnect() end
	if localSyncTrack then localSyncTrack:Stop(0) end
	if localAnimTrack then localAnimTrack:Stop(0) end
	if player.Character then
		restoreCharacterAnimations(player.Character)
	end
end)

-- ============================================
-- DRAWER SLIDE & DRAG CONTROLLER (RESET ON CLOSE & DOCKED BUTTON)
-- ============================================
local toggleBtn = gui:WaitForChild("DanceToggleButton", 5) or gui:FindFirstChild("DanceToggleButton")

-- Hapus UIDragDetector lama dari MainFrame agar klik di area menu tidak memicu drag
local oldDragDetector = mainframe:FindFirstChildOfClass("UIDragDetector")
if oldDragDetector then
	oldDragDetector:Destroy()
end

-- 📏 DIMENSIONS & POSITIONS
local OPEN_POS = UDim2.new(0, 16, 0.5, 0)
local CLOSED_POS = UDim2.new(0, -290, 0.5, 0)
local BTN_CLOSED_POS = UDim2.new(0, 16, 0.5, 0)

-- Hitung posisi tombol saat terbuka agar mepet dan pas di samping menu (gap 8px)
local function getEffectiveWidth()
	local scale = 1
	local pcScale = mainframe:FindFirstChild("PCScale")
	if pcScale and pcScale:IsA("UIScale") then
		scale = pcScale.Scale
	end
	return mainframe.Size.X.Offset * scale
end

local function getBtnOpenPos()
	local gap = 8 -- 🔥 Jarak pas dan rapat di samping menu
	return UDim2.new(0, math.round(OPEN_POS.X.Offset + getEffectiveWidth() + gap), 0.5, 0)
end

-- AnchorPoint alignment (vertical center)
mainframe.AnchorPoint = Vector2.new(0, 0.5)
if toggleBtn then
	toggleBtn.AnchorPoint = Vector2.new(0, 0.5)
end

-- 🏷️ GARIS DRAG DI ATAS MENU (TOP DRAG HANDLE)
local topDragBar = mainframe:FindFirstChild("TopDragBar")
if not topDragBar then
	topDragBar = Instance.new("Frame")
	topDragBar.Name = "TopDragBar"
	topDragBar.Size = UDim2.new(1, 0, 0, 18)
	topDragBar.Position = UDim2.new(0, 0, 0, 0)
	topDragBar.BackgroundTransparency = 1
	topDragBar.ZIndex = 110
	topDragBar.Active = true
	topDragBar.Parent = mainframe
end

local dragPill = topDragBar:FindFirstChild("DragPill")
if not dragPill then
	dragPill = Instance.new("Frame")
	dragPill.Name = "DragPill"
	dragPill.Size = UDim2.new(0, 44, 0, 4)
	dragPill.Position = UDim2.new(0.5, 0, 0.5, 0)
	dragPill.AnchorPoint = Vector2.new(0.5, 0.5)
	dragPill.BackgroundColor3 = Color3.fromRGB(120, 120, 130)
	dragPill.BackgroundTransparency = 0.2
	dragPill.BorderSizePixel = 0
	dragPill.ZIndex = 111
	dragPill.Parent = topDragBar

	local pillCorner = Instance.new("UICorner")
	pillCorner.CornerRadius = UDim.new(1, 0)
	pillCorner.Parent = dragPill
end

-- Sesuaikan posisi Control agar rapi di bawah garis drag
local controlFrameObj = mainframe:FindFirstChild("Control")
if controlFrameObj then
	controlFrameObj.Position = UDim2.new(0, 12, 0, 18)
end

local isDrawerOpen = false
local isCustomPosition = false
local currentTweenMain = nil
local currentTweenBtn = nil

local TWEEN_INFO_OPEN = TweenInfo.new(0.35, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)
local TWEEN_INFO_CLOSE = TweenInfo.new(0.3, Enum.EasingStyle.Cubic, Enum.EasingDirection.In)

setDrawer = function(targetOpen)
	if currentTweenMain then currentTweenMain:Cancel() end
	if currentTweenBtn then currentTweenBtn:Cancel() end

	if targetOpen then
		isDrawerOpen = true
		isCustomPosition = false -- 🔥 RESET SELALU KE POSISI AWAL
		mainframe.Visible = true

		currentTweenMain = TweenService:Create(mainframe, TWEEN_INFO_OPEN, { Position = OPEN_POS })
		if toggleBtn then
			currentTweenBtn = TweenService:Create(toggleBtn, TWEEN_INFO_OPEN, { Position = getBtnOpenPos() })
			currentTweenBtn:Play()
		end
		currentTweenMain:Play()
	else
		isDrawerOpen = false
		isCustomPosition = false -- 🔥 RESET POSISI KETIKA DITUTUP

		currentTweenMain = TweenService:Create(mainframe, TWEEN_INFO_CLOSE, { Position = CLOSED_POS })
		if toggleBtn then
			currentTweenBtn = TweenService:Create(toggleBtn, TWEEN_INFO_CLOSE, { Position = BTN_CLOSED_POS })
			currentTweenBtn:Play()
		end
		currentTweenMain:Play()

		currentTweenMain.Completed:Connect(function(playbackState)
			if playbackState == Enum.PlaybackState.Completed and not isDrawerOpen then
				mainframe.Visible = false
			end
		end)
	end
end

-- 🖱️ LOGIKA DRAG HANYA PADA GARIS DRAG DI ATAS MENU
local isDraggingMenu = false
local dragStartMouse = nil
local dragStartFramePos = nil

topDragBar.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		isDraggingMenu = true
		dragStartMouse = input.Position
		dragStartFramePos = mainframe.Position
		isCustomPosition = true

		dragPill.BackgroundColor3 = Color3.fromRGB(220, 220, 230)
		dragPill.BackgroundTransparency = 0

		if toggleBtn then
			if currentTweenBtn then currentTweenBtn:Cancel() end
			currentTweenBtn = TweenService:Create(toggleBtn, TweenInfo.new(0.25, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), { Position = BTN_CLOSED_POS })
			currentTweenBtn:Play()
		end
	end
end)

topDragBar.MouseEnter:Connect(function()
	if not isDraggingMenu then
		dragPill.BackgroundColor3 = Color3.fromRGB(180, 180, 190)
		dragPill.BackgroundTransparency = 0
	end
end)

topDragBar.MouseLeave:Connect(function()
	if not isDraggingMenu then
		dragPill.BackgroundColor3 = Color3.fromRGB(120, 120, 130)
		dragPill.BackgroundTransparency = 0.2
	end
end)

trackConnection(UserInputService.InputChanged:Connect(function(input)
	if isDraggingMenu and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
		local delta = input.Position - dragStartMouse
		local newX = dragStartFramePos.X.Offset + delta.X
		local newY = dragStartFramePos.Y.Offset + delta.Y

		mainframe.Position = UDim2.new(dragStartFramePos.X.Scale, newX, dragStartFramePos.Y.Scale, newY)
	end
end))

trackConnection(UserInputService.InputEnded:Connect(function(input)
	if isDraggingMenu and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
		isDraggingMenu = false
		dragPill.BackgroundColor3 = Color3.fromRGB(120, 120, 130)
		dragPill.BackgroundTransparency = 0.2

		local isNearDockX = math.abs(mainframe.Position.X.Offset - OPEN_POS.X.Offset) < 35 and mainframe.Position.X.Scale == 0
		local isNearDockY = math.abs(mainframe.Position.Y.Offset - OPEN_POS.Y.Offset) < 35 and math.abs(mainframe.Position.Y.Scale - 0.5) < 0.05

		if isNearDockX and isNearDockY then
			isCustomPosition = false
			TweenService:Create(mainframe, TweenInfo.new(0.25, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), { Position = OPEN_POS }):Play()
			if toggleBtn then
				TweenService:Create(toggleBtn, TweenInfo.new(0.25, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), { Position = getBtnOpenPos() }):Play()
			end
		else
			if toggleBtn and toggleBtn.Position ~= BTN_CLOSED_POS then
				TweenService:Create(toggleBtn, TweenInfo.new(0.25, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), { Position = BTN_CLOSED_POS }):Play()
			end
		end
	end
end))

-- 🔘 TOGGLE BUTTON HANDLER
if toggleBtn then
	toggleBtn.Position = BTN_CLOSED_POS
	toggleBtn.Visible = true

	toggleBtn.MouseButton1Click:Connect(function()
		setDrawer(not isDrawerOpen)
	end)
end

-- Initial state
mainframe.Position = CLOSED_POS
mainframe.Visible = false

-- BindableEvent for external scripts (TopbarPlus, etc.)
local toggleDrawerEvent = gui:FindFirstChild("ToggleDrawer")
if not toggleDrawerEvent then
	toggleDrawerEvent = Instance.new("BindableEvent")
	toggleDrawerEvent.Name = "ToggleDrawer"
	toggleDrawerEvent.Parent = gui
end

toggleDrawerEvent.Event:Connect(function(targetState)
	if type(targetState) == "boolean" then
		setDrawer(targetState)
	else
		setDrawer(not isDrawerOpen)
	end
end)

mainframe:GetPropertyChangedSignal("Visible"):Connect(function()
	if mainframe.Visible and not isDrawerOpen then
		setDrawer(true)
	end
end)
