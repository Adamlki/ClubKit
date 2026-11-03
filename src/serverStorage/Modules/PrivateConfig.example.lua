-- TEMPLATE UNTUK PEMBELI.
-- Salin file ini menjadi PrivateConfig.lua, lalu isi semua nilai dengan milik pembeli.
-- Jangan pernah memakai OwnerIds, GroupId, GamePass, Product, atau SaweriaWebhookURL milik penjual.
local PrivateConfig = {
    -- ID pemilik experience (bukan ID penjual).
    OwnerIds = {0},

    -- ID admin/moderator tambahan. Boleh kosong.
    AdminIds = {},
    ModeratorIds = {},

    -- ID grup komunitas pembeli. Harus sama dengan GameConfig.GroupId.
    GroupId = 0,

    -- Versi skema config. Jangan ubah kecuali mengikuti migrasi Core.
    ConfigSchema = 1,

    -- Awalan DataStore. Gunakan nama unik, misalnya "NamaGame_".
    DataStorePrefix = "BuyerGame_",

    Features = {
        VIPShopEnabled = false,
        VIPGiftEnabled = false,
        CommunityVIPEnabled = true,
    },

    -- Gamepass yang dimiliki pembeli. Ganti semua ID 0.
    GamePasses = {
        VIP = {0}
    },
    GiftProducts = {
        VIP = 0,
    },
    ActiveGamepasses = {
        VIP = 0
    },

    -- URL Apps Script Saweria milik pembeli.
    -- Biarkan kosong jika fitur Saweria belum dipakai.
    SaweriaWebhookURL = "",
}

return PrivateConfig
