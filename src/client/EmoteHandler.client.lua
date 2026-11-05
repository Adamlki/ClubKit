-- SINGLETON PROTECTION
-- Mencegah script berjalan ganda jika masih ada LocalScript di StarterGui.EmoteGui
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
local DanceState = require(Modules:WaitForChild("DanceState"))
AnimatorUtils.AnimationPreloader = AnimationPreloader
local UIAnimator = require(ReplicatedStorage:WaitForChild("UIAnimator"))

-- GLOBAL CONNECTION TRACKER
local isScriptActive = true
local scriptConnections = {}
local characterConnections = {}
local playerConnections = {}
local globalSyncListeners = setmetatable({}, { __mode = "k" })
local leaderCharAddedConn = nil
local leaderDanceConn = nil

-- SNAPSHOT & RENDERER STATE
local parsedSnapshots = setmetatable({}, { __mode = "k" })
local snapshotByPlayerName = {}
local renderStates = setmetatable({}, { __mode = "k" })
local forgetRenderCharacter
local updateUnsyncFrame
local localSourceRestartSeq = 0
local localPlayToken = 0
local localAppliedSpeed = 1
local renderAccumulator = 0
local pruneAccumulator = 0
local lastSpeedPublish = 0
local lastPublishedSpeed = nil
local RENDER_INTERVAL = 1 / 20
local MIRROR_CULL_DISTANCE = 90
local PRUNE_INTERVAL = 5

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
	if globalSyncListeners then
		globalSyncListeners[char] = nil
	end
	if forgetRenderCharacter then
		forgetRenderCharacter(char)
	end
end

-- GUI ELEMENTS
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

-- VARIABLES & CONSTANTS
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

-- CORE ANIMATION & STATE CONTROL
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

-- GUI HELPER FUNCTIONS
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

-- ==========================================================================
-- DANCE MIRROR RENDERER
-- Semua dancer selain local player dirender ulang secara lokal dari snapshot.
-- Track native mereka dihentikan karena TimePosition/AdjustSpeed tidak
-- direplikasi Roblox. Dengan satu snapshot, semua mirror di satu client
-- memakai fase dan speed yang sama.
-- ==========================================================================

local function getCharacterAnimator(char)
	if not char then return nil end
	local humanoid = char:FindFirstChildOfClass("Humanoid")
	return humanoid and humanoid:FindFirstChildOfClass("Animator")
end

local function isLocalFollowing()
	local char = player.Character
	if not char then return false end
	local syncingTo = char:GetAttribute("Syncing")
	return syncingTo ~= nil and syncingTo ~= ""
end

local function getActiveLocalDanceTrack()
	local char = player.Character
	if not char then return nil end
	local syncingTo = char:GetAttribute("Syncing")
	if syncingTo and syncingTo ~= "" then
		return nil
	end

	if localAnimTrack and localAnimTrack.IsPlaying and localAnimTrack.Animation then
		return localAnimTrack
	end

	-- Fallback untuk track yang dibuat script lain (mis. resume GlobalEffect).
	local animator = getCharacterAnimator(char)
	local currentDanceId = char:GetAttribute("CurrentDanceID")
	if animator and currentDanceId and currentDanceId ~= "" then
		local norm = DanceState.normalizeId(currentDanceId)
		for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
			if track.Animation and track.IsPlaying and DanceState.normalizeId(track.Animation.AnimationId) == norm then
				return track
			end
		end
	end

	return nil
end

local function legacyStateForCharacter(char)
	local animationId = char:GetAttribute("CurrentDanceID")
	if not animationId or animationId == "" then
		return nil
	end

	local startTime = char:GetAttribute("DanceStartTime")
	if type(startTime) ~= "number" or startTime ~= startTime then
		startTime = workspace:GetServerTimeNow()
	end

	return {
		animationId = animationId,
		anchorTime = startTime,
		anchorPosition = 0,
		speed = math.clamp(tonumber(char:GetAttribute("DanceSpeed")) or 1, 0.1, 3),
		restartSeq = tonumber(char:GetAttribute("SpamNonce")) or 0,
		version = 0,
	}
end

