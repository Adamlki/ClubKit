--!native
--!optimize 2
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players           = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local LeaderboardRegistry = require(ServerScriptService:WaitForChild("Modules"):WaitForChild("LeaderboardRegistry"))
local DonationLeaderboard = require(script.DonationLeaderboard)

local REFRESH_INTERVAL = 120   -- detik antar refresh otomatis (dinaikkan ke 120 untuk mencegah rate limit)
local TOP_ENTRIES      = 100

-- ============================================
-- REMOTE
-- ============================================
local updateTopBoardRemote = ReplicatedStorage:FindFirstChild("UpdateTopBoard")
	or (function()
		local r = Instance.new("RemoteEvent")
		r.Name   = "UpdateTopBoard"
		r.Parent = ReplicatedStorage
		return r
	end)()

-- ============================================
-- INISIALISASI
-- ============================================
local leaderboard = DonationLeaderboard.new()

-- ============================================
-- MANUAL CONTROL (DIPINDAHKAN KE ATAS)
-- ============================================
_G.LeaderboardControl = {
	Refresh = function()
		leaderboard:ClearCache()
		updateLeaderboard()
	end,
	ShowStudio = function()
		leaderboard:SetMode(true)
		updateLeaderboard()
	end,
	ShowExperience = function()
		leaderboard:SetMode(false)
		updateLeaderboard()
	end,
	GetData = function()
		return leaderboard:GetTopDonors(TOP_ENTRIES)
	end,
}

-- ============================================
-- STATE (CACHE) - OPTIMASI UNTUK 100 PLAYER
-- ============================================
local cachedDonors = {}

-- ============================================
-- HELPER
-- ============================================
local function buildNetworkData(donors)
	local data = {}
	for i = 1, math.min(TOP_ENTRIES, #donors) do
		data[i] = {
			UserId      = donors[i].UserId,
			DisplayName = donors[i].DisplayName,
			Username    = donors[i].Username,
			Amount      = donors[i].Amount,
			Rank        = donors[i].Rank,
		}
	end
	return data
end

-- ============================================
-- UPDATE LEADERBOARD (GLOBAL)
-- ============================================
local function isDataDifferent(oldPayload, newPayload)
	if not oldPayload or not newPayload then return true end
	local oldAll = oldPayload.AllTime or {}
	local newAll = newPayload.AllTime or {}
	if #oldAll ~= #newAll then return true end
	for i = 1, math.min(10, #newAll) do
		local o, n = oldAll[i], newAll[i]
		if not o or not n then return true end
		if (o.userId or o.UserId) ~= (n.userId or n.UserId) or (o.amount or o.Amount) ~= (n.amount or n.Amount) then
			return true
		end
	end
	local oldDaily = oldPayload.Daily or {}
	local newDaily = newPayload.Daily or {}
	if #oldDaily ~= #newDaily then return true end
	for i = 1, math.min(10, #newDaily) do
		local o, n = oldDaily[i], newDaily[i]
		if not o or not n then return true end
		if (o.userId or o.UserId) ~= (n.userId or n.UserId) or (o.amount or o.Amount) ~= (n.amount or n.Amount) then
			return true
		end
	end
	return false
end

function updateLeaderboard()
	local ok, donors = pcall(function()
		return leaderboard:GetTopDonors(TOP_ENTRIES)
	end)
	local okDaily, dailyDonors = pcall(function()
		return leaderboard:GetTopDailyDonors(TOP_ENTRIES)
	end)

	local allTimeData = (ok and donors) and buildNetworkData(donors) or {}
	local dailyData   = (okDaily and dailyDonors) and buildNetworkData(dailyDonors) or {}

	local newPayload = {
		AllTime = allTimeData,
		Daily   = dailyData,
	}

	local hasChanged = isDataDifferent(cachedDonors, newPayload)
	cachedDonors = newPayload

	-- HANYA FIRING JIKA ADA PERUBAHAN DATA (0% Trafik jika tidak ada donasi baru)
	if hasChanged then
		updateTopBoardRemote:FireAllClients(cachedDonors)
	end
end

-- Export ke LeaderboardRegistry & LeaderboardOrchestrator
local function refreshRobuxLeaderboard()
	leaderboard:ClearCache()
	updateLeaderboard()
end

LeaderboardRegistry.register("Robux", refreshRobuxLeaderboard)
_G.UpdateRobuxLeaderboard = refreshRobuxLeaderboard

local clientBoardCooldown = {}

updateTopBoardRemote.OnServerEvent:Connect(function(player)
	if not player then return end
	local now = os.clock()
	if now - (clientBoardCooldown[player.UserId] or 0) < 15 then
		return
	end
	clientBoardCooldown[player.UserId] = now

	if cachedDonors and (cachedDonors.AllTime or #cachedDonors > 0) then
		pcall(function()
			updateTopBoardRemote:FireClient(player, cachedDonors)
		end)
	end
end)

game:GetService("Players").PlayerRemoving:Connect(function(player)
	clientBoardCooldown[player.UserId] = nil
end)