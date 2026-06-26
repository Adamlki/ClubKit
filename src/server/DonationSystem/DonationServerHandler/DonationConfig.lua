local RunService = game:GetService("RunService")

local DonationConfig = {}

-- ============================================
-- ENVIRONMENT DETECTION
-- ============================================
DonationConfig.IS_STUDIO   = RunService:IsStudio()
DonationConfig.IS_TEST_MODE = DonationConfig.IS_STUDIO or game.PlaceId == 0

-- Field DataStore yang aktif sesuai environment
DonationConfig.DONATION_FIELD = DonationConfig.IS_TEST_MODE
	and "Donated - Studio"
	or  "Donated - Experience"

-- ============================================
-- DATASTORE CONFIGURATION
-- ============================================
DonationConfig.DATASTORE = {
	NAME           = "Donation Board JEKY_V2",
	KEY            = "Donations",
	SCOPE          = "global",
	RETRY_ATTEMPTS = 3,
	RETRY_DELAY    = 1,
	SAVE_COOLDOWN  = 5,  -- detik per player
}

-- ============================================
-- PRODUCT CONFIGURATION
-- ============================================
DonationConfig.PRODUCTS = {
	{id = 3578052958, name = "Support 1", price = 13},
	{id = 3578052957, name = "Support 2", price = 25},
	{id = 3578052956, name = "Support 3", price = 50},
	{id = 3578052954, name = "Support 4", price = 100},
	{id = 3578052955, name = "Support 5", price = 250},
	{id = 3578052953, name = "Support 6", price = 500},
	{id = 3578052952, name = "Support 7", price = 1000},
	{id = 3578052948, name = "Support 8", price = 2500},
	{id = 3578052949, name = "Support 9", price = 5000},
}

-- Quick-lookup: ProductId -> Price
DonationConfig.PRODUCT_PRICES = {}
for _, product in ipairs(DonationConfig.PRODUCTS) do
	DonationConfig.PRODUCT_PRICES[product.id] = product.price
end

-- ============================================
-- BROADCAST CONFIGURATION
-- ============================================
DonationConfig.BROADCAST = {
	ENABLED              = true,
	MIN_DONATION         = 13,   -- minimum untuk broadcast dengan custom message
	DISPLAY_DURATION     = 5,    -- detik per notifikasi
	QUEUE_DELAY          = 0.5,
	MAX_MESSAGE_LENGTH   = 200,
	MAX_QUEUE            = 50,
	MAX_QUEUE_PER_PLAYER = 3,
	COOLDOWN             = 10,   -- detik antar broadcast custom
}

-- Pesan default untuk donasi kecil (di bawah MIN_DONATION)
DonationConfig.DEFAULT_SMALL_DONATION_MESSAGE = "Welcome to the game! Thank you for your donation!"

-- ============================================
-- SCREEN BOARD CONFIGURATION  (FITUR BARU)
-- Mengatur tampilan pesan di SurfaceGui ScreenText > ScreenMessage.
--
-- MIN_DONATION  : donasi minimal agar pesan tampil di papan.
--                 Pesan bertahan sampai ada donasi baru yang >= nilai ini.
-- NAME_FORMAT   : format teks DisplayName. %s pertama = nama player,
--                 %s kedua = jumlah donasi (gunakan tostring atau formatNumber).
--                 Contoh: "%s donated %d Robux!"
-- DEFAULT_NAME  : teks DisplayName saat tidak ada donasi (saat server baru start).
-- DEFAULT_MESSAGE: teks DisplayMessage saat tidak ada donasi.
-- ============================================
DonationConfig.SCREEN_BOARD = {
	ENABLED         = true,
	MIN_DONATION    = 13,    -- donasi minimal untuk tampil di screen board
	NAME_FORMAT     = "%s  |  %d Robux",  -- %s = DisplayName, %d = amount
	DEFAULT_NAME    = "NIGHTBEAT PARTY",
	DEFAULT_MESSAGE = "KATA KATA HARI INI KING!!!",
}

-- ============================================
-- SECURITY CONFIGURATION
-- ============================================
DonationConfig.SECURITY = {
	-- Di Studio, tracking dimatikan agar mudah testing
	TRACK_PURCHASES  = not DonationConfig.IS_TEST_MODE,
	PURCHASE_TIMEOUT = 300,   -- 5 menit
	KICK_ON_FAKE     = false, -- Kick player yang terdeteksi fake donation
}

-- ============================================
-- DEBUG CONFIGURATION
-- ============================================
DonationConfig.DEBUG = {
	ENABLED        = false,
	SHOW_DATASTORE = true,
	SHOW_RECEIPT   = true,
	SHOW_BROADCAST = true,
	SHOW_ERRORS    = true,
}

return DonationConfig
