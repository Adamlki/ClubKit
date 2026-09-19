-- ========================================
-- SAWERIA SERVER LOGIC (ENTERPRISE OPTIMIZED)
-- ========================================

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")
local SaweriaAPI = require(game:GetService("ServerStorage"):WaitForChild("Modules"):WaitForChild("SaweriaAPI"))

local IS_STUDIO = RunService:IsStudio()
local UPDATE_INTERVAL = IS_STUDIO and 15 or 60
local TOP_COUNT = 10

local GetTopSaweriaFunc = ServerStorage:FindFirstChild("GetTopSaweriaFunc") or Instance.new("BindableFunction")
GetTopSaweriaFunc.Name = "GetTopSaweriaFunc"
GetTopSaweriaFunc.Parent = ServerStorage

local UpdateSaweriaEvent = ReplicatedStorage:FindFirstChild("UpdateSaweriaTopBoard") or Instance.new("RemoteEvent")
UpdateSaweriaEvent.Name = "UpdateSaweriaTopBoard"
UpdateSaweriaEvent.Parent = ReplicatedStorage

-- 🟡 FIX: CACHE SYSTEM LIMITER (Cegah Memory Leak 24/7)
local userIdCache = {} 
local cacheCount = 0
local MAX_CACHE_LIMIT = 50

local function formatRupiah(amount)
	local formatted = tostring(math.floor(tonumber(amount) or 0))
	local k
	while true do  
		formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1.%2')
		if k == 0 then break end
	end
	return "Rp " .. formatted
end

local function getDonations()
	local data = SaweriaAPI:GetDonationData()
	return data or {}
end

local function aggregateDonations(donations, filterDate)
	local totals = {}
	for _, d in ipairs(donations) do
		local include = true
		if filterDate then
			local dDate = tostring(d.date or d.Date or d.tanggal or d.Tanggal or "")
			local dSub = dDate:sub(1, 10)
			if dSub ~= "" and dSub ~= filterDate then
				include = false
			end
		end
		if include then
			local name = d.donator or d.nama or d.Nama or "Anonymous"
			local rawAmt = tostring(d.amount or d.jumlah or d.Jumlah or "0")
			local cleanAmt = rawAmt:gsub("%D", "") 
			local amt = tonumber(cleanAmt) or 0
			totals[name] = (totals[name] or 0) + amt
		end
	end

	local sorted = {}
	for name, total in pairs(totals) do table.insert(sorted, {name = name, total = total}) end
	table.sort(sorted, function(a, b) return a.total > b.total end)
	return sorted
end

local cachedTopDonators = {}
local cachedSaweriaPayload = { AllTime = {}, Daily = {} }
local lastCacheUpdate = 0
local CACHE_DURATION = IS_STUDIO and 10 or 60

GetTopSaweriaFunc.OnInvoke = function()
	local now = os.time()
	if now - lastCacheUpdate < CACHE_DURATION and #cachedTopDonators > 0 then
		return cachedTopDonators
	end
	
	local donations = getDonations()
	if donations and #donations > 0 then 
		cachedTopDonators = aggregateDonations(donations)
		lastCacheUpdate = now
		return cachedTopDonators 
	end
	
	if #cachedTopDonators > 0 then return cachedTopDonators end
	return {}
end

-- ========================================
-- DYNAMIC BOARD FINDER (Mencari di Workspace)
-- ========================================
local function findBoardComponents()
	-- 1. Cari model/folder di Workspace / Workspace.Leaderboard
	local folder = workspace:FindFirstChild("Leaderboard")
	local root = (folder and (folder:FindFirstChild("BoardSaweria") or folder:FindFirstChild("Saweria")))
		or workspace:FindFirstChild("BoardSaweria")
		or workspace:FindFirstChild("Saweria")
		or workspace:FindFirstChild("BoardSaweria", true)
		or workspace:FindFirstChild("Saweria", true)

	if not root then
		return nil, nil, nil
	end

	-- 2. Cari GUI (bisa LeaderboardGui atau SurfaceGui)
	local gui = root:FindFirstChild("LeaderboardGui", true)
		or root:FindFirstChildWhichIsA("SurfaceGui", true)

	if not gui then
		return root, nil, nil
	end

	-- 3. Cari komponen internal
	local mainFrame = gui:FindFirstChild("MainFrame", true)
	local scrollFrame = gui:FindFirstChild("ScrollFrame", true) 
		or (mainFrame and mainFrame:FindFirstChild("ScrollFrame"))
	local entryTemplate = scrollFrame and (scrollFrame:FindFirstChild("EntryTemplate") or scrollFrame:FindFirstChild("Template"))
	local listLabel = gui:FindFirstChild("List", true)

	return root, gui, {
		MainFrame = mainFrame,
		ScrollFrame = scrollFrame,
		EntryTemplate = entryTemplate,
		ListLabel = listLabel
	}
end

