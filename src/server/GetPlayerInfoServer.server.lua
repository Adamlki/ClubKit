local HttpService       = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService       = game:GetService("TextService")
local Players           = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local GroupService     = game:GetService("GroupService")

local RemoteEventManager = require(ServerScriptService:WaitForChild("Modules"):WaitForChild("RemoteEventManager"))

-- ============================================
-- SETUP REMOTE
-- ============================================
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local getPlayerInfoRF = remotes:FindFirstChild("GetPlayerInfo")
if not getPlayerInfoRF then
	getPlayerInfoRF        = Instance.new("RemoteFunction")
	getPlayerInfoRF.Name   = "GetPlayerInfo"
	getPlayerInfoRF.Parent = remotes
end

-- ============================================
-- CONSTANTS
-- ============================================

-- roproxy adalah mirror publik API Roblox yang aman dipakai dari dalam game.
-- Roblox memblokir direct call ke *.roblox.com dari HttpService,
-- sehingga roproxy.com digunakan sebagai proxy pass-through.
local BASE_USERS   = "https://users.roproxy.com/v1/users/"
local BASE_FRIENDS = "https://friends.roproxy.com/v1/users/"

-- Cache TTL dalam detik — data disimpan selama 30 menit (menghemat kuota & anti-429).
local CACHE_TTL       = 1800
local REQUEST_TIMEOUT = 5  -- detik maksimal menunggu request roproxy

-- ============================================
-- CACHE SYSTEM
-- ============================================
local cache = {}

local function getCached(userId)
	local entry = cache[userId]
	if not entry then return nil end
	if (os.clock() - entry.timestamp) > CACHE_TTL then
		cache[userId] = nil  -- expired, hapus
		return nil
	end
	return entry
end

local function setCached(userId, rawDescription, friendsCount, followersCount, followingCount, primaryGroup)
	cache[userId] = {
		rawDescription = rawDescription,
		friendsCount   = friendsCount,
		followersCount = followersCount,
		followingCount = followingCount,
		primaryGroup   = primaryGroup,
		timestamp      = os.clock(),
	}
end

-- ============================================
-- HTTP HELPER DENGAN GLOBAL PACING & CIRCUIT BREAKER
-- ============================================
local proxyCircuitOpenUntil = 0
local consecutiveErrors = 0
local CIRCUIT_BREAK_DURATION = 30 -- Jeda 30 detik jika proxy down/terkena hard rate limit
local lastHttpCallTime = 0
local MIN_HTTP_GAP = 0.15 -- Jeda minimal 150ms antar outbound request ke RoProxy untuk anti-429

local function httpGet(url)
	-- Jika circuit breaker aktif, jangan kirim HTTP request ke proxy sama sekali
	if os.clock() < proxyCircuitOpenUntil then
		return nil
	end

	-- 🛡️ GLOBAL PACING: Beri jeda minimal 150ms agar RoProxy tidak memblokir IP Roblox (HTTP 429)
	local timeSinceLast = os.clock() - lastHttpCallTime
	if timeSinceLast < MIN_HTTP_GAP then
		task.wait(MIN_HTTP_GAP - timeSinceLast)
	end
	lastHttpCallTime = os.clock()

	for attempt = 1, 2 do
		local ok, result = pcall(function()
			return HttpService:GetAsync(url, true)
		end)

		if ok and result then
			local okJson, data = pcall(HttpService.JSONDecode, HttpService, result)
			if okJson and data then
				consecutiveErrors = 0
				return data
			end
		else
			local errorStr = tostring(result)
			-- Jika terkena rate limit (429), jangan retry agresif dan catat error
			if string.find(errorStr, "429") or string.find(errorStr, "Too Many Requests") then
				consecutiveErrors += 1
				if consecutiveErrors >= 4 then
					proxyCircuitOpenUntil = os.clock() + CIRCUIT_BREAK_DURATION
				end
				-- Beri jeda backoff jika 429
				task.wait(1.5 + math.random() * 0.5)
				break
			elseif string.find(errorStr, "Timeout") then
				consecutiveErrors += 1
				if consecutiveErrors >= 5 then
					proxyCircuitOpenUntil = os.clock() + CIRCUIT_BREAK_DURATION
				end
			else
				consecutiveErrors += 1
				if consecutiveErrors >= 6 then
					proxyCircuitOpenUntil = os.clock() + CIRCUIT_BREAK_DURATION
				end
			end
		end

		if attempt < 2 then 
			task.wait(1.0)
		end
	end
	return nil
end

