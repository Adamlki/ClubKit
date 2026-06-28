local RoleSystem = {}

local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")

-- 🔥 ARCHITECT FIX: Master Debug Toggle
local DEBUG_MODE = false -- Biarkan false agar F9 Console bersih saat game live!

-- ====================================
-- CONFIGURATION
-- ====================================
RoleSystem.Config = {
	GamePasses = {
		VVIP = {1799395597},
		VIP = {1800222458}
	},
	-- Developer Product (Fitur Gift/Beliin orang lain)
	-- Masukkan ID Developer Product yang kamu buat di Creator Dashboard
	GiftProducts = {
		VIP = 3578052945,    -- Ganti ID Dev Product Gift VIP
		VVIP = 3578052943    -- Ganti ID Dev Product Gift VVIP
	},
	
	ActiveGamepasses = {
		VVIP = 1799395597,
		VIP = 1800222458
	},

	OwnerIds = {8978185974}, --7979929622 Noe
	AdminIds = {},
	ModeratorIds = {},

	RoleHierarchy = {
		Owner = 6,
		Admin = 5,
		Moderator = 4,
		VVIP = 3,
		VIP = 2,
		Player = 1
	},

	DATASTORE_NAME = "PlayerGiveGamePasses_v1",
	DATASTORE_RETRY_ATTEMPTS = 3,
	DATASTORE_RETRY_DELAY = 1,
	GAMEPASS_CHECK_TIMEOUT = 15,
	GAMEPASS_CHECK_RETRIES = 2
}

-- ====================================
-- SERVICES
-- ====================================
local giveGamePassStore = DataStoreService:GetDataStore(RoleSystem.Config.DATASTORE_NAME)

-- ====================================
-- OWNERSHIP CACHE
-- ====================================
local playerOwnershipCache = {}

-- ====================================
-- EVENTS
-- ====================================
local roleChangedEvent = Instance.new("BindableEvent")
roleChangedEvent.Name = "RoleChanged"
RoleSystem.RoleChanged = roleChangedEvent.Event

-- ====================================
-- UTILITY
-- ====================================
local function isInList(userId, list)
	for _, id in ipairs(list) do
		if id == userId then
			return true
		end
	end
	return false
end

-- ====================================
-- DATASTORE OPERATIONS (WITH RETRY)
-- ====================================
local function datastoreGetAsync(key)
	for attempt = 1, RoleSystem.Config.DATASTORE_RETRY_ATTEMPTS do
		local success, result = pcall(function()
			return giveGamePassStore:GetAsync(key)
		end)

		if success then
			return result
		end

		if attempt < RoleSystem.Config.DATASTORE_RETRY_ATTEMPTS then
			task.wait(RoleSystem.Config.DATASTORE_RETRY_DELAY)
		end
	end

	return nil
end

local function datastoreSetAsync(key, value)
	for attempt = 1, RoleSystem.Config.DATASTORE_RETRY_ATTEMPTS do
		local success = pcall(function()
			giveGamePassStore:SetAsync(key, value)
		end)

		if success then
			return true
		end

		if attempt < RoleSystem.Config.DATASTORE_RETRY_ATTEMPTS then
			task.wait(RoleSystem.Config.DATASTORE_RETRY_DELAY)
		end
	end

	return false
end

local function datastoreRemoveAsync(key)
	for attempt = 1, RoleSystem.Config.DATASTORE_RETRY_ATTEMPTS do
		local success = pcall(function()
			giveGamePassStore:RemoveAsync(key)
		end)

		if success then
			return true
		end

		if attempt < RoleSystem.Config.DATASTORE_RETRY_ATTEMPTS then
			task.wait(RoleSystem.Config.DATASTORE_RETRY_DELAY)
		end
	end

	return false
end

