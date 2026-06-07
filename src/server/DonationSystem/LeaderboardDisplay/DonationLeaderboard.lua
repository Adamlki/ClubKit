local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local DonationLeaderboard = {}
DonationLeaderboard.__index = DonationLeaderboard

-- Targetkan ke OrderedDataStore yang baru kita buat di DonationDataStore.luau
local ORDERED_DATASTORE_NAME = "DonationBoard_Ordered"
local ORDERED_SCOPE = "global"
local CACHE_LIFETIME = 60 -- detik

-- Cache nama cerdas untuk menghindari limit API Roblox
local userNameCache = {}

local function getPlayerName(userId)
	if userNameCache[userId] then return userNameCache[userId] end
	local success, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	if success and name then
		userNameCache[userId] = name
		return name
	end
	return "Sultan_" .. tostring(userId)
end

function DonationLeaderboard.new()
	local self = setmetatable({}, DonationLeaderboard)

	self.orderedStore = DataStoreService:GetOrderedDataStore(ORDERED_DATASTORE_NAME, ORDERED_SCOPE)
	self.cachedData = nil
	self.lastFetch = 0

	return self
end

function DonationLeaderboard:GetTopDonors(maxEntries)
	maxEntries = maxEntries or 100

	-- Cek Cache agar tidak spam API
	if self.cachedData and (os.clock() - self.lastFetch) < CACHE_LIFETIME then
		return self.cachedData
	end

	-- Tarik langsung dari OrderedDataStore dengan cepat! (false = descending / terbesar di atas)
	local success, pages = pcall(function()
		return self.orderedStore:GetSortedAsync(false, maxEntries)
	end)

	if not success or not pages then
		warn("[Leaderboard] Gagal menarik data dari OrderedDataStore")
		return self.cachedData or {}
	end

	local donors = {}
	local rank = 1

	local pageSuccess, pageData = pcall(function() return pages:GetCurrentPage() end)

	if pageSuccess and pageData then
		for _, entry in ipairs(pageData) do
			local userId = tonumber(entry.key)
			local amount = entry.value

			table.insert(donors, {
				UserId = userId,
				DisplayName = getPlayerName(userId),
				Amount = amount,
				Rank = rank
			})
			rank = rank + 1
		end
	end

	self.cachedData = donors
	self.lastFetch = os.clock()
	return donors
end

function DonationLeaderboard:SetMode(useStudioField)
	-- Fungsi ini sengaja dikosongkan agar skrip LeaderboardDisplay.luau tidak error 
	-- Kita sudah menyatukan hitungan Studio & Experience menjadi satu total di OrderedDataStore
end

function DonationLeaderboard:ClearCache()
	self.cachedData = nil
	self.lastFetch = 0
end

return DonationLeaderboard