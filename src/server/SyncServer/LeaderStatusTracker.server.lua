local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SyncController = require(script.Parent:WaitForChild("Modules"):WaitForChild("SyncController"))
local AnimatorUtils = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("AnimatorUtils"))

-- Create remote event
local LeaderRemotes = ReplicatedStorage:FindFirstChild("Remotes")
if not LeaderRemotes then
	LeaderRemotes = Instance.new("Folder")
	LeaderRemotes.Name = "Remotes"
	LeaderRemotes.Parent = ReplicatedStorage
end

local UpdateLeaderStatus = LeaderRemotes:FindFirstChild("UpdateLeaderStatus")
if not UpdateLeaderStatus then
	UpdateLeaderStatus = Instance.new("RemoteEvent")
	UpdateLeaderStatus.Name = "UpdateLeaderStatus"
	UpdateLeaderStatus.Parent = LeaderRemotes
end

-- Configuration
local CONFIG = {
	DEBUG_ENABLED = false,
	DEBOUNCE_TIME = 0.05,
	PERIODIC_CHECK_INTERVAL = 3
}

-- Connection management
local playerConnections = {}
local characterConnections = {}
local updateScheduled = false
local lastUpdateTime = 0

local function debug(...)
	if CONFIG.DEBUG_ENABLED then
		print("[LeaderTracker]", ...)
	end
end

-- Cleanup connections
local function cleanupPlayerConnections(player)
	if playerConnections[player] then
		for _, connection in ipairs(playerConnections[player]) do
			if connection and connection.Connected then
				connection:Disconnect()
			end
		end
		playerConnections[player] = nil
		debug("?? Cleaned up player connections for", player.Name)
	end
end

local function cleanupCharacterConnections(character)
	if characterConnections[character] then
		for _, connection in ipairs(characterConnections[character]) do
			if connection and connection.Connected then
				connection:Disconnect()
			end
		end
		characterConnections[character] = nil
		debug("?? Cleaned up character connections")
	end
end

-- Update single player
local function updatePlayerLeaderStatus(player)
	if not player or not player.Parent then return end
	if not player.Character then return end

	local followerCount = SyncController.getFollowerCount(player)
	local currentIsLeader = player.Character:GetAttribute("IsLeader")
	local currentFollowerCount = player.Character:GetAttribute("FollowerCount") or 0

	if followerCount > 0 then
		if currentIsLeader ~= true or currentFollowerCount ~= followerCount then
			player.Character:SetAttribute("IsLeader", true)
			player.Character:SetAttribute("FollowerCount", followerCount)
			UpdateLeaderStatus:FireAllClients(player, true, followerCount)
			debug("Set leader status:", player.Name, "Followers:", followerCount)
		end
	else
		if currentIsLeader or currentFollowerCount > 0 then
			player.Character:SetAttribute("IsLeader", nil)
			player.Character:SetAttribute("FollowerCount", nil)
			UpdateLeaderStatus:FireAllClients(player, false, 0)
			debug("Cleared leader status:", player.Name)
		end
	end
end

-- Immediate update all
local function immediateUpdateAll()
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			updatePlayerLeaderStatus(player)
		end
	end
end

-- Scheduled update with debounce (coalesce pattern)
-- Semua panggilan dalam window DEBOUNCE_TIME digabung menjadi 1 eksekusi.
local function scheduleUpdate()
	if updateScheduled then return end  -- sudah ada update pending, ikut antrian itu
	updateScheduled = true

	task.delay(CONFIG.DEBOUNCE_TIME, function()
		updateScheduled = false
		immediateUpdateAll()
		lastUpdateTime = tick()
	end)
end

-- Setup character tracking
local function setupCharacterTracking(player, character)
	debug("Setting up tracking for", player.Name)

	cleanupCharacterConnections(character)
	characterConnections[character] = {}

	-- Listen: Syncing attribute
	-- Hanya listener ini yang dibutuhkan — satu-satunya trigger eksternal yang
	-- perlu ditangkap. IsLeader & FollowerCount TIDAK didengarkan karena
	-- updatePlayerLeaderStatus() sudah FireAllClients setelah set kedua attribute
	-- tersebut; mendengarkannya hanya akan membuat cascade fire berganda.
	local syncingConnection = character:GetAttributeChangedSignal("Syncing"):Connect(function()
		local syncTarget = character:GetAttribute("Syncing")
		debug(syncTarget and "→" or "←", player.Name, syncTarget and "syncing to" or "stopped syncing", syncTarget or "")
		scheduleUpdate()
	end)
	table.insert(characterConnections[character], syncingConnection)

	-- Listen: Character death
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		local diedConnection = humanoid.Died:Connect(function()
			debug("??", player.Name, "died - clearing status")

			-- Clear attributes
			character:SetAttribute("IsLeader", nil)
			character:SetAttribute("FollowerCount", nil)
			character:SetAttribute("Syncing", nil)

			-- ?? NOTE: No manual cache cleanup needed (weak tables auto-cleanup!)

			-- Notify clients
			UpdateLeaderStatus:FireAllClients(player, false, 0)

			-- Cleanup connections
			cleanupCharacterConnections(character)
		end)
		table.insert(characterConnections[character], diedConnection)
	end

	task.wait(0.5)
	updatePlayerLeaderStatus(player)
