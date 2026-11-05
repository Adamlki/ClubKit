local ServerStorage = game:GetService("ServerStorage")
local MusicSystem = require(ServerStorage.Modules.MusicSystem.MusicSystem)

local musicSystem = MusicSystem.new()
MusicSystem.Instance = musicSystem
musicSystem:Start()
