local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")

-- ============================================
-- INITIALIZE REMOTES
-- ============================================
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local animationStartRE = remotes:WaitForChild("animationStart")
local startSyncRE = remotes:WaitForChild("startSync")
local changeSpeedRE = remotes:WaitForChild("changeSpeed")
local syncNotificationRE = remotes:WaitForChild("SyncNotification")

-- ============================================
-- LOAD SERVER MODULES
-- ============================================
local SyncServer = ServerScriptService:WaitForChild("SyncServer")
local ServerModules = SyncServer:WaitForChild("Modules")

local AnimationLoader = require(ServerModules:WaitForChild("AnimationLoader"))
local emotesFolder = AnimationLoader.initializeEmotesFolder()

local AnimationController = require(ServerModules:WaitForChild("AnimationController"))
local SyncController = require(ServerModules:WaitForChild("SyncController"))

-- ============================================
-- LOAD SHARED MODULES
-- ============================================
local SharedModules = ReplicatedStorage:WaitForChild("Modules")
local AnimatorUtils = require(SharedModules:WaitForChild("AnimatorUtils"))

-- ============================================
-- BUILD ANIMATION TABLE
-- ============================================
local loadedAnimations = AnimationLoader.loadAnimations()

-- ============================================
-- RATE LIMIT PER PLAYER untuk changeSpeed
-- Cegah spam slider dari 100 client sekaligus
-- ============================================
local speedDebounce = {}
local SPEED_DEBOUNCE_TIME = 0.05 -- max 20x per detik per player

-- ============================================
-- REMOTE HANDLERS
-- ============================================
animationStartRE.OnServerEvent:Connect(function(player, animationId, shouldPlay, speed, clientFadeTime, isSpam, clientStartTime)
	local animation = nil
	if animationId then
		-- Cari di loadedAnimations dulu (lebih efisien dari buat baru)
		for _, anim in pairs(loadedAnimations) do
			if anim.AnimationId == animationId then
				animation = anim
				break
			end
		end
		-- Fallback: buat Animation baru jika tidak ketemu
		if not animation then
			animation = Instance.new("Animation")
			animation.AnimationId = animationId
		end
	end
	AnimationController.executeAnimation(player, animation, shouldPlay, speed, loadedAnimations, isSpam, clientStartTime)
end)

changeSpeedRE.OnServerEvent:Connect(function(player, speed)
	-- Rate limit per player untuk cegah spam slider
	local now = tick()
	if speedDebounce[player] and (now - speedDebounce[player]) < SPEED_DEBOUNCE_TIME then
		return
	end
	speedDebounce[player] = now
	AnimationController.adjustAnimationSpeed(player, speed, loadedAnimations)
end)

startSyncRE.OnServerEvent:Connect(function(player, target, condition)
	SyncController.handleSyncRequest(player, target, condition, loadedAnimations)
end)

-- ============================================
-- CONNECTION CLEANUP
-- ============================================
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

-- ============================================
-- Force unsync semua follower saat player keluar/respawn
-- ============================================
local function forceUnsyncAllFollowers(leavingPlayer)
	-- Delegasikan semua tugas pembersihan ke SyncController!
	SyncController.forceUnsyncAllFollowers(leavingPlayer, loadedAnimations)
end

local leaderUpdatePending = false
local function queueLeaderUpdate()
	if leaderUpdatePending then return end
	leaderUpdatePending = true
	task.delay(0.2, function()
		leaderUpdatePending = false
		SyncController.updateAllLeaderStatus() -- ✅ BENAR! Panggil SyncController
	end)
end

-- ============================================
-- RESPAWN HANDLER
-- ============================================
local function setupPlayerRespawnHandler(player)
	cleanupPlayerConnections(player) 
	-- ✅ PEMBERSIHAN SELESAI, baru buat yang baru:
	playerConnections[player] = {}

	local charAddedConn = player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid", 5)
		local hrp = character:WaitForChild("HumanoidRootPart", 5)

		if not humanoid or not hrp then
			warn("[SyncSystem] Character load timeout for", player.Name)
			return
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

		character:SetAttribute("Syncing", nil)
		character:SetAttribute("IsLeader", nil)
		character:SetAttribute("FollowerCount", nil)
		character:SetAttribute("CurrentDanceID", nil)
	end)

	table.insert(playerConnections[player], charRemovingConn)

	-- Setup untuk karakter yang sudah ada
	if player.Character then
		task.spawn(function()
			local humanoid = player.Character:WaitForChild("Humanoid", 5)
			local hrp = player.Character:WaitForChild("HumanoidRootPart", 5)
			if humanoid and hrp then
				player.Character:SetAttribute("Syncing", nil)
				player.Character:SetAttribute("IsLeader", nil)
				player.Character:SetAttribute("FollowerCount", nil)
				player.Character:SetAttribute("CurrentDanceID", nil)
			end
		end)
	end
end

-- ============================================
-- PLAYER REMOVING
-- ============================================
Players.PlayerRemoving:Connect(function(leavingPlayer)
	pcall(forceUnsyncAllFollowers, leavingPlayer)
	cleanupPlayerConnections(leavingPlayer)
	speedDebounce[leavingPlayer] = nil
	
	AnimatorUtils.clearCacheForPlayer(leavingPlayer)

	if leavingPlayer.Character then
		leavingPlayer.Character:SetAttribute("Syncing", nil)
		leavingPlayer.Character:SetAttribute("IsLeader", nil)
		leavingPlayer.Character:SetAttribute("FollowerCount", nil)
		leavingPlayer.Character:SetAttribute("CurrentDanceID", nil)
	end

	task.delay(0.1, function()
		queueLeaderUpdate()
	end)
end)

-- ============================================
-- PLAYER INITIALIZATION
-- ============================================
Players.PlayerAdded:Connect(function(player)
	task.wait(0.5)
	setupPlayerRespawnHandler(player)
end)

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(setupPlayerRespawnHandler, player)
end

-- ============================================
-- CLEANUP ON SHUTDOWN
-- ============================================
game:BindToClose(function()
	for player, _ in pairs(playerConnections) do
		cleanupPlayerConnections(player)
	end

	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			player.Character:SetAttribute("Syncing", nil)
			player.Character:SetAttribute("IsLeader", nil)
			player.Character:SetAttribute("FollowerCount", nil)
			player.Character:SetAttribute("CurrentDanceID", nil)
		end
	end
end)
