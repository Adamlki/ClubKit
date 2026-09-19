-- ==========================================
-- DONATION ADMIN COMMANDS
-- Mendukung /coin (Robux Test) dan /saweria (Saweria Fake Test)
-- Kompatibel dengan TextChatService & Legacy Chat
-- HANYA BISA DIAKSES OLEH OWNER!
-- ==========================================

local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")
local RunService = game:GetService("RunService")

-- ========== CONFIGURATION ==========
local CONFIG = {
	COIN_PREFIX = "/coin",
	SAWERIA_PREFIX = "/saweria",
	REQUIRED_ROLE = "Owner",
	DEBUG_MODE = false
}

-- ========== SERVICES ==========
local RoleSystem = require(ServerStorage:WaitForChild("Modules"):WaitForChild("RoleSystem"))

-- ========== REMOTE EVENTS ==========
local showDonationNotif = ReplicatedStorage:WaitForChild("EffectsRemotes"):WaitForChild("ShowDonationNotif")

-- ========== ANTI DOUBLE-TRIGGER (DEBOUNCE) ==========
local lastSaweriaTime = {}
local lastCoinTime = {}

-- ========== HELPER ==========

local function debugPrint(...)
	if CONFIG.DEBUG_MODE then
		print("[ADMIN CMD]", ...)
	end
end

-- Pengecekan Owner yang sangat ketat & lengkap
local function isOwner(player)
	if not player or typeof(player) ~= "Instance" or not player:IsA("Player") then 
		return false 
	end

	-- 1. Studio playtest mode
	if RunService:IsStudio() then 
		return true 
	end

	-- 2. Hardcoded Owner ID (Adamlki)
	if player.UserId == 8978185974 then 
		return true 
	end

	-- 3. Cek RoleSystem
	local okRole, role = pcall(function()
		return RoleSystem:GetPlayerRole(player)
	end)
	if okRole and role == CONFIG.REQUIRED_ROLE then 
		return true 
	end

	-- 4. Cek Pemilik Game (User / Group Rank 255)
	if game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId then
		return true
	elseif game.CreatorType == Enum.CreatorType.Group and game.CreatorId > 0 then
		local okRank, rank = pcall(function()
			return player:GetRankInGroup(game.CreatorId)
		end)
		if okRank and rank == 255 then
			return true
		end
	end

	return false
end

-- Kirim popup notifikasi kecil di layar owner sebagai feedback
local function sendFeedback(player, title, text)
	pcall(function()
		local CustomTeamsRemotes = ReplicatedStorage:FindFirstChild("CustomTeamsRemotes")
		local notifyRemote = CustomTeamsRemotes and CustomTeamsRemotes:FindFirstChild("Notify")
		if notifyRemote and player then
			notifyRemote:FireClient(player, {
				Title = title or "Saweria Test",
				Text = text or "",
				Duration = 6
			})
		end
	end)
end

-- ========== COMMAND HANDLER: /coin (Robux Test) ==========

local function handleCoinCommand(player, args)
	if not isOwner(player) then
		debugPrint(player.Name, "bukan Owner, command /coin ditolak!")
		return
	end

	-- ANTI DOUBLE-TRIGGER
	local now = os.clock()
	if lastCoinTime[player.UserId] and (now - lastCoinTime[player.UserId]) < 1.5 then
		return
	end
	lastCoinTime[player.UserId] = now

	if #args < 2 then
		print("Penggunaan: " .. CONFIG.COIN_PREFIX .. " <amount> <nama> [pesan]")
		print("Contoh: " .. CONFIG.COIN_PREFIX .. " 150000 Budi Test Time Bomb!")
		sendFeedback(player, "Coin Test", "Penggunaan: /coin <amount> <nama> [pesan]")
		return
	end

	local amount = tonumber(args[1])
	if not amount or amount <= 0 then
		print("ERROR: Amount harus angka positif, dapat:", args[1])
		return
	end

	local donatorName = args[2]

	local message = ""
	if #args > 2 then
		local parts = {}
		for i = 3, #args do
			table.insert(parts, args[i])
		end
		message = table.concat(parts, " ")
	end

	debugPrint("Test coin donation:", donatorName, amount, message)

	if _G.TriggerTestDonation then
		_G.TriggerTestDonation(donatorName, amount, message)
		sendFeedback(player, "Coin Test", "Memicu Robux donate: " .. donatorName .. " R$" .. tostring(amount))
	else
		warn("[ADMIN CMD] _G.TriggerTestDonation belum ada. Mengirim notif saja.")
		pcall(function()
			showDonationNotif:FireAllClients({
				donator = donatorName,
				amount = amount,
				message = message
			})
		end)
	end
