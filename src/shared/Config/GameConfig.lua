--!strict
-- ============================================================
-- GameConfig (ClubKit Shared Central Configuration)
-- ============================================================

local RemoteNames = require(script.Parent.RemoteNames)

local GameConfig = {
	RemoteNames = RemoteNames,

	-- Nilai dasar game
	GAME_NAME = "RASA NADA",
	DEFAULT_MESSAGE = "Welcome to RASA NADA",

	-- Timing defaults
	TIMINGS = {
		DEFAULT_NOTIFICATION_DURATION = 3,
		STAGE_EFFECT_DURATION = 15,
		SPOTLIGHT_DURATION = 5,
	},

	-- Role hierarchy ranking
	ROLE_HIERARCHY = {
		Owner = 5,
		Admin = 4,
		Moderator = 3,
		VIP = 2,
		Player = 1,
	},
}

return GameConfig
