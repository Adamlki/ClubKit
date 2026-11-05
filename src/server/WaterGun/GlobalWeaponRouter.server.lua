local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local RemoteEventManager = require(ServerScriptService:WaitForChild("Modules"):WaitForChild("RemoteEventManager"))

local globalEvent = ReplicatedStorage:WaitForChild("GlobalWeaponEvent")

local BATCH_INTERVAL = 0.2
local activeShooters = {}
local lastBatchCount = 0

local function clearShooter(userId)
	activeShooters[userId] = nil
end

globalEvent.OnServerEvent:Connect(function(player, toolName, isShooting)
	if type(toolName) ~= "string" or #toolName > 50 then return end
	if type(isShooting) ~= "boolean" then return end

	if not isShooting then
		clearShooter(player.UserId)
		return
	end

	if not RemoteEventManager.checkRateLimit(player, "waterGunShoot") then return end

	local tool = player.Character and player.Character:FindFirstChild(toolName)
	if not tool or not tool:IsA("Tool") then return end

	activeShooters[player.UserId] = {
		player = player,
		toolName = toolName,
	}
end)

Players.PlayerRemoving:Connect(function(player)
	clearShooter(player.UserId)
end)

task.spawn(function()
	while true do
		task.wait(BATCH_INTERVAL)

		local entries = {}
		for userId, data in pairs(activeShooters) do
			local player = data.player
			local character = player and player.Parent and player.Character
			local tool = character and character:FindFirstChild(data.toolName)
			if not (tool and tool:IsA("Tool")) then
				activeShooters[userId] = nil
			else
				table.insert(entries, {
					userId = userId,
					toolName = data.toolName,
				})
			end
		end

		if #entries > 0 or lastBatchCount > 0 then
			globalEvent:FireAllClients(entries)
			lastBatchCount = #entries
		end
	end
end)
