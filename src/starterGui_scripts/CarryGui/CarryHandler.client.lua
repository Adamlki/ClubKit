-- CarryHandler.lua (LocalScript)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local character = player.Character or player.CharacterAdded:Wait()

local CarryConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("CarryConfig"))
local UIAnimator  = require(ReplicatedStorage:WaitForChild("UIAnimator"))

local remoteFolder = ReplicatedStorage:WaitForChild(CarryConfig.REMOTE_FOLDER, 10)
if not remoteFolder then
	warn("[CARRY UI] Remote folder not found!")
	return
end

local RequestRemote  = remoteFolder:WaitForChild("CarryRequest", 10)
local ResponseRemote = remoteFolder:WaitForChild("CarryResponse", 10)
local EndRemote      = remoteFolder:WaitForChild("CarryEnd", 10)

if not RequestRemote or not ResponseRemote or not EndRemote then
	warn("[CARRY UI] Gagal memuat Remote! Sinyal terlalu lambat atau folder tidak ada.")
	return
end

local gui = script.Parent:IsA("ScreenGui") and script.Parent or playerGui:WaitForChild("CarryGui", 10)
if not gui then
	warn("[CARRY UI] CarryGUI not found!")
	return
end

-- UI Elements
local mainFrame         = gui:WaitForChild("MainFrame")
local notificationFrame = gui:WaitForChild("NotificationFrame")
local getDownBtn        = gui:WaitForChild("GetDownBtn")

local notiLabel = notificationFrame:WaitForChild("NotifLabel")
local acceptBtn = notificationFrame:WaitForChild("AcceptBtn")
local rejectBtn = notificationFrame:WaitForChild("RejectBtn")
local notifAvatar = notificationFrame:FindFirstChild("Avatar")

local headerFrame   = mainFrame:FindFirstChild("HeaderFrame")
local closeBtn      = headerFrame and headerFrame:FindFirstChild("CloseBtn")
local subtitleLabel = headerFrame and headerFrame:FindFirstChild("SubtitleLabel")
local titleLabel    = headerFrame and headerFrame:FindFirstChild("TitleLabel")

local bridalBtn         = mainFrame:FindFirstChild("BridalStyle", true)
local coupleHugBtn      = mainFrame:FindFirstChild("CoupleHugStyle", true)
local pasakalBtn        = mainFrame:FindFirstChild("PasakalStyle", true)
local piggyBackBtn      = mainFrame:FindFirstChild("PiggyBackStyle", true)
local piggyUpperBackBtn = mainFrame:FindFirstChild("PiggyUpperBackStyle", true)

-- ============================================
-- BUTTON HOVER TWEENS (MODERN UI FEEL)
-- ============================================
local function setupHover(btn, normalBg, hoverBg, normalStroke, hoverStroke)
	if not btn then return end
	local stroke = btn:FindFirstChildOfClass("UIStroke")
	btn.MouseEnter:Connect(function()
		TweenService:Create(btn, TweenInfo.new(0.2), { BackgroundColor3 = hoverBg }):Play()
		if stroke and hoverStroke then
			TweenService:Create(stroke, TweenInfo.new(0.2), { Color = hoverStroke }):Play()
		end
	end)
	btn.MouseLeave:Connect(function()
		TweenService:Create(btn, TweenInfo.new(0.2), { BackgroundColor3 = normalBg }):Play()
		if stroke and normalStroke then
			TweenService:Create(stroke, TweenInfo.new(0.2), { Color = normalStroke }):Play()
		end
	end)
end

-- Setup style buttons hover
local styleButtons = { bridalBtn, coupleHugBtn, pasakalBtn, piggyBackBtn, piggyUpperBackBtn }
for _, btn in ipairs(styleButtons) do
	setupHover(btn, 
		Color3.fromRGB(26, 26, 32), 
		Color3.fromRGB(36, 36, 46), 
		Color3.fromRGB(40, 40, 48), 
		Color3.fromRGB(75, 75, 95)
	)