-- ====================================
-- GAMEPASS CHECK (WITH RETRY & TIMEOUT)
-- ====================================
local function checkSingleGamepass(player, gamepassId, retryCount)
	retryCount = retryCount or 0

	if gamepassId == 0 or gamepassId == nil then
		return false
	end

	-- 🔥 ARCHITECT FIX: Amankan UserId SEBELUM task.spawn/yield
	local safeUserId = player.UserId

	local result = false
	local completed = false
	local checkError = nil

	task.spawn(function()
		local success, hasPass = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(safeUserId, gamepassId)
		end)

		if success then
			result = hasPass
		else
			checkError = hasPass
		end
		completed = true
	end)

	local startTime = os.clock()
	while not completed and (os.clock() - startTime) < RoleSystem.Config.GAMEPASS_CHECK_TIMEOUT do
		task.wait(0.1)
	end

	if not completed then
		if retryCount < RoleSystem.Config.GAMEPASS_CHECK_RETRIES then
			task.wait(1)
			return checkSingleGamepass(player, gamepassId, retryCount + 1)
		end
		return false
	end

	if checkError then
		if retryCount < RoleSystem.Config.GAMEPASS_CHECK_RETRIES then
			task.wait(1)
			return checkSingleGamepass(player, gamepassId, retryCount + 1)
		end
	end

	return result
end

local function checkAnyGamepass(player, gamepassIds)
	if type(gamepassIds) == "number" then
		return checkSingleGamepass(player, gamepassIds)
	end

	if type(gamepassIds) == "table" then
		for _, gamepassId in ipairs(gamepassIds) do
			if checkSingleGamepass(player, gamepassId) then
				return true
			end
		end
	end

	return false
end

-- ====================================
-- OWNERSHIP CACHE SYSTEM
-- ====================================
local gamepassQueue = {}
local isCheckingQueue = false

local function processGamepassQueue()
	if isCheckingQueue then return end
	isCheckingQueue = true
	task.spawn(function()
		while #gamepassQueue > 0 do
			local nextCheck = table.remove(gamepassQueue, 1)
			if nextCheck and nextCheck.player and nextCheck.player.Parent then
				nextCheck.callback()
			end
			-- ✨ Anti-Throttling API Global Jitter
			task.wait(1.5)
		end
		isCheckingQueue = false
	end)
end

-- CachePlayerOwnership:
--   SYNC  → hanya baca DataStore givenpass (cepat, ~100-300ms)
--   ASYNC → gamepass check dijalankan di background, update cache & role setelah selesai
--   Ini mencegah blocking di PlayerAdded/assignPlayer yang menyebabkan loading lama
function RoleSystem:CachePlayerOwnership(player)
	local userId = player.UserId

	local ownership = {
		VVIP = false,
		VIP = false,
		GivenPass = "None",
		CheckedAt = os.clock()
	}

	-- 1. Check Given Pass dari DataStore (sync - cepat)
	local key = "givenpass_" .. tostring(userId)
	local givenPassData = datastoreGetAsync(key)

	if givenPassData and givenPassData.passType then
		ownership.GivenPass = givenPassData.passType

		if givenPassData.passType == "VVIP" then
			ownership.VVIP = true
		elseif givenPassData.passType == "VIP" then
			ownership.VIP = true
		elseif givenPassData.passType == "Moderator" then
			ownership.GivenPass = "Moderator"
		elseif givenPassData.passType == "Admin" then
			ownership.GivenPass = "Admin"
		end
	end

	-- Simpan hasil DataStore dulu agar role bisa langsung dipakai
	playerOwnershipCache[userId] = ownership

	-- 2. GamePass check ASYNC di background (tidak blocking PlayerAdded)
	-- Hanya untuk player yang belum punya GivenPass dari DataStore
	if ownership.GivenPass == "None" then
		table.insert(gamepassQueue, {
			player = player,
			callback = function()
				local hasVVIP = checkAnyGamepass(player, self.Config.GamePasses.VVIP)

				if hasVVIP then
					ownership.VVIP = true
					ownership.GivenPass = "VVIP"
					playerOwnershipCache[userId] = ownership

					if DEBUG_MODE then -- 🔥 DEBUG WRAPPER
						print(string.format("[RoleSystem] Auto-saving VVIP purchase for user %d", userId))
					end

					-- Jangan spam DataStore untuk owner asli!
					-- self:GivePassToPlayer(userId, "VVIP", 0)
					if player and player.Parent then
						self:UpdatePlayerRole(player)
					end
					return
				end

				local hasVIP = checkAnyGamepass(player, self.Config.GamePasses.VIP)
				if hasVIP then
					ownership.VIP = true
					ownership.GivenPass = "VIP"
					playerOwnershipCache[userId] = ownership

					if DEBUG_MODE then -- 🔥 DEBUG WRAPPER
						print(string.format("[RoleSystem] Auto-saving VIP purchase for user %d", userId))
					end

					-- Jangan spam DataStore untuk owner asli!
					-- self:GivePassToPlayer(userId, "VIP", 0)
					if player and player.Parent then
						self:UpdatePlayerRole(player)
					end
				end
			end
		})
		processGamepassQueue()
	end

	return ownership
