--!native
--!optimize 2

local ScriptOnce = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("ScriptOnce"))
if not ScriptOnce.Claim("GlobalAntiCollision") then return end

local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")

local GROUP_NAME = "AllPlayers"

pcall(function()
	PhysicsService:RegisterCollisionGroup(GROUP_NAME)
end)
pcall(function()
	PhysicsService:CollisionGroupSetCollidable(GROUP_NAME, GROUP_NAME, false)
end)

local LIMB_NAMES = {
	["Head"] = true,
	["LeftUpperArm"] = true,
	["LeftLowerArm"] = true,
	["LeftHand"] = true,
	["RightUpperArm"] = true,
	["RightLowerArm"] = true,
	["RightHand"] = true,
	["LeftUpperLeg"] = true,
	["LeftLowerLeg"] = true,
	["LeftFoot"] = true,
	["RightUpperLeg"] = true,
	["RightLowerLeg"] = true,
	["RightFoot"] = true,
	["Left Arm"] = true,
	["Right Arm"] = true,
	["Left Leg"] = true,
	["Right Leg"] = true,
}

local function optimizeBasePart(part)
	if not part:IsA("BasePart") then return end

	if part.CollisionGroup ~= GROUP_NAME then
		part.CollisionGroup = GROUP_NAME
	end

	local isAccessory = part:FindFirstAncestorWhichIsA("Accessory") ~= nil
	if isAccessory then
		if part.CanCollide then part.CanCollide = false end
		if part.CanTouch then part.CanTouch = false end
		if part.CanQuery then part.CanQuery = false end
		if not part.Massless then part.Massless = true end
		if part.CastShadow then part.CastShadow = false end
		return
	end

	if part.Name == "HumanoidRootPart" then
		part.Massless = false
		part.CanTouch = true
		return
	end

	if part.Name == "UpperTorso" or part.Name == "LowerTorso" or part.Name == "Torso" then
		part.CanTouch = true
		return
	end

	if LIMB_NAMES[part.Name] then
		if part.CanCollide then part.CanCollide = false end
		if part.CanTouch then part.CanTouch = false end
		if not part.Massless then part.Massless = true end
	end
end

local playerConnections = {}

local function cleanupPlayerConnections(player)
	local conns = playerConnections[player]
	if conns then
		for _, conn in ipairs(conns) do
			if conn and conn.Connected then
				conn:Disconnect()
			end
		end
		playerConnections[player] = nil
	end
end

local function onCharacterAdded(character, player)
	cleanupPlayerConnections(player)
	playerConnections[player] = {}

	for _, inst in ipairs(character:GetDescendants()) do
		if inst:IsA("BasePart") then
			optimizeBasePart(inst)
		end
	end

	local conn = character.DescendantAdded:Connect(function(child)
		if child:IsA("BasePart") then
			optimizeBasePart(child)
		end
	end)
	table.insert(playerConnections[player], conn)
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(char)
		onCharacterAdded(char, player)
	end)
	if player.Character then
		onCharacterAdded(player.Character, player)
	end
end)

for _, player in ipairs(Players:GetPlayers()) do
	player.CharacterAdded:Connect(function(char)
		onCharacterAdded(char, player)
	end)
	if player.Character then
		onCharacterAdded(player.Character, player)
	end
end

Players.PlayerRemoving:Connect(function(player)
	cleanupPlayerConnections(player)
end)
