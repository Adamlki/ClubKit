local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CONFIG = {
	Animations = {
		Top1 = "rbxassetid://140349022227594",
		Top2 = "rbxassetid://140349022227594",
		Top3 = "rbxassetid://140349022227594",
	},
	PosNames = { [1] = "Saweria_Pos1", [2] = "Saweria_Pos2", [3] = "Saweria_Pos3" },
	RankColors = {
		[1] = Color3.fromRGB(255, 215, 0), -- Emas
		[2] = Color3.fromRGB(192, 192, 192), -- Perak
		[3] = Color3.fromRGB(205, 127, 50), -- Coklat
	}
}

local activeStatues = {}
local activeUserIds = {}
local currentRenderVersion = 0

local function formatMoney(amount)
	local cleanStr = string.gsub(tostring(amount), "%D", "")
	if cleanStr == "" then cleanStr = "0" end
	local val = tonumber(cleanStr) or 0
	local formatted = tostring(math.floor(val))
	while true do
		local k
		formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1.%2')
		if (k==0) then break end
	end
	return "Rp " .. formatted
end

local function updateInfoGui(bgui, rank, name, amount)
	local frame = bgui:FindFirstChild("MainFrame")
	if frame then
		local namaLabel = frame:FindFirstChild("PlayerName")
		local valueLabel = frame:FindFirstChild("Value")

		if namaLabel then
			namaLabel.Text = "#" .. rank .. " " .. name
			namaLabel.TextColor3 = CONFIG.RankColors[rank] or Color3.fromRGB(255, 255, 255)
		end

		if valueLabel then
			valueLabel.Text = formatMoney(amount)
		end
	end
end

-- MENGGUNAKAN TEMPLATE DARI REPLICATED STORAGE
local function createInfoGui(parent, rank, name, amount)
	local template = ReplicatedStorage:FindFirstChild("TamplateTopDonation")
	if not template then warn("BillboardGui tidak ditemukan di ReplicatedStorage!") return nil end

	local bgui = template:Clone()
	bgui.Enabled = true
	updateInfoGui(bgui, rank, name, amount)
	bgui.Parent = parent
	return bgui
end

local function renderStatue(rank, data)
	if activeStatues[rank] then activeStatues[rank]:Destroy() end

	local posFolder = workspace:FindFirstChild("DonatorPositions")
	local posPart = posFolder and posFolder:FindFirstChild(CONFIG.PosNames[rank])
	if not posPart then return end

	local userId = data.userId or data.UserId or data.id or 1
	local name = data.name or data.DisplayName or data.Name or data.nama or data.donator or "Unknown"
	local amount = data.amount or data.Amount or data.jumlah or 0

	task.spawn(function()
		if userId == 1 and name ~= "Unknown" then
			pcall(function() userId = Players:GetUserIdFromNameAsync(name) end)
		end

		local success, model = pcall(function() return Players:CreateHumanoidModelFromUserId(userId) end)
		if success and model then
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None 
			end

			-- Optimasi Fisika (0% Lag)
			for _, p in ipairs(model:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide = false end end
			local hrp = model:FindFirstChild("HumanoidRootPart")
			if hrp then hrp.Anchored = true end

			-- 🔥 ARCHITECT FIX: Pasang PrimaryPart jika kosong!
			if hrp and not model.PrimaryPart then
				model.PrimaryPart = hrp
			end

			local hrpY = (hrp and hrp.Size.Y) or 2
			local hipH = (humanoid and humanoid.HipHeight) or 0
			local yOffset = (humanoid and humanoid.RigType == Enum.HumanoidRigType.R15) and (hipH + (hrpY / 2)) or 3

			-- Proteksi mutlak saat memindah posisi
			pcall(function()
				if model.PrimaryPart then
					model:PivotTo(posPart.CFrame * CFrame.new(0, yOffset, 0))
				else
					model:MoveTo((posPart.CFrame * CFrame.new(0, yOffset, 0)).Position)
				end
			end)

			createInfoGui(model:WaitForChild("Head"), rank, name, amount)

			model.Parent = workspace
			activeStatues[rank] = model

			local animator = humanoid and (humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid))
			if animator then
				local anim = Instance.new("Animation")
				anim.AnimationId = CONFIG.Animations["Top"..rank]
				local track = animator:LoadAnimation(anim)
				track.Looped = true
				track:Play()
				track.TimePosition = 0
			end
		end
	end)
end

local function destroyStatue(statue)
	if not statue then return end
	pcall(function()
		local animator = statue:FindFirstChildWhichIsA("Animator", true)
		if animator then
			for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
				track:Stop()
				track:Destroy()
			end
		end
		statue:Destroy()
	end)
end