end

function RoleSystem:GetPlayerOwnership(player)
	local userId = player.UserId

	if playerOwnershipCache[userId] then
		return playerOwnershipCache[userId]
	end

	return self:CachePlayerOwnership(player)
end

function RoleSystem:UpdateOwnershipCache(player, gamepassType, owned)
	local userId = player.UserId

	if not playerOwnershipCache[userId] then
		playerOwnershipCache[userId] = {
			VVIP = false,
			VIP = false,
			GivenPass = "None",
			CheckedAt = os.clock()
		}
	end

	playerOwnershipCache[userId][gamepassType] = owned
	playerOwnershipCache[userId].CheckedAt = os.clock()
end

function RoleSystem:InvalidateOwnershipCache(userId)
	playerOwnershipCache[userId] = nil
end

-- ====================================
-- ROLE CALCULATION
-- ====================================
function RoleSystem:GetPlayerRole(player)
	local userId = player.UserId

	-- Priority 1: Hardcoded Owner (tidak bisa diturunkan)
	if isInList(userId, self.Config.OwnerIds) then
		return "Owner"
	end

	-- Priority 2: Hardcoded Admin
	if isInList(userId, self.Config.AdminIds) then
		return "Admin"
	end

	-- Priority 3: Hardcoded Moderator (backward compatibility)
	if isInList(userId, self.Config.ModeratorIds) then
		return "Moderator"
	end

	-- Priority 4: Cek DataStore (Admin/Moderator/VVIP/VIP yang di-give via panel)
	local ownership = self:GetPlayerOwnership(player)

	-- FIX: Admin dari DataStore sekarang terbaca dengan benar
	if ownership.GivenPass == "Admin" then
		return "Admin"
	end

	if ownership.GivenPass == "Moderator" then
		return "Moderator"
	end

	if ownership.GivenPass == "VVIP" or ownership.VVIP then
		return "VVIP"
	end

	if ownership.GivenPass == "VIP" or ownership.VIP then
		return "VIP"
	end

	return "Player"
end

-- ====================================
-- PLAYER INITIALIZATION
-- ====================================
function RoleSystem:InitializePlayer(player)
	self:CachePlayerOwnership(player)

	local role = self:GetPlayerRole(player)

	local roleValue = player:FindFirstChild("Role")
	if not roleValue then
		roleValue = Instance.new("StringValue")
		roleValue.Name = "Role"
		roleValue.Parent = player
	end

	local oldRole = roleValue.Value
	roleValue.Value = role

	if oldRole ~= role and oldRole ~= "" then
		roleChangedEvent:Fire(player, oldRole, role)
	end

	return role
end

function RoleSystem:UpdatePlayerRole(player)
	self:InvalidateOwnershipCache(player.UserId)
	return self:InitializePlayer(player)
end

-- ====================================
-- GIVE PASS MANAGEMENT (EXTENDED: VIP, VVIP, Moderator, Admin)
-- ====================================
function RoleSystem:GivePassToPlayer(targetUserId, passType, giverUserId)
	-- FIX: "Admin" sekarang valid sebagai passType
	if passType ~= "VIP" and passType ~= "VVIP" and passType ~= "Moderator" and passType ~= "Admin" then
		warn(string.format("[RoleSystem] GivePassToPlayer: invalid passType '%s'", tostring(passType)))
		return false, "Invalid pass type"
	end

	-- Key format TIDAK DIUBAH agar data production tetap kompatibel
	local key = "givenpass_" .. tostring(targetUserId)
	local data = {
		passType  = passType,
		givenBy   = giverUserId,
		givenAt   = os.time(),
		timestamp = os.time()
	}

	local success = datastoreSetAsync(key, data)

	if success then
		self:InvalidateOwnershipCache(targetUserId)

		local player = game.Players:GetPlayerByUserId(targetUserId)
		if player then
			self:UpdatePlayerRole(player)
		end

		if DEBUG_MODE then -- 🔥 DEBUG WRAPPER
			print(string.format("[RoleSystem] GivePassToPlayer OK | userId: %d | passType: %s | givenBy: %s",
				targetUserId, passType, tostring(giverUserId)))
		end

		return true, "Pass given successfully"
	else
		warn(string.format("[RoleSystem] GivePassToPlayer FAILED | userId: %d | passType: %s", targetUserId, passType))
		return false, "DataStore error"
	end
