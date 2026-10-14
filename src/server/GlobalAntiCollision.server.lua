--!native
--!optimize 2
-- ==============================================================================
-- GLOBAL ANTI-COLLISION SYSTEM (ZERO-LAG ARCHITECTURE)
-- Mengatur CollisionGroup AllPlayers agar pemain tidak saling bertabrakan
-- Menggunakan Singleton Guard & Fast-Filter Property Checking
-- ==============================================================================

if _G.__GlobalAntiCollisionLoaded then
	return
end
_G.__GlobalAntiCollisionLoaded = true

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
	-- R6 limb compatibility
	["Left Arm"] = true,
	["Right Arm"] = true,
	["Left Leg"] = true,
	["Right Leg"] = true,
}

local function optimizeBasePart(part)
	if not part:IsA("BasePart") then return end

	-- Semua part karakter wajib masuk ke CollisionGroup AllPlayers
	if part.CollisionGroup ~= GROUP_NAME then
		part.CollisionGroup = GROUP_NAME
	end

	local isAccessory = part:FindFirstAncestorWhichIsA("Accessory") ~= nil
	if isAccessory then
		-- Aksesoris (topi/sayap/tas/senjata/layered clothing)
		if part.CanCollide then part.CanCollide = false end
		if part.CanTouch then part.CanTouch = false end
		if part.CanQuery then part.CanQuery = false end
		if not part.Massless then part.Massless = true end
		if part.CastShadow then part.CastShadow = false end
		return
	end

	-- Root & Torso tetap memegang gravitasi, pergerakan, dan zona deteksi
	if part.Name == "HumanoidRootPart" then
		part.Massless = false
		part.CanTouch = true
		return
	end

	if part.Name == "UpperTorso" or part.Name == "LowerTorso" or part.Name == "Torso" then
		part.CanTouch = true
		return
	end

	-- Anggota tubuh (Limbs):
	-- Massless = true & CanTouch = false
	-- Karakter tetap 100% bebas bergerak & menari, tetapi engine fisika Roblox
	-- hanya mereplikasi 1 center of mass ke server (memangkas KB/s Sent)
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

	-- 1. Scan awal semua bagian yang sudah ada
	for _, inst in ipairs(character:GetDescendants()) do
		if inst:IsA("BasePart") then
			optimizeBasePart(inst)
		end
	end

	-- 2. Listener untuk part baru (aksesoris/tool yang baru terpasang)
	-- Filter ketat: HANYA BasePart, TANPA loop GetDescendants rekursif
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