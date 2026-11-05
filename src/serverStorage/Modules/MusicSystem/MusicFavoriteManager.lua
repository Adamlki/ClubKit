local DataStoreEnv = require(script.Parent.Parent:WaitForChild("DataStoreEnv"))

local MusicFavoriteManager = {}
MusicFavoriteManager.__index = MusicFavoriteManager

local CONFIG = {
	DATASTORE_NAME = "MusicFavorites_v1",
	MAX_FAVORITES = 100,
	RETRY_ATTEMPTS = 3,
	RETRY_DELAY = 1,
	CACHE_DURATION = 300,
}

local favoritesStore, favoritesWriteStore = DataStoreEnv.Get(CONFIG.DATASTORE_NAME)

function MusicFavoriteManager.new()
	local self = setmetatable({}, MusicFavoriteManager)

	self.playerFavorites = {}
	self.loadingQueue = {}
	self.loaded = {}

	task.spawn(function()
		while true do
			task.wait(120)
			for userId, data in pairs(self.playerFavorites) do
				if data.isDirty and self.loaded[userId] then
					self:SavePlayerFavorites(userId)
					task.wait(0.2)
				end
			end
		end
	end)

	return self
end

local function datastoreGetAsync(key)
	for attempt = 1, CONFIG.RETRY_ATTEMPTS do
		local success, result = pcall(function()
			return favoritesStore:GetAsync(key)
		end)

		if success then
			return true, result
		end

		if attempt < CONFIG.RETRY_ATTEMPTS then
			task.wait(CONFIG.RETRY_DELAY)
		end
	end

	warn("[FavoriteManager] Failed to load favorites for key:", key)
	return false, nil
end

local function mergeFavoriteIds(a, b)
	local seen, merged = {}, {}
	for _, list in ipairs({ a or {}, b or {} }) do
		for _, id in ipairs(list) do
			if not seen[id] then
				seen[id] = true
				table.insert(merged, id)
			end
		end
	end
	return merged
end

local function datastoreUpdateAsync(key, value, loadedTimestamp)
	for attempt = 1, CONFIG.RETRY_ATTEMPTS do
		local success, result = pcall(function()
			return favoritesWriteStore:UpdateAsync(key, function(oldData)
				if type(oldData) == "table"
					and type(oldData.musicIds) == "table"
					and (tonumber(oldData.timestamp) or 0) > (tonumber(loadedTimestamp) or 0) then
					value.musicIds = mergeFavoriteIds(oldData.musicIds, value.musicIds)
					value.timestamp = tick()
				end
				return value
			end)
		end)

		if success then
			return true, result
		end

		if attempt < CONFIG.RETRY_ATTEMPTS then
			task.wait(CONFIG.RETRY_DELAY)
		end
	end

	warn("[FavoriteManager] Failed to save favorites for key:", key)
	return false, nil
end

function MusicFavoriteManager:LoadPlayerFavorites(userId)
	local cached = self.playerFavorites[userId]
	local currentTime = tick()

	if cached and (cached.isDirty or (currentTime - cached.lastUpdate) < CONFIG.CACHE_DURATION) then
		self.loaded[userId] = true
		return cached.musicIds
	end

	if self.loadingQueue[userId] then
		local startWait = os.clock()
		while self.loadingQueue[userId] and (os.clock() - startWait) < 10 do
			task.wait(0.1)
		end

		cached = self.playerFavorites[userId]
		if cached then
			self.loaded[userId] = true
			return cached.musicIds
		end
	end

	self.loadingQueue[userId] = true

	local key = "favorites_" .. tostring(userId)
	local loadSuccess, data = datastoreGetAsync(key)

	self.loadingQueue[userId] = nil

	if not loadSuccess then
		if cached then
			self.loaded[userId] = true
			return cached.musicIds
		end
		return nil
	end

	local favorites = {}
	if data and type(data) == "table" and type(data.musicIds) == "table" then
		favorites = data.musicIds
	end

	self.playerFavorites[userId] = {
		musicIds = favorites,
		lastUpdate = currentTime,
		remoteTimestamp = tonumber(data and data.timestamp) or 0,
		isDirty = false
	}
	self.loaded[userId] = true

	return favorites
end

function MusicFavoriteManager:IsLoaded(userId)
	return self.loaded[userId] == true
end

function MusicFavoriteManager:SavePlayerFavorites(userId)
	local cached = self.playerFavorites[userId]

	if not cached or not cached.isDirty then
		return true
	end

	if not self.loaded[userId] then
		return false
	end

	local key = "favorites_" .. tostring(userId)

	local data = {
		musicIds = cached.musicIds,
		lastSaved = tick(),
		timestamp = tick()
	}

	local success, result = datastoreUpdateAsync(key, data, cached.remoteTimestamp)

	if success then
		if type(result) == "table" and type(result.musicIds) == "table" then
			cached.musicIds = result.musicIds
			cached.remoteTimestamp = tonumber(result.timestamp) or data.timestamp
		end
		cached.isDirty = false
		return true
	end

	return false
