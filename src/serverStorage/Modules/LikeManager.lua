local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local LikeManager = {}

local LikesStore = DataStoreService:GetDataStore("PlayerLikes_v1")
local OrderedLikesStore = DataStoreService:GetOrderedDataStore("PlayerLikes_Ordered_v1")
local CooldownsStore = DataStoreService:GetDataStore("LikeCooldowns_v1")

local COOLDOWN_DURATION = 86400 -- 24 jam (dalam detik)

-- Memory Cache
local playerCooldownsCache = {}
local playerLikesCache = {} -- Menyimpan data like sementara sebelum di-save
local playerLoadedFlags = {} -- Mencegah data loss jika GetAsync gagal
local playerDirtyFlags = {} -- Dirty checking untuk TotalLikes penerima like
local cooldownDirtyFlags = {} -- Dirty checking untuk cooldown pengirim like

-- Untuk mencegah Bug Race Condition saat pemain keluar-masuk terlalu cepat di server yang sama
local activeSaves = {}

-- ==========================================
-- COOLDOWN SYSTEM
-- ==========================================
function LikeManager.LoadPlayerCooldowns(player)
	local success, data = pcall(function()
		return CooldownsStore:GetAsync(tostring(player.UserId))
	end)
	-- FIX KELUAR-MASUK KILAT: Jangan simpan ke cache jika pemain sudah keluar saat GetAsync sedang berjalan
	if not player or not player.Parent then return end
	
	if success then
		playerCooldownsCache[player.UserId] = data or {}
	else
		warn("[LikeManager] Gagal memuat cooldown untuk " .. player.Name)
	end
end

function LikeManager.SavePlayerCooldowns(player)
	local userId = player.UserId
	if cooldownDirtyFlags[userId] then
		local data = playerCooldownsCache[userId]
		if data then
			local cleanedData = {}
			local currentTime = os.time()
			for targetId, expireTime in pairs(data) do
				if currentTime < expireTime then
					cleanedData[tostring(targetId)] = expireTime
				end
			end
			
			local ok = pcall(function()
				CooldownsStore:SetAsync(tostring(userId), cleanedData)
			end)
			if ok then
				cooldownDirtyFlags[userId] = nil
			end
		else
			cooldownDirtyFlags[userId] = nil
		end
	end
	playerCooldownsCache[userId] = nil
end

-- ==========================================
-- LIKES SYSTEM (OPTIMIZED)
-- ==========================================
function LikeManager.LoadTotalLikes(player)
	local success, totalLikes = pcall(function()
		return LikesStore:GetAsync(tostring(player.UserId))
	end)
	-- FIX KELUAR-MASUK KILAT: Jangan isi cache jika pemain sudah disconnect saat GetAsync berjalan
	if not player or not player.Parent then return end
	
	totalLikes = totalLikes or 0
	
	if success then
		player:SetAttribute("TotalLikes", totalLikes)
		playerLikesCache[player.UserId] = totalLikes
		playerLoadedFlags[player.UserId] = true
	else
		warn("[LikeManager] Gagal memuat total likes untuk " .. player.Name)
	end
end

function LikeManager.SaveTotalLikes(player)
	local userId = player.UserId
	-- Hanya save JIKA data pemain sudah berhasil di-load saat dia masuk (Mencegah Data Loss Bug)
	if playerLoadedFlags[userId] and playerDirtyFlags[userId] then
		local likesToSave = playerLikesCache[userId]
		if likesToSave ~= nil then
			local ok1 = pcall(function()
				LikesStore:SetAsync(tostring(userId), likesToSave)
			end)
			local ok2 = pcall(function()
				OrderedLikesStore:SetAsync(tostring(userId), likesToSave)
			end)
			if ok1 and ok2 then
				playerDirtyFlags[userId] = nil -- Hanya reset dirty flag jika kedua SetAsync sukses
			end
		else
			playerDirtyFlags[userId] = nil
		end
	end
	playerLikesCache[userId] = nil
	playerLoadedFlags[userId] = nil
end

-- ==========================================
-- LIKE LOGIC
-- ==========================================
function LikeManager.CanLikePlayer(liker, targetPlayer)
	local likerId = liker.UserId
	local targetId = tostring(targetPlayer.UserId)
	
	if likerId == targetPlayer.UserId then
		return false, "Tidak bisa melike diri sendiri!"
	end
	
	-- Cek apakah data liker sudah termuat
	local cooldowns = playerCooldownsCache[likerId]
	if not cooldowns then
		return false, "Data kamu masih loading, sabar ya!"
	end
	
	-- Cek apakah data target sudah termuat (Mencegah Race Condition Overwrite Bug)
	if not playerLoadedFlags[targetPlayer.UserId] then
		return false, "Data pemain ini masih loading!"
	end
	
	local expireTime = cooldowns[targetId]
	if expireTime then
		local remaining = expireTime - os.time()
		if remaining > 0 then
			return false, remaining
		end
	end
	
	return true, 0
end

