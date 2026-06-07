local Players = game:GetService("Players")
local PermissionManager = {}

local RoleSystem = nil

function PermissionManager:Init(roleSystem)
	RoleSystem = roleSystem
end

function PermissionManager:HasAccess(userId)
	local player = Players:GetPlayerByUserId(userId)
	if not player then return false end

	local role = RoleSystem:GetPlayerRole(player)
	return role == "Owner" or role == "Admin"
end

return PermissionManager