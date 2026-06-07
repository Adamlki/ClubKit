local ServerStorage    = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players          = game:GetService("Players")
local TextService      = game:GetService("TextService")
local TextChatService  = game:GetService("TextChatService")
local MessagingService = game:GetService("MessagingService")

-- Sesuaikan path modul dengan struktur project kamu
local RoleSystem    = require(ServerStorage.Modules.RoleSystem)
local MessageConfig = require(script.AdminNotifConfig)

-- ====================================
-- REMOTE SETUP
-- ====================================
local RemoteFolder = ReplicatedStorage:FindFirstChild("Message")
	or Instance.new("Folder")
RemoteFolder.Name   = "Message"
RemoteFolder.Parent = ReplicatedStorage

local function getOrCreate(parent, className, name)
	return parent:FindFirstChild(name)
		or (function()
			local inst = Instance.new(className)
			inst.Name   = name
			inst.Parent = parent
			return inst
		end)()
end

local SendMessageRemote   = getOrCreate(RemoteFolder, "RemoteEvent",    "SendMessage")
local ReceiveMessageRemote = getOrCreate(RemoteFolder, "RemoteEvent",   "ReceiveMessage")
local CheckTimerRemote    = getOrCreate(RemoteFolder, "RemoteFunction", "CheckTimer")
local CheckAccessRemote   = getOrCreate(RemoteFolder, "RemoteFunction", "CheckAccess")

-- ====================================
-- PLAYER DATA
-- ====================================
local PlayerData = {}

local function initPlayerData(userId)
	if not PlayerData[userId] then
		PlayerData[userId] = {
			LastMessageTime    = 0,
			MessageCount       = 0,
			LastMinuteReset    = tick(),
			LastBroadcastTime  = 0
		}
	end
end

local function cleanPlayerData(userId)
	PlayerData[userId] = nil
end

-- ====================================
-- ROLE HELPERS
-- ====================================
local function hasAccess(player)
	local role        = RoleSystem:GetPlayerRole(player)
	local minRole     = MessageConfig.Access.MinimumRole
	local playerPrio  = MessageConfig.Access.RoleHierarchy[role]  or 0
	local minPrio     = MessageConfig.Access.RoleHierarchy[minRole] or 0
	return playerPrio >= minPrio, role
end

local function getTimerDuration(role)
	return (MessageConfig.Timer.Durations[role] or 0)
end

local function hasTimer(role)
	return getTimerDuration(role) > 0
end

local function getRemainingTime(player, role)
	if not hasTimer(role) then return 0 end

	initPlayerData(player.UserId)
	local data     = PlayerData[player.UserId]
	local duration = getTimerDuration(role)
	local elapsed  = tick() - data.LastBroadcastTime
	return math.max(0, duration - elapsed)
end

-- ====================================
-- TIMER REMOTE
-- ====================================
CheckTimerRemote.OnServerInvoke = function(player)
	local _, role   = hasAccess(player)
	local remaining = getRemainingTime(player, role)

	return {
		HasTimer      = hasTimer(role),
		RemainingTime = remaining,
		TimerDuration = getTimerDuration(role)
	}
end

-- ====================================
-- ACCESS REMOTE
-- ====================================
CheckAccessRemote.OnServerInvoke = function(player)
	local ok, _ = hasAccess(player)
	return ok
end

-- ====================================
-- TEXT FILTERING (Roblox-compliant)
-- Wajib: selalu filter di server, batalkan jika filter gagal.
-- ====================================
local function filterText(message, fromPlayer)
	if not MessageConfig.Validation.EnableFilter then
		-- EnableFilter sebaiknya SELALU true untuk kepatuhan Roblox.
		-- Opsi ini hanya untuk keperluan testing lokal.
		return message
	end

	local filterResult
	local ok1, err1 = pcall(function()
		-- TextFilterContext.PublicChat = filter paling ketat, cocok untuk broadcast
		filterResult = TextService:FilterStringAsync(
			message,
			fromPlayer.UserId,
			Enum.TextFilterContext.PublicChat
		)
	end)

	if not ok1 or not filterResult then
		warn("[MessageServer] FilterStringAsync gagal:", err1)
		return nil  -- Batalkan pesan — jangan kirim unfiltered
	end

	local filteredText
	local ok2, err2 = pcall(function()
		filteredText = filterResult:GetNonChatStringForBroadcastAsync()
	end)

	if not ok2 or filteredText == nil then
		warn("[MessageServer] GetNonChatStringForBroadcastAsync gagal:", err2)
		return nil  -- Batalkan pesan
	end

	return filteredText
end

-- ====================================
-- MESSAGE VALIDATION
-- ====================================
local function formatWaitTime(seconds)
	local m = math.floor(seconds / 60)
	local s = math.floor(seconds % 60)
	if m > 0 then
		return string.format("%d minute(s) and %d second(s)", m, s)
	end
	return string.format("%d second(s)", s)
end

