local DataStoreService = game:GetService("DataStoreService")
local DonationConfig   = require(script.Parent.DonationConfig)

local DonationDataStore = {}

-- DATASTORE INSTANCES
local dataStore = DataStoreService:GetDataStore(
	DonationConfig.DATASTORE.NAME,
	DonationConfig.DATASTORE.SCOPE
)

-- 🔥 ARCHITECT FIX: ORDERED DATA STORE (Khusus untuk Papan Leaderboard 3D)
local orderedDataStore = DataStoreService:GetOrderedDataStore("DonationBoard_Ordered", "global")

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

function DonationDataStore:UpdatePlayerDonation(player, amount)
	local userIdStr = "Player_" .. tostring(player.UserId)

	-- 1. Update di Memory (Instant Feedback)
	local cache = PlayerDataCache[userIdStr]
	if cache then
		cache.DisplayName = player.DisplayName
		cache[DonationConfig.DONATION_FIELD] = (cache[DonationConfig.DONATION_FIELD] or 0) + amount
	end

	-- 2. Simpan ke Database asli dan Papan Peringkat
	task.spawn(function()
		local totalAmount = 0

		for attempt = 1, 3 do
			local ok, err = pcall(function()
				dataStore:UpdateAsync(userIdStr, function(current)
					current = current or {
						DisplayName = player.DisplayName,
						["Donated - Studio"] = 0,
						["Donated - Experience"] = 0,
					}
					current.DisplayName = player.DisplayName
					current[DonationConfig.DONATION_FIELD] = (current[DonationConfig.DONATION_FIELD] or 0) + amount

					-- Hitung total gabungan untuk papan
					totalAmount = (current["Donated - Studio"] or 0) + (current["Donated - Experience"] or 0)

					return current
				end)
			end)

			if ok then
				debugLog("DATASTORE", "Berhasil disimpan untuk", player.Name)

				-- 🔥 ARCHITECT FIX: Setor Laporan ke Papan Peringkat 3D (OrderedDataStore)
				pcall(function()
					orderedDataStore:SetAsync(tostring(player.UserId), totalAmount)
				end)

				break
			else
				task.wait(2)
			end
		end
	end)

	return true
end

function DonationDataStore:CleanupPlayer(player)
	local userIdStr = "Player_" .. tostring(player.UserId)
	PlayerDataCache[userIdStr] = nil 
	debugLog("DATASTORE", "Cleanup selesai untuk:", player.Name)
end

return DonationDataStore