--!native
--!optimize 2
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players           = game:GetService("Players")

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
			Amount      = donors[i].Amount,
			Rank        = donors[i].Rank,
		}
	end
	return data
end

-- ============================================
-- UPDATE LEADERBOARD (GLOBAL)
-- ============================================
function updateLeaderboard()
	local ok, donors = pcall(function()
		return leaderboard:GetTopDonors(TOP_ENTRIES)
	end)

	if ok and donors then
		-- Simpan data ke dalam Cache
		cachedDonors = buildNetworkData(donors)

		-- HANYA FIRING KE CLIENT, TIDAK ADA RENDER DI SERVER
		updateTopBoardRemote:FireAllClients(cachedDonors)
	else
		warn("[LeaderboardDisplay] Gagal fetch data:", donors)
	end
end

-- ============================================
-- KETIKA CLIENT MEMINTA DATA (Saat Baru Masuk)
-- ============================================
updateTopBoardRemote.OnServerEvent:Connect(function(player)
	-- Cukup kirim data yang sudah diingat Server, jangan panggil GetTopDonors lagi!
	if cachedDonors and #cachedDonors > 0 then
		pcall(function()
			updateTopBoardRemote:FireClient(player, cachedDonors)
		end)
	end
end)

-- ============================================
-- RENDER AWAL
-- ============================================
task.wait(2)
updateLeaderboard()

-- ============================================
-- LOOP AUTO-REFRESH
-- ============================================
task.spawn(function()
	while true do
		task.wait(REFRESH_INTERVAL)
		leaderboard:ClearCache()
		updateLeaderboard()
	end
end)