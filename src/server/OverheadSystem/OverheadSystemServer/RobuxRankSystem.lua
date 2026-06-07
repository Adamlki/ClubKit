local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local DonationRankSystem = {}

-- ====================================
-- CONFIGURATION
-- ====================================
DonationRankSystem.Config = {
	DATASTORE_NAME = "GALAXY_DONATIONS",
	DONATIONS_KEY = "Donations",
	DONATIONS_SCOPE = "global",

	MAX_RETRIES = 3,
	-- 🟢 FIX: Naikkan ke 300 detik (5 menit) agar aman dari blokir Limit Roblox
	CACHE_DURATION = 300, 
	UPDATE_INTERVAL = 300, 

	TOP_RANKS_TO_TRACK = 10,
	DEBUG_ENABLED = false
}

-- ====================================
-- STORAGE
-- ====================================
local dataStore = nil
local cachedRankings = {}
local playerRankCache = {}
local lastFetchTime = 0
local isStudioMode = false

-- ====================================
-- EVENTS
-- ====================================
local rankChangedEvent = Instance.new("BindableEvent")
rankChangedEvent.Name = "RankChanged"
DonationRankSystem.RankChanged = rankChangedEvent.Event

-- ====================================
-- DEBUG SYSTEM
-- ====================================
local function debug(...)
	if DonationRankSystem.Config.DEBUG_ENABLED then
		print("[DonationRank]", ...)
	end
end

local function debugWarn(...)
	if DonationRankSystem.Config.DEBUG_ENABLED then
		warn("[DonationRank]", ...)
	end
end

-- ====================================
-- INITIALIZATION
-- ====================================
function DonationRankSystem:Init()
	-- Detect environment
	isStudioMode = RunService:IsStudio() or game.PlaceId == 0

	-- Initialize datastore
	dataStore = DataStoreService:GetDataStore(
		self.Config.DATASTORE_NAME, 
		self.Config.DONATIONS_SCOPE
	)

	debug("Initialized - Mode:", isStudioMode and "Studio" or "Live")

	-- Start auto-update loop
	self:StartAutoUpdate()
end

