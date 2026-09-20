-- ========================================
-- DONATION SYSTEM (WITH DEBUG LOGS)
-- Put in ServerScriptService
-- ========================================

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SaweriaAPI = require(game:GetService("ServerStorage"):WaitForChild("Modules"):WaitForChild("SaweriaAPI"))
local SaweriaScreenBoardHandler = require(script.Parent:WaitForChild("SaweriaScreenBoardHandler"))

-- ========================================
-- CONFIG & DEBUG SETTINGS
-- ========================================
local IS_STUDIO = RunService:IsStudio()
local DEBUG_ENABLED = IS_STUDIO -- Otomatis aktif saat di Roblox Studio
local DEBUG_PREFIX = "[DonasiSaweria]"

local function debugPrint(...)
	if DEBUG_ENABLED then print(DEBUG_PREFIX, ...) end
end

local function debugWarn(...)
	if DEBUG_ENABLED then warn(DEBUG_PREFIX, ...) end
end

-- Di Studio cek setiap 15 detik agar tes cepat, di Live Server 30 detik
local CHECK_INTERVAL = IS_STUDIO and 15 or 30 
local MAX_DONATIONS = 50

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
-- GENERATE UNIQUE DONATION ID
-- ========================================
local function getDonationUniqueId(donation, index)
	local rawId = donation.id or donation.Id
	if rawId and rawId ~= "" and rawId ~= "N/A" and rawId ~= "null" and rawId ~= "00000000-0000-0000-0000-000000000000" then
		return tostring(rawId)
	end

	local dDate = tostring(donation.date or donation.Date or donation.tanggal or donation.Tanggal or "")
	local dName = tostring(donation.donator or donation.nama or donation.Nama or "Unknown")
	local dAmt = tostring(donation.amount or donation.jumlah or donation.Jumlah or "0")
	local dMsg = tostring(donation.message or donation.pesan or donation.Pesan or "")
	if dDate ~= "" then
		return string.format("%s_%s_%s_%s", dDate, dName, dAmt, dMsg)
	end
	return string.format("%s_%s_%s_%s", dName, dAmt, dMsg, tostring(index or 1))
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
	local folder = workspace:FindFirstChild("Leaderboard")
	local boardModel = (folder and (folder:FindFirstChild("BoardSaweria") or folder:FindFirstChild("Saweria")))
		or workspace:FindFirstChild("BoardSaweria")
		or workspace:FindFirstChild("Saweria")
		or workspace:FindFirstChild("BoardSaweria", true)
	if not boardModel then return end

	local surfaceGui = boardModel:FindFirstChildWhichIsA("SurfaceGui", true)
	if not surfaceGui then return end
	local listLabel = surfaceGui:FindFirstChild("List", true)
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

local function parseAmount(val)
	if type(val) == "number" then return math.floor(val) end
	if type(val) ~= "string" then return 0 end
	local clean = val:gsub("%D", "")
	return tonumber(clean) or 0
end

