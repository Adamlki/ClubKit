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
	Config.GROUP_ID        = 192828493
	Config.PREMIUM_IMAGE   = "rbxassetid://10885647358"
	Config.VERIFIED_IMAGE  = "rbxassetid://11478378840"

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
		VVIP      = Color3.fromRGB(150, 0, 200),
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
		VVIP      = "VVIP",
		VIP       = "VIP",
		Player    = "Tamu",
	}

	-- ====================================
	-- LOGO DISPLAY RULES
	-- ====================================
	Config.LOGO_DISPLAY = {
		Owner = { ShowAll = true,
			Logos = {"OwnerLogo", "DevLogo", "StaffLogo", "PremiumBadge", "VipLogo", "VvipLogo", "VerifiedBadge", "SultanLogo"} },
		Admin = { ShowAll = true,
			Logos = {"DevLogo", "StaffLogo", "PremiumBadge", "VipLogo", "VvipLogo", "VerifiedBadge", "SultanLogo"} },
		Moderator = { ShowAll = true,
			Logos = {"StaffLogo", "PremiumBadge", "VipLogo", "VvipLogo", "VerifiedBadge", "SultanLogo"} },
		Sultan    = { ShowAll = true, Logos = {"VvipLogo", "SultanLogo"} },
		VVIP      = { ShowAll = false, RoleLogo = "VvipLogo" },
		VIP       = { ShowAll = false, RoleLogo = "VipLogo"  },
		Player    = { ShowAll = false, RoleLogo = nil        },
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

	-- ====================================
	-- TITLE EFFECTS COLOR FACTORS
	-- ====================================
	Config.FRAME_DARKEN_FACTOR  = 0.4
	Config.TEXT_BRIGHTEN_FACTOR = 1.5

	-- ====================================
	-- TITLE EFFECT ANIMATIONS (UPDATED)
	-- ====================================
	Config.EFFECTS = {
		-- ===== Efek Lama (Disempurnakan) =================================

		WAVE = {
			animationRate   = 0.02,
			transitionSpeed = 0.55,
			colors = {
				Color3.fromRGB(255, 0,   0  ),
				Color3.fromRGB(255, 85,  0  ),
				Color3.fromRGB(255, 220, 0  ),
				Color3.fromRGB(0,   220, 0  ),
				Color3.fromRGB(0,   220, 255),
				Color3.fromRGB(0,   60,  255),
				Color3.fromRGB(160, 60,  255),
				Color3.fromRGB(255, 0,   220),
			},
		},

		PULSE = {
			speed           = 3.5,
			animationRate   = 0.02,
			brightnessBoost = 240,
			minBrightness   = 0.1,
			maxBrightness   = 2.0,
			contrastMode    = false,
		},

		RAINBOW = {
			speed         = 0.015,
			animationRate = 0.02,
			saturation    = 1,
			brightness    = 1,
			hueShift      = 0.2,
			useMultiColor = true,
		},

		SHIMMER = {
			speed          = 0.04,
			animationRate  = 0.02,
			flashIntensity = 1.6,
		},

		PALETTE = {
			interval      = 0.75,
			tweenFactor   = 0.92,
			animationRate = 0.02,
		},

		-- None: Tidak ada animasi, hanya warna statis
		NONE = {
			-- Tidak perlu config, CreateNoneEffect hanya set warna statis
		},

		-- Sunset: Gradient oranye-pink-ungu seperti matahari terbenam
		SUNSET = {
			animationRate   = 0.02,
			transitionSpeed = 0.8,
		},

		-- Ocean: Gradient biru laut - cyan - teal
		OCEAN = {
			animationRate   = 0.02,
			transitionSpeed = 0.8,
		},

		-- Galaxy: Gradient ungu-pink-biru seperti nebula
		GALAXY = {
			animationRate   = 0.02,
			transitionSpeed = 0.7,
		},

		-- Emerald: Gradient hijau zamrud - mint - lime
		EMERALD = {
			animationRate   = 0.02,
			transitionSpeed = 0.8,
		},

		-- PinkWhite: Gradient horizontal pink - putih dengan animasi kiri-kanan
		PINKWHITE = {
			animationRate   = 0.02,
			transitionSpeed = 0.8,
		},
	}

	return Config