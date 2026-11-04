local RateLimiter = {}

-- CONFIGURATION
local CONFIG = {
	-- Animation & Emotes
	animationStart = { count = 8, window = 1 },      -- 8 animasi per detik; cukup untuk dance, jauh lebih ringan untuk 100 player
	changeSpeed = { count = 8, window = 1 },         -- 8 speed change per detik
	changeAnimationSpeed = { count = 8, window = 1 },
	startSync = { count = 3, window = 2 },           -- 3 sync per 2 detik
	updateFavoritedAnimations = { count = 3, window = 5 },

	-- Carry System
	carryRequest = { count = 3, window = 3 },
	carryResponse = { count = 5, window = 2 },
	carryEnd = { count = 5, window = 1 },

	-- Donation System
	requestDonationState = { count = 2, window = 5 },

	-- Music System
	musicAction = { count = 5, window = 2 },
	musicSync = { count = 3, window = 5 },

	-- Bio & Title
	setBioStatus = { count = 3, window = 5 },
	updateTitle = { count = 3, window = 5 },
	assignDonatur = { count = 3, window = 5 },
	customTitleAction = { count = 3, window = 3 },

	-- Message System
	sendMessage = { count = 5, window = 3 },
	adminNotifCheck = { count = 5, window = 3 },
	adminNotifSend = { count = 3, window = 3 },

	-- Admin Actions
	teamAction = { count = 5, window = 2 },
	giveRole = { count = 3, window = 3 },
	adminRoleAction = { count = 3, window = 3 },

	-- Accessory & Weapons
	toggleAccessory = { count = 5, window = 2 },
	accessoryHatToggle = { count = 5, window = 2 },
	waterGunShoot = { count = 6, window = 1 },

	-- Profile & Likes
	getPlayerInfo = { count = 3, window = 5 },
	CheckLike = { count = 6, window = 2 },
	LikePlayerInvoke = { count = 3, window = 3 },

	-- Refresh & Anti-AFK
	refreshCharacter = { count = 2, window = 5 },
	antiAfkRejoin = { count = 1, window = 30 },

	-- Default untuk remote yang tidak terdaftar
	default = { count = 10, window = 1 }
}

-- STATE STORAGE
local playerRequests = {}

-- HELPER FUNCTIONS

local function getPlayerKey(player)
	return tostring(player.UserId)
end

local function cleanOldRequests(requests, window)
	local now = os.clock()
	local validRequests = {}

	for _, timestamp in ipairs(requests) do
		if now - timestamp < window then
			table.insert(validRequests, timestamp)
		end
	end

	return validRequests
end

-- MAIN FUNCTIONS

function RateLimiter.check(player, actionName)
	if not player then
		return false, "Invalid player"
	end

	local playerKey = getPlayerKey(player)
	local limit = CONFIG[actionName] or CONFIG.default
	
	local trackActionName = CONFIG[actionName] and actionName or "default_unknown"
	local now = os.clock()

	if not playerRequests[playerKey] then
		playerRequests[playerKey] = {}
	end

	if not playerRequests[playerKey][trackActionName] then
		playerRequests[playerKey][trackActionName] = {}
	end

	playerRequests[playerKey][trackActionName] = cleanOldRequests(
		playerRequests[playerKey][trackActionName],
		limit.window
	)

	local requests = playerRequests[playerKey][trackActionName]

	if #requests >= limit.count then
		return false, "rate_limited"
	end

	table.insert(requests, now)

	return true, "allowed"
end

function RateLimiter.checkWithInfo(player, actionName)
	local allowed, reason = RateLimiter.check(player, actionName)
	local limit = CONFIG[actionName] or CONFIG.default
	local trackActionName = CONFIG[actionName] and actionName or "default_unknown"
	local playerKey = getPlayerKey(player)
	local currentCount = playerRequests[playerKey] 
		and playerRequests[playerKey][trackActionName] 
		and #playerRequests[playerKey][trackActionName] 
		or 0

	return allowed, reason, {
		currentCount = currentCount,
		maxCount = limit.count,
		window = limit.window
	}
end

function RateLimiter.reset(player, actionName)
	if not player then return end

	local playerKey = getPlayerKey(player)

	if actionName then
		if playerRequests[playerKey] then
			playerRequests[playerKey][actionName] = {}
		end
	else
		playerRequests[playerKey] = {}
	end
end

function RateLimiter.resetAll()
	playerRequests = {}
end

function RateLimiter.getUsage(player, actionName)
	if not player then return 0 end

	local playerKey = getPlayerKey(player)
	local limit = CONFIG[actionName] or CONFIG.default
	local trackActionName = CONFIG[actionName] and actionName or "default_unknown"

	if not playerRequests[playerKey] or not playerRequests[playerKey][trackActionName] then
		return 0, limit.count
	end

	playerRequests[playerKey][trackActionName] = cleanOldRequests(
		playerRequests[playerKey][trackActionName],
		limit.window
	)

	return #playerRequests[playerKey][trackActionName], limit.count
end

function RateLimiter.setConfig(actionName, count, window)
	CONFIG[actionName] = { count = count, window = window }
end

function RateLimiter.getConfig(actionName)
	return CONFIG[actionName] or CONFIG.default
end

function RateLimiter.getAllConfigs()
	local copy = {}
	for k, v in pairs(CONFIG) do
		copy[k] = { count = v.count, window = v.window }
	end
	return copy
end

-- CLEANUP

game:GetService("Players").PlayerRemoving:Connect(function(player)
	local playerKey = getPlayerKey(player)
	playerRequests[playerKey] = nil
end)

task.spawn(function()
	while true do
		task.wait(60)

		local now = os.clock()

		for playerKey, actions in pairs(playerRequests) do
			for actionName, requests in pairs(actions) do
				local limit = CONFIG[actionName] or CONFIG.default
				actions[actionName] = cleanOldRequests(requests, limit.window)
				if #actions[actionName] == 0 then
					actions[actionName] = nil
				end
			end

			if next(actions) == nil then
				playerRequests[playerKey] = nil
			end
		end
	end
end)

-- DEBUG FUNCTIONS

RateLimiter.Debug = {
	getStats = function()
		local total = 0
		for _ in pairs(playerRequests) do
			total = total + 1
		end
		return {
			playersTracked = total,
			configs = RateLimiter.getAllConfigs()
		}
	end,

	resetPlayer = function(playerName)
		local player = game:GetService("Players"):FindFirstChild(playerName)
		if player then
			RateLimiter.reset(player)
			print("Reset rate limits for:", playerName)
		else
			print("Player not found:", playerName)
		end
	end,

	setLimit = function(actionName, count, window)
		RateLimiter.setConfig(actionName, count, window)
		print(string.format("Set %s limit: %d requests per %d seconds", actionName, count, window))
	end
}

return RateLimiter
