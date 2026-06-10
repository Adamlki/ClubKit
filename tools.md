local PolicyService = game:GetService("PolicyService")
local TextService = game:GetService("TextService")
local tool = script.Parent

-- RATE LIMITER CACHE
local lastUpdated = {}
local COOLDOWN = 5 -- Pemain hanya bisa update teks setiap 1.5 detik

local function updateSign(player, msg)
	-- KEAMANAN 1: Pastikan tool benar-benar dipegang
	if not player.Character or tool.Parent ~= player.Character then return end

	-- KEAMANAN 2: Batasi panjang karakter mencegah overload (misal max 50)
	if string.len(msg) > 50 then return end

	-- KEAMANAN 3: Rate Limiter (Anti-Spam)
	local now = os.clock()
	if lastUpdated[player.UserId] and (now - lastUpdated[player.UserId]) < COOLDOWN then
		return -- Abaikan spam
	end
	lastUpdated[player.UserId] = now

	-- LANGKAH 1: Cek Kebijakan
	local successPolicy, result = pcall(function()
		return PolicyService:GetPolicyInfoForPlayerAsync(player)
	end)

	if successPolicy and result.IsContentSharingAllowed then
		-- LANGKAH 2: Filtering Teks
		local filteredText = ""
		local successFilter, err = pcall(function()
			local filterResult = TextService:FilterStringAsync(msg, player.UserId)
			filteredText = filterResult:GetNonChatStringForBroadcastAsync()
		end)

		if successFilter then
			-- Pastikan part masih ada setelah Async yield
			if tool:FindFirstChild("SignPart") and tool.SignPart:FindFirstChild("SurfaceGui") then
				tool.SignPart.SurfaceGui.TextLabel.Text = filteredText
			end
		else
			warn("[AFK System] Filter gagal: " .. tostring(err))
		end
	end
end

tool.UpdateSign.OnServerEvent:Connect(updateSign)

-- Bersihkan cache saat pemain keluar
game.Players.PlayerRemoving:Connect(function(player)
	lastUpdated[player.UserId] = nil
end)


-- =====================================================================
-- AFK ANIMATION & IK CONTROLLER (AAA STANDARD)
-- Architecture: Decoupled, Zero-Memory Leak, Absolute Priority
-- =====================================================================

local tool = script.Parent
local animation = Instance.new("Animation")
animation.AnimationId = "rbxassetid://90423173984170"

-- Cache Variables
local animationTrack = nil
local ikInstanceR = nil

-- ============================================
-- 1. FUNGSI IK (Dideklarasikan di Atas)
-- ============================================
local function setupIK(character)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rightHand = character:FindFirstChild("RightHand")
	local rightUpperArm = character:FindFirstChild("RightUpperArm")

	if humanoid and rightHand and rightUpperArm and character:FindFirstChild("Animator") then
		-- Buat IKControl baru jika belum ada
		ikInstanceR = Instance.new("IKControl")
		ikInstanceR.Name = "HandLock_R"
		ikInstanceR.Parent = character:FindFirstChildOfClass("Animator")
		ikInstanceR.Type = Enum.IKControlType.Position -- Kunci posisinya saja

		-- Set anggota tubuh yang akan dikunci (tangan kanan)
		ikInstanceR.EndEffector = rightHand
		ikInstanceR.ChainRoot = rightUpperArm -- Bagian pangkal yang boleh gerak (bahu)

		-- Buat part target untuk IK (diam di tempat)
		local targetPart = Instance.new("Part")
		targetPart.Name = "IKTarget_R"
		targetPart.Transparency = 1 -- Tidak terlihat
		targetPart.Size = Vector3.new(0.1, 0.1, 0.1)
		targetPart.CanCollide = false
		targetPart.Anchored = false -- Harus nempel di bahu agar ikut gerak badan
		targetPart.Parent = rightUpperArm -- Tempelkan ke bahu

		-- Atur posisi target relatif terhadap bahu
		local attachment = Instance.new("Attachment")
		attachment.Parent = targetPart
		local weld = Instance.new("WeldConstraint")
		weld.Parent = targetPart
		weld.Part0 = targetPart
		weld.Part1 = rightUpperArm

		-- Posisi target di depan bahu (sesuaikan jika perlu)
		targetPart.CFrame = rightUpperArm.CFrame * CFrame.new(0.5, -1.5, -0.5)

		ikInstanceR.Target = targetPart
		ikInstanceR.Smoothness = 0 -- Kaku, jangan halus gerakannya
		ikInstanceR.Enabled = true
	end
