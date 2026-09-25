-- ============================================================
-- MEGA EFFECTS CONFIGURATION (ROBUX & SAWERIA)
-- Mengatur toggle On/Off dan ambang batas donasi untuk efek 3D panggung:
-- - Nuke      : Roket Nuklir dari langit
-- - Smite     : Palu Raksasa & Clone Avatar 53x
-- - BlackHole : Black Hole Kosmik
-- - Starfall  : Winged Giant
-- ============================================================

local MegaEffectsConfig = {
	-- ============================================================
	-- 1. MASTER TOGGLE
	-- Set false untuk mematikan SEMUA efek besar panggung (misal saat event/lag)
	-- ============================================================
	GLOBAL_ENABLED = true,

	-- ============================================================
	-- 2. TOGGLE PER SUMBER DONASI
	-- Mengontrol apakah donasi Robux atau Saweria boleh memicu efek panggung
	-- ============================================================
	ROBUX_ENABLED   = true, -- Aktifkan efek panggung untuk donasi Robux
	SAWERIA_ENABLED = true, -- Aktifkan efek panggung untuk donasi Saweria

	-- ============================================================
	-- 3. TOGGLE PER JENIS EFEK (ON / OFF)
	-- Set false pada salah satu efek untuk menonaktifkannya
	-- ============================================================
	EFFECTS_ENABLED = {
		Nuke      = true, -- Efek Roket Nuklir dari langit
		Smite     = true, -- Efek Palu Raksasa & Clone Avatar
		BlackHole = true, -- Efek Black Hole Kosmik
		Starfall  = true, -- Efek Starfall Winged Giant
	},

	-- ============================================================
	-- 4. PENGATURAN TIER ROBUX (R$)
	-- Nominal batas bawah dan batas atas untuk memicu tiap efek
	-- Support 6 (500 R$)  -> Nuke
	-- Support 7 (1000 R$) -> Smite
	-- Support 8 (2500 R$) -> BlackHole
	-- Support 9 (5000 R$) -> Starfall
	-- ============================================================
	ROBUX_TIERS = {
		Nuke = {
			Enabled  = true,
			MinPrice = 500,
			MaxPrice = 999,
			WaitTime = 40, -- Jeda antrean (detik) sesuai durasi efek panggung
		},
		Smite = {
			Enabled  = true,
			MinPrice = 1000,
			MaxPrice = 2499,
			WaitTime = 45,
		},
		BlackHole = {
			Enabled  = true,
			MinPrice = 2500,
			MaxPrice = 4999,
			WaitTime = 45,
		},
		Starfall = {
			Enabled  = true,
			MinPrice = 5000,
			MaxPrice = 999999999,
			WaitTime = 50,
		},
	},

	-- ============================================================
	-- 5. PENGATURAN TIER SAWERIA (Rp)
	-- Nominal batas bawah dan batas atas untuk donasi Saweria
	-- Sesuai dengan command /saweria:
	-- 10k - 49k   -> Nuke
	-- 50k - 199k  -> Smite (Palu Raksasa & Clone Avatar)
	-- 200k - 499k -> Black Hole
	-- >= 500k     -> Starfall (Winged Giant)
	-- ============================================================
	SAWERIA_TIERS = {
		Nuke = {
			Enabled  = true,
			MinPrice = 10000,
			MaxPrice = 49999,
			WaitTime = 40,
		},
		Smite = {
			Enabled  = true,
			MinPrice = 50000,
			MaxPrice = 199999,
			WaitTime = 45,
		},
		BlackHole = {
			Enabled  = true,
			MinPrice = 200000,
			MaxPrice = 499999,
			WaitTime = 45,
		},
		Starfall = {
			Enabled  = true,
			MinPrice = 500000,
			MaxPrice = 999999999,
			WaitTime = 50,
		},
	},
}

return MegaEffectsConfig
