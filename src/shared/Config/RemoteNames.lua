--!strict
-- ============================================================
-- RemoteNames (ClubKit Shared Config)
-- Centralized registry of folder and RemoteEvent/RemoteFunction names
-- ============================================================

local RemoteNames = {
	Folders = {
		Remotes = "Remotes",
		Carry = "CarryRemotes",
		Effects = "EffectsRemotes",
		AdminPanel = "AdminPanelRemotes",
		CustomTeams = "CustomTeamsRemotes",
		Gamepass = "Gamepass",
		ServerList = "ServerListRemotes",
		GlobalEffect = "GlobalEffectRemotes",
	},

	Remotes = {
		-- Animation & Sync
		StartSync = "startSync",
		ChangeSpeed = "changeSpeed",
		UpdateFavoritedAnimations = "updateFavoritedAnimationsEvent",
		SyncNotification = "SyncNotification",
		AnimationStart = "animationStart",
		UpdateLeaderStatus = "UpdateLeaderStatus",

		-- Carry System
		CarryRequest = "CarryRequest",
		CarryResponse = "CarryResponse",
		CarryEnd = "CarryEnd",

		-- Donation & Effects
		EffectsEvent = "EffectsEvent",
		ShowDonationNotif = "ShowDonationNotif",
		DonationNotification = "DonationNotification",
		RequestDonationState = "RequestDonationState",
		DonorSpotlight = "DonorSpotlightRemote",
		Cinematic = "CinematicRemote",

		-- Role & Gamepass
		GiveRole = "GiveRoleRemote",
		RefreshRole = "RefreshRole",
		ShopRequest = "ShopRequest",
		PlayerDataUpdated = "PlayerDataUpdated",

		-- Admin & Teams
		CustomTeamsNotify = "Notify",

		-- Utility & AFK
		RefreshCharacter = "RefreshCharacterEvent",
		AntiAFKRejoin = "AntiAFKRejoin",
		GLightColorSync = "GLightColorSync",
		GlobalWeaponEvent = "GlobalWeaponEvent",

		-- Server List
		GetServerList = "GetServerList",
		TeleportToServer = "TeleportToServer",
	}
}

return RemoteNames
