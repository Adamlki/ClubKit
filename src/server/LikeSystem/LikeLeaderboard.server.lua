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

local function updateLeaderboardBoard()
	local allTimeLikes = fetchOrderedLikes(OrderedLikesStore)
	local dailyKey = "PlayerLikes_Daily_" .. os.date("!%Y_%m_%d")
	local dailyStore = DataStoreService:GetOrderedDataStore(dailyKey)
	local dailyLikes = fetchOrderedLikes(dailyStore)

	_G.LikesLeaderboardData = allTimeLikes
	cachedTopLikes = {
		AllTime = allTimeLikes,
		Daily   = dailyLikes,
	}

	-- HANYA FIRING KE CLIENT, TIDAK ADA RENDER DI SERVER
	updateLikeBoardRemote:FireAllClients(cachedTopLikes)

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

local function startLeaderboardLoop()
	task.wait(2) -- Quick initial fetch on server start
	pcall(updateLeaderboardBoard)
	
	-- Loop terus menerus
	while true do
		task.wait(REFRESH_INTERVAL)
		pcall(updateLeaderboardBoard)
	end
end

-- Jalankan di background thread
task.spawn(startLeaderboardLoop)
