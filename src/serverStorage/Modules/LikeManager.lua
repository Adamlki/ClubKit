local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local DataStoreEnv = require(script.Parent:WaitForChild("DataStoreEnv"))

local LikeManager = {}

local LikesStore, LikesWriteStore = DataStoreEnv.Get("PlayerLikes_v1")
local OrderedLikesStore, OrderedLikesWriteStore = DataStoreEnv.GetOrdered("PlayerLikes_Ordered_v1")
local CooldownsStore, CooldownsWriteStore = DataStoreEnv.Get("LikeCooldowns_v1")

local COOLDOWN_DURATION = 86400

local playerCooldownsCache = {}
local playerLikesCache = {}
local playerLoadedFlags = {}
local playerDirtyFlags = {}
local cooldownDirtyFlags = {}

local activeSaves = {}

function LikeManager.LoadPlayerCooldowns(player)
	local success, data = pcall(function()
		return CooldownsStore:GetAsync(tostring(player.UserId))
	end)
	if not player or not player.Parent then return end
	
	if success then
		playerCooldownsCache[player.UserId] = data or {}
	else
		warn("[LikeManager] Gagal memuat cooldown untuk " .. player.Name)
	end
end

function LikeManager.SavePlayerCooldowns(player)
	local userId = player.UserId
	local saved = true

	if cooldownDirtyFlags[userId] then
		local data = playerCooldownsCache[userId]
		if data then
			local cleanedData = {}
			local currentTime = os.time()
			for targetId, expireTime in pairs(data) do
				if currentTime < expireTime then
					cleanedData[tostring(targetId)] = expireTime
				end
			end

			local ok = pcall(function()
				CooldownsWriteStore:SetAsync(tostring(userId), cleanedData)
			end)
			if ok then
				cooldownDirtyFlags[userId] = nil
			else
				saved = false
			end
		else
			cooldownDirtyFlags[userId] = nil
		end
	end

	if saved then
		playerCooldownsCache[userId] = nil
	end
	return saved
end

function LikeManager.LoadTotalLikes(player)
	local success, totalLikes = pcall(function()
		return LikesStore:GetAsync(tostring(player.UserId))
	end)
	if not player or not player.Parent then return end
	
	totalLikes = totalLikes or 0
	
	if success then
		player:SetAttribute("TotalLikes", totalLikes)
		playerLikesCache[player.UserId] = totalLikes
		playerLoadedFlags[player.UserId] = true
	else
		warn("[LikeManager] Gagal memuat total likes untuk " .. player.Name)
	end
end

function LikeManager.SaveTotalLikes(player)
	local userId = player.UserId
	if playerLoadedFlags[userId] and playerDirtyFlags[userId] then
		local likesToSave = playerLikesCache[userId]
		if likesToSave ~= nil then
			local ok1 = pcall(function()
				LikesWriteStore:SetAsync(tostring(userId), likesToSave)
			end)
			local ok2 = pcall(function()
				OrderedLikesWriteStore:SetAsync(tostring(userId), likesToSave)
			end)
			if not (ok1 and ok2) then
				warn("[LikeManager] Gagal save likes untuk userId:", userId)
				return false
			end
			playerDirtyFlags[userId] = nil
		else
			playerDirtyFlags[userId] = nil
		end
	end

	playerLikesCache[userId] = nil
	playerLoadedFlags[userId] = nil
	return true
end

function LikeManager.CanLikePlayer(liker, targetPlayer)
	local likerId = liker.UserId
	local targetId = tostring(targetPlayer.UserId)
	
	if likerId == targetPlayer.UserId then
		return false, "Tidak bisa melike diri sendiri!"
	end
	
	local cooldowns = playerCooldownsCache[likerId]
	if not cooldowns then
		return false, "Data kamu masih loading, sabar ya!"
	end
	
	if not playerLoadedFlags[targetPlayer.UserId] then
		return false, "Data pemain ini masih loading!"
	end
	
	local expireTime = cooldowns[targetId]
	if expireTime then
		local remaining = expireTime - os.time()
		if remaining > 0 then
			return false, remaining
		end
	end
	
	return true, 0
end

