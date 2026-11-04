--!native
--!optimize 2
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")

-- INITIALIZE REMOTES
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local animationStartRE = remotes:WaitForChild("animationStart")
local startSyncRE = remotes:WaitForChild("startSync")
local changeSpeedRE = remotes:WaitForChild("changeSpeed")
local syncNotificationRE = remotes:WaitForChild("SyncNotification")

-- LOAD SERVER MODULES
local SyncServer = ServerScriptService:WaitForChild("SyncServer")
local ServerModules = SyncServer:WaitForChild("Modules")

local AnimationLoader = require(ServerModules:WaitForChild("AnimationLoader"))
local emotesFolder = AnimationLoader.initializeEmotesFolder()

local AnimationController = require(ServerModules:WaitForChild("AnimationController"))
local SyncController = require(ServerModules:WaitForChild("SyncController"))
local RemoteEventManager = require(ServerScriptService:WaitForChild("Modules"):WaitForChild("RemoteEventManager"))

-- LOAD SHARED MODULES
local SharedModules = ReplicatedStorage:WaitForChild("Modules")
local AnimatorUtils = require(SharedModules:WaitForChild("AnimatorUtils"))

-- BUILD ANIMATION TABLE & O(1) LOOKUP CACHE
local loadedAnimations = AnimationLoader.loadAnimations()
local loadedAnimationsById = {}
local loadedAnimationsByNormId = {}

local function normalizeAnimId(id)
	if not id then return "" end
	local s = tostring(id):gsub("%s+", "")
	local num = s:match("%d+")
	return num or s
end

for _, anim in pairs(loadedAnimations) do
	if anim and anim:IsA("Animation") and anim.AnimationId ~= "" then
		loadedAnimationsById[anim.AnimationId] = anim
		local norm = normalizeAnimId(anim.AnimationId)
		if norm ~= "" then
			loadedAnimationsByNormId[norm] = anim
		end
	end
end

-- REMOTE HANDLERS
animationStartRE.OnServerEvent:Connect(function(player, animationId, shouldPlay, speed, clientFadeTime, isSpam, clientStartTime)
	-- Validasi tipe dan nilai dari client.
	if animationId ~= nil and type(animationId) ~= "string" and type(animationId) ~= "number" then return end
	if type(shouldPlay) ~= "boolean" then return end
	if speed ~= nil and (type(speed) ~= "number" or speed ~= speed) then return end
	if not RemoteEventManager.checkRateLimit(player, "animationStart") then return end
	speed = math.clamp(speed or 1, 0.1, 3.0)

	-- Tolak timestamp yang tidak valid atau terlalu jauh dari waktu server.
	local nowServer = workspace:GetServerTimeNow()
	if type(clientStartTime) ~= "number" or clientStartTime ~= clientStartTime or math.abs(nowServer - clientStartTime) > 10 then
		clientStartTime = nowServer
	end

	local animation = nil
	if animationId then
		local rawStr = tostring(animationId)
		if #rawStr > 60 then return end

		animation = loadedAnimationsById[animationId]
		local norm = normalizeAnimId(animationId)
		if not animation and norm ~= "" then
			animation = loadedAnimationsByNormId[norm]
		end

		-- Hanya animasi yang ada di AnimationRegistry/Emotes yang boleh diputar.
		-- Jangan membuat Animation dari ID arbitrer dari client.
		if shouldPlay and not animation then
			return
		end
	end
	AnimationController.executeAnimation(player, animation, shouldPlay, speed, loadedAnimations, isSpam, clientStartTime)
end)

changeSpeedRE.OnServerEvent:Connect(function(player, speed)
	-- speed ~= speed mendeteksi NaN.
	if type(speed) ~= "number" or speed ~= speed then return end
	speed = math.clamp(speed, 0.1, 3.0)

	if not RemoteEventManager.checkRateLimit(player, "changeAnimationSpeed") then return end

	AnimationController.adjustAnimationSpeed(player, speed, loadedAnimations)
end)

