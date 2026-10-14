-- ====================================
-- CLIENT CONFIGURATION (SIMPLIFIED)
-- ====================================
local Config = {
	Debug = false, -- Set false untuk production
	StartVisible = false,
	ButtonStates = {
		Buy = {
			Text = "Buy",
			BackgroundColor = Color3.fromRGB(27, 67, 46),
			TextColor = Color3.fromRGB(255, 255, 255),
			Enabled = true
		},
		Owned = {
			Text = "Owned",
			BackgroundColor = Color3.fromRGB(24, 24, 24), TextColor = Color3.fromRGB(140, 140, 140),
			Enabled = false
		},
		Loading = {
			Text = "Loading...",
			BackgroundColor = Color3.fromRGB(24, 24, 24), TextColor = Color3.fromRGB(180, 180, 180),
			Enabled = false
		},
		Error = {
			Text = "Error",
			BackgroundColor = Color3.fromRGB(48, 20, 30), TextColor = Color3.fromRGB(255, 120, 140),
			Enabled = false
		}
	},
	Notifications = {
		ErrorServer = {
			Title = "Error",
			Text = "Gagal menghubungi server!",
			Duration = 3
		},
		ErrorPurchase = {
			Title = "Error",
			Text = "Gagal membuka menu pembelian!",
			Duration = 3
		},
		AlreadyOwned = {
			Title = "Sudah Dimiliki",
			Text = "Kamu sudah memiliki gamepass ini!",
			Duration = 3
		},
		PurchaseSuccess = {
			Title = "Pembelian Berhasil",
			Text = "Terima kasih atas pembelianmu!",
			Duration = 5
		},
		TooManyRequests = {
			Title = "Peringatan",
			Text = "Terlalu banyak request, tunggu sebentar!",
			Duration = 3
		}
	},
	RemoteTimeout = 10,
	RoleRefreshDelay = 1
}
return Config
