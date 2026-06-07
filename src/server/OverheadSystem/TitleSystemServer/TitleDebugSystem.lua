local DebugSystem = {}
local isEnabled = false

function DebugSystem:Init(enabled)
	isEnabled = enabled
end

function DebugSystem:Log(...)
	if isEnabled then
		print("[TitleSystem]", ...)
	end
end

function DebugSystem:Warn(...)
	if isEnabled then
		warn("[TitleSystem]", ...)
	end
end

return DebugSystem