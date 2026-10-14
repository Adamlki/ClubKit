local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players           = game:GetService("Players")
local TextService       = game:GetService("TextService")
local TextChatService   = game:GetService("TextChatService")

local DonationConfig        = require(script.DonationConfig)
local DonationDataStore     = require(script.DonationDataStore)
local ProcessReceiptHandler = require(script.ProcessReceiptHandler)
local ScreenBoardHandler    = require(script.ScreenBoardHandler)  -- FITUR BARU

-- ============================================
-- HELPER
-- ============================================
local function debugLog(category, ...)
	if not DonationConfig.DEBUG.ENABLED then return end
	local show = (category == "BROADCAST" and DonationConfig.DEBUG.SHOW_BROADCAST)
		or (category == "ERROR"     and DonationConfig.DEBUG.SHOW_ERRORS)
	if not show then return end
	if category == "ERROR" then
		warn("[SERVER ERROR]", ...)
	else
		print("[BROADCAST]", ...)
	end
end

local function getOrCreate(parent, className, name)
	return parent:FindFirstChild(name) or (function()
		local inst = Instance.new(className)
		inst.Name   = name
		inst.Parent = parent
		return inst
	end)()
end

-- ============================================
-- REMOTES
-- ============================================
local getProductsRemote    = getOrCreate(ReplicatedStorage, "RemoteFunction", "GetDeveloperProducts")
local broadcastRemote      = getOrCreate(ReplicatedStorage, "RemoteFunction", "BroadcastDonationMessage")
local receiveRemote        = getOrCreate(ReplicatedStorage, "RemoteEvent",    "ReceiveDonationBroadcast")
local getPlayerStatsRemote = getOrCreate(ReplicatedStorage, "RemoteFunction", "GetPlayerDonationStats")

-- ============================================
-- STATE
-- ============================================
local broadcastQueue      = {}
local isProcessingQueue   = false
local playerCooldowns     = {}  -- [userId] = lastBroadcastTime
local verifiedPurchases   = {}  -- [userId] = {[timestamp] = {amount, claimed}}

local addToQueue = nil
local processQueue = nil

-- ============================================
-- SECURITY
-- ============================================

local function recordPurchase(userId, amount)
	if not verifiedPurchases[userId] then
		verifiedPurchases[userId] = {}
	end
	local purchaseTime = tick()
	local isSmall = (amount < DonationConfig.BROADCAST.MIN_DONATION)
	verifiedPurchases[userId][purchaseTime] = {amount = amount, claimed = isSmall}
	debugLog("BROADCAST", "Purchase recorded:", userId, amount)

	if not isSmall then
		-- Timeout fallback: jika player tidak mengirim pesan dalam 90 detik (misal AFK/close UI/disconnect),
		-- otomatis kirim pesan default sehingga broadcast dan efek panggung tetap muncul!
		task.delay(120, function()
			local userPurchases = verifiedPurchases[userId]
			if userPurchases and userPurchases[purchaseTime] and not userPurchases[purchaseTime].claimed then
				userPurchases[purchaseTime].claimed = true
				debugLog("BROADCAST", "Timeout tercapai untuk user:", userId, "- memicu broadcast default & efek")
				local p = Players:GetPlayerByUserId(userId)
				local defaultMsg = DonationConfig.DEFAULT_SMALL_DONATION_MESSAGE or "Thank you for your donation!"
				if p then
					addToQueue(p, defaultMsg, amount, true)
				else
					table.insert(broadcastQueue, {
						userId      = userId,
						displayName = "Donator",
						amount      = amount,
						message     = defaultMsg,
						timestamp   = tick()
					})
					task.spawn(processQueue)
				end
			end
		end)
	end
end

local function verifyPurchase(userId, amount)
	local startTime = os.clock()
	-- Beri toleransi waktu hingga 3 detik jika ProcessReceipt di server sedang memproses DataStore
	repeat
		local purchases = verifiedPurchases[userId]
		if purchases then
			local now = tick()
			for timestamp, data in pairs(purchases) do
				if now - timestamp > DonationConfig.SECURITY.PURCHASE_TIMEOUT then
					purchases[timestamp] = nil
				elseif not data.claimed and (amount == nil or data.amount == amount) then
					data.claimed = true
					debugLog("BROADCAST", "Purchase verified & claimed:", userId, data.amount)
					return true, data.amount
				end
			end
		end

		if not DonationConfig.SECURITY.TRACK_PURCHASES then
			return true, amount or 0
		end

		if os.clock() - startTime < 3 then
			task.wait(0.3)
		else
			break
		end
	until false

	debugLog("ERROR", "FAKE DONATION ATTEMPT:", userId, amount)
	return false, 0
