-- SERVICES
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local GuiService = game:GetService("GuiService")
local SoundService = game:GetService("SoundService") 

ReplicatedFirst:RemoveDefaultLoadingScreen()

local CONFIG = {
	AnimationId = "rbxassetid://114486154887764", 
	Tips = {
		"Malam ini kita party habis-habisan 💃🕺",
		"Ikutin vibe, nikmatin beat!",
		"Selamat datang di NIGHTBEAT PARTY!",
		"Gas terus, jangan berhenti!",
		"Vibes lagi naik, jangan kendor!",
		"Musik nyala, kita jalan!",
		"Enjoy the night, no stress!",
		"Party mode: ON 🎧🔥"
	},
	CoverDuration = 2, 
	FakeLoadingTime = 120,
	SkipAppearTime = 15, 
}

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local playerGui = player:WaitForChild("PlayerGui")
local originalVolumes = {} 
local isLoading = true 

local coverGuiPrefab = script:WaitForChild("CoverScreen", 10) 
if not coverGuiPrefab then warn("ERROR: Tidak menemukan 'CoverScreen'!"); return end

local coverGui = coverGuiPrefab:Clone()
coverGui.Parent = playerGui
coverGui.Enabled = true 

if coverGui:IsA("ScreenGui") then coverGui.ScreenInsets = Enum.ScreenInsets.None end
local coverFrame = coverGui:WaitForChild("Image")

local screenGuiPrefab = script:WaitForChild("CinematicLoading", 10)
if not screenGuiPrefab then warn("ERROR: Tidak menemukan 'CinematicLoading'!"); return end

local screenGui = screenGuiPrefab:Clone()
screenGui.Enabled = false 
screenGui.Parent = playerGui

if screenGui:IsA("ScreenGui") then screenGui.ScreenInsets = Enum.ScreenInsets.None end

local topCinematicBar = Instance.new("Frame")
topCinematicBar.Name = "TopCinematicBar"
topCinematicBar.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
topCinematicBar.BorderSizePixel = 0
topCinematicBar.Size = UDim2.new(1, 0, 0.15, 0)
topCinematicBar.Position = UDim2.new(0, 0, 0, 0) 
topCinematicBar.ZIndex = 0 
topCinematicBar.Parent = screenGui

local bottomCinematicBar = Instance.new("Frame")
bottomCinematicBar.Name = "BottomCinematicBar"
bottomCinematicBar.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
bottomCinematicBar.BorderSizePixel = 0
bottomCinematicBar.Size = UDim2.new(1, 0, 0.15, 0) 
bottomCinematicBar.Position = UDim2.new(0, 0, 0.85, 0) 
bottomCinematicBar.ZIndex = 0
bottomCinematicBar.Parent = screenGui

local blackFrame = screenGui:WaitForChild("BlackFrame")
local logoImg = blackFrame:WaitForChild("Logo")

local gradientFrame = screenGui:WaitForChild("GradientFrame")
local container = gradientFrame:WaitForChild("Container")
local barBg = container:WaitForChild("BarBg")
local barFill = barBg:WaitForChild("BarFill")
local pctText = container:WaitForChild("PctText")
local tipsText = container:WaitForChild("TipsText")
local skipBtn = container:WaitForChild("SkipBtn")

barFill.Size = UDim2.new(0, 0, 1, 0)
pctText.Text = "Loading..."
skipBtn.Visible = false
blackFrame.BackgroundTransparency = 0
logoImg.ImageTransparency = 0
gradientFrame.Visible = false 
barBg.BackgroundTransparency = 0
barFill.BackgroundTransparency = 0

local isSkipped = false

-- FUNGSI MUTE AUDIO (OPTIMASI: Gunakan SoundService & single scan, hindari spam GetDescendants)
local origSoundServiceVolume = nil

local function muteAudio(mute)
	if mute then
		origSoundServiceVolume = SoundService.Volume
		SoundService.Volume = 0
		task.spawn(function()
			for _, sound in ipairs(workspace:GetDescendants()) do
				if sound:IsA("Sound") and sound.Playing and sound.Volume > 0 then
					if not originalVolumes[sound] then
						originalVolumes[sound] = sound.Volume
					end
					sound.Volume = 0
				end
			end
		end)
	else
		if origSoundServiceVolume ~= nil then
			SoundService.Volume = origSoundServiceVolume
		end
		for sound, vol in pairs(originalVolumes) do
			if sound and sound.Parent then
				sound.Volume = vol
			end
		end
		originalVolumes = {}
	end
