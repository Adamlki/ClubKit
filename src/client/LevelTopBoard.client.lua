local Players            = game:GetService("Players")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")

-- ====================================
-- CONFIGURATION
-- ====================================
local CONFIG = {
	Top1AnimationId    = "rbxassetid://78286661104382",
	Top1AnimationSpeed = 1.0,

	CamOffsetY  = 1.2,
	CamOffsetZ  = 5,
	ViewportFOV = 70,
	CastShadow  = false,

	RankColors = {
		[1] = Color3.fromRGB(255, 215, 0),
		[2] = Color3.fromRGB(192, 192, 192),
		[3] = Color3.fromRGB(205, 127, 50),
	},
}

-- ====================================
-- REFERENSI
-- ====================================
local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Board = workspace:WaitForChild("EldetoLevelBoard", 30)
if not Board then warn("[LevelBoard] EldetoLevelBoard tidak ditemukan!") return end

local Gui            = Board:WaitForChild("EldetoLevelBoard",5)
local mainFrame      = Gui:WaitForChild("Mainframe",5)
local container      = mainFrame:WaitForChild("Container",5)
local scrollingFrame = container:WaitForChild("ScrollingFrame",5)
local templateFrame  = scrollingFrame:WaitForChild("TemplateFrame",5)
templateFrame.Visible = false

local topboard = Board:WaitForChild("EldetoTop1")

-- ====================================
-- STATE & CACHE MANAGER
-- ====================================
local clonedRows    = {}
local descCache     = {}
local nameCache     = {} -- 🔥 ARCHITECT FIX: Cache Nama untuk cegah API Throttling
local currentTop1Id = nil
local currentSg     = nil

-- ====================================
-- UTILITY (DENGAN CACHING)
-- ====================================
local function getPlayerName(userId)
	if nameCache[userId] then return nameCache[userId] end

	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)

	if ok and name then
		nameCache[userId] = name
		return name
	end
	return "Player_" .. tostring(userId)
end

-- ====================================
-- CLONE SURFACEGUI KE PLAYERGUI
-- ====================================
local function createSurfaceGui()
	if currentSg and currentSg.Parent then
		currentSg:Destroy()
		currentSg = nil
	end

	local originalSg = topboard:FindFirstChildOfClass("SurfaceGui")
	if not originalSg then
		warn("[LevelBoard] SurfaceGui tidak ditemukan di EldetoTop1")
		return nil
	end

	local newSg = Instance.new("SurfaceGui")
	newSg.Name           = "LevelBoard_Top1"
	newSg.Adornee        = topboard
	newSg.Face           = originalSg.Face
	newSg.SizingMode     = originalSg.SizingMode
	newSg.PixelsPerStud  = originalSg.PixelsPerStud
	newSg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	newSg.ResetOnSpawn   = false
	newSg.Enabled        = true
	newSg.Parent         = playerGui

	currentSg = newSg
	return newSg
end

-- ====================================
-- AMBIL DESCRIPTION (SANGAT RINGAN)
-- ====================================
local function getCachedDescription(userId)
	if descCache[userId] then return descCache[userId] end

	local description = nil
	local ok, desc = pcall(function()
		return Players:GetHumanoidDescriptionFromUserId(userId)
	end)

	if ok and desc then
		description = desc
		descCache[userId] = description
	else
		warn("[LevelBoard] GetHumanoidDescription gagal untuk userId:", userId)
	end

	-- 🔥 ARCHITECT FIX: GetCharacterAppearanceAsync dihapus untuk cegah Frame Freeze

	return description
end

