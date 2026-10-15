--!strict
-- ============================================================
-- LeaderboardRegistry (Server Module)
-- Decoupled registry & dispatcher for round-robin leaderboard updates
-- Syncs with _G to guarantee 100% backward compatibility
-- ============================================================

type UpdateCallback = () -> ()

local LeaderboardRegistry = {}

local handlers: { [string]: UpdateCallback } = {}

--- Daftarkan handler pembaruan leaderboard
function LeaderboardRegistry.register(category: string, callback: UpdateCallback)
	handlers[category] = callback

	-- Backwards compatibility synchronization ke _G
	if category == "Robux" then
		_G.UpdateRobuxLeaderboard = callback
	elseif category == "Saweria" then
		_G.UpdateSaweriaLeaderboard = callback
	elseif category == "Likes" then
		_G.UpdateLikeLeaderboard = callback
	elseif category == "Levels" then
		_G.UpdateLevelLeaderboard = callback
	end
end

--- Dapatkan handler untuk kategori tertentu (dengan fallback ke _G jika ada skrip lama)
function LeaderboardRegistry.getHandler(category: string): UpdateCallback?
	if handlers[category] then
		return handlers[category]
	end

	-- Fallback check ke _G
	if category == "Robux" and _G.UpdateRobuxLeaderboard then
		return _G.UpdateRobuxLeaderboard
	elseif category == "Saweria" and _G.UpdateSaweriaLeaderboard then
		return _G.UpdateSaweriaLeaderboard
	elseif category == "Likes" and _G.UpdateLikeLeaderboard then
		return _G.UpdateLikeLeaderboard
	elseif category == "Levels" and _G.UpdateLevelLeaderboard then
		return _G.UpdateLevelLeaderboard
	end

	return nil
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
