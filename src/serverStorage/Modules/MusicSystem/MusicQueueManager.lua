local MusicQueueManager = {}
MusicQueueManager.__index = MusicQueueManager

function MusicQueueManager.new(config)
	local self = setmetatable({}, MusicQueueManager)

	self.config = config
	self.queue = {}
	self.playerQueueCount = {}

	return self
end

function MusicQueueManager:GetMaxQueueForRole(role)
	if self.config.MAX_QUEUE_PER_ROLE and self.config.MAX_QUEUE_PER_ROLE[role] then
		return self.config.MAX_QUEUE_PER_ROLE[role]
	end
	return self.config.MAX_QUEUE_PER_USER or 5
end

function MusicQueueManager:AddToQueue(musicData, uploaderName, userId, role)
	if #self.queue >= self.config.MAX_QUEUE_SIZE then
		return false, "Queue penuh! Tunggu beberapa lagu selesai."
	end

	local maxQueue = self:GetMaxQueueForRole(role)

	if maxQueue == 0 then
		return false, "Anda tidak memiliki permission untuk menambah lagu!"
	end

	local userCount = self.playerQueueCount[userId] or 0
	if userCount >= maxQueue then
		return false, string.format("Anda sudah punya %d lagu di queue! (Limit %s: %d)", userCount, role, maxQueue)
	end

	table.insert(self.queue, {
		musicData = musicData,
		uploader = uploaderName,
		userId = userId,
		addedTime = tick()
	})

	self.playerQueueCount[userId] = userCount + 1

	return true, nil
end

function MusicQueueManager:GetNext()
	if #self.queue > 0 then
		local nextSong = table.remove(self.queue, 1)

		if nextSong.userId then
			local count = self.playerQueueCount[nextSong.userId] or 0
			self.playerQueueCount[nextSong.userId] = math.max(0, count - 1)
		end

		return nextSong
	end

	return nil
end

function MusicQueueManager:GetQueue()
	return self.queue
end

function MusicQueueManager:IsEmpty()
	return #self.queue == 0
end

function MusicQueueManager:GetSize()
	return #self.queue
end

function MusicQueueManager:RemoveUserSongs(userId)
	local removed = 0

	for i = #self.queue, 1, -1 do
		if self.queue[i].userId == userId then
			table.remove(self.queue, i)
			removed = removed + 1
		end
	end

	self.playerQueueCount[userId] = nil

	return removed
end

function MusicQueueManager:GetUserQueueCount(userId)
	return self.playerQueueCount[userId] or 0
end

function MusicQueueManager:Clear()
	self.queue = {}
	self.playerQueueCount = {}
end

return MusicQueueManager
