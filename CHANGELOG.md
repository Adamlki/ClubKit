# Changelog - ClubKit

## 1.0.0 - 2026-11-03

- Menambahkan `BuildInfo` untuk versi Core, schema config, dan versi content.
- Menambahkan validasi `ConfigSchema` di `SetupValidator`.
- Menambahkan `UPDATE.md` untuk alur update Core/Config/Content.
- Menambahkan `PATCH_TEMPLATE.md` untuk format patch penjual.
- Memisahkan aturan buyer-owned config/content dari Core yang di-update penjual.
- Menambahkan atribusi `dev by jekychen` di `BuildInfo`.
- Menambahkan guard `BuildEnforcement` yang memblokir build jika atribusi diubah.
- Fix `LikeLeaderboard` agar membaca ordered likes lewat `DataStoreEnv`; prefix buyer sekarang konsisten dengan `LikeManager`.
- Phase 1 refactor `_G`: debug/config hooks dipindahkan ke `DebugHooks`; referensi `_G` turun dari 134 ke 103.
- Phase 2 refactor `_G`: client flags/actions dipindahkan ke `ClientState`; referensi `_G` turun dari 103 ke 58.
- Phase 3 refactor `_G`: leaderboard controller/callback/data dipindahkan ke `LeaderboardRegistry`; referensi `_G` turun dari 58 ke 32.
- Phase 4 refactor `_G`: stage/Robux effects dipindahkan ke `EffectService`; referensi `_G` turun dari 32 ke 16.
- Phase 5–6 refactor `_G`: `MusicSystem.Instance`, `ChatBadgeSystem` dibersihkan, singleton guard pindah ke `ScriptOnce`; referensi `_G` menjadi 0.
- Arsitektur Dance Sync Snapshot (`0c8bf7c`): Modul `DanceState`, format snapshot atomik (`animationId|anchorTime|anchorPosition|speed|restartSeq|version`), transisi dance mulus tanpa jeda freeze/T-pose, slider speed 1:1 tanpa lerp/snap TimePosition, PLL micro-speed drift correction, local leader mirror zero-delay, dan rate limiter dinaikkan ke 30–40 Hz.
- Pembersihan komentar codebase: Pemangkasan 1.326 baris komentar tidak penting / bernuansa AI dari 118 script fungsional non-config, proteksi direktif kompiler Luau (`--!native`, `--!optimize 2`, `--!strict`), preservasi 100% petunjuk konfigurasi pada 15 script config, dan verifikasi build Rojo bersih.

## Catatan

- Nomor versi Core dinaikkan untuk setiap rilis patch.
- `CONFIG_SCHEMA` hanya dinaikkan jika buyer wajib melakukan migrasi config.
- Perubahan lagu, animation, map, atau GUI masuk sebagai content patch.
