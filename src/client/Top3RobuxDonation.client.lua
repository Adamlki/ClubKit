local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CONFIG = {
	Animations = {
		Top1 = "rbxassetid://114463328960354",
		Top2 = "rbxassetid://114463328960354",
		Top3 = "rbxassetid://114463328960354",
	},
	PosNames = { [1] = "Robux_Pos1", [2] = "Robux_Pos2", [3] = "Robux_Pos3" },
	RankColors = {
		[1] = Color3.fromRGB(255, 215, 0), -- Emas
		[2] = Color3.fromRGB(192, 192, 192), -- Perak
		[3] = Color3.fromRGB(205, 127, 50), -- Coklat
	}
}

local activeStatues = {}
local isRendering = false

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
	return formatted
end

-- MENGGUNAKAN TEMPLATE DARI REPLICATED STORAGE
local function createInfoGui(parent, rank, name, amount)
	local template = ReplicatedStorage:FindFirstChild("TamplateTopDonation")
	if not template then warn("BillboardGui tidak ditemukan di ReplicatedStorage!") return end

	local bgui = template:Clone()
	bgui.Enabled = true -- Pastikan menyala

	local frame = bgui:FindFirstChild("MainFrame")
	if frame then
		local namaLabel = frame:FindFirstChild("PlayerName")
		local valueLabel = frame:FindFirstChild("Value")

		if namaLabel then
			namaLabel.Text = "#" .. rank .. " " .. name
			namaLabel.TextColor3 = CONFIG.RankColors[rank] or Color3.fromRGB(255, 255, 255)
		end

		if valueLabel then
			valueLabel.Text = formatMoney(amount) .. " Robux"
			-- Warnanya dibiarkan mengikuti settingan asli di template Anda
		end
	end

	bgui.Parent = parent
end

local function renderStatue(rank, data)
	if activeStatues[rank] then activeStatues[rank]:Destroy() end

	local posFolder = workspace:FindFirstChild("DonatorPositions")
	local posPart = posFolder and posFolder:FindFirstChild(CONFIG.PosNames[rank])
	if not posPart then return end

	local userId = data.userId or data.UserId or data.id or 1
	local name = data.name or data.DisplayName or data.Name or data.nama or "Unknown"
	local amount = data.amount or data.Amount or data.jumlah or 0

	task.spawn(function()
		if userId == 1 and name ~= "Unknown" then
			pcall(function() userId = Players:GetUserIdFromNameAsync(name) end)
		end

		local success, model = pcall(function() return Players:CreateHumanoidModelFromUserId(userId) end)
		if success and model then
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			if humanoid then
				-- Sembunyikan nama asli bawaan Roblox agar tidak dobel dengan BillboardGui
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

-- 🔥 ARCHITECT FIX: THE CURTAIN DROP (SINKRONISASI MUTLAK)
local function onUpdate(top3Data)
	if isRendering then return end
	isRendering = true

	-- 1. Bersihkan patung yang lama
	for _, statue in pairs(activeStatues) do
		if statue then statue:Destroy() end
	end
	table.clear(activeStatues)

	local pendingModels = {}
	local loadedCount = 0

	-- Hitung jumlah donatur yang valid (bisa jadi cuma 1 atau 2 orang)
	local expectedCount = 0
	for rank = 1, 3 do if top3Data[rank] then expectedCount += 1 end end

	if expectedCount == 0 then
		isRendering = false
		return
	end

	local posFolder = workspace:FindFirstChild("DonatorPositions")

	-- 2. Rakit avatar di belakang layar (Memory)
	for rank, data in pairs(top3Data) do
		task.spawn(function()
			local userId = data.userId or data.UserId or data.id or 1
			local name = data.name or data.DisplayName or data.Name or data.nama or "Unknown"
			local amount = data.amount or data.Amount or data.jumlah or 0

			local posPart = posFolder and posFolder:FindFirstChild(CONFIG.PosNames[rank])

			if posPart then
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

					pcall(function() createInfoGui(model:WaitForChild("Head"), rank, name, amount) end)

					-- 🔥 SIMPAN KE MEMORI DULU (BELAKANG PANGGUNG)
					pendingModels[rank] = { Model = model, Humanoid = humanoid, AnimId = CONFIG.Animations["Top"..rank] }
				end
			end
			loadedCount += 1
		end)
	end

	-- 3. THE BARRIER: Tunggu maksimal 10 detik sampai semua avatar selesai didownload
	local timeout = tick() + 10
	while loadedCount < expectedCount and tick() < timeout do 
		task.wait(0.1) 
	end

	-- 4. THE CURTAIN DROP: Muncul Bareng & Samakan Hentakan!
	local universalStartTime = workspace:GetServerTimeNow()
	for rank, data in pairs(pendingModels) do
		local model, humanoid = data.Model, data.Humanoid

		-- Munculkan di waktu yang bersamaan
		model.Parent = workspace
		activeStatues[rank] = model

		local animator = humanoid and (humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid))
		if animator then
			local anim = Instance.new("Animation")
			anim.AnimationId = data.AnimId
			local track = animator:LoadAnimation(anim)
			track.Looped = true
			track:Play(0.5)

			-- Otoritas Matematika Absolut (Sama seperti Hive Mind!)
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

	isRendering = false
end

ReplicatedStorage:WaitForChild("UpdateTopBoard").OnClientEvent:Connect(onUpdate)