local function parseSnapshotForCharacter(char)
	local parsed = DanceState.decode(char:GetAttribute("DanceSnapshot"))
	parsedSnapshots[char] = parsed

	local targetPlayer = Players:GetPlayerFromCharacter(char)
	if targetPlayer then
		snapshotByPlayerName[targetPlayer.Name] = parsed
	end

	return parsed
end

local function getStateForCharacter(char)
	return parsedSnapshots[char] or legacyStateForCharacter(char)
end

-- Mengembalikan: sourceKind, sourceCharacter, sourceState, sourceTrack,
-- animationId, restartMarker.
local function getSourceForCharacter(char)
	local myChar = player.Character
	local syncingTo = char:GetAttribute("Syncing")
	local isLocal = (char == myChar)

	if isLocal and (not syncingTo or syncingTo == "") then
		local track = getActiveLocalDanceTrack()
		if track and track.Animation then
			return "local", char, nil, track, track.Animation.AnimationId, localSourceRestartSeq
		end
		return nil
	end

	if syncingTo and syncingTo ~= "" then
		local leader = Players:FindFirstChild(syncingTo)
		local leaderChar = leader and leader.Character

		if leaderChar then
			-- Kalau local player adalah leader, follower langsung mengikuti
			-- track lokal tanpa menunggu snapshot/jaringan.
			if leaderChar == myChar and (not myChar:GetAttribute("Syncing") or myChar:GetAttribute("Syncing") == "") then
				local track = getActiveLocalDanceTrack()
				if track and track.Animation then
					return "local", leaderChar, nil, track, track.Animation.AnimationId, localSourceRestartSeq
				end
				return nil
			end

			local state = getStateForCharacter(leaderChar)
			if state then
				return "snapshot", leaderChar, state, nil, state.animationId, state.restartSeq
			end
			return nil
		end

		-- Leader tidak sedang ter-stream, tapi snapshot terakhir masih tersimpan.
		local state = snapshotByPlayerName[syncingTo]
		if state then
			return "snapshot", nil, state, nil, state.animationId, state.restartSeq
		end
		return nil
	end

	local state = getStateForCharacter(char)
	if not state then
		return nil
	end
	return "snapshot", char, state, nil, state.animationId, state.restartSeq
end

local function isPoseAnimation(animation)
	return animation ~= nil and animation.Parent ~= nil and animation.Parent.Name == "Pose"
end

forgetRenderCharacter = function(char)
	local state = renderStates[char]
	if not state then return end

	if state.track then
		pcall(function() state.track:Stop(0) end)
	end
	if char == player.Character and localSyncTrack == state.track then
		localSyncTrack = nil
	end

	renderStates[char] = nil
	parsedSnapshots[char] = nil
end

local function stopRenderState(char, fade)
	local state = renderStates[char]
	if not state then return end

	local track = state.track
	if track then
		pcall(function() track:Stop(fade or DANCE_SWITCH_FADE) end)
	end
	if char == player.Character and localSyncTrack == track then
		localSyncTrack = nil
	end

	state.track = nil
	state.animId = nil
	state.animIdNorm = nil
	state.restartMarker = nil
	state.lastSpeed = nil
	state.sourceKind = nil
end

local function getRenderState(char, animator)
	local state = renderStates[char]
	if state and state.animator ~= animator then
		forgetRenderCharacter(char)
		state = nil
	end

	if not state then
		state = {
			char = char,
			animator = animator,
			track = nil,
			animId = nil,
			animIdNorm = nil,
			restartMarker = nil,
			lastSpeed = nil,
			ourTracks = setmetatable({}, { __mode = "k" }),
		}
		renderStates[char] = state
	end

	return state
end

