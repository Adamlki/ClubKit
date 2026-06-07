-- ========================================
-- SAWERIA SERVER LOGIC (ENTERPRISE OPTIMIZED)
-- ========================================

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local SaweriaAPI = require(game:GetService("ServerStorage"):WaitForChild("Modules"):WaitForChild("SaweriaAPI"))

local GetTopSaweriaFunc = ServerStorage:FindFirstChild("GetTopSaweriaFunc") or Instance.new("BindableFunction")
GetTopSaweriaFunc.Name = "GetTopSaweriaFunc"
GetTopSaweriaFunc.Parent = ServerStorage

local UpdateSaweriaEvent = ReplicatedStorage:FindFirstChild("UpdateSaweriaTopBoard") or Instance.new("RemoteEvent")
UpdateSaweriaEvent.Name = "UpdateSaweriaTopBoard"
UpdateSaweriaEvent.Parent = ReplicatedStorage

local UPDATE_INTERVAL = 60
local TOP_COUNT = 10
local CACHE_TIME = 5

local cachedDonations = nil
local cacheExpiry = 0

-- 🟡 FIX: CACHE SYSTEM LIMITER (Cegah Memory Leak 24/7)
local userIdCache = {} 
local cacheCount = 0
local MAX_CACHE_LIMIT = 50 -- Jangan simpan lebih dari 50 nama donatur di RAM!

local Saweria = workspace:WaitForChild("Saweria", 10)
if not Saweria then return end

local BoardSaweria = Saweria:WaitForChild("BoardSaweria", 5)
local LeaderboardGui = BoardSaweria and BoardSaweria:WaitForChild("LeaderboardGui", 5)
local MainFrameLB = LeaderboardGui and LeaderboardGui:WaitForChild("MainFrame", 5)
local ScrollFrame = MainFrameLB and MainFrameLB:WaitForChild("ScrollFrame", 5)
local EntryTemplate = ScrollFrame and ScrollFrame:FindFirstChild("EntryTemplate")

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

local function aggregateDonations(donations)
	local totals = {}
	for _, d in ipairs(donations) do
		local name = d.donator or d.nama or d.Nama or "Anonymous"
		local rawAmt = tostring(d.amount or d.jumlah or d.Jumlah or "0")
		local cleanAmt = rawAmt:gsub("%D", "") 
		local amt = tonumber(cleanAmt) or 0
		totals[name] = (totals[name] or 0) + amt
	end

	local sorted = {}
	for name, total in pairs(totals) do table.insert(sorted, {name = name, total = total}) end
	table.sort(sorted, function(a, b) return a.total > b.total end)
	return sorted
end

GetTopSaweriaFunc.OnInvoke = function()
	local donations = getDonations()
	if donations and #donations > 0 then return aggregateDonations(donations) end
	return {}
end

local function updateUIs()
	local donations = getDonations()
	local topDonators = #donations > 0 and aggregateDonations(donations) or {}

	if MainFrameLB and ScrollFrame then
		local noDataLB = MainFrameLB:FindFirstChild("NoDataLabel")
		if not noDataLB then
			noDataLB = Instance.new("TextLabel")
			noDataLB.Name = "NoDataLabel"
			noDataLB.Size = UDim2.new(1, 0, 1, -80)
			noDataLB.Position = UDim2.new(0, 0, 0, 80)
			noDataLB.BackgroundTransparency = 1
			noDataLB.Text = "Belum Ada Donasi"
			noDataLB.Font = Enum.Font.GothamBold
			noDataLB.TextSize = 28
			noDataLB.TextColor3 = Color3.fromRGB(150, 150, 150)
			noDataLB.Parent = MainFrameLB
		end

		if #topDonators == 0 then
			ScrollFrame.Visible = false
			noDataLB.Visible = true
		else
			ScrollFrame.Visible = true
			noDataLB.Visible = false

			if EntryTemplate then
				local displayCount = math.min(TOP_COUNT, #topDonators)

				for i = 1, displayCount do
					local donator = topDonators[i]
					local entryName = "Entry_" .. i
					local entry = ScrollFrame:FindFirstChild(entryName)

					if not entry then
						entry = EntryTemplate:Clone()
						entry.Name = entryName
						entry.Parent = ScrollFrame
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

				for _, child in ipairs(ScrollFrame:GetChildren()) do
					if child:IsA("Frame") and child.Name:match("Entry_") then
						local num = tonumber(child.Name:match("%d+"))
						if num > displayCount then child.Visible = false end
					end
				end

				local listLayout = ScrollFrame:FindFirstChildOfClass("UIListLayout")
				if listLayout then ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 20) end
			end
		end
	end

	-- 2. SIAPKAN DATA UNTUK CLIENT 3D DENGAN CACHE API
	local top3ClientData = {}
	for rank = 1, 3 do
		local donator = topDonators[rank]
		if donator then
			local userId = 1 
			local dName = donator.name or "Unknown"
			local dAmount = donator.total or 0 

			if userIdCache[dName] then
				userId = userIdCache[dName]
			else
				local success, foundId = pcall(function() 
					return Players:GetUserIdFromNameAsync(dName) 
				end)

				-- 🟡 FIX: Flush memory kalau sudah mau penuh
				if cacheCount >= MAX_CACHE_LIMIT then
					userIdCache = {}
					cacheCount = 0
				end

				if success and foundId then
					userId = foundId
					userIdCache[dName] = userId
					cacheCount += 1
				else
					userIdCache[dName] = 1
					cacheCount += 1
				end
			end

			top3ClientData[rank] = { 
				UserId = userId, 
				DisplayName = dName, 
				Amount = dAmount 
			}
		end
	end

	UpdateSaweriaEvent:FireAllClients(top3ClientData)
end

task.spawn(updateUIs)
while true do
	task.wait(UPDATE_INTERVAL)
	pcall(updateUIs)
end