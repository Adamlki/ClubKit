local NametagDisabler = {}
local nametagConnections = {}

function NametagDisabler:Init()
	-- Module initialized
end

function NametagDisabler:DisableNametag(player, character)
	local humanoid = character:WaitForChild("Humanoid", 5)
	if not humanoid then return end

	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None

	if nametagConnections[player.UserId] then
		nametagConnections[player.UserId]:Disconnect()
	end

	nametagConnections[player.UserId] = humanoid:GetPropertyChangedSignal("DisplayDistanceType"):Connect(function()
		if humanoid.DisplayDistanceType ~= Enum.HumanoidDisplayDistanceType.None then
			humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		end
	end)
end

function NametagDisabler:Cleanup(player)
	if nametagConnections[player.UserId] then
		nametagConnections[player.UserId]:Disconnect()
		nametagConnections[player.UserId] = nil
	end
end

return NametagDisabler