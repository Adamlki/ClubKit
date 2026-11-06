# SETUP PEMBELI — ClubKit

Dokumen ini untuk pembeli place. Jangan publish sebelum semua langkah selesai.

## Aturan penting

- **Buyer wajib mengedit Config dan Content** untuk mengisi ID, map, GUI, sound, dan animation miliknya.
- **Buyer jangan mengedit Core** kecuali benar-benar paham; patch update dari penjual hanya menyentuh Core.
- **Penjual tidak boleh menimpa Config/Content** milik buyer saat mengirim update.
- Semua update dikirim sebagai patch Core, bukan copy place penuh.
- Versi Core ada di `ReplicatedStorage.Config.BuildInfo`.
- Jangan mengubah `BuildInfo.DEV_BY` atau `BuildInfo.DEV_LABEL`; build akan diblokir. Atribusi wajib tetap `dev by jekychen`.

## 1. File konfigurasi utama

| File | Isi |
|---|---|
| `ServerStorage.Modules.PrivateConfig` | Owner/Admin/Moderator, GroupId, GamePass, Developer Product, Webhook Saweria, prefix DataStore |
| `ReplicatedStorage.Config.GameConfig` | GroupId publik dan branding |
| `ReplicatedStorage.Config.AssetConfig` | Sound, icon, image, animation pendukung |
| `ServerScriptService.DonationSystem.DonationServerHandler.DonationConfig` | Produk donasi dan harga |
| `ServerScriptService.EffectDonationSaweria.MegaEffectsConfig` | Tier dan efek donasi |
| `ServerScriptService.AdminNotif.AdminNotifServer.AdminNotifConfig` | Role dan cooldown broadcast admin |
| `ReplicatedStorage.OverheadShared.Config` | Nama DataStore overhead, ukuran nama, rank |
| `StarterPlayerScripts.ClientConfig` | Pesan chat dan tampilan donasi |

Template `PrivateConfig.example.lua` ada di `ServerStorage.Modules`.
Salin isinya ke `PrivateConfig`, lalu ganti semua nilai placeholder.

**Jangan memakai `PrivateConfig` milik penjual.** File itu berisi Owner ID, GamePass/Product ID, dan URL Saweria penjual.

### Versi config

`PrivateConfig.ConfigSchema` harus sama dengan `ReplicatedStorage.Config.BuildInfo.CONFIG_SCHEMA`.
Kalau berbeda, `SetupValidator` akan memberi warning. Ikuti panduan migrasi dari penjual; jangan menyalin config lama begitu saja.

## 2. Wajib diganti

### Owner dan admin

- `PrivateConfig.OwnerIds` → UserId pembeli.
- `PrivateConfig.AdminIds` → UserId admin pembeli.
- `PrivateConfig.ModeratorIds` → UserId moderator pembeli.
- `PrivateConfig.GroupId` → GroupId komunitas pembeli.
- `GameConfig.GroupId` → **harus sama** dengan `PrivateConfig.GroupId`.

Kalau GroupId tidak sama, script akan memberi warning saat server start.

### Gamepass dan Developer Product

- `PrivateConfig.GamePasses.VIP`
- `PrivateConfig.ActiveGamepasses.VIP`
- `PrivateConfig.GiftProducts.VIP`
- `DonationConfig.PRODUCTS` (9 produk donasi)
- Harga di `DonationConfig.PRODUCTS` harus sama dengan harga di Creator Hub.
- Tier `MegaEffectsConfig` harus disesuaikan dengan harga produk pembeli.

#### Kebijakan Regional Pricing (Creator Hub)
Sistem Gift VIP ClubKit memakai **Roblox Price Levels API (`MarketplaceService:GetUsersPriceLevelsAsync`)** untuk mencegah arbitrase harga regional. Server membandingkan price level pengirim dan penerima sebelum prompt. Jika level pengirim lebih rendah dari penerima, gift diblokir sebelum pembelian. Server juga **memverifikasi ulang saat receipt**; jika verifikasi saat receipt gagal, pass tidak dikirim ke penerima dan diberikan ke pembeli agar pembelian tidak menggantung.

- Di pop-up Creator Hub *"Protect your revenue"*:
  - Pilih **"My experience implements the appropriate checks"** jika `PrivateConfig.Features.VIPGiftEnabled = true` **dan** `PrivateConfig.GiftProducts.VIP` sudah diisi dengan Developer Product yang benar. Opsi ini adalah deklarasi bahwa check benar-benar aktif; pastikan tidak ada sistem trading/gifting lain yang belum memakai check.
  - Pilih **"My experience does not allow trading or gifting"** jika `VIPGiftEnabled = false`. Tombol gift disembunyikan dan server menolak `PromptGift`. Sebaiknya Developer Product gift juga dinonaktifkan di Creator Hub agar tidak bisa dipicu langsung oleh client.
- Jangan klaim "100% bebas sanksi"; pop-up ini adalah perlindungan revenue, bukan jaminan. Yang penting jawaban sesuai kondisi riil.
- Uji di published place dengan dua akun. Di Studio pengecekan dilewati agar testing offline tidak error, jadi perilaku production tidak terlihat di Studio.

