local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage     = game:GetService("ServerStorage")
local Players           = game:GetService("Players")
local TextService       = game:GetService("TextService")
local TextChatService   = game:GetService("TextChatService")

local DonationConfig        = require(script.DonationConfig)
local DonationDataStore     = require(script.DonationDataStore)
local ProcessReceiptHandler = require(script.ProcessReceiptHandler)
local ScreenBoardHandler    = require(script.ScreenBoardHandler)

local function debugLog(category, ...)
	if not DonationConfig.DEBUG.ENABLED then return end
	local show = (category == "BROADCAST" and DonationConfig.DEBUG.SHOW_BROADCAST)
		or (category == "ERROR" and DonationConfig.DEBUG.SHOW_ERRORS)
	if not show then return end
	if category == "ERROR" then
		warn("[SERVER ERROR]", ...)
	else
		print("[BROADCAST]", ...)
	end
end

local function getOrCreate(parent, className, name)
	local inst = parent:FindFirstChild(name)
	if not inst then
		inst = Instance.new(className)
		inst.Name = name
		inst.Parent = parent
	end
	return inst
end

local getProductsRemote    = getOrCreate(ReplicatedStorage, "RemoteFunction", "GetDeveloperProducts")
local broadcastRemote      = getOrCreate(ReplicatedStorage, "RemoteFunction", "BroadcastDonationMessage")
local receiveRemote        = getOrCreate(ReplicatedStorage, "RemoteEvent",    "ReceiveDonationBroadcast")
local getPlayerStatsRemote = getOrCreate(ReplicatedStorage, "RemoteFunction", "GetPlayerDonationStats")
local RobuxDonationEffectEvent = getOrCreate(ServerStorage, "BindableEvent", "RobuxDonationEffectEvent")

local broadcastQueue    = {}
local isProcessingQueue = false
local playerCooldowns   = {}
local verifiedPurchases = {}
local canChatCache      = {}
local statsCooldown     = {}
local statsCache        = {}

local addToQueue
local processQueue

local function cachePlayerChatPermission(player)
	task.spawn(function()
		local ok, result = pcall(TextChatService.CanUserChatAsync, TextChatService, player.UserId)
		if player and player.Parent then
			canChatCache[player.UserId] = (not ok) or (result == true)
		end
	end)
end

Players.PlayerAdded:Connect(cachePlayerChatPermission)
for _, p in ipairs(Players:GetPlayers()) do
	cachePlayerChatPermission(p)
end

local function recordPurchase(userId, amount)
	if not verifiedPurchases[userId] then
		verifiedPurchases[userId] = {}
	end
	local purchaseTime = tick()
	local isSmall = (amount < DonationConfig.BROADCAST.MIN_DONATION)
	verifiedPurchases[userId][purchaseTime] = { amount = amount, claimed = isSmall }
	debugLog("BROADCAST", "Purchase recorded:", userId, amount)

	if not isSmall then
		task.delay(120, function()
			local userPurchases = verifiedPurchases[userId]
			if userPurchases and userPurchases[purchaseTime] and not userPurchases[purchaseTime].claimed then
				userPurchases[purchaseTime].claimed = true
				debugLog("BROADCAST", "Timeout tercapai untuk user:", userId)
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
						timestamp   = tick(),
					})
					task.spawn(processQueue)
				end
			end
		end)
	end
end

local function verifyPurchase(userId)
	local startTime = os.clock()
	repeat
		local purchases = verifiedPurchases[userId]
		if purchases then
			local now = tick()
			local bestTimestamp, bestData

			for timestamp, data in pairs(purchases) do
				if now - timestamp > DonationConfig.SECURITY.PURCHASE_TIMEOUT then
					purchases[timestamp] = nil
				elseif not data.claimed and (data.amount >= DonationConfig.BROADCAST.MIN_DONATION) then
					if not bestTimestamp or timestamp < bestTimestamp then
						bestTimestamp = timestamp
						bestData = data
					end
				end
			end

			if bestData then
				bestData.claimed = true
				debugLog("BROADCAST", "Purchase verified:", userId, bestData.amount)
				return true, bestData.amount
			end
		end

		if not DonationConfig.SECURITY.TRACK_PURCHASES then
			return true, DonationConfig.BROADCAST.MIN_DONATION
		end

		if os.clock() - startTime < 3 then
			task.wait(0.3)
		else
			break
		end
	until false

	debugLog("ERROR", "FAKE DONATION ATTEMPT:", userId)
	return false, 0
