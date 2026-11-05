local Players       = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local RoleSystem  = require(ServerStorage.Modules.RoleSystem)
local TeamGroups  = require(ServerStorage.Modules.TeamGroups)
local CustomTeams = require(ServerStorage.Modules.CustomTeams)

CustomTeams.LoadFromDataStore()
TeamGroups.CreateDefaultTeams()
CustomTeams.AppendCustomTeams()
TeamGroups.Init(CustomTeams.HasOverride)
CustomTeams.Init()

local assignedPlayers = {}

local function assignPlayerOnce(player)
	if not player or not player.Parent then return end
	if assignedPlayers[player] then return end
	assignedPlayers[player] = true
	CustomTeams.AssignNewPlayer(player)
end

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(assignPlayerOnce, player)
end

Players.PlayerAdded:Connect(assignPlayerOnce)
Players.PlayerRemoving:Connect(function(player)
	assignedPlayers[player] = nil
end)
