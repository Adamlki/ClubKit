-- ====================================
-- SERVER LOGGER MODULE
-- ====================================
local Config = require(script.Parent.Config)

local Logger = {}

function Logger:Debug(message)
	if Config.Debug then
		print("[GamepassShop] 🔍", message)
	end
end

function Logger:Info(message)
	if Config.Debug then
		print("[GamepassShop] ℹ️", message)
	end
end

function Logger:Success(message)
	if Config.Debug then
		print("[GamepassShop] ✅", message)
	end
end

function Logger:Warn(message)
	warn("[GamepassShop] ⚠️", message)
end

function Logger:Error(message)
	warn("[GamepassShop] ❌", message)
end

function Logger:Transaction(message)
	if Config.Debug then
		print("[GamepassShop] 💰", message)
	end
end

return Logger