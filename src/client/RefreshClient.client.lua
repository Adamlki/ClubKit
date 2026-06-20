local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")
local TeleportService = game:GetService("TeleportService")
local RunService = game:GetService("RunService")
local Player = Players.LocalPlayer

-- Tunggu RemoteEvent tersedia
local remotefolder = ReplicatedStorage:WaitForChild("Remotes")
local refreshEvent = remotefolder:WaitForChild("RefreshCharacterEvent")

-- Fungsi untuk meminta refresh ke server
local function requestRefresh()
	refreshEvent:FireServer()
end

-- Fungsi untuk rejoin
local function requestRejoin()
	-- Cegah error merah di Roblox Studio
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

-- ====================================
-- GUI BUTTON HANDLER
-- ====================================
local function setupGui()
	local playerGui = Player:WaitForChild("PlayerGui")
	local refreshGui = playerGui:WaitForChild("RefreshGui", 10)
	if not refreshGui then return end

	local mainFrame = refreshGui:WaitForChild("MainFrame")
	local scrollingFrame = mainFrame:WaitForChild("ScrollingFrame")

	local refreshFrame = scrollingFrame:WaitForChild("RefreshFrame")
	local refreshBtn = refreshFrame:WaitForChild("ExecuteBtn")
	refreshBtn.MouseButton1Click:Connect(function()
		requestRefresh()
	end)

	local rejoinFrame = scrollingFrame:WaitForChild("RejoinFrame")
	local rejoinBtn = rejoinFrame:WaitForChild("ExecuteBtn")
	rejoinBtn.MouseButton1Click:Connect(function()
		requestRejoin()
	end)
end

-- Inisialisasi GUI
task.spawn(setupGui)

-- ====================================
-- LEGACY CHAT COMMAND HANDLER
-- ====================================

local function setupLegacyChatCommands()
	-- PRIORITAS: Jika TextChatService aktif, script ini harus BERHENTI (Return)
	-- agar tidak terjadi double trigger (dua kali refresh sekaligus).
	if TextChatService and TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
		return
	end

	-- Hanya berjalan jika game menggunakan sistem chat lama (Legacy)
	Player.Chatted:Connect(function(message)
		local lowercaseMsg = string.lower(message)

		-- Samakan dengan ChatBadgeClient: Hanya gunakan prefix "/" atau "!"
		if lowercaseMsg == "/re" or lowercaseMsg == "/refresh" or lowercaseMsg == "!re" or lowercaseMsg == "!refresh" then
			requestRefresh()
		elseif lowercaseMsg == "/rj" or lowercaseMsg == "/rejoin" or lowercaseMsg == "!rj" or lowercaseMsg == "!rejoin" then
			requestRejoin()
		end
	end)
end

-- Inisialisasi chat commands
setupLegacyChatCommands()