end

local function cleanupPlayerSecurity(userId)
	verifiedPurchases[userId] = nil
	playerCooldowns[userId]   = nil
	canChatCache[userId]      = nil
	statsCooldown[userId]     = nil
	statsCache[userId]        = nil
end

local function getCooldownRemaining(userId)
	local last = playerCooldowns[userId]
	if not last then return 0 end
	local remaining = DonationConfig.BROADCAST.COOLDOWN - (tick() - last)
	return math.max(0, remaining)
end

local function filterBroadcastMessage(message, fromPlayer)
	if not DonationConfig.BROADCAST.ENABLED then return message end

	local ok, filteredText = pcall(function()
		local filterResult = TextService:FilterStringAsync(message, fromPlayer.UserId, Enum.TextFilterContext.PublicChat)
		return filterResult and filterResult:GetNonChatStringForBroadcastAsync()
	end)

	if not ok or not filteredText then
		debugLog("ERROR", "Filter broadcast gagal:", filteredText)
		return nil
	end
	return filteredText
end

local function getPlayerQueueCount(userId)
	local count = 0
	for _, item in ipairs(broadcastQueue) do
		if item.userId == userId then
			count += 1
		end
	end
	return count
end

local function fireBroadcastToAll(displayName, amount, message, userId, totalAmount)
	for _, targetPlayer in ipairs(Players:GetPlayers()) do
		if canChatCache[targetPlayer.UserId] ~= false then
			receiveRemote:FireClient(targetPlayer, displayName, amount, message, userId, totalAmount)
		end
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

		local spotlightSettings = ReplicatedStorage:FindFirstChild("DonationSpotlightSettings")
		local isSpotlightOn = (spotlightSettings and spotlightSettings:GetAttribute("Enabled") == true)
		local minRobux = spotlightSettings and spotlightSettings:GetAttribute("MinRobux") or 500
		local shouldSpotlight = isSpotlightOn and (item.amount >= minRobux)

		if shouldSpotlight then
			local DonorSpotlightRemote = ReplicatedStorage:FindFirstChild("DonorSpotlightRemote")
			if DonorSpotlightRemote then
				DonorSpotlightRemote:FireAllClients(item.userId, item.displayName, 5)
			end
		end

		local player = Players:GetPlayerByUserId(item.userId)
		RobuxDonationEffectEvent:Fire(player or item.displayName, item.amount, shouldSpotlight)

		if DonationConfig.SCREEN_BOARD.ENABLED then
			local donorPlr = Players:GetPlayerByUserId(item.userId) or {
				UserId      = item.userId,
				Name        = item.displayName,
				DisplayName = item.displayName,
			}
			ScreenBoardHandler:ShowDonationMessage(donorPlr, item.amount, item.message)
		end

		task.wait(DonationConfig.BROADCAST.DISPLAY_DURATION + DonationConfig.BROADCAST.QUEUE_DELAY)
	end

	isProcessingQueue = false
end

addToQueue = function(player, message, amount, skipVerification)
	local userId = player.UserId

	if getPlayerQueueCount(userId) >= DonationConfig.BROADCAST.MAX_QUEUE_PER_PLAYER then
		return false, "Terlalu banyak pesan dalam antrian."
	end
	if #broadcastQueue >= DonationConfig.BROADCAST.MAX_QUEUE then
		return false, "Antrian penuh."
	end

	if not skipVerification then
		local remaining = getCooldownRemaining(userId)
		if remaining > 0 then
			return false, string.format("Tunggu %d detik lagi sebelum broadcast berikutnya.", math.ceil(remaining))
		end

		local verified, verifiedAmount = verifyPurchase(userId)
		if not verified or not verifiedAmount or verifiedAmount < DonationConfig.BROADCAST.MIN_DONATION then
			if DonationConfig.SECURITY.KICK_ON_FAKE then
				player:Kick("Fake donation detected")
			end
			return false, "Donasi tidak terverifikasi atau tidak mencukupi."
		end
		amount = verifiedAmount
	end

	message = message:match("^%s*(.-)%s*$")
	if #message > DonationConfig.BROADCAST.MAX_MESSAGE_LENGTH then
		message = message:sub(1, DonationConfig.BROADCAST.MAX_MESSAGE_LENGTH)
	end

	table.insert(broadcastQueue, {
		userId      = userId,
		displayName = player.DisplayName,
		amount      = amount,
		message     = message,
		timestamp   = tick(),
	})

	if not skipVerification then
		playerCooldowns[userId] = tick()
	end

	task.spawn(processQueue)
	return true, "Pesan ditambahkan ke antrian."
