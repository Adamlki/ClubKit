local LevelSystem = {}

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

-- 🔥 ARCHITECT FIX: Panggil RoleSystem
local RoleSystem = require(ServerStorage:WaitForChild("Modules"):WaitForChild("RoleSystem"))

-- ====================================
-- CONFIGURATION
-- ====================================
LevelSystem.Config = {
	DATASTORE_NAME = "PlayerLevel_v1",
	DATASTORE_PREFIX = "Level_",
	DATASTORE_RETRY_ATTEMPTS = 5,
	DATASTORE_RETRY_DELAY = 1.5,

	-- Anti-Spam Save (Dalam Detik)
	SAVE_COOLDOWN = 60,

	LEADERBOARD_STORE_NAME = "PlayerLevels_Leaderboard_v1",

	-- 🔥 ARCHITECT FIX: Daftar Role yang disembunyikan dari Leaderboard
	EXCLUDED_ROLES = {
		["Owner"] = true,
		["Admin"] = true,
		["Moderator"] = true,
	},

	LEVEL_UP_INTERVAL = 900, -- 15 menit (900 detik)
	DEFAULT_LEVEL = 1,
	MAX_LEVEL = nil, -- nil = no limit

	DEBUG_ENABLED = false
}

-- ====================================
-- SERVICES
-- ====================================
local LevelDataStore = DataStoreService:GetDataStore(LevelSystem.Config.DATASTORE_NAME)
local LeaderboardStore = DataStoreService:GetOrderedDataStore(LevelSystem.Config.LEADERBOARD_STORE_NAME)

-- ====================================
-- CACHE & TIMERS
-- ====================================
local playerLevelCache = {}
local playerTimers = {}
local activeConnections = {}
local saveCooldowns = {}
local loadingLocks = {}
local activeSaves = {} -- FIX KELUAR-MASUK CEPAT: Tahan LoadPlayerLevel jika sesi sebelumnya sedang proses SetAsync
local lastSyncedLevel = {} -- 100-PLAYER OPTIMIZATION: Cegah penulisan OrderedDataStore berulang jika level belum berubah

-- ====================================
-- EVENTS
-- ====================================
local levelUpEvent = Instance.new("BindableEvent")
levelUpEvent.Name = "LevelUp"
LevelSystem.LevelUp = levelUpEvent.Event

-- ====================================
-- DEBUG SYSTEM
-- ====================================
local function debug(...)
	if LevelSystem.Config.DEBUG_ENABLED then
		print("[LevelSystem]", ...)
	end
end

local function debugWarn(...)
	if LevelSystem.Config.DEBUG_ENABLED then
		warn("[LevelSystem]", ...)
	end
end

-- ====================================
-- DATASTORE OPERATIONS (WITH EXPONENTIAL BACKOFF)
-- ====================================
local function datastoreGetAsync(key)
	for attempt = 1, LevelSystem.Config.DATASTORE_RETRY_ATTEMPTS do
		local success, result = pcall(function()
			return LevelDataStore:GetAsync(key)
		end)
		if success then return true, result end
		if attempt < LevelSystem.Config.DATASTORE_RETRY_ATTEMPTS then
			task.wait(LevelSystem.Config.DATASTORE_RETRY_DELAY * attempt)
		end
	end
	debugWarn("Failed to load data for key:", key)
	return false, nil
end

local function datastoreSetAsync(key, value)
	for attempt = 1, LevelSystem.Config.DATASTORE_RETRY_ATTEMPTS do
		local success = pcall(function()
			LevelDataStore:SetAsync(key, value)
		end)
		if success then return true end
		if attempt < LevelSystem.Config.DATASTORE_RETRY_ATTEMPTS then
			task.wait(LevelSystem.Config.DATASTORE_RETRY_DELAY * attempt)
		end
	end
	debugWarn("Failed to save data for key:", key)
	return false
end