local function validateMessage(player, message)
	initPlayerData(player.UserId)
	local data = PlayerData[player.UserId]

	-- 1. Cek akses role
	local ok, role = hasAccess(player)
	if not ok then
		return false, "You don't have permission to send broadcast messages."
	end

	-- 2. [WAJIB Roblox] Cek privacy/parental settings via TextChatService
	local canChat = false
	local chatOk, chatErr = pcall(function()
		canChat = TextChatService:CanUserChatAsync(player.UserId)
	end)
	if not chatOk then
		warn("[MessageServer] CanUserChatAsync gagal:", chatErr)
		return false, "Unable to verify chat permissions. Please try again."
	end
	if not canChat then
		return false, "Your account settings do not allow sending broadcast messages."
	end

	-- 3. Cek timer broadcast (per role)
	if hasTimer(role) then
		local remaining = getRemainingTime(player, role)
		if remaining > 0 then
			return false, "Please wait " .. formatWaitTime(remaining) .. " before sending another broadcast."
		end
	end

	-- 4. Validasi panjang pesan
	local trimmed = message:match("^%s*(.-)%s*$")
	if #trimmed < MessageConfig.Validation.MinLength then
		return false, "Message is too short."
	end
	if #trimmed > MessageConfig.Validation.MaxLength then
		return false, string.format(
			"Message is too long (max %d characters).",
			MessageConfig.Validation.MaxLength
		)
	end

	-- 5. Cooldown umum (anti-spam)
	local now = tick()
	local elapsed = now - data.LastMessageTime
	if elapsed < MessageConfig.Validation.Cooldown then
		local wait = math.ceil(MessageConfig.Validation.Cooldown - elapsed)
		return false, string.format("Please wait %d second(s) before sending another message.", wait)
	end

	-- 6. Batas pesan per menit
	if now - data.LastMinuteReset >= 60 then
		data.MessageCount    = 0
		data.LastMinuteReset = now
	end
	if data.MessageCount >= MessageConfig.Validation.MaxMessagesPerMin then
		return false, "Too many messages. Please slow down."
	end

	return true, "Valid", role, trimmed
end

-- ====================================
-- SEND MESSAGE HANDLER
-- ====================================
SendMessageRemote.OnServerEvent:Connect(function(player, message, isGlobal)
	-- Sanity check tipe data dari client
	if type(message) ~= "string" then return end

	local isValid, errorMsg, role, trimmedMessage = validateMessage(player, message)

	if not isValid then
		ReceiveMessageRemote:FireClient(player, {
			Type    = "Error",
			Message = errorMsg
		})
		return
	end

	-- Filter teks
	local filteredMessage = filterText(trimmedMessage, player)
	if filteredMessage == nil then
		ReceiveMessageRemote:FireClient(player, {
			Type    = "Error",
			Message = "Your message could not be sent due to a content filter issue."
		})
		return
	end

	-- Update state player
	local data = PlayerData[player.UserId]
	data.LastMessageTime   = tick()
	data.LastBroadcastTime = tick()
	data.MessageCount      = data.MessageCount + 1

	local roleConfig = MessageConfig.RoleDisplay[role] or MessageConfig.RoleDisplay.Player

	-- Tambahkan tag [GLOBAL] jika ini pesan lintas server
	local finalMessage = filteredMessage
	if isGlobal then
		finalMessage = "[GLOBAL] " .. finalMessage
	end

	local messageData = {
		Type           = "Message",
		SenderId       = player.UserId,
		SenderName     = player.DisplayName,
		SenderUsername = player.Name,
		Role           = role,
		RoleText       = roleConfig.Text,
		-- Ubah Color3 menjadi tabel R,G,B agar bisa dikirim via MessagingService
		RoleColor      = {R = roleConfig.Color.R, G = roleConfig.Color.G, B = roleConfig.Color.B},
		Message        = finalMessage,
		Timestamp      = os.time()
	}

	if isGlobal then
		-- KIRIM KE SEMUA SERVER
		local success, err = pcall(function()
			MessagingService:PublishAsync("GlobalAdminMessage", messageData)
		end)

		if not success then
			warn("[MessageServer] PublishAsync gagal:", err)
			ReceiveMessageRemote:FireClient(player, {
				Type = "Error",
				Message = "Failed to send global message. Please try again."
			})
		end
	else
		-- KIRIM HANYA KE SERVER INI (LOKAL)
		-- Ubah warna kembali ke Color3 untuk server ini
		messageData.RoleColor = Color3.new(messageData.RoleColor.R, messageData.RoleColor.G, messageData.RoleColor.B)

		for _, targetPlayer in ipairs(Players:GetPlayers()) do
			local targetCanChat = false
			local ok = pcall(function() targetCanChat = TextChatService:CanUserChatAsync(targetPlayer.UserId) end)
			if not ok or targetCanChat then
				ReceiveMessageRemote:FireClient(targetPlayer, messageData)
			end
		end
	end
end)

-- ====================================
-- MESSAGING SERVICE SUBSCRIBER (MENERIMA PESAN GLOBAL)
-- ====================================
local subscribeSuccess, subscribeErr = pcall(function()
	MessagingService:SubscribeAsync("GlobalAdminMessage", function(message)
		local messageData = message.Data

		-- Kembalikan tabel {R, G, B} menjadi Color3
		if messageData.RoleColor and type(messageData.RoleColor) == "table" then
			messageData.RoleColor = Color3.new(messageData.RoleColor.R, messageData.RoleColor.G, messageData.RoleColor.B)
		end

		-- Broadcast ke semua player di server ini
		for _, targetPlayer in ipairs(Players:GetPlayers()) do
			local targetCanChat = false
			local ok = pcall(function() targetCanChat = TextChatService:CanUserChatAsync(targetPlayer.UserId) end)
			if not ok or targetCanChat then
				ReceiveMessageRemote:FireClient(targetPlayer, messageData)
			end
		end
	end)
end)

if not subscribeSuccess then
	warn("[MessageServer] Gagal subscribe ke GlobalAdminMessage:", subscribeErr)
end

-- ====================================
-- PLAYER LIFECYCLE
-- ====================================
Players.PlayerAdded:Connect(function(player)
	initPlayerData(player.UserId)
end)

Players.PlayerRemoving:Connect(function(player)
	cleanPlayerData(player.UserId)
end)

game:BindToClose(function()
	PlayerData = {}
end)