end

function MusicFavoriteManager:GetPlayerFavorites(userId)
	local cached = self.playerFavorites[userId]
	if cached then
		return cached.musicIds
	end

	return {}
end

function MusicFavoriteManager:AddFavorite(userId, musicId)
	if not self.loaded[userId] then
		local loaded = self:LoadPlayerFavorites(userId)
		if not loaded then
			return false, "Favorites masih dimuat, coba lagi sebentar lagi."
		end
	end

	local favorites = self:GetPlayerFavorites(userId)

	for _, favId in ipairs(favorites) do
		if favId == musicId then
			return false, "Already in favorites"
		end
	end

	if #favorites >= CONFIG.MAX_FAVORITES then
		return false, string.format("Maximum %d favorites reached", CONFIG.MAX_FAVORITES)
	end

	table.insert(favorites, musicId)

	local previous = self.playerFavorites[userId]
	self.playerFavorites[userId] = {
		musicIds = favorites,
		lastUpdate = tick(),
		remoteTimestamp = previous and previous.remoteTimestamp or 0,
		isDirty = true
	}

	return true, "Added to favorites"
end

function MusicFavoriteManager:RemoveFavorite(userId, musicId)
	if not self.loaded[userId] then
		local loaded = self:LoadPlayerFavorites(userId)
		if not loaded then
			return false, "Favorites masih dimuat, coba lagi sebentar lagi."
		end
	end

	local favorites = self:GetPlayerFavorites(userId)

	local found = false
	for i, favId in ipairs(favorites) do
		if favId == musicId then
			table.remove(favorites, i)
			found = true
			break
		end
	end

	if not found then
		return false, "Not in favorites"
	end

	local previous = self.playerFavorites[userId]
	self.playerFavorites[userId] = {
		musicIds = favorites,
		lastUpdate = tick(),
		remoteTimestamp = previous and previous.remoteTimestamp or 0,
		isDirty = true
	}

	return true, "Removed from favorites"
end

function MusicFavoriteManager:ToggleFavorite(userId, musicId)
	local favorites = self:GetPlayerFavorites(userId)

	for i, favId in ipairs(favorites) do
		if favId == musicId then
			return self:RemoveFavorite(userId, musicId)
		end
	end

	return self:AddFavorite(userId, musicId)
end

function MusicFavoriteManager:IsFavorite(userId, musicId)
	local favorites = self:GetPlayerFavorites(userId)

	for _, favId in ipairs(favorites) do
		if favId == musicId then
			return true
		end
	end

	return false
end

function MusicFavoriteManager:GetFavoriteCount(userId)
	local favorites = self:GetPlayerFavorites(userId)
	return #favorites
end

function MusicFavoriteManager:ClearAllFavorites(userId)
	local success = self:SavePlayerFavoritesImmediate(userId, {})

	if success then
		return true, "All favorites cleared"
	else
		return false, "Failed to clear favorites"
	end
end

function MusicFavoriteManager:SavePlayerFavoritesImmediate(userId, favorites)
	local key = "favorites_" .. tostring(userId)

	local data = {
		musicIds = favorites,
		lastSaved = tick(),
		timestamp = tick()
	}

	local success = datastoreSetAsync(key, data)

	if success then
		self.playerFavorites[userId] = {
			musicIds = favorites,
			lastUpdate = tick(),
			isDirty = false
		}
		self.loaded[userId] = true
		return true
	end

	return false
end

function MusicFavoriteManager:InvalidateCache(userId)
	self.playerFavorites[userId] = nil
end

function MusicFavoriteManager:CleanupPlayer(userId)
	local function finalize(attempt)
		local cached = self.playerFavorites[userId]
		if not cached then
			self.loaded[userId] = nil
			self.loadingQueue[userId] = nil
			return
		end

		if not cached.isDirty or self:SavePlayerFavorites(userId) then
			self.playerFavorites[userId] = nil
			self.loaded[userId] = nil
			self.loadingQueue[userId] = nil
			return
		end

		if attempt < 5 then
			task.delay(2, function()
				finalize(attempt + 1)
			end)
		else
			warn("[FavoriteManager] Gagal menyimpan favorites untuk userId:", userId)
		end
	end

	finalize(1)
end

function MusicFavoriteManager:GetStats()
	local stats = {
		cachedPlayers = 0,
		totalFavorites = 0,
		dirtyPlayers = 0
	}

	for userId, data in pairs(self.playerFavorites) do
		stats.cachedPlayers = stats.cachedPlayers + 1
		stats.totalFavorites = stats.totalFavorites + #data.musicIds
		if data.isDirty then
			stats.dirtyPlayers = stats.dirtyPlayers + 1
		end
	end

	return stats
end

return MusicFavoriteManager
