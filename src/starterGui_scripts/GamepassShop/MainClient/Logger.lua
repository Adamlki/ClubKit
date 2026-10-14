-- ====================================
-- CLIENT LOGGER MODULE
-- ====================================
local Config = require(script.Parent:WaitForChild("Config"))

local Logger = {}

function Logger:Debug(message)
	if Config.Debug then
		print("[GamepassClient] 🔍", message)
	end
end

function Logger:Info(message)
	if Config.Debug then
		print("[GamepassClient] ℹ️", message)
	end
end

function Logger:Success(message)
	if Config.Debug then
		print("[GamepassClient] ✅", message)
	end
end

function Logger:Warn(message)
	warn("[GamepassClient] ⚠️", message)
end

function Logger:Error(message)
	warn("[GamepassClient] ❌", message)
end

return Logger
