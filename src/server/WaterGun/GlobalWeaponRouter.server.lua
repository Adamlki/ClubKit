-- Letak: ServerScriptService > GlobalWeaponRouter
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- 🔥 ARCHITECT FIX: Gunakan RemoteEvent yang sudah Anda buat manual di Explorer
local globalEvent = ReplicatedStorage:WaitForChild("GlobalWeaponEvent")

local lastFired = {}

globalEvent.OnServerEvent:Connect(function(player, toolName, isShooting)
	-- KEAMANAN: Pastikan pemain benar-benar memegang Tool tersebut
	local tool = player.Character and player.Character:FindFirstChild(toolName)
	if not tool then return end

	local now = os.clock()

	-- RATE-LIMITER: Mencegah spam exploit
	if isShooting then
		if lastFired[player.UserId] and (now - lastFired[player.UserId]) < 0.05 then return end
		lastFired[player.UserId] = now
	end

	-- ROUTING: Broadcast ke klien lain beserta nama senjatanya
	for _, otherPlayer in ipairs(Players:GetPlayers()) do
		if otherPlayer ~= player then
			globalEvent:FireClient(otherPlayer, player, toolName, isShooting)
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	lastFired[player.UserId] = nil
end)