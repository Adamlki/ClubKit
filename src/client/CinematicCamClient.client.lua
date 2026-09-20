-- ============================================================
-- CinematicCamClient (ClubKit Cinematic Camera System)
-- ============================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera
local playerGui = player:WaitForChild("PlayerGui")

-- ============================================================
-- STATE
-- ============================================================
local currentMode = nil
local currentSpeedMultiplier = 0.5 -- default 0.5x matching design
local currentDirection = 1 -- 1 = RIGHT, -1 = LEFT
local isRunning = false
local startTime = 0
local initialFOV = 70
local isFirstFrame = true

-- Preset button references for active state highlighting
local presetButtons = {}
local speedButtons = {}
local dirButtons = {}

-- Colors & Styles (Serasi dengan tema ClubKit)
local COLOR_CARD = Color3.fromRGB(24, 26, 31)
local COLOR_CARD_HOVER = Color3.fromRGB(32, 35, 42)
local COLOR_CARD_ACTIVE = Color3.fromRGB(16, 52, 98)
local COLOR_STROKE = Color3.fromRGB(42, 45, 54)
local COLOR_ACCENT = Color3.fromRGB(0, 132, 255)
local COLOR_STOP = Color3.fromRGB(185, 45, 45)
local COLOR_STOP_HOVER = Color3.fromRGB(210, 55, 55)
local COLOR_TEXT = Color3.fromRGB(220, 225, 235)
local COLOR_TEXT_MUTED = Color3.fromRGB(160, 165, 175)

-- ============================================================
-- REFERENCES TO MANUAL STARTERGUI INSTANCE
-- ============================================================
local screenGui = playerGui:WaitForChild("CinematicCamGui")
local mainframe = screenGui:WaitForChild("MainFrame")
local header = mainframe:WaitForChild("Header")
local closeBtn = header:WaitForChild("CloseBtn")
local content = mainframe:WaitForChild("Content")
local speedRow = content:WaitForChild("SpeedRow")
local dirRow = content:WaitForChild("DirRow")
local stopBtn = content:WaitForChild("StopBtn")

local INITIAL_POSITION = UDim2.new(1, -245, 0.5, 0)
mainframe.Position = INITIAL_POSITION

mainframe:GetPropertyChangedSignal("Visible"):Connect(function()
	if mainframe.Visible then
		mainframe.Position = INITIAL_POSITION
	end
end)

local isMouseOverCloseBtn = false
closeBtn.MouseEnter:Connect(function()
	isMouseOverCloseBtn = true
	closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
end)
closeBtn.MouseLeave:Connect(function()
	isMouseOverCloseBtn = false
	closeBtn.TextColor3 = COLOR_TEXT_MUTED
end)
closeBtn.MouseButton1Click:Connect(function()
	mainframe.Visible = false
end)

-- ============================================================
-- HEADER DRAG LOGIC
-- ============================================================
local isDraggingHeader = false
local dragStartMouse = nil
local dragStartFramePos = nil

header.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		if isMouseOverCloseBtn then
			return
		end
		isDraggingHeader = true
		dragStartMouse = input.Position
		dragStartFramePos = mainframe.Position
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if isDraggingHeader and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
		local delta = input.Position - dragStartMouse
		local newX = dragStartFramePos.X.Offset + delta.X
		local newY = dragStartFramePos.Y.Offset + delta.Y
		mainframe.Position = UDim2.new(dragStartFramePos.X.Scale, newX, dragStartFramePos.Y.Scale, newY)
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if isDraggingHeader and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
		isDraggingHeader = false
	end
end)

-- ============================================================
-- SPEED BUTTONS BINDING (0.25x, 0.5x, 1.0x, 2.0x)
-- ============================================================
local speeds = {
	{ label = "0.25x", val = 0.25 },
	{ label = "0.5x",  val = 0.5 },
	{ label = "1.0x",  val = 1.0 },
	{ label = "2.0x",  val = 2.0 },
}

for _, sp in ipairs(speeds) do
	local btn = speedRow:WaitForChild("Speed_" .. sp.label)
	local stroke = btn:FindFirstChild("UIStroke")
	speedButtons[sp.val] = { btn = btn, stroke = stroke }

	btn.MouseButton1Click:Connect(function()
		currentSpeedMultiplier = sp.val
		for val, refs in pairs(speedButtons) do
			if val == sp.val then
				refs.btn.BackgroundColor3 = COLOR_ACCENT
				refs.btn.TextColor3 = Color3.fromRGB(255, 255, 255)
				if refs.stroke then refs.stroke.Color = COLOR_ACCENT end
			else
				refs.btn.BackgroundColor3 = COLOR_CARD
				refs.btn.TextColor3 = COLOR_TEXT_MUTED
				if refs.stroke then refs.stroke.Color = COLOR_STROKE end
			end
		end
	end)
end

-- ============================================================
-- DIRECTION BUTTONS BINDING (◄ LEFT, RIGHT ►)
-- ============================================================
local dirs = {
	{ label = "◄ LEFT", val = -1 },
	{ label = "RIGHT ►", val = 1 },
}

