-- ========================================================
-- TEMPLATE PrivateConfig
-- ========================================================
-- CARA PAKAI:
-- 1. Copy file ini menjadi: src/serverStorage/Modules/PrivateConfig.lua
-- 2. Isi semua nilai di bawah dengan data asli (OwnerIds, GamePasses, SaweriaWebhookURL, dll)
-- 3. JANGAN commit PrivateConfig.lua — file aslinya sudah masuk .gitignore
--
-- Catatan: PrivateConfig.lua asli TIDAK ikut git, jadi di clone baru file ini
-- wajib dibuat ulang dari template. Rojo akan gagal sync jika file aslinya tidak ada.

local PrivateConfig = {
    OwnerIds = {0}, -- ganti dengan UserId owner (angka Roblox)
    AdminIds = {},
    ModeratorIds = {},
    GroupId = 0,

    -- Gamepasses
    GamePasses = {
        VIP = {0, 0} -- {GamePassIdPrimary, GamePassIdSecondary}
    },
    GiftProducts = {
        VIP = 0, -- Developer Product Id untuk gift VIP
    },
    ActiveGamepasses = {
        VIP = 0
    },

    -- API Credentials
    SaweriaWebhookURL = "PASTE_YOUR_SAWERIA_WEBHOOK_URL_HERE"
}

return PrivateConfig