-- ====================================
-- BUILD KARAKTER (OPTIMIZED PHYSICS)
-- ====================================
local function buildCharacter(description)
	if not description then return nil end

	-- 🔥 ARCHITECT FIX: Force R15
	local ok, char = pcall(function()
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	if not ok or not char then return nil end

	for _, obj in ipairs(char:GetChildren()) do
		if obj:IsA("LocalScript") or obj:IsA("Script") then obj:Destroy() end
	end

	local head = char:FindFirstChild("Head")
	if head then
		for _, obj in ipairs(head:GetChildren()) do
			if obj:IsA("BillboardGui") or obj:IsA("SurfaceGui") then obj:Destroy() end
		end
	end

	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.DisplayDistanceType   = Enum.HumanoidDisplayDistanceType.None
		hum.HealthDisplayType     = Enum.HumanoidHealthDisplayType.AlwaysOff
		hum.NameDisplayDistance   = 0
		hum.HealthDisplayDistance = 0

		-- 🔥 ARCHITECT FIX: Matikan Heavy States
		local states = {
			Enum.HumanoidStateType.Swimming,
			Enum.HumanoidStateType.Climbing,
			Enum.HumanoidStateType.FallingDown,
			Enum.HumanoidStateType.Ragdoll,
			Enum.HumanoidStateType.Physics
		}
		for _, state in ipairs(states) do
			pcall(function() hum:SetStateEnabled(state, false) end)
		end
	end

	if not CONFIG.CastShadow then
		for _, part in ipairs(char:GetDescendants()) do
			if part:IsA("BasePart") then part.CastShadow = false end
		end
	end

	return char
end

-- ====================================
-- SETUP VIEWPORT
-- ====================================
local function setupViewport(viewport, char)
	viewport:ClearAllChildren()

	local wm = Instance.new("WorldModel")
	wm.Parent = viewport
	char.Parent = wm

	local hrp = char:FindFirstChild("HumanoidRootPart")
	if hrp then char:PivotTo(CFrame.new(Vector3.zero) * CFrame.Angles(0, math.pi, 0)) end

	local cam = Instance.new("Camera")
	cam.CameraType  = Enum.CameraType.Scriptable
	cam.FieldOfView = CONFIG.ViewportFOV
	cam.CFrame = CFrame.lookAt(Vector3.new(0, CONFIG.CamOffsetY, CONFIG.CamOffsetZ), Vector3.new(0, CONFIG.CamOffsetY, 0))
	cam.Parent = viewport
	viewport.CurrentCamera = cam
	viewport.BackgroundTransparency = 1
	viewport.Visible = true

	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then
		local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
		task.wait()

		if CONFIG.Top1AnimationId and CONFIG.Top1AnimationId ~= "" then
			local anim = Instance.new("Animation")
			anim.AnimationId = CONFIG.Top1AnimationId

			local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
			if ok and track then
				track.Looped   = true
				track.Priority = Enum.AnimationPriority.Action
				track:Play()
				track:AdjustSpeed(CONFIG.Top1AnimationSpeed)
			end
		end
	end
end

-- ====================================
-- RENDER TOP 1 (DELTA CHECK)
-- ====================================
local function renderTop1(entry)
	if currentTop1Id == entry.userId and currentSg then
		local ui = currentSg:FindFirstChild("Top1_UI")
		local header = ui and ui:FindFirstChild("Container") and ui.Container:FindFirstChild("Header")
		if header and header:FindFirstChild("LevelLabel") then 
			header.LevelLabel.Text = "Lv. " .. tostring(entry.level) 
		end
		return 
	end

	currentTop1Id = entry.userId
	local sg = createSurfaceGui()
	if not sg then return end

	local originalSg = topboard:FindFirstChildOfClass("SurfaceGui")
	local templateTop = originalSg and originalSg:FindFirstChild("TemplateTopPlayer")
	if not templateTop then return end

	local ui = templateTop:Clone()
	ui.Name    = "Top1_UI"
	ui.Visible = true
	ui.Size    = UDim2.new(1, 0, 1, 0)
	ui.Parent  = sg

	local uiContainer = ui:FindFirstChild("Container")
	local header      = uiContainer and uiContainer:FindFirstChild("Header")
	local viewport    = uiContainer and uiContainer:FindFirstChildWhichIsA("ViewportFrame", true)

	if header then
		local rankLabel   = header:FindFirstChild("RankLabel")
		local nameLabel   = header:FindFirstChild("NameLabel")
		local levelLabel  = header:FindFirstChild("LevelLabel")

		if rankLabel  then rankLabel.Text  = "#1" end
		if levelLabel then levelLabel.Text = "Lv. " .. tostring(entry.level) end
		if nameLabel  then
			nameLabel.Text = getPlayerName(entry.userId) -- Sinkron berkat nama yang di-cache
		end
	end

	if not viewport then return end

	task.spawn(function()
		local description = getCachedDescription(entry.userId)
		if not description then return end

		local char = buildCharacter(description)
		if not char then return end

		if not viewport or not viewport.Parent then
			char:Destroy()
			return
		end
		setupViewport(viewport, char)
	end)
end

-- ====================================
-- RENDER SCROLLING LEADERBOARD (OBJECT POOLING)
-- ====================================
local function renderRows(topData)
	-- 🔥 ARCHITECT FIX: UI Recycling (Object Pooling)
	-- Jangan pernah Destroy & Clone UI secara massal. Daur ulang baris yang ada!

	for i, entry in ipairs(topData) do
		local row = clonedRows[i]

		-- Buat baris baru HANYA jika kurang
		if not row then
			row = templateFrame:Clone()
			row.Parent = scrollingFrame
			clonedRows[i] = row
		end

		row.Visible     = true
		row.Name        = "Row_" .. tostring(entry.rank)
		row.LayoutOrder = entry.rank

		local rankLabel   = row:FindFirstChild("RankLabel")
		local playerLabel = row:FindFirstChild("PlayerLabel")
		local levelLabel  = row:FindFirstChild("LevelLabel")

		if rankLabel then
			rankLabel.Text = "#" .. tostring(entry.rank)
			rankLabel.TextColor3 = CONFIG.RankColors[entry.rank] or Color3.fromRGB(255, 255, 255)
		end
		if levelLabel  then levelLabel.Text  = "Lv. " .. tostring(entry.level) end
		if playerLabel then
			-- Eksekusi instan berkat caching
			task.spawn(function()
				local name = getPlayerName(entry.userId)
				if playerLabel.Parent then playerLabel.Text = name end
			end)
		end
	end

	-- Sembunyikan sisa baris yang tidak terpakai (jika data turun dari 50 ke 10 misalnya)
	for i = #topData + 1, #clonedRows do
		clonedRows[i].Visible = false
	end
end

-- ====================================
-- MAIN
-- ====================================
local function onDataReceived(topData)
	if not topData or #topData == 0 then return end
	renderRows(topData)
	if topData[1] then
		renderTop1(topData[1])
	end
end

local remote = ReplicatedStorage:WaitForChild("UpdateLevelBoard", 30)
if not remote then
	warn("[LevelBoard] RemoteEvent 'UpdateLevelBoard' tidak ditemukan!")
	return
end

remote.OnClientEvent:Connect(onDataReceived)

print("[LevelBoard Client] Enterprise Architecture Ready!")