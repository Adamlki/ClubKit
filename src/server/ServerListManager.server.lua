-- ============================================================
-- ServerListManager (ClubKit Server Discovery & Teleportation)
-- ============================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local RunService = game:GetService("RunService")

local serverStartTime = os.time()
local isStudio = RunService:IsStudio()

-- Setup Remotes
local remotesFolder = ReplicatedStorage:FindFirstChild("ServerListRemotes")
if not remotesFolder then
	remotesFolder = Instance.new("Folder")
	remotesFolder.Name = "ServerListRemotes"
	remotesFolder.Parent = ReplicatedStorage
end

local getServerListRF = remotesFolder:FindFirstChild("GetServerList")
if not getServerListRF then
	getServerListRF = Instance.new("RemoteFunction")
	getServerListRF.Name = "GetServerList"
	getServerListRF.Parent = remotesFolder
end

local teleportToServerRF = remotesFolder:FindFirstChild("TeleportToServer")
if not teleportToServerRF then
	teleportToServerRF = Instance.new("RemoteFunction")
	teleportToServerRF.Name = "TeleportToServer"
	teleportToServerRF.Parent = remotesFolder
end

-- Flag untuk dummy server (set false agar HANYA menampilkan server ASLI yang aktif)
local ENABLE_DUMMY_SERVERS = false

-- Server Identity
local actualJobId = (game.JobId ~= "") and game.JobId or "STUDIO-SESSION"
local shortId = (game.JobId ~= "") and string.upper(string.sub(game.JobId, -5)) or "2417E"
local thisServerName = "SERVER " .. shortId

local function getPlayerUserIds()
	local ids = {}
	for _, p in ipairs(Players:GetPlayers()) do
		table.insert(ids, p.UserId)
		if #ids >= 5 then break end
	end
	return ids
end

local function formatDuration(seconds)
	local h = math.floor(seconds / 3600)
	local m = math.floor((seconds % 3600) / 60)
	local s = seconds % 60
	return string.format("%02dh %02dm %02ds", h, m, s)
end

local function getCurrentServerData()
	local uptimeSec = os.time() - serverStartTime
	local playersCount = #Players:GetPlayers()
	local maxP = Players.MaxPlayers > 0 and Players.MaxPlayers or 80

	return {
		jobId = actualJobId,
		name = thisServerName,
		isCurrent = true,
		playing = playersCount,
		maxPlayers = maxP,
		location = "Indonesia",
		uptime = formatDuration(uptimeSec),
		average = formatDuration(math.max(15, math.floor(uptimeSec * 0.95))),
		version = tostring(game.PlaceVersion),
		created = os.date("%d %b %Y", serverStartTime),
		playerUserIds = getPlayerUserIds(),
		status = "PLAYING",
	}
end

-- ============================================================
-- MEMORY STORE REGISTRATION (Cross-server discovery)
-- ============================================================
local memoryMap = nil
pcall(function()
	memoryMap = MemoryStoreService:GetSortedMap("ClubKit_ActiveServers_v1")
end)

local function updateServerHeartbeat()
	if not memoryMap then return end
	pcall(function()
		local data = getCurrentServerData()
		-- Expire after 45 seconds if no heartbeat
		memoryMap:SetAsync(actualJobId, data, 45)
	end)
end

task.spawn(function()
	while true do
		updateServerHeartbeat()
		task.wait(20)
	end
end)

game:BindToClose(function()
	if memoryMap then
		pcall(function()
			memoryMap:RemoveAsync(actualJobId)
		end)
	end
end)

