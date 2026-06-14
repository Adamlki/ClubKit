local GlobalEffectManager = require(script.Parent:WaitForChild("Modules"):WaitForChild("GlobalEffect"):WaitForChild("GlobalEffectManager"))

-- Inisialisasi sistem dengan pendekatan OOP
local manager = GlobalEffectManager.new()
manager:Init()

print("[OOP] Global Effect Server Initialized.")
