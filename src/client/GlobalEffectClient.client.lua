--!native
--!optimize 2
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local StarterGui = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local CameraLease = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("CameraLease"))

local Config = {
	CameraDistance = 20,
	CameraSpeed = 0.5,
}

local GlobalEffectRemotes = ReplicatedStorage:WaitForChild("GlobalEffectRemotes", 15)
if not GlobalEffectRemotes then
	warn("[GlobalEffectClient] GlobalEffectRemotes folder not found!")
	return
end

local ToggleEffectEvent = GlobalEffectRemotes:WaitForChild("ToggleEffect", 10)
local CameraEffectEvent = GlobalEffectRemotes:WaitForChild("CameraEffect", 10)
local CheckOwnerFunction = GlobalEffectRemotes:WaitForChild("CheckOwner", 10)
local NotificationEvent = GlobalEffectRemotes:WaitForChild("NotificationEvent", 10)
if not (ToggleEffectEvent and CameraEffectEvent and CheckOwnerFunction and NotificationEvent) then
	warn("[GlobalEffectClient] One or more GlobalEffectRemotes were not found!")
	return
end

NotificationEvent.OnClientEvent:Connect(function(title, text, duration)
	StarterGui:SetCore("SendNotification", {
		Title = title,
		Text = text,
		Duration = duration or 5,
	})
end)

local GlobalEffectGui = PlayerGui:WaitForChild("GlobalEffectGui", 10)

if GlobalEffectGui then
	local isOwner = CheckOwnerFunction:InvokeServer()
	local MainFrame = GlobalEffectGui:WaitForChild("MainFrame")
	local NotifikasiFrame = GlobalEffectGui:WaitForChild("NotifikasiFrame")

	local ToggleNotificationEvent = GlobalEffectRemotes:WaitForChild("ToggleNotification")
	local ToggleFollowEvent = GlobalEffectRemotes:WaitForChild("ToggleFollow")

	local isFollowing = true
	local FollowBtn = NotifikasiFrame:WaitForChild("FollowBtn")
	local FollowBtnText = FollowBtn:WaitForChild("TextLabel")

	NotifikasiFrame.Visible = false

	local lastFollowClick = 0
	FollowBtn.MouseButton1Click:Connect(function()
		local now = os.clock()
		if now - lastFollowClick < 0.3 then return end
		lastFollowClick = now

		isFollowing = not isFollowing
		FollowBtnText.Text = isFollowing and "Unfollow" or "Follow"
		ToggleFollowEvent:FireServer(isFollowing)
	end)

	ToggleNotificationEvent.OnClientEvent:Connect(function(show)
		if show then
			isFollowing = true
			FollowBtnText.Text = "Unfollow"
			NotifikasiFrame.Visible = true
		else
			NotifikasiFrame.Visible = false
		end
	end)

	if not isOwner then
		MainFrame:Destroy()
	else
		local BtnFrame = MainFrame:WaitForChild("BtnFrame")
		local Btn360 = BtnFrame:WaitForChild("360Btn")
		local BtnFloating = BtnFrame:WaitForChild("FloatingBtn")
		local BtnFly = BtnFrame:WaitForChild("FlyBtn")
		local BtnWing = BtnFrame:WaitForChild("WingBtn")
		local BtnClear = MainFrame:WaitForChild("ClearBtn")

		local COLOR_ACTIVE = Color3.fromRGB(0, 255, 0)
		local COLOR_DEFAULT = Color3.fromRGB(255, 255, 255)

		local btnMap = {
			Camera360 = Btn360,
			Floating = BtnFloating,
			Fly = BtnFly,
			Wing = BtnWing,
		}

		local ButtonStates = {
			Camera360 = false,
			Floating = false,
			Fly = false,
			Wing = false,
		}

		MainFrame.Visible = false

		local function updateButtonUI(btnName, isActive)
			local btnObj = btnMap[btnName]
			if btnObj then
				local imageLabel = btnObj:FindFirstChild("ImageLabel")
				if imageLabel then
					imageLabel.ImageColor3 = isActive and COLOR_ACTIVE or COLOR_DEFAULT
				end
			end
		end

		local lastClickTime = 0
		local CLICK_DEBOUNCE = 0.5

		local function setupButton(btnObj, stateName)
			btnObj.MouseButton1Click:Connect(function()
				if os.clock() - lastClickTime < CLICK_DEBOUNCE then return end
				lastClickTime = os.clock()

				ButtonStates[stateName] = not ButtonStates[stateName]
				updateButtonUI(stateName, ButtonStates[stateName])

				local opposite = (stateName == "Fly" and "Floating") or (stateName == "Floating" and "Fly") or nil
				if opposite and ButtonStates[stateName] and ButtonStates[opposite] then
					ButtonStates[opposite] = false
					updateButtonUI(opposite, false)
				end

				ToggleEffectEvent:FireServer(stateName, ButtonStates[stateName])
			end)
		end

		for name, btn in pairs(btnMap) do
			setupButton(btn, name)
		end

		local lastClearClick = 0
		BtnClear.MouseButton1Click:Connect(function()
			local now = os.clock()
			if now - lastClearClick < 0.3 then return end
			lastClearClick = now

			for stateName in pairs(ButtonStates) do
				ButtonStates[stateName] = false
				updateButtonUI(stateName, false)
			end
			ToggleEffectEvent:FireServer("ClearAll", true)
		end)
	end