local function updateRenderCharacter(char, now, force)
	if not char or not char.Parent then return end

	local myChar = player.Character
	local isLocal = (char == myChar)
	local localFollowing = isLocal and isLocalFollowing()
	local syncingTo = char:GetAttribute("Syncing")

	-- Local player yang sedang menjadi leader/solo adalah sumber. Jangan
	-- pernah membuat mirror untuk dirinya sendiri.
	if isLocal and not localFollowing then
		local state = renderStates[char]
		if state and state.track then
			stopRenderState(char, DANCE_SWITCH_FADE)
		end
		return
	end

	-- Selama global effect, animasi efek yang menang.
	if char:GetAttribute("GlobalEffectActive") == true then
		stopRenderState(char, 0.1)
		return
	end

	-- Cull mirror yang jauh. Local follower sendiri tidak pernah di-cull.
	if not isLocal then
		local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
		local hrp = char:FindFirstChild("HumanoidRootPart")
		if not myHrp or not hrp or (myHrp.Position - hrp.Position).Magnitude > MIRROR_CULL_DISTANCE then
			stopRenderState(char, DANCE_SWITCH_FADE)
			return
		end
	end

	local sourceKind, sourceChar, sourceState, sourceTrack, animationId, restartMarker = getSourceForCharacter(char)
	if not animationId or animationId == "" then
		stopRenderState(char, DANCE_SWITCH_FADE)
		return
	end

	local animator = getCharacterAnimator(char)
	if not animator then
		forgetRenderCharacter(char)
		return
	end

	local targetAnim = findAnimById(animationId)
	if not targetAnim then
		stopRenderState(char, DANCE_SWITCH_FADE)
		return
	end

	local state = getRenderState(char, animator)
	local normId = DanceState.normalizeId(animationId)
	local isPose = isPoseAnimation(targetAnim)

	local targetTrack = nil
	if state.track and state.animIdNorm == normId then
		targetTrack = state.track
	else
		targetTrack = AnimatorUtils.getOrCreateTrack(animator, targetAnim)
	end

	if not targetTrack then
		return
	end

	local length = targetTrack.Length
	if not length or length <= 0 then
		-- Asset belum siap. Track lama tetap diputar; jangan pernah
		-- memainkan track baru yang Length-nya masih 0.
		return
	end

	local targetSpeed
	if sourceKind == "local" then
		targetSpeed = sourceTrack and sourceTrack.Speed or localAppliedSpeed
	else
		targetSpeed = sourceState and sourceState.speed or 1
	end
	targetSpeed = math.clamp(tonumber(targetSpeed) or 1, 0.1, 3)

	local targetPos
	if sourceKind == "local" then
		targetPos = sourceTrack and sourceTrack.TimePosition or 0
	else
		local elapsed = (now - sourceState.anchorTime) * sourceState.speed
		if isPose and elapsed >= length then
			stopRenderState(char, DANCE_SWITCH_FADE)
			return
		end
		targetPos = DanceState.positionAt(sourceState, length, now, not isPose)
	end

	local sameAnimation = state.track ~= nil
		and state.animIdNorm == normId
		and state.track.IsPlaying

	local switchFade = DANCE_SWITCH_FADE

	if not sameAnimation then
		local oldTrack = state.track

		state.ourTracks[targetTrack] = true
		targetTrack.Priority = Enum.AnimationPriority.Action4
		pcall(function() targetTrack.TimePosition = targetPos end)
		targetTrack:Play(switchFade, 1, targetSpeed)
		pcall(function() targetTrack.TimePosition = targetPos end)
		pcall(function() targetTrack:AdjustSpeed(targetSpeed) end)

		state.track = targetTrack
		state.animId = animationId
		state.animIdNorm = normId
		state.restartMarker = restartMarker
		state.lastSpeed = targetSpeed
		state.sourceKind = sourceKind

		if oldTrack and oldTrack ~= targetTrack then
			pcall(function() oldTrack:Stop(switchFade) end)
		end

		if isLocal then
			localSyncTrack = targetTrack
		end
		return
	end

	-- Restart eksplisit (spam / start ulang) harus mengenai semua mirror
	-- pada frame yang sama. Tidak ada speed reset sebelum transisi.
	if force or restartMarker ~= state.restartMarker then
		pcall(function() state.track.TimePosition = targetPos end)
		pcall(function() state.track:AdjustSpeed(targetSpeed) end)
		state.restartMarker = restartMarker
		state.lastSpeed = targetSpeed
		return
	end

	if math.abs((state.track.Speed or 1) - targetSpeed) > 0.005 then
		pcall(function() state.track:AdjustSpeed(targetSpeed) end)
		state.lastSpeed = targetSpeed
	end

	-- Koreksi sisa drift hanya lewat speed. TimePosition baru di-set pada
	-- restart, switch, initial sync, atau desync yang benar-benar besar.
	local diff = DanceState.wrapDiff(targetPos - state.track.TimePosition, length)
	local absDiff = math.abs(diff)

	if absDiff > 1.5 then
		pcall(function() state.track.TimePosition = targetPos end)
	elseif absDiff > 0.06 then
		local correction = math.clamp(diff * 1.5, -0.18, 0.18)
		pcall(function()
			state.track:AdjustSpeed(math.max(0.05, targetSpeed * (1 + correction)))
		end)
	elseif math.abs((state.track.Speed or 1) - targetSpeed) > 0.005 then
		pcall(function() state.track:AdjustSpeed(targetSpeed) end)
	end
