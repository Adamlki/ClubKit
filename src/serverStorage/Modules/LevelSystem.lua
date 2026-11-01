local LevelSystem = {}

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")

local RoleSystem = require(ServerStorage:WaitForChild("Modules"):WaitForChild("RoleSystem"))

LevelSystem.Config = {
	DATASTORE_NAME = "PlayerLevel_v1",
	DATASTORE_PREFIX = "Level_",
	DATASTORE_RETRY_ATTEMPTS = 5,
	DATASTORE_RETRY_DELAY = 1.5,
	SAVE_COOLDOWN = 60,
	LEADERBOARD_STORE_NAME = "PlayerLevels_Leaderboard_v1",

	EXCLUDED_ROLES = {
		["Owner"] = true,
		["Admin"] = true,
		["Moderator"] = true,
	},

	LEVEL_UP_INTERVAL = 900,
	DEFAULT_LEVEL = 1,
	MAX_LEVEL = nil,
	DEBUG_ENABLED = false,
}

local LevelDataStore = DataStoreService:GetDataStore(LevelSystem.Config.DATASTORE_NAME)
local LeaderboardStore = DataStoreService:GetOrderedDataStore(LevelSystem.Config.LEADERBOARD_STORE_NAME)

local playerLevelCache = {}
local playerTimers = {}
local activeConnections = {}
local saveCooldowns = {}
local loadingLocks = {}
local activeSaves = {}
local lastSyncedLevel = {}

local levelUpEvent = Instance.new("BindableEvent")
levelUpEvent.Name = "LevelUp"
LevelSystem.LevelUp = levelUpEvent.Event

local function debug(...)
	if LevelSystem.Config.DEBUG_ENABLED then print("[LevelSystem]", ...) end
end

local function debugWarn(...)
	if LevelSystem.Config.DEBUG_ENABLED then warn("[LevelSystem]", ...) end
end

local function datastoreGetAsync(key)
	for attempt = 1, LevelSystem.Config.DATASTORE_RETRY_ATTEMPTS do
		local success, result = pcall(LevelDataStore.GetAsync, LevelDataStore, key)
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
		if pcall(LevelDataStore.SetAsync, LevelDataStore, key, value) then return true end
		if attempt < LevelSystem.Config.DATASTORE_RETRY_ATTEMPTS then
			task.wait(LevelSystem.Config.DATASTORE_RETRY_DELAY * attempt)
		end
	end
	debugWarn("Failed to save data for key:", key)
	return false
end

