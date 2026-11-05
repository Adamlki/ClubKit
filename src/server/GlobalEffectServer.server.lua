local GlobalEffectManager = require(script.Parent:WaitForChild("Modules"):WaitForChild("GlobalEffect"):WaitForChild("GlobalEffectManager"))

local manager = GlobalEffectManager.new()
manager:Init()

print("[OOP] Global Effect Server Initialized.")
