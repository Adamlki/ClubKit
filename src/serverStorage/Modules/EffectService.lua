--!optimize 2

local EffectService = {}
local handlers = {}

function EffectService.Register(name: string, callback)
	if type(name) ~= "string" or name == "" or type(callback) ~= "function" then
		return false, "effect handler tidak valid"
	end
	handlers[name] = callback
	return true
end

function EffectService.Has(name: string): boolean
	return handlers[name] ~= nil
end

function EffectService.Get(name: string)
	return handlers[name]
end

function EffectService.Call(name: string, ...: any)
	local callback = handlers[name]
	if not callback then
		return false, "effect belum terdaftar: " .. tostring(name)
	end

	local ok, result = pcall(callback, ...)
	if not ok then
		warn("[EffectService] " .. tostring(name) .. " error: " .. tostring(result))
		return false, result
	end
	return true, result
end

return EffectService
