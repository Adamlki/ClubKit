local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MusicPlayer = require(ReplicatedStorage.Modules.ClientModules.MusicPlayer)

-- ✅ PERBAIKAN: Jangan menunggu CharacterAdded atau task.wait()!
-- Langsung inisialisasi agar tidak ketinggalan data dari Server
local musicPlayer = MusicPlayer.new()