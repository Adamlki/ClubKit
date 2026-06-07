-- Letak: StarterPlayer > StarterPlayerScripts > GlobalVisualHandler
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local globalEvent = ReplicatedStorage:WaitForChild("GlobalWeaponEvent")

local localPlayer = Players.LocalPlayer

globalEvent.OnClientEvent:Connect(function(shooterPlayer, toolName, state)
	if not shooterPlayer or not shooterPlayer.Character then return end
	if shooterPlayer == localPlayer then return end -- Abaikan tembakan sendiri

	local shooterTool = shooterPlayer.Character:FindFirstChild(toolName)
	if not shooterTool then return end

	-- DISTANCE CULLING (Optimasi Performa yang sangat baik dari kode Anda)
	local myChar = localPlayer.Character
	if myChar and myChar:FindFirstChild("HumanoidRootPart") then
		local shooterRoot = shooterPlayer.Character:FindFirstChild("HumanoidRootPart")
		if shooterRoot then
			local distance = (myChar.HumanoidRootPart.Position - shooterRoot.Position).Magnitude
			if distance > 60 and state == true then
				return 
			end
		end
	end


	if toolName == "WaterGun" then
		-- 🔥 ARCHITECT FIX: Gunakan nama yang sangat spesifik
		local muzzlePart = shooterTool:FindFirstChild("MuzzlePart")
		local handle = shooterTool:FindFirstChild("Handle")

		if muzzlePart and handle then
			local water = muzzlePart:FindFirstChild("Water")
			local sound = handle:FindFirstChild("Explosion")

			if water then 
				water.Enabled = state 
			else
				warn("[Global Handler] Gagal: Objek 'Water' tidak ditemukan di MuzzlePart milik " .. shooterPlayer.Name)
			end

			if sound then 
				if state then sound:Play() else sound:Stop() end 
			else
				warn("[Global Handler] Gagal: Objek 'Explosion' tidak ditemukan di Handle milik " .. shooterPlayer.Name)
			end
		else
			warn("[Global Handler] Gagal: MuzzlePart atau Handle tidak ditemukan pada WaterGun milik " .. shooterPlayer.Name)
		end
	end

	-- Note: Anda bisa menambahkan blok 'elseif toolName == "MoneyGun"' di sini nanti
end)