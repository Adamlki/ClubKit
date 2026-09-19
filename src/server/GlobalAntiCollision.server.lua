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

-- Fungsi ultra-cepat: hanya menyentuh properti jika nilainya BERBEDA
local function optimizeBasePart(part)
	if not part:IsA("BasePart") then return end

	local isAccessory = part:FindFirstAncestorWhichIsA("Accessory") ~= nil
	if not isAccessory then
		-- Hanya ganti CollisionGroup jika belum sama (Mencegah banjir sinyal fisika)
		if part.CollisionGroup ~= GROUP_NAME then
			part.CollisionGroup = GROUP_NAME
		end
	else
		-- Khusus aksesori, matikan shadow hanya jika masih aktif
		if part.CastShadow then
			part.CastShadow = false
		end
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