end

-- Close button hover
if closeBtn then
	setupHover(closeBtn,
		Color3.fromRGB(28, 28, 34),
		Color3.fromRGB(42, 42, 52),
		Color3.fromRGB(44, 44, 52),
		Color3.fromRGB(80, 80, 95)
	)
	closeBtn.MouseButton1Click:Connect(function()
		UIAnimator.Close(mainFrame)
	end)
end

-- Accept / Reject hover
setupHover(acceptBtn,
	Color3.fromRGB(24, 56, 36),
	Color3.fromRGB(32, 75, 48),
	Color3.fromRGB(46, 210, 115),
	Color3.fromRGB(70, 240, 140)
)
setupHover(rejectBtn,
	Color3.fromRGB(48, 22, 26),
	Color3.fromRGB(68, 28, 34),
	Color3.fromRGB(235, 75, 75),
	Color3.fromRGB(255, 110, 110)
)

-- GetDownBtn: default neutral styling, no hover color change
-- ============================================
-- STATE
-- ============================================
local currentState      = "idle"
local selectedTarget    = nil
local pendingCarrier    = nil
local pendingStyle      = nil
local jumpBlockConn     = nil
local currentAnimTracks = {}
local loadedAnimationsCache = {}
local styleTimeoutToken = 0

-- ============================================
-- HELPER FUNCTIONS
-- ============================================
local function getHumanoid()
	local char = player.Character
	return char and char:FindFirstChildOfClass("Humanoid")
end

local function stopAllAnimations()
	for _, track in pairs(currentAnimTracks) do
		if track and track.IsPlaying then
			pcall(function() track:Stop(0.2) end)
		end
	end
	currentAnimTracks = {}
end

local function playAnimation(styleName, role)
	stopAllAnimations()

	local hum = getHumanoid()
	if not hum then return end

	local animId = CarryConfig.getAnimationId(styleName, role)
	if not animId then return end

	local animKey = tostring(animId)
	local animation = loadedAnimationsCache[animKey]

	if not animation then
		animation = Instance.new("Animation")
		animation.AnimationId = "rbxassetid://" .. tostring(animId)
		loadedAnimationsCache[animKey] = animation
	end

	local animator = hum:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = hum
	end

	local track = animator:LoadAnimation(animation)
	track.Priority = Enum.AnimationPriority.Action
	track.Looped   = true
	track:Play(0.1)

	table.insert(currentAnimTracks, track)
end

local function hideAllFrames()
	mainFrame.Visible         = false
	notificationFrame.Visible = false
	getDownBtn.Visible        = false
end

local function cleanupState()
	selectedTarget = nil
	pendingCarrier = nil
	pendingStyle   = nil
	styleTimeoutToken = styleTimeoutToken + 1
	stopAllAnimations()
end

-- ============================================
-- UI FLOW CONTROLLERS
-- ============================================
local function showStyleSelection(target)
	if not target or not target:IsA("Player") then return end
	if not mainFrame or not mainFrame.Parent then return end

	currentState   = "selecting_style"
	selectedTarget = target

	if titleLabel then
		titleLabel.Text = "Carry " .. (target.DisplayName or target.Name)
	end
	if subtitleLabel then
		subtitleLabel.Visible = false
	end

	hideAllFrames()
	task.wait(0.05)
	UIAnimator.Open(mainFrame)

	local myToken = styleTimeoutToken + 1
	styleTimeoutToken = myToken

	task.delay(CarryConfig.REQUEST_TIMEOUT, function()
		if styleTimeoutToken == myToken and currentState == "selecting_style" then
			UIAnimator.Close(mainFrame, function()
				cleanupState()
				currentState = "idle"
			end)
		end
	end)
end

