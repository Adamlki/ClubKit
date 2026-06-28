-- ========================================================
-- ⚙️ PENGATURAN (SETTINGS) - UBAH BEBAS DI SINI
-- ========================================================
local DEBUG_ENABLED = false -- 🟢 UBAH KE 'true' JIKA INGIN MELIHAT LOG DI CONSOLE

local SETTINGS = {
	BatasTopRobux   = 10, -- Tampilkan notif untuk Top X donatur Robux
	BatasTopSaweria = 10, -- Tampilkan notif untuk Top X donatur Saweria

	-- Format pesan (%s = Nama Player, %d = Peringkat)
	PesanRobux   = "💎 Top %d Robux Donator join server!",
	PesanSaweria = "💸 Top %d Saweria Donator join server!",

	-- Nama RemoteEvent untuk trigger UI Notifikasi di Client
	RemoteEventName = "SultanJoinNotifEvent"
}

-- ========================================================
-- 🛠️ FUNGSI DEBUG KUSTOM (ANTI-SPAM LOG)
-- ========================================================
local function debugLog(...)
	if DEBUG_ENABLED then
		print("[DEBUG NOTIF SERVER]", ...)
	end
end

-- ========================================================
-- 🚀 SISTEM & FUNGSI UTAMA (DI BAWAH SINI)
-- ========================================================
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

-- 1. Siapkan RemoteEvent untuk Client (UI)
local NotifEvent = ReplicatedStorage:FindFirstChild(SETTINGS.RemoteEventName)
if not NotifEvent then
	NotifEvent = Instance.new("RemoteEvent")
	NotifEvent.Name = SETTINGS.RemoteEventName
	NotifEvent.Parent = ReplicatedStorage
end

-- 2. Setup Modul Robux Leaderboard (Sesuaikan path jika berbeda)
-- Berdasarkan gambarmu, pathnya kira-kira di sini:
local ServerScriptService = game:GetService("ServerScriptService")
local DonationLeaderboardModule = ServerScriptService.DonationSystem.LeaderboardDisplay.DonationLeaderboard
local DonationLeaderboard = require(DonationLeaderboardModule)
local robuxBoard = DonationLeaderboard.new()

-- Fungsi mengecek Rank Robux
local function getRobuxRank(userId)
	local topDonors = robuxBoard:GetTopDonors(SETTINGS.BatasTopRobux)
	for _, donor in ipairs(topDonors) do
		if donor.UserId == userId then
			return donor.Rank
		end
	end
	return nil
end

-- Fungsi mengecek Rank Saweria
local function getSaweriaRank(playerName, displayName)
	-- Mengambil data dari BindableFunction yang akan kita buat di TopSaweria
	local getSaweriaData = ServerStorage:FindFirstChild("GetTopSaweriaFunc")
	if getSaweriaData then
		local rankFound = nil
		local isCompleted = false
		
		-- Jalankan secara terpisah agar tidak bisa menyandera script utama
		task.spawn(function()
			local success, topSaweria = pcall(function()
				return getSaweriaData:Invoke()
			end)
			if success and type(topSaweria) == "table" then
				for rank, donor in ipairs(topSaweria) do
					if rank > SETTINGS.BatasTopSaweria then break end
					-- Cek kecocokan nama (Username atau DisplayName)
					if string.lower(donor.name) == string.lower(playerName) or string.lower(donor.name) == string.lower(displayName) then
						rankFound = rank
						break
					end
				end
			end
			isCompleted = true
		end)
		
		-- Beri waktu maksimal 2 detik. Jika Saweria lag, tinggalkan saja!
		local timeout = 0
		while not isCompleted and timeout < 2 do
			task.wait(0.1)
			timeout += 0.1
		end
		
		return rankFound
	end
	return nil
end

-- ========================================================
-- 📡 EVENT KETIKA PLAYER JOIN
-- ========================================================
local function onPlayerJoin(player)
	debugLog("👤 Player Join:", player.Name)
	task.wait(math.random(3, 12)) -- Tunggu player load

	-- 🔥 UX FIX: Mencegah Notifikasi "Hantu" jika player langsung keluar
	if not player or not player.Parent then return end

	debugLog("🔍 Mulai mengecek Rank untuk:", player.DisplayName)
	local robuxRank = getRobuxRank(player.UserId)
	debugLog("💎 Hasil Cek Robux Rank:", robuxRank or "TIDAK ADA")

	local saweriaRank = getSaweriaRank(player.Name, player.DisplayName)
	debugLog("💸 Hasil Cek Saweria Rank:", saweriaRank or "TIDAK ADA")

	local notifMessage = nil
	if robuxRank and saweriaRank then
		notifMessage = string.format("Top %d Robux & Top %d Saweria join server!", robuxRank, saweriaRank)
	elseif robuxRank then
		notifMessage = string.format(SETTINGS.PesanRobux, robuxRank)
	elseif saweriaRank then
		notifMessage = string.format(SETTINGS.PesanSaweria, saweriaRank)
	end

	if notifMessage then
		debugLog("🚀 MENGIRIM SINYAL KE CLIENT:", notifMessage)
		NotifEvent:FireAllClients({
			Message = notifMessage,
			PlayerName = player.DisplayName,
			UserId = player.UserId,
			IsSaweria = (saweriaRank ~= nil)
		})
	else
		debugLog("❌ Player tidak masuk Top Rank, notifikasi dibatalkan.")
	end
end

Players.PlayerAdded:Connect(onPlayerJoin)

-- JAGA-JAGA UNTUK STUDIO (Kadang player join lebih cepat dari script)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerJoin, player)
end