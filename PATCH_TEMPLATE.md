# PATCH vX.Y.Z

## Ringkasan

Jelaskan bug/fitur yang diperbaiki dalam 1-3 kalimat.

## Versi

- Core: `vX.Y.Z`
- Config schema: `X`
- Content: `vX.Y.Z`
- Tanggal:

## File Core yang diganti

```text
Path lengkap 1
Path lengkap 2
```

## File yang TIDAK boleh ditimpa

- `PrivateConfig`
- `GameConfig`
- `AssetConfig`
- `DonationConfig`
- `MegaEffectsConfig`
- `MusicModule`
- `AnimationRegistry`
- map
- GUI
- `Kohl's Admin`

## Perubahan config

- [ ] Tidak ada
- [ ] Ada (jelaskan langkah migrasi di bawah)

```lua
-- contoh penambahan key
```

## Dependency

- [ ] Tidak ada
- [ ] Ada (sebutkan patch yang harus dipasang lebih dulu)

## Cara memasang

1. Backup place.
2. Ganti hanya file Core di daftar.
3. Jangan sentuh config/map/GUI.
4. Jalankan `SetupValidator`.
5. Test.

## Testing

- [ ] Compile seluruh script
- [ ] Studio Play
- [ ] Buyer template
- [ ] Patch dari versi sebelumnya
- [ ] Config/map/GUI tidak berubah
- [ ] Music/animation
- [ ] Donation/VIP
- [ ] Mobile

## Checksum

```text
SHA256 file:
```
