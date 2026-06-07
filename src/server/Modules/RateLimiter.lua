local RateLimiter = {}

-- ============================================
-- CONFIGURATION
-- ============================================
local CONFIG = {
	-- Format: { count = max_requests, window = time_window_seconds }
	-- count = jumlah maksimal request dalam window
	-- window = periode waktu dalam detik

	-- Animation & Emotes
	animationStart = { count = 5, window = 1 },      -- 5 animasi per detik
	changeSpeed = { count = 20, window = 1 },        -- 20 speed change per detik (slider debounce 50ms = max 20/s)
	startSync = { count = 2, window = 2 },           -- 2 sync per 2 detik
	updateFavoritedAnimations = { count = 2, window = 5 }, -- 2 save per 5 detik

	-- Carry System
	carryRequest = { count = 3, window = 3 },        -- 3 carry request per 3 detik
	carryResponse = { count = 5, window = 2 },       -- 5 response per 2 detik
	carryEnd = { count = 5, window = 1 },            -- 5 end per detik

	-- Donation System
	requestDonationState = { count = 2, window = 5 }, -- 2 request per 5 detik

	-- Music System
	musicAction = { count = 5, window = 2 },         -- 5 music action per 2 detik
	musicSync = { count = 3, window = 5 },           -- 3 sync per 5 detik

	-- Bio & Title
	setBioStatus = { count = 3, window = 5 },        -- 3 bio update per 5 detik
	updateTitle = { count = 3, window = 5 },         -- 3 title update per 5 detik

	-- Message System
	sendMessage = { count = 5, window = 3 },         -- 5 message per 3 detik

	-- Admin Actions
	teamAction = { count = 5, window = 2 },          -- 5 team action per 2 detik
	giveRole = { count = 3, window = 3 },            -- 3 role change per 3 detik

	-- Accessory
	toggleAccessory = { count = 5, window = 2 },     -- 5 toggle per 2 detik

	-- Refresh
	refreshCharacter = { count = 2, window = 5 },    -- 2 refresh per 5 detik

	-- Default untuk remote yang tidak terdaftar
	default = { count = 10, window = 1 }             -- 10 request per detik
}

-- ============================================
-- STATE STORAGE
-- ============================================
local playerRequests = {}  -- [userId][actionName] = {timestamps}

-- ============================================
-- HELPER FUNCTIONS
-- ============================================

local function getPlayerKey(player)
	return tostring(player.UserId)
end

local function cleanOldRequests(requests, window)
	local now = tick()
	local validRequests = {}

	for _, timestamp in ipairs(requests) do
		if now - timestamp < window then
			table.insert(validRequests, timestamp)
		end
	end

	return validRequests
end

-- ============================================
-- MAIN FUNCTIONS
-- ============================================

-- Cek apakah player bisa melakukan action
function RateLimiter.check(player, actionName)
	if not player then
		return false, "Invalid player"
	end

	local playerKey = getPlayerKey(player)
	local limit = CONFIG[actionName] or CONFIG.default
	local now = tick()

	-- Initialize player storage if not exists
	if not playerRequests[playerKey] then
		playerRequests[playerKey] = {}
	end

	if not playerRequests[playerKey][actionName] then
		playerRequests[playerKey][actionName] = {}
	end

	-- Clean old requests
	playerRequests[playerKey][actionName] = cleanOldRequests(
		playerRequests[playerKey][actionName],
		limit.window
	)

	local requests = playerRequests[playerKey][actionName]

	-- Check if limit exceeded
	if #requests >= limit.count then
		return false, "rate_limited"
	end

	-- Record new request
	table.insert(requests, now)

	return true, "allowed"
end

-- Cek dengan informasi tambahan (untuk debugging)
function RateLimiter.checkWithInfo(player, actionName)
	local allowed, reason = RateLimiter.check(player, actionName)
	local limit = CONFIG[actionName] or CONFIG.default
	local playerKey = getPlayerKey(player)
	local currentCount = playerRequests[playerKey] 
		and playerRequests[playerKey][actionName] 
		and #playerRequests[playerKey][actionName] 
		or 0

	return allowed, reason, {
		currentCount = currentCount,
		maxCount = limit.count,
		window = limit.window
	}
end

-- Reset limit untuk player tertentu (untuk admin)
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

-- Reset semua (untuk admin)
function RateLimiter.resetAll()
	playerRequests = {}
end

-- Get current usage untuk player
function RateLimiter.getUsage(player, actionName)
	if not player then return 0 end

	local playerKey = getPlayerKey(player)
	local limit = CONFIG[actionName] or CONFIG.default

	if not playerRequests[playerKey] or not playerRequests[playerKey][actionName] then
		return 0, limit.count
	end

	playerRequests[playerKey][actionName] = cleanOldRequests(
		playerRequests[playerKey][actionName],
		limit.window
	)

	return #playerRequests[playerKey][actionName], limit.count
end

-- Update config (untuk admin/debug)
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

-- ============================================
-- CLEANUP
-- ============================================

game:GetService("Players").PlayerRemoving:Connect(function(player)
	local playerKey = getPlayerKey(player)
	playerRequests[playerKey] = nil
end)

-- Periodic cleanup (setiap 60 detik)
task.spawn(function()
	while true do
		task.wait(60)

		local now = tick()
		local maxWindow = 10  -- Maximum window time

		for playerKey, actions in pairs(playerRequests) do
			for actionName, requests in pairs(actions) do
				actions[actionName] = cleanOldRequests(requests, maxWindow)

				-- Remove empty tables
				if #actions[actionName] == 0 then
					actions[actionName] = nil
				end
			end

			-- Remove empty player entries
			if next(actions) == nil then
				playerRequests[playerKey] = nil
			end
		end
	end
end)

-- ============================================
-- DEBUG FUNCTIONS
-- ============================================

_G.RateLimiterDebug = {
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