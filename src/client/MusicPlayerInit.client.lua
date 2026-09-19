local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MusicPlayer = require(ReplicatedStorage.Modules.ClientModules.MusicPlayer)

-- Inisialisasi Music Player client menggunakan GUI dari PlayerGui (StarterGui)
local musicPlayer = MusicPlayer.new()