local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("GameConfig"))

local DonationConfig = {}

-- ENVIRONMENT DETECTION
DonationConfig.IS_STUDIO   = RunService:IsStudio()
DonationConfig.IS_TEST_MODE = DonationConfig.IS_STUDIO or game.PlaceId == 0
DonationConfig.DONATION_FIELD = DonationConfig.IS_TEST_MODE
	and "Donated - Studio"
	or  "Donated - Experience"

-- DATASTORE CONFIGURATION
DonationConfig.DATASTORE = {
	NAME           = "Donation Board JEKY_V2",
	KEY            = "Donations",
	SCOPE          = "global",
	RETRY_ATTEMPTS = 3,
	RETRY_DELAY    = 1,
	SAVE_COOLDOWN  = 5,  -- detik per player
}

-- PRODUCT CONFIGURATION
-- ID dan harga Developer Product; harga harus sama dengan yang ada di Creator Hub.
DonationConfig.PRODUCTS = {
	{id = 3578052958, name = "Support 1", price = 11},
	{id = 3578052957, name = "Support 2", price = 20},
	{id = 3578052956, name = "Support 3", price = 40},
	{id = 3578052954, name = "Support 4", price = 80},
	{id = 3578052955, name = "Support 5", price = 200},
	{id = 3578052953, name = "Support 6", price = 400},
	{id = 3578052952, name = "Support 7", price = 800},
	{id = 3578052948, name = "Support 8", price = 2000},
	{id = 3578052949, name = "Support 9", price = 4000},
}

DonationConfig.PRODUCT_PRICES = {}
for _, product in ipairs(DonationConfig.PRODUCTS) do
	DonationConfig.PRODUCT_PRICES[product.id] = product.price
end

-- BROADCAST CONFIGURATION
DonationConfig.BROADCAST = {
	ENABLED              = true,
	MIN_DONATION         = 11,   -- minimum untuk broadcast dengan custom message
	DISPLAY_DURATION     = 5,    -- detik per notifikasi
	QUEUE_DELAY          = 0.5,
	MAX_MESSAGE_LENGTH   = 200,
	MAX_QUEUE            = 50,
	MAX_QUEUE_PER_PLAYER = 3,
	COOLDOWN             = 10,   -- detik antar broadcast custom
}

DonationConfig.DEFAULT_SMALL_DONATION_MESSAGE = GameConfig.Branding.DonationWelcome

DonationConfig.SCREEN_BOARD = {
	ENABLED         = true,
	MIN_DONATION    = 11,    -- donasi minimal untuk tampil di screen board
	NAME_FORMAT     = "%s  |  %d Robux",
	DEFAULT_NAME    = GameConfig.Branding.ScreenBoardName,
	DEFAULT_MESSAGE = GameConfig.Branding.ScreenBoardMessage,
}

-- SECURITY CONFIGURATION
DonationConfig.SECURITY = {
	TRACK_PURCHASES  = not DonationConfig.IS_TEST_MODE,
	PURCHASE_TIMEOUT = 300,   -- 5 menit
	KICK_ON_FAKE     = false, -- Kick player yang terdeteksi fake donation
}

-- DEBUG CONFIGURATION
DonationConfig.DEBUG = {
	ENABLED        = false,
	SHOW_DATASTORE = true,
	SHOW_RECEIPT   = true,
	SHOW_BROADCAST = true,
	SHOW_ERRORS    = true,
}

return DonationConfig
