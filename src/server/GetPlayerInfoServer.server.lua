local HttpService       = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService       = game:GetService("TextService")
local Players           = game:GetService("Players")

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

-- Cache TTL dalam detik — data dianggap fresh selama 5 menit.
-- Setelah TTL habis, data akan di-fetch ulang dari API.
local CACHE_TTL       = 300
local REQUEST_TIMEOUT = 8  -- detik maksimal menunggu semua parallel request

-- ============================================
-- CACHE SYSTEM
-- ============================================
--[[
    Struktur cache:
    cache[userId] = {
        rawDescription : string  -- bio mentah sebelum TextService filter
        friendsCount   : number
        followersCount : number
        followingCount : number
        timestamp      : number  -- tick() saat di-cache
    }

    Cara kerja:
    - Sebelum fetch API, cek apakah cache untuk userId masih fresh (< CACHE_TTL detik)
    - Jika fresh  → kembalikan cache langsung, tanpa HTTP request
    - Jika stale  → fetch ulang dari API, simpan ke cache
    - Saat player keluar → cache dihapus untuk hemat memori
]]
local cache = {}

local function getCached(userId)
	local entry = cache[userId]
	if not entry then return nil end
	if tick() - entry.timestamp > CACHE_TTL then
		cache[userId] = nil  -- expired, hapus
		return nil
	end
	return entry
end

local function setCached(userId, rawDescription, friendsCount, followersCount, followingCount)
	cache[userId] = {
		rawDescription = rawDescription,
		friendsCount   = friendsCount,
		followersCount = followersCount,
		followingCount = followingCount,
		timestamp      = tick(),
	}
end

-- Hapus cache saat player keluar untuk hemat memori
Players.PlayerRemoving:Connect(function(player)
	cache[player.UserId] = nil
end)

-- ============================================
-- HTTP HELPER
-- ============================================
--[[
    httpGet melakukan GET request ke URL dan decode JSON hasilnya.
    Retry otomatis 1 kali jika request pertama gagal,
    dengan jeda 1 detik antar percobaan untuk menangani error sementara.
    Mengembalikan table data jika sukses, nil jika gagal.
]]
local function httpGet(url)
	for attempt = 1, 2 do
		local ok, result = pcall(function()
			return HttpService:GetAsync(url, true) -- 
		end)

		if ok and result then
			local okJson, data = pcall(HttpService.JSONDecode, HttpService, result) -- 
			if okJson and data then
				return data
			end
		else
			-- 🔥 ARCHITECT FIX: Sembunyikan log jika proxy penuh (429), down (InvalidRedirect), atau ngelag (Timeout)
			local errorStr = tostring(result)
			if not string.find(errorStr, "429") and not string.find(errorStr, "InvalidRedirect") and not string.find(errorStr, "Timeout") then
				--warn(string.format("[GetPlayerInfo] HTTP gagal (attempt %d/2): %s | %s", attempt, url, errorStr)) 
			end
		end

		if attempt < 2 then 
			task.wait(2) -- Jeda diperpanjang menjadi 2 detik jika server sibuk 
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

	local ok, filterResult = pcall(function()
		return TextService:FilterStringAsync(
			rawBio,
			fromUserId,
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
]]
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
		}
	end

	-- Fetch sequentially dengan jeda agar roproxy tidak panik
	local rawDescription = ""
	local friendsCount   = 0
	local followersCount = 0
	local followingCount = 0

	rawDescription = fetchDescription(userId)
	task.wait(0.6)

	friendsCount = fetchFriendsCount(userId)
	task.wait(0.6)

	followersCount = fetchFollowersCount(userId)
	task.wait(0.6)

	followingCount = fetchFollowingCount(userId)

	-- Simpan raw ke cache sebelum filter
	setCached(userId, rawDescription, friendsCount, followersCount, followingCount)

	return {
		description    = filterBio(rawDescription, userId, callerPlayer),
		friendsCount   = friendsCount,
		followersCount = followersCount,
		followingCount = followingCount,
	}
end

-- ============================================
-- PRE-FETCH SAAT PLAYER JOIN
-- ============================================
--[[
    Saat player baru join, fetch & cache data mereka di background
    setelah 3 detik (agar tidak menahan proses loading).

    Manfaat:
    - Ketika player lain membuka menu profil player ini, data sudah
      ada di cache → tampil hampir instan
    - Request tersebar di waktu join, bukan burst saat menu dibuka
    - Mengurangi risiko rate limit roproxy
]]
--local function preFetchPlayer(player)
--	task.delay(3, function()
--		if not player or not player.Parent then return end
--		task.spawn(function()
--			local ok, err = pcall(fetchPlayerInfo, player.UserId, player)
--			if ok then
--				print("[GetPlayerInfo] Pre-cached:", player.Name)
--			else
--				warn("[GetPlayerInfo] Pre-fetch gagal untuk", player.Name, ":", err)
--			end
--		end)
--	end)
--end

--Players.PlayerAdded:Connect(preFetchPlayer)

---- Pre-fetch untuk player yang sudah ada saat script pertama jalan
--for _, player in ipairs(Players:GetPlayers()) do
--	task.spawn(function()
--		task.wait(1)
--		pcall(fetchPlayerInfo, player.UserId, player)
--	end)
--end

-- ============================================
-- REMOTE HANDLER
-- ============================================
getPlayerInfoRF.OnServerInvoke = function(callerPlayer, targetUserId)
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