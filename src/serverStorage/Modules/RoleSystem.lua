local RoleSystem = {}

local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local CustomTeamsRemotes = ReplicatedStorage:FindFirstChild("CustomTeamsRemotes")
if not CustomTeamsRemotes then
	CustomTeamsRemotes = Instance.new("Folder")
	CustomTeamsRemotes.Name = "CustomTeamsRemotes"
	CustomTeamsRemotes.Parent = ReplicatedStorage
end

local notifyRemote = CustomTeamsRemotes:FindFirstChild("Notify")
if not notifyRemote then
	notifyRemote = Instance.new("RemoteEvent")
	notifyRemote.Name = "Notify"
	notifyRemote.Parent = CustomTeamsRemotes
end

local PrivateConfig = require(script.Parent:WaitForChild("PrivateConfig"))

local featureConfig = PrivateConfig.Features or {}

RoleSystem.Config = {
	Features = {
		VIPShopEnabled = featureConfig.VIPShopEnabled ~= false, -- default ON
		VIPGiftEnabled = featureConfig.VIPGiftEnabled == true,  -- default OFF
		CommunityVIPEnabled = featureConfig.CommunityVIPEnabled ~= false, -- default ON
	},
	GamePasses = PrivateConfig.GamePasses,
	GiftProducts = PrivateConfig.GiftProducts,
	ActiveGamepasses = PrivateConfig.ActiveGamepasses,
	OwnerIds = PrivateConfig.OwnerIds,
	AdminIds = PrivateConfig.AdminIds,
	ModeratorIds = PrivateConfig.ModeratorIds,

	RoleHierarchy = {
		Owner = 5,
		Admin = 4,
		Moderator = 3,
		VIP = 2,
		Player = 1,
	},

	GroupId = PrivateConfig.GroupId,

	DATASTORE_NAME = RunService:IsStudio() and "PlayerGiveGamePasses_Studio_v1" or "PlayerGiveGamePasses_v1",
	DATASTORE_RETRY_ATTEMPTS = 3,
	DATASTORE_RETRY_DELAY = 1,
	GAMEPASS_CHECK_TIMEOUT = 15,
	GAMEPASS_CHECK_RETRIES = 2,
}

local giveGamePassStore = DataStoreService:GetDataStore(RoleSystem.Config.DATASTORE_NAME)
local VALID_PASS_TYPES = { VIP = true, Moderator = true, Admin = true }
local GROUP_CHECK_TTL = 60 -- detik; hindari IsInGroup berulang di setiap GetPlayerRole

local playerOwnershipCache = {}
local ownershipLoadingLocks = {}
local groupCheckCooldown = {}
local preservedVIPStatus = {}

local roleChangedEvent = Instance.new("BindableEvent")
roleChangedEvent.Name = "RoleChanged"
RoleSystem.RoleChanged = roleChangedEvent.Event

local function isInList(userId, list)
	return list ~= nil and table.find(list, userId) ~= nil
end

local function datastoreGetAsync(key, player)
	for attempt = 1, RoleSystem.Config.DATASTORE_RETRY_ATTEMPTS do
		local success, result = pcall(giveGamePassStore.GetAsync, giveGamePassStore, key)
		if success then return result end
		if attempt < RoleSystem.Config.DATASTORE_RETRY_ATTEMPTS then
			task.wait(2 ^ attempt)
		end
	end

	if player then
		pcall(notifyRemote.FireClient, notifyRemote, player, {
			Title = "Sistem Padat",
			Text = "Pemuatan status Donasi/Gamepass kamu sedang dalam antrean.",
			Duration = 8,
		})
	end
	return nil
end

local function datastoreSetAsync(key, value)
	for attempt = 1, RoleSystem.Config.DATASTORE_RETRY_ATTEMPTS do
		if pcall(giveGamePassStore.SetAsync, giveGamePassStore, key, value) then return true end
		if attempt < RoleSystem.Config.DATASTORE_RETRY_ATTEMPTS then
			task.wait(RoleSystem.Config.DATASTORE_RETRY_DELAY)
		end
	end
	return false
end