-- ====================================
-- LEADERBOARD SYNC (DENGAN DIRTY-CHECK KUOTA ORDERED DATASTORE)
-- ====================================
local function syncLeaderboard(player, level)
	local userId = player.UserId

	-- Jika level belum berubah sejak sync terakhir di sesi ini, hemat kuota OrderedDataStore!
	if lastSyncedLevel[userId] == level then
		return
	end

	local role = RoleSystem:GetPlayerRole(player)
	if LevelSystem.Config.EXCLUDED_ROLES[role] then
		debugWarn("Pemain " .. player.Name .. " (" .. role .. ") di-exclude dari Leaderboard.")
		lastSyncedLevel[userId] = level
		pcall(function() LeaderboardStore:RemoveAsync(tostring(userId)) end)
		return
	end

	lastSyncedLevel[userId] = level

	task.spawn(function()
		for attempt = 1, LevelSystem.Config.DATASTORE_RETRY_ATTEMPTS do
			local success = pcall(function()
				LeaderboardStore:SetAsync(tostring(userId), level)
			end)
			if success then
				debug("Leaderboard synced: User", userId, "Level", level)
				return
			end
			if attempt < LevelSystem.Config.DATASTORE_RETRY_ATTEMPTS then
				task.wait(LevelSystem.Config.DATASTORE_RETRY_DELAY * attempt)
			end
		end
	end)
end

function LevelSystem:GetTopPlayers(count)
	count = count or 100
	local success, pages = pcall(function() return LeaderboardStore:GetSortedAsync(false, count) end)
	if not success or not pages then return {} end

	local ok, data = pcall(function() return pages:GetCurrentPage() end)
	if not ok or not data then return {} end

	local results = {}
	for rank, entry in ipairs(data) do
		table.insert(results, { rank = rank, userId = tonumber(entry.key), level = entry.value })
	end
	return results
end

-- ====================================
-- LEVEL DATA MANAGEMENT
-- ====================================
function LevelSystem:LoadPlayerLevel(player)
	local userId = player.UserId

	-- FIX KELUAR-MASUK CEPAT / AUTO-REJOIN AFK:
	-- Tunggu jika proses save dari sesi sebelumnya masih berjalan agar cache baru tidak terhapus!
	local saveWait = 0
	while activeSaves[userId] and saveWait < 10 do
		saveWait += task.wait(0.1)
	end

	if playerLevelCache[userId] then
		return playerLevelCache[userId].Level
	end

	if loadingLocks[userId] then
		local lockWait = 0
		repeat
			lockWait += task.wait(0.05)
		until not loadingLocks[userId] or lockWait >= 15
		if playerLevelCache[userId] then
			return playerLevelCache[userId].Level
		end
	end

	loadingLocks[userId] = true
	local key = self.Config.DATASTORE_PREFIX .. tostring(userId)

	local success, data = datastoreGetAsync(key)
	loadingLocks[userId] = nil

	if not player or not player.Parent then
		debugWarn("Pemain keluar sebelum data selesai dimuat. Membatalkan inisialisasi memori.")
		return self.Config.DEFAULT_LEVEL
	end

	-- FIX MASUK BARENGAN 100 PEMAIN:
	-- Jangan langsung Kick pemain jika DataStore Roblox sedang padat/throttling!
	-- Gunakan mode ReadOnlyFallback (tidak akan menimpa DataStore saat keluar sampai data asli berhasil dimuat di background).
	if not success then
		warn("[LevelSystem] DataStore sibuk saat memuat level " .. player.Name .. " - menggunakan mode aman (ReadOnlyFallback) tanpa Kick.")
		playerLevelCache[userId] = {
			Level = self.Config.DEFAULT_LEVEL,
			TimeInGame = 0,
			SessionStartTime = os.clock(),
			IsFallback = true,
		}
		-- Coba muat ulang di background setelah 15 detik
		task.delay(15, function()
			if player and player.Parent and playerLevelCache[userId] and playerLevelCache[userId].IsFallback then
				local okRetry, retryData = datastoreGetAsync(key)
				if okRetry and player and player.Parent and playerLevelCache[userId] and playerLevelCache[userId].IsFallback then
					local gainedLevels = playerLevelCache[userId].Level - self.Config.DEFAULT_LEVEL
					local realLevel = (retryData and type(retryData) == "table" and retryData.Level) or self.Config.DEFAULT_LEVEL
					local realTime = (retryData and type(retryData) == "table" and retryData.TimeInGame) or 0
					playerLevelCache[userId].Level = realLevel + math.max(0, gainedLevels)
					playerLevelCache[userId].TimeInGame = realTime
					playerLevelCache[userId].IsFallback = false
					lastSyncedLevel[userId] = playerLevelCache[userId].Level
					local leaderstats = player:FindFirstChild("leaderstats")
					local levelVal = leaderstats and leaderstats:FindFirstChild("Level")
					if levelVal then levelVal.Value = playerLevelCache[userId].Level end
				end
			end
		end)
		return self.Config.DEFAULT_LEVEL
	end

	local level = self.Config.DEFAULT_LEVEL
	local timeInGame = 0

	if data and type(data) == "table" then
		level = data.Level or self.Config.DEFAULT_LEVEL
		timeInGame = data.TimeInGame or 0
	end

	playerLevelCache[userId] = {
		Level = level,
		TimeInGame = timeInGame,
		SessionStartTime = os.clock(),
		IsFallback = false,
	}
	lastSyncedLevel[userId] = level
	return level
