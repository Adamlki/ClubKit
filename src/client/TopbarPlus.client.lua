-- ============================================================
-- UNIFIED TOPBAR PLUS V3 & SYNCTO SCRIPT
-- ============================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players           = game:GetService("Players")
local SoundService      = game:GetService("SoundService")
local RunService        = game:GetService("RunService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Icon      = require(ReplicatedStorage:WaitForChild("Icon"))
local UIAnimator = require(ReplicatedStorage:WaitForChild("UIAnimator"))

local CONFIG = {
	Alignment = "left",
	InitDelay = 0.1,
	GlobalAnimations = true,
	UseStroke       = false,
	StrokeThickness = 0,
	StrokeColor     = Color3.fromRGB(255, 255, 255),
	UseGradient   = false,
	GradientSpeed = 90,
	GradientColor0 = Color3.fromRGB(255, 255, 255),
	GradientColor1 = Color3.fromRGB(0,   0,   0),
	GradientColor2 = Color3.fromRGB(255, 255, 255),
}

local ICON_CONFIGS = {
	Menu      = { enabled = true, image = "rbxassetid://87603332567027",  label = "", order = 1 },
	Dance     = { enabled = true, image = "rbxassetid://113394514826547", label = "", order = 2 },
	Music     = { enabled = true, image = "rbxassetid://123643550590893", label = "", order = 3, animate = false },
	Gamepass  = { enabled = true, image = "rbxassetid://140276937557646", label = "", order = 4 },
	Setting   = { enabled = true, image = "rbxassetid://116292866711662", label = "", order = 5 }, 
	FreeCam   = { enabled = true, image = "rbxassetid://134750039859396", label = "", order = 6 }, 
	Refresh   = { enabled = true, image = nil, label = "/", alignment = "right", order = 7 },
	Broadcast = { enabled = true, image = "rbxassetid://124033060370841", label = ""},
	MyHat     = { enabled = true, image = "rbxassetid://120495411505696", label = "" },
	GlobalEffect = { enabled = true, image = "rbxassetid://84595853614117", label = "" },
}

local function getCfg(name)
	local cfg = ICON_CONFIGS[name] or {}
	return {
		enabled    = cfg.enabled    ~= false,
		label      = cfg.label      or name,
		image      = cfg.image      or nil,
		imageScale = cfg.imageScale or nil,
		caption    = cfg.caption    or nil,
		order      = cfg.order      or nil,
		alignment  = cfg.alignment  or CONFIG.Alignment,
		animate    = CONFIG.GlobalAnimations and (cfg.animate ~= false),
	}
end

local clickSound
pcall(function() clickSound = SoundService:WaitForChild("Sound", 3) end)
local function playClick()
	if clickSound then
		pcall(function()
			clickSound.TimePosition = 0
			clickSound:Play()
		end)
	end
end

-- ============================================================
-- UISTROKE + GRADIENT
-- ============================================================
local gradientRotation    = 0
local registeredGradients = {}

if CONFIG.UseStroke and CONFIG.UseGradient then
	RunService.Heartbeat:Connect(function(dt)
		gradientRotation = (gradientRotation + CONFIG.GradientSpeed * dt) % 180
		for _, g in pairs(registeredGradients) do
			g.Rotation = gradientRotation
		end
	end)
end

local function getIconWidget(icon)
	local candidates = { "IconFrame", "IconContainer", "Widget", "ClickRegion" }
	for _, name in ipairs(candidates) do
		local inst = icon:getInstance(name)
		if inst then return inst end
	end
	return icon.widget
end

local function applyStroke(icon)
	if not CONFIG.UseStroke then return end
	local widget = getIconWidget(icon)
	if not widget then return end

	local stroke = Instance.new("UIStroke")
	stroke.Name            = "TopbarStroke"
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Thickness       = CONFIG.StrokeThickness
	stroke.Color           = CONFIG.StrokeColor
	stroke.Parent          = widget

	if CONFIG.UseGradient then
		local gradient = Instance.new("UIGradient")
		gradient.Name     = "StrokeGradient"
		gradient.Color    = ColorSequence.new({
			ColorSequenceKeypoint.new(0,   CONFIG.GradientColor0),
			ColorSequenceKeypoint.new(0.5, CONFIG.GradientColor1),
			ColorSequenceKeypoint.new(1,   CONFIG.GradientColor2),
		})
		gradient.Rotation = gradientRotation
		gradient.Parent   = stroke
		local uid = icon.UID
		registeredGradients[uid] = gradient
		icon:addToJanitor(function()
			registeredGradients[uid] = nil
			if stroke and stroke.Parent then stroke:Destroy() end
		end)
	else
		icon:addToJanitor(function()
			if stroke and stroke.Parent then stroke:Destroy() end
		end)
	end
end

local function applyConfig(icon, cfg)
	icon:setLabel(cfg.label)
	if cfg.image then
		if type(cfg.image) == "table" then
			for state, id in pairs(cfg.image) do icon:setImage(id, state) end
		else
			icon:setImage(cfg.image)
		end
		if cfg.imageScale then icon:setImageScale(cfg.imageScale) end
	end
	if cfg.caption then icon:setCaption(cfg.caption) end
	if cfg.order   then icon:setOrder(cfg.order)     end

	local a = cfg.alignment
	if     a == "mid"   then icon:setMid()
	elseif a == "right" then icon:setRight()
	else                     icon:setLeft()
	end
end

local function hideOriginalButton(gui, buttonName)
	if gui then
		local btn = gui:FindFirstChild(buttonName)
		if btn then btn.Visible = false end
	end
end

-- ============================================================
-- STATE
-- ============================================================
local icons         = {}
local menuIcon      = nil
local dropdownIcons = {}
local isInitialized = false

-- ============================================================
-- INSTANT ICON CREATION (NO YIELDING)
-- ============================================================
local function createRawIcon(name)
	local cfg = getCfg(name)
	if not cfg.enabled then return nil end
	local icon = Icon.new()
	applyConfig(icon, cfg)
	applyStroke(icon)
	return icon
end

-- 1. Main Topbar Icons
local danceIcon   = createRawIcon("Dance")
local musicIcon   = createRawIcon("Music")
local gpIcon      = createRawIcon("Gamepass")
local refreshIcon = createRawIcon("Refresh")

-- 2. Menu Icon
local menuCfg = getCfg("Menu")
if menuCfg.enabled then
	menuIcon = Icon.new()
	applyConfig(menuIcon, menuCfg)
	applyStroke(menuIcon)
	menuIcon:autoDeselect(false)
end

-- 3. Dropdown Icons (Temporarily unassigned)
local broadcastIcon = createRawIcon("Broadcast")
local setIcon       = createRawIcon("Setting")
local hatIcon       = createRawIcon("MyHat")
local effectIcon    = createRawIcon("GlobalEffect")
local freecamIcon   = createRawIcon("FreeCam")

-- Initially disable network-dependent icons until verified
if broadcastIcon then broadcastIcon:setEnabled(false) end
if effectIcon then effectIcon:setEnabled(false) end

if menuIcon then
	local activeMenu = {}
	-- Masukkan SEMUA icon ke dalam horizontal menu
	if musicIcon then table.insert(activeMenu, musicIcon) end
	if gpIcon then table.insert(activeMenu, gpIcon) end
	if setIcon then table.insert(activeMenu, setIcon) end
	if freecamIcon then table.insert(activeMenu, freecamIcon) end
	
	-- Menu Spesial (Network)
	if broadcastIcon then table.insert(activeMenu, broadcastIcon) end
	if hatIcon then table.insert(activeMenu, hatIcon) end
	if effectIcon then table.insert(activeMenu, effectIcon) end
	
	-- Gunakan setMenu agar bergeser ke samping secara horizontal
	menuIcon:setMenu(activeMenu)
end

-- ============================================================
-- ASYNC LOGIC HOOKUPS
-- ============================================================

local function setupFrameSync(name, icon, frame, closeButtonPath)
	if not icon or not frame then return end
	local d = icons[name]
	local conn = frame:GetPropertyChangedSignal("Visible"):Connect(function()
		if not isInitialized then return end
		if not d or d.lockSync then return end
		if frame.Visible and not d.isOpen then
			d.lockSync = true
			icon:select()
			d.isOpen  = true
			d.lockSync = false
		elseif not frame.Visible and d.isOpen then
			d.lockSync = true
			icon:deselect()
			d.isOpen  = false
			d.lockSync = false
		end
	end)
	icon:addToJanitor(conn)

	if closeButtonPath then
		local closeBtn = frame
		for _, part in ipairs(closeButtonPath) do
			closeBtn = closeBtn and closeBtn:FindFirstChild(part)
		end
		if closeBtn then
			local cc = closeBtn.MouseButton1Click:Connect(function()
				icon:deselect()
			end)
			icon:addToJanitor(cc)
		end
	end
end

local function bindIconLogic(name, icon, gui, frame, closeBtnPath, originalBtnName)
	if not icon then return end
	local cfg = getCfg(name)
	icons[name] = { icon = icon, gui = gui, frame = frame, isOpen = false, lockSync = false, animate = cfg.animate }

	icon:bindEvent("selected", function()
		playClick()
		for otherName, d in pairs(icons) do
			if otherName ~= name and d.isOpen and not d.lockSync then
				if d.animate then
					UIAnimator.Close(d.frame)
				else
					d.frame.Visible = false
				end
				d.isOpen = false
				d.icon:deselect()
			end
		end
		local d = icons[name]
		if d and d.frame and not d.lockSync then
			if d.animate then
				UIAnimator.Open(d.frame)
			else
				d.frame.Visible = true
			end
			d.isOpen = true
		end
	end)

	icon:bindEvent("deselected", function()
		playClick()
		local d = icons[name]
		if d and d.frame and not d.lockSync then
			if d.animate then
				UIAnimator.Close(d.frame)
			else
				d.frame.Visible = false
			end
			d.isOpen = false
		end
	end)

	if gui and originalBtnName then
		hideOriginalButton(gui, originalBtnName)
	end
	if frame then
		setupFrameSync(name, icon, frame, closeBtnPath)
		-- Ensure initial state
		if frame.Visible then frame.Visible = false end
	end
end

-- ============================================================
-- SPAWN GUI FETCHING
-- ============================================================

task.spawn(function()
	local gui = playerGui:WaitForChild("EmoteGui", 5)
	if gui then
		local frame = gui:WaitForChild("MainFrame", 5)
		bindIconLogic("Dance", danceIcon, gui, frame, {"Header", "CloseBtn"}, "Dance")
	end
end)

task.spawn(function()
	local gui = playerGui:WaitForChild("MusicPlayer", 5)
	if gui then
		local frame = gui:WaitForChild("MainFrame", 5)
		bindIconLogic("Music", musicIcon, gui, frame, {"CloseBtn"}, "MusicBtn")
	end
end)

task.spawn(function()
	local gui = playerGui:WaitForChild("GamepassShop", 5)
	if gui then
		local frame = gui:WaitForChild("MainFrame", 5)
		local cp = frame and frame:FindFirstChild("Header") and {"Header","CloseBtn"} or {"CloseBtn"}
		bindIconLogic("Gamepass", gpIcon, gui, frame, cp, "Shop")
	end
end)

task.spawn(function()
	local gui = playerGui:WaitForChild("RefreshGui", 5)
	if gui then
		local frame = gui:WaitForChild("MainFrame", 5)
		local cp = frame and frame:FindFirstChild("Header") and {"Header","CloseBtn"} or {"CloseBtn"}
		bindIconLogic("Refresh", refreshIcon, gui, frame, cp)
	end
end)

task.spawn(function()
	local gui = playerGui:WaitForChild("SettingGui", 5)
	if gui then
		local frame = gui:WaitForChild("Mainframe", 5)
		local cp = frame and frame:FindFirstChild("HeaderFrame") and {"HeaderFrame","CloseBtn"} or {"CloseBtn"}
		bindIconLogic("Setting", setIcon, gui, frame, cp, "SettingBtn")
	end
end)

-- Network Dependent Icons
task.spawn(function()
	local gui = playerGui:WaitForChild("AdminNotif", 10)
	if gui then
		local frame = gui:WaitForChild("MainFrame", 5)
		local rf = ReplicatedStorage:WaitForChild("Message", 10)
		local rc = rf and rf:WaitForChild("CheckAccess", 5)
		if rc then
			local ok, has = pcall(function() return rc:InvokeServer() end)
			if ok and has and broadcastIcon then
				bindIconLogic("Broadcast", broadcastIcon, gui, frame, {"CloseBtn"})
				broadcastIcon:setEnabled(true)
			end
		end
	end
end)

task.spawn(function()
	local gui = playerGui:WaitForChild("MyHat", 10)
	if gui then
		local frame = gui:WaitForChild("Mainframe", 5)
		if frame then
			local ar = ReplicatedStorage:WaitForChild("AccessoryRemotes", 10)
			if ar and hatIcon then
				bindIconLogic("MyHat", hatIcon, gui, frame, frame:FindFirstChild("Header") and {"Header","CloseBtn"} or {"CloseBtn"})
				hatIcon:setEnabled(false)
				
				local se = ar:WaitForChild("ShowIcon", 5)
				if se then
					local sc = se.OnClientEvent:Connect(function(show)
						hatIcon:setEnabled(show)
						if not show and icons["MyHat"] then
							local d = icons["MyHat"]
							if d.isOpen then
								if d.animate then UIAnimator.Close(d.frame) else d.frame.Visible = false end
								d.isOpen = false
								hatIcon:deselect()
							end
						end
					end)
					hatIcon:addToJanitor(sc)
				end
			end
		end
	end
end)

task.spawn(function()
	local gui = playerGui:WaitForChild("GlobalEffectGui", 10)
	if gui then
		local frame = gui:WaitForChild("MainFrame", 5)
		if frame then
			local rf = ReplicatedStorage:WaitForChild("GlobalEffectRemotes", 5)
			local rc = rf and rf:WaitForChild("CheckOwner", 5)
			if rc then
				local ok, isOwner = pcall(function() return rc:InvokeServer() end)
				if ok and isOwner and effectIcon then
					bindIconLogic("GlobalEffect", effectIcon, gui, frame, {"CloseBtn"})
					effectIcon:setEnabled(true)
				end
			end
		end
	end
end)

-- Freecam
if freecamIcon then
	local freecamState = { isOn = false, debounce = false }
	freecamIcon:bindEvent("selected", function()
		if freecamState.debounce then return end
		freecamState.debounce = true
		playClick()
		freecamState.isOn = true
		if _G.__Freecam_Enable then _G.__Freecam_Enable() end
		task.delay(0.35, function() freecamState.debounce = false end)
	end)
	freecamIcon:bindEvent("deselected", function()
		if freecamState.debounce then return end
		playClick()
		freecamState.isOn = false
		if _G.__Freecam_Disable then _G.__Freecam_Disable() end
		freecamState.debounce = false
	end)
end


-- ============================================================
-- INIT & CLEANUP
-- ============================================================
task.wait(CONFIG.InitDelay)
isInitialized = true

Players.PlayerRemoving:Connect(function(removingPlayer)
	if removingPlayer ~= player then return end

	for _, d in pairs(icons) do
		if d.icon then pcall(function() d.icon:destroy() end) end
	end
	if menuIcon    then pcall(function() menuIcon:destroy()    end) end
	if freecamIcon then pcall(function() freecamIcon:destroy() end) end

	icons = {}
end)
