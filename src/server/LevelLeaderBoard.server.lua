local Players            = game:GetService("Players")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local ServerStorage      = game:GetService("ServerStorage")

local DEBUG_ENABLED = false 
local DEBUG_PREFIX = "[LevelBoard Server]"

local function debugPrint(...)
	if DEBUG_ENABLED then print(DEBUG_PREFIX, ...) end
end

local LevelSystem = require(ServerStorage:WaitForChild("Modules"):WaitForChild("LevelSystem"))
local remote = Instance.new("RemoteEvent")
remote.Name = "UpdateLevelBoard"
remote.Parent = ReplicatedStorage

-- ====================================
-- PLAYER MANAGEMENT (ANTI GHOSTING FIX)
-- ====================================
local function onPlayerJoin(player)
	debugPrint("Player joined:", player.Name)
	LevelSystem:InitializePlayer(player)
end

Players.PlayerAdded:Connect(onPlayerJoin)

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(function()
		onPlayerJoin(player)
	end)
end

Players.PlayerRemoving:Connect(function(player)
	debugPrint("Player leaving:", player.Name)
	pcall(function()
		if LevelSystem.CleanupPlayer then
			LevelSystem:CleanupPlayer(player)
		elseif LevelSystem.SavePlayerLevel then
			LevelSystem:SavePlayerLevel(player, true)
		end
	end)
end)

-- ====================================
-- AUTO-SAVE & REFRESH LOOP
-- ====================================
task.spawn(function()
	while true do
		-- 🟡 FIX 1: Interval dinaikkan ke 10 Menit untuk 100 Player (600 detik)
		task.wait(600)
		for _, player in ipairs(Players:GetPlayers()) do
			pcall(function() LevelSystem:SavePlayerLevel(player) end)
			-- 🟡 FIX 2: Staggered Saving! Beri jeda 0.5 detik antar pemain agar DataStore Roblox tidak ter-spam dan error!
			task.wait(0.5) 
		end
	end
end)

task.spawn(function()
	task.wait(10)
	while true do
		local ok, topData = pcall(function() return LevelSystem:GetTopPlayers(100) end)
		if ok and topData and #topData > 0 then
			remote:FireAllClients(topData)
			debugPrint("Leaderboard refreshed -", #topData, "players")
		end
		task.wait(60) 
	end
end)

-- ====================================
-- SHUTDOWN HANDLER
-- ====================================
game:BindToClose(function()
	local players = Players:GetPlayers()
	local totalPlayers = #players
	if totalPlayers == 0 then return end
	
	local savedCount = 0
	local bindable = Instance.new("BindableEvent")
	
	for _, player in ipairs(players) do
		task.spawn(function()
			pcall(function() LevelSystem:SavePlayerLevel(player, true) end)
			savedCount += 1
			if savedCount >= totalPlayers then
				bindable:Fire()
			end
		end)
	end
	
	-- Tunggu maksimal 25 detik (Batas Roblox adalah 30 detik)
	task.delay(25, function()
		if savedCount < totalPlayers then
			bindable:Fire()
		end
	end)
	
	bindable.Event:Wait()
	bindable:Destroy()
	debugPrint("All player levels saved successfully on shutdown!")
end)