function LikeManager.ProcessLike(liker, targetPlayer)
	local canLike, result = LikeManager.CanLikePlayer(liker, targetPlayer)
	if not canLike then
		return false, result
	end
	
	local likerId = liker.UserId
	local targetId = tostring(targetPlayer.UserId)
	
	-- 1. Terapkan Cooldown ke pengirim
	playerCooldownsCache[likerId][targetId] = os.time() + COOLDOWN_DURATION
	
	-- 2. Increment total likes untuk penerima
	playerLikesCache[targetPlayer.UserId] = (playerLikesCache[targetPlayer.UserId] or 0) + 1
	targetPlayer:SetAttribute("TotalLikes", playerLikesCache[targetPlayer.UserId])
	
	-- FIX QUOTA DATASTORE: Jangan set playerDirtyFlags[likerId] = true karena TotalLikes pengirim tidak berubah!
	cooldownDirtyFlags[likerId] = true
	playerDirtyFlags[targetPlayer.UserId] = true

	-- Increment Daily Likes OrderedDataStore
	task.spawn(function()
		local dailyKey = "PlayerLikes_Daily_" .. os.date("!%Y_%m_%d")
		local dailyStore = DataStoreService:GetOrderedDataStore(dailyKey)
		pcall(function()
			dailyStore:IncrementAsync(targetId, 1)
		end)
	end)
	
	return true, "Success"
end

function LikeManager.GetCooldownEndTime(liker, targetPlayer)
	local likerId = liker.UserId
	local targetId = tostring(targetPlayer.UserId)
	
	local cooldowns = playerCooldownsCache[likerId]
	if cooldowns and cooldowns[targetId] then
		return cooldowns[targetId]
	end
	return 0
end

-- ==========================================
-- EVENTS
-- ==========================================
Players.PlayerAdded:Connect(function(player)
	-- FIX MASUK BARENGAN 100 PEMAIN: Beri jeda acak 1-4 detik agar tidak tabrakan dengan GetAsync Role & Level di detik ke-0
	task.wait(math.random(10, 40) / 10)
	if not player or not player.Parent then return end

	-- Jika pemain keluar dan masuk dengan sangat cepat, tunggu sampai proses save sebelumnya selesai
	local waited = 0
	while activeSaves[player.UserId] and waited < 10 do
		waited += task.wait(0.1)
	end
	if not player or not player.Parent then return end
	
	LikeManager.LoadTotalLikes(player)
	LikeManager.LoadPlayerCooldowns(player)
end)

Players.PlayerRemoving:Connect(function(player)
	local userId = player.UserId
	activeSaves[userId] = true
	
	LikeManager.SaveTotalLikes(player)
	LikeManager.SavePlayerCooldowns(player)
	
	activeSaves[userId] = nil
end)

-- Auto Save setiap 300 detik (5 menit) agar DataStore limit tidak over
task.spawn(function()
	while true do
		task.wait(300)
		for _, player in ipairs(Players:GetPlayers()) do
			local userId = player.UserId
			local didWrite = false

			if playerLoadedFlags[userId] and playerDirtyFlags[userId] then
				local likesToSave = playerLikesCache[userId]
				if likesToSave ~= nil then
					local ok1 = pcall(function()
						LikesStore:SetAsync(tostring(userId), likesToSave)
					end)
					local ok2 = pcall(function()
						OrderedLikesStore:SetAsync(tostring(userId), likesToSave)
					end)
					if ok1 and ok2 then
						playerDirtyFlags[userId] = nil
					end
					didWrite = true
				end
			end

			local cooldownData = playerCooldownsCache[userId]
			if cooldownData and cooldownDirtyFlags[userId] then
				local cleanedData = {}
				local currentTime = os.time()
				for targetId, expireTime in pairs(cooldownData) do
					if currentTime < expireTime then
						cleanedData[tostring(targetId)] = expireTime
					end
				end
				local okCd = pcall(function()
					CooldownsStore:SetAsync(tostring(userId), cleanedData)
				end)
				if okCd then
					cooldownDirtyFlags[userId] = nil
				end
				didWrite = true
			end

			if didWrite then
				-- Beri jeda 1 detik antar pemain yang melakukan SetAsync agar tidak kena Throttling
				task.wait(1)
			end
		end
	end
end)

-- Mencegah data loss saat server mati
local RunService = game:GetService("RunService")
if RunService:IsServer() and RunService:IsRunning() then
	pcall(function()
		game:BindToClose(function()
			local players = Players:GetPlayers()
			local totalPlayers = #players
			local completed = 0

			for i, player in ipairs(players) do
				task.spawn(function()
					LikeManager.SaveTotalLikes(player)
					LikeManager.SavePlayerCooldowns(player)
					completed += 1
				end)
				
				-- Beri napas ke API Roblox tiap 10 pemain (Anti-Throttle)
				if i % 10 == 0 then
					task.wait(0.2)
				end
			end
			
			-- Tahan server jangan mati sebelum data diselamatkan (maks 15 detik)
			local elapsed = 0
			while completed < totalPlayers and elapsed < 15 do
				task.wait(1)
				elapsed += 1
			end
		end)
	end)
end

return LikeManager
