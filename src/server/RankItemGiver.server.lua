-- RANK ITEM GIVER SYSTEM

local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")

-- LOAD ROLE SYSTEM MODULE
local RoleSystem = require(ServerStorage.Modules.RoleSystem)

-- CONFIGURATION
local itemsFolder = ServerStorage:WaitForChild("Items", 10)

local function getItemTemplate(itemName)
	if not itemsFolder then
		itemsFolder = ServerStorage:FindFirstChild("Items") or ServerStorage:WaitForChild("Items", 5)
	end
	if itemsFolder then
		return itemsFolder:FindFirstChild(itemName) or itemsFolder:WaitForChild(itemName, 5)
	end
	return nil
end

local Config = {
	DebugMode = false,

	RankItems = {
		{
			Name = "AFK",
			MinimumHierarchy = 2 -- VIP ke atas
		},
		{
			Name = "Glowstick",
			MinimumHierarchy = 2 -- VIP ke atas
		},
		{
			Name = "Umbrella",
			MinimumHierarchy = 2 -- VIP ke atas
		},
		{
			Name = "Sharky",
			MinimumHierarchy = 2 -- VIP ke atas
		},
		{
			Name = "WaterGun",
			MinimumHierarchy = 2 -- VIP ke atas
		},
		{
			Name = "Heart",
			MinimumHierarchy = 2 -- VIP ke atas
		},
		{
			Name = "Mawar",
			MinimumHierarchy = 2 -- VIP ke atas
		},
	}
}

-- UTILITY FUNCTIONS

local function debugPrint(...)
	if Config.DebugMode then
		print("[ItemGiver]", ...)
	end
end

local function cleanAllDuplicates(player, itemName)
	local removed = 0

	if player.Backpack then
		for _, item in ipairs(player.Backpack:GetChildren()) do
			if item.Name == itemName and item:IsA("Tool") then
				item:Destroy()
				removed = removed + 1
			end
		end
	end

	if player.Character then
		for _, item in ipairs(player.Character:GetChildren()) do
			if item.Name == itemName and item:IsA("Tool") then
				item:Destroy()
				removed = removed + 1
			end
		end
	end

	if removed > 0 then
		debugPrint(string.format("Cleaned %d duplicate(s) of %s from %s", removed, itemName, player.Name))
	end
end

local function optimizeToolPhysics(tool)
	for _, descendant in ipairs(tool:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Massless = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
		end
	end
end

local function giveItemToPlayer(player, itemConfig, playerRole)
	if not player or not player.Backpack then return end
	local template = getItemTemplate(itemConfig.Name)
	if not template then
		warn(string.format("[ItemGiver] ⚠️ Item template '%s' tidak ditemukan di ServerStorage.Items!", itemConfig.Name))
		return
	end

	cleanAllDuplicates(player, itemConfig.Name)

	local itemClone = template:Clone()
	optimizeToolPhysics(itemClone)
	itemClone.Parent = player.Backpack

	debugPrint(string.format("Gave %s to %s (Rank: %s)", itemConfig.Name, player.Name, playerRole or "?"))
end

local function checkAndGiveItems(player)
	if not player or not player.Parent then return end

	-- Ambil role sekali per pemain, bukan per item.
	local playerRole = RoleSystem:GetPlayerRole(player)
	local playerHierarchy = RoleSystem.Config.RoleHierarchy[playerRole] or 0

	for _, itemConfig in ipairs(Config.RankItems) do
		if playerHierarchy >= itemConfig.MinimumHierarchy then
			giveItemToPlayer(player, itemConfig, playerRole)
		else
			cleanAllDuplicates(player, itemConfig.Name)
		end
	end
end

-- PLAYER MANAGEMENT

local function onPlayerAdded(player)
	RoleSystem:InitializePlayer(player)

	player.CharacterAdded:Connect(function(character)
		local waited = 0
		while not player:HasAppearanceLoaded() and player.Parent and waited < 5 do
			waited += task.wait(0.2)
		end
		
		task.wait(0.5)
		if not player or not player.Parent or not character or not character.Parent then return end
		checkAndGiveItems(player)
	end)
end

-- ROLE CHANGE HANDLER

RoleSystem.RoleChanged:Connect(function(player, oldRole, newRole)
	debugPrint(string.format("Role changed: %s (%s -> %s)", player.Name, oldRole, newRole))

	task.spawn(function()
		task.wait(0.5)
		checkAndGiveItems(player)
	end)
end)

-- INITIALIZATION

Players.PlayerAdded:Connect(onPlayerAdded)

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(function()
		onPlayerAdded(player)
		if player.Character then
			task.spawn(function()
				task.wait(0.5)
				checkAndGiveItems(player)
			end)
		end
	end)
end

debugPrint("Rank Item Giver System (Option A) initialized successfully!")