-- ============================================================
-- ID-BASED QUEUE READER (FIXED UNTUK GOOGLE SHEETS)
-- ============================================================
local function fetchDonationData()
	local donationArray = SaweriaAPI:GetDonationData()
	if type(donationArray) ~= "table" then return end

	local broadcastQueue = {}
	local hasNewData = false

	if isFirstLoad then
		-- Load awal data dari Google Sheets:
		-- Tandai SEMUA donasi yang sudah ada di spreadsheet sebagai sudah diproses
		for i, donation in ipairs(donationArray) do
			local currentId = getDonationUniqueId(donation, i)
			processedIds[currentId] = true
			table.insert(allDonations, donation)
		end

		while #allDonations > MAX_DONATIONS do 
			table.remove(allDonations, 1) 
		end

		pcall(updateBoard)
		isFirstLoad = false
		debugPrint(string.format("✅ Data awal ter-load (%d donasi). Semua ditandai sudah diproses (tidak ada notifikasi berulang saat start).", #donationArray))
		return
	end

	for i, currentDonation in ipairs(donationArray) do
		local currentId = getDonationUniqueId(currentDonation, i)

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
			local rpAmount = parseAmount(rawAmount)

			local totalAmount = 0
			for _, donation in ipairs(donationArray) do
				local dName = tostring(donation.donator or donation.nama or donation.Nama or "Unknown")
				if dName == rawDonator then
					local amt = parseAmount(donation.amount or donation.jumlah or donation.Jumlah)
					totalAmount = totalAmount + amt
				end
			end
			local donatorUserId = nil
			for _, p in ipairs(Players:GetPlayers()) do
				if p.Name:lower() == rawDonator:lower() or p.DisplayName:lower() == rawDonator:lower() then
					donatorUserId = p.UserId
					break
				end
			end
			if not donatorUserId then
				pcall(function()
					donatorUserId = Players:GetUserIdFromNameAsync(rawDonator)
				end)
			end

			local notifData = {
				donator = rawDonator,
				userId = donatorUserId,
				amount = rpAmount,
				total = totalAmount,
				message = rawMessage,
				timestamp = os.time()
			}

			if remoteEvent then 
				remoteEvent:FireAllClients(notifData) 
			end
			debugPrint(string.format("🚀 Mengirim notifikasi: %s | Rp %d | Pesan: '%s'", rawDonator, rpAmount, rawMessage))

			local ServerStorage = game:GetService("ServerStorage")
			local SaweriaEffectEvent = ServerStorage:FindFirstChild("SaweriaEffectEvent")
			if not SaweriaEffectEvent then
				SaweriaEffectEvent = Instance.new("BindableEvent")
				SaweriaEffectEvent.Name = "SaweriaEffectEvent"
				SaweriaEffectEvent.Parent = ServerStorage
			end
			SaweriaEffectEvent:Fire(rawDonator, rpAmount)

			-- Update ScreenTextSaweria di Workspace
			pcall(function()
				SaweriaScreenBoardHandler:ShowDonationMessage(rawDonator, rpAmount, rawMessage)
			end)

			task.wait(2.5) 
		end
	end
end

-- ========================================
-- TEST HELPER UNTUK ROBLOX STUDIO / ADMIN
-- ========================================
_G.TestSaweria = function(donatorName, amount, message)
	donatorName = tostring(donatorName or "TestDonator")
	amount = tostring(amount or 50000)
	message = tostring(message or "Tes notifikasi Saweria!")

	local rpAmount = parseAmount(amount)
	if rpAmount <= 0 then rpAmount = 50000 end

	local donatorUserId = nil
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Name:lower() == donatorName:lower() or p.DisplayName:lower() == donatorName:lower() then
			donatorUserId = p.UserId
			break
		end
	end
	if not donatorUserId then
		pcall(function()
			donatorUserId = Players:GetUserIdFromNameAsync(donatorName)
		end)
	end

	local notifData = {
		donator = donatorName,
		userId = donatorUserId,
		amount = rpAmount,
		total = rpAmount,
		message = message,
		timestamp = os.time()
	}

	if remoteEvent then
		remoteEvent:FireAllClients(notifData)
	end

	local ServerStorage = game:GetService("ServerStorage")
	local SaweriaEffectEvent = ServerStorage:FindFirstChild("SaweriaEffectEvent")
	if not SaweriaEffectEvent then
		SaweriaEffectEvent = Instance.new("BindableEvent")
		SaweriaEffectEvent.Name = "SaweriaEffectEvent"
		SaweriaEffectEvent.Parent = ServerStorage
	end
	SaweriaEffectEvent:Fire(donatorName, rpAmount)

	-- Update ScreenTextSaweria di Workspace
	pcall(function()
		SaweriaScreenBoardHandler:ShowDonationMessage(donatorName, rpAmount, message)
	end)

	print(string.format("[DonasiSaweria] 🧪 Test Saweria berhasil dipicu: %s | Rp %d | '%s'", donatorName, rpAmount, message))
end

_G.TestNuke = function(donatorName, message)
	_G.TestSaweria(donatorName or "NukeTester", 15000, message or "Nuke Incoming! 🚀")
end

_G.TestSmite = function(donatorName, message)
	_G.TestSaweria(donatorName or "SmiteTester", 50000, message or "Smite / Giant Hammer! ⚡🔨")
end

_G.TestBlackHole = function(donatorName, message)
	_G.TestSaweria(donatorName or "BlackHoleTester", 250000, message or "Black Hole Devastation! 🕳️")
end

_G.TestStarfall = function(donatorName, message)
	_G.TestSaweria(donatorName or "StarfallTester", 500000, message or "Starfall 10M Devastation! ✨⭐")
end

-- ========================================
-- MAIN LOOP
-- ========================================
debugPrint("✅ SAWERIA DONATION SYSTEM STARTED")
updateBoard()

-- Load awal secara asinkron segera saat server boot (tanpa menunggu CHECK_INTERVAL pertama)
task.spawn(function()
	local success, err = pcall(fetchDonationData)
	if not success then
		debugWarn("Error saat fetchDonationData pertama:", err)
	end
end)

local isFetchingAPI = false -- Gembok Anti-Thread Bomb

while true do
	task.wait(CHECK_INTERVAL)
	
	-- Hanya jalan jika API tidak sedang ngelag/nyangkut
	if not isFetchingAPI then
		isFetchingAPI = true
		
		task.spawn(function()
			local success, err = pcall(fetchDonationData)
			if not success then
				debugWarn("Error saat fetchDonationData:", err)
			end
			isFetchingAPI = false -- Buka gembok saat selesai
		end)
	else
		debugWarn("API Saweria sedang lambat, menunda fetch berikutnya...")
	end
end