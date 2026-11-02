local pi    = math.pi
local abs   = math.abs
local clamp = math.clamp
local exp   = math.exp
local rad   = math.rad
local sign  = math.sign
local sqrt  = math.sqrt
local tan   = math.tan

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
	Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
	LocalPlayer = Players.LocalPlayer
end

local CameraLease = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("CameraLease"))

local leaseToken = nil
local Camera = Workspace.CurrentCamera
Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	local newCamera = Workspace.CurrentCamera
	if newCamera then
		Camera = newCamera
	end
end)

local INPUT_PRIORITY = Enum.ContextActionPriority.High.Value

local NAV_GAIN = Vector3.new(1, 1, 1) * 64
local PAN_GAIN = Vector2.new(0.75, 1) * 8
local FOV_GAIN = 300
local PITCH_LIMIT = rad(90)

local VEL_STIFFNESS = 1.5
local PAN_STIFFNESS = 1.0
local FOV_STIFFNESS = 4.0

local Spring = {}
do
	Spring.__index = Spring

	function Spring.new(freq, pos)
		local self = setmetatable({}, Spring)
		self.f = freq
		self.p = pos
		self.v = pos * 0
		return self
	end

	function Spring:Update(dt, goal)
		local f = self.f * 2 * pi
		local p0 = self.p
		local v0 = self.v
		local offset = goal - p0
		local decay = exp(-f * dt)

		local p1 = goal + (v0 * dt - offset * (f * dt + 1)) * decay
		local v1 = (f * dt * (offset * f - v0) + v0) * decay

		self.p = p1
		self.v = v1
		return p1
	end

	function Spring:Reset(pos)
		self.p = pos
		self.v = pos * 0
	end
end

local cameraPos = Vector3.zero
local cameraRot = Vector2.zero
local cameraFov = 0

local velSpring = Spring.new(VEL_STIFFNESS, Vector3.zero)
local panSpring = Spring.new(PAN_STIFFNESS, Vector2.zero)
local fovSpring = Spring.new(FOV_STIFFNESS, 0)

