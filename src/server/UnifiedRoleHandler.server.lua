local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local ServerScriptService = game:GetService("ServerScriptService")

local RemoteEventManager = require(ServerScriptService:WaitForChild("Modules"):WaitForChild("RemoteEventManager"))

-- Load Systems
local RoleSystem = require(ServerStorage:WaitForChild("Modules"):WaitForChild("RoleSystem"))

-- ====================================
-- CONFIG
-- ====================================
local CONFIG = {
	Debug = {
		ENABLE_DEBUG       = false,
		SHOW_SERVER_LOGS   = false,
		SHOW_DISPATCH_LOGS = false,
	},
	DataStores = {
		TRANSACTION_HISTORY = "GiveRoleTransactions_v1",
	},
	Settings = {
		ENABLE_NOTIFICATIONS = true,
		MAX_RETRY_ATTEMPTS   = 3,
		RETRY_DELAY          = 1,
		-- Role yang TIDAK bisa di-give via panel (hardcoded protection)
		PROTECTED_ROLES = {
			Owner = true,
		},
	},
}

-- ====================================
-- DEBUG HELPER
-- ====================================
local function debugPrint(...)
	if CONFIG.Debug.ENABLE_DEBUG and CONFIG.Debug.SHOW_SERVER_LOGS then
		print("[UnifiedRole]", ...)
	end
end

local function debugDispatch(...)
	if CONFIG.Debug.ENABLE_DEBUG and CONFIG.Debug.SHOW_DISPATCH_LOGS then
		print("[UnifiedRole]", ...)
	end
end

-- ====================================
-- DATASTORES
-- ====================================
local transactionStore = DataStoreService:GetDataStore(CONFIG.DataStores.TRANSACTION_HISTORY)

-- ====================================
-- REMOTE SETUP
-- ====================================
local giveRoleRemote = ReplicatedStorage:FindFirstChild("GiveRoleRemote")
if not giveRoleRemote then
	giveRoleRemote        = Instance.new("RemoteEvent")
	giveRoleRemote.Name   = "GiveRoleRemote"
	giveRoleRemote.Parent = ReplicatedStorage
	debugPrint("Created GiveRoleRemote")
else
	debugPrint("Using existing GiveRoleRemote")
end

-- ====================================
-- CONSTANTS
-- ====================================
local ADMIN_ROLES = { Owner = true, Admin = true, Moderator = true }

-- Valid role types yang bisa di-give lewat panel
-- "Player" berarti REMOVE role (kembalikan ke Player default)
local VALID_ROLE_TYPES = {
	VIP       = true,
	VVIP      = true,
	Moderator = true,
	Admin     = true,
	Player    = true,  -- Give "Player" = hapus givenPass, kembali ke default
}

-- ====================================
-- HELPER FUNCTIONS
-- ====================================
local function isAdmin(player)
	return ADMIN_ROLES[RoleSystem:GetPlayerRole(player)] == true
end

-- ====================================
-- CEK PERMISSION UNTUK GIVE ROLE
-- ====================================
-- Hierarki give permission:
--   Owner     → bisa give VIP, VVIP, Moderator, Admin, Player (semua)
--   Admin     → bisa give VIP, VVIP, Moderator, Player
--   Moderator → bisa give VIP, Player
-- "Player" = remove givenPass dari target (downgrade ke Player default)
-- Owner TIDAK bisa di-give role apapun (protected)
local function canGiveRole(player, roleType)
	local playerRole = RoleSystem:GetPlayerRole(player)

	-- Owner bisa give semua (VIP, VVIP, Moderator, Admin, Player)
	if playerRole == "Owner" then
		return true, nil
	end

	-- Admin bisa give VIP, VVIP, Moderator, Player — tapi TIDAK Admin
	if playerRole == "Admin" then
		if roleType == "VIP" or roleType == "VVIP" or roleType == "Moderator" or roleType == "Player" then
			return true, nil
		else
			return false, "Admin hanya dapat memberikan VIP, VVIP, Moderator, atau Player role"
		end
	end

	-- Moderator hanya bisa give VIP atau Player
	if playerRole == "Moderator" then
		if roleType == "VIP" or roleType == "Player" then
			return true, nil
		else
			return false, "Moderator hanya dapat memberikan VIP atau Player role"
		end
	end

	return false, "Kamu bukan admin!"
end

