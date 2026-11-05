local Players = game:GetService("Players")

local MusicSkipVoteManager = {}
MusicSkipVoteManager.__index = MusicSkipVoteManager

function MusicSkipVoteManager.new(config, roleSystem)
	local self = setmetatable({}, MusicSkipVoteManager)

	self.config = config
	self.roleSystem = roleSystem
	self.skipVote = {
		active = false,
		initiator = nil,
		initiatorId = nil,
		songData = nil,
		voters = {},
		yesVotes = 0,
		noVotes = 0,
		startTime = 0,
		requiredVotes = 0,
		totalVoters = 0,
	}
	self.skipVoteRateLimit = {}

	return self
end

function MusicSkipVoteManager:GetEligibleVoters()
	return Players:GetPlayers()
end

function MusicSkipVoteManager:CheckRateLimit(player, customCooldown)
	local userId = player.UserId
	local lastTime = self.skipVoteRateLimit[userId]
	local cooldown = customCooldown or self.config.SKIP_VOTE_COOLDOWN or 7

	if lastTime then
		local elapsed = tick() - lastTime
		if elapsed < cooldown then
			local remaining = math.ceil(cooldown - elapsed)
			return false, remaining
		end
	end

	self.skipVoteRateLimit[userId] = tick()
	return true, 0
end

function MusicSkipVoteManager:IsActive()
	return self.skipVote.active
end

function MusicSkipVoteManager:GetVoteState()
	return {
		active = self.skipVote.active,
		yesVotes = self.skipVote.yesVotes,
		noVotes = self.skipVote.noVotes,
		initiator = self.skipVote.initiator,
		songData = self.skipVote.songData,
		requiredVotes = self.skipVote.requiredVotes,
		totalVoters = self.skipVote.totalVoters,
	}
end

function MusicSkipVoteManager:StartVote(initiatorPlayer, songData, dispatcher)
	if self.skipVote.active then
		return false, "Vote skip sedang berlangsung!"
	end

	local eligible = self:GetEligibleVoters()
	local totalVoters = #eligible
	if totalVoters <= 0 then
		return false, "Tidak ada player di server."
	end

	local requiredVotes = math.max(1, math.ceil(totalVoters * 0.8))

	self.skipVote = {
		active = true,
		initiator = initiatorPlayer.DisplayName,
		initiatorId = initiatorPlayer.UserId,
		songData = songData,
		voters = {
			[initiatorPlayer.UserId] = "yes"
		},
		yesVotes = 1,
		noVotes = 0,
		startTime = tick(),
		requiredVotes = requiredVotes,
		totalVoters = totalVoters,
	}

	if self.skipVote.yesVotes >= requiredVotes then
		return true, true
	end

	for _, player in ipairs(eligible) do
		dispatcher:SendToClient(player, "SKIP_VOTE_START", {
			initiator = initiatorPlayer.DisplayName,
			songTitle = songData.judul or "Unknown",
			totalVoters = totalVoters,
			requiredVotes = requiredVotes,
			yesVotes = 1,
			noVotes = 0,
			isInitiator = (player.UserId == initiatorPlayer.UserId)
		})
	end

	local voteStartTime = self.skipVote.startTime
	local voteDuration = self.config.SKIP_VOTE_DURATION or 30

	task.delay(voteDuration, function()
		if self.skipVote.active and self.skipVote.startTime == voteStartTime then
			self:EndVote(dispatcher, false)
		end
	end)

	return true, false
end

function MusicSkipVoteManager:CastVote(player, voteType, dispatcher)
	if not self.skipVote.active then
		return false, "Tidak ada vote yang sedang aktif!"
	end

	local userId = player.UserId

	if self.skipVote.voters[userId] then
		return false, "Anda sudah memberikan suara!"
	end

	self.skipVote.voters[userId] = voteType

	if voteType == "yes" then
		self.skipVote.yesVotes = self.skipVote.yesVotes + 1
	else
		self.skipVote.noVotes = self.skipVote.noVotes + 1
	end

	local currentEligible = self:GetEligibleVoters()
	local totalVoters = #currentEligible
	local requiredVotes = math.max(1, math.ceil(totalVoters * 0.8))
	self.skipVote.requiredVotes = requiredVotes
	self.skipVote.totalVoters = totalVoters

	for _, p in ipairs(currentEligible) do
		dispatcher:SendToClient(p, "SKIP_VOTE_UPDATE", {
			yesVotes = self.skipVote.yesVotes,
			noVotes = self.skipVote.noVotes,
			totalVoters = totalVoters,
			requiredVotes = requiredVotes
		})
	end

	if self.skipVote.yesVotes >= requiredVotes then
		return true, true
	end

	return true, false
end

function MusicSkipVoteManager:EndVote(dispatcher, forced)
	if not self.skipVote.active then return false end

	local currentEligible = self:GetEligibleVoters()
	local totalVoters = #currentEligible
	local requiredVotes = math.max(1, math.ceil(totalVoters * 0.8))
	local passed = forced or (self.skipVote.yesVotes >= requiredVotes)

	self.skipVote = {
		active = false,
		initiator = nil,
		initiatorId = nil,
		songData = nil,
		voters = {},
		yesVotes = 0,
		noVotes = 0,
		startTime = 0,
		requiredVotes = 0,
		totalVoters = 0,
	}

	dispatcher:SendToAll("SKIP_VOTE_END", {
		result = passed and "passed" or "failed"
	})

	return passed
end

function MusicSkipVoteManager:CancelVote(dispatcher)
	if not self.skipVote.active then return end

	self.skipVote = {
		active = false,
		initiator = nil,
		initiatorId = nil,
		songData = nil,
		voters = {},
		yesVotes = 0,
		noVotes = 0,
		startTime = 0,
		requiredVotes = 0,
		totalVoters = 0,
	}

	dispatcher:SendToAll("SKIP_VOTE_END", {
		result = "cancelled"
	})
end

function MusicSkipVoteManager:UpdateVoteOnPlayerLeave(userId, dispatcher)
	if not self.skipVote.active then return end

	if self.skipVote.voters[userId] then
		if self.skipVote.voters[userId] == "yes" then
			self.skipVote.yesVotes = math.max(0, self.skipVote.yesVotes - 1)
		else
			self.skipVote.noVotes = math.max(0, self.skipVote.noVotes - 1)
		end
		self.skipVote.voters[userId] = nil
	end

	local currentEligible = self:GetEligibleVoters()
	local totalVoters = #currentEligible
	if totalVoters <= 0 then
		self:CancelVote(dispatcher)
		return
	end

	local requiredVotes = math.max(1, math.ceil(totalVoters * 0.8))
	self.skipVote.requiredVotes = requiredVotes
	self.skipVote.totalVoters = totalVoters

	for _, p in ipairs(currentEligible) do
		dispatcher:SendToClient(p, "SKIP_VOTE_UPDATE", {
			yesVotes = self.skipVote.yesVotes,
			noVotes = self.skipVote.noVotes,
			totalVoters = totalVoters,
			requiredVotes = requiredVotes
		})
	end

	if self.skipVote.yesVotes >= requiredVotes then
		return true
	end

	return false
end

return MusicSkipVoteManager
