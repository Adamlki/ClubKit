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

	-- DISTANCE CULLING: Jaga FPS Client tetap tinggi!
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
		local muzzlePart = shooterTool:FindFirstChild("MuzzlePart")
		local handle = shooterTool:FindFirstChild("Handle")

		if muzzlePart and handle then
			local water = muzzlePart:FindFirstChild("Water")
			local sound = handle:FindFirstChild("Explosion")

			-- 🔥 PERBAIKAN: Hapus warn() agar terhindar dari Console FPS Drop (Lag Klien)
			if water then 
				water.Enabled = state 
			end

			if sound then 
				if state then sound:Play() else sound:Stop() end 
			end
		end
	end
end)