local Input = {}
do
	local thumbstickCurve
	do
		local K_CURVATURE = 2.0
		local K_DEADZONE = 0.15

		local function fCurve(x)
			return (exp(K_CURVATURE * x) - 1) / (exp(K_CURVATURE) - 1)
		end

		local function fDeadzone(x)
			return fCurve((x - K_DEADZONE) / (1 - K_DEADZONE))
		end

		function thumbstickCurve(x)
			return sign(x) * clamp(fDeadzone(abs(x)), 0, 1)
		end
	end

	local gamepad = {
		ButtonX = 0,
		ButtonY = 0,
		DPadDown = 0,
		DPadUp = 0,
		ButtonL2 = 0,
		ButtonR2 = 0,
		Thumbstick1 = Vector2.zero,
		Thumbstick2 = Vector2.zero,
	}

	local keyboard = {
		W = 0, A = 0, S = 0, D = 0, E = 0, Q = 0,
		U = 0, H = 0, J = 0, K = 0, I = 0, Y = 0,
		Up = 0, Down = 0, LeftShift = 0, RightShift = 0,
	}

	local mouse = {
		Delta = Vector2.zero,
		MouseWheel = 0,
	}

	local MobileControls = script.Parent:WaitForChild("MobileControls")

	local function bindDir(btn, key)
		local function release() keyboard[key] = 0 end
		btn.MouseButton1Down:Connect(function() keyboard[key] = 1 end)
		btn.MouseLeave:Connect(release)
		btn.MouseButton1Up:Connect(release)
		btn.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
				release()
			end
		end)
	end

	bindDir(MobileControls.Movement.forward.TextButton, "W")
	bindDir(MobileControls.Movement.back.TextButton, "S")
	bindDir(MobileControls.Movement.right.TextButton, "D")
	bindDir(MobileControls.Movement.left.TextButton, "A")

	local function bindZoom(btn, delta)
		local isHeld = false
		local loopRunning = false

		local function stopZoom()
			isHeld = false
		end

		local function startZoom()
			if isHeld then return end
			isHeld = true
			if loopRunning then return end
			loopRunning = true

			task.spawn(function()
				while isHeld and btn.Visible and btn.Parent do
					mouse.MouseWheel += delta
					task.wait()
				end
				isHeld = false
				loopRunning = false
			end)
		end

		btn.MouseButton1Down:Connect(startZoom)
		btn.MouseButton1Up:Connect(stopZoom)
		btn.MouseLeave:Connect(stopZoom)
		btn.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
				stopZoom()
			end
		end)
	end

	bindZoom(MobileControls.zoomIn.TextButton, -0.5)
	bindZoom(MobileControls.zoomOut.TextButton, 0.5)

	local NAV_GAMEPAD_SPEED  = Vector3.one
	local NAV_KEYBOARD_SPEED = Vector3.one
	local PAN_MOUSE_SPEED    = Vector2.one * (pi / 64)
	local PAN_GAMEPAD_SPEED  = Vector2.one * (pi / 8)
	local FOV_WHEEL_SPEED    = 1.0
	local FOV_GAMEPAD_SPEED  = 0.25
	local NAV_ADJ_SPEED      = 0.75
	local NAV_SHIFT_MUL      = 0.25

	local navSpeed = 1

	function Input.Vel(dt)
		navSpeed = clamp(navSpeed + dt * (keyboard.Up - keyboard.Down) * NAV_ADJ_SPEED, 0.01, 4)

		local kGamepad = Vector3.new(
			thumbstickCurve(gamepad.Thumbstick1.X),
			thumbstickCurve(gamepad.ButtonR2) - thumbstickCurve(gamepad.ButtonL2),
			thumbstickCurve(-gamepad.Thumbstick1.Y)
		) * NAV_GAMEPAD_SPEED

		local kKeyboard = Vector3.new(
			keyboard.D - keyboard.A + keyboard.K - keyboard.H,
			keyboard.E - keyboard.Q + keyboard.I - keyboard.Y,
			keyboard.S - keyboard.W + keyboard.J - keyboard.U
		) * NAV_KEYBOARD_SPEED

		local shift = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
		return (kGamepad + kKeyboard) * (navSpeed * (shift and NAV_SHIFT_MUL or 1))
	end

	function Input.Pan(dt)
		if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled and not UserInputService.MouseEnabled
			and not UserInputService.GamepadEnabled and not GuiService:IsTenFootInterface() then
			local delta = UserInputService:GetMouseDelta()
			mouse.Delta = Vector2.new(-delta.Y, -delta.X)
		end
		local kGamepad = Vector2.new(
			thumbstickCurve(gamepad.Thumbstick2.Y),
			thumbstickCurve(-gamepad.Thumbstick2.X)
		) * PAN_GAMEPAD_SPEED
		local kMouse = mouse.Delta * PAN_MOUSE_SPEED
		mouse.Delta = Vector2.zero
		return kGamepad + kMouse
	end

	function Input.Fov(dt)
		local kGamepad = (gamepad.ButtonX - gamepad.ButtonY) * FOV_GAMEPAD_SPEED
		local kMouse = mouse.MouseWheel * FOV_WHEEL_SPEED
		mouse.MouseWheel = 0
		return kGamepad + kMouse
	end

	do
		local function Keypress(action, state, input)
			keyboard[input.KeyCode.Name] = state == Enum.UserInputState.Begin and 1 or 0
			return Enum.ContextActionResult.Sink
		end

		local function GpButton(action, state, input)
			gamepad[input.KeyCode.Name] = state == Enum.UserInputState.Begin and 1 or 0
			return Enum.ContextActionResult.Sink
		end

		local function MousePan(action, state, input)
			mouse.Delta = Vector2.new(-input.Delta.Y, -input.Delta.X)
			return Enum.ContextActionResult.Sink
		end

		local function Thumb(action, state, input)
			gamepad[input.KeyCode.Name] = input.Position
			return Enum.ContextActionResult.Sink
		end

		local function Trigger(action, state, input)
			gamepad[input.KeyCode.Name] = input.Position.Z
			return Enum.ContextActionResult.Sink
		end

		local function MouseWheel(action, state, input)
			mouse[input.UserInputType.Name] = -input.Position.Z
			return Enum.ContextActionResult.Sink
		end

		local function Zero(t)
			for k in pairs(t) do
				t[k] = t[k] * 0
			end
		end

		function Input.StartCapture()
			ContextActionService:BindActionAtPriority("FreecamKeyboard", Keypress, false, INPUT_PRIORITY,
				Enum.KeyCode.W, Enum.KeyCode.U,
				Enum.KeyCode.A, Enum.KeyCode.H,
				Enum.KeyCode.S, Enum.KeyCode.J,
				Enum.KeyCode.D, Enum.KeyCode.K,
				Enum.KeyCode.E, Enum.KeyCode.I,
				Enum.KeyCode.Q, Enum.KeyCode.Y,
				Enum.KeyCode.Up, Enum.KeyCode.Down
			)
			ContextActionService:BindActionAtPriority("FreecamMousePan", MousePan, false, INPUT_PRIORITY, Enum.UserInputType.MouseMovement)
			ContextActionService:BindActionAtPriority("FreecamMouseWheel", MouseWheel, false, INPUT_PRIORITY, Enum.UserInputType.MouseWheel)
			ContextActionService:BindActionAtPriority("FreecamGamepadButton", GpButton, false, INPUT_PRIORITY, Enum.KeyCode.ButtonX, Enum.KeyCode.ButtonY)
			ContextActionService:BindActionAtPriority("FreecamGamepadTrigger", Trigger, false, INPUT_PRIORITY, Enum.KeyCode.ButtonR2, Enum.KeyCode.ButtonL2)
			ContextActionService:BindActionAtPriority("FreecamGamepadThumbstick", Thumb, false, INPUT_PRIORITY, Enum.KeyCode.Thumbstick1, Enum.KeyCode.Thumbstick2)
		end

		function Input.StopCapture()
			navSpeed = 1
			Zero(gamepad)
			Zero(keyboard)
			Zero(mouse)
			ContextActionService:UnbindAction("FreecamKeyboard")
			ContextActionService:UnbindAction("FreecamMousePan")
			ContextActionService:UnbindAction("FreecamMouseWheel")
			ContextActionService:UnbindAction("FreecamGamepadButton")
			ContextActionService:UnbindAction("FreecamGamepadTrigger")
			ContextActionService:UnbindAction("FreecamGamepadThumbstick")
		end
	end
