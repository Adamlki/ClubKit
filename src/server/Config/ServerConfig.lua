--!optimize 2

local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")

local PrivateConfig = require(ServerStorage:WaitForChild("Modules"):WaitForChild("PrivateConfig"))

local featureConfig = PrivateConfig.Features or {}

local ServerConfig = {
	Features = {
		VIPShopEnabled = featureConfig.VIPShopEnabled ~= false, -- default ON
		VIPGiftEnabled = featureConfig.VIPGiftEnabled == true,  -- default OFF
		CommunityVIPEnabled = featureConfig.CommunityVIPEnabled ~= false, -- default ON
	},

	OwnerIds = PrivateConfig.OwnerIds or {},
	AdminIds = PrivateConfig.AdminIds or {},
	ModeratorIds = PrivateConfig.ModeratorIds or {},
	GroupId = PrivateConfig.GroupId or 0,
	GamePasses = PrivateConfig.GamePasses or {},
	GiftProducts = PrivateConfig.GiftProducts or {},
	ActiveGamepasses = PrivateConfig.ActiveGamepasses or {},
	SaweriaWebhookURL = PrivateConfig.SaweriaWebhookURL or "",

	-- DataStores Registry
	DataStores = {
		Donations = "Donation Board JEKY_V2",
		DonationBoardOrdered = "DonationBoard_Ordered_V2",
		RoleSystem = "PlayerGiveGamePasses_v1",
		CustomTeams = "CustomTeamsData_v2",
		GiveRoleTransactions = "GiveRoleTransactions_v1",
		CustomTitleChances = "CustomTitleChances_V1",
		PlayerLevels = "PlayerLevel_v1",
		PlayerLevelsLeaderboard = "PlayerLevels_Leaderboard_v1",
		PlayerLikes = "PlayerLikes_v1",
		PlayerLikesOrdered = "PlayerLikes_Ordered_v1",
		LikeCooldowns = "LikeCooldowns_v1",
	},

	-- DataStore Retry Defaults
	DATASTORE_RETRY_ATTEMPTS = 3,
	DATASTORE_RETRY_DELAY = 1,
}

function ServerConfig.IsOwner(userId: number): boolean
	if RunService:IsStudio() then
		return true
	end
	for _, id in ipairs(ServerConfig.OwnerIds) do
		if id == userId then
			return true
		end
	end
	return false
end

function ServerConfig.GetPrimaryOwnerId(): number
	return ServerConfig.OwnerIds[1] or 0
end

function ServerConfig.GetDailyKey(prefix: string): string
	return prefix .. "_" .. os.date("!%Y_%m_%d")
end

return ServerConfig