function LikeManager.ProcessLike(liker, targetPlayer)
	local canLike, result = LikeManager.CanLikePlayer(liker, targetPlayer)
	if not canLike then
		return false, result
	end
	
	local likerId = liker.UserId
	local targetId = tostring(targetPlayer.UserId)
	
	playerCooldownsCache[likerId][targetId] = os.time() + COOLDOWN_DURATION
	playerLikesCache[targetPlayer.UserId] = (playerLikesCache[targetPlayer.UserId] or 0) + 1
	targetPlayer:SetAttribute("TotalLikes", playerLikesCache[targetPlayer.UserId])
	
	cooldownDirtyFlags[likerId] = true
	playerDirtyFlags[targetPlayer.UserId] = true

	task.spawn(function()
		local dailyKey = "PlayerLikes_Daily_" .. os.date("!%Y_%m_%d")
		local _, dailyWriteStore = DataStoreEnv.GetOrdered(dailyKey)
		pcall(function()
			dailyWriteStore:IncrementAsync(targetId, 1)
		end)
	end)
	
	return true, "Success"
end

function LikeManager.GetCooldownEndTime(liker, targetPlayer)
	local likerId = liker.UserId
	local targetId = tostring(targetPlayer.UserId)
	
	local cooldowns = playerCooldownsCache[likerId]
	if cooldowns and cooldowns[targetId] then
		return cooldowns[targetId]
	end
	return 0
end

Players.PlayerAdded:Connect(function(player)
	task.wait(math.random(10, 40) / 10)
	if not player or not player.Parent then return end

	local waited = 0
	while activeSaves[player.UserId] and waited < 10 do
		waited += task.wait(0.1)
	end
	if not player or not player.Parent then return end
	
	LikeManager.LoadTotalLikes(player)
	LikeManager.LoadPlayerCooldowns(player)
end)

Players.PlayerRemoving:Connect(function(player)
	local userId = player.UserId
	activeSaves[userId] = true

	local function cleanup(attempt)
		local likesSaved = LikeManager.SaveTotalLikes(player)
		local cooldownsSaved = LikeManager.SavePlayerCooldowns(player)
		local ok = likesSaved and cooldownsSaved

		if ok then
			activeSaves[userId] = nil
			return
		end

		if attempt < 5 then
			task.delay(2, function()
				cleanup(attempt + 1)
			end)
		else
			warn("[LikeManager] Menyerah menyimpan likes untuk userId:", userId)
			activeSaves[userId] = nil
		end
	end

	cleanup(1)
end)

task.spawn(function()
	while true do
		task.wait(300)
		for _, player in ipairs(Players:GetPlayers()) do
			local userId = player.UserId
			local didWrite = false

			if playerLoadedFlags[userId] and playerDirtyFlags[userId] then
				local likesToSave = playerLikesCache[userId]
				if likesToSave ~= nil then
					local ok1 = pcall(function()
						LikesWriteStore:SetAsync(tostring(userId), likesToSave)
					end)
					local ok2 = pcall(function()
						OrderedLikesWriteStore:SetAsync(tostring(userId), likesToSave)
					end)
					if ok1 and ok2 then
						playerDirtyFlags[userId] = nil
					end
					didWrite = true
				end
			end

			local cooldownData = playerCooldownsCache[userId]
			if cooldownData and cooldownDirtyFlags[userId] then
				local cleanedData = {}
				local currentTime = os.time()
				for targetId, expireTime in pairs(cooldownData) do
					if currentTime < expireTime then
						cleanedData[tostring(targetId)] = expireTime
					end
				end
				local okCd = pcall(function()
					CooldownsWriteStore:SetAsync(tostring(userId), cleanedData)
				end)
				if okCd then
					cooldownDirtyFlags[userId] = nil
				end
				didWrite = true
			end

			if didWrite then
				task.wait(1)
			end
		end
	end
end)

local RunService = game:GetService("RunService")
if RunService:IsServer() and RunService:IsRunning() then
	pcall(function()
		game:BindToClose(function()
			local players = Players:GetPlayers()
			local totalPlayers = #players
			local completed = 0

			for i, player in ipairs(players) do
				task.spawn(function()
					LikeManager.SaveTotalLikes(player)
					LikeManager.SavePlayerCooldowns(player)
					completed += 1
				end)
				
				if i % 10 == 0 then
					task.wait(0.2)
				end
			end
			
			local elapsed = 0
			while completed < totalPlayers and elapsed < 15 do
				task.wait(1)
				elapsed += 1
			end
		end)
	end)
end

return LikeManager
