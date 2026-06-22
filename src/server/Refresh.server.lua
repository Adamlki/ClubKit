local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local remotefolder = ReplicatedStorage:WaitForChild("Remotes")
local refreshEvent = remotefolder:FindFirstChild("RefreshCharacterEvent")
if not refreshEvent then
	refreshEvent = Instance.new("RemoteEvent")
	refreshEvent.Name = "RefreshCharacterEvent"
	refreshEvent.Parent = remotefolder
end

-- ==========================================
-- SISTEM ANTI-SPAM & PENGAMAN SERVER
-- ==========================================
local playerCooldowns = {}
local COOLDOWN_TIME = 5 -- Player hanya bisa /re setiap 5 detik

local function onRefreshRequest(player)
	-- 1. CEK COOLDOWN
	local lastRefreshTime = playerCooldowns[player.UserId]
	if lastRefreshTime and (os.clock() - lastRefreshTime) < COOLDOWN_TIME then
		return 
	end

	playerCooldowns[player.UserId] = os.clock()

	local character = player.Character
	if not character then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not rootPart then return end

	-- 2. KUNCI POSISI & AMANKAN TOOL
	local currentCFrame = rootPart.CFrame

	-- 🔥 ARCHITECT FIX: Cek apakah ada Tool yang sedang dipegang
	local equippedTool = character:FindFirstChildOfClass("Tool")
	if equippedTool then
		-- Pindahkan Tool secara paksa ke Backpack agar aman dari proses ApplyDescription
		humanoid:UnequipTools()
	end

	local userId = player.UserId
	local success, description = pcall(function()
		return Players:GetHumanoidDescriptionFromUserId(userId)
	end)

	-- 🔥 FATAL CRASH FIX: Pastikan karakter dan part masih ada sesudah tertahan (Yield) oleh API Web
	if not player or not player.Parent or not character or not character.Parent then return end
	if not humanoid or not humanoid.Parent or not rootPart or not rootPart.Parent then return end

	if success and description then
		local head = character:FindFirstChild("Head")
		local savedBillboards = {}

		if head then
			for _, child in ipairs(head:GetChildren()) do
				if child:IsA("BillboardGui") and child.Name ~= "OverheadGui" then
					local clone = child:Clone()
					table.insert(savedBillboards, {
						name = child.Name,
						billboard = clone
					})
				end
			end
		end

		local applySuccess, err = pcall(function()
			humanoid:ApplyDescription(description)
		end)

		if applySuccess then
			-- KEMBALIKAN POSISI SECARA INSTAN
			rootPart.CFrame = currentCFrame

			-- Beri jeda sepersekian detik agar engine selesai merakit joint/rig baru
			task.wait(0.2)

			-- Restore Billboards
			local newHead = character:FindFirstChild("Head")
			if newHead then
				for _, data in ipairs(savedBillboards) do
					local existing = newHead:FindFirstChild(data.name)
					if existing then
						existing:Destroy()
					end

					local restored = data.billboard:Clone()
					restored.Adornee = newHead
					restored.Parent = newHead
				end
			end

			-- 🔥 ARCHITECT FIX: Kembalikan Tool ke tangan pemain secara otomatis
			if equippedTool and equippedTool.Parent == player.Backpack then
				humanoid:EquipTool(equippedTool)
			end
			
			-- BERITAHU SISTEM LAIN (GLOBAL EFFECT) BAHWA REFRESH SUDAH SELESAI
			character:SetAttribute("RefreshTrigger", os.clock())
		else
			warn("[Refresh System] Gagal ApplyDescription: " .. tostring(err))
		end
	end
end

refreshEvent.OnServerEvent:Connect(onRefreshRequest)

-- 3. BERSIHKAN MEMORY SAAT PLAYER KELUAR
Players.PlayerRemoving:Connect(function(player)
	playerCooldowns[player.UserId] = nil
end)