end

local function cleanupPlayerSecurity(userId)
	verifiedPurchases[userId] = nil
	playerCooldowns[userId]   = nil
end

-- ============================================
-- TEXT FILTERING
-- [WAJIB Roblox] Filter custom message dari donor sebelum broadcast.
-- Jika gagal, kembalikan nil (pesan TIDAK dikirim).
-- ============================================
local function filterBroadcastMessage(message, fromPlayer)
	if not DonationConfig.BROADCAST.ENABLED then return message end

	local filterResult
	local ok1, err1 = pcall(function()
		filterResult = TextService:FilterStringAsync(
			message,
			fromPlayer.UserId,
			Enum.TextFilterContext.PublicChat
		)
	end)

	if not ok1 or not filterResult then
		debugLog("ERROR", "FilterStringAsync gagal:", err1)
		return nil  -- Batalkan, jangan kirim unfiltered
	end

	local filteredText
	local ok2, err2 = pcall(function()
		filteredText = filterResult:GetNonChatStringForBroadcastAsync()
	end)

	if not ok2 or filteredText == nil then
		debugLog("ERROR", "GetNonChatStringForBroadcastAsync gagal:", err2)
		return nil
	end

	return filteredText
end

-- ============================================
-- BROADCAST / QUEUE
-- ============================================

local function getPlayerQueueCount(userId)
	local count = 0
	for _, item in ipairs(broadcastQueue) do
		if item.userId == userId then
			count += 1
		end
	end
	return count
end

--[[
    Kirim broadcast ke semua player yang bisa menerima chat.
    [WAJIB Roblox] Periksa CanUserChatAsync() per penerima.
--]]
local function fireBroadcastToAll(displayName, amount, message, userId, totalAmount)
	for _, targetPlayer in ipairs(Players:GetPlayers()) do
		task.spawn(function()
			local canChat = false
			local ok = pcall(function()
				canChat = TextChatService:CanUserChatAsync(targetPlayer.UserId)
			end)
			-- Jika pengecekan gagal (error jaringan), tetap kirim agar broadcast tidak hilang
			if not ok or canChat then
				receiveRemote:FireClient(targetPlayer, displayName, amount, message, userId, totalAmount)
			end
		end)
	end
end

processQueue = function()
	if isProcessingQueue then return end
	isProcessingQueue = true

	while #broadcastQueue > 0 do
		local item = table.remove(broadcastQueue, 1)
		debugLog("BROADCAST", "Broadcasting:", item.displayName, item.amount)

		local totalAmount = item.amount
		pcall(function()
			local robuxData = DonationDataStore:GetPlayerDonation(item.userId)
			if robuxData then
				local tot = (robuxData["Donated - Studio"] or 0) + (robuxData["Donated - Experience"] or 0)
				if tot > 0 then totalAmount = tot end
			end
		end)

		fireBroadcastToAll(item.displayName, item.amount, item.message, item.userId, totalAmount)

		-- Cek pengaturan sorot kamera donor
		local spotlightSettings = ReplicatedStorage:FindFirstChild("DonationSpotlightSettings")
		local isSpotlightOn = (spotlightSettings and spotlightSettings:GetAttribute("Enabled") == true)
		local minRobux = spotlightSettings and spotlightSettings:GetAttribute("MinRobux") or 500
		local shouldSpotlight = isSpotlightOn and (item.amount >= minRobux)

		-- Trigger animasi kamera sorot donor ke semua client jika memenuhi syarat
		if shouldSpotlight then
			local DonorSpotlightRemote = ReplicatedStorage:FindFirstChild("DonorSpotlightRemote")
			if DonorSpotlightRemote then
				DonorSpotlightRemote:FireAllClients(item.userId, item.displayName, 5)
			end
		end

		-- 🔥 PICU EFEK ROBUX BERSAMAAN DENGAN NOTIFIKASI PESAN & SCREEN BOARD!
		local ServerStorage = game:GetService("ServerStorage")
		local RobuxDonationEffectEvent = ServerStorage:FindFirstChild("RobuxDonationEffectEvent")
		if not RobuxDonationEffectEvent then
			RobuxDonationEffectEvent = Instance.new("BindableEvent")
			RobuxDonationEffectEvent.Name = "RobuxDonationEffectEvent"
			RobuxDonationEffectEvent.Parent = ServerStorage
		end
		local player = Players:GetPlayerByUserId(item.userId)
		RobuxDonationEffectEvent:Fire(player or item.displayName, item.amount, shouldSpotlight)

		-- ============================================
		-- SCREEN BOARD UPDATE (FITUR BARU)
		-- Setiap broadcast yang masuk antrian juga ditampilkan
		-- di screen board jika amount >= SCREEN_BOARD.MIN_DONATION.
		-- Message yang dipakai adalah yang sudah difilter dari antrian.
		-- ============================================
		if DonationConfig.SCREEN_BOARD.ENABLED then
			local player = Players:GetPlayerByUserId(item.userId)
			if player then
				ScreenBoardHandler:ShowDonationMessage(player, item.amount, item.message)
			else
				-- Player sudah disconnect, tapi tetap update board dengan data yang ada
				local fakePlayer = {
					UserId      = item.userId,
					Name        = item.displayName,
					DisplayName = item.displayName,
				}
				ScreenBoardHandler:ShowDonationMessage(fakePlayer, item.amount, item.message)
				debugLog("BROADCAST", "Screen board diupdate (player offline):", item.displayName)
			end
		end

		task.wait(DonationConfig.BROADCAST.DISPLAY_DURATION + DonationConfig.BROADCAST.QUEUE_DELAY)
	end

	isProcessingQueue = false
	debugLog("BROADCAST", "Queue selesai diproses")
