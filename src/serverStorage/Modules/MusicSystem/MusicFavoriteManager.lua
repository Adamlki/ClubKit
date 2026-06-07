local DataStoreService = game:GetService("DataStoreService")

local MusicFavoriteManager = {}
MusicFavoriteManager.__index = MusicFavoriteManager

-- ====================================
-- CONFIGURATION
-- ====================================
local CONFIG = {
	DATASTORE_NAME = "MusicFavorites_v1",
	MAX_FAVORITES = 100,
	RETRY_ATTEMPTS = 3,
	RETRY_DELAY = 1,
	CACHE_DURATION = 300, -- 5 minutes
}

-- ====================================
-- DATASTORE SETUP
-- ====================================
local favoritesStore = DataStoreService:GetDataStore(CONFIG.DATASTORE_NAME)

-- ====================================
-- INITIALIZATION
-- ====================================
function MusicFavoriteManager.new()
	local self = setmetatable({}, MusicFavoriteManager)

	self.playerFavorites = {} -- Cache: [userId] = {musicIds = {}, lastUpdate = tick(), isDirty = bool}
	self.loadingQueue = {} -- Track loading states

	return self
end

-- ====================================
-- DATASTORE OPERATIONS (WITH RETRY)
-- ====================================
local function datastoreGetAsync(key)
	for attempt = 1, CONFIG.RETRY_ATTEMPTS do
		local success, result = pcall(function()
			return favoritesStore:GetAsync(key)
		end)

		if success then
			return result
		end

		if attempt < CONFIG.RETRY_ATTEMPTS then
			task.wait(CONFIG.RETRY_DELAY)
		end
	end

	warn("[FavoriteManager] Failed to load favorites for key:", key)
	return nil
end

local function datastoreSetAsync(key, value)
	for attempt = 1, CONFIG.RETRY_ATTEMPTS do
		local success = pcall(function()
			favoritesStore:SetAsync(key, value)
		end)

		if success then
			return true
		end

		if attempt < CONFIG.RETRY_ATTEMPTS then
			task.wait(CONFIG.RETRY_DELAY)
		end
	end

	warn("[FavoriteManager] Failed to save favorites for key:", key)
	return false
end

-- ====================================
-- LOAD PLAYER FAVORITES
-- ====================================
function MusicFavoriteManager:LoadPlayerFavorites(userId)
	-- Check cache first
	local cached = self.playerFavorites[userId]
	local currentTime = tick()

	if cached and (currentTime - cached.lastUpdate) < CONFIG.CACHE_DURATION then
		return cached.musicIds
	end

	-- Check if already loading
	if self.loadingQueue[userId] then
		local startWait = os.clock()
		while self.loadingQueue[userId] and (os.clock() - startWait) < 10 do
			task.wait(0.1)
		end

		-- Check cache again after waiting
		cached = self.playerFavorites[userId]
		if cached then
			return cached.musicIds
		end
	end

	-- Load from DataStore
	self.loadingQueue[userId] = true

	local key = "favorites_" .. tostring(userId)
	local data = datastoreGetAsync(key)

	self.loadingQueue[userId] = nil

	local favorites = {}
	if data and type(data) == "table" and data.musicIds then
		favorites = data.musicIds
	end

	-- Cache the result
	self.playerFavorites[userId] = {
		musicIds = favorites,
		lastUpdate = currentTime,
		isDirty = false
	}

	return favorites
end

-- ====================================
-- SAVE PLAYER FAVORITES (ON LEAVE ONLY)
-- ====================================
function MusicFavoriteManager:SavePlayerFavorites(userId)
	local cached = self.playerFavorites[userId]

	-- Only save if data exists and is dirty (modified)
	if not cached or not cached.isDirty then
		return true
	end

	local key = "favorites_" .. tostring(userId)

	local data = {
		musicIds = cached.musicIds,
		lastSaved = tick(),
		timestamp = tick()
	}

	local success = datastoreSetAsync(key, data)

	if success then
		cached.isDirty = false
		return true
	end

	return false
end

-- ====================================
-- GET PLAYER FAVORITES (FROM CACHE)
-- ====================================
function MusicFavoriteManager:GetPlayerFavorites(userId)
	local cached = self.playerFavorites[userId]
	if cached then
		return cached.musicIds
	end

	return {}
end

-- ====================================
-- ADD FAVORITE (IN-MEMORY ONLY)
-- ====================================
function MusicFavoriteManager:AddFavorite(userId, musicId)
	local favorites = self:GetPlayerFavorites(userId)

	-- Check if already favorited
	for _, favId in ipairs(favorites) do
		if favId == musicId then
			return false, "Already in favorites"
		end
	end

	-- Check max limit
	if #favorites >= CONFIG.MAX_FAVORITES then
		return false, string.format("Maximum %d favorites reached", CONFIG.MAX_FAVORITES)
	end

	-- Add to favorites (in memory only)
	table.insert(favorites, musicId)

	-- Update cache and mark as dirty
	self.playerFavorites[userId] = {
		musicIds = favorites,
		lastUpdate = tick(),
		isDirty = true -- Mark for save on leave
	}

	return true, "Added to favorites"
end

-- ====================================
-- REMOVE FAVORITE (IN-MEMORY ONLY)
-- ====================================
function MusicFavoriteManager:RemoveFavorite(userId, musicId)
	local favorites = self:GetPlayerFavorites(userId)

	-- Find and remove
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

	-- Update cache and mark as dirty
	self.playerFavorites[userId] = {
		musicIds = favorites,
		lastUpdate = tick(),
		isDirty = true -- Mark for save on leave
	}

	return true, "Removed from favorites"
end

-- ====================================
-- TOGGLE FAVORITE
-- ====================================
function MusicFavoriteManager:ToggleFavorite(userId, musicId)
	local favorites = self:GetPlayerFavorites(userId)

	-- Check if already favorited
	for i, favId in ipairs(favorites) do
		if favId == musicId then
			-- Remove
			return self:RemoveFavorite(userId, musicId)
		end
	end

	-- Add
	return self:AddFavorite(userId, musicId)
end

-- ====================================
-- IS FAVORITE
-- ====================================
function MusicFavoriteManager:IsFavorite(userId, musicId)
	local favorites = self:GetPlayerFavorites(userId)

	for _, favId in ipairs(favorites) do
		if favId == musicId then
			return true
		end
	end

	return false
end

-- ====================================
-- GET FAVORITE COUNT
-- ====================================
function MusicFavoriteManager:GetFavoriteCount(userId)
	local favorites = self:GetPlayerFavorites(userId)
	return #favorites
end

-- ====================================
-- CLEAR ALL FAVORITES
-- ====================================
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
		-- Update cache
		self.playerFavorites[userId] = {
			musicIds = favorites,
			lastUpdate = tick(),
			isDirty = false
		}
		return true
	end

	return false
end

-- ====================================
-- INVALIDATE CACHE
-- ====================================
function MusicFavoriteManager:InvalidateCache(userId)
	self.playerFavorites[userId] = nil
end

-- ====================================
-- CLEANUP PLAYER DATA (SAVE ON LEAVE)
-- ====================================
function MusicFavoriteManager:CleanupPlayer(userId)
	-- Save current favorites before cleanup
	self:SavePlayerFavorites(userId)

	-- Remove from cache
	self.playerFavorites[userId] = nil
	self.loadingQueue[userId] = nil
end

-- ====================================
-- GET STATISTICS
-- ====================================
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