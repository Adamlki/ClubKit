local DEBUG_ENABLED = false

local SETTINGS = {
	BatasTopRobux   = 10,
	BatasTopSaweria = 10,

	PesanRobux   = "💎 Top %d Robux Donator join server!",
	PesanSaweria = "💸 Top %d Saweria Donator join server!",

	RemoteEventName = "SultanJoinNotifEvent"
}

local function debugLog(...)
	if DEBUG_ENABLED then
		print("[DEBUG NOTIF SERVER]", ...)
	end
end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local LeaderboardRegistry = require(ServerScriptService:WaitForChild("Modules"):WaitForChild("LeaderboardRegistry"))

local NotifEvent = ReplicatedStorage:FindFirstChild(SETTINGS.RemoteEventName)
if not NotifEvent then
	NotifEvent = Instance.new("RemoteEvent")
	NotifEvent.Name = SETTINGS.RemoteEventName
	NotifEvent.Parent = ReplicatedStorage
end

local fallbackRobuxBoard = nil

local function getRobuxRank(userId)
	local topDonors = nil
	local control = LeaderboardRegistry.getController("Robux")
	if control and control.GetData then
		local ok, data = pcall(control.GetData)
		if ok and type(data) == "table" and #data > 0 then
			topDonors = data
		end
	end

	if not topDonors then
		if not fallbackRobuxBoard then
			local DonationLeaderboardModule = ServerScriptService.DonationSystem.LeaderboardDisplay.DonationLeaderboard
			local DonationLeaderboard = require(DonationLeaderboardModule)
			fallbackRobuxBoard = DonationLeaderboard.new()
		end
		topDonors = fallbackRobuxBoard:GetTopDonors(SETTINGS.BatasTopRobux)
	end

	if type(topDonors) == "table" then
		for _, donor in ipairs(topDonors) do
			if donor.Rank and donor.Rank <= SETTINGS.BatasTopRobux and donor.UserId == userId then
				return donor.Rank
			end
		end
	end
	return nil
end

local function getSaweriaRank(playerName, displayName)
	local getSaweriaData = ServerStorage:FindFirstChild("GetTopSaweriaFunc")
	if getSaweriaData then
		local rankFound = nil
		local isCompleted = false
		
		task.spawn(function()
			local success, topSaweria = pcall(function()
				return getSaweriaData:Invoke()
			end)
			if success and type(topSaweria) == "table" then
				for rank, donor in ipairs(topSaweria) do
					if rank > SETTINGS.BatasTopSaweria then break end
					if string.lower(tostring(donor.name or "")) == string.lower(playerName) then
						rankFound = rank
						break
					end
				end
			end
			isCompleted = true
		end)
		
		local timeout = 0
		while not isCompleted and timeout < 2 do
			task.wait(0.1)
			timeout += 0.1
		end
		
		return rankFound
	end
	return nil
end

local function onPlayerJoin(player)
	debugLog("👤 Player Join:", player.Name)
	task.wait(math.random(3, 12))

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

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerJoin, player)
end
