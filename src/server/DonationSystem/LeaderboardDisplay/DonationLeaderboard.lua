local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local UserService = game:GetService("UserService")

local DonationLeaderboard = {}
DonationLeaderboard.__index = DonationLeaderboard

local ORDERED_DATASTORE_NAME = "DonationBoard_Ordered_V2"
local ORDERED_SCOPE = "global"
local CACHE_LIFETIME = 60 -- detik

-- Cache cerdas untuk User Info (DisplayName & Username)
local userInfoCache = {}

local function resolveUserInfos(userIds)
	local missingIds = {}
	for _, id in ipairs(userIds) do
		if not userInfoCache[id] then
			local inGamePlayer = Players:GetPlayerByUserId(id)
			if inGamePlayer then
				userInfoCache[id] = {
					DisplayName = inGamePlayer.DisplayName,
					Username = inGamePlayer.Name,
				}
			else
				table.insert(missingIds, id)
			end
		end
	end

	if #missingIds > 0 then
		-- Batasi batch maksimal 100 ID per request ke UserService
		for i = 1, #missingIds, 100 do
			local batch = {}
			for j = i, math.min(i + 99, #missingIds) do
				table.insert(batch, missingIds[j])
			end

			local success, results = pcall(function()
				return UserService:GetUserInfosByUserIdsAsync(batch)
			end)

			if success and results then
				for _, info in ipairs(results) do
					userInfoCache[info.Id] = {
						DisplayName = info.DisplayName,
						Username = info.Username,
					}
				end
			end
		end

		-- Fallback untuk ID yang tidak ditemukan
		for _, id in ipairs(missingIds) do
			if not userInfoCache[id] then
				local s, name = pcall(function()
					return Players:GetNameFromUserIdAsync(id)
				end)
				if s and name then
					userInfoCache[id] = {
						DisplayName = name,
						Username = name,
					}
				else
					userInfoCache[id] = {
						DisplayName = "Player_" .. tostring(id),
						Username = "player_" .. tostring(id),
					}
				end
			end
		end
	end
end

function DonationLeaderboard.new()
	local self = setmetatable({}, DonationLeaderboard)

	self.orderedStore = DataStoreService:GetOrderedDataStore(ORDERED_DATASTORE_NAME, ORDERED_SCOPE)
	self.cachedData = nil
	self.lastFetch = 0
	self.isFetching = false

	return self
end

function DonationLeaderboard:GetTopDonors(maxEntries)
	maxEntries = maxEntries or 100

	if self.cachedData and (os.clock() - self.lastFetch) < CACHE_LIFETIME then
		return self.cachedData
	end

	if self.isFetching then
		while self.isFetching do task.wait(0.1) end
		return self.cachedData or {}
	end

	self.isFetching = true

	local success, pages = nil, nil
	for attempt = 1, 3 do
		success, pages = pcall(function()
			return self.orderedStore:GetSortedAsync(false, maxEntries)
		end)
		if success and pages then break end
		if attempt < 3 then task.wait(1) end
	end

	if not success or not pages then
		warn("[Leaderboard] Gagal menarik data dari OrderedDataStore setelah 3 percobaan (gangguan server Roblox)")
		self.isFetching = false
		return self.cachedData or {}
	end

	local donors = {}
	local pageSuccess, pageData = pcall(function() return pages:GetCurrentPage() end)

	if pageSuccess and pageData then
		local userIds = {}
		for _, entry in ipairs(pageData) do
			local uid = tonumber(entry.key)
			if uid then table.insert(userIds, uid) end
		end

		-- Tarik DisplayName dan Username asli secara cepat
		resolveUserInfos(userIds)

		local rank = 1
		for _, entry in ipairs(pageData) do
			local userId = tonumber(entry.key)
			local amount = entry.value
			local uInfo = userInfoCache[userId] or { DisplayName = "Player", Username = "user" }

			table.insert(donors, {
				UserId = userId,
				DisplayName = uInfo.DisplayName,
				Username = "@" .. uInfo.Username,
				Amount = amount,
				Rank = rank
			})
			rank = rank + 1
		end
	end

	self.cachedData = donors
	self.lastFetch = os.clock()
	self.isFetching = false
	return donors
end

function DonationLeaderboard:SetMode(useStudioField)
end

function DonationLeaderboard:GetTopDailyDonors(maxEntries)
	maxEntries = maxEntries or 100
	local dailyKey = "DonationDaily_" .. os.date("!%Y_%m_%d")
	local dailyStore = DataStoreService:GetOrderedDataStore(dailyKey, "global")

	local success, pages = nil, nil
	for attempt = 1, 3 do
		success, pages = pcall(function()
			return dailyStore:GetSortedAsync(false, maxEntries)
		end)
		if success and pages then break end
		if attempt < 3 then task.wait(1) end
	end

	if not success or not pages then
		return {}
	end

	local donors = {}
	local pageSuccess, pageData = pcall(function() return pages:GetCurrentPage() end)
	if pageSuccess and pageData then
		local userIds = {}
		for _, entry in ipairs(pageData) do
			local uid = tonumber(entry.key)
			if uid then table.insert(userIds, uid) end
		end

		resolveUserInfos(userIds)

		local rank = 1
		for _, entry in ipairs(pageData) do
			local userId = tonumber(entry.key)
			local amount = entry.value
			if amount and amount > 0 then
				local uInfo = userInfoCache[userId] or { DisplayName = "Player", Username = "user" }
				table.insert(donors, {
					UserId = userId,
					DisplayName = uInfo.DisplayName,
					Username = "@" .. uInfo.Username,
					Amount = amount,
					Rank = rank
				})
				rank = rank + 1
			end
		end
	end
	return donors
end

function DonationLeaderboard:ClearCache()
	self.cachedData = nil
	self.lastFetch = 0
end

return DonationLeaderboard