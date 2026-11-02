local TopbarPanelRegistry = {}
local closers = {}

function TopbarPanelRegistry:Register(name, closeFn)
	if type(name) == "string" and type(closeFn) == "function" then
		closers[name] = closeFn
	end
end

function TopbarPanelRegistry:Unregister(name)
	closers[name] = nil
end

function TopbarPanelRegistry:CloseOthers(exceptName)
	for name, closeFn in pairs(closers) do
		if name ~= exceptName then
			pcall(closeFn)
		end
	end
end

return TopbarPanelRegistry
