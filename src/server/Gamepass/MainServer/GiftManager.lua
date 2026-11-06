local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local ServerStorage = game:GetService("ServerStorage")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local RoleSystem = require(ServerStorage.Modules.RoleSystem)

local GiftManager = {}
local lastPromptAt = {}
local recentReceipt = {}

-- Intent gift hanya berlaku 15 menit. Harga regional bisa berubah, jadi intent
-- lama tidak boleh dipakai ulang untuk mengakali hasil verifikasi.
local INTENT_MAX_AGE = 15 * 60

local POLICY_TARGET_MISSING = "GRANT_TO_BUYER"

local INTENT_STORE_NAME = RunService:IsStudio() and "PendingGiftIntents_Studio_v1" or "PendingGiftIntents_v2"
local RECEIPT_MAP_STORE_NAME = RunService:IsStudio() and "GiftReceiptMap_Studio_v1" or "GiftReceiptMap_v2"

local intentStore = nil
local receiptMapStore = nil
local isDataStoreAvailable = false

local localMemoryQueue = {} 
local localReceiptMap = {}

local function initDataStore()
	local ok1, s1 = pcall(function()
		return DataStoreService:GetDataStore(INTENT_STORE_NAME)
	end)
	local ok2, s2 = pcall(function()
		return DataStoreService:GetDataStore(RECEIPT_MAP_STORE_NAME)
	end)
	if ok1 and s1 and ok2 and s2 then
		intentStore = s1
		receiptMapStore = s2
		isDataStoreAvailable = true
	else
		isDataStoreAvailable = false
		if not RunService:IsStudio() then
			warn("[GiftManager] ⚠️ DataStoreService tidak tersedia, menggunakan cache RAM lokal.")
		end
	end
end

initDataStore()

local function getQueueKey(giverUserId, productId)
	return string.format("queue_%s_%s", tostring(giverUserId), tostring(productId))
end

local function getReceiptKey(purchaseId)
	return string.format("rcpt_%s", tostring(purchaseId))
end

local function findGiftTypeForProduct(productId)
	if not RoleSystem.Config.GiftProducts then return nil end
	for gType, prodId in pairs(RoleSystem.Config.GiftProducts) do
		if prodId == productId then
			return gType
		end
	end
	return nil
end

local function pushIntentAtomic(giverUserId, productId, intentData)
	local qKey = getQueueKey(giverUserId, productId)
	local now = os.time()

	if not localMemoryQueue[qKey] then
		localMemoryQueue[qKey] = {}
	end
	table.insert(localMemoryQueue[qKey], intentData)

	if isDataStoreAvailable and intentStore then
		pcall(function()
			intentStore:UpdateAsync(qKey, function(oldQueue)
				oldQueue = oldQueue or {}
				local cleanQueue = {}
				for _, item in ipairs(oldQueue) do
					if type(item) == "table" and (now - (item.Timestamp or 0)) <= INTENT_MAX_AGE then
						table.insert(cleanQueue, item)
					end
				end
				table.insert(cleanQueue, intentData)
				return cleanQueue
			end)
		end)
	end
end

local function cancelLatestIntentAtomic(giverUserId, productId)
	local qKey = getQueueKey(giverUserId, productId)

	if localMemoryQueue[qKey] and #localMemoryQueue[qKey] > 0 then
		table.remove(localMemoryQueue[qKey])
	end
	if isDataStoreAvailable and intentStore then
		pcall(function()
			intentStore:UpdateAsync(qKey, function(oldQueue)
				if not oldQueue or #oldQueue == 0 then return nil end
				table.remove(oldQueue)
				return #oldQueue > 0 and oldQueue or nil
			end)
		end)
	end
	print(string.format("[GiftManager] ℹ️ Intent gift untuk giver %d produk %d dibatalkan karena prompt ditutup.", giverUserId, productId))
end