-- ============================================
-- API FETCH FUNCTIONS
-- ============================================

--[[
    Endpoint : GET users.roproxy.com/v1/users/{userId}
    Response :
    {
      "description" : "Bio player",
      "id"          : 123456,
      "name"        : "Username",
      "displayName" : "DisplayName",
      "isBanned"    : false,
      "created"     : "2015-01-01T00:00:00Z"
    }
    Kita ambil field "description" saja.
]]
local function fetchDescription(userId)
	local data = httpGet(BASE_USERS .. userId)
	return data and tostring(data.description or "") or ""
end

--[[
    Endpoint : GET friends.roproxy.com/v1/users/{userId}/friends/count
    Response : { "count": 123 }
]]
local function fetchFriendsCount(userId)
	local data = httpGet(BASE_FRIENDS .. userId .. "/friends/count")
	return data and (data.count or 0) or 0
end

--[[
    Endpoint : GET friends.roproxy.com/v1/users/{userId}/followers/count
    Response : { "count": 4821 }
]]
local function fetchFollowersCount(userId)
	local data = httpGet(BASE_FRIENDS .. userId .. "/followers/count")
	return data and (data.count or 0) or 0
end

--[[
    Endpoint : GET friends.roproxy.com/v1/users/{userId}/followings/count
    Response : { "count": 310 }
]]
local function fetchFollowingCount(userId)
	local data = httpGet(BASE_FRIENDS .. userId .. "/followings/count")
	return data and (data.count or 0) or 0
end

-- ============================================
-- BIO FILTER
-- ============================================
--[[
    TextService:FilterStringAsync WAJIB dipakai sesuai Roblox ToS
    untuk setiap string eksternal sebelum ditampilkan ke player lain.

    - fromUserId  : UserId pemilik teks (userId target profil)
    - toPlayer    : player yang akan melihat teks ini

    Jika filter gagal → kembalikan string kosong (fail-safe).
    Lebih aman menampilkan kosong daripada konten yang belum difilter.

    rawBio disimpan di cache dan difilter ulang per caller karena
    hasil filter bisa berbeda tergantung setting akun penerima
    (misal akun di bawah 13 tahun mendapat filter lebih ketat).
]]
local function filterBio(rawBio, fromUserId, toPlayer)
	if rawBio == "" then return "" end

	-- FilterStringAsync mewajibkan sender berada di server saat ini
	local senderId = fromUserId
	if not Players:GetPlayerByUserId(fromUserId) and toPlayer then
		senderId = toPlayer.UserId
	end

	local ok, filterResult = pcall(function()
		return TextService:FilterStringAsync(
			rawBio,
			senderId,
			Enum.TextFilterContext.PublicChat
		)
	end)

	if not ok then
		warn("[GetPlayerInfo] FilterStringAsync gagal:", filterResult)
		return ""
	end

	local okGet, filtered = pcall(function()
		return filterResult:GetNonChatStringForUserAsync(toPlayer.UserId)
	end)

	return (okGet and filtered) and filtered or ""
end

