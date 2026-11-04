local DataStoreEnv = require(script.Parent.Parent:WaitForChild("DataStoreEnv"))

local MusicFavoriteManager = {}
MusicFavoriteManager.__index = MusicFavoriteManager

-- CONFIGURATION
local CONFIG = {
	DATASTORE_NAME = "MusicFavorites_v1",
	MAX_FAVORITES = 100,
	RETRY_ATTEMPTS = 3,
	RETRY_DELAY = 1,
	CACHE_DURATION = 300, -- 5 minutes
}

-- DATASTORE SETUP
local favoritesStore, favoritesWriteStore = DataStoreEnv.Get(CONFIG.DATASTORE_NAME)

-- INITIALIZATION
function MusicFavoriteManager.new()
	local self = setmetatable({}, MusicFavoriteManager)

	self.playerFavorites = {} -- Cache: [userId] = {musicIds = {}, lastUpdate = tick(), isDirty = bool}
	self.loadingQueue = {} -- Track loading states
	self.loaded = {} -- [userId] = true hanya jika DataStore berhasil dibaca

	-- Simpan perubahan berkala; jangan menunggu player leave saja.
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

-- DATASTORE OPERATIONS (WITH RETRY)
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
					-- Another server wrote newer favorites. Keep both additions.
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

-- LOAD PLAYER FAVORITES
function MusicFavoriteManager:LoadPlayerFavorites(userId)
	-- Check cache first. Cache yang dirty (ada perubahan lokal) tidak boleh
	-- ditimpa oleh hasil GetAsync yang lebih lama.
	local cached = self.playerFavorites[userId]
	local currentTime = tick()

	if cached and (cached.isDirty or (currentTime - cached.lastUpdate) < CONFIG.CACHE_DURATION) then
		self.loaded[userId] = true
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
			self.loaded[userId] = true
			return cached.musicIds
		end
	end

	-- Load from DataStore
	self.loadingQueue[userId] = true

	local key = "favorites_" .. tostring(userId)
	local loadSuccess, data = datastoreGetAsync(key)

	self.loadingQueue[userId] = nil

	if not loadSuccess then
		-- Jangan cache daftar kosong saat DataStore gagal: itu akan menimpa
		-- favorites lama ketika pemain menekan tombol Favorite.
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

	-- Cache the result hanya setelah load sukses.
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

-- SAVE PLAYER FAVORITES (ON LEAVE ONLY)
function MusicFavoriteManager:SavePlayerFavorites(userId)
	local cached = self.playerFavorites[userId]

	-- Only save if data exists and is dirty (modified)
	if not cached or not cached.isDirty then
		return true
	end

	-- Jangan pernah menyimpan cache yang belum berhasil dimuat dari DataStore.
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

-- GET PLAYER FAVORITES (FROM CACHE)
function MusicFavoriteManager:GetPlayerFavorites(userId)
	local cached = self.playerFavorites[userId]
	if cached then
		return cached.musicIds
	end

	return {}
end

-- ADD FAVORITE (IN-MEMORY ONLY)
function MusicFavoriteManager:AddFavorite(userId, musicId)
	if not self.loaded[userId] then
		local loaded = self:LoadPlayerFavorites(userId)
		if not loaded then
			return false, "Favorites masih dimuat, coba lagi sebentar lagi."
		end
	end

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
	local previous = self.playerFavorites[userId]
	self.playerFavorites[userId] = {
		musicIds = favorites,
		lastUpdate = tick(),
		remoteTimestamp = previous and previous.remoteTimestamp or 0,
		isDirty = true -- Mark for save on leave
	}

	return true, "Added to favorites"
end

-- REMOVE FAVORITE (IN-MEMORY ONLY)
function MusicFavoriteManager:RemoveFavorite(userId, musicId)
	if not self.loaded[userId] then
		local loaded = self:LoadPlayerFavorites(userId)
		if not loaded then
			return false, "Favorites masih dimuat, coba lagi sebentar lagi."
		end
	end

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
	local previous = self.playerFavorites[userId]
	self.playerFavorites[userId] = {
		musicIds = favorites,
		lastUpdate = tick(),
		remoteTimestamp = previous and previous.remoteTimestamp or 0,
		isDirty = true -- Mark for save on leave
	}

	return true, "Removed from favorites"
end

-- TOGGLE FAVORITE
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

-- IS FAVORITE
function MusicFavoriteManager:IsFavorite(userId, musicId)
	local favorites = self:GetPlayerFavorites(userId)

	for _, favId in ipairs(favorites) do
		if favId == musicId then
			return true
		end
	end

	return false
end

-- GET FAVORITE COUNT
function MusicFavoriteManager:GetFavoriteCount(userId)
	local favorites = self:GetPlayerFavorites(userId)
	return #favorites
end

-- CLEAR ALL FAVORITES
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
		self.loaded[userId] = true
		return true
	end

	return false
end

-- INVALIDATE CACHE
function MusicFavoriteManager:InvalidateCache(userId)
	self.playerFavorites[userId] = nil
end

-- CLEANUP PLAYER DATA (SAVE ON LEAVE)
function MusicFavoriteManager:CleanupPlayer(userId)
	-- Jangan hapus cache sebelum save benar-benar sukses. Jika DataStore
	-- sedang sibuk, retry beberapa kali agar favorites tidak hilang.
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

-- GET STATISTICS
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