end

local function removeIK()
	if ikInstanceR then
		-- Bersihkan target part secara manual untuk mencegah memory leak
		if ikInstanceR.Target then
			ikInstanceR.Target:Destroy()
		end
		ikInstanceR:Destroy()
		ikInstanceR = nil
	end
end

-- ============================================
-- 2. EVENT CONNECTION (Dieksekusi di Bawah)
-- ============================================
tool.Equipped:Connect(function()
	local character = tool.Parent
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")

	if animator then
		-- 🔥 ZERO MEMORY LEAK: Load animasi hanya 1x sepanjang sesi
		if not animationTrack then
			animationTrack = animator:LoadAnimation(animation)
			animationTrack.Priority = Enum.AnimationPriority.Action4
			animationTrack.Looped = true
		end

		-- 🔥 ABSOLUTE AUTHORITY: Paksa weight 1 dan waktu transisi 0
		animationTrack:Play(0, 1, 1)

		-- Setup IK (Linter sudah membaca fungsi ini dari atas)
		setupIK(character)
	end
end)

tool.Unequipped:Connect(function()
	-- Matikan animasi dengan aman
	if animationTrack then
		animationTrack:Stop()
	end

	-- Hapus IK (Linter sudah membaca fungsi ini dari atas)
	removeIK()
end)

local player = game.Players.LocalPlayer
local tool = script.Parent
local signGuiTemplate = tool:WaitForChild("SignGui")

-- 🔥 SISTEM FAILSAFE: Cek apakah Settings GUI melarang spawn
local function canShowGui()
	local settings = player.PlayerGui:FindFirstChild("SettingsGUI") -- Samakan dengan nama GUI Settingsmu
	if settings then
		local hideState = settings:FindFirstChild("HideGuiState", true)
		if hideState and hideState.Value == true then
			return false
		end
	end
	return true
end

tool.Equipped:Connect(function()
	if not canShowGui() then return end

	local gui = signGuiTemplate:Clone()
	gui.Name = "ActiveSignGui" -- Beri nama spesifik agar mudah dihapus
	gui.Parent = player.PlayerGui

	local createMsg = gui:WaitForChild("CreateMsg")
	local textBox = createMsg:WaitForChild("TextMsg")

	-- Initial State: AFK
	textBox.Text = "AFK"

	local updateEvent = tool:FindFirstChild("UpdateSign")
	if updateEvent then
		updateEvent:FireServer("AFK")
	end
end)

tool.Unequipped:Connect(function()
	local existingGui = player.PlayerGui:FindFirstChild("ActiveSignGui")
	if existingGui then
		existingGui:Destroy()
	end
end)


local player = game.Players.LocalPlayer
local createMsg = script.Parent:WaitForChild("CreateMsg")
local textBox = createMsg:WaitForChild("TextMsg")
local closeButton = createMsg:WaitForChild("CloseBtn")
local submitButton = createMsg:WaitForChild("SubmitBtn") -- 🔥 Referensi tombol baru Anda

-- ==========================================
-- FUNGSI MODULAR: Pengiriman Teks ke Server
-- ==========================================
local function submitText()
	if not createMsg.Visible then return end

	local character = player.Character
	if character then
		-- ARSITEKTUR DINAMIS: Cari Tool apa pun yang sedang dipegang
		local equippedTool = character:FindFirstChildOfClass("Tool")

		if equippedTool then
			local updateEvent = equippedTool:FindFirstChild("UpdateSign")
			if updateEvent then
				-- Kirim seluruh teks SECARA UTUH dalam satu kali request
				updateEvent:FireServer(textBox.Text)
			end
		end
	end