local function updateUIs()
	local donations = getDonations()
	local topDonators = #donations > 0 and aggregateDonations(donations) or {}

	local root, gui, comp = findBoardComponents()
	if not root then
		if IS_STUDIO then
			warn("[TopSaweria] ⚠️ Model 'BoardSaweria' atau 'Saweria' belum ditemukan di Workspace!")
		end
	elseif not gui then
		if IS_STUDIO then
			warn("[TopSaweria] ⚠️ SurfaceGui / LeaderboardGui belum ditemukan di dalam " .. root:GetFullName())
		end
	else
		-- Render ke ScrollFrame jika ada
		if comp.ScrollFrame then
			local mainFrame = comp.MainFrame or comp.ScrollFrame.Parent
			local noDataLB = mainFrame and mainFrame:FindFirstChild("NoDataLabel")
			if not noDataLB and mainFrame then
				noDataLB = Instance.new("TextLabel")
				noDataLB.Name = "NoDataLabel"
				noDataLB.Size = UDim2.new(1, 0, 1, -80)
				noDataLB.Position = UDim2.new(0, 0, 0, 80)
				noDataLB.BackgroundTransparency = 1
				noDataLB.Text = "Belum Ada Donasi"
				noDataLB.Font = Enum.Font.GothamBold
				noDataLB.TextSize = 28
				noDataLB.TextColor3 = Color3.fromRGB(150, 150, 150)
				noDataLB.Parent = mainFrame
			end

			if #topDonators == 0 then
				comp.ScrollFrame.Visible = false
				if noDataLB then noDataLB.Visible = true end
			else
				comp.ScrollFrame.Visible = true
				if noDataLB then noDataLB.Visible = false end

				if comp.EntryTemplate then
					local displayCount = math.min(TOP_COUNT, #topDonators)

					for i = 1, displayCount do
						local donator = topDonators[i]
						local entryName = "Entry_" .. i
						local entry = comp.ScrollFrame:FindFirstChild(entryName)

						if not entry then
							entry = comp.EntryTemplate:Clone()
							entry.Name = entryName
							entry.Parent = comp.ScrollFrame
						end

						entry.LayoutOrder = i
						entry.Visible = true

						local rankLbl = entry:FindFirstChild("RankLabel", true)
						local nameLbl = entry:FindFirstChild("NameLabel", true)
						local amountLbl = entry:FindFirstChild("AmountLabel", true)

						if rankLbl then rankLbl.Text = "#" .. i end
						if nameLbl then nameLbl.Text = donator.name end
						if amountLbl then amountLbl.Text = formatRupiah(donator.total) end
					end

					for _, child in ipairs(comp.ScrollFrame:GetChildren()) do
						if child:IsA("Frame") and child.Name:match("Entry_") then
							local num = tonumber(child.Name:match("%d+"))
							if num and num > displayCount then child.Visible = false end
						end
					end

					local listLayout = comp.ScrollFrame:FindFirstChildOfClass("UIListLayout")
					if listLayout then comp.ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 20) end
				end
			end
		end

		-- Render ke ListLabel (format teks sederhana) jika ada
		if comp.ListLabel then
			local displayText = "🏆 TOP 10 DONATOR 🏆\n\n"
			if #topDonators == 0 then
				displayText = displayText .. "Belum ada donasi"
			else
				for i = 1, math.min(TOP_COUNT, #topDonators) do
					local donor = topDonators[i]
					displayText = displayText .. tostring(i) .. ". " .. donor.name .. "\n"
					displayText = displayText .. formatRupiah(donor.total) .. "\n\n"
				end
			end
			comp.ListLabel.Text = displayText
		end

		if IS_STUDIO and #topDonators > 0 then
			print(string.format("[TopSaweria] 🏆 Leaderboard berhasil diperbarui dengan %d donatur! Top 1: %s (%s)", #topDonators, topDonators[1].name, formatRupiah(topDonators[1].total)))
		end
	end

	-- 2. SIAPKAN DATA UNTUK CLIENT (ALL TIME & DAILY)
	local function resolveUserId(dName)
		if userIdCache[dName] then return userIdCache[dName] end
		local success, foundId = pcall(function() 
			return Players:GetUserIdFromNameAsync(dName) 
		end)
		if cacheCount >= MAX_CACHE_LIMIT then
			userIdCache = {}
			cacheCount = 0
		end
		if success and foundId then
			userIdCache[dName] = foundId
			cacheCount += 1
			return foundId
		else
			userIdCache[dName] = 1
			cacheCount += 1
			return 1
		end
	end

	local function buildList(sourceDonators, limit)
		local list = {}
		for rank = 1, math.min(limit, #sourceDonators) do
			local d = sourceDonators[rank]
			local dName = d.name or "Unknown"
			local uId = resolveUserId(dName)
			table.insert(list, {
				Rank = rank,
				UserId = uId,
				DisplayName = dName,
				Username = "@" .. dName:gsub("%s+", "_"),
				Amount = d.total or 0,
			})
		end
		return list
	end

	local todayUtc = os.date("!%Y-%m-%d")
	local todayLocal = os.date("%Y-%m-%d")
	local dailyDonators = aggregateDonations(donations, todayUtc)
	if #dailyDonators == 0 and todayLocal ~= todayUtc then
		dailyDonators = aggregateDonations(donations, todayLocal)
	end

	local allTimeClientData = buildList(topDonators, 50)
	local dailyClientData = buildList(dailyDonators, 50)

	cachedSaweriaPayload = {
		AllTime = allTimeClientData,
		Daily = dailyClientData,
	}

	UpdateSaweriaEvent:FireAllClients(cachedSaweriaPayload)
end

UpdateSaweriaEvent.OnServerEvent:Connect(function(plr)
	if cachedSaweriaPayload and (cachedSaweriaPayload.AllTime or #cachedSaweriaPayload > 0) then
		pcall(function()
			UpdateSaweriaEvent:FireClient(plr, cachedSaweriaPayload)
		end)
	end
end)

-- Eksekusi awal segera saat startup
task.spawn(function()
	task.wait(1) -- Beri waktu 1 detik agar workspace selesai di-load
	pcall(updateUIs)
end)

while true do
	task.wait(UPDATE_INTERVAL)
	pcall(updateUIs)
end