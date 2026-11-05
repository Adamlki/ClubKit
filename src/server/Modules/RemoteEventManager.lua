local RateLimiter = require(script.Parent:WaitForChild("RateLimiter"))

local RemoteEventManager = {}

local REMOTE_ACTION_MAP = {
	["startSync"] = "startSync",
	["changeSpeed"] = "changeSpeed",
	["updateFavoritedAnimationsEvent"] = "updateFavoritedAnimations",
	["UpdateLeaderStatus"] = "startSync",
	
	["CarryRequest"] = "carryRequest",
	["CarryResponse"] = "carryResponse",
	["CarryEnd"] = "carryEnd",
	
	["SetBioStatus"] = "setBioStatus",
	
	["UpdateTitle"] = "updateTitle",
	
	["SendMessage"] = "sendMessage",
	
	["ToggleAccessory"] = "toggleAccessory",
	
	["RefreshCharacterEvent"] = "refreshCharacter",
	["GiveRoleRemote"] = "giveRole",
	["RequestDonationState"] = "requestDonationState",
	
	["DispatchAction"] = "musicAction",
	["RequestSync"] = "musicSync",
	
	["RefreshRole"] = "giveRole",
}

function RemoteEventManager.wrapRemoteEvent(remoteEvent, actionName, callback)
	if not remoteEvent or not remoteEvent:IsA("RemoteEvent") then
		warn("[RemoteEventManager] Invalid RemoteEvent")
		return
	end
	
	local rateLimitAction = actionName or REMOTE_ACTION_MAP[remoteEvent.Name] or remoteEvent.Name
	
	remoteEvent.OnServerEvent:Connect(function(player, ...)
		local allowed, reason = RateLimiter.check(player, rateLimitAction)
		
		if not allowed then
			return
		end
		
		if callback then
			callback(player, ...)
		end
	end)
end

function RemoteEventManager.wrapRemoteFunction(remoteFunction, actionName, callback)
	if not remoteFunction or not remoteFunction:IsA("RemoteFunction") then
		warn("[RemoteEventManager] Invalid RemoteFunction")
		return
	end
	
	local rateLimitAction = actionName or REMOTE_ACTION_MAP[remoteFunction.Name] or remoteFunction.Name
	
	remoteFunction.OnServerInvoke = function(player, ...)
		local allowed, reason = RateLimiter.check(player, rateLimitAction)
		
		if not allowed then
			return "rate_limited"
		end
		
		if callback then
			return callback(player, ...)
		end
		
		return nil
	end
end

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

function RemoteEventManager.checkRateLimit(player, actionName)
	return RateLimiter.check(player, actionName)
end

function RemoteEventManager.checkRateLimitWithInfo(player, actionName)
	return RateLimiter.checkWithInfo(player, actionName)
end

function RemoteEventManager.getRateLimiter()
	return RateLimiter
end

return RemoteEventManager