local function showCarryNotification(carrierId, carrierName, style)
	currentState   = "pending_response"
	pendingCarrier = carrierId
	pendingStyle   = style

	hideAllFrames()

	if notifAvatar and carrierId then
		notifAvatar.Image = string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150", carrierId)
	end

	local styleData = CarryConfig.getStyle(style)
	local styleNameDisplay = styleData and styleData.displayName or style
	notiLabel.Text = string.format("<b>%s</b> ingin menggendongmu dengan gaya <b>%s</b>", carrierName, styleNameDisplay)

	task.wait(0.05)
	UIAnimator.Open(notificationFrame)
end

local function showGetDownButton()
	currentState = "being_carried"

	hideAllFrames()
	task.wait(0.05)
	UIAnimator.Open(getDownBtn)

	if not jumpBlockConn then
		jumpBlockConn = UserInputService.JumpRequest:Connect(function()
			local hum = getHumanoid()
			if hum then hum.Jump = false end
		end)
	end
end

local function hideGetDownButton()
	UIAnimator.Close(getDownBtn)

	if jumpBlockConn then
		jumpBlockConn:Disconnect()
		jumpBlockConn = nil
	end
end

-- ============================================
-- STYLE BUTTON HANDLERS
-- ============================================
local function handleStyleSelection(styleName)
	if currentState ~= "selecting_style" or not selectedTarget then return end
	if not CarryConfig.isValidStyle(styleName) then return end

	UIAnimator.Close(mainFrame)

	RequestRemote:FireServer({
		cmd      = "RequestCarry",
		targetId = selectedTarget.UserId,
		style    = styleName
	})

	currentState = "waiting"
end

if bridalBtn then bridalBtn.MouseButton1Click:Connect(function() handleStyleSelection("bridal") end) end
if coupleHugBtn then coupleHugBtn.MouseButton1Click:Connect(function() handleStyleSelection("couplehug") end) end
if pasakalBtn then pasakalBtn.MouseButton1Click:Connect(function() handleStyleSelection("pasakal") end) end
if piggyBackBtn then piggyBackBtn.MouseButton1Click:Connect(function() handleStyleSelection("piggyback") end) end
if piggyUpperBackBtn then piggyUpperBackBtn.MouseButton1Click:Connect(function() handleStyleSelection("piggyupperback") end) end

-- ============================================
-- NOTIFICATION BUTTON HANDLERS
-- ============================================
acceptBtn.MouseButton1Click:Connect(function()
	if currentState ~= "pending_response" or not pendingCarrier then return end

	UIAnimator.Close(notificationFrame)
	ResponseRemote:FireServer({ cmd = "AcceptCarry" })
	currentState = "waiting"
end)

rejectBtn.MouseButton1Click:Connect(function()
	if currentState ~= "pending_response" or not pendingCarrier then return end

	UIAnimator.Close(notificationFrame, function()
		cleanupState()
		currentState = "idle"
	end)
	ResponseRemote:FireServer({ cmd = "RejectCarry" })
end)

-- ============================================
-- GET DOWN BUTTON HANDLER
-- ============================================
getDownBtn.MouseButton1Click:Connect(function()
	if currentState ~= "being_carried" and currentState ~= "carrying" then return end

	hideGetDownButton()
	EndRemote:FireServer({})
	cleanupState()
	currentState = "idle"
end)

-- ============================================
-- REMOTE EVENT HANDLERS
-- ============================================
RequestRemote.OnClientEvent:Connect(function(data)
	if not data or type(data) ~= "table" then return end

	local cmd = data.cmd
	CarryConfig.debugPrint("UI", "Received:", cmd)

	if cmd == "CarryStarted" then
		currentState = "carrying"
		UIAnimator.Open(getDownBtn)
		playAnimation(data.style, "carrier")

	elseif cmd == "BeingCarried" then
		showGetDownButton()
		playAnimation(data.style, "carried")

	elseif cmd == "RequestExpired" or cmd == "RequestFailed" then
		UIAnimator.Close(mainFrame, function()
			cleanupState()
			currentState = "idle"
		end)

	elseif cmd == "RequestRejected" then
		cleanupState()
		currentState = "idle"
	end
end)

