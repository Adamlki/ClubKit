local MessageConfig = {}

-- ====================================
-- ACCESS CONFIGURATION
-- ====================================
MessageConfig.Access = {
	-- Role minimum yang boleh mengirim broadcast
	MinimumRole = "Moderator",

	-- Hierarki role (semakin besar angka = semakin tinggi)
	RoleHierarchy = {
		Owner     = 5,
		Admin     = 4,
		Moderator = 3,
		VIP       = 2,
		Player    = 1
	}
}

-- ====================================
-- TIMER CONFIGURATION
-- Per-role cooldown sebelum bisa broadcast lagi.
-- Owner, Admin, Moderator = 0 (tidak ada cooldown)
-- ====================================
MessageConfig.Timer = {
	Durations = {
		Owner     = 0,
		Admin     = 15,
		Moderator = 30,
		VIP       = 120,  -- VIP harus tunggu 120 detik
		Player    = 360
	},

	-- Tampilkan notifikasi sisa waktu ke pengirim
	ShowNotification = true
}

-- ====================================
-- ROLE DISPLAY CONFIGURATION
-- ====================================
MessageConfig.RoleDisplay = {
	Owner = {
		Text  = "Owner",
		Color = Color3.fromRGB(255, 0, 0),
	},
	Admin = {
		Text  = "Head Staff",
		Color = Color3.fromRGB(255, 255, 0),
	},
	Moderator = {
		Text  = "Staff",
		Color = Color3.fromRGB(0, 100, 255),
	},
	VIP = {
		Text  = "VIP",
		Color = Color3.fromRGB(0, 220, 80),
	},
	Player = {
		Text  = "Player",
		Color = Color3.fromRGB(220, 220, 220),
	}
}

-- ====================================
-- MESSAGE VALIDATION
-- ====================================
MessageConfig.Validation = {
	MinLength          = 1,
	MaxLength          = 200,
	Cooldown           = 3,   -- detik antar pesan umum
	MaxMessagesPerMin  = 10,

	-- Selalu aktif — wajib per aturan Roblox
	EnableFilter       = true
}

-- ====================================
-- NOTIFICATION CONFIGURATION (Client)
-- ====================================
MessageConfig.Notification = {
	Duration   = 8,
	MaxVisible = 4,
	Animation  = {
		DropSpeed      = 0.5,
		EasingStyle    = Enum.EasingStyle.Back,
		EasingDirection = Enum.EasingDirection.Out
	},
	Sound = {
		Enabled       = false,
		SoundId       = "",
		Volume        = 0,
		PlaybackSpeed = 1
	}
}

-- ====================================
-- UI CONFIGURATION
-- ====================================
MessageConfig.UI = {
	Icon = {
		Image = "rbxassetid://7733992901",
		Name  = "BC",
		Tip   = "Admin Message"
	}
}

return MessageConfig