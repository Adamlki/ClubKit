local DataStoreService = game:GetService("DataStoreService")
local DonationConfig   = require(script.Parent.DonationConfig)

local DonationDataStore = {}

-- DATASTORE INSTANCES
local dataStore = DataStoreService:GetDataStore(
	DonationConfig.DATASTORE.NAME,
	DonationConfig.DATASTORE.SCOPE
)

-- 🔥 ARCHITECT FIX: ORDERED DATA STORE (Khusus untuk Papan Leaderboard 3D)
local orderedDataStore = DataStoreService:GetOrderedDataStore("DonationBoard_Ordered_V2", "global")

local PlayerDataCache = {} 

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
	
	-- 🔥 ARCHITECT FIX: Cache info penting SEBELUM yield (UpdateAsync).
	-- Jika pemain leave saat loading, object player akan terhapus dan error!
	local safeUserId = tostring(player.UserId)
	local safePlayerName = player.Name
	local safeDisplayName = player.DisplayName
	
	local saveSuccess = false
	local isNewReceipt = true
	local totalAmount = 0

	-- 1. Simpan ke Database asli (Synchronous agar bisa return sukses/gagal ke ProcessReceipt)
	for attempt = 1, 3 do
		local ok, err = pcall(function()
			dataStore:UpdateAsync(userIdStr, function(current)
				isNewReceipt = true
				current = current or {
					DisplayName = safeDisplayName,
					["Donated - Studio"] = 0,
					["Donated - Experience"] = 0,
					ProcessedReceipts = {}
				}
				current.ProcessedReceipts = current.ProcessedReceipts or {}

				-- IDEMPOTENSI: Jika receipt sudah ada di DataStore, abaikan penambahan amount
				if receiptInfo and receiptInfo.PurchaseId then
					if current.ProcessedReceipts[receiptInfo.PurchaseId] then
						totalAmount = (current["Donated - Studio"] or 0) + (current["Donated - Experience"] or 0)
						isNewReceipt = false
						return current
					end
					current.ProcessedReceipts[receiptInfo.PurchaseId] = os.time()

					-- Hapus receipt lama (3 hari) agar batas kuota DataStore tidak jebol
					local now = os.time()
					for pid, time in pairs(current.ProcessedReceipts) do
						if now - time > 86400 * 3 then
							current.ProcessedReceipts[pid] = nil
						end
					end
				end

				current.DisplayName = safeDisplayName
				current[DonationConfig.DONATION_FIELD] = (current[DonationConfig.DONATION_FIELD] or 0) + amount
				totalAmount = (current["Donated - Studio"] or 0) + (current["Donated - Experience"] or 0)

				return current
			end)
		end)

		if ok then
			debugLog("DATASTORE", "Berhasil disimpan untuk", safePlayerName)
			saveSuccess = true
			break
		else
			task.wait(2)
		end
	end

	if saveSuccess then
		-- Update Memory Cache
		local cache = PlayerDataCache[userIdStr]
		if cache then
			cache.DisplayName = safeDisplayName
			cache[DonationConfig.DONATION_FIELD] = (cache[DonationConfig.DONATION_FIELD] or 0) + amount
		end

		-- 2. Papan Peringkat 3D (Dengan Sistem Retry Mandiri)
		task.spawn(function()
			local safeAmount = math.floor(totalAmount)
			for attempt = 1, 3 do
				local ok = pcall(function()
					orderedDataStore:SetAsync(safeUserId, safeAmount)
				end)
				if ok then break end
				task.wait(2)
			end
		end)
	end

	return saveSuccess, isNewReceipt
end

function DonationDataStore:CleanupPlayer(player)
	local userIdStr = "Player_" .. tostring(player.UserId)
	PlayerDataCache[userIdStr] = nil 
	debugLog("DATASTORE", "Cleanup selesai untuk:", player.Name)
end

return DonationDataStore