end

-- FUNGSI FORCE HIDE UI (OPTIMASI: Event-driven, hindari RenderStep loop & spam SetCoreGui)
local function startUiEnforcer()
	task.spawn(function()
		local attempts = 0
		while isLoading and attempts < 10 do
			attempts += 1
			local ok = pcall(function()
				StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, false)
				StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
				StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
				StarterGui:SetCore("TopbarEnabled", false)
			end)
			if ok then break end
			task.wait(0.2)
		end
	end)

	for _, gui in ipairs(playerGui:GetChildren()) do
		if gui:IsA("ScreenGui") and gui.Name ~= "CinematicLoading" and gui.Name ~= "CoverScreen" then
			gui.Enabled = false
		end
	end

	local childConn
	childConn = playerGui.ChildAdded:Connect(function(child)
		if not isLoading then
			if childConn then childConn:Disconnect() end
			return
		end
		if child:IsA("ScreenGui") and child.Name ~= "CinematicLoading" and child.Name ~= "CoverScreen" then
			child.Enabled = false
		end
	end)
end

local function setupCharacter()
	local char = player.Character or player.CharacterAdded:Wait()
	local hrp = char:WaitForChild("HumanoidRootPart")
	local humanoid = char:WaitForChild("Humanoid")
	if humanoid then humanoid:UnequipTools() end

	local charSpot = workspace:WaitForChild("LoadingCharSpot", 10)
	local camSpot = workspace:WaitForChild("LoadingCamSpot", 10)

	if charSpot and camSpot then
		player:RequestStreamAroundAsync(charSpot.Position)
		char:SetPrimaryPartCFrame(charSpot.CFrame)
		hrp.Anchored = true 

		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = camSpot.CFrame

		local animator = humanoid:WaitForChild("Animator")
		local animObj = Instance.new("Animation")
		animObj.AnimationId = CONFIG.AnimationId
		local track = animator:LoadAnimation(animObj)
		track.Priority = Enum.AnimationPriority.Action
		track.Looped = true
		track:Play()

		return track, char
	else
		warn("Loading Spots (LoadingCharSpot/LoadingCamSpot) not found in Workspace!")
		return nil, char
	end
end

local function transitionToGame(character)
	if not character then return end
	local hrp = character:WaitForChild("HumanoidRootPart")

	local cpValue = player:WaitForChild("Checkpoint", 5) 
	if not cpValue then 
		local ls = player:FindFirstChild("leaderstats")
		if ls then cpValue = ls:FindFirstChild("Checkpoint") end
	end

	local targetCFrame = nil
	if cpValue then
		local cpFolder = workspace:FindFirstChild("Checkpoints")
		if cpFolder then
			for _, part in ipairs(cpFolder:GetChildren()) do
				local orderVal = part:FindFirstChild("Order")
				if orderVal and orderVal.Value == cpValue.Value then
					targetCFrame = part.CFrame + Vector3.new(0, 5, 0)
					break
				end
			end
		end
	end

	if not targetCFrame then
		local spawnLoc = workspace:FindFirstChild("SpawnLocation")
		if spawnLoc then
			targetCFrame = spawnLoc.CFrame + Vector3.new(0, 5, 0)
		else
			targetCFrame = CFrame.new(0, 50, 0)
		end
	end

	player:RequestStreamAroundAsync(targetCFrame.Position)

	local currentCamPos = camera.CFrame.Position
	local lookUpRotation = CFrame.Angles(math.rad(80), 0, 0)
	local skyViewCFrame = CFrame.new(currentCamPos) * lookUpRotation

	local tweenUp = TweenService:Create(camera, 
		TweenInfo.new(1.2, Enum.EasingStyle.Quart, Enum.EasingDirection.InOut), 
		{CFrame = skyViewCFrame}
	)
	tweenUp:Play()
	tweenUp.Completed:Wait()

	character:PivotTo(targetCFrame)
	hrp.Anchored = false 

	local camOffset = CFrame.new(0, 2, 10)
	local finalCamPos = targetCFrame:ToWorldSpace(camOffset).Position
	camera.CFrame = CFrame.new(finalCamPos) * lookUpRotation

	task.wait(0.3)

	local finalViewCFrame = CFrame.new(finalCamPos, targetCFrame.Position)
	local tweenDown = TweenService:Create(camera, 
		TweenInfo.new(1.8, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), 
		{CFrame = finalViewCFrame}
	)
	tweenDown:Play()
	tweenDown.Completed:Wait()

	camera.CameraType = Enum.CameraType.Custom