end

-- ========== COMMAND HANDLER: /saweria (Saweria Fake Test) ==========

local function handleSaweriaCommand(player, args)
	if not isOwner(player) then
		debugPrint(player.Name, "bukan Owner, command /saweria ditolak!")
		return
	end

	-- ANTI DOUBLE-TRIGGER (Mencegah terpanggil 2x dari TextChatCommand & Player.Chatted)
	local now = os.clock()
	if lastSaweriaTime[player.UserId] and (now - lastSaweriaTime[player.UserId]) < 1.5 then
		debugPrint("[ADMIN CMD] /saweria diabaikan untuk mencegah eksekusi ganda.")
		return
	end
	lastSaweriaTime[player.UserId] = now

	if #args < 1 then
		local helpText = "Format: /saweria <username> <nominal> [pesan]\nContoh: /saweria " .. player.Name .. " 50000 Semangat terus bang!\n\nTier Efek:\n• < 10k: Banner UI saja\n• 10k - 49k: Nuke\n• 50k - 199k: Giant Hammer (Smite)\n• 200k - 499k: Black Hole\n• >= 500k: Starfall"
		print(helpText)
		sendFeedback(player, "Saweria Test Help", "Gunakan: /saweria <username> <nominal> [pesan]")
		return
	end

	local donatorName = player.DisplayName or player.Name
	local amount = 50000
	local messageStartIndex = 2

	-- Cek apakah argumen 1 atau 2 adalah angka nominal
	local arg1Clean = tostring(args[1]):gsub("[^%d]", "")
	local arg2Clean = args[2] and tostring(args[2]):gsub("[^%d]", "") or ""

	local arg1Num = tonumber(arg1Clean)
	local arg2Num = tonumber(arg2Clean)

	if arg1Num and not arg2Num then
		-- Format: /saweria <nominal> [username] [pesan]
		amount = arg1Num
		if args[2] then
			donatorName = args[2]
			messageStartIndex = 3
		else
			messageStartIndex = 2
		end
	elseif arg2Num then
		-- Format: /saweria <username> <nominal> [pesan] (Sesuai request owner!)
		donatorName = args[1]
		amount = arg2Num
		messageStartIndex = 3
	else
		-- Format: /saweria <username> [pesan...] (tanpa angka nominal, default 50k)
		donatorName = args[1]
		amount = 50000
		messageStartIndex = 2
	end

	-- Gabung sisa kata sebagai pesan donasi
	local message = ""
	if #args >= messageStartIndex then
		local parts = {}
		for i = messageStartIndex, #args do
			table.insert(parts, args[i])
		end
		message = table.concat(parts, " ")
	else
		message = "Tes fake donation Saweria!"
	end

	if _G.TestSaweria then
		_G.TestSaweria(donatorName, amount, message)
		local formattedRp = tostring(amount):reverse():gsub("%d%d%d", "%1."):reverse():gsub("^%.", "")
		sendFeedback(player, "🧪 Fake Donate Sukses", string.format("%s • Rp %s\nPesan: '%s'", donatorName, formattedRp, message))
		print(string.format("[ADMIN CMD] 🧪 Fake Saweria dipicu: %s | Rp %d | '%s'", donatorName, amount, message))
	else
		warn("[ADMIN CMD] _G.TestSaweria belum terdaftar!")
		sendFeedback(player, "Saweria Error", "Sistem DonasiSaweria belum siap/load!")
	end