startSyncRE.OnServerEvent:Connect(function(player, target, condition)
	if not RemoteEventManager.checkRateLimit(player, "startSync") then return end
	if typeof(target) ~= "Instance" or not target:IsA("Player") then return end

	SyncController.handleSyncRequest(player, target, condition, loadedAnimations)
end)

-- CONNECTION CLEANUP
local playerConnections = {}

local function cleanupPlayerConnections(player)
	if playerConnections[player] then
		for _, connection in ipairs(playerConnections[player]) do
			if connection and connection.Connected then
				connection:Disconnect()
			end
		end
		playerConnections[player] = nil
	end
end

-- Force unsync semua follower saat player keluar/respawn.
local function forceUnsyncAllFollowers(leavingPlayer)
	SyncController.forceUnsyncAllFollowers(leavingPlayer, loadedAnimations)
end

local leaderUpdatePending = false
local function queueLeaderUpdate()
	if leaderUpdatePending then return end
	leaderUpdatePending = true
	task.delay(0.2, function()
		leaderUpdatePending = false
		SyncController.updateAllLeaderStatus()
	end)
end

-- RESPAWN HANDLER
local function setupPlayerRespawnHandler(player)
	cleanupPlayerConnections(player) 
	playerConnections[player] = {}

	local charAddedConn = player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid", 5)
		local hrp = character:WaitForChild("HumanoidRootPart", 5)

		if not humanoid or not hrp then
			warn("[SyncSystem] Character load timeout for", player.Name)
			-- Jangan return: atribut dasar tetap harus di-set.
		end

		task.wait(0.5)

		pcall(forceUnsyncAllFollowers, player)

		character:SetAttribute("Syncing", nil)
		character:SetAttribute("IsLeader", nil)
		character:SetAttribute("FollowerCount", nil)
		character:SetAttribute("CurrentDanceID", nil)
		queueLeaderUpdate()
	end)

	table.insert(playerConnections[player], charAddedConn)

	local charRemovingConn = player.CharacterRemoving:Connect(function(character)
		pcall(forceUnsyncAllFollowers, player)
		
		AnimatorUtils.clearCacheForPlayer(player)

		SyncController.clearAllSyncAttributes(character)
	end)

	table.insert(playerConnections[player], charRemovingConn)

	-- Setup untuk karakter yang sudah ada
	if player.Character then
		task.spawn(function()
			local humanoid = player.Character:WaitForChild("Humanoid", 5)
			local hrp = player.Character:WaitForChild("HumanoidRootPart", 5)
			if humanoid and hrp then
			SyncController.clearAllSyncAttributes(player.Character)
			end
		end)
	end
end

-- PLAYER REMOVING
Players.PlayerRemoving:Connect(function(leavingPlayer)
	pcall(forceUnsyncAllFollowers, leavingPlayer)
	cleanupPlayerConnections(leavingPlayer)
	
	AnimatorUtils.clearCacheForPlayer(leavingPlayer)

	if leavingPlayer.Character then
		SyncController.clearAllSyncAttributes(leavingPlayer.Character)
	end

	task.delay(0.1, function()
		queueLeaderUpdate()
	end)
end)

-- PLAYER INITIALIZATION
Players.PlayerAdded:Connect(function(player)
	task.wait(0.5)
	-- VALIDASI: Cegah Memory Leak (Ghost Player) jika player DC saat yield
	if not player or not player.Parent then return end
	setupPlayerRespawnHandler(player)
end)

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(setupPlayerRespawnHandler, player)
end

-- CLEANUP ON SHUTDOWN
game:BindToClose(function()
	for player, _ in pairs(playerConnections) do
		cleanupPlayerConnections(player)
	end

	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			SyncController.clearAllSyncAttributes(player.Character)
		end
	end
end)
