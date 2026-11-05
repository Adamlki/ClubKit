local HttpService = game:GetService("HttpService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local DebugHooks = require(ServerStorage:WaitForChild("Modules"):WaitForChild("DebugHooks"))
local SaweriaAPI = require(ServerStorage:WaitForChild("Modules"):WaitForChild("SaweriaAPI"))
local ServerConfig = require(ServerScriptService:WaitForChild("Config"):WaitForChild("ServerConfig"))
local SaweriaScreenBoardHandler = require(script.Parent:WaitForChild("SaweriaScreenBoardHandler"))
local FormatUtils = require(ReplicatedStorage:WaitForChild("Utils"):WaitForChild("FormatUtils"))

local IS_STUDIO = RunService:IsStudio()
local DEBUG_ENABLED = IS_STUDIO
local DEBUG_PREFIX = "[DonasiSaweria]"

local function debugPrint(...)
	if DEBUG_ENABLED then print(DEBUG_PREFIX, ...) end
end

local function debugWarn(...)
	if DEBUG_ENABLED then warn(DEBUG_PREFIX, ...) end
end

local function getSafeContextUserId(preferredUserId)
	if preferredUserId and type(preferredUserId) == "number" and preferredUserId > 0 then
		return preferredUserId
	end
	local onlinePlayer = Players:GetPlayers()[1]
	if onlinePlayer then
		return onlinePlayer.UserId
	end
	local ownerId = ServerConfig.GetPrimaryOwnerId()
	if ownerId and ownerId > 0 then
		return ownerId
	end
	if game.CreatorType == Enum.CreatorType.User and game.CreatorId > 0 then
		return game.CreatorId
	end
	return 1
end

local function filterBroadcastText(rawText, contextUserId, defaultFallback)
	if not rawText or type(rawText) ~= "string" or #rawText == 0 then
		return defaultFallback
	end
	local safeUid = getSafeContextUserId(contextUserId)
	local filteredText = nil
	local okFilter = pcall(function()
		local filterResult = TextService:FilterStringAsync(rawText, safeUid, Enum.TextFilterContext.PublicChat)
		if filterResult then
			filteredText = filterResult:GetNonChatStringForBroadcastAsync()
		end
	end)
	if okFilter and filteredText and #filteredText > 0 then
		return filteredText
	end
	if IS_STUDIO then
		local trimmed = rawText:match("^%s*(.-)%s*$")
		if trimmed and #trimmed > 0 then
			return trimmed
		end
	end
	return defaultFallback
end

local CHECK_INTERVAL = IS_STUDIO and 30 or 60
local MAX_DONATIONS = 50

local DEDUP_MAP_NAME = "SaweriaDedup_v1"
local DEDUP_TTL = 7 * 24 * 60 * 60
local MAX_PROCESSED_IDS = 500

local JOB_ID = game.JobId
if JOB_ID == "" then
	JOB_ID = "studio-" .. tostring(math.random(100000, 999999))
end

local processedIds = {}
local processedOrder = {}
local isFirstLoad = true
local allDonations = {}

local seenMap = nil
pcall(function()
	seenMap = MemoryStoreService:GetHashMap(DEDUP_MAP_NAME)
end)
if not seenMap then
	warn(DEBUG_PREFIX, "MemoryStore tidak tersedia — dedupe lintas-server nonaktif (fallback: dedupe lokal).")
end

local remoteEvent = ReplicatedStorage:FindFirstChild("DonationNotification")
if not remoteEvent then
	remoteEvent = Instance.new("RemoteEvent")
	remoteEvent.Name = "DonationNotification"
	remoteEvent.Parent = ReplicatedStorage
end

debugPrint("✅ Donation system initialized")

local function formatRupiah(amount)
	return FormatUtils.formatRupiah(amount)
end

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

local function claimDonationCrossServer(uniqueId)
	if not seenMap then
		return true
	end

	local success, result = pcall(function()
		return seenMap:UpdateAsync(uniqueId, function(current)
			if current ~= nil then
				return nil
			end
			return JOB_ID
		end, DEDUP_TTL)
	end)

	if not success then
		debugWarn("MemoryStore claim gagal (fail-open, mungkin duplikat):", uniqueId, result)
		return true
	end

	return result == JOB_ID
end

local function markProcessed(uniqueId)
	if processedIds[uniqueId] then return end
	processedIds[uniqueId] = true
	table.insert(processedOrder, uniqueId)
	while #processedOrder > MAX_PROCESSED_IDS do
		local oldest = table.remove(processedOrder, 1)
		processedIds[oldest] = nil
	end
end

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

local function fetchDonationData()
	local donationArray = SaweriaAPI:GetDonationData()
	if type(donationArray) ~= "table" then return end

	local broadcastQueue = {}
	local hasNewData = false

	if isFirstLoad then
		for i, donation in ipairs(donationArray) do
			local currentId = getDonationUniqueId(donation, i)
			markProcessed(currentId)
			table.insert(allDonations, donation)
		end

		while #allDonations > MAX_DONATIONS do 
			table.remove(allDonations, 1) 
		end

		pcall(updateBoard)

		pcall(function()
			SaweriaScreenBoardHandler:ResetToDefault()
		end)

		isFirstLoad = false
		debugPrint(string.format("✅ Data awal ter-load (%d donasi). Semua ditandai sudah diproses (tidak ada notifikasi berulang saat start).", #donationArray))
		return
	end

	for i, currentDonation in ipairs(donationArray) do
		local currentId = getDonationUniqueId(currentDonation, i)

		if not processedIds[currentId] then
			markProcessed(currentId)
			hasNewData = true
			table.insert(allDonations, currentDonation)
			table.insert(broadcastQueue, { donation = currentDonation, id = currentId })
		end
	end

	if hasNewData then
		while #allDonations > MAX_DONATIONS do 
			table.remove(allDonations, 1) 
		end

		pcall(updateBoard)

		for _, entry in ipairs(broadcastQueue) do
			local currentDonation = entry.donation

			if not claimDonationCrossServer(entry.id) then
				debugPrint("⏭️ Skip donasi yang sudah diumumkan server lain: " .. tostring(entry.id))
				continue
			end

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
				if p.Name:lower() == rawDonator:lower() then
					donatorUserId = p.UserId
					break
				end
			end
			if not donatorUserId then
				pcall(function()
					donatorUserId = Players:GetUserIdFromNameAsync(rawDonator)
				end)
			end

			local filteredDonator = filterBroadcastText(rawDonator, donatorUserId, "Donatur")
			local filteredMessage = filterBroadcastText(rawMessage, donatorUserId, "Terima kasih banyak atas donasinya!")

			local notifData = {
				donator = filteredDonator,
				userId = donatorUserId,
				amount = rpAmount,
				total = totalAmount,
				message = filteredMessage,
				timestamp = os.time()
			}

			if remoteEvent then 
				remoteEvent:FireAllClients(notifData) 
			end
			debugPrint(string.format("🚀 Mengirim notifikasi: %s | Rp %d | Pesan: '%s'", filteredDonator, rpAmount, filteredMessage))

			local spotlightSettings = ReplicatedStorage:FindFirstChild("DonationSpotlightSettings")
			local isSpotlightOn = (spotlightSettings and spotlightSettings:GetAttribute("Enabled") == true)
			local minSaweria = spotlightSettings and spotlightSettings:GetAttribute("MinSaweria") or 50000
			local shouldSpotlight = isSpotlightOn and (rpAmount >= minSaweria)

			if shouldSpotlight then
				local DonorSpotlightRemote = ReplicatedStorage:FindFirstChild("DonorSpotlightRemote")
				if DonorSpotlightRemote then
					DonorSpotlightRemote:FireAllClients(donatorUserId or 0, filteredDonator, 5)
				end
			end

			local ServerStorage = game:GetService("ServerStorage")
			local SaweriaEffectEvent = ServerStorage:FindFirstChild("SaweriaEffectEvent")
			if not SaweriaEffectEvent then
				SaweriaEffectEvent = Instance.new("BindableEvent")
				SaweriaEffectEvent.Name = "SaweriaEffectEvent"
				SaweriaEffectEvent.Parent = ServerStorage
			end
			SaweriaEffectEvent:Fire(filteredDonator, rpAmount, shouldSpotlight)

			pcall(function()
				SaweriaScreenBoardHandler:ShowDonationMessage(filteredDonator, rpAmount, filteredMessage)
			end)

			task.wait(2.5) 
		end
	end
end

local function testSaweria(donatorName, amount, message)
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

	local filteredDonator = filterBroadcastText(donatorName, donatorUserId, "Donatur")
	local filteredMessage = filterBroadcastText(message, donatorUserId, "Terima kasih banyak atas donasinya!")

	local notifData = {
		donator = filteredDonator,
		userId = donatorUserId,
		amount = rpAmount,
		total = rpAmount,
		message = filteredMessage,
		timestamp = os.time()
	}

	if remoteEvent then
		remoteEvent:FireAllClients(notifData)
	end

	local spotlightSettings = ReplicatedStorage:FindFirstChild("DonationSpotlightSettings")
	local isSpotlightOn = (spotlightSettings and spotlightSettings:GetAttribute("Enabled") == true)
	local minSaweria = spotlightSettings and spotlightSettings:GetAttribute("MinSaweria") or 50000
	local shouldSpotlight = isSpotlightOn and (rpAmount >= minSaweria)

	if shouldSpotlight then
		local DonorSpotlightRemote = ReplicatedStorage:FindFirstChild("DonorSpotlightRemote")
		if DonorSpotlightRemote then
			DonorSpotlightRemote:FireAllClients(donatorUserId or 0, filteredDonator, 5)
		end
	end

	local ServerStorage = game:GetService("ServerStorage")
	local SaweriaEffectEvent = ServerStorage:FindFirstChild("SaweriaEffectEvent")
	if not SaweriaEffectEvent then
		SaweriaEffectEvent = Instance.new("BindableEvent")
		SaweriaEffectEvent.Name = "SaweriaEffectEvent"
		SaweriaEffectEvent.Parent = ServerStorage
	end
	SaweriaEffectEvent:Fire(filteredDonator, rpAmount, shouldSpotlight)

	pcall(function()
		SaweriaScreenBoardHandler:ShowDonationMessage(filteredDonator, rpAmount, filteredMessage)
	end)

	print(string.format("[DonasiSaweria] 🧪 Test Saweria berhasil dipicu: %s | Rp %d | '%s'", donatorName, rpAmount, message))
end

local function testNuke(donatorName, message)
	testSaweria(donatorName or "NukeTester", 15000, message or "Nuke Incoming! 🚀")
end

local function testSmite(donatorName, message)
	testSaweria(donatorName or "SmiteTester", 50000, message or "Smite / Giant Hammer! ⚡🔨")
end

local function testBlackHole(donatorName, message)
	testSaweria(donatorName or "BlackHoleTester", 250000, message or "Black Hole Devastation! 🕳️")
end

local function testStarfall(donatorName, message)
	testSaweria(donatorName or "StarfallTester", 500000, message or "Starfall 10M Devastation! ✨⭐")
end

DebugHooks.Register("TestSaweria", testSaweria)
DebugHooks.Register("TestNuke", testNuke)
DebugHooks.Register("TestSmite", testSmite)
DebugHooks.Register("TestBlackHole", testBlackHole)
DebugHooks.Register("TestStarfall", testStarfall)

debugPrint("✅ SAWERIA DONATION SYSTEM STARTED")
updateBoard()

task.spawn(function()
	local success, err = pcall(fetchDonationData)
	if not success then
		debugWarn("Error saat fetchDonationData pertama:", err)
	end
end)

local isFetchingAPI = false

while true do
	task.wait(CHECK_INTERVAL)
	
	if #Players:GetPlayers() == 0 then
		continue
	end

	if not isFetchingAPI then
		isFetchingAPI = true
		
		task.spawn(function()
			local success, err = pcall(fetchDonationData)
			if not success then
				debugWarn("Error saat fetchDonationData:", err)
			end
			isFetchingAPI = false
		end)
	else
		debugWarn("API Saweria sedang lambat, menunda fetch berikutnya...")
	end
end
