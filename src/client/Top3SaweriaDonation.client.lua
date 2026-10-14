local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CONFIG = {
	Animations = {
		Top1 = "rbxassetid://109979406375718",
		Top2 = "rbxassetid://109979406375718",
		Top3 = "rbxassetid://109979406375718",
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

local function onUpdate(rawData)
	local top3Data = (type(rawData) == "table" and rawData.AllTime) and rawData.AllTime or rawData
	if not top3Data then return end

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

	local function findPosPart(rank)
		local targetName = CONFIG.PosNames[rank]
		-- 1. Cari di DonatorPositions (langsung atau rekursif)
		local folder = workspace:FindFirstChild("DonatorPositions") or workspace:FindFirstChild("DonatorPositions", true)
		if folder then
			local p = folder:FindFirstChild(targetName) or folder:FindFirstChild(targetName, true)
			if p and p:IsA("BasePart") then return p end
			for _, alt in ipairs({"Saweria_Pos" .. rank, "SaweriaPos" .. rank, "Saweria_" .. rank, "Saweria" .. rank, "Pos_Saweria" .. rank, "SaweriaTop" .. rank, "Top" .. rank .. "_Saweria"}) do
				local altPart = folder:FindFirstChild(alt, true)
				if altPart and altPart:IsA("BasePart") then return altPart end
			end
		end

		-- 2. Cari di seluruh workspace jika folder belum/tidak ada
		local p = workspace:FindFirstChild(targetName, true)
		if p and p:IsA("BasePart") then return p end
		for _, alt in ipairs({"Saweria_Pos" .. rank, "SaweriaPos" .. rank, "Saweria_" .. rank, "Saweria" .. rank, "Pos_Saweria" .. rank, "SaweriaTop" .. rank, "Top" .. rank .. "_Saweria"}) do
			local altPart = workspace:FindFirstChild(alt, true)
			if altPart and altPart:IsA("BasePart") then return altPart end
		end
		return nil
	end

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

	-- 2. Rakit avatar baru dengan Jeda Bertingkat (Staggered Delay: 1.5 detik per patung)
	task.spawn(function()
		local universalStartTime = workspace:GetServerTimeNow()
		for rank = 1, 3 do
			if currentRenderVersion ~= myRenderVersion then return end
			local data = top3Data[rank]
			if data and not activeStatues[rank] then
				local userId = data.resolvedUserId
				local name = data.name or data.DisplayName or data.Name or data.nama or data.donator or "Unknown"
				local amount = data.amount or data.Amount or data.jumlah or 0
				
				local posPart = findPosPart(rank)
				if not posPart then
					-- Jika part belum streaming in (StreamingEnabled), tunggu sebentar
					local waitLimit = os.clock() + 5
					while not posPart and os.clock() < waitLimit do
						task.wait(0.5)
						posPart = findPosPart(rank)
					end
				end

				if posPart then
					local success, model = pcall(function() return Players:CreateHumanoidModelFromUserId(userId) end)
					if not success or not model then
						-- Fallback ke default avatar jika userId bukan akun Roblox asli
						pcall(function() model = Players:CreateHumanoidModelFromUserId(1) end)
					end

					if currentRenderVersion ~= myRenderVersion then
						if model then model:Destroy() end
						return
					end

					if model then
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

						pcall(function() createInfoGui(model:WaitForChild("Head", 5), rank, name, amount) end)

						local existing = workspace:FindFirstChild("Saweria_Donator_" .. rank)
						if existing and existing ~= model then
							destroyStatue(existing)
						end

						model.Name = "Saweria_Donator_" .. rank
						model.Parent = workspace
						activeStatues[rank] = model
						activeUserIds[rank] = userId

						local animator = humanoid and (humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid))
						if animator then
							local anim = Instance.new("Animation")
							anim.AnimationId = CONFIG.Animations["Top"..rank]
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

				-- Staggered delay 1.5 detik antar patung agar download mesh/texture tidak bersamaan
				task.wait(1.5)
			end
		end
	end)
end

local updateSaweriaEvent = ReplicatedStorage:WaitForChild("UpdateSaweriaTopBoard", 15)
if updateSaweriaEvent then
	updateSaweriaEvent.OnClientEvent:Connect(onUpdate)
	-- Minta data awal langsung ke server saat client aktif
	task.spawn(function()
		task.wait(1)
		updateSaweriaEvent:FireServer()
		-- Polling retry jika server masih loading Google Sheets
		for i = 1, 4 do
			task.wait(5)
			local hasStatue = false
			for _ in pairs(activeStatues) do hasStatue = true break end
			if not hasStatue then
				updateSaweriaEvent:FireServer()
			else
				break
			end
		end
	end)
end