-- ====================================
-- FETCH RANKINGS FROM DATASTORE
-- ====================================
function DonationRankSystem:FetchRankings()
	-- Check cache
	if cachedRankings and #cachedRankings > 0 then
		local timeSinceLastFetch = os.time() - lastFetchTime
		if timeSinceLastFetch < self.Config.CACHE_DURATION then
			debug("Using cached rankings (age:", timeSinceLastFetch, "seconds)")
			return cachedRankings
		end
	end

	debug("Fetching fresh rankings from DataStore...")

	local donationsDoc = nil

	-- Fetch donations document with retry
	for attempt = 1, self.Config.MAX_RETRIES do
		local success, result = pcall(function()
			return dataStore:GetAsync(self.Config.DONATIONS_KEY)
		end)

		if success then
			if result then
				donationsDoc = result
				break
			else
				debugWarn("GetAsync returned nil (key not found or empty)")
			end
		else
			debugWarn("Fetch attempt", attempt, "failed:", result)
		end

		if attempt < self.Config.MAX_RETRIES then
			task.wait(1)
		end
	end

	if not donationsDoc then
		debugWarn("Failed to fetch donation data")
		return {}
	end

	-- Parse users from document
	local donors = {}
	local donationField = isStudioMode and "Donated - Studio" or "Donated - Experience"

	for key, value in pairs(donationsDoc) do
		-- Skip meta fields
		if type(value) == "table" 
			and tonumber(key) 
			and value[donationField] then

			local amount = value[donationField]

			-- Skip if amount is 0
			if amount > 0 then
				table.insert(donors, {
					UserId = tonumber(key),
					DisplayName = value.DisplayName or value.Name or "User" .. key,
					Amount = amount
				})
			end
		end
	end

	if #donors == 0 then
		debug("No donors found")
		return {}
	end

	-- Sort by amount (descending)
	table.sort(donors, function(a, b)
		return a.Amount > b.Amount
	end)

	-- Assign ranks (only top N)
	local rankings = {}
	for i = 1, math.min(self.Config.TOP_RANKS_TO_TRACK, #donors) do
		donors[i].Rank = i
		rankings[i] = donors[i]
	end

	-- Update cache
	cachedRankings = rankings
	lastFetchTime = os.time()

	debug("Fetched", #rankings, "top donors")

	return rankings
end

-- ====================================
-- GET PLAYER RANK
-- ====================================
function DonationRankSystem:GetPlayerRank(userId)
	-- Check cache first
	if playerRankCache[userId] then
		return playerRankCache[userId]
	end

	-- Fetch fresh rankings
	local rankings = self:FetchRankings()

	-- Find player in rankings
	for _, donor in ipairs(rankings) do
		if donor.UserId == userId then
			playerRankCache[userId] = donor.Rank
			return donor.Rank
		end
	end

	-- Not in top rankings
	return nil
end

-- ====================================
-- CHECK IF RANK CHANGED
-- ====================================
function DonationRankSystem:CheckRankChanges()
	local oldCache = playerRankCache
	local newRankings = self:FetchRankings()

	-- Build new cache
	local newCache = {}
	for _, donor in ipairs(newRankings) do
		newCache[donor.UserId] = donor.Rank
	end

	-- Detect changes
	local changedPlayers = {}

	-- Check for rank changes in new rankings
	for userId, newRank in pairs(newCache) do
		local oldRank = oldCache[userId]
		if oldRank ~= newRank then
			table.insert(changedPlayers, {
				UserId = userId,
				OldRank = oldRank,
				NewRank = newRank
			})
		end
	end

	-- Check for players who lost their rank
	for userId, oldRank in pairs(oldCache) do
		if not newCache[userId] then
			table.insert(changedPlayers, {
				UserId = userId,
				OldRank = oldRank,
				NewRank = nil
			})
		end
	end

	-- Update cache
	playerRankCache = newCache

	-- Fire events for changes
	for _, change in ipairs(changedPlayers) do
		rankChangedEvent:Fire(change.UserId, change.OldRank, change.NewRank)
		debug("Rank changed - UserId:", change.UserId, "Old:", change.OldRank, "New:", change.NewRank)
	end

	return changedPlayers
end

-- ====================================
-- AUTO UPDATE SYSTEM (OPTIMIZED)
-- ====================================
function DonationRankSystem:StartAutoUpdate()
	task.spawn(function()
		-- Initial fetch
		task.wait(2)
		self:FetchRankings()

		-- Build initial cache
		local rankings = cachedRankings
		for _, donor in ipairs(rankings) do
			playerRankCache[donor.UserId] = donor.Rank
		end
		debug("Initial rankings cached")

		-- Auto-update loop
		while true do
			task.wait(self.Config.UPDATE_INTERVAL)

			-- 🟢 FIX: Hemat API! Kalau server lagi tidak ada orang, tidak usah request DataStore
			if #game:GetService("Players"):GetPlayers() > 0 then
				debug("Auto-update: Checking for rank changes...")
				local changes = self:CheckRankChanges()

				if #changes > 0 then
					debug("Found", #changes, "rank changes")
				else
					debug("No rank changes detected")
				end
			else
				debug("Server empty, skipping update to save DataStore limits")
			end
		end
	end)
end

-- ====================================
-- CLEAR CACHE (FORCE REFRESH)
-- ====================================
function DonationRankSystem:ClearCache()
	cachedRankings = {}
	playerRankCache = {}
	lastFetchTime = 0
	debug("Cache cleared")
end

-- ====================================
-- GET ALL TOP RANKINGS
-- ====================================
function DonationRankSystem:GetTopRankings()
	return self:FetchRankings()
end

-- ====================================
-- FORCE MODE (FOR TESTING)
-- ====================================
function DonationRankSystem:SetStudioMode(enabled)
	isStudioMode = enabled
	self:ClearCache()
	debug("Studio mode:", enabled and "ON" or "OFF")
end

return DonationRankSystem