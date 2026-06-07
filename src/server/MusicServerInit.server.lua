local ServerStorage = game:GetService("ServerStorage")
local MusicSystem = require(ServerStorage.Modules.MusicSystem.MusicSystem)

-- Start the system
local musicSystem = MusicSystem.new()
musicSystem:Start()