end

function RoleSystem:RemovePassFromPlayer(targetUserId)
	local key = "givenpass_" .. tostring(targetUserId)

	local success = datastoreRemoveAsync(key)

	if success then
		self:InvalidateOwnershipCache(targetUserId)

		local player = game.Players:GetPlayerByUserId(targetUserId)
		if player then
			self:UpdatePlayerRole(player)
		end

		if DEBUG_MODE then -- 🔥 DEBUG WRAPPER
			print(string.format("[RoleSystem] RemovePassFromPlayer OK | userId: %d", targetUserId))
		end

		return true, "Pass removed successfully"
	else
		warn(string.format("[RoleSystem] RemovePassFromPlayer FAILED | userId: %d", targetUserId))
		return false, "DataStore error"
	end
end

-- ====================================
-- MODERATOR MANAGEMENT (backward compatibility)
-- ====================================
function RoleSystem:AddModerator(userId, givenByUserId)
	return self:GivePassToPlayer(userId, "Moderator", givenByUserId)
end

function RoleSystem:RemoveModerator(userId)
	local key = "givenpass_" .. tostring(userId)
	local givenPassData = datastoreGetAsync(key)

	if givenPassData and (givenPassData.passType == "Moderator" or givenPassData.passType == "Admin") then
		return self:RemovePassFromPlayer(userId)
	end

	if isInList(userId, self.Config.ModeratorIds) then
		return false, "Cannot remove hardcoded moderator (edit config instead)"
	end

	return false, "User is not a moderator or admin"
end

-- ====================================
-- STATS & DIAGNOSTICS
-- ====================================
function RoleSystem:GetOwnershipStats()
	local stats = {
		totalCached   = 0,
		vvipCount     = 0,
		vipCount      = 0,
		givenPassCount = 0,
		moderatorCount = 0,
		adminCount    = 0
	}

	for userId, ownership in pairs(playerOwnershipCache) do
		stats.totalCached = stats.totalCached + 1

		if ownership.VVIP then stats.vvipCount = stats.vvipCount + 1 end
		if ownership.VIP  then stats.vipCount  = stats.vipCount  + 1 end

		if ownership.GivenPass ~= "None" then
			stats.givenPassCount = stats.givenPassCount + 1
			if ownership.GivenPass == "Moderator" then
				stats.moderatorCount = stats.moderatorCount + 1
			elseif ownership.GivenPass == "Admin" then
				stats.adminCount = stats.adminCount + 1
			end
		end
	end

	return stats
end

-- ====================================
-- UTILITY FUNCTIONS
-- ====================================
function RoleSystem:CompareRoles(role1, role2)
	local h1 = self.Config.RoleHierarchy[role1] or 0
	local h2 = self.Config.RoleHierarchy[role2] or 0
	return h1 - h2
end

function RoleSystem:HasHigherRole(player1, player2)
	local role1 = self:GetPlayerRole(player1)
	local role2 = self:GetPlayerRole(player2)
	return self:CompareRoles(role1, role2) > 0
end

function RoleSystem:GetPlayerPriority(player)
	local role = self:GetPlayerRole(player)
	return self.Config.RoleHierarchy[role] or 1
end

-- Compatibility stubs
function RoleSystem:GetRolePermissions(role) return {} end
function RoleSystem:GetPlayerPermissions(player) return {} end
function RoleSystem:HasZoneAccess(player, zoneName) return false end
function RoleSystem:HasItemAccess(player, itemName) return false end
function RoleSystem:CanUseCommand(player, commandName) return false end
function RoleSystem:GetFeature(player, featureName) return nil end
function RoleSystem:GetStatMultiplier(player, statName) return 1 end
function RoleSystem:GetAllSpecialItems(player) return {} end
function RoleSystem:ApplyRoleToPlayer(player) return self:GetPlayerRole(player) end
function RoleSystem:GiveSpecialItems(player) end

-- ANTI MEMORY LEAK UNTUK CACHE ROLE
game:GetService("Players").PlayerRemoving:Connect(function(player)
	-- Variabel playerOwnershipCache ada di scope file ini
	RoleSystem:InvalidateOwnershipCache(player.UserId)
end)

return RoleSystem