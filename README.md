# ClubKit

Roblox club experience. The place file itself is not stored in this repository;
the game is edited in Roblox Studio and synced to Rojo-managed script folders.

## Prerequisites

- [Rojo](https://rojo.space/) 7.7+
- [Aftman](https://github.com/LPGhatguy/aftman)

## Private configuration

`PrivateConfig.lua` contains owner IDs, gamepass/product IDs, and the Saweria
webhook URL. It is intentionally ignored by git.

1. Copy `PrivateConfig.example.lua` to `src/serverStorage/Modules/PrivateConfig.lua`.
2. Fill in the real values.
3. Never commit the filled-in file. If the Saweria URL was ever committed,
   rotate it in the Google Apps Script deployment.

## Buyer setup

If this place is sold as a copy, read `SETUP.md` before publishing. The buyer
must update:

- `ServerStorage.Modules.PrivateConfig` — owner, group, gamepasses, products,
  DataStore prefix, Saweria webhook.
- `ReplicatedStorage.Config.GameConfig` — public group ID and branding.
- `ReplicatedStorage.Config.AssetConfig` — sound, image, and animation IDs.

`ServerScriptService.SetupValidator` prints warnings when required values or
instances are missing.

## DataStore in Studio

Studio uses **live DataStores for reads** so leaderboards, levels, likes, titles,
donation boards, and similar data match the live server. Writes made in Studio
are redirected by `ServerStorage.Modules.DataStoreEnv` to
`<name>_StudioWrite_v1`; they do not overwrite live player data. The gift-intent
store is intentionally kept separate because it contains pending purchases.

## Build / sync

```bash
rojo build -o "ClubKit.rbxlx"
rojo serve
```

> Important: the map, GUI layouts, effects, tools in `ServerStorage.Items`, and
> several Studio-only scripts live only in the Studio place. A plain `rojo build`
> from this repository will not reproduce the complete experience until those
> assets are exported into the project.
