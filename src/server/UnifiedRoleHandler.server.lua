local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local DataStoreEnv = require(ServerStorage:WaitForChild("Modules"):WaitForChild("DataStoreEnv"))
local HttpService = game:GetService("HttpService")
local ServerScriptService = game:GetService("ServerScriptService")

local RemoteEventManager = require(ServerScriptService:WaitForChild("Modules"):WaitForChild("RemoteEventManager"))

local RoleSystem = require(ServerStorage:WaitForChild("Modules"):WaitForChild("RoleSystem"))

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
		PROTECTED_ROLES = {
			Owner = true,
		},
	},
}

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

local _, transactionWriteStore = DataStoreEnv.Get(CONFIG.DataStores.TRANSACTION_HISTORY)

local giveRoleRemote = ReplicatedStorage:FindFirstChild("GiveRoleRemote")
if not giveRoleRemote then
	giveRoleRemote        = Instance.new("RemoteEvent")
	giveRoleRemote.Name   = "GiveRoleRemote"
	giveRoleRemote.Parent = ReplicatedStorage
	debugPrint("Created GiveRoleRemote")
else
	debugPrint("Using existing GiveRoleRemote")
end

local ADMIN_ROLES = { Owner = true, Admin = true, Moderator = true }

local VALID_ROLE_TYPES = {
	VIP       = true,
	Moderator = true,
	Admin     = true,
	Player    = true,
}

local function isAdmin(player)
	return ADMIN_ROLES[RoleSystem:GetPlayerRole(player)] == true
end

local function canGiveRole(player, roleType)
	local playerRole = RoleSystem:GetPlayerRole(player)

	if playerRole == "Owner" then
		return true, nil
	end

	if playerRole == "Admin" then
		if roleType == "VIP" or roleType == "Moderator" or roleType == "Player" then
			return true, nil
		else
			return false, "Admin hanya dapat memberikan VIP, Moderator, atau Player role"
		end
	end

	if playerRole == "Moderator" then
		if roleType == "VIP" or roleType == "Player" then
			return true, nil
		else
			return false, "Moderator hanya dapat memberikan VIP atau Player role"
		end
	end

	return false, "Kamu bukan admin!"
end

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
	local cleanGuid = string.gsub(HttpService:GenerateGUID(false), "-", "")
	local uniqueId = string.sub(cleanGuid, 1, 16)
	local key = string.format("txn_%d_%s", os.time(), uniqueId)
	return datastoreRetry(function()
		transactionWriteStore:SetAsync(key, {
			giver       = giverUserId,
			target      = targetUserId,
			roleType    = roleType,
			timestamp   = os.time(),
			receiptInfo = receiptInfo,
		})
	end)
end

giveRoleRemote.OnServerEvent:Connect(function(player, requestData)
	if not RemoteEventManager.checkRateLimit(player, "adminRoleAction") then return end

	if type(requestData) ~= "table" then
		warn("[UnifiedRole] Invalid request from", player.Name)
		return
	end

	local source = requestData.source
	local action = requestData.action

	debugDispatch(string.format("Request | Player: %s | Source: %s | Action: %s",
		player.Name, source or "nil", action or "nil"))

	if source == "AdminPanel" then
		if action == "GiveRole" then
			debugPrint("AdminPanel: GiveRole")

			if not isAdmin(player) then
				giveRoleRemote:FireClient(player, {
					source  = "AdminPanel",
					success = false,
					message = "Kamu bukan admin!",
				})
				return
			end

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

			if not VALID_ROLE_TYPES[roleType] then
				giveRoleRemote:FireClient(player, {
					source  = "AdminPanel",
					success = false,
					message = "Role tidak valid!",
				})
				return
			end

			local targetCurrentRole = RoleSystem:GetPlayerRole(targetPlayer)
			if CONFIG.Settings.PROTECTED_ROLES[targetCurrentRole] then
				giveRoleRemote:FireClient(player, {
					source  = "AdminPanel",
					success = false,
					message = "Tidak bisa mengubah role Owner!",
				})
				return
			end

			local playerRoleName = RoleSystem:GetPlayerRole(player)
			local giverPriority = RoleSystem.Config.RoleHierarchy[playerRoleName] or 0
			local targetPriority = RoleSystem.Config.RoleHierarchy[targetCurrentRole] or 0
			
			if playerRoleName ~= "Owner" and targetPriority >= giverPriority then
				giveRoleRemote:FireClient(player, {
					source  = "AdminPanel",
					success = false,
					message = "Kamu tidak bisa mengubah role pemain yang jabatannya setara atau lebih tinggi darimu!",
				})
				return
			end

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

			if roleType == "Player" then
				success, result = RoleSystem:RemovePassFromPlayer(targetUserId)
			else
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

				debugPrint(string.format("[ROLE GIVEN] %s (@%s) gave %s to %s (@%s) | UserID: %d | New role: %s",
					player.Name, player.DisplayName,
					roleType,
					targetPlayer.Name, targetPlayer.DisplayName,
					targetUserId, newRole))

				debugPrint(string.format("%s gave %s to %s (now: %s)", player.Name, roleType, targetPlayer.Name, newRole))

				saveTransaction(player.UserId, targetUserId, roleType, {
					adminGive = true,
					timestamp = os.time(),
				})

				giveRoleRemote:FireClient(player, {
					source  = "AdminPanel",
					success = true,
					message = successMessage,
				})

				pcall(function()
					if targetPlayer and targetPlayer ~= player then
						giveRoleRemote:FireClient(targetPlayer, {
							source  = "AdminPanel",
							success = true,
							message = (roleType == "Player") and "Role kamu telah direset ke Player." or string.format("Selamat! Kamu telah diberikan role %s!", roleType),
						})
					end
				end)
			else
				warn(string.format("[UnifiedRole] Give role failed: %s", result or "Unknown"))
				giveRoleRemote:FireClient(player, {
					source  = "AdminPanel",
					success = false,
					message = "Gagal memberikan role: " .. (result or "Unknown error"),
				})
			end

		elseif action == "RemoveRole" then
			debugPrint("AdminPanel: RemoveRole (Owner only)")

			if RoleSystem:GetPlayerRole(player) ~= "Owner" then
				giveRoleRemote:FireClient(player, {
					source  = "AdminPanel",
					success = false,
					message = "Hanya Owner yang dapat menurunkan role",
				})
				return
			end

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

debugPrint("============================================================")
debugPrint("Unified Role Handler Initialized")
debugPrint("Config: Embedded (GiveRoleConfig module removed)")
debugPrint("DataStore: PlayerGiveGamePasses_v1 (VIP/Moderator/Admin)")
debugPrint("DataStore: GiveRoleTransactions_v1 (Transaction history)")
debugPrint("Admin Panel: Direct give (NO payment required)")
debugPrint("Permissions:")
debugPrint("  - Owner     : Give VIP, Moderator, Admin, Player + RemoveRole")
debugPrint("  - Admin     : Give VIP, Moderator, Player")
debugPrint("  - Moderator : Give VIP, Player")
debugPrint("  - 'Player' roleType = RemovePass (downgrade ke Player default)")
debugPrint("============================================================")
