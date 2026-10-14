local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local TextService = game:GetService("TextService")
local RunService = game:GetService("RunService")
local workspace = game:GetService("Workspace")

-- ============================================
-- KONFIGURASI SAWERIA SCREEN BOARD
-- ============================================
local CONFIG = {
	ENABLED = true,
	MIN_DONATION = 10000, -- minimal Rp 10.000 untuk tampil di papan (bisa disesuaikan)
	NAME_FORMAT = "%s  |  Rp %s",
	DEFAULT_NAME = "RASA NADA",
	DEFAULT_MESSAGE = "KATA KATA HARI INI KING!!!",
	FADE_OUT_TIME = 0.3,
	FADE_IN_TIME = 0.4,
}

-- ============================================
-- HELPER FORMAT RUPIAH
-- ============================================
local function formatRupiah(num)
	local val = math.floor(tonumber(num) or 0)
	local str = tostring(val)
	local k
	while true do
		str, k = string.gsub(str, "^(-?%d+)(%d%d%d)", "%1.%2")
		if k == 0 then break end
	end
	return str
end

-- ============================================
-- REFERENSI WORKSPACE GUI
-- ============================================
local gui = nil
local mainframe = nil
local displayname = nil
local displaymessage = nil
local avatarImage = nil

local function getSaweriaScreenGui()
	local folder = workspace:FindFirstChild("ScreenText")
	if folder then
		local part = folder:FindFirstChild("ScreenTextSaweria")
		if part then
			return part:FindFirstChild("ScreenMessage")
		end
	end
	local part = workspace:FindFirstChild("ScreenTextSaweria", true)
	return part and part:FindFirstChild("ScreenMessage")
end

local function ensureElements()
	if displayname and displaymessage and displayname.Parent and displaymessage.Parent then
		return true
	end

	gui = getSaweriaScreenGui()
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

-- Coba dapatkan di awal
ensureElements()

-- ============================================
-- ANIMASI FADE (Server-side TweenService)
-- ============================================
local isAnimating = false