end

addToQueue = function(player, message, amount, skipVerification)
	local userId = player.UserId

	-- Batas antrian dicek terlebih dahulu
	if getPlayerQueueCount(userId) >= DonationConfig.BROADCAST.MAX_QUEUE_PER_PLAYER then
		return false, "Terlalu banyak pesan dalam antrian."
	end
	if #broadcastQueue >= DonationConfig.BROADCAST.MAX_QUEUE then
		return false, "Antrian penuh."
	end

	-- Verifikasi purchase (kecuali untuk auto-broadcast kecil / fallback)
	if not skipVerification then
		local verified, verifiedAmount = verifyPurchase(userId, amount)
		if not verified then
			if DonationConfig.SECURITY.KICK_ON_FAKE then
				player:Kick("Fake donation detected")
			end
			return false, "Donasi tidak terverifikasi."
		end
		if verifiedAmount and verifiedAmount > 0 then
			amount = verifiedAmount
		end
	end

	-- Trim whitespace dan potong kalau terlalu panjang
	message = message:match("^%s*(.-)%s*$")
	if #message > DonationConfig.BROADCAST.MAX_MESSAGE_LENGTH then
		message = message:sub(1, DonationConfig.BROADCAST.MAX_MESSAGE_LENGTH)
	end

	table.insert(broadcastQueue, {
		userId      = userId,
		displayName = player.DisplayName,
		amount      = amount,
		message     = message,
		timestamp   = tick()
	})

	if not skipVerification then
		playerCooldowns[userId] = tick()
	end

	debugLog("BROADCAST", "Antrian:", player.DisplayName, "| Queue size:", #broadcastQueue)
	task.spawn(processQueue)
	return true, "Pesan ditambahkan ke antrian."
end

-- ============================================
-- REMOTES  Products
-- ============================================

local cachedProducts = nil
getProductsRemote.OnServerInvoke = function(player)
	debugLog("BROADCAST", player.Name, "meminta daftar produk")

	if not cachedProducts then
		cachedProducts = {}
		for _, p in ipairs(DonationConfig.PRODUCTS) do
			table.insert(cachedProducts, {Id = p.id, Name = p.name, Price = p.price})
		end
		table.sort(cachedProducts, function(a, b) return a.Price < b.Price end)
	end
	return cachedProducts
end

-- ============================================
-- REMOTES - Get Player Donation Stats (Robux + Rupiah)
-- ============================================
getPlayerStatsRemote.OnServerInvoke = function(clientPlayer)
	if not clientPlayer then return {robux = 0, rupiah = 0} end

	local robuxData = DonationDataStore:GetPlayerDonation(clientPlayer.UserId)
	local totalRobux = 0
	if robuxData then
		totalRobux = (robuxData["Donated - Studio"] or 0) + (robuxData["Donated - Experience"] or 0)
	end

	local totalRupiah = 0
	local ok, SaweriaAPI = pcall(function()
		return require(game:GetService("ServerStorage"):WaitForChild("Modules"):WaitForChild("SaweriaAPI"))
	end)
	if ok and SaweriaAPI then
		local okData, donations = pcall(function() return SaweriaAPI:GetDonationData() end)
		if okData and type(donations) == "table" then
			local pName = clientPlayer.Name:lower()
			local pDisplay = clientPlayer.DisplayName:lower()
			for _, d in ipairs(donations) do
				local dName = tostring(d.donator or d.nama or d.Nama or ""):lower()
				if dName == pName or dName == pDisplay then
					local raw = tostring(d.amount or d.jumlah or d.Jumlah or "0"):gsub("%D", "")
					local amt = tonumber(raw) or 0
					totalRupiah = totalRupiah + amt
				end
			end
		end
	end

	return {
		robux = totalRobux,
		rupiah = totalRupiah
	}
end

-- ============================================
-- REMOTES  Custom Broadcast Message
-- ============================================

broadcastRemote.OnServerInvoke = function(player, message, amount)
	if not player or not player.Parent then
		return false, "Player tidak valid."
	end
	if type(message) ~= "string" or #message < 1 then
		return false, "Pesan tidak valid."
	end
	if amount ~= nil and (type(amount) ~= "number" or amount < DonationConfig.BROADCAST.MIN_DONATION) then
		return false, "Donasi tidak mencukupi untuk broadcast."
	end

	-- [WAJIB Roblox] Filter konten sebelum dikirim
	local filtered = filterBroadcastMessage(message, player)
	if filtered == nil then
		return false, "Pesan tidak dapat dikirim karena gagal melewati filter konten."
	end

	return addToQueue(player, filtered, amount, false)
end

-- ============================================
-- INITIALIZATION
-- ============================================

ProcessReceiptHandler:Initialize()
--DonationDataStore:StartPeriodicSave()

-- ============================================
-- PROCESS RECEIPT CALLBACKS
-- ============================================

-- Callback 1: Simpan ke DataStore (total saja, tanpa history)
ProcessReceiptHandler:RegisterCallback("SaveToDataStore", function(player, productId, amount, receiptInfo)
	local ok, isNew = DonationDataStore:UpdatePlayerDonation(player, amount, receiptInfo)
	if not ok then
		debugLog("ERROR", "DataStore save gagal untuk:", player.Name)
	end
	return ok, isNew
end)

-- Callback 2: Catat untuk verifikasi keamanan
ProcessReceiptHandler:RegisterCallback("RecordPurchase", function(player, productId, amount, receiptInfo)
	recordPurchase(player.UserId, amount)
	return true
end)

-- Callback 3: Auto-broadcast untuk semua donasi
ProcessReceiptHandler:RegisterCallback("AutoBroadcastAll", function(player, productId, amount, receiptInfo)
	if not DonationConfig.BROADCAST.ENABLED then return true end

	-- Donasi kecil (< MIN_DONATION): gunakan pesan default, skip verifikasi & cooldown
	if amount < DonationConfig.BROADCAST.MIN_DONATION then
		local defaultMsg = DonationConfig.DEFAULT_SMALL_DONATION_MESSAGE
		local ok, reason = addToQueue(player, defaultMsg, amount, true)
		if not ok then
			debugLog("ERROR", "Auto-broadcast kecil gagal:", reason)
		end
		return ok
	end

	-- Donasi besar (>= MIN_DONATION): donor akan kirim custom message via UI
	debugLog("BROADCAST", "Menunggu custom message dari:", player.Name)
	return true
end)

-- ============================================
-- PLAYER CLEANUP
-- ============================================

Players.PlayerRemoving:Connect(function(player)
	DonationDataStore:CleanupPlayer(player)
	cleanupPlayerSecurity(player.UserId)

	-- (REMOVED) Tidak lagi menghapus pesan dari antrian saat player keluar.
	-- Hak donasi tetap berjalan agar player tidak rugi jika putus koneksi.

	debugLog("BROADCAST", "Cleanup selesai:", player.Name)
end)

debugLog("BROADCAST", "DonationServerHandler initialized")
debugLog("BROADCAST", "Environment:", DonationConfig.IS_TEST_MODE and "STUDIO" or "LIVE")
debugLog("BROADCAST", "MIN_DONATION:", DonationConfig.BROADCAST.MIN_DONATION)
debugLog("BROADCAST", "SCREEN_BOARD MIN_DONATION:", DonationConfig.SCREEN_BOARD.MIN_DONATION)