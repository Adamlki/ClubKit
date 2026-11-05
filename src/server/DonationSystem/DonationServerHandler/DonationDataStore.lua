local DataStoreService = game:GetService("DataStoreService")
local DonationConfig   = require(script.Parent.DonationConfig)

local DonationDataStore = {}

local dataStore = DataStoreService:GetDataStore(
	DonationConfig.DATASTORE.NAME,
	DonationConfig.DATASTORE.SCOPE
)

local orderedDataStore = DataStoreService:GetOrderedDataStore("DonationBoard_Ordered_V2", "global")

local PlayerDataCache = {}
local pendingBoardWrites = 0

local function debugLog(category, ...)
	if not DonationConfig.DEBUG.ENABLED then return end
	print("[DATASTORE]", ...)
end

function DonationDataStore:LoadPlayerDonation(player)
	local userIdStr = "Player_" .. tostring(player.UserId)

	if PlayerDataCache[userIdStr] then return PlayerDataCache[userIdStr] end

	local data = nil
	for attempt = 1, 3 do
		local ok, result = pcall(function()
			return dataStore:GetAsync(userIdStr)
		end)
		if ok then
			data = result or {
				DisplayName = player.DisplayName,
				["Donated - Studio"] = 0,
				["Donated - Experience"] = 0,
			}
			PlayerDataCache[userIdStr] = data 
			return data
		else
			task.wait(1)
		end
	end
	return data
end

function DonationDataStore:GetPlayerDonation(userId)
	local userIdStr = "Player_" .. tostring(userId)
	return PlayerDataCache[userIdStr] 
end

function DonationDataStore:UpdatePlayerDonation(player, amount, receiptInfo)
	if DonationConfig.IS_STUDIO then
		debugLog("DATASTORE", "Test di Studio: Mengabaikan penyimpanan DataStore dan Papan Peringkat")
		return true, true
	end

	local userIdStr = "Player_" .. tostring(player.UserId)
	local safeUserId = tostring(player.UserId)
	local safePlayerName = player.Name
	local safeDisplayName = player.DisplayName
	local saveSuccess = false
	local isNewReceipt = true
	local totalAmount = 0

	for attempt = 1, 3 do
		local ok, updatedData = pcall(function()
			return dataStore:UpdateAsync(userIdStr, function(current)
				isNewReceipt = true
				current = current or {
					DisplayName = safeDisplayName,
					["Donated - Studio"] = 0,
					["Donated - Experience"] = 0,
					ProcessedReceipts = {}
				}
				current.ProcessedReceipts = current.ProcessedReceipts or {}

				if receiptInfo and receiptInfo.PurchaseId then
					if current.ProcessedReceipts[receiptInfo.PurchaseId] then
						isNewReceipt = false
						return current
					end
					current.ProcessedReceipts[receiptInfo.PurchaseId] = os.time()
					local now = os.time()
					for pid, time in pairs(current.ProcessedReceipts) do
						if now - time > 86400 * 3 then
							current.ProcessedReceipts[pid] = nil
						end
					end
				end

				current.DisplayName = safeDisplayName
				current[DonationConfig.DONATION_FIELD] = (current[DonationConfig.DONATION_FIELD] or 0) + amount

				return current
			end)
		end)

		if ok then
			debugLog("DATASTORE", "Berhasil disimpan untuk", safePlayerName)
			saveSuccess = true
			if updatedData then
				totalAmount = (updatedData["Donated - Studio"] or 0) + (updatedData["Donated - Experience"] or 0)
			end
			break
		else
			task.wait(2)
		end
	end

	if saveSuccess then
		if isNewReceipt then
			local cache = PlayerDataCache[userIdStr]
			if cache then
				cache.DisplayName = safeDisplayName
				cache[DonationConfig.DONATION_FIELD] = (cache[DonationConfig.DONATION_FIELD] or 0) + amount
			end

			pendingBoardWrites += 1
			task.spawn(function()
				local safeAmount = math.floor(totalAmount)
				for attempt = 1, 3 do
					local ok = pcall(function()
						orderedDataStore:SetAsync(safeUserId, safeAmount)
					end)
					if ok then break end
					task.wait(2)
				end

				local dailyKey = "DonationDaily_" .. os.date("!%Y_%m_%d")
				local dailyStore = DataStoreService:GetOrderedDataStore(dailyKey, "global")
				for attempt = 1, 3 do
					local ok = pcall(function()
						dailyStore:IncrementAsync(safeUserId, math.floor(amount))
					end)
					if ok then break end
					task.wait(2)
				end
				pendingBoardWrites = math.max(0, pendingBoardWrites - 1)
			end)
		else
			debugLog("DATASTORE", "Receipt sudah pernah diproses sebelumnya. Melewati penambahan Daily & Cache.")
		end
	end

	return saveSuccess, isNewReceipt
end

function DonationDataStore:FlushBoardWrites(timeout)
	local started = os.clock()
	local limit = timeout or 8
	while pendingBoardWrites > 0 and (os.clock() - started) < limit do
		task.wait(0.1)
	end
	return pendingBoardWrites == 0
end

function DonationDataStore:CleanupPlayer(player)
	local userIdStr = "Player_" .. tostring(player.UserId)
	PlayerDataCache[userIdStr] = nil 
	debugLog("DATASTORE", "Cleanup selesai untuk:", player.Name)
end

return DonationDataStore
