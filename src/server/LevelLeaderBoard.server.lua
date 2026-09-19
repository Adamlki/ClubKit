local Players            = game:GetService("Players")
local UserService        = game:GetService("UserService")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local ServerStorage      = game:GetService("ServerStorage")

local DEBUG_ENABLED = false 
local DEBUG_PREFIX = "[LevelBoard Server]"

local function debugPrint(...)
	if DEBUG_ENABLED then print(DEBUG_PREFIX, ...) end
end

local LevelSystem = require(ServerStorage:WaitForChild("Modules"):WaitForChild("LevelSystem"))
local remote = ReplicatedStorage:FindFirstChild("UpdateLevelBoard")
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = "UpdateLevelBoard"
	remote.Parent = ReplicatedStorage
end

local userInfoCache = {}
local cachedTopData = {}

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

local function refreshLeaderboard()
	local ok, topData = pcall(function() return LevelSystem:GetTopPlayers(100) end)
	if ok and topData and #topData > 0 then
		local userIds = {}
		for _, item in ipairs(topData) do
			local uid = item.userId or item.UserId
			if uid then table.insert(userIds, uid) end
		end
		resolveUserInfos(userIds)

		for _, item in ipairs(topData) do
			local uid = item.userId or item.UserId
			local uInfo = userInfoCache[uid] or { DisplayName = "Player", Username = "player" }
			item.DisplayName = uInfo.DisplayName
			item.Username = "@" .. uInfo.Username
		end

		cachedTopData = topData
		remote:FireAllClients(cachedTopData)
		debugPrint("Leaderboard refreshed -", #topData, "players")
	end
end

-- ====================================
-- CLIENT ON-DEMAND SYNC (RATE LIMITED)
-- ====================================
local requestCooldowns = {}
local REQUEST_COOLDOWN = 5

remote.OnServerEvent:Connect(function(player)
	if not player or not player.Parent then return end
	local now = os.clock()
	if now - (requestCooldowns[player.UserId] or 0) < REQUEST_COOLDOWN then
		return -- Ignore spam requests from clients
	end
	requestCooldowns[player.UserId] = now

	if cachedTopData and #cachedTopData > 0 then
		pcall(function()
			remote:FireClient(player, cachedTopData)
		end)
	else
		-- Fetch on first client if empty
		pcall(refreshLeaderboard)
		if cachedTopData and #cachedTopData > 0 then
			pcall(function()
				remote:FireClient(player, cachedTopData)
			end)
		end
	end
end)

-- ====================================
-- PLAYER MANAGEMENT (ANTI GHOSTING FIX)
-- ====================================
local function onPlayerJoin(player)
	debugPrint("Player joined:", player.Name)
	LevelSystem:InitializePlayer(player)
end

Players.PlayerAdded:Connect(onPlayerJoin)
Players.PlayerRemoving:Connect(function(player)
	requestCooldowns[player.UserId] = nil
end)

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(function()
		onPlayerJoin(player)
	end)
end

-- ====================================
-- AUTO-SAVE & REFRESH LOOP
-- ====================================
task.spawn(function()
	while true do
		-- Interval 10 Menit untuk 100 Player (600 detik)
		task.wait(600)
		for _, player in ipairs(Players:GetPlayers()) do
			pcall(function() LevelSystem:SavePlayerLevel(player) end)
			task.wait(0.5) 
		end
	end
end)

task.spawn(function()
	task.wait(2) -- Quick initial fetch on startup
	pcall(refreshLeaderboard)
	while true do
		task.wait(120) 
		pcall(refreshLeaderboard)
	end
end)