end

local function GetFocusDistance(cameraFrame)
	local znear = 0.1
	local viewport = Camera.ViewportSize
	local projy = 2 * tan(cameraFov / 2)
	local projx = viewport.X / viewport.Y * projy
	local fx = cameraFrame.RightVector
	local fy = cameraFrame.UpVector
	local fz = cameraFrame.LookVector

	local minVect = Vector3.zero
	local minDist = 512

	for x = 0, 1, 0.5 do
		for y = 0, 1, 0.5 do
			local offset = fx * ((x - 0.5) * projx) - fy * ((y - 0.5) * projy) + fz
			local origin = cameraFrame.Position + offset * znear
			local rayDirection = offset.Unit * minDist
			local rayResult = Workspace:Raycast(origin, rayDirection)
			local hit = rayResult and rayResult.Position or (origin + rayDirection)
			local dist = (hit - origin).Magnitude
			if minDist > dist then
				minDist = dist
				minVect = offset.Unit
			end
		end
	end

	return fz:Dot(minVect) * minDist
end

local function StepFreecam(dt)
	if not CameraLease:IsOwner("Freecam", leaseToken) then return end
	local vel = velSpring:Update(dt, Input.Vel(dt))
	local pan = panSpring:Update(dt, Input.Pan(dt))
	local fov = fovSpring:Update(dt, Input.Fov(dt))

	local zoomFactor = sqrt(tan(rad(70 / 2)) / tan(rad(cameraFov / 2)))

	cameraFov = clamp(cameraFov + fov * FOV_GAIN * (dt / zoomFactor), 1, 120)
	cameraRot = cameraRot + pan * PAN_GAIN * (dt / zoomFactor)
	cameraRot = Vector2.new(clamp(cameraRot.X, -PITCH_LIMIT, PITCH_LIMIT), cameraRot.Y % (2 * pi))

	local cameraCFrame = CFrame.new(cameraPos) * CFrame.fromOrientation(cameraRot.X, cameraRot.Y, 0) * CFrame.new(vel * NAV_GAIN * dt)
	cameraPos = cameraCFrame.Position

	Camera.CFrame = cameraCFrame
	Camera.Focus = cameraCFrame * CFrame.new(0, 0, -GetFocusDistance(cameraCFrame))
	Camera.FieldOfView = cameraFov
end

