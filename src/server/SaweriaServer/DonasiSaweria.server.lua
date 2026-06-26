-- ========================================
-- DONATION SYSTEM (WITH DEBUG LOGS)
-- Put in ServerScriptService
-- ========================================

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SaweriaAPI = require(game:GetService("ServerStorage"):WaitForChild("Modules"):WaitForChild("SaweriaAPI"))

-- ========================================
-- CONFIG & DEBUG SETTINGS
-- ========================================
local DEBUG_ENABLED = false
local DEBUG_PREFIX = "[DonasiSaweria]"

local function debugPrint(...)
	if DEBUG_ENABLED then print(DEBUG_PREFIX, ...) end
end

local function debugWarn(...)
	if DEBUG_ENABLED then warn(DEBUG_PREFIX, ...) end
end

-- 🔴 FIX 1: Interval dinaikkan ke 15 detik untuk mencegah IP Server diblokir oleh API Saweria!
local CHECK_INTERVAL = 10 
local MAX_DONATIONS = 50

-- STATE
-- STATE
local processedIds = {}
local isFirstLoad = true
local allDonations = {}

local remoteEvent = ReplicatedStorage:FindFirstChild("DonationNotification")
if not remoteEvent then
	remoteEvent = Instance.new("RemoteEvent")
	remoteEvent.Name = "DonationNotification"
	remoteEvent.Parent = ReplicatedStorage
end

debugPrint("✅ Donation system initialized")

-- ========================================
-- FORMAT RUPIAH
-- ========================================
local function formatRupiah(amount)
	local str = tostring(math.floor(amount))
	local result = ""
	local count = 0
	for i = #str, 1, -1 do
		if count == 3 then
			result = "." .. result
			count = 0
		end
		result = str:sub(i, i) .. result
		count = count + 1
	end
	return "Rp " .. result
end

-- ========================================
-- GET TOP DONATORS
-- ========================================
local function getTopDonators(limit)
	local donorTotals = {}
	for _, donation in ipairs(allDonations) do
		local donatorName = tostring(donation.donator or donation.nama or donation.Nama or "Unknown")
		local amt = tonumber(donation.amount) or tonumber(donation.jumlah) or tonumber(donation.Jumlah) or 0
		donorTotals[donatorName] = (donorTotals[donatorName] or 0) + amt
	end

	local topList = {}
	for name, total in pairs(donorTotals) do
		table.insert(topList, {name = name, total = total})
	end
	table.sort(topList, function(a, b) return a.total > b.total end)

	local result = {}
	for i = 1, math.min(limit, #topList) do
		table.insert(result, topList[i])
	end
	return result
end

-- ========================================
-- UPDATE BOARD GUI
-- ========================================
local function updateBoard()
	local boardModel = workspace:FindFirstChild("BoardSaweria")
	if not boardModel then return end
	local boardPart = boardModel:FindFirstChild("BoardSaweria")
	if not boardPart then return end
	local surfaceGui = boardPart:FindFirstChild("SurfaceGui")
	if not surfaceGui then return end
	local listLabel = surfaceGui:FindFirstChild("List")
	if not listLabel then return end

	local topDonators = getTopDonators(10)
	local displayText = "🏆 TOP 10 DONATOR 🏆\n\n"

	if #topDonators == 0 then
		displayText = displayText .. "Belum ada donasi"
	else
		for i, donor in ipairs(topDonators) do
			displayText = displayText .. tostring(i) .. ". " .. donor.name .. "\n"
			displayText = displayText .. formatRupiah(donor.total) .. "\n\n"
		end
	end
	listLabel.Text = displayText
end

-- ============================================================
-- ID-BASED QUEUE READER (FIXED UNTUK GOOGLE SHEETS)
-- ============================================================
local function fetchDonationData()
	local donationArray = SaweriaAPI:GetDonationData()
	if type(donationArray) ~= "table" then return end

	if isFirstLoad then
		-- Load awal: masukkan semua data tanpa memicu notifikasi
		for i, donation in ipairs(donationArray) do
			local currentId = donation.id or donation.Id or (tostring(donation.tanggal or donation.Tanggal or i) .. "_" .. tostring(donation.nama or donation.Nama))
			processedIds[currentId] = true
			table.insert(allDonations, donation)
		end

		while #allDonations > MAX_DONATIONS do 
			table.remove(allDonations, 1) 
		end

		pcall(updateBoard)
		isFirstLoad = false
		return
	end

	local broadcastQueue = {}
	local hasNewData = false

	for i, currentDonation in ipairs(donationArray) do
		-- Kombinasi ID agar unik meskipun kolom Id kosong
		local currentId = currentDonation.id or currentDonation.Id or (tostring(currentDonation.tanggal or currentDonation.Tanggal or i) .. "_" .. tostring(currentDonation.nama or currentDonation.Nama))

		if not processedIds[currentId] then
			processedIds[currentId] = true
			hasNewData = true
			table.insert(allDonations, currentDonation)
			table.insert(broadcastQueue, currentDonation)
		end
	end

	if hasNewData then
		while #allDonations > MAX_DONATIONS do 
			table.remove(allDonations, 1) 
		end

		pcall(updateBoard)

		-- Broadcast secara sekuensial dengan jeda
		for _, currentDonation in ipairs(broadcastQueue) do

			local rawDonator = tostring(currentDonation.donator or currentDonation.nama or currentDonation.Nama or "Unknown")
			local rawAmount = tostring(currentDonation.amount or currentDonation.jumlah or currentDonation.Jumlah or "0")
			local rawMessage = tostring(currentDonation.message or currentDonation.pesan or currentDonation.Pesan or "")

			local totalAmount = 0
			for _, donation in ipairs(donationArray) do
				local dName = tostring(donation.donator or donation.nama or donation.Nama or "Unknown")
				if dName == rawDonator then
					local amt = tonumber(donation.amount) or tonumber(donation.jumlah) or tonumber(donation.Jumlah) or 0
					totalAmount = totalAmount + amt
				end
			end

			local notifData = {
				donator = rawDonator,
				amount = rawAmount,
				total = totalAmount,
				message = rawMessage,
				timestamp = os.time()
			}

			if remoteEvent then remoteEvent:FireAllClients(notifData) end
			debugPrint("🚀 Mengirim notifikasi: " .. notifData.donator)

			local cleanAmount = rawAmount:gsub("%D", "") 
			local rpAmount = tonumber(cleanAmount) or 0

			local ServerStorage = game:GetService("ServerStorage")
			local SaweriaEffectEvent = ServerStorage:FindFirstChild("SaweriaEffectEvent")
			if not SaweriaEffectEvent then
				SaweriaEffectEvent = Instance.new("BindableEvent")
				SaweriaEffectEvent.Name = "SaweriaEffectEvent"
				SaweriaEffectEvent.Parent = ServerStorage
			end
			SaweriaEffectEvent:Fire(rawDonator, rpAmount)

			task.wait(2.5) 
		end
	end
end

-- ========================================
-- MAIN LOOP
-- ========================================
debugPrint("✅ SAWERIA DONATION SYSTEM STARTED")
updateBoard()

-- 🔴 FIX 3: Loop utama tidak lagi menggunakan logika tumpang tindih. Jauh lebih hemat CPU Server!
while true do
	task.wait(CHECK_INTERVAL)
	-- 🔥 ARCHITECT FIX: Bungkus dalam Thread agar Jaringan tidak Deadlock jika API lambat
	task.spawn(function()
		pcall(fetchDonationData)
	end)
end