end

-- ==========================================
-- EVENT BINDINGS (CROSS-PLATFORM SUPPORT)
-- ==========================================

-- TRIGGER 1: Pemain mengklik/tap tombol Submit (Optimal untuk Mobile & PC)
submitButton.Activated:Connect(function()
	submitText()
end)

-- TRIGGER 2: Pemain menekan tombol "Enter" di Keyboard (Optimal untuk PC)
textBox.FocusLost:Connect(function(enterPressed)
	-- Hanya kirim jika pemain benar-benar menekan Enter, bukan sekadar klik di luar UI
	if enterPressed then
		submitText()
	end
end)

-- ==========================================
-- UI CONTROLS
-- ==========================================

-- Tombol Close (Menutup GUI)
closeButton.Activated:Connect(function()
	createMsg.Visible = false
end)

-- =====================================================================
-- GLOWSTICK SERVER CONTROLLER (AAA STANDARD)
-- Architecture: Server-Authoritative, Anti-Spam Rate Limiter, Zero Leak
-- =====================================================================

local Tool = script.Parent
local Remote = Tool:WaitForChild("GlowRemote")
local Players = game:GetService("Players")

local lastChar
local DEFAULT_COLOR = Color3.fromRGB(255,255,255)

-- 🔥 SECURITY: Rate Limiter Cache
local rateLimit = {}
local SERVER_COOLDOWN = 0.3

-- ===== UTILITIES =====
local function ensureTrail(stick)
	if not stick then return end
	local base = stick:FindFirstChild("Base") or Instance.new("Attachment", stick)
	base.Name = "Base"
	local tip  = stick:FindFirstChild("Tip")  or Instance.new("Attachment", stick)
	tip.Name = "Tip"

	local halfZ = (stick.Size and stick.Size.Z or 0.7) / 2
	base.Position = Vector3.new(0, 0, -halfZ)
	tip.Position  = Vector3.new(0, 0, halfZ)

	local tr = stick:FindFirstChildOfClass("Trail")
	if not tr then
		tr = Instance.new("Trail")
		tr.Name = "GlowTrail"
		tr.Attachment0, tr.Attachment1 = base, tip
		tr.MinLength = 0
		tr.Lifetime = 0.35
		tr.LightEmission = 1
		tr.Transparency = NumberSequence.new{
			NumberSequenceKeypoint.new(0,0),
			NumberSequenceKeypoint.new(1,0.85)
		}
		tr.Parent = stick
	end

	-- Gunakan warna part saat ini sebagai single source of truth
	tr.Color = ColorSequence.new(stick.Color) 
	tr.Enabled = true
	return tr
end

local function setStickLightsEnabled(stick, on)
	if not stick then return end
	for _, d in ipairs(stick:GetChildren()) do
		if d:IsA("Light") then d.Enabled = on end
	end
	local tr = stick:FindFirstChildOfClass("Trail")
	if tr then tr.Enabled = on end
end

local function destroyJointsInCharacter(char)
	if not char then return end
	for _, j in ipairs(char:GetDescendants()) do
		if j:IsA("Motor6D") and (j.Name == "RightGlowstickJoint" or j.Name == "LeftGlowstickJoint") then
			j:Destroy()
		end
	end
end

local function restoreSticksToTool()
	for _, name in ipairs({"RightStick","LeftStick"}) do
		local stick = Tool:FindFirstChild(name)
		if not stick and lastChar then stick = lastChar:FindFirstChild(name) end
		if stick then
			stick.Anchored = true
			stick.CanCollide = false
			stick.Parent = Tool
			setStickLightsEnabled(stick, false)
		end
	end
end

local function getHands(char)
	local isR15 = char:FindFirstChild("UpperTorso") ~= nil
	local rightHand = isR15 and (char:FindFirstChild("RightHand")) or (char:FindFirstChild("Right Arm"))
	local leftHand  = isR15 and (char:FindFirstChild("LeftHand"))  or (char:FindFirstChild("Left Arm"))
	return rightHand, leftHand, isR15
