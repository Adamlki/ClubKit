local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local remotefolder = ReplicatedStorage:WaitForChild("Remotes")
local refreshEvent = remotefolder:FindFirstChild("RefreshCharacterEvent")

if not refreshEvent then
	refreshEvent = Instance.new("RemoteEvent")
	refreshEvent.Name = "RefreshCharacterEvent"
	refreshEvent.Parent = remotefolder
end

-- ================================
-- 🔥 CONFIG
-- ================================
local COOLDOWN_TIME = 8
local MAX_WAIT_TIME = 6

-- ================================
-- 🔥 STATE
-- ================================
local playerCooldowns = {}
local queue = {}
local isProcessing = false

-- ================================
-- 🔥 HELPER: WAIT CLOTHING READY
-- ================================
local function waitForClothing(character)
	local t = 0
	
	while t < MAX_WAIT_TIME do
		task.wait(0.2)
		t += 0.2
		
		if not character or not character.Parent then return end
		
		local ready = true
		
		for _, v in ipairs(character:GetChildren()) do
			if v:IsA("Accessory") then
				local handle = v:FindFirstChild("Handle")
				if handle and #handle:GetChildren() == 0 then
					ready = false
					break
				end
			end
		end
		
		if ready then break end
	end
end

-- ================================
-- 🔥 CORE REFRESH FUNCTION
-- ================================
local function processPlayer(player)
	local character = player.Character
	if not character then return end
	
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	
	if not humanoid or not rootPart then return end
	
	-- ❌ BLOCK kondisi tertentu
	local carryable = character:FindFirstChild("Carryable")
	if (carryable and carryable.Value == false) or character:GetAttribute("GlobalEffectAirborne") then
		return
	end
	
	-- simpan posisi
	local currentCFrame = rootPart.CFrame
	
	-- simpan tool
	local equippedTool = character:FindFirstChildOfClass("Tool")
	if equippedTool then
		humanoid:UnequipTools()
	end
	
	-- ambil description
	local success, description = pcall(function()
		return Players:GetHumanoidDescriptionFromUserId(player.UserId)
	end)
	
	if not success or not description then return end
	
	-- safety check
	if humanoid.Health <= 0 then return end
	
	-- simpan billboard
	local head = character:FindFirstChild("Head")
	local savedBillboards = {}
	
	if head then
		for _, child in ipairs(head:GetChildren()) do
			if child:IsA("BillboardGui") and child.Name ~= "OverheadGui" then
				table.insert(savedBillboards, {
					name = child.Name,
					obj = child:Clone()
				})
			end
		end
	end
	
	-- 🔥 1. FREEZE KARAKTER SEMENTARA
	-- Simpan kecepatan asli
	local origSpeed = humanoid.WalkSpeed
	local origJump = humanoid.UseJumpPower and humanoid.JumpPower or humanoid.JumpHeight
	
	humanoid.WalkSpeed = 0
	if humanoid.UseJumpPower then
		humanoid.JumpPower = 0
	else
		humanoid.JumpHeight = 0
	end
	
	-- 🛡️ FAILSAFE ANTI STUCK: Garansi 100% pasti bisa jalan lagi apapun yang terjadi
	task.delay(10, function()
		if humanoid and humanoid.Parent and humanoid.Health > 0 and humanoid.WalkSpeed == 0 then
			humanoid.WalkSpeed = origSpeed
			if humanoid.UseJumpPower then humanoid.JumpPower = origJump else humanoid.JumpHeight = origJump end
		end
	end)
	
	-- 🔥 REMOVE OLD CLOTHING
	for _, item in ipairs(character:GetChildren()) do
		if item:IsA("Accessory") or item:IsA("Clothing") or item:IsA("BodyColors") or item:IsA("ShirtGraphic") then
			item:Destroy()
		end
	end
	
	task.wait(0.2) -- kasih napas engine
	
	-- 🔥 2. OPTIONAL (PALING KUAT) — RE-APPLY 2x
	local applySuccess = pcall(function()
		humanoid:ApplyDescriptionReset(description)
	end)
	
	if not applySuccess then 
		-- Restore speed if failed
		humanoid.WalkSpeed = origSpeed
		if humanoid.UseJumpPower then humanoid.JumpPower = origJump else humanoid.JumpHeight = origJump end
		return 
	end
	
	task.wait(0.5)
	
	-- Safety check setelah yield
	if not humanoid or humanoid.Parent == nil or humanoid.Health <= 0 then return end
	
	pcall(function()
		humanoid:ApplyDescription(description) -- Double apply fix
	end)
	
	-- 🔥 WAIT SAMPAI BENERAN KE-LOAD
	waitForClothing(character)
	
	-- 🔥 3. TAMBAH DELAY FINAL (PENTING BANGET)
	task.wait(1)
	
	-- Safety check setelah yield lama
	if not humanoid or humanoid.Parent == nil or humanoid.Health <= 0 then return end
	
	-- 🔥 4. PAKSA REBUILD RIG (Pro Fix)
	pcall(function()
		humanoid:BuildRigFromAttachments()
	end)
	
	-- 🔥 5. FORCE “RELOAD” ACCESSORY (Trigger Physics Ulang)
	for _, v in ipairs(character:GetChildren()) do
		if v:IsA("Accessory") then
			local handle = v:FindFirstChild("Handle")
			if handle then
				handle.Anchored = true
				task.wait()
				handle.Anchored = false
			end
		end
	end
	
	-- 🔥 BALIKIN POSISI
	if rootPart and rootPart.Parent then
		rootPart.CFrame = currentCFrame
	end
	
	-- 🔥 UNFREEZE KARAKTER
	humanoid.WalkSpeed = origSpeed
	if humanoid.UseJumpPower then
		humanoid.JumpPower = origJump
	else
		humanoid.JumpHeight = origJump
	end
	
	-- 🔥 RESTORE BILLBOARD
	local newHead = character:FindFirstChild("Head")
	if newHead then
		for _, data in ipairs(savedBillboards) do
			local existing = newHead:FindFirstChild(data.name)
			if existing then existing:Destroy() end
			
			local clone = data.obj:Clone()
			clone.Adornee = newHead
			clone.Parent = newHead
		end
	end
	
	-- 🔥 EQUIP TOOL BALIK
	if equippedTool and equippedTool.Parent == player.Backpack then
		humanoid:EquipTool(equippedTool)
	end
	
	-- 🔥 TRIGGER SYNC FIX
	local currentDance = character:GetAttribute("CurrentDanceID")
	local syncingTo = character:GetAttribute("Syncing")

	if currentDance and currentDance ~= "" then
		character:SetAttribute("CurrentDanceID", nil)
		task.delay(0.1, function()
			if character and character.Parent then
				character:SetAttribute("CurrentDanceID", currentDance)
			end
		end)
	elseif syncingTo and syncingTo ~= "" then
		task.delay(0.1, function()
			if character and character.Parent then
				local syncNotificationRE = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("SyncNotification")
				if syncNotificationRE then
					syncNotificationRE:FireClient(player, "sync_success", syncingTo)
				end
			end
		end)
	end
	
	character:SetAttribute("RefreshTrigger", os.clock())
end

-- ================================
-- 🔥 QUEUE SYSTEM
-- ================================
local function processQueue()
	if isProcessing then return end
	isProcessing = true
	
	while #queue > 0 do
		local player = table.remove(queue, 1)
		
		if player and player.Parent then
			processPlayer(player)
			
			-- 🔥 DELAY ANTAR PLAYER (ANTI LAG)
			task.wait(0.5)
		end
	end
	
	isProcessing = false
end

-- ================================
-- 🔥 EVENT HANDLER
-- ================================
refreshEvent.OnServerEvent:Connect(function(player)
	local last = playerCooldowns[player.UserId]
	
	if last and (os.clock() - last) < COOLDOWN_TIME then
		return
	end
	
	playerCooldowns[player.UserId] = os.clock()
	
	-- masukin ke queue
	table.insert(queue, player)
	
	-- jalankan queue
	task.spawn(processQueue)
end)

-- ================================
-- 🔥 CLEANUP
-- ================================
Players.PlayerRemoving:Connect(function(player)
	playerCooldowns[player.UserId] = nil
	-- Cleanup antrian
	for i = #queue, 1, -1 do
		if queue[i] == player then
			table.remove(queue, i)
		end
	end
end)