local function claimTargetForReceipt(giverUserId, productId, purchaseId, matchedGiftType)
	local qKey = getQueueKey(giverUserId, productId)
	local rKey = getReceiptKey(purchaseId)
	local now = os.time()
	if localReceiptMap[rKey] then
		return localReceiptMap[rKey]
	end
	if isDataStoreAvailable and receiptMapStore then
		local okMap, mappedTarget = pcall(function()
			return receiptMapStore:GetAsync(rKey)
		end)
		if okMap and mappedTarget then
			localReceiptMap[rKey] = mappedTarget
			return mappedTarget
		end
	end

	local claimedIntent = nil

	if isDataStoreAvailable and intentStore then
		pcall(function()
			intentStore:UpdateAsync(qKey, function(oldQueue)
				if not oldQueue or #oldQueue == 0 then return nil end
				while #oldQueue > 0 do
					local candidate = table.remove(oldQueue, 1)
					if type(candidate) == "table" and (now - (candidate.Timestamp or 0)) <= INTENT_MAX_AGE then
						claimedIntent = candidate
						break
					end
				end
				return #oldQueue > 0 and oldQueue or nil
			end)
		end)
	end

	if claimedIntent then
		local ramQueue = localMemoryQueue[qKey]
		if ramQueue then
			for i = #ramQueue, 1, -1 do
				local item = ramQueue[i]
				local sameIntent = type(item) == "table"
					and item.Timestamp == claimedIntent.Timestamp
					and item.TargetId == claimedIntent.TargetId
				if sameIntent then
					table.remove(ramQueue, i)
					break
				end
			end
		end
	end

	if not claimedIntent and localMemoryQueue[qKey] and #localMemoryQueue[qKey] > 0 then
		while #localMemoryQueue[qKey] > 0 do
			local cand = table.remove(localMemoryQueue[qKey], 1)
			if type(cand) == "table" and (now - (cand.Timestamp or 0)) <= INTENT_MAX_AGE then
				claimedIntent = cand
				break
			end
		end
	end

	if claimedIntent and claimedIntent.TargetId then
		local targetId = claimedIntent.TargetId
		localReceiptMap[rKey] = targetId
		if isDataStoreAvailable and receiptMapStore then
			pcall(function()
				receiptMapStore:SetAsync(rKey, targetId)
			end)
		end
		return targetId
	end

	return nil
end

local function setReceiptTarget(purchaseId, targetId)
	local rKey = getReceiptKey(purchaseId)
	localReceiptMap[rKey] = targetId
	if isDataStoreAvailable and receiptMapStore then
		local ok = pcall(function()
			receiptMapStore:SetAsync(rKey, targetId)
		end)
		if not ok then
			warn(string.format(
				"[GiftManager] ⚠️ Gagal menyimpan target final receipt %s ke DataStore.",
				tostring(purchaseId)
			))
		end
	end
end

local function checkRegionalPriceLevel(giverUserId, recipientUserId)
	if RunService:IsStudio() then
		return true
	end

	local success, result = pcall(function()
		return MarketplaceService:GetUsersPriceLevelsAsync({ giverUserId, recipientUserId })
	end)

	if not success or type(result) ~= "table" then
		warn(string.format("[GiftManager] ⚠️ GetUsersPriceLevelsAsync gagal: %s", tostring(result)))
		return false, "Gagal memverifikasi tingkat harga regional. Silakan coba lagi nanti."
	end

	local lookup = {}
	for _, data in ipairs(result) do
		if type(data) == "table"
			and type(data.UserId) == "number"
			and type(data.PriceLevel) == "number" then
			lookup[data.UserId] = data.PriceLevel
		end
	end

	local giverLevel = lookup[giverUserId]
	local recipientLevel = lookup[recipientUserId]

	if type(giverLevel) ~= "number" or type(recipientLevel) ~= "number"
		or giverLevel < 1 or giverLevel > 1000
		or recipientLevel < 1 or recipientLevel > 1000 then
		warn(string.format(
			"[GiftManager] ⚠️ Price level tidak lengkap: giver %d=%s, recipient %d=%s",
			giverUserId, tostring(giverLevel), recipientUserId, tostring(recipientLevel)
		))
		return false, "Gagal memverifikasi tingkat harga regional. Silakan coba lagi nanti."
	end

	if giverLevel < recipientLevel then
		warn(string.format(
			"[GiftManager] 🛡️ Regional price check diblokir: Giver %d (Level %d) < Recipient %d (Level %d)",
			giverUserId, giverLevel, recipientUserId, recipientLevel
		))
		return false, "Gift tidak dapat dikirim karena perbedaan tingkat harga regional akun."
	end

	return true
end


