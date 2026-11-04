local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local DonationServerHandler = ServerScriptService:WaitForChild("DonationSystem"):WaitForChild("DonationServerHandler")

local DonationDataStore = require(DonationServerHandler:WaitForChild("DonationDataStore"))
local ProcessReceiptHandler = require(DonationServerHandler:WaitForChild("ProcessReceiptHandler"))
local CustomTeams = require(ServerStorage.Modules.CustomTeams)

local SULTAN_REQUIREMENT = 10000

-- Setup leaderstat donasi saat player join.
local function setupPlayer(player)
	local leaderstats = player:WaitForChild("leaderstats", 15)
	if not leaderstats then return end

	-- Pastikan Level dibuat lebih dulu agar urutan leaderstat rapi.
	leaderstats:WaitForChild("Level", 10)

	local donationStat = leaderstats:FindFirstChild("Donation") or Instance.new("IntValue")
	donationStat.Name = "Donation"
	if not donationStat.Parent then
		donationStat.Value = 0
		donationStat.Parent = leaderstats
	end

	task.spawn(function()
		local myData = DonationDataStore:LoadPlayerDonation(player)

		-- Pastikan player masih ada sebelum update UI.
		if not player or not player.Parent then return end

		local totalDonated = 0
		if myData then
			totalDonated = (myData["Donated - Studio"] or 0) + (myData["Donated - Experience"] or 0)
		end

		-- Masukkan data asli ke leaderstats
		donationStat.Value = totalDonated

		-- Cek apakah dia berhak masuk tim Sultan sejak awal.
		-- Assignment team tetap milik CustomTeams supaya override custom team
		-- tidak ditimpa dan tidak ada transisi tim yang berulang.
		if totalDonated >= SULTAN_REQUIREMENT then
			local wasSultan = player:GetAttribute("IsSultan") == true
			player:SetAttribute("IsSultan", true)
			if not wasSultan then
				CustomTeams.RefreshPlayerTeam(player)
			end
		end
	end)
end

local setupStarted = {}

local function setupPlayerOnce(player)
	if not player or not player.Parent then return end
	if setupStarted[player] then return end
	setupStarted[player] = true
	setupPlayer(player)
end

Players.PlayerAdded:Connect(setupPlayerOnce)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(setupPlayerOnce, player)
end
Players.PlayerRemoving:Connect(function(player)
	setupStarted[player] = nil
end)

-- 2. SAAT PLAYER DONASI: Update Leaderstat secara Real-time
ProcessReceiptHandler:RegisterCallback("UpdateSultanLeaderstat", function(player, productId, amount, receiptInfo)
	local RunService = game:GetService("RunService")
	if RunService:IsStudio() then return true end

	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local donationStat = leaderstats:FindFirstChild("Donation")
		if donationStat then
			-- Tambahkan angka di sebelah level
			donationStat.Value += amount

			-- Cek apakah donasi totalnya menembus batas Sultan
			if donationStat.Value >= SULTAN_REQUIREMENT and not player:GetAttribute("IsSultan") then
				player:SetAttribute("IsSultan", true)
				CustomTeams.RefreshPlayerTeam(player)

				print("[SULTAN SYSTEM]", player.Name, "telah resmi menjadi Sultan!")
			end
		end
	end

	return true
end)