end

function LevelSystem:SavePlayerLevel(player, forceSave, snapshotCache)
	local userId = player.UserId
	local cache = snapshotCache or playerLevelCache[userId]

	if not cache then return false end
	-- Proteksi Data Loss: Jangan pernah timpa DataStore jika data asli gagal dimuat (IsFallback)
	if cache.IsFallback then return false end

	local lastSave = saveCooldowns[userId] or 0
	if not forceSave and (os.clock() - lastSave) < self.Config.SAVE_COOLDOWN then
		debug("Save dibatalkan untuk", player.Name, "- Masih dalam cooldown.")
		return true
	end

	local sessionTime = os.clock() - cache.SessionStartTime
	local totalTime = cache.TimeInGame + sessionTime

	cache.TimeInGame = totalTime
	cache.SessionStartTime = os.clock()

	local key = self.Config.DATASTORE_PREFIX .. tostring(userId)
	local data = { Level = cache.Level, TimeInGame = totalTime, LastSaved = os.time() }

	local success = datastoreSetAsync(key, data)
	if success then
		saveCooldowns[userId] = os.clock()
		syncLeaderboard(player, cache.Level)
		return true
	end
	return false
end

-- ====================================
-- LEVEL MANAGEMENT
-- ====================================
function LevelSystem:GetPlayerLevel(player)
	local userId = player.UserId
	local cache = playerLevelCache[userId]
	if cache then return cache.Level end
	return self:LoadPlayerLevel(player)
end

function LevelSystem:SetPlayerLevel(player, newLevel)
	local userId = player.UserId
	if not playerLevelCache[userId] then self:LoadPlayerLevel(player) end
	if not playerLevelCache[userId] then return false end

	local oldLevel = playerLevelCache[userId].Level
	playerLevelCache[userId].Level = newLevel

	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local levelValue = leaderstats:FindFirstChild("Level")
		if levelValue then levelValue.Value = newLevel end
	end

	levelUpEvent:Fire(player, oldLevel, newLevel)
	return true
end

function LevelSystem:AddLevels(player, amount)
	local currentLevel = self:GetPlayerLevel(player)
	local newLevel = currentLevel + amount
	if self.Config.MAX_LEVEL then newLevel = math.min(newLevel, self.Config.MAX_LEVEL) end
	return self:SetPlayerLevel(player, newLevel)
end

-- ====================================
-- TIMER SYSTEM
-- ====================================
local function startLevelTimer(player)
	local userId = player.UserId
	local token = os.clock()
	playerTimers[userId] = token

	task.spawn(function()
		while player.Parent and playerTimers[userId] == token do
			task.wait(LevelSystem.Config.LEVEL_UP_INTERVAL)
			if not player.Parent or playerTimers[userId] ~= token then break end
			LevelSystem:AddLevels(player, 1)
		end
	end)
end

local function stopLevelTimer(player)
	local userId = player.UserId
	playerTimers[userId] = nil
end

function LevelSystem:InitializePlayer(player)
	local level = self:LoadPlayerLevel(player)
	if not player or not player.Parent then return level end

	local leaderstats = player:FindFirstChild("leaderstats") or Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local levelValue = leaderstats:FindFirstChild("Level") or Instance.new("IntValue")
	levelValue.Name = "Level"
	levelValue.Parent = leaderstats
	levelValue.Value = level

	startLevelTimer(player)
	return level
end

