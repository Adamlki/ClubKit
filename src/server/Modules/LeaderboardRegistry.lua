--!optimize 2

type UpdateCallback = () -> ()

local LeaderboardRegistry = {}

local handlers: { [string]: UpdateCallback } = {}
local controllers: { [string]: any } = {}
local dataCache: { [string]: any } = {}

--- Daftarkan handler pembaruan leaderboard
function LeaderboardRegistry.register(category: string, callback: UpdateCallback)
	handlers[category] = callback
end

--- Daftarkan controller manual (mis. Robux GetData/Refresh)
function LeaderboardRegistry.setController(category: string, controller: any)
	controllers[category] = controller
end

function LeaderboardRegistry.getController(category: string)
	return controllers[category]
end

--- Cache data leaderboard terakhir untuk overhead/notifier
function LeaderboardRegistry.setData(category: string, payload: any)
	dataCache[category] = payload
end

function LeaderboardRegistry.getData(category: string)
	return dataCache[category]
end

--- Dapatkan handler untuk kategori tertentu
function LeaderboardRegistry.getHandler(category: string): UpdateCallback?
	return handlers[category]
end

--- Eksekusi pembaruan kategori secara aman
function LeaderboardRegistry.execute(category: string): boolean
	local handler = LeaderboardRegistry.getHandler(category)
	if handler then
		local ok, err = pcall(handler)
		if not ok then
			warn(string.format("[LeaderboardRegistry] Error executing %s update: %s", category, tostring(err)))
		end
		return ok
	end
	return false
end

return LeaderboardRegistry
