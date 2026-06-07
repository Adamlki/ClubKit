local MusicCooldownService = {}
MusicCooldownService.__index = MusicCooldownService

function MusicCooldownService.new(config)
	local self = setmetatable({}, MusicCooldownService)

	self.config = config
	self.playerCooldowns = {} -- [userId] = timestamp

	return self
end

-- ====================================
-- COOLDOWN CHECK
-- ====================================
function MusicCooldownService:CheckCooldown(player, roleCooldowns)
	local userId = player.UserId
	local RoleSystem = require(game:GetService("ServerStorage").Modules.RoleSystem)
	local role = RoleSystem:GetPlayerRole(player)
	local cooldown = roleCooldowns[role] or 300

	-- No cooldown for this role
	if cooldown == 0 then
		return true, nil
	end

	local lastTime = self.playerCooldowns[userId]
	local currentTime = tick()

	if lastTime then
		local elapsed = currentTime - lastTime
		if elapsed < cooldown then
			local remaining = math.ceil(cooldown - elapsed)
			local minutes = math.floor(remaining / 60)
			local seconds = remaining % 60
			local timeStr = minutes > 0 and 
				string.format("%dm %ds", minutes, seconds) or 
				string.format("%ds", seconds)

			return false, string.format("Cooldown aktif! Tunggu %s lagi.", timeStr)
		end
	end

	return true, nil
end

function MusicCooldownService:UpdateCooldown(player)
	self.playerCooldowns[player.UserId] = tick()
end

-- ====================================
-- CLEANUP
-- ====================================
function MusicCooldownService:CleanupPlayer(userId)
	self.playerCooldowns[userId] = nil
end

return MusicCooldownService