end

local function attachStick(stick, hand, isRight, isR15)
	if not (stick and hand) then return end
	stick.Massless = true
	stick.CanCollide = false
	stick.Anchored = false
	ensureTrail(stick)

	for _, j in ipairs(hand:GetChildren()) do
		if j:IsA("Motor6D") and (j.Name == "RightGlowstickJoint" or j.Name == "LeftGlowstickJoint") then
			j:Destroy()
		end
	end

	local joint = Instance.new("Motor6D")
	joint.Part0 = hand
	joint.Part1 = stick
	joint.Name = isRight and "RightGlowstickJoint" or "LeftGlowstickJoint"
	local yaw = isRight and math.rad(90) or math.rad(-90)

	if isR15 then
		joint.C0 = CFrame.new(0, -0.12, -0.20) * CFrame.Angles(0, yaw, 0)
	else
		joint.C0 = CFrame.new(0, -1.00, -0.20) * CFrame.Angles(0, yaw, 0)
	end
	joint.Parent = hand
end

-- ===== EQUIP / UNEQUIP LIFECYCLE =====
Tool.Equipped:Connect(function()
	local char = Tool.Parent
	if not char then return end
	lastChar = char

	restoreSticksToTool()

	local rightStick = Tool:FindFirstChild("RightStick")
	local leftStick  = Tool:FindFirstChild("LeftStick")
	if not (rightStick and leftStick) then return end

	local rightHand, leftHand, isR15 = getHands(char)
	if not (rightHand and leftHand) then return end

	attachStick(rightStick, rightHand, true, isR15)
	attachStick(leftStick, leftHand, false, isR15)

	setStickLightsEnabled(rightStick, true)
	setStickLightsEnabled(leftStick,  true)

	-- Garbage Collection saat pemain mati
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.Died:Once(function()
			destroyJointsInCharacter(char)
			restoreSticksToTool()
			lastChar = nil
		end)
	end
end)

Tool.Unequipped:Connect(function()
	destroyJointsInCharacter(lastChar)
	restoreSticksToTool()
	lastChar = nil
end)

-- ===== REMOTE EVENT ROUTER =====
Remote.OnServerEvent:Connect(function(player, action, payload)
	-- 🔥 RATE LIMITER: Cegah Hacker eksploitasi spam packet
	local now = os.clock()
	if rateLimit[player.UserId] and (now - rateLimit[player.UserId]) < SERVER_COOLDOWN then 
		return 
	end
	rateLimit[player.UserId] = now

	local rightStick = Tool:FindFirstChild("RightStick")
	local leftStick  = Tool:FindFirstChild("LeftStick")
	if not (rightStick and leftStick) then return end

	if action == "setColor" and typeof(payload) == "Color3" then
		for _, stick in ipairs({rightStick, leftStick}) do
			-- Update warna fisik part terlebih dahulu (Persistent State)
			stick.Color = payload 

			-- Update semua lampu
			for _, d in ipairs(stick:GetChildren()) do
				if d:IsA("Light") then
					d.Color = payload
				end
			end

			-- Update Trail
			local tr = stick:FindFirstChildOfClass("Trail")
			if tr then
				tr.Enabled = true
				tr.Color = ColorSequence.new(payload)
			end
		end

	elseif action == "toggleLights" then
		local sample = rightStick:FindFirstChildOfClass("PointLight")
		local nextOn = sample and (not sample.Enabled) or true
		setStickLightsEnabled(rightStick, nextOn)
		setStickLightsEnabled(leftStick,  nextOn)
	end
end)

-- Bersihkan cache memory saat pemain keluar
Players.PlayerRemoving:Connect(function(player)
	rateLimit[player.UserId] = nil
end)