local function datastoreRemoveAsync(key)
	for attempt = 1, RoleSystem.Config.DATASTORE_RETRY_ATTEMPTS do
		if pcall(giveGamePassStore.RemoveAsync, giveGamePassStore, key) then return true end
		if attempt < RoleSystem.Config.DATASTORE_RETRY_ATTEMPTS then
			task.wait(RoleSystem.Config.DATASTORE_RETRY_DELAY)
		end
	end
	return false
end

local function checkSingleGamepass(player, gamepassId, retryCount)
	retryCount = retryCount or 0
	if not player or not gamepassId or gamepassId == 0 then return false end

	local success, hasPass = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, gamepassId)
	if success then return hasPass end

	if retryCount < RoleSystem.Config.GAMEPASS_CHECK_RETRIES then
		task.wait(2 ^ (retryCount + 1))
		return checkSingleGamepass(player, gamepassId, retryCount + 1)
	end

	if player then
		pcall(notifyRemote.FireClient, notifyRemote, player, {
			Title = "Sistem Padat",
			Text = "Pemuatan status Donasi/Gamepass kamu sedang dalam antrean.",
			Duration = 8,
		})
	end
	return false
end

local function checkAnyGamepass(player, gamepassIds)
	if type(gamepassIds) == "number" then
		return checkSingleGamepass(player, gamepassIds)
	end
	if type(gamepassIds) == "table" then
		for _, gamepassId in ipairs(gamepassIds) do
			if checkSingleGamepass(player, gamepassId) then return true end
		end
	end
	return false
end

local gamepassQueue = {}
local activeWorkers = 0
local MAX_GAMEPASS_WORKERS = 6

local function processGamepassQueue()
	while activeWorkers < MAX_GAMEPASS_WORKERS and #gamepassQueue > 0 do
		activeWorkers += 1
		task.spawn(function()
			while #gamepassQueue > 0 do
				local nextCheck = table.remove(gamepassQueue, 1)
				if nextCheck and nextCheck.player and nextCheck.player.Parent then
					pcall(nextCheck.callback)
				end
				task.wait(0.25)
			end
			activeWorkers -= 1
		end)
	end
end

function RoleSystem:CachePlayerOwnership(player)
	local userId = player.UserId
	local cached = playerOwnershipCache[userId]
	if cached then
		cached.DisconnectedAt = nil
		return cached
	end

	if ownershipLoadingLocks[userId] then
		local waited = 0
		while ownershipLoadingLocks[userId] and waited < 10 do
			waited += task.wait(0.05)
		end
		if playerOwnershipCache[userId] then
			return playerOwnershipCache[userId]
		end
	end

	ownershipLoadingLocks[userId] = true

	local ownership = {
		VIP = preservedVIPStatus[userId] or false,
		GivenPass = "None",
		CheckedAt = os.clock(),
	}
	preservedVIPStatus[userId] = nil

	local key = "givenpass_" .. tostring(userId)
	local givenPassData = datastoreGetAsync(key, player)

	if givenPassData then
		local passType = type(givenPassData) == "table"
			and (givenPassData.passType or givenPassData.PassType or givenPassData.Role or givenPassData.role)
			or (type(givenPassData) == "string" and givenPassData or nil)

		if passType then
			if passType == "VVIP" then passType = "VIP" end
			ownership.GivenPass = passType
			if passType == "VIP" then ownership.VIP = true end
		end
	end

	playerOwnershipCache[userId] = ownership
	ownershipLoadingLocks[userId] = nil

	if ownership.GivenPass == "None" then
		table.insert(gamepassQueue, {
			player = player,
			callback = function()
				if checkAnyGamepass(player, self.Config.GamePasses.VIP) then
					ownership.VIP = true
					ownership.GivenPass = "VIP"
					playerOwnershipCache[userId] = ownership
					if player and player.Parent then
						self:UpdatePlayerRole(player)
					end
				end
			end,
		})
		processGamepassQueue()
	end

	return ownership
end

function RoleSystem:GetPlayerOwnership(player)
	local userId = player.UserId
	local cached = playerOwnershipCache[userId]
	if cached then
		cached.DisconnectedAt = nil
		return cached
	end
	return self:CachePlayerOwnership(player)
end

function RoleSystem:UpdateOwnershipCache(player, gamepassType, owned)
	local userId = player.UserId
	if not playerOwnershipCache[userId] then
		playerOwnershipCache[userId] = {
			VIP = false,
			GivenPass = "None",
			CheckedAt = os.clock(),
		}
	end
	playerOwnershipCache[userId][gamepassType] = owned
	playerOwnershipCache[userId].CheckedAt = os.clock()
