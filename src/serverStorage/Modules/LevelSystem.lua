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
	DATASTORE_RETRY_ATTEMPTS = 3,
	DATASTORE_RETRY_DELAY = 1,

	-- Anti-Spam Save (Dalam Detik)
	SAVE_COOLDOWN = 60,

	LEADERBOARD_STORE_NAME = "PlayerLevels_Leaderboard_v1",

	-- 🔥 ARCHITECT FIX: Daftar Role yang disembunyikan dari Leaderboard
	EXCLUDED_ROLES = {
		["Owner"] = true,
		["Admin"] = true,
		["Moderator"] = true,
	},

	LEVEL_UP_INTERVAL = 900, -- 12 seconds
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
local saveCooldowns = {} -- BARU: Mencegah spam DataStore

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
-- DATASTORE OPERATIONS (WITH RETRY)
-- ====================================
local function datastoreGetAsync(key)
	for attempt = 1, LevelSystem.Config.DATASTORE_RETRY_ATTEMPTS do
		local success, result = pcall(function()
			return LevelDataStore:GetAsync(key)
		end)
		if success then return true, result end
		if attempt < LevelSystem.Config.DATASTORE_RETRY_ATTEMPTS then
			task.wait(LevelSystem.Config.DATASTORE_RETRY_DELAY)
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
			task.wait(LevelSystem.Config.DATASTORE_RETRY_DELAY)
		end
	end
	debugWarn("Failed to save data for key:", key)
	return false
end

-- ====================================
-- LEADERBOARD SYNC
-- ====================================
-- 🔥 ARCHITECT FIX: Gunakan (player, level) bukan (userId, level)
local function syncLeaderboard(player, level)
	local userId = player.UserId

	-- Gatekeeper Absolute: Cek role tanpa takut 'nil' saat leave
	local role = RoleSystem:GetPlayerRole(player)
	if LevelSystem.Config.EXCLUDED_ROLES[role] then
		debugWarn("Pemain " .. player.Name .. " (" .. role .. ") di-exclude dari Leaderboard.")
		pcall(function() LeaderboardStore:RemoveAsync(tostring(userId)) end)
		return -- Jangan lanjutkan proses save ke Leaderboard!
	end

	task.spawn(function()
		for attempt = 1, LevelSystem.Config.DATASTORE_RETRY_ATTEMPTS do
			local success, err = pcall(function()
				LeaderboardStore:SetAsync(tostring(userId), level)
			end)
			if success then
				debug("Leaderboard synced: User", userId, "Level", level)
				return
			end
			if attempt < LevelSystem.Config.DATASTORE_RETRY_ATTEMPTS then
				task.wait(LevelSystem.Config.DATASTORE_RETRY_DELAY)
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
	local key = self.Config.DATASTORE_PREFIX .. tostring(userId)
	
	local success, data = datastoreGetAsync(key)
	
	-- 🔥 ARCHITECT FIX 1: Cegah Data Wipe akibat Roblox Down
	if not success then
		player:Kick("\n[Server Error]\nGagal memuat data level Anda karena gangguan jaringan Roblox.\n\nSilakan coba lagi beberapa saat untuk mencegah data Anda hilang/ter-reset.")
		return self.Config.DEFAULT_LEVEL
	end
	
	-- 🔥 ARCHITECT FIX 2: Cegah Memory Leak Ghost Session (Join-Leave super cepat)
	if not player.Parent then
		debugWarn("Pemain " .. player.Name .. " keluar sebelum data selesai dimuat. Membatalkan inisialisasi memori.")
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
		SessionStartTime = os.clock()
	}
	return level
end

