-- ====================================
-- VVIP ACCESSORY GIVER WITH EQUIP/UNEQUIP
-- Place in ServerScriptService
-- ====================================

local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Load RoleSystem Module
local RoleSystem = require(ServerStorage.Modules.RoleSystem)

-- ====================================
-- REMOTE EVENTS SETUP
-- ====================================
local RemotesFolder = ReplicatedStorage:FindFirstChild("AccessoryRemotes") or Instance.new("Folder")
RemotesFolder.Name = "AccessoryRemotes"
RemotesFolder.Parent = ReplicatedStorage

local AccessoryEvent = RemotesFolder:FindFirstChild("ToggleAccessory") or Instance.new("RemoteEvent")
AccessoryEvent.Name = "ToggleAccessory"
AccessoryEvent.Parent = RemotesFolder

local ShowIconEvent = RemotesFolder:FindFirstChild("ShowIcon") or Instance.new("RemoteEvent")
ShowIconEvent.Name = "ShowIcon"
ShowIconEvent.Parent = RemotesFolder

-- ====================================
-- CONFIGURATION
-- ====================================
local Config = {
	-- Debug Settings
	DebugMode = false,

	-- Item Settings
	AccessoryPath = ServerStorage:WaitForChild("Items"):WaitForChild("Crown8bit"),
	RequiredRole = "VVIP",

	-- Role Behavior
	IncludeHigherRoles = true,

	-- Storage
	StorageTag = "VVIP_AccessoryOwned",

	-- Timing
	RoleCheckDelay = 0.1
}

-- ====================================
-- PLAYER DATA TRACKING
-- ====================================
local PlayerAccessoryData = {} -- [UserId] = {owned = bool, equipped = bool}

-- ====================================
-- DEBUG SYSTEM
-- ====================================
local function debugPrint(message, isSuccess)
	if not Config.DebugMode then return end
	local prefix = isSuccess and "[✓ SUCCESS]" or "[✗ FAILED]"
	local color = isSuccess and "🟢" or "🔴"
	print(color .. " " .. prefix .. " " .. message)
end

-- ====================================
-- ACCESSORY FUNCTIONS
-- ====================================
local function equipAccessory(character, player)
	-- Cek jika sudah equipped
	if character:FindFirstChild(Config.AccessoryPath.Name) then
		debugPrint(player.Name .. " accessory already equipped", false)
		return false
	end

	-- Clone dan equip
	local success, err = pcall(function()
		local accessory = Config.AccessoryPath:Clone()
		accessory.Parent = character
	end)

	if success then
		if PlayerAccessoryData[player.UserId] then
			PlayerAccessoryData[player.UserId].equipped = true
		end
		debugPrint(player.Name .. " equipped accessory", true)
		return true
	else
		debugPrint(player.Name .. " failed to equip: " .. tostring(err), false)
		return false
	end
end

local function unequipAccessory(character, player)
	local accessory = character:FindFirstChild(Config.AccessoryPath.Name)

	if not accessory then
		debugPrint(player.Name .. " no accessory to unequip", false)
		return false
	end

	local success, err = pcall(function()
		accessory:Destroy()
	end)

	if success then
		if PlayerAccessoryData[player.UserId] then
			PlayerAccessoryData[player.UserId].equipped = false
		end
		debugPrint(player.Name .. " unequipped accessory", true)
		return true
	else
		debugPrint(player.Name .. " failed to unequip: " .. tostring(err), false)
		return false
	end
end

local function grantOwnership(player)
	if not PlayerAccessoryData[player.UserId] then
		PlayerAccessoryData[player.UserId] = {
			owned = true,
			equipped = false
		}
	else
		PlayerAccessoryData[player.UserId].owned = true
	end

	debugPrint(player.Name .. " granted accessory ownership", true)
end

local function hasRequiredRole(player)
	local role = RoleSystem:GetPlayerRole(player)

	if Config.IncludeHigherRoles then
		local roleLevel = RoleSystem.Config.RoleHierarchy[role] or 0
		local requiredLevel = RoleSystem.Config.RoleHierarchy[Config.RequiredRole] or 0
		return roleLevel >= requiredLevel, role
	else
		return role == Config.RequiredRole, role
	end
end

local function ownsAccessory(player)
	return PlayerAccessoryData[player.UserId] and PlayerAccessoryData[player.UserId].owned or false
end

local function isAccessoryEquipped(player)
	return PlayerAccessoryData[player.UserId] and PlayerAccessoryData[player.UserId].equipped or false
end

-- ====================================
-- GUI CREATION
-- ====================================
local function showIconForPlayer(player, shouldShow)
	ShowIconEvent:FireClient(player, shouldShow)
	debugPrint(player.Name .. " icon visibility: " .. tostring(shouldShow), true)
end

-- ====================================
-- CHARACTER HANDLERS
-- ====================================
local function onCharacterAdded(character, player)
	if Config.RoleCheckDelay > 0 then
		task.wait(Config.RoleCheckDelay)
	end

	local hasRole, currentRole = hasRequiredRole(player)

	if hasRole then
		grantOwnership(player)
		debugPrint(player.Name .. " (" .. currentRole .. ") qualified for accessory", true)
	else
		debugPrint(player.Name .. " (" .. currentRole .. ") does not meet role requirement", false)
	end
end

local function onPlayerAdded(player)
	-- Wait for player to load
	task.wait(1)

	local hasRole, _ = hasRequiredRole(player)
	if hasRole then
		showIconForPlayer(player, true)
	end

	-- Handle existing character
	if player.Character then
		onCharacterAdded(player.Character, player)
	end

	-- Handle new character
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(character, player)
	end)
end

-- ====================================
-- REMOTE EVENT HANDLERS
-- ====================================
AccessoryEvent.OnServerEvent:Connect(function(player, action)
	if not ownsAccessory(player) then
		debugPrint(player.Name .. " attempted to toggle without ownership", false)
		return
	end

	if not player.Character then
		debugPrint(player.Name .. " has no character", false)
		return
	end

	if action == "equip" then
		equipAccessory(player.Character, player)
	elseif action == "unequip" then
		unequipAccessory(player.Character, player)
	else
		debugPrint(player.Name .. " sent invalid action: " .. tostring(action), false)
	end
end)

-- ====================================
-- INITIALIZATION
-- ====================================
if not Config.AccessoryPath then
	debugPrint("Accessory path not found in ServerStorage.Items!", false)
	return
end

debugPrint("VVIP Accessory System Initializing...", true)
debugPrint("Required Role: " .. Config.RequiredRole .. " | Include Higher: " .. tostring(Config.IncludeHigherRoles), true)

-- Handle existing players
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

-- Handle new players
Players.PlayerAdded:Connect(onPlayerAdded)

-- Handle role changes
RoleSystem.RoleChanged:Connect(function(player, oldRole, newRole)
	local hasRole, _ = hasRequiredRole(player)

	if hasRole then
		grantOwnership(player)
		showIconForPlayer(player, true)

		debugPrint(player.Name .. " role upgraded: " .. oldRole .. " → " .. newRole .. " | Access granted", true)
	else
		-- Hide icon
		showIconForPlayer(player, false)

		-- Remove accessory if equipped
		if player.Character then
			unequipAccessory(player.Character, player)
		end

		-- Revoke ownership
		if PlayerAccessoryData[player.UserId] then
			PlayerAccessoryData[player.UserId].owned = false
		end

		debugPrint(player.Name .. " role changed: " .. oldRole .. " → " .. newRole .. " | Access revoked", false)
	end
end)

debugPrint("VVIP Accessory System with Equip/Unequip Loaded Successfully", true)