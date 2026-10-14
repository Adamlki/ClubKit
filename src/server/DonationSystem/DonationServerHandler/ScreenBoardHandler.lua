local Players       = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService  = game:GetService("TweenService")
local TextService   = game:GetService("TextService")
local workspace     = game:GetService("Workspace")

local RunService    = game:GetService("RunService")
local DonationConfig = require(script.Parent.DonationConfig)

-- ============================================
-- REFERENSI WORKSPACE GUI (server side — selalu ketemu)
-- ============================================
local gui = nil
local mainframe = nil
local displayname = nil
local displaymessage = nil
local avatarImage = nil

local function getRobuxScreenGui()
	local folder = workspace:FindFirstChild("ScreenText")
	if folder then
		local part = folder:FindFirstChild("ScreenTextRobux")
		if part then
			return part:FindFirstChild("ScreenMessage")
		end
	end
	local part = workspace:FindFirstChild("ScreenTextRobux", true)
	return part and part:FindFirstChild("ScreenMessage")
end

local function ensureElements()
	if displayname and displaymessage and displayname.Parent and displaymessage.Parent then
		return true
	end

	gui = getRobuxScreenGui()
	if gui then
		mainframe = gui:FindFirstChild("MainFrame") or gui:WaitForChild("MainFrame", 5)
		if mainframe then
			displayname = mainframe:FindFirstChild("DisplayName") or mainframe:WaitForChild("DisplayName", 5)
			displaymessage = mainframe:FindFirstChild("DisplayMessage") or mainframe:WaitForChild("DisplayMessage", 5)
			local avatarContainer = mainframe:FindFirstChild("AvatarContainer")
			if avatarContainer then
				avatarImage = avatarContainer:FindFirstChild("Avatar")
			else
				avatarImage = mainframe:FindFirstChild("Avatar")
			end
		end
	end

	return displayname ~= nil and displaymessage ~= nil
end

ensureElements()

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

if RunService:IsServer() and RunService:IsRunning() then
	screenBoardRemote.OnServerEvent:Connect(function(player)
		player:Kick("Unauthorized remote invocation.")
	end)
end

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
-- ============================================
local FADE_OUT_TIME = 0.3
local FADE_IN_TIME  = 0.4

local function animateUpdate(newName, newMessage, userId)
	if not ensureElements() then return end

	local newAvatarThumb = userId and string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=420&h=420", userId) or nil

	if isAnimating then
		displayname.Text    = newName
		displaymessage.Text = newMessage
		if avatarImage and newAvatarThumb then
			avatarImage.Image = newAvatarThumb
		end
		return
	end
	isAnimating = true

	-- Fade out
	local fadeNameOut = TweenService:Create(displayname, TweenInfo.new(FADE_OUT_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextTransparency = 1})
	local fadeMsgOut = TweenService:Create(displaymessage, TweenInfo.new(FADE_OUT_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextTransparency = 1})
	local fadeAvatarOut = avatarImage and TweenService:Create(avatarImage, TweenInfo.new(FADE_OUT_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {ImageTransparency = 1})

	fadeNameOut:Play()
	fadeMsgOut:Play()
	if fadeAvatarOut then fadeAvatarOut:Play() end
	task.wait(FADE_OUT_TIME + 0.05)

	-- Update konten
	displayname.Text    = newName
	displaymessage.Text = newMessage
	if avatarImage and newAvatarThumb then
		avatarImage.Image = newAvatarThumb
	end

	-- Fade in
	local fadeNameIn = TweenService:Create(displayname, TweenInfo.new(FADE_IN_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {TextTransparency = 0})
	local fadeMsgIn = TweenService:Create(displaymessage, TweenInfo.new(FADE_IN_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {TextTransparency = 0})
	local fadeAvatarIn = avatarImage and TweenService:Create(avatarImage, TweenInfo.new(FADE_IN_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {ImageTransparency = 0})

	fadeNameIn:Play()
	fadeMsgIn:Play()
	if fadeAvatarIn then fadeAvatarIn:Play() end
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
		debugLog("FilterStringAsync gagal:", err1, "- pakai fallback")
		return RunService:IsStudio() and message or DonationConfig.SCREEN_BOARD.DEFAULT_MESSAGE
	end

	local filteredText
	local ok2, err2 = pcall(function()
		filteredText = filterResult:GetNonChatStringForBroadcastAsync()
	end)

	if not ok2 or filteredText == nil then
		debugLog("GetNonChatStringForBroadcastAsync gagal:", err2, "- pakai fallback")
		return RunService:IsStudio() and message or DonationConfig.SCREEN_BOARD.DEFAULT_MESSAGE
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
	local username        = player.Name or ("user_" .. tostring(player.UserId))
	local displayNameText = string.format("%s (@%s)", resolvedName, username)

	-- Animasi dan update dijalankan di server — direplikasi otomatis ke semua client
	task.spawn(function()
		animateUpdate(displayNameText, filtered, player.UserId)
	end)

	debugLog("Screen board diupdate untuk:", player.Name, "| Amount:", amount)
	return true
end

-- ============================================
-- INISIALISASI: Tampilkan pesan default saat server start
-- ============================================
task.spawn(function()
	task.wait(1.5)
	if ensureElements() then
		displayname.Text = "RASA NADA (@rasanada)"
		displaymessage.Text = DonationConfig.SCREEN_BOARD.DEFAULT_MESSAGE
		if avatarImage then
			avatarImage.Image = "rbxthumb://type=AvatarHeadShot&id=8978185974&w=420&h=420"
		end
		debugLog("Screen board Robux diinisialisasi dengan pesan default")
	else
		warn("[ScreenBoardHandler] ⚠️ ScreenTextRobux belum ditemukan saat inisialisasi awal.")
	end
end)

-- Shortcut test dari console/command bar
_G.TestRobuxScreen = function(name, amount, msg)
	ScreenBoardHandler:ShowDonationMessage(
		{ UserId = 1, Name = name or "AdamRobux", DisplayName = name or "AdamRobux" },
		amount or 100,
		msg or "Keren banget clubnya king!"
	)
end

return ScreenBoardHandler