-- ====================================
-- DATASTORE RETRY HELPER
-- ====================================
local function datastoreRetry(operation, maxAttempts)
	maxAttempts = maxAttempts or CONFIG.Settings.MAX_RETRY_ATTEMPTS
	for attempt = 1, maxAttempts do
		local success, result = pcall(operation)
		if success then return true, result end
		if attempt < maxAttempts then task.wait(CONFIG.Settings.RETRY_DELAY) end
	end
	return false, nil
end

local function saveTransaction(giverUserId, targetUserId, roleType, receiptInfo)
	-- 🔥 FIX DATASTORE COLLISION & KEY LIMIT: Gunakan GUID saja (maksimal 50 karakter)
	local key = string.format("txn_%s", HttpService:GenerateGUID(false))
	return datastoreRetry(function()
		transactionStore:SetAsync(key, {
			giver       = giverUserId,
			target      = targetUserId,
			roleType    = roleType,
			timestamp   = os.time(),
			receiptInfo = receiptInfo,
		})
	end)
end

-- ====================================
-- REMOTE EVENT HANDLER
-- ====================================
giveRoleRemote.OnServerEvent:Connect(function(player, requestData)
	-- 🔥 ARCHITECT FIX: Rate Limiter Sentral
	if not RemoteEventManager.checkRateLimit(player, "adminRoleAction") then return end

	if type(requestData) ~= "table" then
		warn("[UnifiedRole] Invalid request from", player.Name)
		return
	end

	local source = requestData.source
	local action = requestData.action

	debugDispatch(string.format("Request | Player: %s | Source: %s | Action: %s",
		player.Name, source or "nil", action or "nil"))

	-- ====================================
	-- ADMIN PANEL - GIVE ROLE
	-- ====================================
	if source == "AdminPanel" then
		if action == "GiveRole" then
			debugPrint("AdminPanel: GiveRole")

			-- Verifikasi admin
			if not isAdmin(player) then
				giveRoleRemote:FireClient(player, {
					source  = "AdminPanel",
					success = false,
					message = "Kamu bukan admin!",
				})
				return
			end

			-- 🔥 FATAL SECURITY FIX: Cegah Type Mismatch Crash
			local targetUserId = tonumber(requestData.targetUserId)
			if not targetUserId then
				giveRoleRemote:FireClient(player, {
					source  = "AdminPanel",
					success = false,
					message = "Target User ID harus berupa angka valid!",
				})
				return
			end

			local roleType     = requestData.roleType
			local targetPlayer = Players:GetPlayerByUserId(targetUserId)

			if not targetPlayer then
				giveRoleRemote:FireClient(player, {
					source  = "AdminPanel",
					success = false,
					message = "Player tidak ditemukan!",
				})
				return
			end

			-- Validate role type
			if not VALID_ROLE_TYPES[roleType] then
				giveRoleRemote:FireClient(player, {
					source  = "AdminPanel",
					success = false,
					message = "Role tidak valid!",
				})
				return
			end

			-- Cegah give role ke Owner (hardcoded protected)
			local targetCurrentRole = RoleSystem:GetPlayerRole(targetPlayer)
			if CONFIG.Settings.PROTECTED_ROLES[targetCurrentRole] then
				giveRoleRemote:FireClient(player, {
					source  = "AdminPanel",
					success = false,
					message = "Tidak bisa mengubah role Owner!",
				})
				return
			end

			-- Cek permission giver
			local canGive, errorMessage = canGiveRole(player, roleType)
			if not canGive then
				giveRoleRemote:FireClient(player, {
					source  = "AdminPanel",
					success = false,
					message = errorMessage,
				})
				return
			end

			local success, result

			-- "Player" = hapus givenPass → kembalikan ke Player default
			if roleType == "Player" then
				success, result = RoleSystem:RemovePassFromPlayer(targetUserId)
			else
				-- Give VIP / VVIP / Moderator / Admin
				success, result = RoleSystem:GivePassToPlayer(targetUserId, roleType, player.UserId)
			end

			if success then
				local targetDisplayName = targetPlayer.DisplayName or targetPlayer.Name or "Unknown"
				local newRole = RoleSystem:GetPlayerRole(targetPlayer)

				local successMessage
				if roleType == "Player" then
					successMessage = string.format("Role %s dihapus, %s kembali ke Player", targetDisplayName, targetDisplayName)
				else
					successMessage = string.format("%s role diberikan ke %s", roleType, targetDisplayName)
				end

				-- Production log (always printed)
				debugPrint(string.format("[ROLE GIVEN] %s (@%s) gave %s to %s (@%s) | UserID: %d | New role: %s",
					player.Name, player.DisplayName,
					roleType,
					targetPlayer.Name, targetPlayer.DisplayName,
					targetUserId, newRole))

				debugPrint(string.format("%s gave %s to %s (now: %s)", player.Name, roleType, targetPlayer.Name, newRole))

				-- Save transaction
				saveTransaction(player.UserId, targetUserId, roleType, {
					adminGive = true,
					timestamp = os.time(),
				})

				giveRoleRemote:FireClient(player, {
					source  = "AdminPanel",
					success = true,
					message = successMessage,
				})
			else
				warn(string.format("[UnifiedRole] Give role failed: %s", result or "Unknown"))
				giveRoleRemote:FireClient(player, {
					source  = "AdminPanel",
					success = false,
					message = "Gagal memberikan role: " .. (result or "Unknown error"),
				})
			end

		-- ====================================
		-- REMOVE ROLE (OWNER ONLY)
		-- ====================================
		elseif action == "RemoveRole" then
			debugPrint("AdminPanel: RemoveRole (Owner only)")

			-- Hanya Owner yang bisa remove role via action ini
			if RoleSystem:GetPlayerRole(player) ~= "Owner" then
				giveRoleRemote:FireClient(player, {
					source  = "AdminPanel",
					success = false,
					message = "Hanya Owner yang dapat menurunkan role",
				})
				return
			end

			-- 🔥 FATAL SECURITY FIX: Cegah Type Mismatch Crash di RemoveRole
			local targetUserId = tonumber(requestData.targetUserId)
			if not targetUserId then
				giveRoleRemote:FireClient(player, {
					source  = "AdminPanel",
					success = false,
					message = "Target User ID harus berupa angka valid!",
				})
				return
			end
			local targetPlayer = Players:GetPlayerByUserId(targetUserId)

			if not targetPlayer then
				giveRoleRemote:FireClient(player, {
					source  = "AdminPanel",
					success = false,
					message = "Player tidak ditemukan!",
				})
				return
			end

			local success, result = RoleSystem:RemovePassFromPlayer(targetUserId)
			if success then
				local targetDisplayName = targetPlayer.DisplayName or targetPlayer.Name or "Unknown"
				local newRole = RoleSystem:GetPlayerRole(targetPlayer)
				local successMessage = string.format("Role %s dihapus (sekarang: %s)", targetDisplayName, newRole)

				-- Production log
				debugPrint(string.format("[ROLE REMOVED] %s (@%s) removed role from %s (@%s) | New role: %s | UserID: %d",
					player.Name, player.DisplayName,
					targetPlayer.Name, targetPlayer.DisplayName,
					newRole, targetUserId))

				debugPrint(string.format("Owner %s removed role from %s (now: %s)",
					player.Name, targetPlayer.Name, newRole))

				giveRoleRemote:FireClient(player, {
					source  = "AdminPanel",
					success = true,
					message = successMessage,
				})
			else
				giveRoleRemote:FireClient(player, {
					source  = "AdminPanel",
					success = false,
					message = result or "Gagal menghapus role (mungkin tidak ada role yang di-assign)",
				})
			end

		else
			warn("[UnifiedRole] Unknown AdminPanel action:", action)
		end

	else
		warn("[UnifiedRole] Unknown source:", source, "from", player.Name)
	end
end)

-- ====================================
-- INITIALIZATION
-- ====================================
debugPrint("============================================================")
debugPrint("Unified Role Handler Initialized")
debugPrint("Config: Embedded (GiveRoleConfig module removed)")
debugPrint("DataStore: PlayerGiveGamePasses_v1 (VIP/VVIP/Moderator/Admin)")
debugPrint("DataStore: GiveRoleTransactions_v1 (Transaction history)")
debugPrint("Admin Panel: Direct give (NO payment required)")
debugPrint("Permissions:")
debugPrint("  - Owner     : Give VIP, VVIP, Moderator, Admin, Player + RemoveRole")
debugPrint("  - Admin     : Give VIP, VVIP, Moderator, Player")
debugPrint("  - Moderator : Give VIP, Player")
debugPrint("  - 'Player' roleType = RemovePass (downgrade ke Player default)")
debugPrint("============================================================")