for _, d in ipairs(dirs) do
	local btn = dirRow:WaitForChild("Dir_" .. d.val)
	local stroke = btn:FindFirstChild("UIStroke")
	dirButtons[d.val] = { btn = btn, stroke = stroke }

	btn.MouseButton1Click:Connect(function()
		currentDirection = d.val
		for val, refs in pairs(dirButtons) do
			if val == d.val then
				refs.btn.BackgroundColor3 = COLOR_ACCENT
				refs.btn.TextColor3 = Color3.fromRGB(255, 255, 255)
				if refs.stroke then refs.stroke.Color = COLOR_ACCENT end
			else
				refs.btn.BackgroundColor3 = COLOR_CARD
				refs.btn.TextColor3 = COLOR_TEXT_MUTED
				if refs.stroke then refs.stroke.Color = COLOR_STROKE end
			end
		end
	end)
end

-- ============================================================
-- STOP SYSTEM BUTTON
-- ============================================================
stopBtn.MouseEnter:Connect(function()
	stopBtn.BackgroundColor3 = COLOR_STOP_HOVER
end)
stopBtn.MouseLeave:Connect(function()
	stopBtn.BackgroundColor3 = COLOR_STOP
end)

-- ============================================================
-- PRESETS BINDING
-- ============================================================
local PRESETS = {
	"ORBIT MASTER",
	"DRONE VIEW",
	"FLOOR LEVEL",
	"SIDE SLIDER",
	"HERO FLY-BY",
	"SPIRAL UP",
	"PORTRAIT FOCUS",
}

local function updatePresetVisuals(activePreset)
	for name, refs in pairs(presetButtons) do
		if name == activePreset then
			refs.btn.BackgroundColor3 = COLOR_CARD_ACTIVE
			refs.btn.TextColor3 = Color3.fromRGB(255, 255, 255)
			if refs.stroke then refs.stroke.Color = COLOR_ACCENT end
		else
			refs.btn.BackgroundColor3 = COLOR_CARD
			refs.btn.TextColor3 = COLOR_TEXT
			if refs.stroke then refs.stroke.Color = COLOR_STROKE end
		end
	end
end

-- ============================================================
-- CAMERA MATH & ENGINE
-- ============================================================
local function stopCinematicSystem()
	if not isRunning then return end
	isRunning = false
	currentMode = nil

	RunService:UnbindFromRenderStep("CinematicCameraMovement")

	local cam = Workspace.CurrentCamera
	if cam then
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")

		-- 1. Reset FOV to standard 70
		cam.FieldOfView = 70

		-- 2. Restore CameraSubject to Humanoid
		if hum then
			cam.CameraSubject = hum
		end

		-- 3. Reset Camera CFrame to standard third-person behind character
		if hrp then
			local headPos = hrp.Position + Vector3.new(0, 1.5, 0)
			local look = hrp.CFrame.LookVector
			local defaultCamPos = headPos - (look * 12) + Vector3.new(0, 2.5, 0)
			cam.CFrame = CFrame.new(defaultCamPos, headPos)
			cam.Focus = CFrame.new(headPos)
		end

		-- 4. Switch back to Custom camera type
		cam.CameraType = Enum.CameraType.Custom
	end

	updatePresetVisuals(nil)
end

stopBtn.MouseButton1Click:Connect(stopCinematicSystem)

local function getTargetData()
	local char = player.Character
	if not char then return nil end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	local head = char:FindFirstChild("Head")
	if not hrp then return nil end

	local center = hrp.Position + Vector3.new(0, 1.2, 0)
	return {
		char = char,
		hrp = hrp,
		head = head,
		center = center,
	}
end