end

local isTransitioning = false
local pendingCameraCallback = nil

local function playCinematicTransition(callback)
	pendingCameraCallback = callback
	if isTransitioning then return end
	isTransitioning = true

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "CinematicTransitionGui"
	screenGui.IgnoreGuiInset = true
	screenGui.ScreenInsets = Enum.ScreenInsets.None
	screenGui.DisplayOrder = 9999
	screenGui.Parent = PlayerGui

	local function makeFrame(startPos)
		local frame = Instance.new("Frame")
		frame.Size = UDim2.new(1, 0, 0.5, 0)
		frame.Position = startPos
		frame.BackgroundColor3 = Color3.new(0, 0, 0)
		frame.BorderSizePixel = 0
		frame.Parent = screenGui
		return frame
	end

	local topFrame = makeFrame(UDim2.new(0, 0, -0.5, 0))
	local bottomFrame = makeFrame(UDim2.new(0, 0, 1, 0))
	local tweenInfo = TweenInfo.new(0.6, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)

	local topTweenIn = TweenService:Create(topFrame, tweenInfo, { Position = UDim2.new(0, 0, 0, 0) })
	local bottomTweenIn = TweenService:Create(bottomFrame, tweenInfo, { Position = UDim2.new(0, 0, 0.5, 0) })

	topTweenIn:Play()
	bottomTweenIn:Play()
	topTweenIn.Completed:Wait()

	if pendingCameraCallback then
		local cb = pendingCameraCallback
		pendingCameraCallback = nil
		cb()
	end
	task.wait(0.2)

	local topTweenOut = TweenService:Create(topFrame, tweenInfo, { Position = UDim2.new(0, 0, -0.5, 0) })
	local bottomTweenOut = TweenService:Create(bottomFrame, tweenInfo, { Position = UDim2.new(0, 0, 1, 0) })

	topTweenOut:Play()
	bottomTweenOut:Play()
	topTweenOut.Completed:Wait()
	screenGui:Destroy()

	if pendingCameraCallback then
		local cb = pendingCameraCallback
		pendingCameraCallback = nil
		cb()
	end

	isTransitioning = false
end

local Camera = Workspace.CurrentCamera
local CameraConnection = nil
local CameraAngle = 0
local originalCameraType = nil
local originalCameraMode = nil
local originalCameraSubject = nil
local originalFOV = nil
local leaseToken = nil

