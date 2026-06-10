-- ============================================================
-- UNIFIED TOPBAR PLUS V3 & SYNCTO SCRIPT
-- LocalScript in StarterPlayer.StarterPlayerScripts
-- ============================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players           = game:GetService("Players")
local SoundService      = game:GetService("SoundService")
local RunService        = game:GetService("RunService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Icon      = require(ReplicatedStorage:WaitForChild("Icon"))

-- Remotes untuk SyncTo
local Remotes            = ReplicatedStorage:WaitForChild("Remotes", 15)
local UpdateLeaderStatus = Remotes and Remotes:WaitForChild("UpdateLeaderStatus", 10)
local startSyncRE        = Remotes and Remotes:WaitForChild("startSync", 10)

-- ============================================================
-- CONFIG
-- ============================================================
local CONFIG = {
	Alignment = "left",
	InitDelay = 2,

	UseStroke       = false,
	StrokeThickness = 1,
	StrokeColor     = Color3.fromRGB(255, 255, 255),

	UseGradient   = false,
	GradientSpeed = 90,

	GradientColor0 = Color3.fromRGB(255, 255, 255),
	GradientColor1 = Color3.fromRGB(0,   0,   0),
	GradientColor2 = Color3.fromRGB(255, 255, 255),
}

-- ============================================================
-- PER-ICON CONFIG
-- ============================================================
local ICON_CONFIGS = {
	Menu      = { enabled = true, label = "Menu",     order = 1 },
	Dance     = { enabled = true, label = "Dance",    order = 2 },
	Music     = { enabled = true, label = "Music",    order = 3 },
	Gamepass  = { enabled = true, label = "Shop",     order = 5 }, -- Shop di luar menu

	-- Item di dalam Menu:
	Broadcast = { enabled = true, label = "BC"       },
	Teleport  = { enabled = true, label = "Places"   },
	Setting   = { enabled = true, label = "Settings" },
	MyHat     = { enabled = true, label = "Crown"    },
	FreeCam   = { enabled = true, label = "FreeCam"  },
	GlobalEffect = { enabled = true, label = "Global Effect" },
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
	}
end

-- ============================================================
-- SOUND
-- ============================================================
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
-- GUI REFERENCES
-- ============================================================
local function safeGet(parent, name, timeout)
	local ok, res = pcall(function() return parent:WaitForChild(name, timeout or 15) end)
	return ok and res or nil
end

local guis = {
	Emote         = safeGet(playerGui, "EmoteGui"),
	Gamepass      = safeGet(playerGui, "GamepassShop"),
	Music         = safeGet(playerGui, "MusicPlayer"),
	Setting       = safeGet(playerGui, "SettingGui"),
	Teleport      = safeGet(playerGui, "Teleport"),
	MyHat         = safeGet(playerGui, "MyHat"),
	ServerMessage = safeGet(playerGui, "AdminNotif"),
	GlobalEffect  = safeGet(playerGui, "GlobalEffectGui", 5),
}

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

-- ============================================================
-- STATE
-- ============================================================
local icons         = {}
local menuIcon      = nil
local dropdownIcons = {}
local isInitialized = false

local freecamState = { isOn = false, debounce = false }
local freecamIcon  = nil

-- ============================================================
-- HELPERS
-- ============================================================
local function hideOriginalButton(gui, buttonName)
	if gui then
		local btn = gui:FindFirstChild(buttonName)
		if btn then btn.Visible = false end
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

-- ============================================================
-- CREATE ICON
-- ============================================================
local function createIcon(name, targetGui, targetFrame)
	if not targetGui or not targetFrame then return nil end
	local cfg = getCfg(name)
	if not cfg.enabled then return nil end

	local icon = Icon.new()
	applyConfig(icon, cfg)
	applyStroke(icon)

	icons[name] = { icon = icon, gui = targetGui, frame = targetFrame, isOpen = false, lockSync = false }

	icon:bindEvent("selected", function()
		playClick()
		for otherName, d in pairs(icons) do
			if otherName ~= name and d.isOpen and not d.lockSync then
				d.frame.Visible = false
				d.isOpen = false
				d.icon:deselect()
			end
		end
		local d = icons[name]
		if d and d.frame and not d.lockSync then
			d.frame.Visible = true
			d.isOpen = true
		end
		if menuIcon then
			task.wait(0.1)
			menuIcon:deselect()
		end
	end)

	icon:bindEvent("deselected", function()
		playClick()
		local d = icons[name]
		if d and not d.lockSync then
			d.frame.Visible = false
			d.isOpen = false
		end
	end)

	return icon
end

local function createToggleIcon(name)
	local cfg = getCfg(name)
	if not cfg.enabled then return nil end
	local icon = Icon.new()
	applyConfig(icon, cfg)
	applyStroke(icon)
	return icon
end

local function setupFrameSync(name, frame, closeButtonPath)
	local d = icons[name]
	if not d or not frame then return end

	local conn = frame:GetPropertyChangedSignal("Visible"):Connect(function()
		if not isInitialized then return end
		local dd = icons[name]
		if not dd or dd.lockSync then return end
		if frame.Visible and not dd.isOpen then
			dd.lockSync = true
			dd.icon:select()
			dd.isOpen  = true
			dd.lockSync = false
		elseif not frame.Visible and dd.isOpen then
			dd.lockSync = true
			dd.icon:deselect()
			dd.isOpen  = false
			dd.lockSync = false
		end
	end)
	d.icon:addToJanitor(conn)

	if closeButtonPath then
		local closeBtn = frame
		for _, part in ipairs(closeButtonPath) do
			closeBtn = closeBtn and closeBtn:FindFirstChild(part)
		end
		if closeBtn then
			local cc = closeBtn.MouseButton1Click:Connect(function()
				local dd = icons[name]
				if dd then dd.icon:deselect() end
			end)
			d.icon:addToJanitor(cc)
		end
	end
end

-- ============================================================
-- ICON CREATION — STANDALONE (LUAR DROPDOWN)
-- ============================================================

if guis.Emote then
	local frame = guis.Emote:FindFirstChild("MainFrame")
	local icon  = createIcon("Dance", guis.Emote, frame)
	if icon then
		setupFrameSync("Dance", frame, nil)
		hideOriginalButton(guis.Emote, "Dance")
	end
end

if guis.Music then
	local frame = guis.Music:FindFirstChild("MainFrame")
	local icon  = createIcon("Music", guis.Music, frame)
	if icon then
		setupFrameSync("Music", frame, {"CloseBtn"})
		hideOriginalButton(guis.Music, "MusicBtn")
	end
end

if guis.Gamepass then
	local frame = guis.Gamepass:FindFirstChild("MainFrame")
	local icon  = createIcon("Gamepass", guis.Gamepass, frame)
	if icon then
		hideOriginalButton(guis.Gamepass, "Shop")
		local cp = frame and frame:FindFirstChild("Header") and {"Header","CloseBtn"} or {"CloseBtn"}
		setupFrameSync("Gamepass", frame, cp)
	end
end

-- ============================================================
-- MENU ICON UTAMA
-- ============================================================
local menuCfg = getCfg("Menu")
if menuCfg.enabled then
	menuIcon = Icon.new()
	applyConfig(menuIcon, menuCfg)
	applyStroke(menuIcon)
	menuIcon:autoDeselect(false)
end

-- ============================================================
-- ICON CREATION — DROPDOWN ITEMS (DALAM MENU)
-- ============================================================

if guis.ServerMessage then
	local frame = guis.ServerMessage:FindFirstChild("MainFrame")
	if frame then
		local rf = ReplicatedStorage:WaitForChild("Message", 10)
		local rc = rf and rf:WaitForChild("CheckAccess", 5)
		if rc then
			local ok, has = pcall(function() return rc:InvokeServer() end)
			if ok and has then
				local icon = createIcon("Broadcast", guis.ServerMessage, frame)
				if icon then 
					table.insert(dropdownIcons, icon)
					setupFrameSync("Broadcast", frame, {"CloseBtn"}) 
				end
			end
		end
	end
end

if guis.Teleport then
	local frame = guis.Teleport:FindFirstChild("MainFrame")
	local icon  = createIcon("Teleport", guis.Teleport, frame)
	if icon then
		table.insert(dropdownIcons, icon)
		setupFrameSync("Teleport", frame, {"headerframe", "CloseBtn"})
	end
end

if guis.Setting then
	local frame = guis.Setting:FindFirstChild("Mainframe")
	local icon  = createIcon("Setting", guis.Setting, frame)
	if icon then
		table.insert(dropdownIcons, icon)
		hideOriginalButton(guis.Setting, "SettingBtn")
		local cp = frame and frame:FindFirstChild("HeaderFrame") and {"HeaderFrame","CloseBtn"} or {"CloseBtn"}
		setupFrameSync("Setting", frame, cp)
	end
end

if guis.MyHat then
	local frame = guis.MyHat:FindFirstChild("Mainframe")
	if frame then
		local ar = ReplicatedStorage:WaitForChild("AccessoryRemotes", 10)
		if ar then
			local icon = createIcon("MyHat", guis.MyHat, frame)
			if icon then
				table.insert(dropdownIcons, icon)
				icon:setEnabled(false)
				local se = ar:WaitForChild("ShowIcon", 5)
				if se then
					local sc = se.OnClientEvent:Connect(function(show)
						icon:setEnabled(show)
						if not show then
							local d = icons["MyHat"]
							if d then
								d.frame.Visible = false
								d.isOpen = false
								icon:deselect()
							end
						end
					end)
					icon:addToJanitor(sc)
				end
				local cp = frame:FindFirstChild("Header") and {"Header","CloseBtn"} or {"CloseBtn"}
				setupFrameSync("MyHat", frame, cp)
			end
		end
	end
end

if guis.GlobalEffect then
	local frame = guis.GlobalEffect:FindFirstChild("MainFrame")
	if frame then
		local rf = ReplicatedStorage:WaitForChild("GlobalEffectRemotes", 5)
		local rc = rf and rf:WaitForChild("CheckOwner", 5)
		if rc then
			local ok, isOwner = pcall(function() return rc:InvokeServer() end)
			if ok and isOwner then
				local icon = createIcon("GlobalEffect", guis.GlobalEffect, frame)
				if icon then
					table.insert(dropdownIcons, icon)
					setupFrameSync("GlobalEffect", frame, {"CloseBtn"})
				end
			end
		end
	end
end

freecamIcon = createToggleIcon("FreeCam")
if freecamIcon then
	table.insert(dropdownIcons, freecamIcon)
	freecamIcon:bindEvent("selected", function()
		if freecamState.debounce then return end
		freecamState.debounce = true
		playClick()
		freecamState.isOn = true
		if _G.__Freecam_Enable then _G.__Freecam_Enable() end
		if menuIcon then task.wait(0.1) ; menuIcon:deselect() end
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
-- SYNCTO LOGIC [DIMASUKKAN KE DALAM MENU]
-- ============================================================
local syncToIcon = nil
local syncIconMap = {}
local leaders = {}

if UpdateLeaderStatus and startSyncRE then
	syncToIcon = Icon.new()
	syncToIcon:setLabel("SyncTo")

	table.insert(dropdownIcons, syncToIcon)

	local function rebuildSyncDropdown()
		for name, ic in pairs(syncIconMap) do
			pcall(function() ic:destroy() end)
		end
		syncIconMap = {}

		local subIcons = {}
		for name, data in pairs(leaders) do
			if data.player ~= player then
				local ic = Icon.new()
				ic:setLabel(string.format("%s (%d)", name, data.followerCount))
				ic:bindEvent("selected", function()
					ic:deselect()
					local targetPlayer = Players:FindFirstChild(name)
					if targetPlayer then
						startSyncRE:FireServer(targetPlayer, true)
					end
					if menuIcon then
						task.wait(0.05)
						menuIcon:deselect()
					end
				end)
				syncIconMap[name] = ic
				table.insert(subIcons, ic)
			end
		end

		if #subIcons > 0 then
			syncToIcon:setDropdown(subIcons)
		else
			syncToIcon:setDropdown({})
		end
	end

	UpdateLeaderStatus.OnClientEvent:Connect(function(targetPlayer, isLeader, followerCount)
		if not targetPlayer or not targetPlayer.Parent then return end
		local name = targetPlayer.Name
		if isLeader and followerCount > 0 then
			leaders[name] = { player = targetPlayer, followerCount = followerCount }
		else
			leaders[name] = nil
		end
		rebuildSyncDropdown()
	end)

	task.spawn(function()
		task.wait(2)
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= player and p.Character then
				local isLeader      = p.Character:GetAttribute("IsLeader")
				local followerCount = p.Character:GetAttribute("FollowerCount") or 0
				if isLeader and followerCount > 0 then
					leaders[p.Name] = { player = p, followerCount = followerCount }
				end
			end
		end
		rebuildSyncDropdown()
	end)

	Players.PlayerRemoving:Connect(function(leavingPlayer)
		if leaders[leavingPlayer.Name] then
			leaders[leavingPlayer.Name] = nil
			rebuildSyncDropdown()
		end
		if syncIconMap[leavingPlayer.Name] then
			pcall(function() syncIconMap[leavingPlayer.Name]:destroy() end)
			syncIconMap[leavingPlayer.Name] = nil
		end
	end)
else
	warn("[SyncTo] Remotes not found – SyncTo feature will not be added to menu.")
end

-- ============================================================
-- PASANG SEMUA KE DROPDOWN UTAMA
-- ============================================================
if menuIcon and #dropdownIcons > 0 then
	menuIcon:setDropdown(dropdownIcons)
end

-- ============================================================
-- INIT
-- ============================================================
task.wait(CONFIG.InitDelay)

for _, d in pairs(icons) do
	if d.frame then d.frame.Visible = false end
	d.isOpen = false
	d.icon:deselect()
end
if menuIcon    then menuIcon:deselect()    end
if freecamIcon then freecamIcon:deselect() end

task.wait(0.5)
isInitialized = true

-- ============================================================
-- CLEANUP LOCAL PLAYER
-- ============================================================
Players.PlayerRemoving:Connect(function(removingPlayer)
	if removingPlayer ~= player then return end

	for _, d in pairs(icons) do
		if d.icon then pcall(function() d.icon:destroy() end) end
	end
	if menuIcon    then pcall(function() menuIcon:destroy()    end) end
	if freecamIcon then pcall(function() freecamIcon:destroy() end) end
	if syncToIcon  then pcall(function() syncToIcon:destroy()  end) end

	for _, ic in pairs(syncIconMap) do
		pcall(function() ic:destroy() end)
	end

	icons = {} ; guis = {} ; dropdownIcons = {} ; syncIconMap = {} ; leaders = {}
end)