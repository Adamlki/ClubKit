-- Letak: ServerScriptService > GlobalWeaponRouter
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local RemoteEventManager = require(ServerScriptService:WaitForChild("Modules"):WaitForChild("RemoteEventManager"))

-- 🔥 ARCHITECT FIX: Gunakan RemoteEvent yang sudah Anda buat manual di Explorer
local globalEvent = ReplicatedStorage:WaitForChild("GlobalWeaponEvent")

globalEvent.OnServerEvent:Connect(function(player, toolName, isShooting)
	-- 🔥 SECURITY FIX: Cegah Type Spoofing & Serangan Bandwidth (Payload Size Exploitation)
	if type(toolName) ~= "string" then return end
	if string.len(toolName) > 50 then return end
	if type(isShooting) ~= "boolean" then return end

	-- 🔥 ARCHITECT FIX: Rate limit berlaku untuk true maupun false agar tidak bisa dipakai broadcast DoS
	if not RemoteEventManager.checkRateLimit(player, "waterGunShoot") then return end

	-- KEAMANAN: Pastikan pemain benar-benar memegang Tool tersebut
	local tool = player.Character and player.Character:FindFirstChild(toolName)
	if not tool or not tool:IsA("Tool") then return end

	-- ROUTING: Proximity-based multicast broadcast (Optimasi 100+ Player: cegah spam paket ke seluruh server)
	local char = player.Character
	local rootPart = char and char:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end

	local shooterPos = rootPart.Position
	-- Radius pandang ~100 studs saat menembak, kelonggaran 120 studs saat stop agar efek tidak nyangkut
	local maxRadius = isShooting and 100 or 120
	local maxRadiusSq = maxRadius * maxRadius

	for _, targetPlayer in ipairs(Players:GetPlayers()) do
		if targetPlayer ~= player then
			local targetChar = targetPlayer.Character
			local targetRoot = targetChar and targetChar:FindFirstChild("HumanoidRootPart")
			if targetRoot then
				local diff = targetRoot.Position - shooterPos
				local distSq = diff.X * diff.X + diff.Y * diff.Y + diff.Z * diff.Z
				if distSq <= maxRadiusSq then
					globalEvent:FireClient(targetPlayer, player, toolName, isShooting)
				end
			end
		end
	end
end)