-- Reset ke default saat spawn (Failsafe)
Tool.AncestryChanged:Connect(function(_, parent)
	if parent == workspace or parent == nil then
		for _, stick in ipairs({Tool:FindFirstChild("RightStick"), Tool:FindFirstChild("LeftStick")}) do
			if stick then
				stick.Color = DEFAULT_COLOR
				for _, d in ipairs(stick:GetChildren()) do
					if d:IsA("Light") then
						d.Color = DEFAULT_COLOR
					end
				end
				local tr = stick:FindFirstChildOfClass("Trail")
				if tr then
					tr.Color = ColorSequence.new(DEFAULT_COLOR)
					tr.Enabled = true
				end
			end
		end
	end
end)

-- =====================================================================
-- GLOWSTICK CLIENT CONTROLLER (AAA STANDARD)
-- Architecture: Cross-Platform Support, Modular, Zero Memory Leak
-- =====================================================================

local Tool = script.Parent
local Remote = Tool:WaitForChild("GlowRemote")
local ContextActionService = game:GetService("ContextActionService")

-- Palet Warna
local colorWheel = { 
	Color3.fromRGB(0, 255, 170), Color3.fromRGB(255, 0, 110),
	Color3.fromRGB(255, 170, 0), Color3.fromRGB(0, 170, 255),
	Color3.fromRGB(180, 0, 255), Color3.fromRGB(0, 255, 60)
}
local colorIndex = 1
local ACTION_NAME = "ChangeGlowColor"