local function syncLeaderboard(player, level)
	local userId = player.UserId
	if lastSyncedLevel[userId] == level then return end

	local role = RoleSystem:GetPlayerRole(player)
	if LevelSystem.Config.EXCLUDED_ROLES[role] then
		lastSyncedLevel[userId] = level
		pcall(LeaderboardStore.RemoveAsync, LeaderboardStore, tostring(userId))
		return
	end

	lastSyncedLevel[userId] = level

	task.spawn(function()
		for attempt = 1, LevelSystem.Config.DATASTORE_RETRY_ATTEMPTS do
			if pcall(LeaderboardStore.SetAsync, LeaderboardStore, tostring(userId), level) then
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
	local success, pages = pcall(LeaderboardStore.GetSortedAsync, LeaderboardStore, false, count)
	if not success or not pages then return {} end

	local ok, data = pcall(pages.GetCurrentPage, pages)
	if not ok or not data then return {} end

	local results = {}
	for rank, entry in ipairs(data) do
		table.insert(results, { rank = rank, userId = tonumber(entry.key), level = entry.value })
	end
	return results
end

function LevelSystem:LoadPlayerLevel(player)
	local userId = player.UserId

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
		return self.Config.DEFAULT_LEVEL
	end

	if not success then
		warn("[LevelSystem] DataStore sibuk saat memuat level " .. player.Name .. " - menggunakan ReadOnlyFallback.")
		playerLevelCache[userId] = {
			Level = self.Config.DEFAULT_LEVEL,
			TimeInGame = 0,
			SessionStartTime = os.clock(),
			IsFallback = true,
		}

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

	local level = (data and type(data) == "table" and data.Level) or self.Config.DEFAULT_LEVEL
	local timeInGame = (data and type(data) == "table" and data.TimeInGame) or 0

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

	if not cache or cache.IsFallback then return false end

	local lastSave = saveCooldowns[userId] or 0
	if not forceSave and (os.clock() - lastSave) < self.Config.SAVE_COOLDOWN then
		return true
	end

	local sessionTime = os.clock() - cache.SessionStartTime
	local totalTime = cache.TimeInGame + sessionTime
	cache.TimeInGame = totalTime
	cache.SessionStartTime = os.clock()

	local key = self.Config.DATASTORE_PREFIX .. tostring(userId)
	local data = { Level = cache.Level, TimeInGame = totalTime, LastSaved = os.time() }

	if datastoreSetAsync(key, data) then
		saveCooldowns[userId] = os.clock()
		syncLeaderboard(player, cache.Level)
		return true
	end
	return false
end

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
	local levelValue = leaderstats and leaderstats:FindFirstChild("Level")
	if levelValue then levelValue.Value = newLevel end

	levelUpEvent:Fire(player, oldLevel, newLevel)
	return true
end

function LevelSystem:AddLevels(player, amount)
	local currentLevel = self:GetPlayerLevel(player)
	local newLevel = currentLevel + amount
	if self.Config.MAX_LEVEL then newLevel = math.min(newLevel, self.Config.MAX_LEVEL) end
	return self:SetPlayerLevel(player, newLevel)
end

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
	playerTimers[player.UserId] = nil
end

function LevelSystem:InitializePlayer(player)
	local level = self:LoadPlayerLevel(player)
	if not player or not player.Parent then return level end

	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player
	end

	local levelValue = leaderstats:FindFirstChild("Level")
	if not levelValue then
		levelValue = Instance.new("IntValue")
		levelValue.Name = "Level"
		levelValue.Parent = leaderstats
	end
	levelValue.Value = level

	startLevelTimer(player)
	return level
end

local COMMAND_HANDLERS = {
	["/setlevel"] = function(target, val)
		if target and val then LevelSystem:SetPlayerLevel(target, val) end
	end,
	["/addlevel"] = function(target, val)
		if target and val then LevelSystem:AddLevels(target, val) end
	end,
	["/resetlevel"] = function(target)
		if target then LevelSystem:SetPlayerLevel(target, LevelSystem.Config.DEFAULT_LEVEL) end
	end,
}

local textCommandsRegistered = false
local lastLevelCommand = {} -- [userId] = { text = string, timestamp = number }

local function executeLevelCommand(player, message, roleSystem)
	if not player or not player.Parent then return end
	if roleSystem and roleSystem:GetPlayerRole(player) ~= "Owner" then return end

	-- Deduplikasi perintah dalam 0.5s agar tidak tereksekusi 2x jika dipicu Chatted + TextChatCommand bersamaan
	local now = os.clock()
	local last = lastLevelCommand[player.UserId]
	if last and last.text == message and (now - last.timestamp) < 0.5 then
		return
	end
	lastLevelCommand[player.UserId] = { text = message, timestamp = now }

	local args = string.split(message, " ")
	local command = args[1] and args[1]:lower()
	local handler = COMMAND_HANDLERS[command]

	if handler and args[2] then
		local targetPlayer = Players:FindFirstChild(args[2])
		handler(targetPlayer, tonumber(args[3]))
	elseif command == "/hideboard" then
		local targetId = tonumber(args[2]) or player.UserId
		pcall(LeaderboardStore.RemoveAsync, LeaderboardStore, tostring(targetId))
		print("[LevelSystem] Berhasil menghapus UserId " .. targetId .. " dari Leaderboard!")
	end
end

local function registerModernTextCommands(roleSystem)
	if textCommandsRegistered then return end
	textCommandsRegistered = true

	pcall(function()
		local TextChatService = game:GetService("TextChatService")
		local cmdFolder = TextChatService:FindFirstChild("TextChatCommands")
		if cmdFolder then
			local function registerLevelTCC(name, primaryAlias)
				local cmd = cmdFolder:FindFirstChild(name)
				if not cmd then
					cmd = Instance.new("TextChatCommand")
					cmd.Name = name
					cmd.PrimaryAlias = primaryAlias
					cmd.Parent = cmdFolder
				end
				cmd.Triggered:Connect(function(textSource, rawMsg)
					local p = Players:GetPlayerByUserId(textSource.UserId)
					if p then executeLevelCommand(p, rawMsg, roleSystem) end
				end)
			end

			registerLevelTCC("LevelSet", "/setlevel")
			registerLevelTCC("LevelAdd", "/addlevel")
			registerLevelTCC("LevelHideBoard", "/hideboard")
		end
	end)
end

function LevelSystem:SetupCommands(player, roleSystem)
	registerModernTextCommands(roleSystem)

	local userId = player.UserId
	if activeConnections[userId] then
		for _, conn in ipairs(activeConnections[userId]) do
			conn:Disconnect()
		end
	end
	activeConnections[userId] = {}

	local connection = player.Chatted:Connect(function(message)
		executeLevelCommand(player, message, roleSystem)
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
	if stats.totalPlayers > 0 then
		stats.averageLevel = math.floor(stats.totalLevels / stats.totalPlayers)
	end
	return stats
end

function LevelSystem:CleanupPlayer(player)
	local userId = player.UserId
	local snapshot = playerLevelCache[userId]
	if not snapshot then return end

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

if RunService:IsServer() and RunService:IsRunning() then
	pcall(function()
		game:BindToClose(function()
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
		end)
	end)
end

return LevelSystem
