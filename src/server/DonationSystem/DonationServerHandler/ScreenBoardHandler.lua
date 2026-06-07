local Players       = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService  = game:GetService("TweenService")
local TextService   = game:GetService("TextService")
local workspace     = game:GetService("Workspace")

local DonationConfig = require(script.Parent.DonationConfig)

-- ============================================
-- REFERENSI WORKSPACE GUI (server side — selalu ketemu)
-- ============================================
local BoardModel     = workspace:WaitForChild("ScreenText", 10)
local gui            = BoardModel and BoardModel:WaitForChild("ScreenMessage", 10)
local mainframe      = gui and gui:WaitForChild("MainFrame", 10)
local displayname    = mainframe and mainframe:WaitForChild("DisplayName", 10)
local displaymessage = mainframe and mainframe:WaitForChild("DisplayMessage", 10)

if not displayname or not displaymessage then
	warn("[ScreenBoardHandler] SurfaceGui elements tidak ditemukan! Periksa struktur Workspace.")
end

-- ============================================
-- REMOTE (tetap dibuat agar tidak error, tapi tidak dipakai untuk sync)
-- Anti-exploit: kick siapapun yang coba fire dari client
-- ============================================
local screenBoardRemote = ReplicatedStorage:FindFirstChild("UpdateScreenBoard")
	or (function()
		local r    = Instance.new("RemoteEvent")
		r.Name     = "UpdateScreenBoard"
		r.Parent   = ReplicatedStorage
		return r
	end)()

screenBoardRemote.OnServerEvent:Connect(function(player)
	player:Kick("Unauthorized remote invocation.")
end)

-- ============================================
-- DEBUG
-- ============================================
local function debugLog(...)
	if DonationConfig.DEBUG.ENABLED and DonationConfig.DEBUG.SHOW_BROADCAST then
		print("[ScreenBoard]", ...)
	end
end

-- ============================================
-- STATE
-- ============================================
local isAnimating = false

-- ============================================
-- ANIMASI FADE (server-side TweenService)
-- TweenService di server menganimasikan Instance di Workspace
-- dan direplikasi otomatis ke semua client — tanpa client perlu
-- pegang referensi apapun.
-- ============================================
local FADE_OUT_TIME = 0.3
local FADE_IN_TIME  = 0.4

local function animateUpdate(newName, newMessage)
	if not displayname or not displaymessage then return end

	if isAnimating then
		-- Langsung update tanpa animasi jika sedang transisi
		displayname.Text    = newName
		displaymessage.Text = newMessage
		return
	end
	isAnimating = true

	-- Fade out
	local fadeNameOut = TweenService:Create(
		displayname,
		TweenInfo.new(FADE_OUT_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{TextTransparency = 1}
	)
	local fadeMsgOut = TweenService:Create(
		displaymessage,
		TweenInfo.new(FADE_OUT_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{TextTransparency = 1}
	)
	fadeNameOut:Play()
	fadeMsgOut:Play()
	task.wait(FADE_OUT_TIME + 0.05)

	-- Update konten
	displayname.Text    = newName
	displaymessage.Text = newMessage

	-- Fade in
	local fadeNameIn = TweenService:Create(
		displayname,
		TweenInfo.new(FADE_IN_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{TextTransparency = 0}
	)
	local fadeMsgIn = TweenService:Create(
		displaymessage,
		TweenInfo.new(FADE_IN_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{TextTransparency = 0}
	)
	fadeNameIn:Play()
	fadeMsgIn:Play()
	task.wait(FADE_IN_TIME + 0.05)

	isAnimating = false
end

-- ============================================
-- TEXT FILTERING
-- ============================================
local function filterMessage(message, fromPlayer)
	if not message or #message == 0 then
		return DonationConfig.SCREEN_BOARD.DEFAULT_MESSAGE
	end

	local filterResult
	local ok1, err1 = pcall(function()
		filterResult = TextService:FilterStringAsync(
			message,
			fromPlayer.UserId,
			Enum.TextFilterContext.PublicChat
		)
	end)

	if not ok1 or not filterResult then
		debugLog("FilterStringAsync gagal:", err1, "- pakai default message")
		return DonationConfig.SCREEN_BOARD.DEFAULT_MESSAGE
	end

	local filteredText
	local ok2, err2 = pcall(function()
		filteredText = filterResult:GetNonChatStringForBroadcastAsync()
	end)

	if not ok2 or filteredText == nil then
		debugLog("GetNonChatStringForBroadcastAsync gagal:", err2, "- pakai default message")
		return DonationConfig.SCREEN_BOARD.DEFAULT_MESSAGE
	end

	local trimmed = filteredText:match("^%s*(.-)%s*$")
	if #trimmed == 0 then
		return DonationConfig.SCREEN_BOARD.DEFAULT_MESSAGE
	end

	return trimmed
end

-- ============================================
-- RESOLVE NAMA PLAYER
-- Online  -> DisplayName
-- Offline -> Username via API
-- Gagal   -> "User_<userId>"
-- ============================================
local function getPlayerDisplayName(userId)
	local player = Players:GetPlayerByUserId(userId)
	if player then
		return player.DisplayName
	end

	local ok, result = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)

	if ok and result then
		debugLog("Resolved username (offline) untuk UserId:", userId, "->", result)
		return result
	end

	warn("[ScreenBoardHandler] GetNameFromUserIdAsync gagal untuk UserId:", userId)
	return "User_" .. userId
end

-- ============================================
-- MAIN
-- ============================================
local ScreenBoardHandler = {}

function ScreenBoardHandler:ShowDonationMessage(player, amount, message)
	if amount < DonationConfig.SCREEN_BOARD.MIN_DONATION then
		debugLog("Skip screen board (amount", amount, "< MIN_DONATION", DonationConfig.SCREEN_BOARD.MIN_DONATION .. ")")
		return false
	end

	local filtered        = filterMessage(message or "", player)
	local resolvedName    = getPlayerDisplayName(player.UserId)
	local displayNameText = string.format(
		DonationConfig.SCREEN_BOARD.NAME_FORMAT,
		resolvedName,
		amount
	)

	-- Animasi dan update dijalankan di server — direplikasi otomatis ke semua client
	task.spawn(function()
		animateUpdate(displayNameText, filtered)
	end)

	debugLog("Screen board diupdate untuk:", player.Name, "| Amount:", amount)
	return true
end

-- ============================================
-- INISIALISASI: Tampilkan pesan default saat server start
-- ============================================
task.spawn(function()
	task.wait(1)
	if displayname then
		displayname.Text = DonationConfig.SCREEN_BOARD.DEFAULT_NAME
	end
	if displaymessage then
		displaymessage.Text = DonationConfig.SCREEN_BOARD.DEFAULT_MESSAGE
	end
	debugLog("Screen board diinisialisasi dengan pesan default")
end)

return ScreenBoardHandler