local function start360Camera()
	if CameraConnection then return end
	local cam = Workspace.CurrentCamera
	if not cam then return end
	leaseToken = CameraLease:Acquire("GlobalEffect", 60)
	if not leaseToken then return end
	Camera = cam
	originalCameraType = cam.CameraType
	originalCameraMode = LocalPlayer.CameraMode
	originalCameraSubject = cam.CameraSubject
	originalFOV = cam.FieldOfView
	Camera.CameraType = Enum.CameraType.Scriptable

	CameraConnection = RunService.RenderStepped:Connect(function(dt)
		if not CameraLease:IsOwner("GlobalEffect", leaseToken) then
			stop360Camera()
			return
		end
		local character = LocalPlayer.Character
		local head = character and character:FindFirstChild("Head")
		if not head then return end

		CameraAngle += (Config.CameraSpeed * dt)
		local offsetX = math.sin(CameraAngle) * Config.CameraDistance
		local offsetZ = math.cos(CameraAngle) * Config.CameraDistance
		local targetPos = head.Position + Vector3.new(offsetX, 2, offsetZ)
		Camera.CFrame = CFrame.lookAt(targetPos, head.Position)
	end)
end

local function stop360Camera()
	if not CameraConnection then return end
	local owned = CameraLease:IsOwner("GlobalEffect", leaseToken)
	CameraConnection:Disconnect()
	CameraConnection = nil
	CameraLease:Release("GlobalEffect", leaseToken)
	leaseToken = nil

	if not owned then return end

	local cam = Workspace.CurrentCamera
	if cam then
		cam.FieldOfView = originalFOV or 70
		LocalPlayer.CameraMode = originalCameraMode or Enum.CameraMode.Classic
		if originalCameraSubject then
			cam.CameraSubject = originalCameraSubject
		else
			local char = LocalPlayer.Character
			local humanoid = char and char:FindFirstChildOfClass("Humanoid")
			if humanoid then cam.CameraSubject = humanoid end
		end
		cam.CameraType = originalCameraType or Enum.CameraType.Custom
	end
end

CameraEffectEvent.OnClientEvent:Connect(function(isActive)
	playCinematicTransition(function()
		if isActive then
			start360Camera()
		else
			stop360Camera()
		end
	end)
end)

local FLY_ANIM_ID = "81229486815853"
local FLOAT_ANIM_ID = "112082806790047"

local suspendedTimePosition = 0
local suspendedDanceID = nil
local resumedDanceTrack = nil
local EmoteNumericIds = nil

local function getNumericId(id)
	if not id then return "" end
	return string.match(tostring(id), "%d+") or ""
end

local function buildEmoteCache()
	local folder = ReplicatedStorage:FindFirstChild("Emotes")
	if not folder then return end

	EmoteNumericIds = {}
	for _, anim in ipairs(folder:GetDescendants()) do
		if anim:IsA("Animation") then
			local numId = getNumericId(anim.AnimationId)
			if numId ~= "" then
				EmoteNumericIds[numId] = true
			end
		end
	end
end

local function isRegisteredDanceOrPose(animationId)
	if not EmoteNumericIds then buildEmoteCache() end
	if not EmoteNumericIds then return false end
	return EmoteNumericIds[getNumericId(animationId)] == true
end

local function stopAllExceptGlobalEffects()
	local char = LocalPlayer.Character
	local humanoid = char and char:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator then return end

	for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
		if track.Animation then
			local numId = getNumericId(track.Animation.AnimationId)
			if numId ~= "" and numId ~= FLY_ANIM_ID and numId ~= FLOAT_ANIM_ID and isRegisteredDanceOrPose(track.Animation.AnimationId) then
				local currentDanceID = char:GetAttribute("CurrentDanceID")
				local syncTarget = char:GetAttribute("Syncing")
				if syncTarget and syncTarget ~= "" then
					local leader = Players:FindFirstChild(syncTarget)
					if leader and leader.Character then
						currentDanceID = leader.Character:GetAttribute("CurrentDanceID")
					end
				end

				if currentDanceID and getNumericId(currentDanceID) == numId then
					suspendedTimePosition = track.TimePosition
					suspendedDanceID = currentDanceID
				end
				track:Stop(0.1)
			end
		end
	end
