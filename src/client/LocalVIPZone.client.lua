local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local player = Players.LocalPlayer

local ALLOWED_ROLES = {
	["VIP"] = true, ["VVIP"] = true, ["Moderator"] = true,
	["Admin"] = true, ["Owner"] = true, ["Sultan"] = true,
	["Head Staff"] = true, ["Staff"] = true
}

local function checkAccess()
	local roleVal = player:FindFirstChild("Role")
	return roleVal and ALLOWED_ROLES[roleVal.Value] or false
end

local function updateSingleDoor(door)
	if checkAccess() then
		door.CanCollide = false
		door.Transparency = 1.0
	else
		door.CanCollide = true
		door.Transparency = 1.0
	end
end

local function updateAllDoors()
	-- Hanya mencari barang yang punya Tag "PintuVIP"
	for _, door in ipairs(CollectionService:GetTagged("PintuVIP")) do
		updateSingleDoor(door)
	end
end

-- 1. PANTAU PERUBAHAN ROLE
task.spawn(function()
	local roleVal = player:WaitForChild("Role", 15)
	if roleVal then
		updateAllDoors() 
		roleVal.Changed:Connect(updateAllDoors)
	end
end)

-- 2. FIX STREAMING ENABLED (ANTI-LAG MAKSIMAL)
-- Mesin hanya akan bereaksi JIKA barang yang di-render punya Tag "PintuVIP"
CollectionService:GetInstanceAddedSignal("PintuVIP"):Connect(function(door)
	updateSingleDoor(door)
end)

updateAllDoors()