local function onUpdate(top3Data)
	currentRenderVersion = currentRenderVersion + 1
	local myRenderVersion = currentRenderVersion

	local expectedCount = 0
	for rank = 1, 3 do if top3Data[rank] then expectedCount += 1 end end

	if expectedCount == 0 then
		for rank, statue in pairs(activeStatues) do destroyStatue(statue) end
		table.clear(activeStatues)
		table.clear(activeUserIds)
		return
	end

	local posFolder = workspace:FindFirstChild("DonatorPositions")
	local pendingModels = {}
	local loadedCount = 0

	-- 1. Evaluasi Cache
	for rank = 1, 3 do
		local data = top3Data[rank]
		if data then
			local userId = data.userId or data.UserId or data.id or 1
			local name = data.name or data.DisplayName or data.Name or data.nama or data.donator or "Unknown"
			local amount = data.amount or data.Amount or data.jumlah or 0

			if userId == 1 and name ~= "Unknown" then
				pcall(function() userId = Players:GetUserIdFromNameAsync(name) end)
			end
			data.resolvedUserId = userId

			if activeUserIds[rank] == userId and activeStatues[rank] then
				-- CACHE HIT! Orang yang sama, cuma update teks
				loadedCount += 1
				local head = activeStatues[rank]:FindFirstChild("Head")
				if head then
					local oldGui = head:FindFirstChildOfClass("BillboardGui")
					if oldGui then 
						-- 🔥 AAA FIX: Daur ulang UI yang sudah ada (Object Pooling)
						updateInfoGui(oldGui, rank, name, amount)
					else
						pcall(function() createInfoGui(head, rank, name, amount) end)
					end
				end
			else
				-- CACHE MISS! Orang beda, hancurkan yang lama
				if activeStatues[rank] then 
					destroyStatue(activeStatues[rank]) 
					activeStatues[rank] = nil 
				end
				activeUserIds[rank] = nil
			end
		else
			if activeStatues[rank] then 
				destroyStatue(activeStatues[rank]) 
				activeStatues[rank] = nil 
			end
			activeUserIds[rank] = nil
		end
	end

	-- 2. Rakit avatar baru di belakang layar (jika ada yang Cache Miss)
	for rank, data in pairs(top3Data) do
		if not activeStatues[rank] then
			task.spawn(function()
				local userId = data.resolvedUserId
				local name = data.name or data.DisplayName or data.Name or data.nama or data.donator or "Unknown"
				local amount = data.amount or data.Amount or data.jumlah or 0
				local posPart = posFolder and posFolder:FindFirstChild(CONFIG.PosNames[rank])

				if posPart then
					local success, model = pcall(function() return Players:CreateHumanoidModelFromUserId(userId) end)
					if success and model then
						local humanoid = model:FindFirstChildOfClass("Humanoid")
						if humanoid then humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None end

						-- Optimasi Fisika (0% Lag)
						for _, p in ipairs(model:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide = false end end
						local hrp = model:FindFirstChild("HumanoidRootPart")
						if hrp then hrp.Anchored = true end

						if hrp and not model.PrimaryPart then model.PrimaryPart = hrp end

						local hrpY = (hrp and hrp.Size.Y) or 2
						local hipH = (humanoid and humanoid.HipHeight) or 0
						local yOffset = (humanoid and humanoid.RigType == Enum.HumanoidRigType.R15) and (hipH + (hrpY / 2)) or 3

						pcall(function()
							if model.PrimaryPart then model:PivotTo(posPart.CFrame * CFrame.new(0, yOffset, 0))
							else model:MoveTo((posPart.CFrame * CFrame.new(0, yOffset, 0)).Position) end
						end)

						pcall(function() createInfoGui(model:WaitForChild("Head"), rank, name, amount) end)

						pendingModels[rank] = { Model = model, Humanoid = humanoid, AnimId = CONFIG.Animations["Top"..rank], UserId = userId }
					end
				end
				loadedCount += 1
			end)
		end
	end

	-- 3. THE BARRIER
	local timeout = tick() + 10
	while loadedCount < expectedCount and tick() < timeout do task.wait(0.1) end

	-- 🔥 CLIENT FIX: Jika ada update baru yang masuk saat loading (Data Loss), atau loading sangat lambat
	-- Hancurkan avatar yang baru saja jadi (Orphaned Object) agar tidak memicu Memory Leak!
	if currentRenderVersion ~= myRenderVersion then
		for _, data in pairs(pendingModels) do
			if data.Model then data.Model:Destroy() end
		end
		return
	end

	-- 4. THE CURTAIN DROP
	local universalStartTime = workspace:GetServerTimeNow()
	for rank, data in pairs(pendingModels) do
		local model, humanoid = data.Model, data.Humanoid
		model.Parent = workspace
		activeStatues[rank] = model
		activeUserIds[rank] = data.UserId

		local animator = humanoid and (humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid))
		if animator then
			local anim = Instance.new("Animation")
			anim.AnimationId = data.AnimId
			local track = animator:LoadAnimation(anim)
			track.Looped = true
			track:Play(0.5)

			task.spawn(function()
				local waitTimeout = tick() + 2
				while track.Length == 0 and tick() < waitTimeout do task.wait() end
				if track.Length > 0 then
					local elapsed = workspace:GetServerTimeNow() - universalStartTime
					track.TimePosition = elapsed % track.Length
				end
			end)
		end
	end
end

ReplicatedStorage:WaitForChild("UpdateSaweriaTopBoard").OnClientEvent:Connect(onUpdate)