-- ==========================================
-- DONATION ADMIN COMMANDS (CLEANED)
-- Hanya command /coin untuk test efek
-- Tidak ada lagi /writelb atau /editdonatur
-- ==========================================

local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ========== CONFIGURATION ==========
local CONFIG = {
	PREFIX = "/coin",
	REQUIRED_ROLE = "Owner",
	DEBUG_MODE = false
}

-- ========== SERVICES ==========
local RoleSystem = require(ServerStorage.Modules.RoleSystem)

-- ========== REMOTE EVENTS ==========
-- Dipakai sebagai fallback untuk amount < 10k (tidak ada efek)
local showDonationNotif = ReplicatedStorage:WaitForChild("EffectsRemotes"):WaitForChild("ShowDonationNotif")

-- ========== HELPER ==========

local function debugPrint(...)
	if CONFIG.DEBUG_MODE then
		print("[ADMIN CMD]", ...)
	end
end

-- ========== COMMAND HANDLER ==========

local function handleCoinCommand(player, args)
	-- Cek role
	local playerRole = RoleSystem:GetPlayerRole(player)
	if playerRole ~= CONFIG.REQUIRED_ROLE then
		debugPrint(player.Name, "ditolak, role:", playerRole)
		return
	end

	-- Minimal 2 argumen: amount dan nama
	if #args < 2 then
		print("Penggunaan: " .. CONFIG.PREFIX .. " <amount> <nama> [pesan]")
		print("Contoh: " .. CONFIG.PREFIX .. " 150000 Budi Test Time Bomb!")
		return
	end

	local amount = tonumber(args[1])
	if not amount or amount <= 0 then
		print("ERROR: Amount harus angka positif, dapat:", args[1])
		return
	end

	local donatorName = args[2]

	-- Gabung argumen ke-3 dst sebagai pesan
	local message = ""
	if #args > 2 then
		local parts = {}
		for i = 3, #args do
			table.insert(parts, args[i])
		end
		message = table.concat(parts, " ")
	end

	debugPrint("Test donation:", donatorName, amount, message)

	-- Delegasikan ke DonationSystem (sudah handle tier + efek + notif)
	if _G.TriggerTestDonation then
		_G.TriggerTestDonation(donatorName, amount, message)
	else
		-- Fallback: DonationSystem belum load, kirim notif saja
		warn("[ADMIN CMD] _G.TriggerTestDonation belum ada. Pastikan DonationSystem sudah load.")
		pcall(function()
			showDonationNotif:FireAllClients({
				donator = donatorName,
				amount = amount,
				message = message
			})
		end)
	end
end

-- ========== CHAT LISTENER ==========

local function onPlayerChatted(player, message)
	if message:sub(1, #CONFIG.PREFIX):lower() ~= CONFIG.PREFIX:lower() then
		return
	end

	local args = {}
	for word in message:gmatch("%S+") do
		table.insert(args, word)
	end
	table.remove(args, 1) -- hapus prefix itu sendiri

	handleCoinCommand(player, args)
end

-- ========== PLAYER SETUP ==========

local function setupPlayer(player)
	player.Chatted:Connect(function(msg)
		onPlayerChatted(player, msg)
	end)
end

for _, player in ipairs(Players:GetPlayers()) do
	setupPlayer(player)
end
Players.PlayerAdded:Connect(setupPlayer)

-- ========== CONSOLE HELPER ==========

-- Jalankan test donation langsung dari server console tanpa perlu chat
_G.TestCoin = function(amount, donatorName, message)
	amount = tonumber(amount)
	if not amount or amount <= 0 then
		print("Usage: _G.TestCoin(amount, 'NamaDonatur', 'pesan opsional')")
		print("Contoh: _G.TestCoin(250000, 'Budi', 'UFO test!')")
		return
	end
	donatorName = donatorName or "TestDonor"
	message = message or ""

	if _G.TriggerTestDonation then
		_G.TriggerTestDonation(donatorName, amount, message)
		print("[TEST] Fired:", donatorName, amount, message)
	else
		warn("[TEST] _G.TriggerTestDonation tidak ditemukan!")
	end
end

debugPrint("Admin command loaded — hanya /coin aktif")