-- ====================================
-- COMMAND SYSTEM & STATS
-- ====================================
function LevelSystem:SetupCommands(player, roleSystem)
	local userId = player.UserId
	if activeConnections[userId] then
		for _, conn in ipairs(activeConnections[userId]) do
			conn:Disconnect()
		end
	end
	activeConnections[userId] = {}

	local connection = player.Chatted:Connect(function(message)
		local args = string.split(message, " ")
		local command = args[1]:lower()

		local role = roleSystem:GetPlayerRole(player)
		if role ~= "Owner" then return end

		if command == "/setlevel" then
			if not args[2] then return end
			local targetPlayer = Players:FindFirstChild(args[2])
			if targetPlayer and tonumber(args[3]) then LevelSystem:SetPlayerLevel(targetPlayer, tonumber(args[3])) end
		elseif command == "/addlevel" then
			if not args[2] then return end
			local targetPlayer = Players:FindFirstChild(args[2])
			if targetPlayer and tonumber(args[3]) then LevelSystem:AddLevels(targetPlayer, tonumber(args[3])) end
		elseif command == "/resetlevel" then
			if not args[2] then return end
			local targetPlayer = Players:FindFirstChild(args[2])
			if targetPlayer then LevelSystem:SetPlayerLevel(targetPlayer, LevelSystem.Config.DEFAULT_LEVEL) end
		elseif command == "/hideboard" then
			local targetId = tonumber(args[2]) or player.UserId
			pcall(function()
				LeaderboardStore:RemoveAsync(tostring(targetId))
			end)
			print("[LevelSystem] Berhasil menghapus UserId " .. targetId .. " dari Leaderboard!")
		end
	end)
	table.insert(activeConnections[userId], connection)
end

function LevelSystem:GetStats()
	local stats = { totalPlayers = 0, totalLevels = 0, averageLevel = 0, highestLevel = 0, highestLevelPlayer = nil }
	for userId, cache in pairs(playerLevelCache) do
		stats.totalPlayers += 1
		stats.totalLevels += cache.Level
		if cache.Level > stats.highestLevel then
			stats.highestLevel = cache.Level
			stats.highestLevelPlayer = Players:GetPlayerByUserId(userId)
		end
	end
	if stats.totalPlayers > 0 then stats.averageLevel = math.floor(stats.totalLevels / stats.totalPlayers) end
	return stats
end

-- ====================================
-- CLEANUP SYSTEM (ANTI MEMORY LEAK & ANTI RACE CONDITION REJOIN)
-- ====================================
function LevelSystem:CleanupPlayer(player)
	local userId = player.UserId
	local snapshot = playerLevelCache[userId]
	if not snapshot then return end

	-- Hapus cache dari tabel SEBELUM yielding SetAsync agar jika dipanggil 2x atau player rejoin cepat tidak bentrok!
	playerLevelCache[userId] = nil
	saveCooldowns[userId] = nil
	loadingLocks[userId] = nil
	stopLevelTimer(player)

	if activeConnections[userId] then
		for _, connection in ipairs(activeConnections[userId]) do
			connection:Disconnect()
		end
		activeConnections[userId] = nil
	end

	activeSaves[userId] = true
	self:SavePlayerLevel(player, true, snapshot)
	lastSyncedLevel[userId] = nil
	saveCooldowns[userId] = nil
	activeSaves[userId] = nil
end

Players.PlayerRemoving:Connect(function(player)
	LevelSystem:CleanupPlayer(player)
end)

-- ====================================
-- SHUTDOWN PROTECTION (BINDTOCLOSE)
-- ====================================
local RunService = game:GetService("RunService")
if RunService:IsServer() and RunService:IsRunning() then
	pcall(function()
		game:BindToClose(function()
			print("[LevelSystem] Server shutting down, saving all player data safely...")
			local players = Players:GetPlayers()
			local totalPlayers = #players
			local completed = 0

			for i, player in ipairs(players) do
				task.spawn(function()
					LevelSystem:SavePlayerLevel(player, true)
					completed += 1
				end)

				if i % 10 == 0 then
					task.wait(0.2)
				end
			end

			local elapsed = 0
			while completed < totalPlayers and elapsed < 25 do
				task.wait(1)
				elapsed += 1
			end

			print("[LevelSystem] " .. completed .. "/" .. totalPlayers .. " data pemain berhasil diselamatkan sebelum shutdown!")
		end)
	end)
end

return LevelSystem