-- ==========================================
-- INPUT HANDLER (CROSS-PLATFORM)
-- ==========================================
local function handleColorChange(actionName, inputState, inputObject)
	if actionName == ACTION_NAME and inputState == Enum.UserInputState.Begin then
		-- Putar index warna
		colorIndex = (colorIndex % #colorWheel) + 1

		-- Kirim sinyal ke server
		Remote:FireServer("setColor", colorWheel[colorIndex])
	end
end

-- ==========================================
-- EQUIP / UNEQUIP LIFECYCLE
-- ==========================================
Tool.Equipped:Connect(function()
	-- 🔥 PERBAIKAN: Parameter ke-3 diubah menjadi 'false' agar TIDAK memunculkan tombol di HP
	-- PC masih bisa menggunakan (R), dan Console menggunakan (Y)
	ContextActionService:BindAction(ACTION_NAME, handleColorChange, false, Enum.KeyCode.R, Enum.KeyCode.ButtonY)

	-- Nyala/mati lampu tetap dilakukan lewat klik layar / tap layar normal
	Tool.Activated:Connect(function()
		Remote:FireServer("toggleLights")
	end)
end)

Tool.Unequipped:Connect(function()
	-- 🔥 ZERO MEMORY LEAK: Hapus binding saat senjata dilepas
	ContextActionService:UnbindAction(ACTION_NAME)
end)


-- =========================================================
-- TOOL ANIMATION CONTROLLER
-- Pastikan ini berada di dalam "LocalScript" (bukan Script biasa)
-- =========================================================

local tool = script.Parent
local player = game.Players.LocalPlayer
local character = nil
local humanoid = nil
local animator = nil

-- Settings
local ANIMATION_ID = "rbxassetid://70491642909581" 
local COOLDOWN_TIME = 0.5 
local PLAY_ONLY_ONCE = false 

-- Variables
local lastClickTime = 0
local hasPlayedOnce = false
local animationTrack = nil

-- Function untuk load animation
local function loadAnimation()
	if animator and not animationTrack then
		local animation = Instance.new("Animation")
		animation.AnimationId = ANIMATION_ID
		animationTrack = animator:LoadAnimation(animation)

		-- Action4 sudah cukup kuat untuk menimpa emote bawaan 
		-- TANPA perlu mematikan emote tersebut secara paksa.
		animationTrack.Priority = Enum.AnimationPriority.Action4 
		animationTrack.Looped = false
	end
end

tool.Equipped:Connect(function()
	character = player.Character or player.CharacterAdded:Wait()
	humanoid = character:FindFirstChildOfClass("Humanoid")

	if humanoid then
		animator = humanoid:FindFirstChildOfClass("Animator")
		if not animator then
			animator = Instance.new("Animator")
			animator.Parent = humanoid
		end
		loadAnimation()
	end
end)

tool.Unequipped:Connect(function()
	if animationTrack then
		animationTrack:Stop(0.2)
	end
	character = nil
	humanoid = nil
	animator = nil
end)

tool.Activated:Connect(function()
	local currentTime = os.clock()
	if currentTime - lastClickTime < COOLDOWN_TIME then return end
	if PLAY_ONLY_ONCE and hasPlayedOnce then return end

	if animationTrack then
		-- Langsung Play. Jika Action4, dia akan otomatis tampil di atas emote bawaan.
		animationTrack:Play(0.1, 1, 1) 

		lastClickTime = currentTime
		hasPlayedOnce = true
	else
		warn("Animation track not loaded!")
	end
end)


-- =========================================================
-- TOOL ANIMATION CONTROLLER
-- Pastikan ini berada di dalam "LocalScript" (bukan Script biasa)
-- =========================================================

local tool = script.Parent
local player = game.Players.LocalPlayer
local character = nil
local humanoid = nil
local animator = nil

-- Settings
local ANIMATION_ID = "rbxassetid://70491642909581" 
local COOLDOWN_TIME = 0.5 
local PLAY_ONLY_ONCE = false 

-- Variables
local lastClickTime = 0
local hasPlayedOnce = false
local animationTrack = nil

-- Function untuk load animation
local function loadAnimation()
	if animator and not animationTrack then
		local animation = Instance.new("Animation")
		animation.AnimationId = ANIMATION_ID
		animationTrack = animator:LoadAnimation(animation)

		-- Action4 sudah cukup kuat untuk menimpa emote bawaan 
		-- TANPA perlu mematikan emote tersebut secara paksa.
		animationTrack.Priority = Enum.AnimationPriority.Action4 
		animationTrack.Looped = false
	end
end

tool.Equipped:Connect(function()
	character = player.Character or player.CharacterAdded:Wait()
	humanoid = character:FindFirstChildOfClass("Humanoid")

	if humanoid then
		animator = humanoid:FindFirstChildOfClass("Animator")
		if not animator then
			animator = Instance.new("Animator")
			animator.Parent = humanoid
		end
		loadAnimation()
	end
end)

tool.Unequipped:Connect(function()
	if animationTrack then
		animationTrack:Stop(0.2)
	end
	character = nil
	humanoid = nil
	animator = nil
end)

tool.Activated:Connect(function()
	local currentTime = os.clock()
	if currentTime - lastClickTime < COOLDOWN_TIME then return end
	if PLAY_ONLY_ONCE and hasPlayedOnce then return end

	if animationTrack then
		-- Langsung Play. Jika Action4, dia akan otomatis tampil di atas emote bawaan.
		animationTrack:Play(0.1, 1, 1) 

		lastClickTime = currentTime
		hasPlayedOnce = true
	else
		warn("Animation track not loaded!")
	end
end)


local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local tool = script.Parent
local localPlayer = Players.LocalPlayer

-- Konfigurasi
local ANIM_ID = "rbxassetid://81293983980231"
local BOOST_SPEED = 30
local NORMAL_SPEED = 16

-- Variabel State
local idleTrack = nil
local isEquipped = false

-- ==========================================
-- ANIMATION HANDLER (LOAD SEKALI SAJA)
-- ==========================================
local function playIdleAnimation(character)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)

	-- Mencegah memory leak dengan tidak meload ulang jika sudah ada
	if not idleTrack then
		local anim = Instance.new("Animation")
		anim.AnimationId = ANIM_ID
		idleTrack = animator:LoadAnimation(anim)
		idleTrack.Priority = Enum.AnimationPriority.Action4
		idleTrack.Looped = true
	end

	idleTrack:Play(0, 1, 1) -- Mengunci otoritas sendi penuh
end

local function stopIdleAnimation()
	if idleTrack and idleTrack.IsPlaying then
		idleTrack:Stop()
	end
end

