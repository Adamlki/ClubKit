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
local getProductsRemote  = getOrCreate(ReplicatedStorage, "RemoteFunction", "GetDeveloperProducts")
local broadcastRemote    = getOrCreate(ReplicatedStorage, "RemoteFunction", "BroadcastDonationMessage")
local receiveRemote      = getOrCreate(ReplicatedStorage, "RemoteEvent",    "ReceiveDonationBroadcast")

-- ============================================
-- STATE
-- ============================================
local broadcastQueue      = {}
local isProcessingQueue   = false
local playerCooldowns     = {}  -- [userId] = lastBroadcastTime
local verifiedPurchases   = {}  -- [userId] = {[timestamp] = {amount, claimed}}

-- ============================================
-- SECURITY
-- ============================================

local function recordPurchase(userId, amount)
	if not verifiedPurchases[userId] then
		verifiedPurchases[userId] = {}
	end
	verifiedPurchases[userId][tick()] = {amount = amount, claimed = false}
	debugLog("BROADCAST", "Purchase recorded:", userId, amount)
end

local function verifyPurchase(userId, amount)
	if not DonationConfig.SECURITY.TRACK_PURCHASES then
		return true  -- Security dimatikan di Studio/Test
	end

	local purchases = verifiedPurchases[userId]
	if not purchases then
		debugLog("ERROR", "Tidak ada purchase tercatat untuk:", userId)
		return false
	end

	local now = tick()
	for timestamp, data in pairs(purchases) do
		if now - timestamp > DonationConfig.SECURITY.PURCHASE_TIMEOUT then
			purchases[timestamp] = nil
		elseif not data.claimed and data.amount == amount then
			data.claimed = true
			debugLog("BROADCAST", "Purchase verified:", userId, amount)
			return true
		end
	end

	debugLog("ERROR", "FAKE DONATION ATTEMPT:", userId, amount)
	return false
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
local function fireBroadcastToAll(displayName, amount, message)
	for _, targetPlayer in ipairs(Players:GetPlayers()) do
		local canChat = false
		local ok = pcall(function()
			canChat = TextChatService:CanUserChatAsync(targetPlayer.UserId)
		end)
		-- Jika pengecekan gagal (error jaringan), tetap kirim agar broadcast tidak hilang
		if not ok or canChat then
			receiveRemote:FireClient(targetPlayer, displayName, amount, message)
		end
	end
end

local function processQueue()
	if isProcessingQueue then return end
	isProcessingQueue = true

	while #broadcastQueue > 0 do
		local item = table.remove(broadcastQueue, 1)
		debugLog("BROADCAST", "Broadcasting:", item.displayName, item.amount)
		fireBroadcastToAll(item.displayName, item.amount, item.message)

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
				-- Buat objek sementara agar format bisa dipakai
				if item.amount >= DonationConfig.SCREEN_BOARD.MIN_DONATION then
					local fakePlayer = {
						UserId      = item.userId,
						DisplayName = item.displayName,
					}
					
					-- FILTERING RICHTEXT UNTUK DISPLAY NAME (Mencegah eksploitasi <font>)
					local safeDisplayName = item.displayName
					safeDisplayName = string.gsub(safeDisplayName, "&", "&amp;")
					safeDisplayName = string.gsub(safeDisplayName, "<", "&lt;")
					safeDisplayName = string.gsub(safeDisplayName, ">", "&gt;")
					safeDisplayName = string.gsub(safeDisplayName, '"', "&quot;")
					safeDisplayName = string.gsub(safeDisplayName, "'", "&apos;")

					-- Langsung update tanpa filtering (message sudah difilter saat masuk antrian)
					local displayNameText = string.format(
						DonationConfig.SCREEN_BOARD.NAME_FORMAT,
						safeDisplayName,
						item.amount
					)
					-- Fire manual ke semua client
					local screenBoardRemote = ReplicatedStorage:FindFirstChild("UpdateScreenBoard")
					if screenBoardRemote then
						for _, targetPlayer in ipairs(Players:GetPlayers()) do
							pcall(function()
								screenBoardRemote:FireClient(targetPlayer, displayNameText, item.message)
							end)
						end
					end
					debugLog("BROADCAST", "Screen board diupdate (player offline):", item.displayName)
				end
			end
		end

		task.wait(DonationConfig.BROADCAST.DISPLAY_DURATION + DonationConfig.BROADCAST.QUEUE_DELAY)
	end

	isProcessingQueue = false
	debugLog("BROADCAST", "Queue selesai diproses")
end

local function addToQueue(player, message, amount, skipVerification)
	local userId = player.UserId

	-- Verifikasi purchase (kecuali untuk auto-broadcast kecil)
	if not skipVerification then
		if not verifyPurchase(userId, amount) then
			if DonationConfig.SECURITY.KICK_ON_FAKE then
				player:Kick("Fake donation detected")
			end
			return false, "Donasi tidak terverifikasi."
		end

		-- Cooldown per player
		local lastTime  = playerCooldowns[userId] or 0
		local remaining = DonationConfig.BROADCAST.COOLDOWN - (tick() - lastTime)
		if remaining > 0 then
			return false, "Cooldown: tunggu " .. math.ceil(remaining) .. " detik."
		end
	end

	-- Batas antrian
	if getPlayerQueueCount(userId) >= DonationConfig.BROADCAST.MAX_QUEUE_PER_PLAYER then
		return false, "Terlalu banyak pesan dalam antrian."
	end
	if #broadcastQueue >= DonationConfig.BROADCAST.MAX_QUEUE then
		return false, "Antrian penuh."
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
-- REMOTES  Custom Broadcast Message
-- ============================================

broadcastRemote.OnServerInvoke = function(player, message, amount)
	if not player or not player.Parent then
		return false, "Player tidak valid."
	end
	if type(message) ~= "string" or #message < 1 then
		return false, "Pesan tidak valid."
	end
	if type(amount) ~= "number" or amount < DonationConfig.BROADCAST.MIN_DONATION then
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
	local ok = DonationDataStore:UpdatePlayerDonation(player, amount, receiptInfo)
	if not ok then
		debugLog("ERROR", "DataStore save gagal untuk:", player.Name)
	end
	return ok
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