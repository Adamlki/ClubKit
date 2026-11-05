local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local DonationServerHandler = ServerScriptService:WaitForChild("DonationSystem"):WaitForChild("DonationServerHandler")

local DonationDataStore = require(DonationServerHandler:WaitForChild("DonationDataStore"))
local ProcessReceiptHandler = require(DonationServerHandler:WaitForChild("ProcessReceiptHandler"))
local CustomTeams = require(ServerStorage.Modules.CustomTeams)

local SULTAN_REQUIREMENT = 10000

local function setupPlayer(player)
	local leaderstats = player:WaitForChild("leaderstats", 15)
	if not leaderstats then return end

	leaderstats:WaitForChild("Level", 10)

	local donationStat = leaderstats:FindFirstChild("Donation") or Instance.new("IntValue")
	donationStat.Name = "Donation"
	if not donationStat.Parent then
		donationStat.Value = 0
		donationStat.Parent = leaderstats
	end

	task.spawn(function()
		local myData = DonationDataStore:LoadPlayerDonation(player)

		if not player or not player.Parent then return end

		local totalDonated = 0
		if myData then
			totalDonated = (myData["Donated - Studio"] or 0) + (myData["Donated - Experience"] or 0)
		end

		donationStat.Value = totalDonated

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

ProcessReceiptHandler:RegisterCallback("UpdateSultanLeaderstat", function(player, productId, amount, receiptInfo)
	local RunService = game:GetService("RunService")
	if RunService:IsStudio() then return true end

	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local donationStat = leaderstats:FindFirstChild("Donation")
		if donationStat then
			donationStat.Value += amount

			if donationStat.Value >= SULTAN_REQUIREMENT and not player:GetAttribute("IsSultan") then
				player:SetAttribute("IsSultan", true)
				CustomTeams.RefreshPlayerTeam(player)

				print("[SULTAN SYSTEM]", player.Name, "telah resmi menjadi Sultan!")
			end
		end
	end

	return true
end)
