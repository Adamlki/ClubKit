-- ============================================
-- SINGLETON PROTECTION
-- Mencegah script berjalan ganda jika masih ada LocalScript di StarterGui.EmoteGui
-- ============================================
local ScriptOnce = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("ScriptOnce"))
if not ScriptOnce.Claim("EmoteHandlerClient") then return end

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
local AnimationRegistry = require(Modules:WaitForChild("AnimationRegistry"))
AnimatorUtils.AnimationPreloader = AnimationPreloader

-- 🔥 INTEGRASI MODULE ANIMASI
local UIAnimator = require(ReplicatedStorage:WaitForChild("UIAnimator"))

-- ============================================
-- GLOBAL CONNECTION TRACKER (ANTI MEMORY LEAK)
-- ============================================
local isScriptActive = true
local scriptConnections = {}
local fakeStartTimes = setmetatable({}, { __mode = "k" }) -- 🔥 THE HIVE MIND: Weak table cache waktu mulai dinamis (Anti-Memory Leak)
local characterConnections = {} -- [char] = { conn1, conn2, ... }
local playerConnections = {} -- [Player] = { conn1, conn2, ... }
-- Harus dideklarasikan sebelum cleanupCharacterConnections (dipakai di dalamnya)
local globalSyncListeners = setmetatable({}, { __mode = "k" })
local leaderCharAddedConn = nil
local leaderDanceConn = nil

local function trackConnection(conn)
	table.insert(scriptConnections, conn)
	return conn
end

local function cleanupCharacterConnections(char)
	if not char then return end
	local conns = characterConnections[char]
	if conns then
		for _, conn in ipairs(conns) do
			if conn and conn.Connected then
				pcall(function() conn:Disconnect() end)
			end
		end
		characterConnections[char] = nil
	end
	fakeStartTimes[char] = nil
	if globalSyncListeners then
		globalSyncListeners[char] = nil
	end
end


-- ============================================
-- GUI ELEMENTS (Mendukung StarterPlayerScripts & StarterGui)
-- ============================================
local playerGui = player:WaitForChild("PlayerGui")
local gui = script.Parent:IsA("ScreenGui") and script.Parent or playerGui:WaitForChild("EmoteGui", 30)
if not gui then
	warn("[EmoteHandler] EmoteGui tidak ditemukan di PlayerGui dalam 30 detik!")
	return
end
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

local function updateResponsiveScale()
	local camera = workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
	local isMobile = UserInputService.TouchEnabled and not (UserInputService.MouseEnabled and not UserInputService.TouchEnabled)

	local uiScale = mainframe:FindFirstChild("ResponsiveScale") or mainframe:FindFirstChild("PCScale") or Instance.new("UIScale")
	uiScale.Name = "ResponsiveScale"
	uiScale.Parent = mainframe

	if isMobile then
		local scaleByHeight = (viewport.Y - 20) / 430
		uiScale.Scale = math.clamp(scaleByHeight, 0.95, 1.25)
	else
		uiScale.Scale = 0.85
	end
end

updateResponsiveScale()
local currentCam = workspace.CurrentCamera
if currentCam then
	currentCam:GetPropertyChangedSignal("ViewportSize"):Connect(updateResponsiveScale)
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

local FADE_TIME = 0.5
local DANCE_SWITCH_FADE = 0.5

local function normalizeId(id)
	if not id then return "" end
	return tostring(id):match("%d+") or tostring(id)
end

local notificationQueue = {}
local isShowingNotification = false

local allButtons = {}
local buttonColorMap = {}
local buttonCategoryMap = {}
local emoteIdCache = {}
for name, id in pairs(AnimationRegistry.Dances) do
	local norm = normalizeId(id)
	emoteIdCache[id] = name
	if norm ~= "" then
		emoteIdCache[norm] = name
		emoteIdCache["rbxassetid://" .. norm] = name
	end
end
for name, id in pairs(AnimationRegistry.Poses) do
	local norm = normalizeId(id)
	emoteIdCache[id] = name
	if norm ~= "" then
		emoteIdCache[norm] = name
		emoteIdCache["rbxassetid://" .. norm] = name
	end
end
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
local animationStarted

local lastEmoteClickTime = 0 
local lastDanceSwitchTime = 0 

-- ============================================
-- CORE ANIMATION & STATE CONTROL
-- ============================================
local function isClubDanceId(animId)
	if not animId or animId == "" then return false end
	if emoteIdCache[animId] then return true end
	local norm = normalizeId(animId)
	if norm ~= "" and emoteIdCache[norm] then return true end
	return false
end

local function setAnimateEnabled(character, enabled)
	if not character then return end
	character:SetAttribute("AnimateDisabled", not enabled)
end

local function killGhostAnimation(animator, fade, excludeTrack, excludeTrack2)
	local f = fade or 0.5
	pcall(function()
		if not animator or not animator.Parent then return end
		if animator.Parent.Parent ~= player.Character then return end 
		for _, t in ipairs(animator:GetPlayingAnimationTracks()) do
			if t ~= excludeTrack and t ~= excludeTrack2 then
				local animId = t.Animation and t.Animation.AnimationId
				if (animId and isClubDanceId(animId)) or t.Priority == Enum.AnimationPriority.Action4 then
					pcall(function()
						t:AdjustSpeed(1)
						t:Stop(f)
					end)
				end
			end
		end
	end)
