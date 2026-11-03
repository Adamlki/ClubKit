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

## Catatan

- Nomor versi Core dinaikkan untuk setiap rilis patch.
- `CONFIG_SCHEMA` hanya dinaikkan jika buyer wajib melakukan migrasi config.
- Perubahan lagu, animation, map, atau GUI masuk sebagai content patch.
