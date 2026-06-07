-- ====================================
-- ANTI-SPAM MANAGER (FIXED)
-- ====================================
local Config = require(script.Parent.Config)
local Logger = require(script.Parent.Logger)

local AntiSpamManager = {}
AntiSpamManager.playerCooldowns = {}
AntiSpamManager.playerRequestCounts = {}

function AntiSpamManager:IsSpamming(player, actionType)
	if not Config.AntiSpam.Enabled then return false end

	local userId = player.UserId
	local currentTime = tick()

	-- Create unique key per action type
	local cooldownKey = userId .. "_" .. (actionType or "generic")

	-- Check cooldown untuk action ini
	if self.playerCooldowns[cooldownKey] then
		if currentTime - self.playerCooldowns[cooldownKey] < Config.AntiSpam.CooldownTime then
			Logger:Debug(string.format("Player %s is spamming action: %s (cooldown)", 
				player.Name, actionType or "generic"))
			return true
		end
	end

	-- Check request count per minute (global)
	if not self.playerRequestCounts[userId] then
		self.playerRequestCounts[userId] = {count = 0, resetTime = currentTime + 60}
	end

	local requestData = self.playerRequestCounts[userId]

	if currentTime > requestData.resetTime then
		requestData.count = 0
		requestData.resetTime = currentTime + 60
	end

	requestData.count = requestData.count + 1

	if requestData.count > Config.AntiSpam.MaxRequestsPerMinute then
		Logger:Debug(string.format("Player %s exceeded request limit (%d/%d)", 
			player.Name, requestData.count, Config.AntiSpam.MaxRequestsPerMinute))
		return true
	end

	-- Set cooldown untuk action ini
	self.playerCooldowns[cooldownKey] = currentTime

	Logger:Debug(string.format("Player %s request OK: %s (%d/%d)", 
		player.Name, actionType or "generic", 
		requestData.count, Config.AntiSpam.MaxRequestsPerMinute))

	return false
end

function AntiSpamManager:CleanupPlayer(userId)
	-- Cleanup all cooldowns untuk user ini
	for key in pairs(self.playerCooldowns) do
		if key:match("^" .. userId .. "_") then
			self.playerCooldowns[key] = nil
		end
	end

	self.playerRequestCounts[userId] = nil
	Logger:Debug("Cleaned up anti-spam data for user: " .. userId)
end

return AntiSpamManager