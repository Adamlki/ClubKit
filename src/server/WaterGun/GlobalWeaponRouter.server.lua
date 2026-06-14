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

	-- 🔥 ARCHITECT FIX: Gunakan RemoteEventManager untuk Anti-Spam
	if isShooting then
		if not RemoteEventManager.checkRateLimit(player, "waterGunShoot") then return end
	end

	-- KEAMANAN: Pastikan pemain benar-benar memegang Tool tersebut
	local tool = player.Character and player.Character:FindFirstChild(toolName)
	if not tool then return end

	-- ROUTING: Broadcast ke klien lain beserta nama senjatanya
	for _, otherPlayer in ipairs(Players:GetPlayers()) do
		if otherPlayer ~= player then
			globalEvent:FireClient(otherPlayer, player, toolName, isShooting)
		end
	end
end)