local function computeCameraCFrame(mode, t, data)
	local hrp = data.hrp
	local head = data.head
	local center = data.center

	local speed = currentSpeedMultiplier
	-- Invert direction so RIGHT rotates camera to the right and LEFT rotates camera to the left from viewer perspective
	local dir = -currentDirection

	if mode == "ORBIT MASTER" then
		local angle = t * (0.65 * speed * dir)
		local radius = 12
		local height = 2.0 + math.sin(t * 0.4) * 0.4
		local camPos = center + Vector3.new(math.cos(angle) * radius, height, math.sin(angle) * radius)
		return CFrame.new(camPos, center + Vector3.new(0, 0.4, 0)), 70

	elseif mode == "DRONE VIEW" then
		local angle = t * (0.35 * speed * dir)
		local radius = 17
		local height = 18 + math.sin(t * 0.6) * 1.5
		local camPos = center + Vector3.new(math.cos(angle) * radius, height, math.sin(angle) * radius)
		return CFrame.new(camPos, center), 68

	elseif mode == "FLOOR LEVEL" then
		local angle = t * (0.55 * speed * dir)
		local radius = 8.5
		local camPos = center + Vector3.new(math.cos(angle) * radius, -2.2, math.sin(angle) * radius)
		return CFrame.new(camPos, center + Vector3.new(0, 1.4, 0)), 75

	elseif mode == "SIDE SLIDER" then
		local slide = math.sin(t * (0.7 * speed * dir)) * 7.5
		local forward = hrp.CFrame.LookVector * 10
		local right = hrp.CFrame.RightVector * slide
		local camPos = center + forward + right + Vector3.new(0, 0.4, 0)
		return CFrame.new(camPos, center + Vector3.new(0, 0.4, 0)), 70

	elseif mode == "HERO FLY-BY" then
		local cycle = (t * 0.25 * speed) % 1
		local fwdDist = (cycle - 0.5) * 26 * dir
		local side = math.sin(cycle * math.pi) * 8.5 * (-dir)
		local height = 1.0 + math.abs(cycle - 0.5) * 6
		local camPos = center + (hrp.CFrame.LookVector * fwdDist) + (hrp.CFrame.RightVector * side) + Vector3.new(0, height, 0)
		return CFrame.new(camPos, center + Vector3.new(0, 0.5, 0)), 72

	elseif mode == "SPIRAL UP" then
		local angle = t * (0.75 * speed * dir)
		local loop = (math.sin(t * 0.4 * speed) + 1) * 0.5
		local h = -1.8 + (loop * 11.5)
		local r = 11 - (loop * 3.5)
		local camPos = center + Vector3.new(math.cos(angle) * r, h, math.sin(angle) * r)
		return CFrame.new(camPos, center + Vector3.new(0, 0.3 + (h * 0.12), 0)), 70

	elseif mode == "PORTRAIT FOCUS" then
		local angle = t * (0.35 * speed * dir)
		local headPos = head and head.Position or (center + Vector3.new(0, 1.5, 0))
		local camPos = headPos + Vector3.new(math.cos(angle) * 5.2, 0.15 + math.sin(t * 0.5) * 0.2, math.sin(angle) * 5.2)
		return CFrame.new(camPos, headPos), 46
	end

	return camera.CFrame, 70
end

local function startCinematicMode(presetName)
	if currentMode == presetName and isRunning then return end

	currentMode = presetName
	isRunning = true
	startTime = os.clock()
	isFirstFrame = true
	initialFOV = camera.FieldOfView

	updatePresetVisuals(presetName)

	local cam = Workspace.CurrentCamera
	if cam then
		cam.CameraType = Enum.CameraType.Scriptable
	end

	RunService:UnbindFromRenderStep("CinematicCameraMovement")
	RunService:BindToRenderStep("CinematicCameraMovement", Enum.RenderPriority.Camera.Value + 1, function(dt)
		if not isRunning then return end

		local currentCam = Workspace.CurrentCamera
		if not currentCam then return end

		local data = getTargetData()
		if not data then
			stopCinematicSystem()
			return
		end

		local t = os.clock() - startTime
		local targetCFrame, targetFOV = computeCameraCFrame(currentMode, t, data)

		-- Smooth Anti-Clip Raycast
		local rayParams = RaycastParams.new()
		rayParams.FilterType = Enum.RaycastFilterType.Exclude
		rayParams.FilterDescendantsInstances = { data.char }
		local rayDist = (targetCFrame.Position - data.center).Magnitude
		local rayDir = (targetCFrame.Position - data.center).Unit * rayDist
		local rayResult = Workspace:Raycast(data.center, rayDir, rayParams)

		local safePos = targetCFrame.Position
		if rayResult then
			safePos = data.center + (targetCFrame.Position - data.center).Unit * math.max(2.5, (rayResult.Position - data.center).Magnitude - 0.6)
			targetCFrame = CFrame.new(safePos, targetCFrame.Position + targetCFrame.LookVector * 10)
		end

		if isFirstFrame then
			currentCam.CFrame = targetCFrame
			currentCam.FieldOfView = targetFOV
			isFirstFrame = false
		else
			currentCam.CFrame = currentCam.CFrame:Lerp(targetCFrame, math.clamp(dt * 9, 0, 1))
			currentCam.FieldOfView = currentCam.FieldOfView + (targetFOV - currentCam.FieldOfView) * math.clamp(dt * 6, 0, 1)
		end
	end)
end

-- Bind Preset Buttons
for _, presetName in ipairs(PRESETS) do
	local btn = content:WaitForChild("Preset_" .. presetName)
	local stroke = btn:FindFirstChild("UIStroke")
	presetButtons[presetName] = { btn = btn, stroke = stroke }

	btn.MouseEnter:Connect(function()
		if currentMode ~= presetName then
			btn.BackgroundColor3 = COLOR_CARD_HOVER
		end
	end)
	btn.MouseLeave:Connect(function()
		if currentMode ~= presetName then
			btn.BackgroundColor3 = COLOR_CARD
		end
	end)
	btn.MouseButton1Click:Connect(function()
		startCinematicMode(presetName)
	end)
end

-- Clean up on death
player.CharacterRemoving:Connect(function()
	stopCinematicSystem()
end)

return true
