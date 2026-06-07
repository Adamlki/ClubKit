local RateLimiter = require(script.Parent:WaitForChild("RateLimiter"))

local RemoteEventManager = {}

-- ============================================
-- CONFIG: Mapping RemoteEvent Name -> Rate Limit Action
-- ============================================
local REMOTE_ACTION_MAP = {
	-- Remotes folder
	["startSync"] = "startSync",
	["changeSpeed"] = "changeSpeed",
	["updateFavoritedAnimationsEvent"] = "updateFavoritedAnimations",
	["UpdateLeaderStatus"] = "startSync",
	
	-- CarryRemotes
	["CarryRequest"] = "carryRequest",
	["CarryResponse"] = "carryResponse",
	["CarryEnd"] = "carryEnd",
	
	-- BioRemotes
	["SetBioStatus"] = "setBioStatus",
	
	-- TitleRemotes
	["UpdateTitle"] = "updateTitle",
	
	-- Message
	["SendMessage"] = "sendMessage",
	
	-- AccessoryRemotes
	["ToggleAccessory"] = "toggleAccessory",
	
	-- ReplicatedStorage root
	["RefreshCharacterEvent"] = "refreshCharacter",
	["GiveRoleRemote"] = "giveRole",
	["RequestDonationState"] = "requestDonationState",
	
	-- MusicRemotes
	["DispatchAction"] = "musicAction",
	["RequestSync"] = "musicSync",
	
	-- Gamepass
	["RefreshRole"] = "giveRole",
}

-- ============================================
-- WRAPPER FUNCTIONS
-- ============================================

-- Wrap RemoteEvent.OnServerEvent dengan rate limiting
function RemoteEventManager.wrapRemoteEvent(remoteEvent, actionName, callback)
	if not remoteEvent or not remoteEvent:IsA("RemoteEvent") then
		warn("[RemoteEventManager] Invalid RemoteEvent")
		return
	end
	
	-- Gunakan mapped action name atau nama remote
	local rateLimitAction = actionName or REMOTE_ACTION_MAP[remoteEvent.Name] or remoteEvent.Name
	
	remoteEvent.OnServerEvent:Connect(function(player, ...)
		-- Check rate limit
		local allowed, reason = RateLimiter.check(player, rateLimitAction)
		
		if not allowed then
			-- Optional: Notify player they're rate limited
			-- warn(string.format("[RateLimit] %s rate limited for %s", player.Name, rateLimitAction))
			return
		end
		
		-- Execute callback
		if callback then
			callback(player, ...)
		end
	end)
end

-- Wrap RemoteFunction.OnServerInvoke dengan rate limiting
function RemoteEventManager.wrapRemoteFunction(remoteFunction, actionName, callback)
	if not remoteFunction or not remoteFunction:IsA("RemoteFunction") then
		warn("[RemoteEventManager] Invalid RemoteFunction")
		return
	end
	
	local rateLimitAction = actionName or REMOTE_ACTION_MAP[remoteFunction.Name] or remoteFunction.Name
	
	remoteFunction.OnServerInvoke = function(player, ...)
		-- Check rate limit
		local allowed, reason = RateLimiter.check(player, rateLimitAction)
		
		if not allowed then
			return "rate_limited"
		end
		
		-- Execute callback
		if callback then
			return callback(player, ...)
		end
		
		return nil
	end
end

-- ============================================
-- HELPER: Auto-wrap semua remotes di folder
-- ============================================

function RemoteEventManager.wrapFolder(folder, callbackMap)
	if not folder or not folder:IsA("Folder") then
		warn("[RemoteEventManager] Invalid folder")
		return
	end
	
	callbackMap = callbackMap or {}
	
	for _, child in ipairs(folder:GetDescendants()) do
		if child:IsA("RemoteEvent") then
			local callback = callbackMap[child.Name]
			if callback then
				RemoteEventManager.wrapRemoteEvent(child, nil, callback)
			end
		elseif child:IsA("RemoteFunction") then
			local callback = callbackMap[child.Name]
			if callback then
				RemoteEventManager.wrapRemoteFunction(child, nil, callback)
			end
		end
	end
end

-- ============================================
-- HELPER: Check tanpa wrap (untuk manual usage)
-- ============================================

function RemoteEventManager.checkRateLimit(player, actionName)
	return RateLimiter.check(player, actionName)
end

function RemoteEventManager.checkRateLimitWithInfo(player, actionName)
	return RateLimiter.checkWithInfo(player, actionName)
end

-- ============================================
-- GETTER
-- ============================================

function RemoteEventManager.getRateLimiter()
	return RateLimiter
end

return RemoteEventManager