-- ==========================================
-- MOVEMENT HANDLER (NATIVE & OPTIMIZED)
-- ==========================================
local function applySpeedBoost(character, isBoosting)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		-- Menggunakan WalkSpeed jauh lebih stabil dan ringan daripada BodyVelocity
		humanoid.WalkSpeed = isBoosting and BOOST_SPEED or NORMAL_SPEED
	end
end

-- ==========================================
-- EQUIP / UNEQUIP LIFECYCLE
-- ==========================================
tool.Equipped:Connect(function()
	isEquipped = true
	local character = localPlayer.Character or localPlayer.CharacterAdded:Wait()

	playIdleAnimation(character)
	applySpeedBoost(character, true)
end)

tool.Unequipped:Connect(function()
	isEquipped = false

	stopIdleAnimation()

	if localPlayer.Character then
		applySpeedBoost(localPlayer.Character, false)
	end
end)

-- =====================================================================
-- SERVER-SIDED IK REPLICATOR
-- Architecture: Natively Replicated, Client-Calculated, Zero-Leak
-- =====================================================================
local tool = script.Parent
local currentIK = nil

tool.Equipped:Connect(function()
	local char = tool.Parent
	local humanoid = char:FindFirstChildOfClass("Humanoid")
	local leftUpperArm = char:FindFirstChild("LeftUpperArm") 
	local leftHand = char:FindFirstChild("LeftHand")

	-- Cari LeftGrip yang merupakan target pegangan
	local targetGrip = tool:FindFirstChild("LeftGrip", true)

	if humanoid and leftUpperArm and leftHand and targetGrip then
		-- 🔥 ARCHITECT FIX: Dibuat di Server agar tereplikasi ke 100 pemain
		currentIK = Instance.new("IKControl")
		currentIK.Name = "WaterGunLeftHandIK"
		currentIK.Type = Enum.IKControlType.Position 
		currentIK.ChainRoot = leftUpperArm
		currentIK.EndEffector = leftHand
		currentIK.Target = targetGrip
		currentIK.Weight = 0.85 
		currentIK.SmoothTime = 0.15 

		-- Memasukkan IK ke dalam Humanoid secara otomatis akan membagikannya ke semua klien
		currentIK.Parent = humanoid
	end
end)

tool.Unequipped:Connect(function()
	-- 🔥 ZERO MEMORY LEAK: Hapus objek saat senjata dilepas
	if currentIK then
		currentIK:Destroy()
		currentIK = nil
	end
end)

-- =====================================================================
-- ⚙️ WEAPON CLIENT CONTROLLER (AAA ENTERPRISE STANDARD)
-- 🧑‍💻 Developer : Muhammad Adam Al Kidri (DIGITAL ADAM AL TECH)
-- 📐 Architecture: State-Driven, Decoupled, Zero Memory Leak
-- =====================================================================

local Players = game:GetService("Players")
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ==========================================
-- 1. DEPENDENCIES & GLOBAL NETWORK
-- ==========================================
local globalEvent = ReplicatedStorage:WaitForChild("GlobalWeaponEvent")
local localPlayer = Players.LocalPlayer

local tool = script.Parent
local handle = tool:WaitForChild("Handle")
local muzzlePart = tool:WaitForChild("MuzzlePart") -- Unique Identifier
local waterEmitter = muzzlePart:WaitForChild("Water")
local explosionSound = handle:WaitForChild("Explosion")
local animObjectHold = tool:WaitForChild("Pegang watergun")

-- ==========================================
-- 2. STATE MANAGEMENT (SINGLE SOURCE OF TRUTH)
-- ==========================================
local ClientState = {
	IsEquipped = false,
	IsFiring = false,
	HoldTrack = nil
}
local ACTION_NAME = "Fire_" .. tool.Name -- Dinamis untuk mencegah konflik antar-tool

-- ==========================================
-- 3. LOCAL VISUAL HANDLER (ZERO LATENCY)
-- ==========================================
local function toggleLocalVisuals(state)
	waterEmitter.Enabled = state
	if state then
		explosionSound:Play()
	else
		explosionSound:Stop()
	end