end

local function refreshLocalGroup(force)
	local myChar = player.Character
	if not myChar then return end

	local now = workspace:GetServerTimeNow()
	local localName = player.Name
	for _, otherPlayer in ipairs(Players:GetPlayers()) do
		local char = otherPlayer.Character
		if char and char ~= myChar and char:GetAttribute("Syncing") == localName then
			updateRenderCharacter(char, now, force ~= false)
		end
	end
end

local function updateAllRenderCharacters(now, force)
	local myChar = player.Character
	local localFollowing = isLocalFollowing()

	for _, otherPlayer in ipairs(Players:GetPlayers()) do
		local char = otherPlayer.Character
		if char and (char ~= myChar or localFollowing) then
			updateRenderCharacter(char, now, force)
		end
	end
end

local function suppressNativeDanceTrack(char, track)
	if not track or not track.Animation then return end

	local state = renderStates[char]
	if state and state.ourTracks[track] then return end

	local myChar = player.Character
	if char == myChar and not isLocalFollowing() then
		return
	end

	local animationId = track.Animation.AnimationId
	if isClubDanceId(animationId) or track.Priority == Enum.AnimationPriority.Action4 then
		pcall(function() track:Stop(0) end)
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

		-- Track native dance pada karakter remote dihentikan. Track mirror
		-- buatan renderer kita sendiri dikecualikan lewat state.ourTracks.
		trackCharConn(animator.AnimationPlayed:Connect(function(track)
			suppressNativeDanceTrack(char, track)
		end))

		-- Track dance yang sudah terlanjur diputar sebelum listener terpasang
		-- juga harus dihentikan supaya tidak dobel dengan mirror.
		for _, existingTrack in ipairs(animator:GetPlayingAnimationTracks()) do
			suppressNativeDanceTrack(char, existingTrack)
		end

		local function onSnapshotChanged()
			parseSnapshotForCharacter(char)
		end

		trackCharConn(char:GetAttributeChangedSignal("DanceSnapshot"):Connect(onSnapshotChanged))

		trackCharConn(char:GetAttributeChangedSignal("Syncing"):Connect(function()
			if char == player.Character and updateUnsyncFrame then
				updateUnsyncFrame()
			end
		end))

		trackCharConn(char:GetAttributeChangedSignal("GlobalEffectActive"):Connect(function()
			if char:GetAttribute("GlobalEffectActive") == true then
				stopRenderState(char, 0.1)
			end
		end))

		parseSnapshotForCharacter(char)
	end

	local charAddedConn = targetPlayer.CharacterAdded:Connect(onCharacterAdded)
	table.insert(playerConnections[targetPlayer], charAddedConn)

	local charRemovingConn = targetPlayer.CharacterRemoving:Connect(function(oldChar)
		snapshotByPlayerName[targetPlayer.Name] = nil
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

	snapshotByPlayerName[leavingPlayer.Name] = nil

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

-- GUI & SYNC MANAGEMENT

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

function updateUnsyncFrame()
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

		-- Simpan dance lokal sebelum track dihentikan. Listener lain bisa
		-- berjalan lebih dulu, jadi jangan bergantung pada urutan sinyal.
		if not savedLocalEmoteData and currentAnimation then
			for _, data in ipairs(allButtons) do
				if data.button == currentAnimation then
					savedLocalEmoteData = {
						animation = data.animation,
						button = currentAnimation,
						speed = currentSpeed,
					}
					break
				end
			end
		end

		-- Dance lokal harus berhenti saat mulai menjadi follower. Mirror
		-- renderer akan memutar dance leader pada karakter ini.
		local character = player.Character
		if localAnimTrack then
			pcall(function() localAnimTrack:Stop(FADE_TIME) end)
			localAnimTrack = nil
		end
		if localSyncTrack then
			pcall(function() localSyncTrack:Stop(FADE_TIME) end)
			localSyncTrack = nil
		end
		if character then
			local animator = getCharacterAnimator(character)
			if animator then
				killGhostAnimation(animator, FADE_TIME)
			end
			freezeHumanoidForPose(character, false)
		end

		-- UI kembali netral selama mengikuti leader. Dance yang disimpan
		-- akan dipulihkan saat unsync.
		currentAnimation = nil
		lastEmoteClickTime = 0
		updateButtonVisuals()

		setMenuElementsBlocked(true)
		unsyncframe.Visible = true

		-- Mulai mirror pada frame ini juga, jangan menunggu render tick.
		updateAllRenderCharacters(workspace:GetServerTimeNow(), true)
	else
		if leaderDanceConn then leaderDanceConn:Disconnect() leaderDanceConn = nil end
		if leaderCharAddedConn then leaderCharAddedConn:Disconnect() leaderCharAddedConn = nil end
		
		unsyncframe.Visible = false
		setMenuElementsBlocked(false)

		isSyncing = false
		currentLeaderName = nil
		if localSyncTrack then 
			pcall(function() localSyncTrack:Stop(FADE_TIME) end)
			localSyncTrack = nil 
		end
		if player.Character then
			restoreCharacterAnimations(player.Character)
		end

		-- Kembalikan dance lokal yang tadi disimpan saat mulai sync.
		if savedLocalEmoteData and not currentAnimation then
			local saved = savedLocalEmoteData
			savedLocalEmoteData = nil
			currentSpeed = saved.speed or currentSpeed
			if speedSlider and speedBar and speedtext then
				local scale = (currentSpeed - SPEED_MIN) / (SPEED_MAX - SPEED_MIN)
				speedSlider.Position = UDim2.fromScale(math.clamp(scale, 0, 1), 0.5)
				speedtext.Text = string.format("%.1fx", math.floor(currentSpeed * 10 + 0.5) / 10)
			end
			task.delay(0.08, function()
				if not isScriptActive or isSyncing or currentAnimation then return end
				if localAnimTrack and localAnimTrack.IsPlaying then return end
				animationStarted(saved.animation, saved.button, true)
			end)
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

-- ANIMATION STARTED
local function publishPlaySnapshot(animation, track, isSpam, fade)
	if not animation or not track or not track.Animation then return end
	if not isScriptActive then return end

	animationStartRE:FireServer(
		animation.AnimationId,
		true,
		localAppliedSpeed,
		fade or DANCE_SWITCH_FADE,
		isSpam == true,
		workspace:GetServerTimeNow(),
		track.TimePosition
	)
	lastSpeedPublish = os.clock()
	lastPublishedSpeed = localAppliedSpeed
end

local function playLocalDance(animation, isSpam, isPose)
	local character = player.Character
	local animator = getCharacterAnimator(character)
	if not character or not animator or not animation then
		return false
	end

	local normId = DanceState.normalizeId(animation.AnimationId)
	local token = localPlayToken + 1
	localPlayToken = token

	-- Spam dance yang sama: restart track yang sudah siap. Tidak ada
	-- fade keluar/masuk yang membuat karakter terlihat patah.
	if localAnimTrack and localAnimTrack.IsPlaying and localAnimTrack.Animation
		and DanceState.normalizeId(localAnimTrack.Animation.AnimationId) == normId then
		localAppliedSpeed = currentSpeed
		localAnimTrack.Priority = Enum.AnimationPriority.Action4
		pcall(function() localAnimTrack.TimePosition = 0 end)
		pcall(function() localAnimTrack:AdjustSpeed(localAppliedSpeed) end)
		setAnimateEnabled(character, false)
		localSourceRestartSeq += 1
		lastDanceSwitchTime = os.clock()

		refreshLocalGroup(true)
		publishPlaySnapshot(animation, localAnimTrack, true, DANCE_SWITCH_FADE)

		task.delay(DANCE_SWITCH_FADE + 0.02, function()
			if isScriptActive and localPlayToken == token and localAnimTrack then
				freezeHumanoidForPose(character, isPose)
			end
		end)
		return true
	end

	local track = AnimatorUtils.getOrCreateTrack(animator, animation)
	if not track then
		return false
	end

	local function beginPlay()
		if token ~= localPlayToken or not isScriptActive then return end
		if not track or not track.Animation or track.Length <= 0 then return end

		local currentCharacter = player.Character
		if not currentCharacter then return end

		local currentAnimator = getCharacterAnimator(currentCharacter)
		if not currentAnimator then return end

		local oldTrack = localAnimTrack
		localAppliedSpeed = currentSpeed

		setAnimateEnabled(currentCharacter, false)
		track.Priority = Enum.AnimationPriority.Action4

		-- Penting: track baru diputar setelah Length > 0. Dance lama tetap
		-- berjalan sampai titik ini, jadi tidak ada frame karakter diam.
		pcall(function() track.TimePosition = 0 end)
		track:Play(DANCE_SWITCH_FADE, 1, localAppliedSpeed)
		pcall(function() track.TimePosition = 0 end)
		pcall(function() track:AdjustSpeed(localAppliedSpeed) end)

		localAnimTrack = track

		if oldTrack and oldTrack ~= track then
			pcall(function() oldTrack:Stop(DANCE_SWITCH_FADE) end)
		end

		killGhostAnimation(currentAnimator, DANCE_SWITCH_FADE, track)
		localSourceRestartSeq += 1
		lastDanceSwitchTime = os.clock()

		refreshLocalGroup(true)
		publishPlaySnapshot(animation, track, isSpam, DANCE_SWITCH_FADE)

		task.delay(DANCE_SWITCH_FADE + 0.02, function()
			if isScriptActive and localPlayToken == token and localAnimTrack == track then
				freezeHumanoidForPose(currentCharacter, isPose)
			end
		end)
	end

	if track.Length > 0 then
		beginPlay()
	else
		-- First-click / asset belum siap: tunggu track benar-benar punya
		-- Length, sambil dance lama terus diputar.
		local lengthConn
		local done = false
		local function tryStart()
			if done then return end
			if track.Length > 0 then
				done = true
				if lengthConn then lengthConn:Disconnect() lengthConn = nil end
				beginPlay()
			end
		end

		lengthConn = track:GetPropertyChangedSignal("Length"):Connect(tryStart)
		local timeoutThread = task.delay(3, function()
			if done then return end
			done = true
			if lengthConn then lengthConn:Disconnect() lengthConn = nil end
		end)
		task.delay(0.01, tryStart)
	end

	return true
end

local function stopLocalDance(animationId, fade)
	local character = player.Character
	local animator = getCharacterAnimator(character)
	local track = localAnimTrack or getActiveLocalDanceTrack()

	localPlayToken += 1
	localAnimTrack = nil
	localSourceRestartSeq += 1
	lastPublishedSpeed = nil
	lastSpeedPublish = 0

	if track then
		pcall(function() track:Stop(fade or FADE_TIME) end)
	end
	if animator then
		killGhostAnimation(animator, fade or FADE_TIME)
	end
	restoreCharacterAnimations(character)

	if animationId and animationId ~= "" then
		animationStartRE:FireServer(
			animationId,
			false,
			currentSpeed,
			0,
			false,
			workspace:GetServerTimeNow(),
			0
		)
	end

	refreshLocalGroup(true)
end

function animationStarted(animation, button, ignoreLock)
	if not animation or (inputLock and not ignoreLock) or pendingRequest then return end

	inputLock = true
	task.delay(0.02, function()
		inputLock = false
	end)

	local currentTime = os.clock()
	local character = player.Character
	if not character then return end

	if isSyncing then
		isSyncing = false
		savedLocalEmoteData = nil
		local prevLeader = currentLeaderName
		currentLeaderName = nil
		if unsyncframe then unsyncframe.Visible = false end
		if localSyncTrack then
			pcall(function() localSyncTrack:Stop(DANCE_SWITCH_FADE) end)
			localSyncTrack = nil
		end
		if prevLeader then
			local lp = Players:FindFirstChild(prevLeader)
			if lp then
				startSyncRE:FireServer(lp, false)
			end
		end
		character:SetAttribute("Syncing", nil)
	end

	local timeSinceLastClick = currentTime - lastEmoteClickTime
	local isSpamming = (timeSinceLastClick < 0.7)

	if currentAnimation == button then
		if isSpamming then
			-- Spam: restart seketika tanpa mematikan track lama lebih dulu.
			lastEmoteClickTime = os.clock()
			local isPose = buttonCategoryMap[button] == "Pose"
			playLocalDance(animation, true, isPose)
		else
			local stopAnimationId = nil
			if localAnimTrack and localAnimTrack.Animation then
				stopAnimationId = localAnimTrack.Animation.AnimationId
			else
				local activeTrack = getActiveLocalDanceTrack()
				if activeTrack and activeTrack.Animation then
					stopAnimationId = activeTrack.Animation.AnimationId
				end
			end

			currentAnimation = nil
			lastEmoteClickTime = 0
			updateButtonVisuals()
			savedLocalEmoteData = nil
			stopLocalDance(stopAnimationId, FADE_TIME)
		end
	else
		savedLocalEmoteData = nil
		currentAnimation = button
		lastEmoteClickTime = os.clock()
		updateButtonVisuals()

		local isPose = buttonCategoryMap[button] == "Pose"
		playLocalDance(animation, false, isPose)
	end
end

-- GUI & BUTTON BUILDER

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

-- SPEED SLIDER
-- Knob mengikuti input secara langsung (tanpa easing). Speed animasi memakai
-- ramp pendek di updateLocalSpeed agar perubahan tetap halus.
if speedSlider and speedBar and speedtext and speedButton then
	local isDraggingSpeed = false
	local activeInput = nil
	speedSlider.AnchorPoint = Vector2.new(0.5, 0.5)

	local function scaleToSpeed(scale)
		return math.floor((SPEED_MIN + scale * (SPEED_MAX - SPEED_MIN)) * 100 + 0.5) / 100
	end
	local function speedToScale(speed)
		return (speed - SPEED_MIN) / (SPEED_MAX - SPEED_MIN)
	end

	local function applyScale(scale)
		scale = math.clamp(scale, 0, 1)
		speedSlider.Position = UDim2.fromScale(scale, 0.5)

		local newSpeed = scaleToSpeed(scale)
		if newSpeed ~= currentSpeed then
			currentSpeed = newSpeed
			speedtext.Text = string.format("%.1fx", math.floor(currentSpeed * 10 + 0.5) / 10)
		end
	end

	local function updateSlider(input)
		local width = math.max(1, speedBar.AbsoluteSize.X)
		local scale = (input.Position.X - speedBar.AbsolutePosition.X) / width
		applyScale(scale)
	end

	speedBar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			if isSyncing then
				showNotification("Cannot change speed while syncing", 2, Color3.fromRGB(0, 0, 0))
				return
			end
			isDraggingSpeed = true
			activeInput = input
			updateSlider(input)
		end
	end)

	speedButton.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			if isSyncing then
				showNotification("Cannot change speed while syncing", 2, Color3.fromRGB(0, 0, 0))
				return
			end
			isDraggingSpeed = true
			activeInput = input
		end
	end)

	trackConnection(UserInputService.InputChanged:Connect(function(input)
		if isDraggingSpeed and (input == activeInput or input.UserInputType == Enum.UserInputType.MouseMovement) then
			updateSlider(input)
		end
	end))

	trackConnection(UserInputService.InputEnded:Connect(function(input)
		if input == activeInput or input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			isDraggingSpeed = false
			activeInput = nil
			-- Snapshot final dikirim oleh loop speed saat nilainya sudah stabil.
		end
	end))

	local initialScale = speedToScale(SPEED_DEFAULT)
	speedSlider.Position = UDim2.fromScale(initialScale, 0.5)
	speedtext.Text = string.format("%.1fx", SPEED_DEFAULT)