### Saweria

- `PrivateConfig.SaweriaWebhookURL` → URL Apps Script pembeli.
- Buat Google Sheet dan Apps Script sendiri.
- Deploy Apps Script dengan **Manage deployments → New version**, lalu pakai URL `/exec`.
- Jangan memakai URL atau secret milik penjual.
- Jika belum memakai Saweria, kosongkan URL dan matikan fitur terkait.

### DataStore

- `PrivateConfig.DataStorePrefix` → nama unik, misalnya `NamaGame_`.
- Semua DataStore yang memakai `DataStoreEnv` otomatis memakai prefix ini.
- DataStore yang tidak memakai `DataStoreEnv` harus diganti manual:
  - `DonationConfig.DATASTORE.NAME`
  - `OverheadShared.Config.TITLE_DATASTORE_NAME`
  - `OverheadShared.Config.DONATION_DATASTORE_NAME`
  - `OverheadShared.Config.DONATUR_RANK_DATASTORE_NAME`
  - `ServerListManager` MemoryStore
  - `AntiAFK` MemoryStore
  - Kohl's Admin `_KData`

## 3. Nama yang tidak boleh diubah sembarangan

Script mencari nama instance berikut. Kalau pembeli mengganti nama, script harus ikut diubah.

### StarterGui

- `PlayerMenuHandler`
- `SettingGui`
- `MusicPlayer`
- `EmoteGui`
- `SaweriaDonationGui`
- `GamepassShop`
- `DonationBoard`
- `AdminPanel`
- `Level4Donation`
- `CarryGui`
- `MyHat`
- `CustomTitleGui`
- `NotifSaweriaGui`

### Workspace

- `Leaderboard` (isi: `JekyLevelBoard`, `JekyLikeBoard`, `BoardSaweria`, `JekyDonationBoard`)
- `StageEffects`
- `ActiveEffects`
- `ScreenText`
- `Kohl's Admin`
- `DonatorPositions` / statue top donatur

### ServerStorage / ReplicatedStorage

- `ServerStorage.Items` (tool: AFK, Glowstick, Heart, Mawar, Sharky, Umbrella, WaterGun)
- `ReplicatedStorage.UI`
- `ReplicatedStorage.Emotes`
- `ReplicatedStorage.Sounds`
- `ReplicatedStorage.VFX`
- `ReplicatedStorage.Modules`

## 4. Sound, animation, dan image

- `AssetConfig.Sounds` → sound notifikasi, backpack, Saweria.
- `AssetConfig.Images` → icon topbar, admin, donasi, banner, badge.
- `AssetConfig.Animations` → animasi fly/float/top donatur.
- `AnimationRegistry` berisi ratusan animation ID. Ganti hanya jika pembeli punya lisensi/akses.
- `MusicModule` berisi ratusan sound ID dan album cover. Ganti jika tidak punya lisensi.
- Animation/sound di dalam `ServerStorage.Items` dan `ReplicatedStorage.Emotes` harus dicek satu per satu karena berada di place, bukan di repo.
- Jangan menjual ulang animation/music/asset yang lisensinya tidak mengizinkan redistribusi.

## 5. Branding

Ubah di:

- `GameConfig.Branding`
  - `GameName`
  - `GroupName`
  - `WelcomeMessage`
  - `DonationWelcome`
  - `ScreenBoardName`
  - `ScreenBoardMessage`

Cek juga teks lama yang masih memakai `RASA NADA` atau `DMS STUDIO`.

## 6. Kohl's Admin

- Ganti konfigurasi owner/admin di folder `Workspace.Kohl's Admin`.
- Ganti DataStore `_KData` jika perlu.
- Pastikan pembeli berhak mendistribusikan ulang Kohl's Admin.
- Jangan biarkan Owner ID penjual ada di konfigurasi admin.

## 7. Test sebelum publish

1. Server start tanpa warning `[SETUP]`.
2. Owner bisa membuka AdminPanel; player biasa tidak bisa.
3. Group VIP bekerja untuk member group pembeli.
4. Gamepass VIP dan gift product menghasilkan revenue ke pembeli.
5. Donation Robux: 9 produk, harga, broadcast, leaderboard.
6. Saweria: webhook, notifikasi, top donatur, screen board.
7. Music: play, queue, favorite, album cover.
8. Emote/dance: tidak ada animation yang private/error.
9. Backpack, topbar, setting, whisper, carry, watergun.
10. DataStore: cek data baru masuk ke prefix pembeli.
11. Test di HP dan PC.
12. Publish, lalu test di server live (bukan hanya Studio).

## 8. Catatan penjualan

Place yang sudah dibeli tidak bisa otomatis menerima update dari place master. Untuk update:

- kirim patch/package terpisah, atau
- gunakan hosted experience, atau
- minta pembeli mengimpor package Core/Config/Content secara manual.

Jangan publish place master di atas place yang sudah diedit pembeli.
