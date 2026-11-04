local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local remotefolder = ReplicatedStorage:WaitForChild("Remotes")
local refreshEvent = remotefolder:FindFirstChild("RefreshCharacterEvent")

if not refreshEvent then
	refreshEvent = Instance.new("RemoteEvent")
	refreshEvent.Name = "RefreshCharacterEvent"
	refreshEvent.Parent = remotefolder
end

-- CONFIG
local COOLDOWN_TIME = 8
local MAX_WAIT_TIME = 6
local MAX_CONCURRENT_REFRESH = 10

-- STATE
local playerCooldowns = {}
local activeRefreshes = {}
local queue = {}
local activeWorkers = 0

-- HELPER: WAIT CLOTHING READY
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

local function cleanupSavedBillboards(savedBillboards)
	for _, data in ipairs(savedBillboards) do
		if data.obj and not data.obj.Parent then
			pcall(function() data.obj:Destroy() end)
		end
	end
	table.clear(savedBillboards)
end

-- CORE REFRESH FUNCTION
local function processPlayer(player)
	local character = player.Character
	if not character then return end
	
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	
	if not humanoid or not rootPart then return end
	
	-- Jangan refresh saat karakter di-carry atau efek global aktif.
	local carryable = character:FindFirstChild("Carryable")
	if (carryable and carryable.Value == false)
		or player:GetAttribute("GlobalEffectAirborne")
		or character:GetAttribute("GlobalEffectAirborne")
		or character:GetAttribute("GlobalEffectActive") then
		return
	end
	
	local currentCFrame = rootPart.CFrame

	local equippedTool = character:FindFirstChildOfClass("Tool")
	if equippedTool then
		humanoid:UnequipTools()
	end

	local success, description = pcall(function()
		return Players:GetHumanoidDescriptionFromUserId(player.UserId)
	end)

	if not success or not description then return end

	if not humanoid or not humanoid.Parent or humanoid.Health <= 0 then return end

	local head = character:FindFirstChild("Head")
	local savedBillboards = {}
	
	if head then
		for _, child in ipairs(head:GetChildren()) do
			if child:IsA("BillboardGui") and child.Name ~= "OverheadGui" and child.Name ~= "PlayerOverhead" then
				table.insert(savedBillboards, {
					name = child.Name,
					obj = child:Clone()
				})
			end
		end
	end
	
	-- Bekukan karakter sementara.
	local origSpeed = humanoid.WalkSpeed
	local origJump = humanoid.UseJumpPower and humanoid.JumpPower or humanoid.JumpHeight
	
	humanoid.WalkSpeed = 0
	if humanoid.UseJumpPower then
		humanoid.JumpPower = 0
	else
		humanoid.JumpHeight = 0
	end
	
	-- Failsafe agar karakter tidak stuck jika proses gagal.
	task.delay(10, function()
		if humanoid and humanoid.Parent and humanoid.Health > 0 and humanoid.WalkSpeed == 0 then
			humanoid.WalkSpeed = origSpeed
			if humanoid.UseJumpPower then humanoid.JumpPower = origJump else humanoid.JumpHeight = origJump end
		end
	end)
	
	-- Hapus pakaian lama.
	for _, item in ipairs(character:GetChildren()) do
		if item:IsA("Accessory") or item:IsA("Clothing") or item:IsA("BodyColors") or item:IsA("ShirtGraphic") then
			item:Destroy()
		end
	end

	task.wait(0.2)

	-- Terapkan ulang deskripsi.
	local applySuccess = pcall(function()
		humanoid:ApplyDescriptionReset(description)
	end)
	
	if not applySuccess then 
		humanoid.WalkSpeed = origSpeed
		if humanoid.UseJumpPower then humanoid.JumpPower = origJump else humanoid.JumpHeight = origJump end
		cleanupSavedBillboards(savedBillboards)
		return 
	end
	
	task.wait(0.5)
	
	-- Pastikan karakter masih valid setelah yield.
	if not humanoid or humanoid.Parent == nil or humanoid.Health <= 0 then
		cleanupSavedBillboards(savedBillboards)
		return
	end

	pcall(function()
		humanoid:ApplyDescription(description)
	end)

	waitForClothing(character)

	task.wait(1)

	if not humanoid or humanoid.Parent == nil or humanoid.Health <= 0 then
		cleanupSavedBillboards(savedBillboards)
		return
	end

	pcall(function()
		humanoid:BuildRigFromAttachments()
	end)

	-- Reset fisika aksesori.
	for _, v in ipairs(character:GetChildren()) do
		if v:IsA("Accessory") then
			local handle = v:FindFirstChild("Handle")
			if handle then
				handle.Anchored = true
				task.wait()
				if handle and handle.Parent then
					handle.Anchored = false
				end
			end
		end
	end
	
	if rootPart and rootPart.Parent then
		rootPart.CFrame = currentCFrame
	end

	if humanoid and humanoid.Parent then
		humanoid.WalkSpeed = origSpeed
		if humanoid.UseJumpPower then
			humanoid.JumpPower = origJump
		else
			humanoid.JumpHeight = origJump
		end
	end
	
	-- Kembalikan billboard.
	local newHead = character:FindFirstChild("Head")
	if newHead then
		for _, data in ipairs(savedBillboards) do
			local existing = newHead:FindFirstChild(data.name)
			if existing then existing:Destroy() end
			
			if data.obj then
				data.obj.Adornee = newHead
				data.obj.Parent = newHead
			end
		end
	else
		cleanupSavedBillboards(savedBillboards)
	end
	
	if equippedTool and player.Parent and equippedTool.Parent == player.Backpack and humanoid and humanoid.Parent then
		humanoid:EquipTool(equippedTool)
	end

	-- Pulihkan state dance/sync.
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

-- PARALLEL WORKER POOL SYSTEM
local function processQueue()
	while activeWorkers < MAX_CONCURRENT_REFRESH and #queue > 0 do
		local player = table.remove(queue, 1)
		if player and player.Parent and not activeRefreshes[player.UserId] then
			activeWorkers += 1
			activeRefreshes[player.UserId] = true
			task.spawn(function()
				pcall(processPlayer, player)
				activeRefreshes[player.UserId] = nil
				activeWorkers -= 1
				if #queue > 0 then
					processQueue()
				end
			end)
		end
	end
end

-- EVENT HANDLER
refreshEvent.OnServerEvent:Connect(function(player)
	if activeRefreshes[player.UserId] then return end
	local last = playerCooldowns[player.UserId]
	
	if last and (os.clock() - last) < COOLDOWN_TIME then
		return
	end
	
	playerCooldowns[player.UserId] = os.clock()
	
	for _, queuedPlr in ipairs(queue) do
		if queuedPlr == player then return end
	end
	table.insert(queue, player)
	
	processQueue()
end)

-- CLEANUP
Players.PlayerRemoving:Connect(function(player)
	playerCooldowns[player.UserId] = nil
	activeRefreshes[player.UserId] = nil
	for i = #queue, 1, -1 do
		if queue[i] == player then
			table.remove(queue, i)
		end
	end
end)
