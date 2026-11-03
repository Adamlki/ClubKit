--!optimize 2

-- Registry debug/test hooks server-only.
-- Menggantikan _G untuk hook debug agar tidak ada akses nil dan mudah dilacak.
local DebugHooks = {}
local hooks = {}

function DebugHooks.Register(name: string, callback)
	if type(name) ~= "string" or name == "" then
		return false, "nama hook tidak valid"
	end
	if type(callback) ~= "function" then
		return false, "callback harus function"
	end
	hooks[name] = callback
	return true
end

function DebugHooks.Has(name: string): boolean
	return hooks[name] ~= nil
end

function DebugHooks.Get(name: string)
	return hooks[name]
end

function DebugHooks.Call(name: string, ...: any)
	local callback = hooks[name]
	if not callback then
		return false, "debug hook belum terdaftar: " .. tostring(name)
	end

	local ok, result = pcall(callback, ...)
	if not ok then
		warn("[DebugHooks] " .. tostring(name) .. " error: " .. tostring(result))
		return false, result
	end
	return true, result
end

return DebugHooks