local PlayerState = {}
do
	local mouseBehavior
	local mouseIconEnabled
	local cameraType
	local cameraFocus
	local cameraCFrame
	local cameraFieldOfView
	local screenGuis = {}
	local coreGuis = {
		Backpack = true,
		Chat = true,
		Health = true,
		PlayerList = true,
	}
	local setCores = {
		BadgesNotificationsActive = true,
		PointsNotificationsActive = true,
	}

	function PlayerState.Push()
		for name in pairs(coreGuis) do
			coreGuis[name] = StarterGui:GetCoreGuiEnabled(Enum.CoreGuiType[name])
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType[name], false)
		end
		for name in pairs(setCores) do
			setCores[name] = StarterGui:GetCore(name)
			StarterGui:SetCore(name, false)
		end
		local playergui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
		if playergui then
			for _, gui in pairs(playergui:GetChildren()) do
				if gui:IsA("ScreenGui") and gui.Enabled and gui.Name ~= "MobileFreecam" and gui ~= script.Parent then
					screenGuis[#screenGuis + 1] = gui
					gui.Enabled = false
				end
			end
		end

		cameraFieldOfView = Camera.FieldOfView
		Camera.FieldOfView = 70
		cameraType = Camera.CameraType
		Camera.CameraType = Enum.CameraType.Custom
		cameraCFrame = Camera.CFrame
		cameraFocus = Camera.Focus

		mouseIconEnabled = UserInputService.MouseIconEnabled
		UserInputService.MouseIconEnabled = true
		mouseBehavior = UserInputService.MouseBehavior
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	end

	function PlayerState.Pop()
		for name, isEnabled in pairs(coreGuis) do
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType[name], isEnabled)
		end
		for name, isEnabled in pairs(setCores) do
			StarterGui:SetCore(name, isEnabled)
		end
		for _, gui in pairs(screenGuis) do
			if gui.Parent then
				gui.Enabled = true
			end
		end
		table.clear(screenGuis)

		Camera.FieldOfView = cameraFieldOfView
		cameraFieldOfView = nil
		Camera.CameraType = cameraType
		cameraType = nil
		Camera.CFrame = cameraCFrame
		cameraCFrame = nil
		Camera.Focus = cameraFocus
		cameraFocus = nil

		UserInputService.MouseIconEnabled = mouseIconEnabled
		mouseIconEnabled = nil
		UserInputService.MouseBehavior = mouseBehavior
		mouseBehavior = nil
	end
end

local function StartFreecam()
	local token = CameraLease:Acquire("Freecam", 100)
	if not token then return false end
	leaseToken = token

	local cframe = Camera.CFrame
	cameraRot = Vector2.new(cframe:toEulerAnglesYXZ())
	cameraPos = cframe.Position
	cameraFov = Camera.FieldOfView

	velSpring:Reset(Vector3.zero)
	panSpring:Reset(Vector2.zero)
	fovSpring:Reset(0)

	PlayerState.Push()
	RunService:BindToRenderStep("Freecam", Enum.RenderPriority.Camera.Value, StepFreecam)
	Input.StartCapture()
	return true
end

local function StopFreecam()
	local owned = CameraLease:IsOwner("Freecam", leaseToken)
	Input.StopCapture()
	RunService:UnbindFromRenderStep("Freecam")
	if owned then
		PlayerState.Pop()
	end
	CameraLease:Release("Freecam", leaseToken)
	leaseToken = nil
end

local enabled = false
local PlayerModule = require(LocalPlayer.PlayerScripts:WaitForChild("PlayerModule"))
local Controls = PlayerModule:GetControls()
local isMobile = UserInputService.TouchEnabled and not UserInputService.MouseEnabled

local closeBtn = script.Parent:WaitForChild("CloseFreecamBtn")
closeBtn.Visible = false

local function TurnOffFreecam()
	if enabled then
		StopFreecam()
		enabled = false
		Controls:Enable()
		closeBtn.Visible = false
		if script.Parent:FindFirstChild("MobileControls") then
			script.Parent.MobileControls.Visible = false
		end
	end
end

_G.__Freecam_Enable = function()
	if not enabled and StartFreecam() then
		enabled = true
		Controls:Disable()
		closeBtn.Visible = true
		if isMobile and script.Parent:FindFirstChild("MobileControls") then
			script.Parent.MobileControls.Visible = true
		end
	end
end

_G.__Freecam_Disable = function()
	TurnOffFreecam()
end

closeBtn.MouseButton1Click:Connect(TurnOffFreecam)

LocalPlayer.CharacterAdded:Connect(function()
	if enabled then
		TurnOffFreecam()
	end
end)
