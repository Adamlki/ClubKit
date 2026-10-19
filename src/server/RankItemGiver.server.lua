-- ====================================
-- RANK ITEM GIVER SYSTEM
-- ====================================

local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")

-- ====================================
-- LOAD ROLE SYSTEM MODULE
-- ====================================
local RoleSystem = require(ServerStorage.Modules.RoleSystem)

-- ====================================
-- CONFIGURATION
-- ====================================
local Config = {
	DebugMode = false,

	RankItems = {
		{
			Name = "AFK",
			Path = ServerStorage.Items.AFK,
			MinimumHierarchy = 2 -- VIP ke atas
		},
		{
			Name = "Glowstick",
			Path = ServerStorage.Items.Glowstick,
			MinimumHierarchy = 2 -- VIP ke atas
		},
		{
			Name = "Umbrella",
			Path = ServerStorage.Items.Umbrella,
			MinimumHierarchy = 2 -- VIP ke atas
		},
		{
			Name = "Sharky",
			Path = ServerStorage.Items.Sharky,
			MinimumHierarchy = 2 -- VIP ke atas
		},
		{
			Name = "WaterGun",
			Path = ServerStorage.Items.WaterGun,
			MinimumHierarchy = 2 -- VIP ke atas
		},
		{
			Name = "Heart",
			Path = ServerStorage.Items.Heart,
			MinimumHierarchy = 2 -- VIP ke atas
		},
		{
			Name = "Mawar",
			Path = ServerStorage.Items.Mawar,
			MinimumHierarchy = 2 -- VIP ke atas
		},
	}
}

-- ====================================
-- UTILITY FUNCTIONS
-- ====================================

local function debugPrint(...)
	if Config.DebugMode then
		print("[ItemGiver]", ...)
	end
end

local function hasMinimumRank(player, minimumHierarchy)
	local playerRole = RoleSystem:GetPlayerRole(player)
	local playerHierarchy = RoleSystem.Config.RoleHierarchy[playerRole] or 0
	return playerHierarchy >= minimumHierarchy
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


local function giveItemToPlayer(player, itemConfig)
	if not player or not player.Backpack then return end
	if not itemConfig.Path or not itemConfig.Path.Parent then return end

	cleanAllDuplicates(player, itemConfig.Name)

	local itemClone = itemConfig.Path:Clone()
	optimizeToolPhysics(itemClone)
	itemClone.Parent = player.Backpack

	debugPrint(string.format("Gave %s to %s (Rank: %s)", itemConfig.Name, player.Name, RoleSystem:GetPlayerRole(player)))
end

local function checkAndGiveItems(player)
	if not player or not player.Parent then return end

	for _, itemConfig in ipairs(Config.RankItems) do
		if hasMinimumRank(player, itemConfig.MinimumHierarchy) then
			giveItemToPlayer(player, itemConfig)
		else
			cleanAllDuplicates(player, itemConfig.Name)
		end
	end
end

-- ====================================
-- PLAYER MANAGEMENT
-- ====================================

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

-- ====================================
-- ROLE CHANGE HANDLER
-- ====================================

RoleSystem.RoleChanged:Connect(function(player, oldRole, newRole)
	debugPrint(string.format("Role changed: %s (%s -> %s)", player.Name, oldRole, newRole))

	task.spawn(function()
		task.wait(0.5)
		checkAndGiveItems(player)
	end)
end)

-- ====================================
-- INITIALIZATION
-- ====================================

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