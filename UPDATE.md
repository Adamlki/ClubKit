# UPDATE GUIDE - ClubKit

Panduan ini untuk penjual/master project. Tujuannya agar update Core tidak
menimpa config, map, GUI, atau konten milik pembeli.

## 1. Aturan utama

- **Buyer** mengedit Config dan Content miliknya.
- **Seller** mengupdate Core.
- **Patch Core tidak boleh menyertakan Config atau Content.**
- Jangan pernah mengirim ulang full place ke pembeli yang sudah punya place.
- Jangan pernah mengirim `PrivateConfig` asli milik pembeli/seller.

Kalimat "file tidak boleh disentuh" berarti **tidak boleh ditimpa oleh patch
update dari seller**, bukan berarti buyer tidak boleh mengeditnya.

## 2. Pembagian file

### Core - seller yang update

Semua script perilaku yang tidak berisi ID pembeli, contoh:

- `ServerScriptService` sistem: level, music, donation, carry, watergun,
  leaderboard, overhead, saweria server, role, remote, dll.
- `ServerStorage` module sistem: `LevelSystem`, `RoleSystem`, `LikeManager`,
  `DataStoreEnv`, `MusicSystem`, `SaweriaAPI`, dll.
- `ReplicatedStorage` module sistem: `CameraLease`, `CarryConfig`,
  `TopbarPanelRegistry`, `Utils`, `BridgeNet`, dll.
- `StarterPlayerScripts` dan `StarterGui` script perilaku.
- `ReplicatedStorage.Config.BuildInfo` - versi core dan atribusi developer.
- `ServerScriptService.BuildEnforcement` - guard atribusi build.

### Atribusi developer

`ReplicatedStorage.Config.BuildInfo` wajib berisi:

```lua
DEV_BY = "jekychen"
DEV_LABEL = "dev by jekychen"
```

`GameConfig` dan `ServerScriptService.BuildEnforcement` memeriksa nilai ini.
Kalau `BuildInfo` diubah, build akan error dan player ditolak. Ini guard
atribusi, bukan enkripsi absolut: buyer yang menghapus guard tetap bisa
memodifikasi place. Untuk proteksi penuh, gunakan hosted experience.

Jangan mengubah `DEV_BY`/`DEV_LABEL` saat membuat patch Core. File `BuildInfo`
dan `BuildEnforcement` harus tetap membawa atribusi `dev by jekychen`.

### Config - buyer yang edit

- `ServerStorage.Modules.PrivateConfig`
- `ReplicatedStorage.Config.GameConfig`
- `ReplicatedStorage.Config.AssetConfig`
- `ServerScriptService.DonationSystem.DonationServerHandler.DonationConfig`
- `ServerScriptService.EffectDonationSaweria.MegaEffectsConfig`
- `ServerScriptService.AdminNotif.AdminNotifServer.AdminNotifConfig`
- `ServerScriptService.Gamepass.MainServer.Config`
- `ReplicatedStorage.OverheadShared.Config`
- `StarterPlayerScripts.ClientConfig`
- `ServerStorage.Modules.PrivateConfig.example` (template, jangan diisi data asli)

Jika buyer mengubah file config, seller tidak boleh mengirim versi baru yang
menimpa nilai mereka. Kirim migrasi/instruksi, bukan file penuh.

### Content - buyer/map yang punya

- Map di `Workspace`
- GUI di `StarterGui`
- `ServerStorage.Items`
- `ReplicatedStorage.Emotes`
- `ReplicatedStorage.Sounds`
- `ReplicatedStorage.UI`
- `ReplicatedStorage.VFX`
- `ReplicatedStorage.Modules.MusicModule`
- `ReplicatedStorage.Modules.AnimationRegistry`
- `Workspace.Kohl's Admin` (vendor/pihak ketiga)

Content patch dikirim terpisah dan bersifat opsional. Jangan paksa menimpa
music/animation/map yang sudah dikustom pembeli.

## 3. Versi

`ReplicatedStorage.Config.BuildInfo` berisi:

```lua
CORE_VERSION = "1.0.0"
CONFIG_SCHEMA = 1
CONTENT_VERSION = "1.0.0"
```

- Naikkan `CORE_VERSION` setiap rilis Core.
- Naikkan `CONFIG_SCHEMA` hanya jika format config berubah dan buyer wajib
  melakukan migrasi.
- Naikkan `CONTENT_VERSION` untuk patch lagu/animation/GUI/map.
- Jangan ubah `BuildInfo` dari config pembeli.