end

local function suppressNativeAnimations(animator, fade)
end

local function freezeHumanoidForPose(character, freeze)
	if not character then return end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	if freeze then
		humanoid.WalkSpeed = 0
	else
		humanoid.WalkSpeed = 16
	end
end

local function isCurrentAnimPose()
	return currentAnimation ~= nil and buttonCategoryMap[currentAnimation] == "Pose"
end

local function restoreCharacterAnimations(character)
	if not character then return end

	setAnimateEnabled(character, true)
	freezeHumanoidForPose(character, false)

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")

	if animator then
		pcall(function()
			local hasNonClubPlaying = false
			for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
				local animId = track.Animation and track.Animation.AnimationId
				if not isClubDanceId(animId) then
					hasNonClubPlaying = true
					track:AdjustSpeed(1)
					track:AdjustWeight(1)
				end
			end

			if not hasNonClubPlaying then
				local animScript = character:FindFirstChild("Animate")
				if animScript and animScript:IsA("LocalScript") and animScript.Enabled then
					task.spawn(function()
						animScript.Disabled = true
						task.wait()
						if animScript and animScript.Parent then
							animScript.Disabled = false
						end
					end)
				end
			end
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

local NOTIF_HANDLERS = {
	sync_success = function(leaderName)
		local leaderPlayer = Players:FindFirstChild(leaderName)
		local displayName = leaderPlayer and leaderPlayer.DisplayName or leaderName
		showNotification("Coordinate dance are apply to " .. displayName, 2.5, Color3.fromRGB(0, 0, 0))
	end,
	unsync_success = function()
		showNotification("Unsynced", 2, Color3.fromRGB(0, 0, 0))
	end,
	leader_left = function(leaderName)
		showNotification("LEAD " .. leaderName .. " meninggalkan server", 4, Color3.fromRGB(200, 30, 30))
		if player.Character then
			restoreCharacterAnimations(player.Character)
			if localSyncTrack then 
				localSyncTrack:Stop(FADE_TIME) 
				localSyncTrack = nil 
			end
		end
	end,
	leader_blocked = function()
		showNotification("You are a Dance Leader!\nCannot sync to followers", 3, Color3.fromRGB(0, 0, 0))
	end,
	circular_blocked = function()
		showNotification("Cannot create circular coordinate dance", 2.5, Color3.fromRGB(0, 0, 0))
	end,
}

trackConnection(syncNotificationRE.OnClientEvent:Connect(function(notifType, leaderName)
	local handler = NOTIF_HANDLERS[notifType]
	if handler then handler(leaderName) end
end))

local previousAnimation = nil
local function updateButtonVisuals()
	if previousAnimation then
		previousAnimation.BackgroundColor3 = buttonColorMap[previousAnimation] or Color3.fromRGB(34, 34, 38)
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
	for _, anim in ipairs(emotesFolder:GetDescendants()) do
		if anim:IsA("Animation") then
			if anim.AnimationId == danceId or (numId and anim.AnimationId:match("%d+") == numId) then
				animByIdCache[danceId] = anim
				return anim
			end
		end
	end

	local fallbackAnim = Instance.new("Animation")
	fallbackAnim.Name = "DynamicSyncAnim"
	fallbackAnim.AnimationId = danceId
	animByIdCache[danceId] = fallbackAnim
	return fallbackAnim
end

-- ============================================
-- THE UNIVERSAL HIVE MIND (Observer Tunggal)
-- ============================================
local function applyDance(char, danceId, speed, startTime, leaderName, isSpam)
	if char ~= player.Character then return end 

	speed = speed or 1

	local animator = char:FindFirstChild("Humanoid") and char.Humanoid:FindFirstChild("Animator")
	if not animator then return end

	local applyTicket = (char:GetAttribute("ApplyTicket") or 0) + 1
	char:SetAttribute("ApplyTicket", applyTicket)

	local normDanceId = normalizeId(danceId)

	if localSyncTrack and localSyncTrack.Animation and normalizeId(localSyncTrack.Animation.AnimationId) == normDanceId and localSyncTrack.IsPlaying then
		if isSpam then
			pcall(function() localSyncTrack.TimePosition = 0 end)
		end
		pcall(function() localSyncTrack:AdjustSpeed(speed) end)
		currentSpeed = speed
		return
	end

	local now = os.clock()
	local isRapid = (now - lastDanceSwitchTime < 0.6)
	lastDanceSwitchTime = now
	local actualFade = isSpam and 0 or (isRapid and 0.4 or 0.5)

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

	setAnimateEnabled(char, false)

	local oldSyncTrack = localSyncTrack or localAnimTrack
	if localAnimTrack and localAnimTrack ~= oldSyncTrack then
		localAnimTrack:Stop(actualFade)
		localAnimTrack = nil
	end

	local track = AnimatorUtils.getOrCreateTrack(animator, targetAnim)
	if not track then setAnimateEnabled(char, true) return end

	localSyncTrack = track
	track.Priority = Enum.AnimationPriority.Action4

	local exactPos = nil
	if leaderName and leaderName ~= "" then
		local leaderPlayer = Players:FindFirstChild(leaderName)
		local leaderChar = leaderPlayer and leaderPlayer.Character
		local leaderAnimator = leaderChar and leaderChar:FindFirstChild("Humanoid") and leaderChar.Humanoid:FindFirstChild("Animator")
		if leaderAnimator then
			for _, t in ipairs(leaderAnimator:GetPlayingAnimationTracks()) do
				local tId = t.Animation and t.Animation.AnimationId
				if tId and normalizeId(tId) == normDanceId and t.IsPlaying then
					exactPos = t.TimePosition
					break
				end
			end
		end
	end

	if not exactPos and startTime and track.Length > 0 then
		exactPos = ((workspace:GetServerTimeNow() - startTime) * speed) % track.Length
	end

	track:Play(actualFade, 1, speed)
	local initialPosApplied = false
	if exactPos and track.Length > 0 then
		pcall(function() track.TimePosition = exactPos end)
		initialPosApplied = true
	end

	if oldSyncTrack and oldSyncTrack ~= track then
		pcall(function()
			oldSyncTrack:AdjustSpeed(1)
			oldSyncTrack:Stop(actualFade)
		end)
	end
	killGhostAnimation(animator, actualFade, track)

	local capturedTicket = applyTicket
	local function onTrackReady()
		if not isScriptActive then return end
		if char:GetAttribute("ApplyTicket") ~= capturedTicket then return end

		if not initialPosApplied and track and track.Length > 0 then
			local targetPos = nil
			if leaderName and leaderName ~= "" then
				local leaderPlayer = Players:FindFirstChild(leaderName)
				local leaderChar = leaderPlayer and leaderPlayer.Character
				local leaderAnimator = leaderChar and leaderChar:FindFirstChild("Humanoid") and leaderChar.Humanoid:FindFirstChild("Animator")
				if leaderAnimator then
					for _, t in ipairs(leaderAnimator:GetPlayingAnimationTracks()) do
						local tId = t.Animation and t.Animation.AnimationId
						if tId and normalizeId(tId) == normDanceId and t.IsPlaying then
							targetPos = t.TimePosition
							break
						end
					end
				end
			end

			if not targetPos and startTime and track.Length > 0 then
				local finalTime = workspace:GetServerTimeNow()
				targetPos = ((finalTime - startTime) * speed) % track.Length
			end

			if targetPos and track.Length > 0 then
				pcall(function() track.TimePosition = targetPos end)
			end
		end

		track:AdjustSpeed(speed) 
		killGhostAnimation(animator, actualFade, track)
	end

	if track and track.Length > 0 then
		onTrackReady()
	elseif track then
		local lengthConn
		local timeoutThread
		local done = false
		local function triggerReady()
			if done then return end
			done = true
			if lengthConn then lengthConn:Disconnect() lengthConn = nil end
			onTrackReady()
		end

		lengthConn = track:GetPropertyChangedSignal("Length"):Connect(function()
			if track.Length > 0 then
				triggerReady()
			end
		end)

		timeoutThread = task.delay(1.5, function()
			triggerReady()
		end)
	end
end

local function monitorPlayerCharacter(targetPlayer)
	if not targetPlayer then return end

	if playerConnections[targetPlayer] then
		for _, c in ipairs(playerConnections[targetPlayer]) do
			if c and c.Connected then pcall(function() c:Disconnect() end) end
		end
		playerConnections[targetPlayer] = nil
	end
	playerConnections[targetPlayer] = {}

	local function onCharacterAdded(char)
		if not char then return end
		cleanupCharacterConnections(char)

		characterConnections[char] = {}
		local function trackCharConn(c)
			if c then table.insert(characterConnections[char], c) end
			return c
		end

		local humanoid = char:WaitForChild("Humanoid", 10)
		if not humanoid then return end

		local animator = humanoid:WaitForChild("Animator", 10)
		if not animator then return end

		-- Cleanup otomatis saat karakter respawn, mati, atau dihancurkan
		trackCharConn(char.AncestryChanged:Connect(function(_, parent)
			if not parent then
				cleanupCharacterConnections(char)
			end
		end))
		trackCharConn(char.Destroying:Connect(function()
			cleanupCharacterConnections(char)
		end))
		trackCharConn(humanoid.Died:Connect(function()
			task.delay(5, function()
				if not char.Parent then
					cleanupCharacterConnections(char)
				end
			end)
		end))

		local function forceSnapCharacterDance(track)
			if not track or track.Length == 0 then return end

			local startTime = fakeStartTimes[char] or char:GetAttribute("DanceStartTime")
			local speed = char:GetAttribute("DanceSpeed") or 1
			local currentDanceId = char:GetAttribute("CurrentDanceID")
			local syncingTo = char:GetAttribute("Syncing")

			if syncingTo == player.Name then
				local myRef = localSyncTrack or localAnimTrack
				if myRef and myRef.IsPlaying and myRef.Animation and track.Animation then
					local myNorm = normalizeId(myRef.Animation.AnimationId)
					local trackNorm = normalizeId(track.Animation.AnimationId)
					if myNorm == trackNorm then
						pcall(function()
							track.TimePosition = myRef.TimePosition
							track:AdjustSpeed(currentSpeed)
						end)
					end
				end
				return
			end

			if syncingTo and syncingTo ~= "" then
				local leader = Players:FindFirstChild(syncingTo)
				local leaderChar = leader and leader.Character
				local leaderAnim = leaderChar and leaderChar:FindFirstChild("Humanoid") and leaderChar.Humanoid:FindFirstChild("Animator")
				if leaderAnim then
					local targetNorm = normalizeId(currentDanceId)
					for _, lt in ipairs(leaderAnim:GetPlayingAnimationTracks()) do
						local ltId = lt.Animation and lt.Animation.AnimationId
						if ltId and normalizeId(ltId) == targetNorm and lt.IsPlaying then
							pcall(function()
								track.TimePosition = lt.TimePosition
								track:AdjustSpeed(lt.Speed)
							end)
							return
						end
					end
				end
				if leaderChar then
					startTime = fakeStartTimes[leaderChar] or leaderChar:GetAttribute("DanceStartTime") or startTime
					speed = leaderChar:GetAttribute("DanceSpeed") or speed
				end
			end

			if currentDanceId and track.Animation and normalizeId(track.Animation.AnimationId) ~= normalizeId(currentDanceId) then
				return
			end

			if not char:GetAttribute("IsLeader") and startTime and track.Length > 0 then
				local elapsed = workspace:GetServerTimeNow() - startTime
				local exactPos = (elapsed * speed) % track.Length
				if exactPos > 0 and math.abs(track.TimePosition - exactPos) > 0.02 then
					pcall(function() track.TimePosition = exactPos end)
				end
			end

			pcall(function() track:AdjustSpeed(speed) end)
		end

		trackCharConn(animator.AnimationPlayed:Connect(function(track)
			if char ~= player.Character and track and track.Animation then
				if track.Length > 0 then
					forceSnapCharacterDance(track)
				else
					local lengthConn
					local timeoutThread
					local snapped = false
					local function triggerSnap()
						if snapped then return end
						snapped = true
						if lengthConn then lengthConn:Disconnect() lengthConn = nil end
						if track and track.Length > 0 then
							forceSnapCharacterDance(track)
						end
					end

					lengthConn = track:GetPropertyChangedSignal("Length"):Connect(function()
						if track.Length > 0 then
							triggerSnap()
						end
					end)

					timeoutThread = task.delay(1.5, function()
						triggerSnap()
					end)
				end
			end
		end))

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
			if char == player.Character then return end
			local myChar = player.Character
			if myChar and myChar:GetAttribute("Syncing") == char.Name then
				local danceId = char:GetAttribute("CurrentDanceID")
				local speed = char:GetAttribute("DanceSpeed") or 1
				local startTime = char:GetAttribute("DanceStartTime")
				applyDance(myChar, danceId, speed, startTime, char.Name, isSpamTrigger)
			end
		end

		-- 6 Listener attribute yang terdaftar dan dibersihkan per-karakter
		trackCharConn(char:GetAttributeChangedSignal("DanceStartTime"):Connect(function()
			fakeStartTimes[char] = char:GetAttribute("DanceStartTime")
			onAttributeChanged()
			broadcastLeaderState(false)
		end))

		trackCharConn(char:GetAttributeChangedSignal("CurrentDanceID"):Connect(function()
			onAttributeChanged()
			broadcastLeaderState(false)
		end))

		trackCharConn(char:GetAttributeChangedSignal("Syncing"):Connect(function()
			onAttributeChanged()
			syncToLeader()
		end))

		trackCharConn(char:GetAttributeChangedSignal("SpamNonce"):Connect(function() 
			broadcastLeaderState(true) 
		end))

		trackCharConn(char:GetAttributeChangedSignal("DanceSpeed"):Connect(function()
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
		end))

		task.spawn(function()
			if char:GetAttribute("Syncing") and char:GetAttribute("Syncing") ~= "" then
				syncToLeader()
			elseif char:GetAttribute("CurrentDanceID") then
				broadcastLeaderState(false)
			end
		end)
	end

	local charAddedConn = targetPlayer.CharacterAdded:Connect(onCharacterAdded)
	table.insert(playerConnections[targetPlayer], charAddedConn)

	local charRemovingConn = targetPlayer.CharacterRemoving:Connect(function(oldChar)
		cleanupCharacterConnections(oldChar)
	end)
	table.insert(playerConnections[targetPlayer], charRemovingConn)

	if targetPlayer.Character then 
		task.spawn(onCharacterAdded, targetPlayer.Character) 
	end
end

local function onPlayerRemoving(leavingPlayer)
	if not leavingPlayer then return end

	if playerConnections[leavingPlayer] then
		for _, c in ipairs(playerConnections[leavingPlayer]) do
			if c and c.Connected then
				pcall(function() c:Disconnect() end)
			end
		end
		playerConnections[leavingPlayer] = nil
	end

	if leavingPlayer.Character then
		cleanupCharacterConnections(leavingPlayer.Character)
	end

	if currentLeaderName and leavingPlayer.Name == currentLeaderName then
		if leaderDanceConn then leaderDanceConn:Disconnect() leaderDanceConn = nil end
		if leaderCharAddedConn then leaderCharAddedConn:Disconnect() leaderCharAddedConn = nil end
	end
end

for _, p in ipairs(Players:GetPlayers()) do monitorPlayerCharacter(p) end
trackConnection(Players.PlayerAdded:Connect(monitorPlayerCharacter))
trackConnection(Players.PlayerRemoving:Connect(onPlayerRemoving))

-- ============================================
-- GUI & SYNC MANAGEMENT
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
	if leaderCharAddedConn then leaderCharAddedConn:Disconnect() leaderCharAddedConn = nil end
	if not leaderPlayer then return end

	local function onLeaderChar(char)
		if leaderDanceConn then leaderDanceConn:Disconnect() leaderDanceConn = nil end
		if char then
			leaderDanceConn = char:GetAttributeChangedSignal("CurrentDanceID"):Connect(updateLeaderDanceIndicator)
		end
		updateLeaderDanceIndicator()
	end

	if leaderPlayer.Character then onLeaderChar(leaderPlayer.Character) end
	leaderCharAddedConn = leaderPlayer.CharacterAdded:Connect(onLeaderChar)
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

		setMenuElementsBlocked(true)
		unsyncframe.Visible = true
	else
		if leaderDanceConn then leaderDanceConn:Disconnect() leaderDanceConn = nil end
		if leaderCharAddedConn then leaderCharAddedConn:Disconnect() leaderCharAddedConn = nil end
		
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
-- ANIMATION STARTED 
-- ============================================
function animationStarted(animation, button)
	if inputLock or pendingRequest then return end

	inputLock = true
	task.delay(0.05, function() inputLock = false end)

	local currentTime = os.clock()
	local character = player.Character
	local animator = character and character:FindFirstChild("Humanoid") and character.Humanoid:FindFirstChild("Animator")

	if isSyncing then
		isSyncing = false
		local prevLeader = currentLeaderName
		currentLeaderName = nil
		if unsyncframe then unsyncframe.Visible = false end
		if localSyncTrack then
			localSyncTrack:Stop(DANCE_SWITCH_FADE)
			localSyncTrack = nil
		end
		if prevLeader then
			local lp = Players:FindFirstChild(prevLeader)
			if lp then
				startSyncRE:FireServer(lp, false)
			end
		end
		if character then
			character:SetAttribute("Syncing", nil)
		end
	end

	local timeSinceLastClick = currentTime - lastEmoteClickTime
	local isSpamming = (timeSinceLastClick < 0.7)

	if currentAnimation == button then
		if isSpamming then
			lastEmoteClickTime = os.clock()
			if animator then
				if localAnimTrack and localAnimTrack.Animation and normalizeId(localAnimTrack.Animation.AnimationId) == normalizeId(animation.AnimationId) then
					localAnimTrack.TimePosition = 0
				else
					local isPose = isCurrentAnimPose()
					local char = character
					setAnimateEnabled(character, false)

					local oldTrack = localAnimTrack
					localAnimTrack = AnimatorUtils.getOrCreateTrack(animator, animation)
					if localAnimTrack then
						localAnimTrack.TimePosition = 0
						localAnimTrack.Priority = Enum.AnimationPriority.Action4
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
		savedLocalEmoteData = nil
		currentAnimation = button
		lastEmoteClickTime = os.clock()
		updateButtonVisuals()

		local oldAnimTrack = localAnimTrack
		local now = os.clock()
		local isRapid = (now - lastDanceSwitchTime < 0.6)
		lastDanceSwitchTime = now
		local actualFade = isRapid and 0.4 or 0.5

		if animator then
			local isPose = isCurrentAnimPose()
			local char = character
			setAnimateEnabled(character, false)

			localAnimTrack = AnimatorUtils.getOrCreateTrack(animator, animation)
			if localAnimTrack then
				localAnimTrack.Priority = Enum.AnimationPriority.Action4
				localAnimTrack.TimePosition = 0
				localAnimTrack:Play(actualFade, 1, currentSpeed)

				if oldAnimTrack and oldAnimTrack ~= localAnimTrack then
					pcall(function()
						oldAnimTrack:AdjustSpeed(1)
						oldAnimTrack:Stop(actualFade)
					end)
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
	buttonColorMap[newButton] = originalColor
	buttonCategoryMap[newButton] = category
	return newButton
end

function updateDisplay()
	pcall(function()
		containerlist.CanvasPosition = Vector2.new(0, 0)
		for _, data in ipairs(allButtons) do
			local shouldShow = (currentCategory == "Favorite") and (favoritedAnimations[data.name] == true) or (currentCategory == data.category)
			if shouldShow and searchQuery ~= "" then 
				local nameLower = string.lower(data.name)
				local queryLower = string.lower(searchQuery)
				if string.find(nameLower, queryLower, 1, true) then
					shouldShow = true
				else
					local matchesAll = true
					for word in string.gmatch(queryLower, "%S+") do
						if not string.find(nameLower, word, 1, true) then
							matchesAll = false
							break
						end
					end
					shouldShow = matchesAll
				end
			end
			data.button.Visible = shouldShow
		end
		updateButtonVisuals()
	end)
end

local CATEGORY_BUTTONS = {
	Dance = danceBtn,
	Pose = poseBtn,
	Favorite = favoriteBtn,
}

local function setActiveCategory(category)
	currentCategory = category
	for cat, btn in pairs(CATEGORY_BUTTONS) do
		local sel = (cat == category)
		btn.BackgroundColor3 = sel and Color3.fromRGB(15, 15, 18) or Color3.fromRGB(68, 70, 75)
		btn.TextColor3 = sel and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(215, 215, 220)
	end
	updateDisplay()
end

danceBtn.MouseButton1Click:Connect(function() setActiveCategory("Dance") end)
poseBtn.MouseButton1Click:Connect(function() setActiveCategory("Pose") end)
favoriteBtn.MouseButton1Click:Connect(function() setActiveCategory("Favorite") end)
searchBox:GetPropertyChangedSignal("Text"):Connect(function() searchQuery = searchBox.Text updateDisplay() end)

-- ============================================
-- SPEED SLIDER 
-- ============================================
if speedSlider and speedBar and speedtext and speedButton then
	local isDraggingSpeed = false
	local activeInput = nil
	local speedSendDebounce = false
	local lastSentSpeed = SPEED_DEFAULT
	speedSlider.AnchorPoint = Vector2.new(0.5, 0.5)

	local function scaleToSpeed(scale) return math.floor((SPEED_MIN + scale * (SPEED_MAX - SPEED_MIN)) * 100 + 0.5) / 100 end
	local function speedToScale(speed) return (speed - SPEED_MIN) / (SPEED_MAX - SPEED_MIN) end

	local function sendSpeedToServer(speed, isFinal)
		if speed == lastSentSpeed then return end
		if not isFinal and speedSendDebounce then return end
		speedSendDebounce = true
		lastSentSpeed = speed
		changeSpeedRE:FireServer(speed)
		task.delay(0.25, function()
			speedSendDebounce = false
			if not isDraggingSpeed and currentSpeed ~= lastSentSpeed then
				changeSpeedRE:FireServer(currentSpeed)
				lastSentSpeed = currentSpeed
			end
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
		if input == activeInput or input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			isDraggingSpeed = false 
			activeInput = nil
			if not isSyncing and currentSpeed ~= lastSentSpeed then
				sendSpeedToServer(currentSpeed, true)
			end
		end
	end))

	trackConnection(RunService.RenderStepped:Connect(function(dt)
		if currentScale == targetScale then return end

		if math.abs(currentScale - targetScale) > 0.001 then
			currentScale = currentScale + (targetScale - currentScale) * (12 * dt)
			speedSlider.Position = UDim2.fromScale(currentScale, 0.5)
			local newSpeed = scaleToSpeed(currentScale)
			if newSpeed ~= currentSpeed then
				currentSpeed = newSpeed
				speedtext.Text = string.format("%.1fx", math.floor(currentSpeed * 10 + 0.5) / 10)
				if not isSyncing then
					if localAnimTrack then
						localAnimTrack:AdjustSpeed(currentSpeed)
					end
					sendSpeedToServer(currentSpeed, false)
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

	local createdButtons = 0
	for _, anim in ipairs(emotesFolder:GetChildren()) do
		if anim:IsA("Animation") then
			createEmoteButton(anim, "Dance")
			createdButtons += 1
			local aId = anim.AnimationId
			local norm = normalizeId(aId)
			emoteIdCache[aId] = anim.Name
			if norm ~= "" then
				emoteIdCache[norm] = anim.Name
				emoteIdCache["rbxassetid://" .. norm] = anim.Name
			end
			if createdButtons % 20 == 0 then task.wait() end
		end
	end
	local poseFolder = emotesFolder:FindFirstChild("Pose")
	if poseFolder then
		for _, anim in ipairs(poseFolder:GetChildren()) do
			if anim:IsA("Animation") then
				createEmoteButton(anim, "Pose")
				createdButtons += 1
				local aId = anim.AnimationId
				local norm = normalizeId(aId)
				emoteIdCache[aId] = anim.Name
				if norm ~= "" then
					emoteIdCache[norm] = anim.Name
					emoteIdCache["rbxassetid://" .. norm] = anim.Name
				end
				if createdButtons % 20 == 0 then task.wait() end
			end
		end
	end
	table.sort(allButtons, function(a, b) return a.name < b.name end)
	for i, data in ipairs(allButtons) do data.button.LayoutOrder = i end
	setActiveCategory("Dance")
end)

-- ============================================
-- ANTI-DRIFT BACKGROUND SYNC 
-- ============================================
task.spawn(function()
	local ANTI_DRIFT_INTERVAL = 0.35
	local CULL_DISTANCE = 60

	local function wrapDiff(diff, len)
		if diff > len / 2 then return diff - len end
		if diff < -len / 2 then return diff + len end
		return diff
	end

	local function syncTrackPosition(track, targetPos, targetSpeed, snapThreshold)
		if track.Length <= 0 then return end
		local diff = wrapDiff(targetPos - track.TimePosition, track.Length)
		if math.abs(diff) > (snapThreshold or 0.03) then
			pcall(function() track.TimePosition = targetPos end)
			pcall(function() track:AdjustSpeed(targetSpeed) end)
		elseif math.abs(track.Speed - targetSpeed) > 0.02 then
			pcall(function() track:AdjustSpeed(targetSpeed) end)
		end
	end

	while isScriptActive do 
		task.wait(ANTI_DRIFT_INTERVAL)
		if not isScriptActive then break end 

		local myChar = player.Character
		local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
		if not myHrp then continue end

		local isDancing = (localAnimTrack and localAnimTrack.IsPlaying) or (localSyncTrack and localSyncTrack.IsPlaying)
		if not isDancing and not isSyncing then
			task.wait(1.0)
			continue
		end

		local activeLeader = currentLeaderName or (myChar and myChar:GetAttribute("Syncing"))
		if isSyncing and localSyncTrack and localSyncTrack.IsPlaying and activeLeader then
			local leaderPlayer = Players:FindFirstChild(activeLeader)
			local leaderChar = leaderPlayer and leaderPlayer.Character
			local leaderAnimator = leaderChar and leaderChar:FindFirstChild("Humanoid") and leaderChar.Humanoid:FindFirstChild("Animator")
			local synced = false

			if leaderAnimator then
				local myAnimId = localSyncTrack.Animation and localSyncTrack.Animation.AnimationId
				local myNorm = myAnimId and normalizeId(myAnimId)
				for _, lt in ipairs(leaderAnimator:GetPlayingAnimationTracks()) do
					local ltId = lt.Animation and lt.Animation.AnimationId
					if ltId and (normalizeId(ltId) == myNorm or ltId == myAnimId) and lt.IsPlaying then
						if localSyncTrack.Length > 0 then
							local diff = wrapDiff(lt.TimePosition - localSyncTrack.TimePosition, localSyncTrack.Length)
							local leaderSpeed = leaderChar:GetAttribute("DanceSpeed") or lt.Speed
							local absDiff = math.abs(diff)

							if absDiff <= 0.05 then
								pcall(function() localSyncTrack:AdjustSpeed(leaderSpeed) end)
							elseif absDiff <= 0.40 then
								local nudge = math.clamp(diff * 0.35, -0.15, 0.15)
								pcall(function() localSyncTrack:AdjustSpeed(math.max(0.05, leaderSpeed * (1 + nudge))) end)
							else
								pcall(function() localSyncTrack.TimePosition = lt.TimePosition end)
								pcall(function() localSyncTrack:AdjustSpeed(leaderSpeed) end)
							end
							synced = true
						end
						break
					end
				end
			end

			if not synced and leaderChar and localSyncTrack.Length > 0 then
				local sTime = fakeStartTimes[leaderChar] or leaderChar:GetAttribute("DanceStartTime")
				local sSpeed = leaderChar:GetAttribute("DanceSpeed") or 1
				if sTime then
					local expectedPos = ((workspace:GetServerTimeNow() - sTime) * sSpeed) % localSyncTrack.Length
					local diff = wrapDiff(expectedPos - localSyncTrack.TimePosition, localSyncTrack.Length)
					local absDiff = math.abs(diff)

					if absDiff <= 0.05 then
						pcall(function() localSyncTrack:AdjustSpeed(sSpeed) end)
					elseif absDiff <= 0.40 then
						local nudge = math.clamp(diff * 0.35, -0.15, 0.15)
						pcall(function() localSyncTrack:AdjustSpeed(math.max(0.05, sSpeed * (1 + nudge))) end)
					else
						pcall(function() localSyncTrack.TimePosition = expectedPos end)
						pcall(function() localSyncTrack:AdjustSpeed(sSpeed) end)
					end
				end
			end
		end

		local myReferenceTrack = localSyncTrack or localAnimTrack

		for _, p in ipairs(Players:GetPlayers()) do
			local char = p.Character
			if not (char and char ~= myChar) then continue end

			local targetHrp = char:FindFirstChild("HumanoidRootPart")
			if not targetHrp or (myHrp.Position - targetHrp.Position).Magnitude > CULL_DISTANCE then 
				continue 
			end

			local animator = char:FindFirstChild("Humanoid") and char.Humanoid:FindFirstChild("Animator")
			if not animator then continue end

			local syncingTo = char:GetAttribute("Syncing")

			if syncingTo == player.Name then
				if myReferenceTrack and myReferenceTrack.IsPlaying then
					local myNorm = myReferenceTrack.Animation and normalizeId(myReferenceTrack.Animation.AnimationId)
					for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
						local tId = track.Animation and track.Animation.AnimationId
						if tId and (normalizeId(tId) == myNorm or tId == myReferenceTrack.Animation.AnimationId) then
							syncTrackPosition(track, myReferenceTrack.TimePosition, currentSpeed, 0.03)
						end
					end
				end
				continue 
			end

			if syncingTo and syncingTo ~= "" then
				local leader = Players:FindFirstChild(syncingTo)
				local leaderChar = leader and leader.Character
				local leaderAnimator = leaderChar and leaderChar:FindFirstChild("Humanoid") and leaderChar.Humanoid:FindFirstChild("Animator")
				local currentDanceId = char:GetAttribute("CurrentDanceID")
				local danceNorm = currentDanceId and normalizeId(currentDanceId)

				local leaderTrack
				if leaderAnimator then
					for _, lt in ipairs(leaderAnimator:GetPlayingAnimationTracks()) do
						local ltId = lt.Animation and lt.Animation.AnimationId
						if ltId and (normalizeId(ltId) == danceNorm or ltId == currentDanceId) and lt.IsPlaying then
							leaderTrack = lt
							break
						end
					end
				end

				if leaderTrack and leaderTrack.Length > 0 then
					for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
						local tId = track.Animation and track.Animation.AnimationId
						if tId and (normalizeId(tId) == danceNorm or tId == currentDanceId) then
							syncTrackPosition(track, leaderTrack.TimePosition, leaderTrack.Speed, 0.03)
						end
					end
					continue
				end
			end

			local startTime = fakeStartTimes[char] or char:GetAttribute("DanceStartTime")
			local speed = char:GetAttribute("DanceSpeed") or 1
			local currentDanceId = char:GetAttribute("CurrentDanceID")

			if startTime and currentDanceId then
				local danceNorm = normalizeId(currentDanceId)
				for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
					local tId = track.Animation and track.Animation.AnimationId
					if tId and (normalizeId(tId) == danceNorm or tId == currentDanceId) and track.Length > 0 then
						local elapsed = workspace:GetServerTimeNow() - startTime
						local exactPos = (elapsed * speed) % track.Length
						if exactPos > 0 then
							syncTrackPosition(track, exactPos, speed, 0.03)
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

	if leaderDanceConn then leaderDanceConn:Disconnect() leaderDanceConn = nil end
	if leaderCharAddedConn then leaderCharAddedConn:Disconnect() leaderCharAddedConn = nil end

	for _, conn in ipairs(scriptConnections) do
		if conn and conn.Connected then
			conn:Disconnect()
		end
	end
	table.clear(scriptConnections)

	for _, conns in pairs(characterConnections) do
		for _, c in ipairs(conns) do
			if c and c.Connected then c:Disconnect() end
		end
	end
	table.clear(characterConnections)

	for _, conns in pairs(playerConnections) do
		for _, c in ipairs(conns) do
			if c and c.Connected then c:Disconnect() end
		end
	end
	table.clear(playerConnections)

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

local oldDragDetector = mainframe:FindFirstChildOfClass("UIDragDetector")
if oldDragDetector then
	oldDragDetector:Destroy()
end

local OPEN_POS = UDim2.new(0, 16, 0.5, 0)
local CLOSED_POS = UDim2.new(0, -360, 0.5, 0)
local BTN_CLOSED_POS = UDim2.new(0, 16, 0.5, 0)

local function getEffectiveWidth()
	local scale = 1
	local scaleObj = mainframe:FindFirstChild("ResponsiveScale") or mainframe:FindFirstChild("PCScale")
	if scaleObj and scaleObj:IsA("UIScale") then
		scale = scaleObj.Scale
	end
	return mainframe.Size.X.Offset * scale
end

local function getBtnOpenPos()
	local gap = 8 
	return UDim2.new(0, math.round(OPEN_POS.X.Offset + getEffectiveWidth() + gap), 0.5, 0)
end

mainframe.AnchorPoint = Vector2.new(0, 0.5)
if toggleBtn then
	toggleBtn.AnchorPoint = Vector2.new(0, 0.5)
end

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
		isCustomPosition = false 
		mainframe.Visible = true

		currentTweenMain = TweenService:Create(mainframe, TWEEN_INFO_OPEN, { Position = OPEN_POS })
		if toggleBtn then
			currentTweenBtn = TweenService:Create(toggleBtn, TWEEN_INFO_OPEN, { Position = getBtnOpenPos() })
			currentTweenBtn:Play()
		end
		currentTweenMain:Play()
	else
		isDrawerOpen = false
		isCustomPosition = false

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

if toggleBtn then
	toggleBtn.Position = BTN_CLOSED_POS
	toggleBtn.Visible = true

	toggleBtn.MouseButton1Click:Connect(function()
		setDrawer(not isDrawerOpen)
	end)
end

mainframe.Position = CLOSED_POS
mainframe.Visible = false

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
