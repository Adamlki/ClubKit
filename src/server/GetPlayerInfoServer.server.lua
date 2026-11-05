local HttpService       = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService       = game:GetService("TextService")
local Players           = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local GroupService     = game:GetService("GroupService")

local RemoteEventManager = require(ServerScriptService:WaitForChild("Modules"):WaitForChild("RemoteEventManager"))
local GameConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("GameConfig"))
local AssetConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("AssetConfig"))

local remotes = ReplicatedStorage:WaitForChild("Remotes")

local getPlayerInfoRF = remotes:FindFirstChild("GetPlayerInfo")
if not getPlayerInfoRF then
	getPlayerInfoRF        = Instance.new("RemoteFunction")
	getPlayerInfoRF.Name   = "GetPlayerInfo"
	getPlayerInfoRF.Parent = remotes
end

local BASE_USERS   = "https://users.roproxy.com/v1/users/"
local BASE_FRIENDS = "https://friends.roproxy.com/v1/users/"

local CACHE_TTL       = 1800
local REQUEST_TIMEOUT = 5

local cache = {}
local profileLoadingLocks = {}
local activeProfileFetches = 0
local MAX_CONCURRENT_PROFILE_FETCHES = 2

local function getCached(userId)
	local entry = cache[userId]
	if not entry then return nil end
	if (os.clock() - entry.timestamp) > CACHE_TTL then
		cache[userId] = nil
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

local proxyCircuitOpenUntil = 0
local consecutiveErrors = 0
local CIRCUIT_BREAK_DURATION = 30
local lastHttpCallTime = 0
local MIN_HTTP_GAP = 0.15

local function httpGet(url)
	if os.clock() < proxyCircuitOpenUntil then
		return nil
	end

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
			if string.find(errorStr, "429") or string.find(errorStr, "Too Many Requests") then
				consecutiveErrors += 1
				if consecutiveErrors >= 4 then
					proxyCircuitOpenUntil = os.clock() + CIRCUIT_BREAK_DURATION
				end
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

local function fetchDescription(userId)
	local data = httpGet(BASE_USERS .. userId)
	return data and tostring(data.description or "") or ""
end

local function fetchFriendsCount(userId)
	local data = httpGet(BASE_FRIENDS .. userId .. "/friends/count")
	return data and (data.count or 0) or 0
end

local function fetchFollowersCount(userId)
	local data = httpGet(BASE_FRIENDS .. userId .. "/followers/count")
	return data and (data.count or 0) or 0
end

local function fetchFollowingCount(userId)
	local data = httpGet(BASE_FRIENDS .. userId .. "/followings/count")
	return data and (data.count or 0) or 0
end

local function filterBio(rawBio, fromUserId, toPlayer)
	if rawBio == "" then return "" end

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
		id = GameConfig.GroupId,
		name = GameConfig.Branding.GroupName,
		emblem = string.format("http://www.roblox.com/asset/?id=%d", AssetConfig.Images.DefaultCommunityId)
	}
end

local function cachedResponse(cached, userId, callerPlayer)
	return {
		description    = filterBio(cached.rawDescription, userId, callerPlayer),
		friendsCount   = cached.friendsCount,
		followersCount = cached.followersCount,
		followingCount = cached.followingCount,
		primaryGroup   = cached.primaryGroup,
	}
end

local function fetchPlayerInfo(userId, callerPlayer)
	local cached = getCached(userId)
	if cached then
		return cachedResponse(cached, userId, callerPlayer)
	end

	if profileLoadingLocks[userId] then
		local lockStart = os.clock()
		while profileLoadingLocks[userId] and (os.clock() - lockStart) < 10 do
			task.wait(0.1)
		end
		local afterWait = getCached(userId)
		if afterWait then
			return cachedResponse(afterWait, userId, callerPlayer)
		end
	end

	profileLoadingLocks[userId] = true

	while activeProfileFetches >= MAX_CONCURRENT_PROFILE_FETCHES do
		task.wait(0.05)
	end
	activeProfileFetches += 1

	local ok, result = pcall(function()
		local primaryGroup = fetchPrimaryGroup(userId)

		local rawDescription = ""
		local friendsCount   = 0
		local followersCount = 0
		local followingCount = 0

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

		setCached(userId, rawDescription, friendsCount, followersCount, followingCount, primaryGroup)

		return {
			description    = filterBio(rawDescription, userId, callerPlayer),
			friendsCount   = friendsCount,
			followersCount = followersCount,
			followingCount = followingCount,
			primaryGroup   = primaryGroup,
		}
	end)

	activeProfileFetches = math.max(0, activeProfileFetches - 1)
	profileLoadingLocks[userId] = nil

	if not ok then
		warn("[GetPlayerInfo] Fetch profile gagal untuk", userId, ":", tostring(result))
		return {
			description = "",
			friendsCount = 0,
			followersCount = 0,
			followingCount = 0,
			primaryGroup = { emblem = string.format("http://www.roblox.com/asset/?id=%d", AssetConfig.Images.DefaultCommunityId) },
		}
	end

	return result
end

getPlayerInfoRF.OnServerInvoke = function(callerPlayer, targetUserId)
	if not RemoteEventManager.checkRateLimit(callerPlayer, "getPlayerInfo") then
		return { description = "", friendsCount = 0, followersCount = 0, followingCount = 0 }
	end

	if type(targetUserId) ~= "number" or targetUserId <= 0 then
		warn("[GetPlayerInfo] UserId tidak valid:", tostring(targetUserId))
		return { description = "", friendsCount = 0, followersCount = 0, followingCount = 0 }
	end

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

task.spawn(function()
	while true do
		task.wait(300)
		local now = os.clock()

		for uid, entry in pairs(cache) do
			if now - entry.timestamp > CACHE_TTL then
				cache[uid] = nil
			end
		end
	end
end)
