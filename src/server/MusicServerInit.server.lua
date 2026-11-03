local ServerStorage = game:GetService("ServerStorage")
local MusicSystem = require(ServerStorage.Modules.MusicSystem.MusicSystem)

-- Start the system
local musicSystem = MusicSystem.new()
-- Instance tetap dapat diakses lewat module, bukan global _G/shared.
MusicSystem.Instance = musicSystem
musicSystem:Start()