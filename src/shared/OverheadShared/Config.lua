	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local ConfigFolder = ReplicatedStorage:WaitForChild("Config")
	local GameConfig = require(ConfigFolder:WaitForChild("GameConfig"))
	local AssetConfig = require(ConfigFolder:WaitForChild("AssetConfig"))

	local Config = {}

	-- ====================================
	-- DEBUG
	-- ====================================
	Config.DEBUG_ENABLED = false

	-- ====================================
	-- DATASTORE (Title)
	-- ====================================
	Config.TITLE_DATASTORE_NAME   = "PlayerTitles_V4"
	Config.TITLE_DATASTORE_PREFIX = "User_"

	-- ====================================
	-- DONATION RANK SYSTEM (AUTO - TopRobux dari GALAXY_DONATIONS)
	-- ====================================
	Config.DONATION_DATASTORE_NAME        = "Donation Board JEKY"
	Config.DONATION_RANK_UPDATE_INTERVAL  = 60
	Config.DONATION_TOP_RANKS             = 10
	Config.SAWERIA_TOP_RANKS              = 10 -- [TAMBAH INI] Batas rank Saweria yang dimunculkan di Overhead
	
	-- ====================================
	-- DONATUR RANK SYSTEM (MANUAL - TopDonatur, assigned by Admin)
	-- ====================================
	Config.DONATUR_RANK_DATASTORE_NAME = "ManualDonaturRanks_V1"
	Config.DONATUR_RANK_PREFIX         = "Rank_"

	-- ====================================
	-- GROUP & BADGES
	-- ====================================
	Config.GROUP_ID        = GameConfig.GroupId
	Config.PREMIUM_IMAGE   = AssetConfig.Images.PremiumBadge
	Config.VERIFIED_IMAGE  = AssetConfig.Images.VerifiedBadge

	-- ====================================
	-- REGION & FLAGS
	-- ====================================
	-- Jika true, semua pemain dari negara Eropa (Jerman, Inggris, Prancis, dll.) akan disatukan memakai bendera Uni Eropa (🇪🇺).
	-- Jika false, pemain Eropa akan memakai bendera spesifik negara masing-masing (🇩🇪, 🇬🇧, 🇫🇷, dll.).
	Config.USE_EU_FLAG_FOR_EUROPE = true

	-- ====================================
	-- AVATAR
	-- ====================================
	Config.AVATAR_SIZE = Enum.ThumbnailSize.Size420x420
	Config.AVATAR_TYPE = Enum.ThumbnailType.HeadShot

	-- ====================================
	-- ROLE COLORS
	-- ====================================
	Config.ROLE_COLORS = {
		Owner     = Color3.fromRGB(255, 0, 0),
		Admin     = Color3.fromRGB(255, 85, 0),
		Moderator = Color3.fromRGB(0, 170, 255),
		Sultan    = Color3.fromRGB(255, 215, 0), -- [TAMBAH INI]
		VIP       = Color3.fromRGB(0, 255, 0),
		Player    = Color3.fromRGB(200, 200, 200),
	}

	-- ====================================
	-- TOP ROBUX COLORS (Auto dari GALAXY_DONATIONS)
	-- ====================================
	Config.TOP_SPENDER_COLORS = {
		[1]  = { Frame = Color3.fromRGB(180, 140, 0),   Text = Color3.fromRGB(255, 255, 255) },
		[2]  = { Frame = Color3.fromRGB(120, 120, 140),  Text = Color3.fromRGB(255, 255, 255) },
		[3]  = { Frame = Color3.fromRGB(140, 90, 50),   Text = Color3.fromRGB(255, 255, 255) },
		[4]  = { Frame = Color3.fromRGB(100, 50, 150),  Text = Color3.fromRGB(255, 255, 255) },
		[5]  = { Frame = Color3.fromRGB(100, 50, 150),  Text = Color3.fromRGB(255, 255, 255) },
		[6]  = { Frame = Color3.fromRGB(30, 80, 150),   Text = Color3.fromRGB(255, 255, 255) },
		[7]  = { Frame = Color3.fromRGB(30, 80, 150),   Text = Color3.fromRGB(255, 255, 255) },
		[8]  = { Frame = Color3.fromRGB(40, 120, 60),   Text = Color3.fromRGB(255, 255, 255) },
		[9]  = { Frame = Color3.fromRGB(40, 120, 60),   Text = Color3.fromRGB(80, 220, 100)  },
		[10] = { Frame = Color3.fromRGB(40, 120, 60),   Text = Color3.fromRGB(255, 255, 255) },
	}

	-- ====================================
	-- TOP DONATUR COLORS (Manual assign by Admin) - sama dengan TopRobux
	-- ====================================
	Config.TOP_DONATUR_COLORS = {
		[1]  = { Frame = Color3.fromRGB(180, 140, 0),   Text = Color3.fromRGB(255, 255, 255) },
		[2]  = { Frame = Color3.fromRGB(120, 120, 140),  Text = Color3.fromRGB(255, 255, 255) },
		[3]  = { Frame = Color3.fromRGB(140, 90, 50),   Text = Color3.fromRGB(255, 255, 255) },
		[4]  = { Frame = Color3.fromRGB(100, 50, 150),  Text = Color3.fromRGB(255, 255, 255) },
		[5]  = { Frame = Color3.fromRGB(100, 50, 150),  Text = Color3.fromRGB(255, 255, 255) },
		[6]  = { Frame = Color3.fromRGB(30, 80, 150),   Text = Color3.fromRGB(255, 255, 255) },
		[7]  = { Frame = Color3.fromRGB(30, 80, 150),   Text = Color3.fromRGB(255, 255, 255) },
		[8]  = { Frame = Color3.fromRGB(40, 120, 60),   Text = Color3.fromRGB(255, 255, 255) },
		[9]  = { Frame = Color3.fromRGB(40, 120, 60),   Text = Color3.fromRGB(80, 220, 100)  },
		[10] = { Frame = Color3.fromRGB(40, 120, 60),   Text = Color3.fromRGB(255, 255, 255) },
	}

	-- ====================================
	-- ROLE DISPLAY TEXT
	-- ====================================
	Config.CUSTOM_DISPLAY_TEXT = {
		Owner     = "Owner",
		Admin     = "Head Staff",
		Moderator = "Staff",
		Sultan    = "Sultan", -- [TAMBAH INI]
		VIP       = "VIP",
		Player    = "Tamu",
	}

	-- ====================================
	-- LOGO DISPLAY RULES
	-- ====================================
	Config.LOGO_DISPLAY = {
		Owner     = { Verified = true },
		Admin     = { Verified = true },
		Moderator = { Verified = true },
		VIP       = { Verified = false },
		Player    = { Verified = false },
	}

	-- ====================================
	-- LEVEL DISPLAY
	-- ====================================
	Config.LEVEL_FORMAT = "Level %d"

	-- ====================================
	-- NAME TEXT SIZE
	-- ====================================
	Config.NAME_TEXT_SIZE_MIN = 10
	Config.NAME_TEXT_SIZE_MAX = 16

	return Config