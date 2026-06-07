local Logger = require(script.Parent.Logger)

local Players = game:GetService("Players")

local ValidationManager = {}

function ValidationManager:ValidatePlayer(player)
	if not player or not player:IsDescendantOf(Players) then
		Logger:Debug("Invalid player validation failed")
		return false
	end
	return true
end

return ValidationManager