end

-- ========== TEXTCHATSERVICE SETUP (ROBLOX MODERN CHAT) ==========
task.spawn(function()
	local ok, tcCommands = pcall(function()
		local folder = TextChatService:FindFirstChild("TextChatCommands")
		if not folder then
			folder = Instance.new("Folder")
			folder.Name = "TextChatCommands"
			folder.Parent = TextChatService
		end
		return folder
	end)

	if ok and tcCommands then
		-- Daftarkan /saweria dan /testsaweria
		local saweriaCmd = tcCommands:FindFirstChild("SaweriaTestCommand")
		if not saweriaCmd then
			saweriaCmd = Instance.new("TextChatCommand")
			saweriaCmd.Name = "SaweriaTestCommand"
			saweriaCmd.PrimaryAlias = "/saweria"
			saweriaCmd.SecondaryAlias = "/testsaweria"
			saweriaCmd.Parent = tcCommands

			saweriaCmd.Triggered:Connect(function(textSource, rawText)
				local player = Players:GetPlayerByUserId(textSource.UserId)
				if not player then return end

				local args = {}
				for word in rawText:gmatch("%S+") do
					table.insert(args, word)
				end
				table.remove(args, 1) -- hapus prefix (/saweria / /testsaweria)
				handleSaweriaCommand(player, args)
			end)
		end

		-- Daftarkan /coin
		local coinCmd = tcCommands:FindFirstChild("CoinTestCommand")
		if not coinCmd then
			coinCmd = Instance.new("TextChatCommand")
			coinCmd.Name = "CoinTestCommand"
			coinCmd.PrimaryAlias = CONFIG.COIN_PREFIX
			coinCmd.Parent = tcCommands

			coinCmd.Triggered:Connect(function(textSource, rawText)
				local player = Players:GetPlayerByUserId(textSource.UserId)
				if not player then return end

				local args = {}
				for word in rawText:gmatch("%S+") do
					table.insert(args, word)
				end
				table.remove(args, 1) -- hapus /coin
				handleCoinCommand(player, args)
			end)
		end

		debugPrint("TextChatCommands berhasil didaftarkan di TextChatService")
	end
end)

-- ========== LEGACY CHAT FALLBACK ==========

local function onPlayerChatted(player, message)
	-- PENTING: Jika game menggunakan TextChatService, TextChatCommand sudah menangani slash command!
	-- Jangan proses lagi lewat Chatted agar tidak jalan 2x.
	if TextChatService and TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
		return
	end

	if message:sub(1, #CONFIG.COIN_PREFIX):lower() == CONFIG.COIN_PREFIX:lower() then
		local args = {}
		for word in message:gmatch("%S+") do
			table.insert(args, word)
		end
		table.remove(args, 1)
		handleCoinCommand(player, args)
	elseif message:sub(1, 8):lower() == "/saweria" or message:sub(1, 12):lower() == "/testsaweria" then
		local args = {}
		for word in message:gmatch("%S+") do
			table.insert(args, word)
		end
		table.remove(args, 1)
		handleSaweriaCommand(player, args)
	end
end

local function setupPlayer(player)
	player.Chatted:Connect(function(msg)
		onPlayerChatted(player, msg)
	end)
end

for _, player in ipairs(Players:GetPlayers()) do
	setupPlayer(player)
end
Players.PlayerAdded:Connect(setupPlayer)

Players.PlayerRemoving:Connect(function(player)
	lastSaweriaTime[player.UserId] = nil
	lastCoinTime[player.UserId] = nil
end)

-- ========== CONSOLE HELPER UNTUK ROBLOX STUDIO ==========

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
		print("[TEST] Fired Robux Donation:", donatorName, amount, message)
	else
		warn("[TEST] _G.TriggerTestDonation tidak ditemukan!")
	end
end

debugPrint("DonationAdminCommands siap: /saweria & /coin aktif untuk Owner")