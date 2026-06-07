local DataStoreService = game:GetService("DataStoreService")

local DonaturRankSystem = {}

-- ====================================
-- STATE
-- ====================================
local dataStore  = nil
local rankCache  = {}
local loadingLocks = {} -- 🟢 BARU: Mencegah request ganda di waktu bersamaan

local DEBUG = false

local function log(...)
	if DEBUG then print("[DonaturRank]", ...) end
end

local function logWarn(...)
	if DEBUG then warn("[DonaturRank]", ...) end
end

-- ====================================
-- INIT
-- ====================================
function DonaturRankSystem:Init(config)
	DEBUG    = config.DEBUG_ENABLED or false
	dataStore = DataStoreService:GetDataStore(config.DONATUR_RANK_DATASTORE_NAME)
	log("Initialized - DataStore:", config.DONATUR_RANK_DATASTORE_NAME)
end

-- ====================================
-- LOAD RANK (dari DataStore, dengan cache & lock)
-- ====================================
function DonaturRankSystem:LoadRank(userId)
	-- 1. Cek jika sudah ada di cache
	local cached = rankCache[userId]
	if cached ~= nil then
		return cached ~= false and cached or nil
	end

	-- 2. 🟢 ANTI-SPAM LOCK: Jika script lain sedang mengambil data ini, tunggu!
	if loadingLocks[userId] then
		repeat task.wait(0.1) until loadingLocks[userId] == nil

		-- Setelah kunci dibuka, ambil dari cache
		local reCheck = rankCache[userId]
		return reCheck ~= false and reCheck or nil
	end

	-- Kunci request agar script lain tidak ikut-ikutan menembak DataStore
	loadingLocks[userId] = true 

	-- 3. Fetch dari DataStore
	local success, data = pcall(function()
		return dataStore:GetAsync(tostring(userId))
	end)

	-- Buka kunci karena data sudah didapat
	loadingLocks[userId] = nil 

	if success then
		if type(data) == "number" and data >= 1 and data <= 10 then
			rankCache[userId] = data
			log("Loaded rank", data, "for UserId:", userId)
			return data
		else
			rankCache[userId] = false
			log("No rank found for UserId:", userId)
			return nil
		end
	else
		logWarn("Failed to load rank for UserId:", userId, "-", data)
		return nil
	end
end

-- ====================================
-- GET RANK (cache-first, load jika belum)
-- ====================================
function DonaturRankSystem:GetRank(userId)
	local cached = rankCache[userId]
	if cached ~= nil then
		return cached ~= false and cached or nil
	end
	return self:LoadRank(userId)
end

-- ====================================
-- ASSIGN RANK (simpan ke DataStore)
-- ====================================
function DonaturRankSystem:AssignRank(userId, rank)
	local success, err = pcall(function()
		if rank then
			dataStore:SetAsync(tostring(userId), rank)
		else
			dataStore:RemoveAsync(tostring(userId))
		end
	end)

	if success then
		rankCache[userId] = rank or false
		log("Rank", rank or "removed", "for UserId:", userId)
		return true
	else
		logWarn("Failed to assign rank for UserId:", userId, "-", err)
		return false
	end
end

-- ====================================
-- REMOVE RANK
-- ====================================
function DonaturRankSystem:RemoveRank(userId)
	return self:AssignRank(userId, nil)
end

-- ====================================
-- PRELOAD (saat player join, load di background)
-- ====================================
function DonaturRankSystem:PreloadRank(userId)
	if rankCache[userId] ~= nil then return end

	task.spawn(function()
		-- 🟢 JEDA PINTAR: Tunggu 1 hingga 2 detik agar tidak bertabrakan dengan LevelSystem
		task.wait(math.random(10, 20) / 10) 
		self:LoadRank(userId)
	end)
end

-- ====================================
-- CLEAR CACHE (saat player leave)
-- ====================================
function DonaturRankSystem:ClearCache(userId)
	rankCache[userId] = nil
	loadingLocks[userId] = nil
end

-- ====================================
-- UPDATE CACHE LANGSUNG (tanpa DataStore)
-- ====================================
function DonaturRankSystem:UpdateCache(userId, rank)
	rankCache[userId] = rank or false
end

return DonaturRankSystem