local function animateUpdate(newName, newMessage, userId)
	if not ensureElements() then
		warn("[SaweriaScreenBoard] Elemen GUI ScreenTextSaweria tidak ditemukan di Workspace!")
		return
	end

	local newAvatarThumb = userId and string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=420&h=420", userId) or nil

	if isAnimating then
		displayname.Text = newName
		displaymessage.Text = newMessage
		if avatarImage and newAvatarThumb then
			avatarImage.Image = newAvatarThumb
		end
		return
	end
	isAnimating = true

	-- Fade out
	local fadeNameOut = TweenService:Create(
		displayname,
		TweenInfo.new(CONFIG.FADE_OUT_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{TextTransparency = 1}
	)
	local fadeMsgOut = TweenService:Create(
		displaymessage,
		TweenInfo.new(CONFIG.FADE_OUT_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{TextTransparency = 1}
	)
	local fadeAvatarOut = avatarImage and TweenService:Create(
		avatarImage,
		TweenInfo.new(CONFIG.FADE_OUT_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ImageTransparency = 1}
	)
	fadeNameOut:Play()
	fadeMsgOut:Play()
	if fadeAvatarOut then fadeAvatarOut:Play() end
	task.wait(CONFIG.FADE_OUT_TIME + 0.05)

	-- Update teks & avatar
	displayname.Text = newName
	displaymessage.Text = newMessage
	if avatarImage and newAvatarThumb then
		avatarImage.Image = newAvatarThumb
	end

	-- Fade in
	local fadeNameIn = TweenService:Create(
		displayname,
		TweenInfo.new(CONFIG.FADE_IN_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{TextTransparency = 0}
	)
	local fadeMsgIn = TweenService:Create(
		displaymessage,
		TweenInfo.new(CONFIG.FADE_IN_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{TextTransparency = 0}
	)
	local fadeAvatarIn = avatarImage and TweenService:Create(
		avatarImage,
		TweenInfo.new(CONFIG.FADE_IN_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ImageTransparency = 0}
	)
	fadeNameIn:Play()
	fadeMsgIn:Play()
	if fadeAvatarIn then fadeAvatarIn:Play() end
	task.wait(CONFIG.FADE_IN_TIME + 0.05)

	isAnimating = false
end

-- ============================================
-- TEXT FILTERING (Roblox Community Standard)
-- ============================================
local function filterMessage(message, fromUserId)
	if not message or #message == 0 then
		return CONFIG.DEFAULT_MESSAGE
	end

	local filterResult
	local ok1 = pcall(function()
		filterResult = TextService:FilterStringAsync(
			message,
			fromUserId or 1,
			Enum.TextFilterContext.PublicChat
		)
	end)

	if ok1 and filterResult then
		local filteredText
		local ok2 = pcall(function()
			filteredText = filterResult:GetNonChatStringForBroadcastAsync()
		end)

		if ok2 and filteredText ~= nil then
			local trimmed = filteredText:match("^%s*(.-)%s*$")
			if #trimmed > 0 then
				return trimmed
			end
		end
	end

	-- Jika filtering gagal atau jaringan TextService sedang timeout, gunakan pesan asli yang sudah di-trim
	local trimmed = message:match("^%s*(.-)%s*$")
	if trimmed and #trimmed > 0 then
		return trimmed
	end

	return CONFIG.DEFAULT_MESSAGE
end

-- ============================================
-- RESOLVE USER ID DARI NAMA DONATUR
-- ============================================
local function resolveUserId(donatorName)
	if not donatorName or donatorName == "" then return 1 end

	-- Cek apakah player sedang berada di server
	local cleanName = donatorName:lower()
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Name:lower() == cleanName or player.DisplayName:lower() == cleanName then
			return player.UserId
		end
	end

	-- Coba cari ID online via Players service
	local ok, foundId = pcall(function()
		return Players:GetUserIdFromNameAsync(donatorName)
	end)
	if ok and foundId then
		return foundId
	end

	-- Fallback cerdas: gunakan salah satu pemain aktif di server sebagai konteks TextService
	local activePlayer = Players:GetPlayers()[1]
	if activePlayer then
		return activePlayer.UserId
	end

	return 1
end

-- ============================================
-- MAIN MODULE
-- ============================================
local SaweriaScreenBoardHandler = {}

function SaweriaScreenBoardHandler:ShowDonationMessage(donatorName, amount, message)
	if not CONFIG.ENABLED then return false end

	amount = tonumber(amount) or 0
	if amount < CONFIG.MIN_DONATION then
		print(string.format("[SaweriaScreenBoard] Skip (Rp %d < MIN_DONATION Rp %d)", amount, CONFIG.MIN_DONATION))
		return false
	end

	donatorName = tostring(donatorName or "Unknown")
	local userId = resolveUserId(donatorName)
	local filtered = filterMessage(message or "", userId)

	local targetPlayer = Players:GetPlayerByUserId(userId)
	local displayNameText = ""
	if targetPlayer then
		displayNameText = string.format("%s (@%s)", targetPlayer.DisplayName, targetPlayer.Name)
	else
		displayNameText = string.format("%s (@%s)", donatorName, donatorName:lower():gsub("%s+", ""))
	end

	task.spawn(function()
		animateUpdate(displayNameText, filtered, userId)
	end)

	print(string.format("[SaweriaScreenBoard] 📺 Screen Text Saweria diupdate untuk: %s | Rp %d", donatorName, amount))
	return true
end

-- ============================================
-- INISIALISASI DEFAULT SAAT SERVER BOOT
-- ============================================
task.spawn(function()
	task.wait(1.5)
	if ensureElements() then
		displayname.Text = "RASA NADA (@rasanada)"
		displaymessage.Text = CONFIG.DEFAULT_MESSAGE
		if avatarImage then
			avatarImage.Image = "rbxthumb://type=AvatarHeadShot&id=8978185974&w=420&h=420"
		end
		print("[SaweriaScreenBoard] ✅ ScreenTextSaweria berhasil diinisialisasi dengan pesan default")
	else
		warn("[SaweriaScreenBoard] ⚠️ ScreenTextSaweria belum ditemukan saat inisialisasi awal.")
	end
end)

function SaweriaScreenBoardHandler:ResetToDefault()
	if ensureElements() then
		displayname.Text = "RASA NADA (@rasanada)"
		displaymessage.Text = CONFIG.DEFAULT_MESSAGE
		if avatarImage then
			avatarImage.Image = "rbxthumb://type=AvatarHeadShot&id=8978185974&w=420&h=420"
		end
		print("[SaweriaScreenBoard] 🔄 ScreenTextSaweria di-reset ke template default")
	end
end

-- Global test shortcut
_G.TestSaweriaScreen = function(donatorName, amount, message)
	SaweriaScreenBoardHandler:ShowDonationMessage(
		donatorName or "AdamSaweria",
		amount or 50000,
		message or "Keren banget clubnya king, sukses selalu!"
	)
end

return SaweriaScreenBoardHandler