`SetupValidator` akan menampilkan versi dan memberi warning jika
`PrivateConfig.ConfigSchema` tidak cocok.

## 4. Format paket patch

Gunakan folder rilis, bukan file lepas tanpa keterangan:

```text
ClubKit_Update_v1.1.0/
  README.md
  CHANGELOG.md
  MANIFEST.txt
  Core/
    ServerScriptService/
      ...
    ServerStorage/
      ...
    ReplicatedStorage/
      ...
  Config/
    Config.example.lua
  Content/
    (opsional, hanya jika buyer mau)
```

`MANIFEST.txt` minimal berisi:

```text
Version: 1.1.0
ConfigSchema: 1
Tanggal: 2026-11-03

File Core yang diganti:
- ServerStorage.Modules.LevelSystem
- ServerScriptService.GetPlayerInfoServer

File yang TIDAK boleh ditimpa:
- PrivateConfig
- GameConfig
- AssetConfig
- DonationConfig
- MegaEffectsConfig
- MusicModule
- AnimationRegistry
- map
- GUI
- Kohl's Admin

Perubahan config:
- Tidak ada

Test:
- Studio Play
- Buyer template
- Patch dari v1.0.0
```

## 5. Patch satu script

Untuk perbaikan kecil, satu script boleh dikirim, tetapi tetap harus jelas:

```text
Patch: v1.1.1
File: ServerStorage.Modules.MusicSystem.MusicPlaybackManager
Path: src/serverStorage/Modules/MusicSystem/MusicPlaybackManager.lua
Dependency: tidak ada
Config berubah: tidak
Test: music play, queue, favorite
```

Jangan hanya mengirim `fix.lua` tanpa path dan versi.

Jika satu perbaikan menyentuh beberapa file yang saling bergantung, kirim
sebagai satu paket. Jangan memecah dependency ke beberapa pesan.

## 6. Migrasi config

Jika Core membutuhkan key config baru:

1. Tambahkan nilai default di Core agar config lama tetap jalan.
2. Update `PrivateConfig.example` atau contoh config terkait.
3. Kirim instruksi migrasi ke buyer.
4. Jangan mengirim `PrivateConfig` pembeli.

Contoh:

```text
Tambahkan di PrivateConfig:

Features.NewFeatureEnabled = true
ConfigSchema = 2
```

Jika perubahan tidak kompatibel:

- naikkan `CONFIG_SCHEMA`,
- beri panduan langkah demi langkah,
- minta buyer backup place sebelum migrasi.

## 7. Content patch

Content patch terpisah dari Core:

- lagu baru di `MusicModule`,
- animation baru di `AnimationRegistry`,
- GUI/map baru,
- sound/icon baru.

Buyer boleh menolak content patch jika sudah punya kustomisasi sendiri.

Jangan mengirim content patch yang menimpa map/GUI pembeli tanpa persetujuan.

## 8. Map varian

Jika ada beberapa map:

- semua map memakai Core yang sama,
- nama instance penting harus sama,
- config tetap milik masing-masing pembeli,
- patch Core berlaku untuk semua map,
- script khusus Workspace harus dicatat di manifest map.

Contoh nama yang harus stabil:

- `Workspace.Leaderboard`
- `Workspace.StageEffects`
- `Workspace.ActiveEffects`
- `Workspace.ScreenText`
- `ServerStorage.Items`
- `StarterGui.PlayerMenuHandler`
- `StarterGui.MusicPlayer`
- `StarterGui.SaweriaDonationGui`

## 9. Testing sebelum kirim

1. Terapkan patch ke master place.
2. Compile seluruh script.
3. Play di Studio, cek output error/warning.
4. Terapkan patch ke buyer template dengan config kosong.
5. Terapkan patch dari versi sebelumnya, bukan hanya build baru.
6. Pastikan config/map/GUI buyer tidak berubah.
7. Test dua map jika ada lebih dari satu.
8. Test music, animation, donation, VIP, admin, carry, watergun.
9. Test di HP.
10. Catat versi yang dikirim ke tiap buyer.

## 10. Larangan

- Jangan kirim full master place sebagai update.
- Jangan kirim `PrivateConfig` pembeli.
- Jangan menimpa `GameConfig`, `AssetConfig`, map, GUI, atau music pembeli.
- Jangan obfuscate `Kohl's Admin` atau library pihak ketiga.
- Jangan mengandalkan update otomatis dari dalam game.
- Jangan menjanjikan proteksi copy tanpa hosted experience.