end

-- Inisialisasi awal (pastikan partikel mati)
toggleLocalVisuals(false)

-- ==========================================
-- 4. INPUT CONTROLLER (CROSS-PLATFORM)
-- ==========================================
local function handleFireInput(actionName, inputState, _inputObject)
	if actionName ~= ACTION_NAME or not ClientState.IsEquipped then return end

	if inputState == Enum.UserInputState.Begin then
		if not ClientState.IsFiring then
			ClientState.IsFiring = true

			-- Eksekusi visual lokal instan tanpa menunggu server
			toggleLocalVisuals(true)      

			-- Kirim Intent ke Server (Fire and Forget)
			globalEvent:FireServer(tool.Name, true)  
		end

	elseif inputState == Enum.UserInputState.End then
		if ClientState.IsFiring then
			ClientState.IsFiring = false

			-- Hentikan visual lokal
			toggleLocalVisuals(false)

			-- Beritahu Server untuk berhenti broadcast
			globalEvent:FireServer(tool.Name, false) 
		end
	end
end

-- ==========================================
-- 5. ANIMATION HANDLER (OPTIMIZED)
-- ==========================================
local function playHoldAnimation(character)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")

	if animator then
		-- O(1) Memory Allocation: Load hanya jika belum pernah di-load
		if not ClientState.HoldTrack then
			-- 🔥 ARCHITECT FIX: Kunci ID secara eksplisit di script
			animObjectHold.AnimationId = "rbxassetid://99319590573889"

			ClientState.HoldTrack = animator:LoadAnimation(animObjectHold)
			ClientState.HoldTrack.Priority = Enum.AnimationPriority.Action4 
		end
		-- Mengunci sendi dengan otoritas absolut
		ClientState.HoldTrack:Play(0, 1, 1) 
	end
end

-- 🔥 TAMBAHKAN FUNGSI INI KEMBALI
local function stopHoldAnimation()
	if ClientState.HoldTrack and ClientState.HoldTrack.IsPlaying then
		ClientState.HoldTrack:Stop()
	end
end

-- ==========================================
-- 6. LIFECYCLE HOOKS (EQUIP / UNEQUIP)
-- ==========================================
tool.Equipped:Connect(function()
	ClientState.IsEquipped = true
	local character = localPlayer.Character or localPlayer.CharacterAdded:Wait()

	-- 1. Jalankan Animasi
	playHoldAnimation(character)

	-- 2. Bind Input Action
	ContextActionService:BindAction(ACTION_NAME, handleFireInput, true, Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2)
	ContextActionService:SetTitle(ACTION_NAME, "SQUIRT!")
	ContextActionService:SetPosition(ACTION_NAME, UDim2.new(0.5, 0, 0.5, -50))

	-- 3. AAA UI Polish (Mobile Support)
	local fireButton = ContextActionService:GetButton(ACTION_NAME)
	if fireButton then
		fireButton.Size = UDim2.new(0, 50, 0, 50)
		fireButton.BackgroundColor3 = Color3.fromRGB(52, 152, 219)
		fireButton.BackgroundTransparency = 1

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = fireButton

		local buttonText = fireButton:FindFirstChild("ActionTitle")
		if buttonText and buttonText:IsA("TextLabel") then
			buttonText.Font = Enum.Font.GothamBlack
			buttonText.TextSize = 11
			buttonText.TextColor3 = Color3.fromRGB(255, 255, 255)
		end
	end
end)

tool.Unequipped:Connect(function()
	ClientState.IsEquipped = false

	-- 1. Bersihkan Input (Mencegah Memory Leak)
	ContextActionService:UnbindAction(ACTION_NAME)

	-- 2. Matikan Animasi dengan Aman
	stopHoldAnimation()

	-- 3. Failsafe: Reset state
	if ClientState.IsFiring then
		ClientState.IsFiring = false
		toggleLocalVisuals(false)
		globalEvent:FireServer(tool.Name, false)
	end
end)