end

-- PRELOAD & LOAD ANIMATIONS
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

-- RENDERER LOOP & SPEED STREAM
-- 20 Hz cukup untuk semua mirror; aksi leader memakai refreshLocalGroup
-- agar follower di layar leader berubah pada frame yang sama.
local function publishLocalSpeedSnapshot()
	if not isScriptActive then return end

	local char = player.Character
	if not char then return end
	local syncingTo = char:GetAttribute("Syncing")
	if syncingTo and syncingTo ~= "" then return end

	local track = getActiveLocalDanceTrack()
	if not track or not track.Animation then return end

	local nowClock = os.clock()
	if nowClock - lastSpeedPublish < (1 / 20) then return end
	if lastPublishedSpeed ~= nil and math.abs(lastPublishedSpeed - localAppliedSpeed) < 0.001 then
		return
	end

	changeSpeedRE:FireServer(localAppliedSpeed, workspace:GetServerTimeNow(), track.TimePosition)
	lastSpeedPublish = nowClock
	lastPublishedSpeed = localAppliedSpeed
end

local function updateLocalSpeed(dt)
	if math.abs(localAppliedSpeed - currentSpeed) > 0.0005 then
		local alpha = 1 - math.exp(-dt * 22)
		localAppliedSpeed += (currentSpeed - localAppliedSpeed) * alpha
		if math.abs(localAppliedSpeed - currentSpeed) < 0.004 then
			localAppliedSpeed = currentSpeed
		end

		local track = getActiveLocalDanceTrack()
		if track and track.IsPlaying then
			pcall(function() track:AdjustSpeed(localAppliedSpeed) end)
		end
	elseif localAppliedSpeed ~= currentSpeed then
		localAppliedSpeed = currentSpeed
	end
