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

-- Untuk mencegah Bug Race Condition saat pemain keluar-masuk terlalu cepat di server yang sama
local activeSaves = {}

-- ==========================================
-- COOLDOWN SYSTEM
-- ==========================================
function LikeManager.LoadPlayerCooldowns(player)
	local success, data = pcall(function()
		return CooldownsStore:GetAsync(tostring(player.UserId))
	end)
	
	if success then
		playerCooldownsCache[player.UserId] = data or {}
	else
		warn("[LikeManager] Gagal memuat cooldown untuk " .. player.Name)
		-- Jangan set ke {} jika gagal, biarkan nil agar kita tahu datanya rusak/belum load
	end
end

function LikeManager.SavePlayerCooldowns(player)
	local data = playerCooldownsCache[player.UserId]
	if data then
		local cleanedData = {}
		local currentTime = os.time()
		for targetId, expireTime in pairs(data) do
			if currentTime < expireTime then
				cleanedData[tostring(targetId)] = expireTime
			end
		end
		
		pcall(function()
			CooldownsStore:SetAsync(tostring(player.UserId), cleanedData)
		end)
	end
	playerCooldownsCache[player.UserId] = nil
end

-- ==========================================
-- LIKES SYSTEM (OPTIMIZED)
-- ==========================================
function LikeManager.LoadTotalLikes(player)
	local success, totalLikes = pcall(function()
		return LikesStore:GetAsync(tostring(player.UserId))
	end)
	
	totalLikes = totalLikes or 0
	
	if success then
		player:SetAttribute("TotalLikes", totalLikes)
		playerLikesCache[player.UserId] = totalLikes
		playerLoadedFlags[player.UserId] = true
	else
		warn("[LikeManager] Gagal memuat total likes untuk " .. player.Name)
		-- Jangan nge-set apapun agar data aslinya (yang mungkin masih 1000) tidak tertimpa jadi 0!
	end
end

function LikeManager.SaveTotalLikes(player)
	-- Hanya save JIKA data pemain sudah berhasil di-load saat dia masuk (Mencegah Data Loss Bug)
	if playerLoadedFlags[player.UserId] then
		local likesToSave = playerLikesCache[player.UserId]
		if likesToSave then
			pcall(function()
				LikesStore:SetAsync(tostring(player.UserId), likesToSave)
				-- Save to OrderedDataStore for Leaderboard (ignoring 0 likes if you want to save space, but saving 0 is fine, leaderboard will filter it)
				OrderedLikesStore:SetAsync(tostring(player.UserId), likesToSave)
			end)
		end
	end
	playerLikesCache[player.UserId] = nil
	playerLoadedFlags[player.UserId] = nil
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
	
	-- 2. Tambahkan Like ke Target (Hanya di Memory & Attribute agar tidak lag)
	local currentLikes = (playerLikesCache[targetPlayer.UserId] or 0) + 1
	playerLikesCache[targetPlayer.UserId] = currentLikes
	targetPlayer:SetAttribute("TotalLikes", currentLikes)
	
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
	-- Jika pemain keluar dan masuk dengan sangat cepat, tunggu sampai proses save sebelumnya selesai
	while activeSaves[player.UserId] do
		task.wait(0.1)
	end
	
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

-- Auto Save setiap 60 detik (Mencegah data hilang jika server crash)
task.spawn(function()
	while true do
		task.wait(60)
		for _, player in ipairs(Players:GetPlayers()) do
			-- Simpan diam-diam di background (Pcall untuk cegah error)
			local likesToSave = playerLikesCache[player.UserId]
			if likesToSave then
				pcall(function()
					LikesStore:SetAsync(tostring(player.UserId), likesToSave)
					OrderedLikesStore:SetAsync(tostring(player.UserId), likesToSave)
				end)
			end
			
			-- Simpan juga cooldown agar tidak hilang jika server crash tanpa BindToClose
			local cooldownData = playerCooldownsCache[player.UserId]
			if cooldownData then
				local cleanedData = {}
				local currentTime = os.time()
				for targetId, expireTime in pairs(cooldownData) do
					if currentTime < expireTime then
						cleanedData[tostring(targetId)] = expireTime
					end
				end
				pcall(function()
					CooldownsStore:SetAsync(tostring(player.UserId), cleanedData)
				end)
			end
			
			-- Beri jeda kecil antar pemain agar tidak kena Limit/Throttling dari Roblox DataStore
			task.wait(2)
		end
	end
end)

-- Mencegah data loss saat server mati
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

return LikeManager