ResponseRemote.OnClientEvent:Connect(function(data)
	if not data or type(data) ~= "table" then return end

	local cmd = data.cmd
	CarryConfig.debugPrint("UI", "Received:", cmd)

	if cmd == "ShowRequest" then
		showCarryNotification(data.carrierId, data.carrierName, data.style)

	elseif cmd == "RequestExpired" or cmd == "CarryFailed" then
		UIAnimator.Close(notificationFrame, function()
			cleanupState()
			currentState = "idle"
		end)
	end
end)

EndRemote.OnClientEvent:Connect(function(data)
	if not data or type(data) ~= "table" then return end

	if data.cmd == "CarryEnded" then
		hideGetDownButton()
		hideAllFrames()
		cleanupState()
		currentState = "idle"
	end
end)

-- ============================================
-- CONTEXT MENU INTEGRATION
-- ============================================
local carryEventConnection = nil

local function setupCarryEventListener()
	local eventsFolder = ReplicatedStorage:FindFirstChild("CarryEvents")
	if not eventsFolder then
		eventsFolder = Instance.new("Folder")
		eventsFolder.Name = "CarryEvents"
		eventsFolder.Parent = ReplicatedStorage
	end

	local showUIEvent = eventsFolder:FindFirstChild("ShowStyleUI")
	if not showUIEvent then
		showUIEvent = Instance.new("BindableEvent")
		showUIEvent.Name = "ShowStyleUI"
		showUIEvent.Parent = eventsFolder
	end

	return showUIEvent.Event:Connect(function(target)
		if not target or not target:IsA("Player") then return end
		if not player.Character or not target.Character then return end

		local myHRP     = player.Character:FindFirstChild("HumanoidRootPart")
		local targetHRP = target.Character:FindFirstChild("HumanoidRootPart")

		if not myHRP or not targetHRP then return end
		if (myHRP.Position - targetHRP.Position).Magnitude > CarryConfig.MAX_DISTANCE then return end

		if currentState == "idle" or currentState == "selecting_style" then
			showStyleSelection(target)
		elseif currentState == "waiting" then
			cleanupState()
			currentState = "idle"
			task.wait(0.1)
			showStyleSelection(target)
		end
	end)
end

carryEventConnection = setupCarryEventListener()

-- ============================================
-- RESPAWN HANDLING
-- ============================================
player.CharacterAdded:Connect(function()
	hideAllFrames()
	cleanupState()
	currentState = "idle"

	if loadedAnimationsCache then
		for _, track in pairs(loadedAnimationsCache) do
			pcall(function() track:Destroy() end)
		end
	end

	loadedAnimationsCache = {}
	currentAnimTracks = {}

	if carryEventConnection then
		carryEventConnection:Disconnect()
	end

	task.wait(1)
	carryEventConnection = setupCarryEventListener()
end)

-- ============================================
-- CLEANUP ON LEAVE
-- ============================================
Players.PlayerRemoving:Connect(function(leavingPlayer)
	if leavingPlayer == player then
		if carryEventConnection then carryEventConnection:Disconnect() end
		if jumpBlockConn then jumpBlockConn:Disconnect() end
		stopAllAnimations()
		cleanupState()
	else
		if leavingPlayer == selectedTarget or leavingPlayer.UserId == pendingCarrier then
			hideAllFrames()
			cleanupState()
			currentState = "idle"

			pcall(function()
				game.StarterGui:SetCore("SendNotification", {
					Title = "Carry Cancelled",
					Text  = (leavingPlayer.Name .. " has left the game."),
					Duration = 3,
				})
			end)
		end
	end
end)

-- ============================================
-- INITIALIZATION
-- ============================================
hideAllFrames()
CarryConfig.debugPrint("UI", "Carry UI Initialized")
