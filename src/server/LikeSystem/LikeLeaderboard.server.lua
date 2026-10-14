local DataStoreService = game:GetService("DataStoreService")
local UserService = game:GetService("UserService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ORDERED_DATASTORE_NAME = "PlayerLikes_Ordered_v1"
local MAX_PLAYERS = 30
local REFRESH_INTERVAL = 120

local OrderedLikesStore = DataStoreService:GetOrderedDataStore(ORDERED_DATASTORE_NAME)

-- Buat RemoteEvent untuk Update Client
local updateLikeBoardRemote = ReplicatedStorage:FindFirstChild("UpdateLikeBoard")
if not updateLikeBoardRemote then
	updateLikeBoardRemote = Instance.new("RemoteEvent")
	updateLikeBoardRemote.Name = "UpdateLikeBoard"
	updateLikeBoardRemote.Parent = ReplicatedStorage
end

-- Cache untuk UserInfo (DisplayName & Username)
local userInfoCache = {}
local cachedTopLikes = {
	AllTime = {},
	Daily = {},
}

local function resolveUserInfos(userIds)
	local missingIds = {}
	for _, id in ipairs(userIds) do
		if not userInfoCache[id] then
			local player = Players:GetPlayerByUserId(id)
			if player then
				userInfoCache[id] = {
					DisplayName = player.DisplayName,
					Username = player.Name,
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

		-- Fallback untuk ID yang tidak ditemukan oleh UserService (moderasi, banned, atau privasi)
		for _, id in ipairs(missingIds) do
			if not userInfoCache[id] then
				local s, name = pcall(function()
					return Players:GetNameFromUserIdAsync(id)
				end)
				if s and name and name ~= "" then
					userInfoCache[id] = {
						DisplayName = name,
						Username = name,
					}
				else
					userInfoCache[id] = {
						DisplayName = "Player",
						Username = "player_" .. tostring(id),
					}
				end
			end
		end
	end
end

local function fetchOrderedLikes(store)
	local success, pages = pcall(function()
		return store:GetSortedAsync(false, MAX_PLAYERS)
	end)

	if not success or not pages then
		return {}
	end

	local pageSuccess, pageData = pcall(function() return pages:GetCurrentPage() end)
	if not pageSuccess or not pageData then return {} end

	local userIds = {}
	for _, entry in ipairs(pageData) do
		local userId = tonumber(entry.key)
		local likes = entry.value
		if userId and likes and likes > 0 then
			table.insert(userIds, userId)
		end
	end

	resolveUserInfos(userIds)

	local rank = 1
	local results = {}
	for _, entry in ipairs(pageData) do
		local userId = tonumber(entry.key)
		local likes = entry.value
		if userId and likes and likes > 0 then
			local uInfo = userInfoCache[userId] or { DisplayName = "Player", Username = "player" }
			table.insert(results, {
				UserId = userId,
				DisplayName = uInfo.DisplayName,
				Username = "@" .. uInfo.Username,
				Rank = rank,
				Likes = likes,
			})
			rank = rank + 1
		end
	end
	return results
end

local function isDataDifferent(oldPayload, newPayload)
	if not oldPayload or not newPayload then return true end
	local oldAll = oldPayload.AllTime or {}
	local newAll = newPayload.AllTime or {}
	if #oldAll ~= #newAll then return true end
	for i = 1, math.min(10, #newAll) do
		local o, n = oldAll[i], newAll[i]
		if not o or not n then return true end
		if (o.UserId or o.userId) ~= (n.UserId or n.userId) or (o.Likes or o.likes) ~= (n.Likes or n.likes) then
			return true
		end
	end
	local oldDaily = oldPayload.Daily or {}
	local newDaily = newPayload.Daily or {}
	if #oldDaily ~= #newDaily then return true end
	for i = 1, math.min(10, #newDaily) do
		local o, n = oldDaily[i], newDaily[i]
		if not o or not n then return true end
		if (o.UserId or o.userId) ~= (n.UserId or n.userId) or (o.Likes or o.likes) ~= (n.Likes or n.likes) then
			return true
		end
	end
	return false
end

local function updateLeaderboardBoard()
	local allTimeLikes = fetchOrderedLikes(OrderedLikesStore)
	local dailyKey = "PlayerLikes_Daily_" .. os.date("!%Y_%m_%d")
	local dailyStore = DataStoreService:GetOrderedDataStore(dailyKey)
	local dailyLikes = fetchOrderedLikes(dailyStore)

	local newPayload = {
		AllTime = allTimeLikes,
		Daily   = dailyLikes,
	}

	local hasChanged = isDataDifferent(cachedTopLikes, newPayload)
	cachedTopLikes = newPayload
	_G.LikesLeaderboardData = allTimeLikes

	-- HANYA FIRING JIKA ADA PERUBAHAN DATA (0% Trafik jika tidak ada like baru)
	if hasChanged then
		updateLikeBoardRemote:FireAllClients(cachedTopLikes)
	end

	-- [PERBAIKAN]: Otomatis refresh Overhead semua pemain setiap kali data Leaderboard selesai ditarik.
	task.spawn(function()
		local success2, OverheadManager = pcall(function()
			return require(game:GetService("ServerScriptService").OverheadSystem.OverheadSystemServer.OverheadManager)
		end)
		if success2 and OverheadManager then
			for _, player in ipairs(Players:GetPlayers()) do
				pcall(function()
					OverheadManager:UpdateDonaturRank(player)
				end)
			end
		end
	end)

	return true
end

-- ============================================
-- KETIKA CLIENT MEMINTA DATA (Saat Baru Masuk - Rate Limited)
-- ============================================
local requestCooldowns = {}
local REQUEST_COOLDOWN = 5

updateLikeBoardRemote.OnServerEvent:Connect(function(player)
	if not player or not player.Parent then return end
	local now = os.clock()
	if now - (requestCooldowns[player.UserId] or 0) < REQUEST_COOLDOWN then
		return -- Ignore spam requests
	end
	requestCooldowns[player.UserId] = now

	if not cachedTopLikes or not cachedTopLikes.AllTime or #cachedTopLikes.AllTime == 0 then
		pcall(updateLeaderboardBoard)
	end
	if cachedTopLikes and cachedTopLikes.AllTime and #cachedTopLikes.AllTime > 0 then
		pcall(function()
			updateLikeBoardRemote:FireClient(player, cachedTopLikes)
		end)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	requestCooldowns[player.UserId] = nil
end)

-- Export ke LeaderboardOrchestrator (Round-Robin centralized scheduler)
_G.UpdateLikeLeaderboard = function()
	pcall(updateLeaderboardBoard)
end
