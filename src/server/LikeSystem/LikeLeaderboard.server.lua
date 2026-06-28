local DataStoreService = game:GetService("DataStoreService")
local UserService = game:GetService("UserService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ORDERED_DATASTORE_NAME = "PlayerLikes_Ordered_v1"
local MAX_PLAYERS = 30
local REFRESH_INTERVAL = 60

local OrderedLikesStore = DataStoreService:GetOrderedDataStore(ORDERED_DATASTORE_NAME)

-- Buat RemoteEvent untuk Update Client
local updateLikeBoardRemote = ReplicatedStorage:FindFirstChild("UpdateLikeBoard")
if not updateLikeBoardRemote then
	updateLikeBoardRemote = Instance.new("RemoteEvent")
	updateLikeBoardRemote.Name = "UpdateLikeBoard"
	updateLikeBoardRemote.Parent = ReplicatedStorage
end

-- Cache untuk DisplayName
local displayNameCache = {}
local cachedTopLikes = {}

local function updateLeaderboardBoard()
	-- Tarik data dari OrderedDataStore
	local success, pages = pcall(function()
		return OrderedLikesStore:GetSortedAsync(false, MAX_PLAYERS)
	end)

	if not success or not pages then
		warn("[LikeLeaderboard] Gagal menarik data likes")
		return false
	end

	local pageSuccess, pageData = pcall(function() return pages:GetCurrentPage() end)
	if not pageSuccess or not pageData then return false end

	-- Kumpulkan ID yang belum ada di cache untuk di-batch (mencegah limit API)
	local missingIds = {}
	for _, entry in ipairs(pageData) do
		local userId = tonumber(entry.key)
		local likes = entry.value
		if likes > 0 and not displayNameCache[userId] then
			local player = Players:GetPlayerByUserId(userId)
			if player then
				displayNameCache[userId] = player.DisplayName
			else
				table.insert(missingIds, userId)
			end
		end
	end

	-- Request batch ke UserService jika ada ID yang missing
	if #missingIds > 0 then
		local s, info = pcall(function()
			return UserService:GetUserInfosByUserIdsAsync(missingIds)
		end)
		if s and info then
			for _, userInfo in ipairs(info) do
				displayNameCache[userInfo.Id] = userInfo.DisplayName
			end
		end
	end

	local rank = 1
	local currentLikesData = {}
	for _, entry in ipairs(pageData) do
		local userId = tonumber(entry.key)
		local likes = entry.value

		-- Aturan: Jika like = 0, jangan ditampilin
		if likes > 0 then
			local dName = displayNameCache[userId] or ("Player_" .. tostring(userId))
			table.insert(currentLikesData, { 
				UserId = userId, 
				DisplayName = dName,
				Rank = rank, 
				Likes = likes 
			})
			rank = rank + 1
		end
	end

	_G.LikesLeaderboardData = currentLikesData
	cachedTopLikes = currentLikesData

	-- HANYA FIRING KE CLIENT, TIDAK ADA RENDER DI SERVER
	updateLikeBoardRemote:FireAllClients(currentLikesData)

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
-- KETIKA CLIENT MEMINTA DATA (Saat Baru Masuk)
-- ============================================
updateLikeBoardRemote.OnServerEvent:Connect(function(player)
	if cachedTopLikes and #cachedTopLikes > 0 then
		pcall(function()
			updateLikeBoardRemote:FireClient(player, cachedTopLikes)
		end)
	end
end)

local function startLeaderboardLoop()
	-- Beri jeda 15 detik di awal agar tidak berbarengan/bentrok dengan Auto-Save LikeManager
	task.wait(15)
	
	-- Loop terus menerus
	while true do
		pcall(updateLeaderboardBoard)
		task.wait(REFRESH_INTERVAL)
	end
end

-- Jalankan di background thread
task.spawn(startLeaderboardLoop)
