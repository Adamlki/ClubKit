local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local ServerStorage = game:GetService("ServerStorage")

-- ====================================
-- MODULES
-- ====================================
local Config = require(script.TitleConfig)
local DebugSystem = require(script.TitleDebugSystem)
local TitleDataManager = require(script.TitleManager)
local RemoteManager = require(script.TitleRemoteManager)
local PermissionManager = require(script.TitlePermissionManager)

-- ====================================
-- INITIALIZATION
-- ====================================
DebugSystem:Init(Config.DEBUG_ENABLED)
TitleDataManager:Init(Config)
RemoteManager:Init(Config)

local RoleSystem = require(ServerStorage:WaitForChild("Modules"):WaitForChild("RoleSystem"))

-- ====================================
-- SETUP PERMISSION MANAGER
-- ====================================
PermissionManager:Init(RoleSystem)

-- ====================================
-- REMOTE EVENT HANDLERS
-- ====================================
RemoteManager.CheckAccessRemote.OnServerInvoke = function(sender)
	if not sender then return false end
	return PermissionManager:HasAccess(sender.UserId)
end

RemoteManager.UpdateTitleRemote.OnServerEvent:Connect(function(sender, targetPlayer, titleData)
	DebugSystem:Log("UpdateTitle Request")
	DebugSystem:Log("Sender:", sender and sender.Name or "nil")
	DebugSystem:Log("Target:", targetPlayer and targetPlayer.Name or "nil")

	if not sender or not targetPlayer or not titleData then 
		DebugSystem:Warn("Invalid parameters")
		return 
	end

	if not targetPlayer.Parent then
		DebugSystem:Warn("Target player not in game")
		return
	end

	if not PermissionManager:HasAccess(sender.UserId) then
		DebugSystem:Warn("Access denied! Player role:", RoleSystem:GetPlayerRole(sender))
		return
	end

	DebugSystem:Log("Permission granted!")

	if type(titleData) ~= "table" then 
		DebugSystem:Warn("Invalid titleData type")
		return 
	end

	local validatedData = TitleDataManager:ValidateTitleData(titleData)

	DebugSystem:Log("Validated:")
	DebugSystem:Log("  - Title:", validatedData.Title)
	DebugSystem:Log("  - Gradient:", validatedData.GradientEnabled)
	DebugSystem:Log("  - Effect:", validatedData.GradientEffect)

	-- FUNGSI BARU: Jika title kosong, hapus title
	if validatedData.Title == "" then 
		DebugSystem:Log("Empty title detected - Removing title for", targetPlayer.Name)

		-- Simpan data kosong untuk menghapus title
		local emptyData = {
			Title = "",
			Color = Color3.fromRGB(255, 255, 255),
			GradientEnabled = false,
			GradientEffect = "wave"
		}

		local saveSuccess = TitleDataManager:SaveTitleData(targetPlayer.UserId, emptyData)

		if saveSuccess then
			DebugSystem:Log("Title removed successfully! Overhead will auto-update")
		else
			DebugSystem:Warn("Failed to remove title")
		end
		return 
	end

	local saveSuccess = TitleDataManager:SaveTitleData(targetPlayer.UserId, validatedData)

	if saveSuccess then
		DebugSystem:Log("Save successful! Overhead will auto-update")
	else
		DebugSystem:Warn("Save failed")
	end
end)

RemoteManager.GetPlayerTitleRemote.OnServerInvoke = function(sender, targetPlayer)
	if not targetPlayer then return nil end
	return TitleDataManager:LoadTitleData(targetPlayer.UserId)
end

-- ====================================
-- PLAYER MANAGEMENT
-- ====================================
Players.PlayerRemoving:Connect(function(player)
	TitleDataManager:ClearCache(player.UserId)
	DebugSystem:Log("Cleaned cache for", player.Name)
end)