end

function RoleSystem:InvalidateOwnershipCache(userId)
	if playerOwnershipCache[userId] and playerOwnershipCache[userId].VIP then
		preservedVIPStatus[userId] = true
	end
	playerOwnershipCache[userId] = nil
end

function RoleSystem:HandlePlayerRemoving(userId)
	groupCheckCooldown[userId] = nil
	preservedVIPStatus[userId] = nil
	local cached = playerOwnershipCache[userId]
	if cached then
		cached.DisconnectedAt = os.clock()
		task.delay(65, function()
			local current = playerOwnershipCache[userId]
			if current and current.DisconnectedAt and (os.clock() - current.DisconnectedAt >= 60) then
				playerOwnershipCache[userId] = nil
			end
		end)
	end
end

function RoleSystem:GetPlayerRole(player)
	local userId = player.UserId

	if isInList(userId, self.Config.OwnerIds) then return "Owner" end
	if isInList(userId, self.Config.AdminIds) then return "Admin" end
	if isInList(userId, self.Config.ModeratorIds) then return "Moderator" end

	local ownership = self:GetPlayerOwnership(player)
	if ownership.GivenPass == "Admin" then return "Admin" end
	if ownership.GivenPass == "Moderator" then return "Moderator" end
	if ownership.GivenPass == "VIP" or ownership.GivenPass == "VVIP" or ownership.VIP or ownership.GroupVIP then
		return "VIP"
	end

	local now = os.clock()
	if ownership.GroupCheckedAt and (now - ownership.GroupCheckedAt) < GROUP_CHECK_TTL then
		if ownership.GroupVIP then return "VIP" end
		return "Player"
	end

	local targetGroupId = self.Config.GroupId or 192828493
	local ok, inGroup = pcall(player.IsInGroup, player, targetGroupId)
	ownership.GroupCheckedAt = now
	if ok and inGroup then
		ownership.VIP = true
		ownership.GroupVIP = true
		return "VIP"
	end

	ownership.GroupVIP = false
	return "Player"
end

function RoleSystem:InitializePlayer(player)
	self:GetPlayerOwnership(player)
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
	return self:InitializePlayer(player)
end

function RoleSystem:GivePassToPlayer(targetUserId, passType, giverUserId, callback)
	if passType == "VVIP" then passType = "VIP" end

	if not VALID_PASS_TYPES[passType] then
		warn(string.format("[RoleSystem] GivePassToPlayer: invalid passType '%s'", tostring(passType)))
		if type(callback) == "function" then task.spawn(callback, false, "Invalid pass type") end
		return false, "Invalid pass type"
	end

	local existing = playerOwnershipCache[targetUserId]
	if passType == "VIP" and existing and (existing.GivenPass == "Admin" or existing.GivenPass == "Moderator") then
		existing.VIP = true
		existing.CheckedAt = os.clock()
		local player = Players:GetPlayerByUserId(targetUserId)
		if player then self:UpdatePlayerRole(player) end
		if type(callback) == "function" then task.spawn(callback, true, "Pass given successfully") end
		return true, "Pass given successfully"
	end

	local key = "givenpass_" .. tostring(targetUserId)
	local data = {
		passType = passType,
		givenBy = giverUserId,
		givenAt = os.time(),
		timestamp = os.time(),
	}

	if datastoreSetAsync(key, data) then
		playerOwnershipCache[targetUserId] = {
			VIP = (passType == "VIP") or (existing and existing.VIP == true) or false,
			GivenPass = passType,
			CheckedAt = os.clock(),
		}

		local player = Players:GetPlayerByUserId(targetUserId)
		if player then self:UpdatePlayerRole(player) end
		if type(callback) == "function" then task.spawn(callback, true, "Pass given successfully") end
		return true, "Pass given successfully"
	else
		warn(string.format("[RoleSystem] GivePassToPlayer FAILED | userId: %d | passType: %s", targetUserId, passType))
		if type(callback) == "function" then task.spawn(callback, false, "DataStore error") end
		return false, "DataStore error"
	end
end

