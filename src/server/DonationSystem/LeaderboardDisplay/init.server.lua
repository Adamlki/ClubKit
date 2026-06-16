--!native
--!optimize 2
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players           = game:GetService("Players")

local DonationLeaderboard = require(script.DonationLeaderboard)
local BoardRenderer       = require(script.BoardRenderer)

local REFRESH_INTERVAL = 60   -- detik antar refresh otomatis
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

local board = workspace:WaitForChild("EldetoDonationBoard", 10)
if not board then
	error("[LeaderboardDisplay] EldetoDonationBoard tidak ditemukan di Workspace!")
end

local renderer = BoardRenderer.new(board)
if not renderer then
	error("[LeaderboardDisplay] BoardRenderer gagal diinisialisasi!")
end

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
local cachedTop3 = {}

-- ============================================
-- HELPER
-- ============================================
local function buildTop3(donors)
	local top3 = {}
	for i = 1, math.min(3, #donors) do
		top3[i] = {
			UserId      = donors[i].UserId,
			DisplayName = donors[i].DisplayName,
			Amount      = donors[i].Amount,
			Rank        = donors[i].Rank,
		}
	end
	return top3
end

-- ============================================
-- UPDATE LEADERBOARD (GLOBAL)
-- ============================================
local function updateLeaderboard()
	renderer:ShowLoading("Loading...")
	task.wait(0.5)

	local ok, donors = pcall(function()
		return leaderboard:GetTopDonors(TOP_ENTRIES)
	end)

	if ok and donors then
		-- Simpan data Top 3 ke dalam Cache
		cachedTop3 = buildTop3(donors)

		renderer:Render(donors)
		updateTopBoardRemote:FireAllClients(cachedTop3)
	else
		warn("[LeaderboardDisplay] Gagal fetch data:", donors)
		renderer:ShowEmpty()
	end
end

-- ============================================
-- PLAYER JOIN — KIRIM CACHE SAJA! (SUPER RINGAN)
-- ============================================
Players.PlayerAdded:Connect(function(player)
	task.wait(3)  -- Tunggu LocalScript client siap

	-- Cukup kirim data yang sudah diingat Server, jangan panggil GetTopDonors lagi!
	if cachedTop3 and #cachedTop3 > 0 then
		pcall(function()
			updateTopBoardRemote:FireClient(player, cachedTop3)
		end)
	end
end)

-- ============================================
-- RENDER AWAL
-- ============================================
task.wait(2)
updateLeaderboard()

-- ============================================
-- LOOP AUTO-REFRESH DENGAN COUNTDOWN
-- ============================================
task.spawn(function()
	while true do
		-- Countdown
		for i = REFRESH_INTERVAL, 1, -1 do
			pcall(function()
				renderer:ShowCountdown(i)
			end)
			task.wait(1)
		end

		leaderboard:ClearCache()
		updateLeaderboard()
	end
end)