function GiftManager:Init(ProcessReceiptHandler)
	local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
	local promptGiftEvent = remotesFolder:FindFirstChild("PromptGift") or Instance.new("RemoteEvent")
	promptGiftEvent.Name = "PromptGift"
	promptGiftEvent.Parent = remotesFolder

	promptGiftEvent.OnServerEvent:Connect(function(giver, targetPlayer, giftType)
		if not giver or not giver.Parent then return end
		local features = RoleSystem.Config.Features or {}
		if not features.VIPGiftEnabled then return end
		if typeof(targetPlayer) ~= "Instance" or not targetPlayer:IsA("Player") then return end
		if not targetPlayer.Parent then return end
		if giver == targetPlayer then return end
		if not RoleSystem.Config.GiftProducts or not RoleSystem.Config.GiftProducts[giftType] then return end

		local productId = RoleSystem.Config.GiftProducts[giftType]
		if type(productId) ~= "number" or productId <= 0 then return end

		local now = os.clock()
		if now - (lastPromptAt[giver.UserId] or 0) < 2 then return end
		lastPromptAt[giver.UserId] = now
		local allowed, errMessage = checkRegionalPriceLevel(giver.UserId, targetPlayer.UserId)
		if not allowed then
			promptGiftEvent:FireClient(giver, false, errMessage or "Gift diblokir oleh proteksi harga regional.")
			return
		end

		if not giver.Parent or not targetPlayer.Parent then return end


		local intentData = {
			GiverId = giver.UserId,
			TargetId = targetPlayer.UserId,
			GiftType = giftType,
			ProductId = productId,
			Timestamp = os.time(),
		}

		pushIntentAtomic(giver.UserId, productId, intentData)

		MarketplaceService:PromptProductPurchase(giver, productId)
	end)

	MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId, productId, isPurchased)
		if isPurchased then return end
		local receiptKey = tostring(userId) .. ":" .. tostring(productId)
		task.delay(15, function()
			local lastReceipt = recentReceipt[receiptKey]
			if lastReceipt and (os.clock() - lastReceipt) < 15 then
				return
			end
			cancelLatestIntentAtomic(userId, productId)
		end)
	end)

	ProcessReceiptHandler:RegisterCallback("GiftSystem", function(player, productId, amount, receiptInfo)
		local matchedGiftType = findGiftTypeForProduct(productId)
		if not matchedGiftType then
			return nil
		end

		local purchaseId = receiptInfo and receiptInfo.PurchaseId or "unknown"
		recentReceipt[tostring(player.UserId) .. ":" .. tostring(productId)] = os.clock()
		local targetId = claimTargetForReceipt(player.UserId, productId, purchaseId, matchedGiftType)

		if targetId then
			-- Verifikasi ulang saat receipt: level harga bisa berubah, dan
			-- PromptProductPurchase juga bisa dipicu langsung dari client
			-- tanpa melewati pengecekan di PromptGift.
			local allowed, errMessage = checkRegionalPriceLevel(player.UserId, targetId)
			if not allowed then
				warn(string.format(
					"[GiftManager] 🛡️ Gift dialihkan ke pembeli saat receipt: giver %d -> target %d. %s",
					player.UserId, targetId, tostring(errMessage)
				))
				if player.Parent then
					promptGiftEvent:FireClient(player, false,
						"Gift tidak dapat dikirim ke penerima karena verifikasi harga regional gagal. Pass diberikan ke pembeli.")
				end
				targetId = player.UserId
				setReceiptTarget(purchaseId, targetId)
			end

			local success = RoleSystem:GivePassToPlayer(targetId, matchedGiftType, player.UserId)
			if success then
				return true
			end
			return false 
		end

		warn(string.format(
			"[GiftManager] ⚠️ Gift target tidak ditemukan untuk userId: %d | productId: %d | purchaseId: %s.",
			player.UserId, productId, tostring(purchaseId)
		))

		if POLICY_TARGET_MISSING == "GRANT_TO_BUYER" then
			warn(string.format(
				"[GiftManager] ℹ️ Kebijakan fallback aktif (%s): Memberikan pass %s ke pembeli (userId: %d) agar receipt selesai.",
				POLICY_TARGET_MISSING, matchedGiftType, player.UserId
			))
			local success = RoleSystem:GivePassToPlayer(player.UserId, matchedGiftType, player.UserId)
			if success then
				return true
			end
			return false
		else
			warn("[GiftManager] ℹ️ Receipt diselesaikan tanpa reward untuk mencegah loop NotProcessedYet.")
			return true
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastPromptAt[player.UserId] = nil
	end)
end

return GiftManager