-- ============================================
-- MAIN FETCH FUNCTION
-- ============================================
--[[
    fetchPlayerInfo mengambil semua data sosial secara paralel (task.spawn),
    lalu menunggu semua selesai sebelum return.

    Paralel vs Sequential:
    - Sequential : ~3–6 detik (4 request satu per satu)
    - Paralel    : ~0.5–1.5 detik (4 request bersamaan)

    Return table:
    {
        description    : string  (sudah difilter TextService)
        friendsCount   : number
        followersCount : number
        followingCount : number
    }
--[[
    Ambil grup utama (Primary Group) atau grup pertama pemain menggunakan GroupService resmi Roblox.
    GroupService tidak menggunakan roproxy sehingga 100% cepat dan aman dari 429.
]]
local function fetchPrimaryGroup(userId)
	local ok, groups = pcall(function()
		return GroupService:GetGroupsAsync(userId)
	end)
	if ok and type(groups) == "table" then
		for _, g in ipairs(groups) do
			if g.IsPrimary then
				return {
					id = g.Id,
					name = g.Name,
					emblem = g.EmblemUrl or ("rbxthumb://type=GroupIcon&id=" .. g.Id .. "&w=420&h=420")
				}
			end
		end
		if #groups > 0 then
			local g = groups[1]
			return {
				id = g.Id,
				name = g.Name,
				emblem = g.EmblemUrl or ("rbxthumb://type=GroupIcon&id=" .. g.Id .. "&w=420&h=420")
			}
		end
	end
	return {
		id = 192828493,
		name = "DMS STUDIO",
		emblem = "http://www.roblox.com/asset/?id=100615948228188"
	}
end

local function fetchPlayerInfo(userId, callerPlayer)
	-- Cek cache terlebih dahulu
	local cached = getCached(userId)
	if cached then
		return {
			-- Filter ulang per caller karena hasil filter bergantung pada penerima
			description    = filterBio(cached.rawDescription, userId, callerPlayer),
			friendsCount   = cached.friendsCount,
			followersCount = cached.followersCount,
			followingCount = cached.followingCount,
			primaryGroup   = cached.primaryGroup,
		}
	end

	-- Fetch primary group via native GroupService (super fast & reliable)
	local primaryGroup = fetchPrimaryGroup(userId)

	local rawDescription = ""
	local friendsCount   = 0
	local followersCount = 0
	local followingCount = 0

	-- Cek circuit breaker roproxy
	if os.clock() >= proxyCircuitOpenUntil then
		local completedTasks = 0
		task.spawn(function()
			rawDescription = fetchDescription(userId)
			completedTasks += 1
		end)

		task.wait(0.1)
		task.spawn(function()
			friendsCount = fetchFriendsCount(userId)
			completedTasks += 1
		end)

		task.wait(0.1)
		task.spawn(function()
			followersCount = fetchFollowersCount(userId)
			completedTasks += 1
		end)

		task.wait(0.1)
		task.spawn(function()
			followingCount = fetchFollowingCount(userId)
			completedTasks += 1
		end)

		local startTime = os.clock()
		while completedTasks < 4 and (os.clock() - startTime) < 3.5 do
			task.wait(0.05)
		end
	end

	-- Simpan ke cache agar TIDAK PERNAH request berulang kali (Anti-Lag, Anti-429)
	setCached(userId, rawDescription, friendsCount, followersCount, followingCount, primaryGroup)

	return {
		description    = filterBio(rawDescription, userId, callerPlayer),
		friendsCount   = friendsCount,
		followersCount = followersCount,
		followingCount = followingCount,
		primaryGroup   = primaryGroup,
	}
end

-- ============================================
-- ON-DEMAND FETCH ONLY (OPTIMASI 50+ PLAYERS)
-- ============================================
-- Pre-fetch otomatis saat join dinonaktifkan agar server tidak memborbardir Roproxy
-- dengan ratusan request saat 50 pemain bergabung (mencegah HTTP 429 & Timeout).
-- Data hanya di-fetch secara lazy/on-demand saat ada pemain yang membuka menu profil.

-- ============================================
-- REMOTE HANDLER
-- ============================================
getPlayerInfoRF.OnServerInvoke = function(callerPlayer, targetUserId)
	-- 🔥 SECURITY FIX: Anti-DDoS Rate Limiter untuk Mencegah Server IP diblokir (Error 429) oleh API Roproxy
	if not RemoteEventManager.checkRateLimit(callerPlayer, "getPlayerInfo") then
		return { description = "", friendsCount = 0, followersCount = 0, followingCount = 0 }
	end

	-- Validasi input
	if type(targetUserId) ~= "number" or targetUserId <= 0 then
		warn("[GetPlayerInfo] UserId tidak valid:", tostring(targetUserId))
		return { description = "", friendsCount = 0, followersCount = 0, followingCount = 0 }
	end

	-- Pastikan caller masih di game
	if not callerPlayer or not callerPlayer.Parent then
		return { description = "", friendsCount = 0, followersCount = 0, followingCount = 0 }
	end

	local ok, result = pcall(fetchPlayerInfo, targetUserId, callerPlayer)

	if ok and result then
		return result
	else
		warn("[GetPlayerInfo] Error:", tostring(result))
		return { description = "", friendsCount = 0, followersCount = 0, followingCount = 0 }
	end
end

-- ============================================
-- GARBAGE COLLECTOR (ANTI RAM LEAK)
-- ============================================
-- Membersihkan data cache dari pemain OFFLINE yang tidak terjangkau oleh PlayerRemoving
task.spawn(function()
	while true do
		task.wait(300) -- Berpatroli setiap 5 menit
		local now = os.clock()
		local deletedCount = 0
		
		for uid, entry in pairs(cache) do
			if now - entry.timestamp > CACHE_TTL then
				cache[uid] = nil
				deletedCount += 1
			end
		end
		
		if deletedCount > 0 then
			-- print("[GetPlayerInfo] Garbage Collector membersihkan " .. deletedCount .. " cache offline.")
		end
	end
end)