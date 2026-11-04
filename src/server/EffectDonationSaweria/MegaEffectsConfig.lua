-- Konfigurasi efek panggung (Robux & Saweria): Nuke, Smite, BlackHole, Starfall

local MegaEffectsConfig = {
	GLOBAL_ENABLED  = true, -- false = matikan semua efek panggung
	ROBUX_ENABLED   = true,
	SAWERIA_ENABLED = true,

	-- false = nonaktifkan efek tertentu
	EFFECTS_ENABLED = {
		Nuke      = true,
		Smite     = true,
		BlackHole = true,
		Starfall  = true,
	},

	-- Harga produk Robux (R$); WaitTime = jeda antrean (detik)
	ROBUX_TIERS = {
		Nuke      = { Enabled = true, MinPrice = 400,  MaxPrice = 799,       WaitTime = 40 },
		Smite     = { Enabled = true, MinPrice = 800,  MaxPrice = 1999,      WaitTime = 45 },
		BlackHole = { Enabled = true, MinPrice = 2000, MaxPrice = 3999,      WaitTime = 45 },
		Starfall  = { Enabled = true, MinPrice = 4000, MaxPrice = 999999999, WaitTime = 50 },
	},

	-- Nominal donasi Saweria (Rp)
	SAWERIA_TIERS = {
		Nuke      = { Enabled = true, MinPrice = 10000,  MaxPrice = 49999,     WaitTime = 40 },
		Smite     = { Enabled = true, MinPrice = 50000,  MaxPrice = 199999,    WaitTime = 45 },
		BlackHole = { Enabled = true, MinPrice = 200000, MaxPrice = 499999,    WaitTime = 45 },
		Starfall  = { Enabled = true, MinPrice = 500000, MaxPrice = 999999999, WaitTime = 50 },
	},
}

return MegaEffectsConfig