function RoleSystem:RemovePassFromPlayer(targetUserId)
	local key = "givenpass_" .. tostring(targetUserId)
	if datastoreRemoveAsync(key) then
		playerOwnershipCache[targetUserId] = {
			VIP = false,
			GivenPass = "None",
			CheckedAt = os.clock(),
		}
		local player = Players:GetPlayerByUserId(targetUserId)
		if player then self:UpdatePlayerRole(player) end
		return true, "Pass removed successfully"
	end

	warn(string.format("[RoleSystem] RemovePassFromPlayer FAILED | userId: %d", targetUserId))
	return false, "DataStore error"
end

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

function RoleSystem:GetOwnershipStats()
	local stats = {
		totalCached = 0,
		vipCount = 0,
		givenPassCount = 0,
		moderatorCount = 0,
		adminCount = 0,
	}

	for _, ownership in pairs(playerOwnershipCache) do
		stats.totalCached += 1
		if ownership.VIP then stats.vipCount += 1 end
		if ownership.GivenPass ~= "None" then
			stats.givenPassCount += 1
			if ownership.GivenPass == "Moderator" then
				stats.moderatorCount += 1
			elseif ownership.GivenPass == "Admin" then
				stats.adminCount += 1
			end
		end
	end

	return stats
end

function RoleSystem:CompareRoles(role1, role2)
	local h1 = self.Config.RoleHierarchy[role1] or 0
	local h2 = self.Config.RoleHierarchy[role2] or 0
	return h1 - h2
end

function RoleSystem:HasHigherRole(player1, player2)
	return self:CompareRoles(self:GetPlayerRole(player1), self:GetPlayerRole(player2)) > 0
end

function RoleSystem:GetPlayerPriority(player)
	return self.Config.RoleHierarchy[self:GetPlayerRole(player)] or 1
end

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

Players.PlayerRemoving:Connect(function(player)
	RoleSystem:HandlePlayerRemoving(player.UserId)
end)

local RemotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
if not RemotesFolder then
	RemotesFolder = Instance.new("Folder")
	RemotesFolder.Name = "Remotes"
	RemotesFolder.Parent = ReplicatedStorage
end

local checkGroupVIPRemote = RemotesFolder:FindFirstChild("CheckGroupVIP")
if not checkGroupVIPRemote then
	checkGroupVIPRemote = Instance.new("RemoteFunction")
	checkGroupVIPRemote.Name = "CheckGroupVIP"
	checkGroupVIPRemote.Parent = RemotesFolder
end

if RunService:IsServer() then
	checkGroupVIPRemote.OnServerInvoke = function(player)
		if not player then return false, "Invalid player" end

		local features = RoleSystem.Config.Features or {}
		if features.CommunityVIPEnabled == false then
			return false, "Reward VIP komunitas sedang dinonaktifkan."
		end

		local now = os.clock()
		local lastCheck = groupCheckCooldown[player.UserId] or 0
		if (now - lastCheck) < 30 then
			local remaining = math.ceil(30 - (now - lastCheck))
			return false, string.format("Mohon tunggu %d detik sebelum memeriksa kembali.", remaining)
		end
		groupCheckCooldown[player.UserId] = now

		local targetGroupId = RoleSystem.Config.GroupId or 192828493
		local ok, inGroup = pcall(player.IsInGroup, player, targetGroupId)
		local isMember = ok and inGroup

		if not isMember then
			local GroupService = game:GetService("GroupService")
			local ok2, groups = pcall(GroupService.GetGroupsAsync, GroupService, player.UserId)
			if ok2 and groups then
				for _, g in ipairs(groups) do
					if g.Id == targetGroupId then
						isMember = true
						break
					end
				end
			end
		end

		local ownership = RoleSystem:GetPlayerOwnership(player)
		if isMember then
			ownership.VIP = true
			ownership.GroupVIP = true
			ownership.GroupCheckedAt = os.clock()
			ownership.CheckedAt = os.clock()

			RoleSystem:UpdatePlayerRole(player)
			return true, "Selamat! Kamu telah bergabung di komunitas dan mendapatkan VIP Gratis!"
		end

		ownership.GroupVIP = false
		ownership.GroupCheckedAt = os.clock()
		return false, "Kamu belum bergabung ke grup komunitas."
	end
end

return RoleSystem