end

-- Player character added
Players.PlayerAdded:Connect(function(player)
	debug("?", player.Name, "joined the game")

	if not playerConnections[player] then
		playerConnections[player] = {}
	end

	local charAddedConn = player.CharacterAdded:Connect(function(character)
		debug("??", player.Name, "spawned")

		task.spawn(function()
			character:WaitForChild("Humanoid")

			-- ?? NOTE: No manual cache cleanup needed!

			-- Clear attributes
			character:SetAttribute("Syncing", nil)
			character:SetAttribute("IsLeader", nil)
			character:SetAttribute("FollowerCount", nil)

			task.wait(0.1)
			setupCharacterTracking(player, character)
		end)
	end)
	table.insert(playerConnections[player], charAddedConn)

	local charRemovingConn = player.CharacterRemoving:Connect(function(character)
		debug("??", player.Name, "character removing")

		-- Clear attributes
		character:SetAttribute("Syncing", nil)
		character:SetAttribute("IsLeader", nil)
		character:SetAttribute("FollowerCount", nil)

		-- ?? NOTE: No manual cache cleanup needed!

		-- Notify clients
		UpdateLeaderStatus:FireAllClients(player, false, 0)

		-- Cleanup connections
		cleanupCharacterConnections(character)
	end)
	table.insert(playerConnections[player], charRemovingConn)

	-- Setup existing character
	if player.Character then
		-- ?? NOTE: No manual cache cleanup needed!

		player.Character:SetAttribute("Syncing", nil)
		player.Character:SetAttribute("IsLeader", nil)
		player.Character:SetAttribute("FollowerCount", nil)

		task.wait(0.1)
		setupCharacterTracking(player, player.Character)
	end
end)

-- Player removing
Players.PlayerRemoving:Connect(function(player)
	debug("??", player.Name, "left the game")

	-- Clear attributes
	if player.Character then
		player.Character:SetAttribute("Syncing", nil)
		player.Character:SetAttribute("IsLeader", nil)
		player.Character:SetAttribute("FollowerCount", nil)

		cleanupCharacterConnections(player.Character)
	end

	-- ?? NOTE: No manual cache cleanup needed (weak tables auto-cleanup!)

	-- Notify clients
	UpdateLeaderStatus:FireAllClients(player, false, 0)

	-- Cleanup connections
	cleanupPlayerConnections(player)

	task.defer(immediateUpdateAll)
end)

-- Periodic update (safety net)
-- Hanya koreksi drift tanpa set attribute — mencegah trigger listener Syncing
-- yang bisa menyebabkan scheduleUpdate() berjalan berulang.
local periodicUpdateTask = task.spawn(function()
	while true do
		task.wait(CONFIG.PERIODIC_CHECK_INTERVAL)

		for _, player in ipairs(Players:GetPlayers()) do
			if player.Character then
				local followerCount = SyncController.getFollowerCount(player)
				local currentIsLeader = player.Character:GetAttribute("IsLeader")
				local currentFollowerCount = player.Character:GetAttribute("FollowerCount") or 0

				local needsUpdate = false

				if followerCount > 0 and not currentIsLeader then
					needsUpdate = true
				elseif followerCount == 0 and currentIsLeader then
					needsUpdate = true
				elseif currentFollowerCount ~= followerCount then
					needsUpdate = true
				end

				if needsUpdate then
					debug("⚠ Fixing status drift for", player.Name)
					-- Panggil updatePlayerLeaderStatus yang sudah dilindungi
					-- scheduleUpdate() tidak dipakai di sini supaya koreksi
					-- periodic langsung terjadi tanpa menunggu debounce.
					updatePlayerLeaderStatus(player)
				end
			end
		end
	end
end)

-- Cleanup on shutdown
game:BindToClose(function()
	debug("Shutting down - cleaning up...")

	if periodicUpdateTask then
		task.cancel(periodicUpdateTask)
	end

	for character, _ in pairs(characterConnections) do
		cleanupCharacterConnections(character)
	end

	for player, _ in pairs(playerConnections) do
		cleanupPlayerConnections(player)
	end

	-- ?? NOTE: No manual cache cleanup needed (Lua GC will handle it!)

	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			player.Character:SetAttribute("Syncing", nil)
			player.Character:SetAttribute("IsLeader", nil)
			player.Character:SetAttribute("FollowerCount", nil)
		end
	end

	debug("Cleanup complete")
end)

-- Initialization
task.spawn(function()
	task.wait(2)

	debug("-----------------------------------")
	debug("Leader Status Tracker ACTIVE")
	debug("-----------------------------------")
	debug("Mode: Hybrid (Auto Cache Cleanup)")
	debug("Tracking:", #Players:GetPlayers(), "players")
	debug("-----------------------------------")

	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			-- ?? NOTE: No manual cache cleanup needed!

			player.Character:SetAttribute("Syncing", nil)
			player.Character:SetAttribute("IsLeader", nil)
			player.Character:SetAttribute("FollowerCount", nil)

			task.wait(0.1)
			setupCharacterTracking(player, player.Character)
		end
	end

	immediateUpdateAll()
end)