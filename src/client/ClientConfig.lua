local ClientConfig = {}

-- ============================================
-- DEBUG
-- ============================================
ClientConfig.DEBUG = {
	ENABLED      = false,
	SHOW_EVENTS  = true,
	SHOW_ERRORS  = true,
}

-- ============================================
-- UI SETTINGS
-- ============================================
ClientConfig.UI = {
	BUTTON_SPACING      = 5,
	BUTTON_CREATE_DELAY = 0.03,
	LOADING_TEXT        = "Memuat produk...",
	PROCESSING_TEXT     = "Processing...",
}

-- ============================================
-- MESSAGE SETTINGS
-- ============================================
ClientConfig.MESSAGE = {
	MIN_DONATION    = 13,
	MAX_LENGTH      = 200,
	COOLDOWN        = 10,
	DEFAULT_MESSAGE = "Welcome to RASA NADA",
}

-- ============================================
-- NOTIFICATION SETTINGS
-- ============================================
ClientConfig.NOTIFICATION = {
	ENABLED          = true,
	MIN_DONATION     = 13,
	SOUND_ID         = "rbxassetid://82038059105956",
	SOUND_VOLUME     = 0.5,
	SLIDE_TIME       = 0.4,
	FADE_TIME        = 0.3,
	SHAKE_ENABLED    = true,
	SHAKE_INTENSITY  = 5,
	SHAKE_DURATION   = 0.15,
}

-- ============================================
-- DONATION COLORS (by tier, descending)
-- ============================================
ClientConfig.DONATION_COLORS = {
	{min = 2000, color = Color3.fromRGB(230, 33,  23),  name = "Legendary"}, 
	{min = 1000, color = Color3.fromRGB(233, 30,  99),  name = "Epic"},      
	{min = 500,  color = Color3.fromRGB(156, 39,  176), name = "Rare"},      
	{min = 250,  color = Color3.fromRGB(63,  81,  181), name = "Super"},     
	{min = 100,  color = Color3.fromRGB(33,  150, 243), name = "Great"},     
	{min = 50,   color = Color3.fromRGB(0,   188, 212), name = "Good"},      
	{min = 30,   color = Color3.fromRGB(0,   150, 136), name = "Nice"},      
	{min = 0,    color = Color3.fromRGB(76,  175, 80),  name = "Thanks"},    
}

-- ============================================
-- CHAT MESSAGES
-- ============================================
ClientConfig.CHAT_MESSAGES = {
	{min = 10000, messages = {
		"WOAHH! %s has donated %s Robux!",
		"LEGENDARY! %s donated %s Robux!",
		"AMAZING! %s just donated %s Robux!",
		"INSANE! %s donated %s Robux!",
	}},
	{min = 5000, messages = {
		"WOW! %s has donated %s Robux!",
		"EPIC! %s donated %s Robux!",
		"INCREDIBLE! %s just donated %s Robux!",
		"AWESOME! %s donated %s Robux!",
	}},
	{min = 2000, messages = {
		"Woahh! %s has donated %s Robux!",
		"Amazing! %s donated %s Robux!",
		"Fantastic! %s just donated %s Robux!",
	}},
	{min = 1000, messages = {
		"Woahh! %s has donated %s Robux!",
		"Great! %s donated %s Robux!",
		"Awesome! %s just donated %s Robux!",
	}},
	{min = 500, messages = {
		"Woahh! %s has donated %s Robux!",
		"Nice! %s donated %s Robux!",
		"Thanks! %s just donated %s Robux!",
	}},
	{min = 200, messages = {
		"Woahh! %s has donated %s Robux!",
		"Thanks! %s donated %s Robux!",
	}},
	{min = 100, messages = {
		"Woahh! %s has donated %s Robux!",
		"Thank you! %s donated %s Robux!",
	}},
	{min = 0, messages = {
		"Thank you! %s has donated %s Robux!",
		"Thanks! %s donated %s Robux!",
	}},
}

ClientConfig.MESSAGES = {
	NO_PRODUCTS         = "Tidak ada produk donasi\n\nHubungi developer untuk bantuan.",
	SERVER_UNAVAILABLE  = "Server tidak tersedia!\n\nSilakan coba lagi.",
	PURCHASE_FAILED     = "Gagal membuka pembelian.",
	LOAD_FAILED         = "Gagal memuat produk.",
	MESSAGE_TOO_SHORT   = "Pesan terlalu pendek!",
	MESSAGE_TOO_LONG    = "Pesan terlalu panjang! (Maks 200 karakter)",
	MESSAGE_SENT        = "Pesan Terkirim!",
}

return ClientConfig
