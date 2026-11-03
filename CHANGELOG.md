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

## Catatan

- Nomor versi Core dinaikkan untuk setiap rilis patch.
- `CONFIG_SCHEMA` hanya dinaikkan jika buyer wajib melakukan migrasi config.
- Perubahan lagu, animation, map, atau GUI masuk sebagai content patch.