end

local function pruneRemoteTracks()
	local keepByAnimator = {}

	for _, otherPlayer in ipairs(Players:GetPlayers()) do
		local char = otherPlayer.Character
		local animator = getCharacterAnimator(char)
		if animator then
			keepByAnimator[animator] = keepByAnimator[animator] or {}
		end
	end

	for char, state in pairs(renderStates) do
		if state.animator and state.track then
			local keep = keepByAnimator[state.animator]
			if not keep then
				keep = {}
				keepByAnimator[state.animator] = keep
			end
			keep[state.track] = true
		end
		if not char.Parent then
			renderStates[char] = nil
		end
	end

	for animator, keep in pairs(keepByAnimator) do
		AnimatorUtils.pruneTracks(animator, keep)
	end
end

trackConnection(RunService.RenderStepped:Connect(function(dt)
	if not isScriptActive then return end
	updateLocalSpeed(dt)
end))

trackConnection(RunService.Heartbeat:Connect(function(dt)
	if not isScriptActive then return end

	renderAccumulator += dt
	if renderAccumulator < RENDER_INTERVAL then return end
	renderAccumulator = 0

	local now = workspace:GetServerTimeNow()
	updateAllRenderCharacters(now, false)
	publishLocalSpeedSnapshot()

	pruneAccumulator += dt
	if pruneAccumulator >= PRUNE_INTERVAL then
		pruneAccumulator = 0
		pruneRemoteTracks()
	end
end))

-- CLEANUP
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
	localAppliedSpeed = 1
	localSourceRestartSeq += 1
	lastPublishedSpeed = nil
	lastSpeedPublish = 0
	currentAnimation = nil
	lastEmoteClickTime = 0
	savedLocalEmoteData = nil
	if speedSlider and speedBar and speedtext then
		local scale = (SPEED_DEFAULT - SPEED_MIN) / (SPEED_MAX - SPEED_MIN)
		speedSlider.Position = UDim2.fromScale(scale, 0.5)
		speedtext.Text = string.format("%.1fx", SPEED_DEFAULT)
	end
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

-- DRAWER SLIDE & DRAG CONTROLLER (RESET ON CLOSE & DOCKED BUTTON)
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
