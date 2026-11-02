-- Letak: StarterPlayer > StarterPlayerScripts > GlobalVisualHandler
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local globalEvent = ReplicatedStorage:WaitForChild("GlobalWeaponEvent")

local localPlayer = Players.LocalPlayer
local MAX_DISTANCE = 60

local activeVisuals = {}

local function getLocalRoot()
	local char = localPlayer.Character
	return char and char:FindFirstChild("HumanoidRootPart")
end

local function clearVisual(userId)
	local data = activeVisuals[userId]
	if not data then return end
	if data.water and data.water.Parent then
		data.water.Enabled = false
	end
	if data.sound and data.sound.Parent and data.sound.IsPlaying then
		data.sound:Stop()
	end
	activeVisuals[userId] = nil
end

local function setVisual(player, toolName, state)
	if not player or player == localPlayer then return end
	local userId = player.UserId

	if not state then
		clearVisual(userId)
		return
	end

	local char = player.Character
	local tool = char and char:FindFirstChild(toolName)
	if not (tool and tool.Name == "WaterGun") then
		clearVisual(userId)
		return
	end

	local myRoot = getLocalRoot()
	local shooterRoot = char:FindFirstChild("HumanoidRootPart")
	if myRoot and shooterRoot and (myRoot.Position - shooterRoot.Position).Magnitude > MAX_DISTANCE then
		clearVisual(userId)
		return
	end

	local muzzlePart = tool:FindFirstChild("MuzzlePart")
	local handle = tool:FindFirstChild("Handle")
	if not (muzzlePart and handle) then
		clearVisual(userId)
		return
	end

	local water = muzzlePart:FindFirstChild("Water")
	local sound = handle:FindFirstChild("Explosion")

	local existing = activeVisuals[userId]
	if existing and existing.water == water and existing.sound == sound then
		if water then water.Enabled = true end
		if sound and not sound.IsPlaying then sound:Play() end
		return
	end

	clearVisual(userId)
	if water then water.Enabled = true end
	if sound and not sound.IsPlaying then sound:Play() end
	activeVisuals[userId] = {
		water = water,
		sound = sound,
	}
end

local function applyBatch(entries)
	local seen = {}
	for _, entry in ipairs(entries) do
		if type(entry) == "table" then
			local userId = tonumber(entry.userId)
			local player = userId and Players:GetPlayerByUserId(userId)
			if player then
				seen[userId] = true
				setVisual(player, entry.toolName, true)
			end
		end
	end

	for userId in pairs(activeVisuals) do
		if not seen[userId] then
			clearVisual(userId)
		end
	end
end

globalEvent.OnClientEvent:Connect(function(first, toolName, state)
	if type(first) == "table" then
		applyBatch(first)
		return
	end
	-- Backward compatibility with the old single-shooter payload.
	setVisual(first, toolName, state)
end)

Players.PlayerRemoving:Connect(function(player)
	clearVisual(player.UserId)
end)