end

local function findEmoteAnimationInstance(currentDanceID)
	local folder = ReplicatedStorage:FindFirstChild("Emotes")
	if not folder then return nil end

	local targetNumeric = getNumericId(currentDanceID)
	if targetNumeric == "" then return nil end

	for _, anim in ipairs(folder:GetDescendants()) do
		if anim:IsA("Animation") and getNumericId(anim.AnimationId) == targetNumeric then
			return anim
		end
	end
	return nil
end

local function resumeLocalDance()
	local char = LocalPlayer.Character
	if not char then return end

	local currentDanceID = char:GetAttribute("CurrentDanceID")
	local speed = char:GetAttribute("DanceSpeed") or 1

	local syncTarget = char:GetAttribute("Syncing")
	if syncTarget and syncTarget ~= "" then
		-- Follower disinkronkan oleh DanceMirror renderer di EmoteHandler.
		-- Jangan membuat track kedua di sini.
		if resumedDanceTrack then
			resumedDanceTrack:Stop(0.1)
			resumedDanceTrack:Destroy()
			resumedDanceTrack = nil
		end
		suspendedTimePosition = 0
		suspendedDanceID = nil
		return
	end

	if not currentDanceID or currentDanceID == "" then return end

	local humanoid = char:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator then return end

	local anim = findEmoteAnimationInstance(currentDanceID)
	local isTempAnim = false
	if not anim then
		anim = Instance.new("Animation")
		anim.AnimationId = currentDanceID
		isTempAnim = true
	end

	if resumedDanceTrack then
		resumedDanceTrack:Stop(0.1)
		resumedDanceTrack:Destroy()
		resumedDanceTrack = nil
	end

	stopAllExceptGlobalEffects()

	local track = animator:LoadAnimation(anim)
	if isTempAnim then anim:Destroy() end
	track.Priority = Enum.AnimationPriority.Action4
	track.Looped = true
	track:Play(0.2, 1, speed)
	resumedDanceTrack = track

	if suspendedTimePosition > 0 and suspendedDanceID == currentDanceID then
		pcall(function() track.TimePosition = suspendedTimePosition end)
	end
	suspendedTimePosition = 0
	suspendedDanceID = nil
end

local function onGlobalEffectActiveChanged()
	local char = LocalPlayer.Character
	if not char then return end
	if char:GetAttribute("GlobalEffectActive") == true then
		stopAllExceptGlobalEffects()
	else
		resumeLocalDance()
	end
end

local function onAnimationPlayed(track)
	local char = LocalPlayer.Character
	if not char or char:GetAttribute("GlobalEffectActive") ~= true then return end

	local numId = getNumericId(track.Animation and track.Animation.AnimationId)
	if numId ~= "" and numId ~= FLY_ANIM_ID and numId ~= FLOAT_ANIM_ID and isRegisteredDanceOrPose(track.Animation.AnimationId) then
		track:Stop(0)
	end
end

local function setupCharacterListener(char)
	suspendedTimePosition = 0
	suspendedDanceID = nil
	resumedDanceTrack = nil

	local humanoid = char:WaitForChild("Humanoid", 10)
	local animator = humanoid and humanoid:WaitForChild("Animator", 10)
	if animator then
		animator.AnimationPlayed:Connect(onAnimationPlayed)
	end

	char:GetAttributeChangedSignal("GlobalEffectActive"):Connect(onGlobalEffectActiveChanged)
	char:GetAttributeChangedSignal("CurrentDanceID"):Connect(function()
		if resumedDanceTrack then
			resumedDanceTrack:Stop(0.1)
			resumedDanceTrack = nil
		end
	end)

	onGlobalEffectActiveChanged()
end

if LocalPlayer.Character then
	task.spawn(setupCharacterListener, LocalPlayer.Character)
end
LocalPlayer.CharacterAdded:Connect(function(char)
	task.spawn(setupCharacterListener, char)
end)