end

local cachedProducts
getProductsRemote.OnServerInvoke = function(player)
	if not cachedProducts then
		cachedProducts = {}
		for _, p in ipairs(DonationConfig.PRODUCTS) do
			table.insert(cachedProducts, { Id = p.id, Name = p.name, Price = p.price })
		end
		table.sort(cachedProducts, function(a, b) return a.Price < b.Price end)
	end
	return cachedProducts
end

getPlayerStatsRemote.OnServerInvoke = function(clientPlayer)
	if not clientPlayer then return { robux = 0, rupiah = 0 } end

	local userId = clientPlayer.UserId
	local now = os.clock()
	local cached = statsCache[userId]
	if now - (statsCooldown[userId] or 0) < 3 and cached then
		-- Remote ini read-only. Saat cooldown, kembalikan hasil terakhir;
		-- jangan kirim 0 karena UI akan menimpanya dengan "0 CASH".
		return cached
	end
	statsCooldown[userId] = now

	local robuxData = DonationDataStore:GetPlayerDonation(clientPlayer.UserId)
	local totalRobux = 0
	if robuxData then
		totalRobux = (robuxData["Donated - Studio"] or 0) + (robuxData["Donated - Experience"] or 0)
	end

	local totalRupiah = 0
	local ok, SaweriaAPI = pcall(function()
		return require(ServerStorage:WaitForChild("Modules"):WaitForChild("SaweriaAPI"))
	end)
	if ok and SaweriaAPI then
		local okData, donations = pcall(SaweriaAPI.GetDonationData, SaweriaAPI)
		if okData and type(donations) == "table" then
			local pName = clientPlayer.Name:lower()
			for _, d in ipairs(donations) do
				local dName = tostring(d.donator or d.nama or d.Nama or ""):lower()
				if dName == pName then
					local raw = tostring(d.amount or d.jumlah or d.Jumlah or "0"):gsub("%D", "")
					totalRupiah += (tonumber(raw) or 0)
				end
			end
		end
	end

	local result = {
		robux = totalRobux,
		rupiah = totalRupiah,
	}
	statsCache[userId] = result
	return result
end

broadcastRemote.OnServerInvoke = function(player, message)
	if not player or not player.Parent then
		return false, "Player tidak valid."
	end
	if type(message) ~= "string" or #message < 1 then
		return false, "Pesan tidak valid."
	end

	local remaining = getCooldownRemaining(player.UserId)
	if remaining > 0 then
		return false, string.format("Tunggu %d detik lagi sebelum broadcast berikutnya.", math.ceil(remaining))
	end

	local filtered = filterBroadcastMessage(message, player)
	if filtered == nil then
		return false, "Pesan tidak dapat dikirim karena gagal melewati filter konten."
	end

	return addToQueue(player, filtered, nil, false)
end

ProcessReceiptHandler:Initialize()

ProcessReceiptHandler:RegisterCallback("SaveToDataStore", function(player, productId, amount, receiptInfo)
	local ok, isNew = DonationDataStore:UpdatePlayerDonation(player, amount, receiptInfo)
	if not ok then debugLog("ERROR", "DataStore save gagal untuk:", player.Name) end
	return ok, isNew
end)

ProcessReceiptHandler:RegisterCallback("RecordPurchase", function(player, productId, amount, receiptInfo)
	recordPurchase(player.UserId, amount)
	return true
end)

ProcessReceiptHandler:RegisterCallback("AutoBroadcastAll", function(player, productId, amount, receiptInfo)
	if not DonationConfig.BROADCAST.ENABLED then return true end

	if amount < DonationConfig.BROADCAST.MIN_DONATION then
		local ok, reason = addToQueue(player, DonationConfig.DEFAULT_SMALL_DONATION_MESSAGE, amount, true)
		if not ok then debugLog("ERROR", "Auto-broadcast kecil gagal:", reason) end
		return ok
	end
	return true
end)

game:BindToClose(function()
	DonationDataStore:FlushBoardWrites(8)
end)

Players.PlayerRemoving:Connect(function(player)
	DonationDataStore:CleanupPlayer(player)
	cleanupPlayerSecurity(player.UserId)
	statsCooldown[player.UserId] = nil
	statsCache[player.UserId] = nil
end)
