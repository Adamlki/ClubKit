local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")
local Player = Players.LocalPlayer

-- Tunggu RemoteEvent tersedia
local remotefolder = ReplicatedStorage:WaitForChild("Remotes")
local refreshEvent = remotefolder:WaitForChild("RefreshCharacterEvent")

-- Fungsi untuk meminta refresh ke server
local function requestRefresh()
	refreshEvent:FireServer()
end

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

		-- Samakan dengan ChatBadgeClient: Hanya gunakan prefix "/"
		if lowercaseMsg == "/re" or lowercaseMsg == "/refresh" then
			requestRefresh()
		end
	end)
end

-- Inisialisasi chat commands
setupLegacyChatCommands()