-- Mock / Realistic discovery servers for demonstration & testing
local DEMO_SERVERS = {
	{
		idSuffix = "25D81",
		playing = 80,
		maxPlayers = 80,
		uptimeSec = 33041,
		avgSec = 1724,
		version = "1242",
		daysAgo = 1,
		playerUserIds = { 1, 2, 3, 4 },
	},
	{
		idSuffix = "76203",
		playing = 80,
		maxPlayers = 80,
		uptimeSec = 44112,
		avgSec = 1101,
		version = "1242",
		daysAgo = 1,
		playerUserIds = { 5, 6, 7, 8 },
	},
	{
		idSuffix = "9D82F",
		playing = 80,
		maxPlayers = 80,
		uptimeSec = 77089,
		avgSec = 2269,
		version = "1233",
		daysAgo = 1,
		playerUserIds = { 9, 10, 11, 12 },
	},
	{
		idSuffix = "D75B8",
		playing = 80,
		maxPlayers = 80,
		uptimeSec = 119318,
		avgSec = 2343,
		version = "1233",
		daysAgo = 2,
		playerUserIds = { 13, 14, 15, 16 },
	},
	{
		idSuffix = "ADCE4",
		playing = 79,
		maxPlayers = 80,
		uptimeSec = 75991,
		avgSec = 1532,
		version = "1233",
		daysAgo = 1,
		playerUserIds = { 17, 18, 19, 20 },
	},
	{
		idSuffix = "05487",
		playing = 78,
		maxPlayers = 80,
		uptimeSec = 79714,
		avgSec = 1728,
		version = "1233",
		daysAgo = 1,
		playerUserIds = { 21, 22, 23, 24 },
	},
	{
		idSuffix = "5A785",
		playing = 77,
		maxPlayers = 80,
		uptimeSec = 76415,
		avgSec = 1299,
		version = "1233",
		daysAgo = 1,
		playerUserIds = { 25, 26, 27, 28 },
	},
}

local function getDiscoveryServers()
	local list = {}
	local thisServer = getCurrentServerData()
	table.insert(list, thisServer)

	-- Ambil daftar server nyata antar-instance dari MemoryStore
	local foundCrossServers = false
	if memoryMap then
		local ok, items = pcall(function()
			return memoryMap:GetRangeAsync(Enum.SortDirection.Descending, 100)
		end)
		if ok and items and #items > 0 then
			for _, item in ipairs(items) do
				if item.key ~= actualJobId and item.value and type(item.value) == "table" then
					local sData = item.value
					sData.isCurrent = false
					if (sData.playing or 0) >= (sData.maxPlayers or 80) then
						sData.status = "FULL"
					else
						sData.status = "JOIN"
					end
					table.insert(list, sData)
					foundCrossServers = true
				end
			end
		end
	end

	-- Dummy servers hanya dimuat jika ENABLE_DUMMY_SERVERS diaktifkan secara eksplisit
	if ENABLE_DUMMY_SERVERS and not foundCrossServers then
		for _, mock in ipairs(DEMO_SERVERS) do
			local createdTime = serverStartTime - (mock.daysAgo * 86400)
			local status = (mock.playing >= mock.maxPlayers) and "FULL" or "JOIN"
			table.insert(list, {
				jobId = "MOCK-JOBID-" .. mock.idSuffix,
				name = "SERVER " .. mock.idSuffix,
				isCurrent = false,
				playing = mock.playing,
				maxPlayers = mock.maxPlayers,
				location = "Indonesia",
				uptime = formatDuration(mock.uptimeSec),
				average = formatDuration(mock.avgSec),
				version = mock.version,
				created = os.date("%d %b %Y", createdTime),
				playerUserIds = mock.playerUserIds,
				status = status,
			})
		end
	end

	return list
end

-- ============================================================
-- REMOTE CALLBACKS
-- ============================================================
getServerListRF.OnServerInvoke = function(player)
	return getDiscoveryServers()
end

teleportToServerRF.OnServerInvoke = function(player, targetJobId)
	if not targetJobId or targetJobId == actualJobId then
		return false, "Anda sudah berada di dalam server ini."
	end

	if isStudio then
		return false, "Teleportasi hanya dapat dilakukan di dalam game publik Roblox (Fitur simulasi di Studio)."
	end

	local targetPlaceId = game.PlaceId
	local ok, err = pcall(function()
		TeleportService:TeleportToPlaceInstance(targetPlaceId, targetJobId, player)
	end)

	if not ok then
		return false, "Gagal melakukan teleportasi: " .. tostring(err)
	end

	return true, "Sedang memindahkan Anda ke server..."
end

print("[ServerListManager] Initialized successfully.")
