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
local TopbarPanelRegistry = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("TopbarPanelRegistry"))
local AssetConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("AssetConfig"))
local TOPBAR_ICONS = AssetConfig.Images.Topbar

local CONFIG = {
	Alignment = "left",
	InitDelay = 0.1,
	GlobalAnimations = false,
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
	Menu         = { enabled = true, image = TOPBAR_ICONS.Menu,  label = "", alignment = "right", order = 1 },
	Refresh      = { enabled = true, image = nil, label = "/", alignment = "right", order = 2 },
	Music        = { enabled = true, image = TOPBAR_ICONS.Music, label = "", alignment = "left", order = 1, animate = false },
	Dance        = { enabled = false, image = TOPBAR_ICONS.Dance, label = "", order = 1 },
	Setting      = { enabled = true, image = TOPBAR_ICONS.Setting, label = "", order = 2 },
	FreeCam      = { enabled = true, image = TOPBAR_ICONS.FreeCam, label = "", order = 3 },
	Cinematic    = { enabled = true, image = "", label = "🎬", order = 4 },
	CustomTitle  = { enabled = true, image = "", label = "🏷️", order = 5 },
	ServerList   = { enabled = true, image = "", label = "🌐", caption = "Server List", order = 6 },
	Broadcast    = { enabled = true, image = TOPBAR_ICONS.Broadcast, label = "" },
	MyHat        = { enabled = true, image = TOPBAR_ICONS.MyHat, label = "" },
	GlobalEffect = { enabled = true, image = TOPBAR_ICONS.GlobalEffect, label = "" },
	Gamepass     = { enabled = true, image = TOPBAR_ICONS.Gamepass, label = "", alignment = "right", order = 3 },
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

local function closeAllTopbarPanels()
	for _, data in pairs(icons) do
		if data.isOpen then
			local toggleDrawer = data.gui and data.gui:FindFirstChild("ToggleDrawer")
			if toggleDrawer then
				toggleDrawer:Fire(false)
			elseif data.animate then
				UIAnimator.Close(data.frame)
			else
				data.frame.Visible = false
			end
			data.isOpen = false
			data.icon:deselect()
		end
	end
end

TopbarPanelRegistry:Register("TopbarPlus", closeAllTopbarPanels)

-- ============================================================
-- INSTANT ICON CREATION (NO YIELDING)
-- ============================================================
local function createRawIcon(name)
	local cfg = getCfg(name)
	if not cfg.enabled then return nil end
	local icon = Icon.new()
	icon:setName(name)
	applyConfig(icon, cfg)
	applyStroke(icon)
	return icon
end

-- 1. Main Topbar Icons
-- Sisi Kiri: Musik (di luar menu)
local musicIcon   = createRawIcon("Music")

-- Sisi Kanan: Refresh
local refreshIcon = createRawIcon("Refresh")

-- 2. Menu Icon (Sisi Kanan, sejajar dengan refresh)
local menuCfg = getCfg("Menu")
if menuCfg.enabled then
	menuIcon = Icon.new()
	menuIcon:setName("Menu")
	applyConfig(menuIcon, menuCfg)
	applyStroke(menuIcon)
	menuIcon:autoDeselect(false)
end

-- 3. Icons di dalam Menu Dropdown
local danceIcon     = createRawIcon("Dance")
local setIcon       = createRawIcon("Setting")
local freecamIcon   = createRawIcon("FreeCam")
local cinematicIcon  = createRawIcon("Cinematic")
local titleIcon      = createRawIcon("CustomTitle")
local serverListIcon = createRawIcon("ServerList")
local broadcastIcon  = createRawIcon("Broadcast")
local hatIcon        = createRawIcon("MyHat")
local effectIcon     = createRawIcon("GlobalEffect")
local gamepassIcon   = createRawIcon("Gamepass")

-- Initially disable network-dependent icons until verified
if broadcastIcon then broadcastIcon:setEnabled(false) end
if effectIcon then effectIcon:setEnabled(false) end
-- Shop hanya muncul jika FeatureFlags.VIPShopEnabled bernilai true.
if gamepassIcon then gamepassIcon:setEnabled(false) end

if menuIcon then
	local activeMenu = {}
	if danceIcon then table.insert(activeMenu, danceIcon) end
	if setIcon then table.insert(activeMenu, setIcon) end
	if freecamIcon then table.insert(activeMenu, freecamIcon) end
	if cinematicIcon then table.insert(activeMenu, cinematicIcon) end
	if titleIcon then table.insert(activeMenu, titleIcon) end
	if serverListIcon then table.insert(activeMenu, serverListIcon) end
	
	-- Menu Spesial (Network)
	if broadcastIcon then table.insert(activeMenu, broadcastIcon) end
	if hatIcon then table.insert(activeMenu, hatIcon) end
	if effectIcon then table.insert(activeMenu, effectIcon) end
	-- Gamepass sengaja TIDAK dimasukkan ke menu; tampil langsung di topbar kanan.
	
	-- Gunakan setMenu agar bergeser ke samping
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
			local lastTopbarCloseClick = 0
			local cc = closeBtn.MouseButton1Click:Connect(function()
				local now = os.clock()
				if now - lastTopbarCloseClick < 0.3 then return end
				lastTopbarCloseClick = now

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

	local lastToggleIconTime = 0
	icon:bindEvent("selected", function()
		local now = os.clock()
		if now - lastToggleIconTime < 0.3 then return end
		lastToggleIconTime = now

		playClick()
		TopbarPanelRegistry:CloseOthers("TopbarPlus")
		for otherName, d in pairs(icons) do
			if otherName ~= name and d.isOpen and not d.lockSync then
				local toggleDrawer = d.gui and d.gui:FindFirstChild("ToggleDrawer")
				if toggleDrawer then
					toggleDrawer:Fire(false)
				elseif d.animate then
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
			local toggleDrawer = d.gui and d.gui:FindFirstChild("ToggleDrawer")
			if toggleDrawer then
				toggleDrawer:Fire(true)
			elseif d.animate then
				UIAnimator.Open(d.frame)
			else
				d.frame.Visible = true
			end
			d.isOpen = true
		end
	end)

	icon:bindEvent("deselected", function()
		local now = os.clock()
		if now - lastToggleIconTime < 0.3 then return end
		lastToggleIconTime = now

		playClick()
		local d = icons[name]
		if d and d.frame and not d.lockSync then
			local toggleDrawer = d.gui and d.gui:FindFirstChild("ToggleDrawer")
			if toggleDrawer then
				toggleDrawer:Fire(false)
			elseif d.animate then
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

-- Dance diputuskan dari topbar karena sudah ada button sendiri buat dancenya.
-- Pastikan tombol asli di EmoteGui tetap terlihat jika sebelumnya sempat di-hide.
task.spawn(function()
	local gui = playerGui:WaitForChild("EmoteGui", 5)
	if gui then
		local btn = gui:FindFirstChild("DanceToggleButton") or gui:FindFirstChild("Dance")
		if btn then btn.Visible = true end
	end
end)

task.spawn(function()
	local gui = playerGui:WaitForChild("MusicPlayer", 5)
	if gui then
		local frame = gui:WaitForChild("MainFrame", 5)
		local cp = frame and frame:FindFirstChild("Header") and {"Header","CloseBtn"} or {"CloseBtn"}
		bindIconLogic("Music", musicIcon, gui, frame, cp, "MusicBtn")
	end
end)

task.spawn(function()
	local gui = playerGui:WaitForChild("GamepassShop")
	if gui then
		gui.Enabled = false
		local frame = gui:FindFirstChild("MainFrame")
		if frame then frame.Visible = false end
	end

	if not gui or not gamepassIcon then return end
	local frame = gui:FindFirstChild("MainFrame")
	if not frame then return end

	local featureFolder = ReplicatedStorage:WaitForChild("FeatureFlags")
	local shopFlag = featureFolder:WaitForChild("VIPShopEnabled")
	local bound = false

	local function applyShopEnabled()
		if shopFlag.Value == true then
			if not bound then
				bound = true
				bindIconLogic("Gamepass", gamepassIcon, gui, frame, {"Header","CloseBtn"})
			end
			gui.Enabled = true
			gamepassIcon:setEnabled(true)
		else
			gui.Enabled = false
			gamepassIcon:setEnabled(false)
		end
	end

	applyShopEnabled()
	shopFlag:GetPropertyChangedSignal("Value"):Connect(applyShopEnabled)
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

task.spawn(function()
	local gui = playerGui:WaitForChild("CustomTitleGui", 10)
	if gui then
		local frame = gui:WaitForChild("MainFrame", 5)
		if frame and titleIcon then
			local cp = frame:FindFirstChild("Header") and {"Header","CloseBtn"} or {"CloseBtn"}
			bindIconLogic("CustomTitle", titleIcon, gui, frame, cp)
		end
	end
end)

task.spawn(function()
	local gui = playerGui:WaitForChild("CinematicCamGui", 10)
	if gui then
		local frame = gui:WaitForChild("MainFrame", 5)
		if frame and cinematicIcon then
			local cp = frame:FindFirstChild("Header") and {"Header","CloseBtn"} or {"CloseBtn"}
			bindIconLogic("Cinematic", cinematicIcon, gui, frame, cp)
		end
	end
end)

task.spawn(function()
	local gui = playerGui:WaitForChild("ServerListGui", 10)
	if gui then
		local frame = gui:WaitForChild("MainFrame", 5)
		if frame and serverListIcon then
			local cp = frame:FindFirstChild("Header") and {"Header","RightControls","CloseBtn"} or {"CloseBtn"}
			bindIconLogic("ServerList", serverListIcon, gui, frame, cp)
		end
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
				
				local function setHatEnabled(show)
					hatIcon:setEnabled(show == true)
					if not show and icons["MyHat"] then
						local d = icons["MyHat"]
						if d.isOpen then
							if d.animate then UIAnimator.Close(d.frame) else d.frame.Visible = false end
							d.isOpen = false
							hatIcon:deselect()
						end
					end
				end

				-- Attribute tetap benar walau event ShowIcon sudah lewat
				-- sebelum client selesai binding.
				setHatEnabled(player:GetAttribute("CanUseHat") == true)
				local attrConn = player:GetAttributeChangedSignal("CanUseHat"):Connect(function()
					setHatEnabled(player:GetAttribute("CanUseHat") == true)
				end)
				hatIcon:addToJanitor(attrConn)

				local se = ar:WaitForChild("ShowIcon", 5)
				if se then
					local sc = se.OnClientEvent:Connect(function(show)
						setHatEnabled(show)
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