-- BARU: Tambahan forceSave agar bisa di-bypass saat keluar game
function LevelSystem:SavePlayerLevel(player, forceSave)
	local userId = player.UserId
	local cache = playerLevelCache[userId]

	if not cache then return false end

	-- ANTI SPAM DATASTORE LIMIT
	local lastSave = saveCooldowns[userId] or 0
	if not forceSave and (os.clock() - lastSave) < self.Config.SAVE_COOLDOWN then
		debug("Save dibatalkan untuk", player.Name, "- Masih dalam cooldown.")
		return true -- Anggap sukses karena datanya toh aman di Cache
	end

	local sessionTime = os.clock() - cache.SessionStartTime
	local totalTime = cache.TimeInGame + sessionTime

	cache.TimeInGame = totalTime
	cache.SessionStartTime = os.clock()

	local key = self.Config.DATASTORE_PREFIX .. tostring(userId)
	local data = { Level = cache.Level, TimeInGame = totalTime, LastSaved = os.time() }

	local success = datastoreSetAsync(key, data)
	if success then
		saveCooldowns[userId] = os.clock() -- Catat waktu save terakhir

		-- 🔥 ARCHITECT FIX: Panggil dengan 'player', BUKAN 'userId'
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

	local oldLevel = playerLevelCache[userId].Level
	playerLevelCache[userId].Level = newLevel

	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local levelValue = leaderstats:FindFirstChild("Level")
		if levelValue then levelValue.Value = newLevel end
	end

	-- BARIS INI TELAH DIHAPUS AGAR TIDAK SPAM KE ORDERED DATASTORE
	-- syncLeaderboard(userId, newLevel) 

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
	if playerTimers[userId] then return end

	local running = true
	playerTimers[userId] = running

	task.spawn(function()
		while running and player.Parent and playerTimers[userId] do
			task.wait(LevelSystem.Config.LEVEL_UP_INTERVAL)
			if not running or not player.Parent or not playerTimers[userId] then break end
			LevelSystem:AddLevels(player, 1)
		end
	end)
	
	-- 🔥 ARCHITECT FIX: AUTO-SAVE LOOP
	task.spawn(function()
		while running and player.Parent and playerTimers[userId] do
			task.wait(LevelSystem.Config.SAVE_COOLDOWN)
			if not running or not player.Parent or not playerTimers[userId] then break end
			-- Lakukan save secara background (bukan force save)
			LevelSystem:SavePlayerLevel(player, false)
		end
	end)
end

local function stopLevelTimer(player)
	local userId = player.UserId
	if playerTimers[userId] then playerTimers[userId] = nil end
end

function LevelSystem:InitializePlayer(player)
	local level = self:LoadPlayerLevel(player) -- 

	local leaderstats = player:FindFirstChild("leaderstats") or Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player -- 

	local levelValue = leaderstats:FindFirstChild("Level") or Instance.new("IntValue")
	levelValue.Name = "Level"
	levelValue.Parent = leaderstats
	levelValue.Value = level -- 

	-- BARIS SYNC LEADERBOARD DIHAPUS DARI SINI AGAR TIDAK SPAM SAAT JOIN --

	startLevelTimer(player) -- 
	return level
end

-- ====================================
-- COMMAND SYSTEM & STATS
-- ====================================
function LevelSystem:SetupCommands(player, roleSystem)
	local userId = player.UserId
	if not activeConnections[userId] then activeConnections[userId] = {} end

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

			-- 🔥 ARCHITECT FIX: Command untuk menghapus Ghost Data dari Leaderboard
		elseif command == "/hideboard" then
			-- Jika tidak mengetik ID target, maka akan menghapus diri sendiri
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
-- CLEANUP SYSTEM (ANTI MEMORY LEAK)
-- ====================================
function LevelSystem:CleanupPlayer(player)
	local userId = player.UserId
	
	-- Hapus koneksi chat
	if activeConnections[userId] then
		for _, connection in ipairs(activeConnections[userId]) do
			connection:Disconnect()
		end
		activeConnections[userId] = nil
	end
	
	-- Hentikan timer
	stopLevelTimer(player)
	
	-- Simpan data terakhir (bypass cooldown)
	self:SavePlayerLevel(player, true)
	
	-- Hapus dari cache
	playerLevelCache[userId] = nil
	saveCooldowns[userId] = nil
end

Players.PlayerRemoving:Connect(function(player)
	LevelSystem:CleanupPlayer(player)
end)

-- ====================================
-- SHUTDOWN PROTECTION (BINDTOCLOSE)
-- ====================================
game:BindToClose(function()
	debug("Server shutting down, saving all players data...")
	
	local saveCount = 0
	-- Simpan secara paralel agar tidak kehabisan waktu shutdown (max 30 detik)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(function()
			LevelSystem:SavePlayerLevel(player, true)
		end)
		saveCount += 1
	end
	
	-- Beri waktu maksimal 5 detik untuk semua save process selesai
	if saveCount > 0 then
		task.wait(5)
	end
end)

return LevelSystem