end

task.spawn(function()
	startUiEnforcer() 
	muteAudio(true)   
	GuiService:SetGameplayPausedNotificationEnabled(false)

	task.wait(CONFIG.CoverDuration)

	screenGui.Enabled = true
	local animTrack, character = setupCharacter()

	local fadeCover = TweenService:Create(coverFrame, TweenInfo.new(0.5), {ImageTransparency = 1, BackgroundTransparency = 1})
	fadeCover:Play()
	fadeCover.Completed:Wait()
	coverGui:Destroy()

	gradientFrame.Visible = true
	local tweenInfo = TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
	TweenService:Create(blackFrame, tweenInfo, {BackgroundTransparency = 1}):Play()
	TweenService:Create(logoImg, tweenInfo, {ImageTransparency = 1}):Play()
	task.wait(0.5)
	blackFrame.Visible = false

	local elapsed = 0
	local lastTipUpdate = 0
	local totalFakeTime = CONFIG.FakeLoadingTime

	tipsText.Text = CONFIG.Tips[math.random(1, #CONFIG.Tips)]

	while elapsed < totalFakeTime do
		if isSkipped then break end

		local dt = task.wait(0.05)
		elapsed = elapsed + dt

		local percent = math.clamp(elapsed / totalFakeTime, 0, 1)

		barFill.Size = UDim2.new(percent, 0, 1, 0)
		pctText.Text = "Loading... " .. math.floor(percent * 100) .. "%"

		if elapsed - lastTipUpdate > 2 then
			tipsText.Text = CONFIG.Tips[math.random(1, #CONFIG.Tips)]
			lastTipUpdate = elapsed
		end

		if elapsed >= CONFIG.SkipAppearTime and not skipBtn.Visible then
			skipBtn.Visible = true
		end
	end

	if not isSkipped then
		barFill.Size = UDim2.new(1, 0, 1, 0)
		pctText.Text = "Loading Complete!"
		task.wait(0.5)
	end

	local fadeOut = TweenService:Create(gradientFrame, TweenInfo.new(0.8), {BackgroundTransparency = 1})
	fadeOut:Play()

	local cinematicTweenInfo = TweenInfo.new(1.5, Enum.EasingStyle.Quart, Enum.EasingDirection.InOut)
	TweenService:Create(topCinematicBar, cinematicTweenInfo, {Position = UDim2.new(0, 0, -0.15, 0)}):Play()
	TweenService:Create(bottomCinematicBar, cinematicTweenInfo, {Position = UDim2.new(0, 0, 1, 0)}):Play()

	TweenService:Create(barFill, TweenInfo.new(0.5), {BackgroundTransparency = 1}):Play()
	TweenService:Create(barBg, TweenInfo.new(0.5), {BackgroundTransparency = 1}):Play()

	for _, child in pairs(container:GetChildren()) do
		local tweenProps = {BackgroundTransparency = 1}
		if child:IsA("TextLabel") or child:IsA("TextButton") then
			tweenProps.TextTransparency = 1
			local stroke = child:FindFirstChildOfClass("UIStroke")
			if stroke then TweenService:Create(stroke, TweenInfo.new(0.5), {Transparency = 1}):Play() end
		end
		TweenService:Create(child, TweenInfo.new(0.5), tweenProps):Play()
	end

	if animTrack then animTrack:Stop() end
	transitionToGame(character)

	isLoading = false 
	muteAudio(false)
	GuiService:SetGameplayPausedNotificationEnabled(true)

	pcall(function() 
		StarterGui:SetCore("TopbarEnabled", true)
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, true)
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, true)
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, true)
	end)

	for _, gui in ipairs(playerGui:GetChildren()) do
		if gui:IsA("ScreenGui") and gui.Name ~= "CinematicLoading" then
			gui.Enabled = true
		end
	end

	screenGui:Destroy()
	coverGui:Destroy() 
end)

skipBtn.MouseButton1Click:Connect(function()
	if not isSkipped then
		isSkipped = true
		skipBtn.Text = "LAUNCHING..."
		TweenService:Create(skipBtn, TweenInfo.new(0.2), {BackgroundTransparency = 0.5}):Play()
	end
end)
