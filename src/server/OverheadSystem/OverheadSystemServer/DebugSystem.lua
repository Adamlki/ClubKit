local DebugSystem = {}
local isEnabled = false

function DebugSystem:Init(enabled)
	isEnabled = enabled
end

function DebugSystem:Log(...)
	if isEnabled then
		print("[OverheadSystem]", ...)
	end
end

function DebugSystem:Warn(...)
	if isEnabled then
		warn("[OverheadSystem]", ...)
	end
end

return DebugSystem