--!optimize 2
--!native
-- ============================================
-- CENTRALIZED UI SCALE CONTROLLER
-- Menggantikan 20 script AutoResize individual menjadi 1 controller terpusat.
-- Mengatur skala semua ScreenGui di PlayerGui saat resolusi/viewport berubah.
-- ============================================
if _G.__UIScaleControllerLoaded then
	return
end
_G.__UIScaleControllerLoaded = true

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Resolusi referensi desain dasar
local BASE_X = 1366
local BASE_Y = 768

-- Batas clamp per-ScreenGui (sesuai konfigurasi asli masing-masing UI)
local CUSTOM_LIMITS = {
	["EmoteGui"] = { min = 0.6, max = 0.9 },
	["PlayerMenuHandler"] = { min = 0.5, max = 1.0 },
}
local DEFAULT_LIMITS = { min = 0.35, max = 1.0 }

local trackedGuis = {} -- [ScreenGui] = UIScale
local cameraConnection = nil

local function getLimits(guiName)
	return CUSTOM_LIMITS[guiName] or DEFAULT_LIMITS
end

local function applyScaleToGui(screenGui, uiScale, baseScale)
	if not screenGui or not uiScale or not uiScale.Parent then return end
	local limits = getLimits(screenGui.Name)
	uiScale.Scale = math.clamp(baseScale, limits.min, limits.max)
end

local function updateAllScales()
	local camera = Workspace.CurrentCamera
	if not camera then return end

	local screenSize = camera.ViewportSize
	if screenSize.X <= 0 or screenSize.Y <= 0 then return end

	local scaleX = screenSize.X / BASE_X
	local scaleY = screenSize.Y / BASE_Y
	local baseScale = math.min(scaleX, scaleY)

	for screenGui, uiScale in pairs(trackedGuis) do
		if screenGui.Parent == playerGui and uiScale.Parent == screenGui then
			applyScaleToGui(screenGui, uiScale, baseScale)
		else
			trackedGuis[screenGui] = nil
		end
	end
end

local function registerScreenGui(child)
	if not child:IsA("ScreenGui") then return end

	-- Cari UIScale yang sudah ada atau buat baru
	local uiScale = child:FindFirstChildOfClass("UIScale")
	if not uiScale then
		uiScale = Instance.new("UIScale")
		uiScale.Name = "UIScale"
		uiScale.Parent = child
	end

	trackedGuis[child] = uiScale

	-- Update langsung skala gui ini
	local camera = Workspace.CurrentCamera
	if camera and camera.ViewportSize.X > 0 and camera.ViewportSize.Y > 0 then
		local scaleX = camera.ViewportSize.X / BASE_X
		local scaleY = camera.ViewportSize.Y / BASE_Y
		local baseScale = math.min(scaleX, scaleY)
		applyScaleToGui(child, uiScale, baseScale)
	end
end

local function unregisterScreenGui(child)
	trackedGuis[child] = nil
end

-- Daftarkan semua ScreenGui yang sudah ada di PlayerGui
for _, child in ipairs(playerGui:GetChildren()) do
	registerScreenGui(child)
end

playerGui.ChildAdded:Connect(registerScreenGui)
playerGui.ChildRemoved:Connect(unregisterScreenGui)

-- Ikat listener ViewportSize ke kamera saat ini
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
