--!optimize 2
--!native
local ScriptOnce = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("ScriptOnce"))
if not ScriptOnce.Claim("UIScaleController") then return end

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local BASE_X = 1366
local BASE_Y = 768
local MIN_SCALE = 0.6
local MAX_SCALE = 1
local HARD_MIN_SCALE = 0.4
local FIT_MARGIN = 0.95

local GAME_GUI_NAMES = {}
for _, child in ipairs(StarterGui:GetChildren()) do
	if child:IsA("ScreenGui") then
		GAME_GUI_NAMES[child.Name] = true
	end
end

local EXTERNALLY_SCALED = {
	MusicPlayer = true,
}

local trackedGuis = {} 
local pendingRefresh = {} 
local cameraConnection = nil
local fullscreenSizes = setmetatable({}, { __mode = "k" })

local function getDesignSize(screenGui, viewport, currentScale)
	local maxW, maxH = 0, 0
	for _, child in ipairs(screenGui:GetChildren()) do
		if child:IsA("GuiObject") then
			local size = child.Size
			local fullscreen = size.X.Scale >= 0.98 and size.Y.Scale >= 0.98
			if not fullscreen then
				local designW, designH
				if size.X.Scale == 0 and size.Y.Scale == 0 then
					local abs = child.AbsoluteSize / currentScale
					designW, designH = abs.X, abs.Y
				else
					designW = size.X.Scale * viewport.X + size.X.Offset
					designH = size.Y.Scale * viewport.Y + size.Y.Offset
				end
				if designW > maxW then maxW = designW end
				if designH > maxH then maxH = designH end
			end
		end
	end
	return maxW, maxH
end

local function getGlobalScale(viewport)
	local scale = math.min(viewport.X / BASE_X, viewport.Y / BASE_Y)
	return math.clamp(scale, MIN_SCALE, MAX_SCALE)
end

local function updateFullscreenChildren(screenGui, scale)
	for _, child in ipairs(screenGui:GetChildren()) do
		if child:IsA("GuiObject") and child.Size.X.Scale >= 0.98 and child.Size.Y.Scale >= 0.98 then
			local original = fullscreenSizes[child]
			if not original then
				original = child.Size
				fullscreenSizes[child] = original
			end
			if scale ~= 1 then
				child.Size = UDim2.new(
					original.X.Scale / scale,
					original.X.Offset / scale,
					original.Y.Scale / scale,
					original.Y.Offset / scale
				)
			else
				child.Size = original
			end
		end
	end
end

local function updateGui(screenGui)
	local uiScale = trackedGuis[screenGui]
	if not uiScale or uiScale.Parent ~= screenGui then
		trackedGuis[screenGui] = nil
		return
	end

	local camera = Workspace.CurrentCamera
	if not camera then return end
	local viewport = camera.ViewportSize
	if viewport.X <= 0 or viewport.Y <= 0 then return end

	local currentScale = uiScale.Scale
	if currentScale <= 0 then currentScale = 1 end

	local scale = getGlobalScale(viewport)

	local designW, designH = getDesignSize(screenGui, viewport, currentScale)
	if designW > 0 and designH > 0 then
		local fitScale = math.min(
			(viewport.X * FIT_MARGIN) / designW,
			(viewport.Y * FIT_MARGIN) / designH
		)
		if fitScale < scale then
			scale = fitScale
		end
	end

	uiScale.Scale = math.clamp(scale, HARD_MIN_SCALE, MAX_SCALE)
	updateFullscreenChildren(screenGui, uiScale.Scale)
end

local function updateAllScales()
	for screenGui in pairs(trackedGuis) do
		updateGui(screenGui)
	end
end

local function scheduleRefresh(screenGui)
	if pendingRefresh[screenGui] then return end
	pendingRefresh[screenGui] = true
	task.defer(function()
		pendingRefresh[screenGui] = nil
		updateGui(screenGui)
	end)
end

local function registerScreenGui(child)
	if not child:IsA("ScreenGui") then return end

	if not GAME_GUI_NAMES[child.Name] then return end
	if EXTERNALLY_SCALED[child.Name] then return end

	local uiScale = child:FindFirstChildOfClass("UIScale")
	if not uiScale then
		uiScale = Instance.new("UIScale")
		uiScale.Name = "UIScale"
		uiScale.Parent = child
	end

	trackedGuis[child] = uiScale
	updateGui(child)

	child.ChildAdded:Connect(function(grandChild)
		if not grandChild:IsA("UIScale") then
			scheduleRefresh(child)
		end
	end)
	child.ChildRemoved:Connect(function(grandChild)
		if not grandChild:IsA("UIScale") then
			scheduleRefresh(child)
		end
	end)
	child:GetPropertyChangedSignal("Enabled"):Connect(function()
		scheduleRefresh(child)
	end)
end

for _, child in ipairs(playerGui:GetChildren()) do
	registerScreenGui(child)
end

playerGui.ChildAdded:Connect(registerScreenGui)
playerGui.ChildRemoved:Connect(function(child)
	trackedGuis[child] = nil
	pendingRefresh[child] = nil
end)

local function bindCameraListener()
	if cameraConnection then
		cameraConnection:Disconnect()
		cameraConnection = nil
	end

	local camera = Workspace.CurrentCamera
	if camera then
		cameraConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateAllScales)
		updateAllScales()
	end
end

bindCameraListener()
Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindCameraListener)
