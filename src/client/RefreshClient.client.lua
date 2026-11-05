--!native
--!optimize 2
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")
local TeleportService = game:GetService("TeleportService")
local RunService = game:GetService("RunService")
local Player = Players.LocalPlayer

local remotefolder = ReplicatedStorage:WaitForChild("Remotes")
local refreshEvent = remotefolder:WaitForChild("RefreshCharacterEvent")

local function requestRefresh()
	refreshEvent:FireServer()
end

local function requestRejoin()
	if RunService:IsStudio() then
		warn("[Sistem Rejoin] Fitur Rejoin tidak bisa digunakan di dalam Roblox Studio. Silakan coba di Game asli (Roblox Player).")
		return
	end

	pcall(function()
		if #Players:GetPlayers() <= 1 then
			TeleportService:Teleport(game.PlaceId, Player)
		else
			TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, Player)
		end
	end)
end

local function setupGui()
	local playerGui = Player:WaitForChild("PlayerGui")
	local refreshGui = playerGui:WaitForChild("RefreshGui", 10)
	if not refreshGui then return end

	local mainFrame = refreshGui:WaitForChild("MainFrame")
	local scrollingFrame = mainFrame:WaitForChild("ScrollingFrame")

	local refreshFrame = scrollingFrame:WaitForChild("RefreshFrame")
	local refreshBtn = refreshFrame:WaitForChild("ExecuteBtn")
	local lastRefreshClick = 0
	refreshBtn.MouseButton1Click:Connect(function()
		local now = os.clock()
		if now - lastRefreshClick < 0.3 then return end
		lastRefreshClick = now

		requestRefresh()
	end)

	local rejoinFrame = scrollingFrame:WaitForChild("RejoinFrame")
	local rejoinBtn = rejoinFrame:WaitForChild("ExecuteBtn")
	local lastRejoinClick = 0
	rejoinBtn.MouseButton1Click:Connect(function()
		local now = os.clock()
		if now - lastRejoinClick < 0.3 then return end
		lastRejoinClick = now

		requestRejoin()
	end)
end

task.spawn(setupGui)

local function setupLegacyChatCommands()
	if TextChatService and TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
		return
	end

	Player.Chatted:Connect(function(message)
		local lowercaseMsg = string.lower(message)

		if lowercaseMsg == "/re" or lowercaseMsg == "/refresh" or lowercaseMsg == "!re" or lowercaseMsg == "!refresh" then
			requestRefresh()
		elseif lowercaseMsg == "/rj" or lowercaseMsg == "/rejoin" or lowercaseMsg == "!rj" or lowercaseMsg == "!rejoin" then
			requestRejoin()
		end
	end)
end

setupLegacyChatCommands()
