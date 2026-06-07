local Players    = game:GetService("Players")
local RS         = game:GetService("ReplicatedStorage")
local TS         = game:GetService("TweenService")
local SG         = game:GetService("StarterGui")
local TextService = game:GetService("TextService")

local player     = Players.LocalPlayer
local playerGui  = player:WaitForChild("PlayerGui")

-- ====================================
-- REMOTE REFERENCES
-- ====================================
local RemoteFolder         = RS:WaitForChild("Message")
local SendMessageRemote    = RemoteFolder:WaitForChild("SendMessage")
local ReceiveMessageRemote = RemoteFolder:WaitForChild("ReceiveMessage")
local CheckTimerRemote     = RemoteFolder:WaitForChild("CheckTimer")
local CheckAccessRemote    = RemoteFolder:WaitForChild("CheckAccess")

-- ====================================
-- UI REFERENCES
-- ====================================
local gui          = script.Parent
local mainframe    = gui:WaitForChild("MainFrame")
local frame        = mainframe:WaitForChild("Frame") -- Ini tempat tombol Server & Global
local textbox      = mainframe:WaitForChild("TextBox") -- TextBox aslinya ada di MainFrame
local serverBtn    = frame:WaitForChild("ServerBtn")
local globalBtn    = frame:WaitForChild("GlobalBtn")
local closeBtn     = mainframe:WaitForChild("CloseBtn") -- Sekalian kita siapkan tombol Closenya
local messageFrame = gui:WaitForChild("MessageFrame")

-- Template notifikasi (clone sekali, jangan ubah yang asli)
local templateNotif = messageFrame:Clone()
templateNotif.Parent  = nil
templateNotif.Visible = false

-- ====================================
-- CONFIG (dari ModuleScript)
-- Jika tidak ingin require ModuleScript di client, duplikasi nilai yang
-- dibutuhkan di sini. Nilai harus sinkron dengan MessageConfig.lua.
-- ====================================
local Config = {
	Notification = {
		Duration   = 10,
		MaxVisible = 3,
		Animation  = {
			DropSpeed       = 0.5,
			EasingStyle     = Enum.EasingStyle.Back,
			EasingDirection = Enum.EasingDirection.Out
		},
		Sound = {
			Enabled       = true,
			SoundId       = "rbxassetid://17208361335",
			Volume        = 0.5,
			PlaybackSpeed = 1
		}
	},
	Timer = {
		UpdateInterval   = 1,
		ShowNotification = true
	}
}

-- ====================================
-- STATE
-- ====================================
local activeNotifications  = {}
local notificationContainer = nil
local timerData = {
	HasTimer      = false,
	RemainingTime = 0,
	TimerDuration = 0
}
local lastTimerNotifTime = 0
local isSending = false  -- Mencegah double-send

-- ====================================
-- NOTIFICATION CONTAINER
-- ====================================
local function setupNotificationContainer()
	if notificationContainer and notificationContainer.Parent then return end

	notificationContainer = Instance.new("ScreenGui")
	notificationContainer.Name            = "MessageNotifications"
	notificationContainer.ResetOnSpawn    = false
	notificationContainer.ZIndexBehavior  = Enum.ZIndexBehavior.Sibling
	notificationContainer.Parent          = playerGui
end

-- ====================================
-- UTILITY
-- ====================================
local function formatTime(seconds)
	local minutes = math.floor(seconds / 60)
	local secs    = math.floor(seconds % 60)
	if minutes > 0 then
		return string.format("%d minute(s) %d second(s)", minutes, secs)
	end
	return string.format("%d second(s)", secs)
end

-- ====================================
-- TIMER FUNCTIONS
-- ====================================
local function showTimerNotification(remainingTime)
	if not Config.Timer.ShowNotification then return end

	local now = tick()
	if now - lastTimerNotifTime < 5 then return end
	lastTimerNotifTime = now

	pcall(function()
		SG:SetCore("SendNotification", {
			Title    = "Broadcast Timer",
			Text     = "Next broadcast available in " .. formatTime(remainingTime),
			Duration = 4,
			Icon     = "rbxassetid://7733992901"
		})
	end)
end

local function refreshTimerData()
	local ok, result = pcall(function()
		return CheckTimerRemote:InvokeServer()
	end)
	if ok and result then
		timerData.HasTimer      = result.HasTimer
		timerData.RemainingTime = result.RemainingTime
		timerData.TimerDuration = result.TimerDuration
	end
end

-- ====================================
-- SOUND
-- ====================================
local function playNotificationSound()
	if not Config.Notification.Sound.Enabled then return end

	local sound              = Instance.new("Sound")
	sound.SoundId            = Config.Notification.Sound.SoundId
	sound.Volume             = Config.Notification.Sound.Volume
	sound.PlaybackSpeed      = Config.Notification.Sound.PlaybackSpeed
	sound.RollOffMaxDistance = 0
	sound.Parent             = workspace

	sound:Play()
	sound.Ended:Connect(function()
		sound:Destroy()
	end)
end

-- ====================================
-- NOTIFICATION DISPLAY
-- ====================================
local function tweenTransparency(frame, tweenInfo, targetAlpha)
	local goals = {}
	if frame:IsA("Frame") or frame:IsA("ImageLabel") or frame:IsA("ImageButton") then
		goals.BackgroundTransparency = targetAlpha
	end
	if frame:IsA("TextLabel") or frame:IsA("TextButton") then
		goals.BackgroundTransparency = targetAlpha
		goals.TextTransparency       = targetAlpha
	end
	if frame:IsA("ImageLabel") or frame:IsA("ImageButton") then
		goals.ImageTransparency = targetAlpha
	end
	if next(goals) then
		TS:Create(frame, tweenInfo, goals):Play()
	end
end

local function removeNotification(notifData)
	-- Hapus dari tabel aktif
	for i, data in ipairs(activeNotifications) do
		if data == notifData then
			table.remove(activeNotifications, i)
			break
		end
	end

	local fadeInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

	-- Fade out frame dan semua children
	if notifData.Frame and notifData.Frame.Parent then
		tweenTransparency(notifData.Frame, fadeInfo, 1)
		for _, child in ipairs(notifData.Frame:GetDescendants()) do
			tweenTransparency(child, fadeInfo, 1)
		end
	end

	task.delay(0.35, function()
		if notifData.Frame and notifData.Frame.Parent then
			notifData.Frame:Destroy()
		end
	end)
end

local function updateNotificationPositions()
	for i, notifData in ipairs(activeNotifications) do
		if i > Config.Notification.MaxVisible then
			-- Hapus notifikasi yang melebihi batas tanpa animasi fade
			if notifData.Frame and notifData.Frame.Parent then
				notifData.Frame:Destroy()
			end
			table.remove(activeNotifications, i)
		elseif i > 1 then
			-- Geser notifikasi ke bawah sesuai urutan
			local orig    = notifData.OriginalPosition

			-- 👇 DI SINI TEMPAT ATUR JARAKNYA 👇
			-- 0.05 artinya jaraknya 5% dari layar. 
			-- Kalau masih terlalu jauh, kecilkan jadi 0.04 atau 0.03. 
			-- Kalau terlalu mepet, naikkan jadi 0.06 atau 0.07.
			local offsetY = 0.10 * (i - 1) 

			local newPos  = UDim2.new(
				orig.X.Scale, orig.X.Offset,
				orig.Y.Scale + offsetY, orig.Y.Offset
			)
			local moveInfo = TweenInfo.new(
				Config.Notification.Animation.DropSpeed * 0.7,
				Config.Notification.Animation.EasingStyle,
				Config.Notification.Animation.EasingDirection
			)
			TS:Create(notifData.Frame, moveInfo, { Position = newPos }):Play()
		end
	end
end

-- ====================================
-- NOTIFICATION DISPLAY
-- ====================================
local function createNotification(messageData)
	setupNotificationContainer()

	local notif = templateNotif:Clone()
	notif.Parent  = notificationContainer

	-- SEMBUNYIKAN DULU DI LUAR LAYAR UNTUK MENGUKUR LEBAR NAMA
	local originalPos = notif.Position
	notif.Position = UDim2.new(2, 0, 2, 0)
	notif.Visible = true 

	local messageLabel = notif:FindFirstChild("Message")
	local verifIcon = messageLabel and messageLabel:FindFirstChild("VerifiedBadge")

	if messageLabel and verifIcon then
		-- Pastikan RichText nyala
		messageLabel.RichText = true

		-- Bersihkan teks "[Global]" (Kebal huruf besar/kecil dan tanda baca)
		local rawMessage = messageData.Message or ""
		local cleanMessage = string.gsub(rawMessage, "%[[Gg][Ll][Oo][Bb][Aa][Ll]%]%s*:?%s*", "")

		-- 1. UKUR LEBAR NAMA DENGAN AKURAT (Tanpa merusak settingan manualmu)
		messageLabel.Text = "<b>" .. messageData.SenderName .. "</b>"

		-- Tunggu 1 frame agar mesin Roblox selesai menghitung ukuran font
		task.wait()

		local nameWidth = messageLabel.TextBounds.X
		local lineHeight = messageLabel.TextBounds.Y

		-- 2. POSISIKAN ICON BAWAAN GUI-MU
		local iconWidth = 15 -- Ukuran logomu
		verifIcon.BackgroundTransparency = 1
		verifIcon.Size = UDim2.new(0, iconWidth, 0, iconWidth)
		verifIcon.AnchorPoint = Vector2.new(0, 0)

		-- Hitung agar posisi icon pas di tengah-tengah teks baris pertama
		local yOffset = (lineHeight - iconWidth) / 2

		-- Posisikan persis di sebelah nama (kasih jarak 4 pixel)
		verifIcon.Position = UDim2.new(0, nameWidth + 4, 0, yOffset)
		verifIcon.Visible = true

		-- 3. FORMAT TEKS KESELURUHAN (NAMA MENJADI KUNING)
		-- Kita pakai 5 spasi manual yang pasti pas untuk tempat icon 18px
		local emptySpaces = "     " 
		-- Perhatikan tag <font color="#FFD700"> yang mengapit %s (SenderName)
		messageLabel.Text = string.format('<font color="#FFD700"><b>%s</b></font>%s: %s', messageData.SenderName, emptySpaces, cleanMessage)
	end

	-- Kembalikan posisi ke atas layar untuk persiapan animasi turun
	notif.Position = UDim2.new(originalPos.X.Scale, originalPos.X.Offset, -0.25, 0)

	local notifData = {
		Frame           = notif,
		OriginalPosition = originalPos,
		Timestamp       = tick(),
		Duration        = Config.Notification.Duration
	}
	table.insert(activeNotifications, 1, notifData)

	if #activeNotifications > Config.Notification.MaxVisible then
		local oldest = activeNotifications[#activeNotifications]
		removeNotification(oldest)
	end

	local dropInfo = TweenInfo.new(
		Config.Notification.Animation.DropSpeed,
		Config.Notification.Animation.EasingStyle,
		Config.Notification.Animation.EasingDirection
	)
	TS:Create(notif, dropInfo, { Position = originalPos }):Play()

	updateNotificationPositions()
	playNotificationSound()

	task.delay(notifData.Duration, function()
		if notifData.Frame and notifData.Frame.Parent then
			removeNotification(notifData)
		end
	end)
end

-- ====================================
-- SEND MESSAGE
-- ====================================
local function sendMessage(isGlobal)
	if isSending then return end

	local message = textbox.Text:match("^%s*(.-)%s*$")
	if message == "" then return end

	isSending = true
	textbox.Text = ""

	-- Kirim ke server (dengan status isGlobal boolean)
	SendMessageRemote:FireServer(message, isGlobal)

	-- Refresh timer setelah mengirim
	task.delay(0.5, function()
		refreshTimerData()
		if timerData.HasTimer and timerData.RemainingTime > 0 then
			showTimerNotification(timerData.RemainingTime)
		end
		isSending = false
	end)
end

-- ====================================
-- UI SETUP
-- ====================================
mainframe.Visible = false  -- Kontrol visibilitas dari luar (misal toolbar)

-- Tombol Server mengirim dengan isGlobal = false
serverBtn.MouseButton1Click:Connect(function()
	sendMessage(false)
end)

-- Tombol Global mengirim dengan isGlobal = true
globalBtn.MouseButton1Click:Connect(function()
	sendMessage(true)
end)

textbox.FocusLost:Connect(function(enterPressed)
	if enterPressed then
		-- Jika menekan tombol Enter, kita anggap sebagai pesan Server biasa
		sendMessage(false)
	end
end)

-- ====================================
-- RECEIVE MESSAGE FROM SERVER
-- ====================================
ReceiveMessageRemote.OnClientEvent:Connect(function(messageData)
	-- Validasi tipe data dasar dari server
	if type(messageData) ~= "table" then return end

	if messageData.Type == "Error" then
		-- Tampilkan error kepada pengirim
		pcall(function()
			SG:SetCore("SendNotification", {
				Title    = "Broadcast Error",
				Text     = messageData.Message or "An unknown error occurred.",
				Duration = 4
			})
		end)

		-- Perbarui info timer jika error terkait cooldown
		local msg = messageData.Message or ""
		if msg:find("wait") or msg:find("broadcast") or msg:find("minute") or msg:find("second") then
			refreshTimerData()
		end

	elseif messageData.Type == "Message" then
		-- Hanya tampilkan jika data pesan lengkap
		if messageData.Message and messageData.SenderId then
			createNotification(messageData)
		end
	end
end)

-- ====================================
-- INITIALIZE
-- ====================================
refreshTimerData()


local CONFIG = {
	DEBUG_ENABLED = false,

	-- GANTI GRADIENT_EFFECTS MENJADI INI:
	COLOR_PRESETS = {
		{ name = "White",       color = Color3.fromRGB(255, 255, 255) },
		{ name = "Black",       color = Color3.fromRGB(0, 0, 0) },
		{ name = "Crimson Red", color = Color3.fromRGB(220, 20, 60) },
		{ name = "Ruby",        color = Color3.fromRGB(224, 17, 95) },
		{ name = "Gold",        color = Color3.fromRGB(255, 215, 0) },
		{ name = "Neon Green",  color = Color3.fromRGB(57, 255, 20) },
		{ name = "Emerald",     color = Color3.fromRGB(80, 200, 120) },
		{ name = "Cyan",        color = Color3.fromRGB(0, 255, 255) },
		{ name = "Royal Blue",  color = Color3.fromRGB(65, 105, 225) },
		{ name = "Navy",        color = Color3.fromRGB(0, 0, 128) },
		{ name = "Purple",      color = Color3.fromRGB(128, 0, 128) },
		{ name = "Amethyst",    color = Color3.fromRGB(153, 102, 204) },
		{ name = "Hot Pink",    color = Color3.fromRGB(255, 105, 180) },
		{ name = "Orange",      color = Color3.fromRGB(255, 165, 0) },
		{ name = "Silver",      color = Color3.fromRGB(192, 192, 192) },
	},

	MAX_TITLE_LENGTH = 50,
	REFRESH_INTERVAL = 5,

	BTN_ACTIVE_COLOR   = Color3.fromRGB(255, 200, 50),
	BTN_INACTIVE_COLOR = Color3.fromRGB(70,  70,  70),

	ROLE_BTN_ACTIVE_COLOR   = Color3.fromRGB(255, 200, 50),
	ROLE_BTN_INACTIVE_COLOR = Color3.fromRGB(70,  70,  70),

	ADMIN_ICON_IMAGE     = nil,
	ADMIN_ICON_LABEL     = "🛠",
	ADMIN_ICON_ALIGNMENT = "left",
	ADMIN_ICON_SETORDER  = -1,

	UseStroke       = false,
	StrokeThickness = 1,
	StrokeColor     = Color3.fromRGB(255, 255, 255),

	UseGradient    = false,
	GradientSpeed  = 90,
	GradientColor0 = Color3.fromRGB(255, 255, 255),
	GradientColor1 = Color3.fromRGB(0,   0,   0),
	GradientColor2 = Color3.fromRGB(255, 255, 255),
}

-- [BARU] Fallback warna agar tombol warna tidak pernah putih/error
local COLOR_FALLBACKS = {
	["Merah"] = "Bright red", ["Oranye"] = "Deep orange", ["Kuning"] = "New Yeller",
	["Hijau"] = "Dark green", ["Hijau Tua"] = "Earth green", ["Cyan"] = "Cyan",
	["Biru"] = "Bright blue", ["Biru Tua"] = "Navy blue", ["Ungu"] = "Royal purple",
	["Pink"] = "Hot pink", ["Putih"] = "White", ["Abu-abu"] = "Medium stone grey",
	["Hitam"] = "Really black", ["Emas"] = "Bright yellow", ["Perak"] = "Silver",
	["Coklat"] = "Brown"
}

local function debug(...) if CONFIG.DEBUG_ENABLED then print("[AdminPanel]", ...) end end
local function debugWarn(...) if CONFIG.DEBUG_ENABLED then warn("[AdminPanel]", ...) end end

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local RunService        = game:GetService("RunService")
local Teams             = game:GetService("Teams") -- [BARU] Ambil data langsung dari Teams

local LocalPlayer = Players.LocalPlayer

-- ====================================
-- GUI REFERENCES
-- ====================================
local gui               = script.Parent
local mainframe         = gui:WaitForChild("mainframe")
local notificationframe = gui:WaitForChild("NotificationFrame")
local notificationtext  = notificationframe:WaitForChild("NotificationText")
local headerframe       = mainframe:WaitForChild("HeaderFrame")
local closeBtn          = headerframe:WaitForChild("CloseBtn")

local playerlistframe   = mainframe:WaitForChild("PlayerlistFrame")
local playerimage       = playerlistframe:WaitForChild("playerimage")
local playername        = playerlistframe:WaitForChild("PlayerName")
local rolelabel         = playerlistframe:WaitForChild("Rolelabel")
local teamlabel         = playerlistframe:WaitForChild("Teamlabel")
local titlelabel        = playerlistframe:WaitForChild("Titlelabel")
local searchbox         = playerlistframe:WaitForChild("Searchbox")
local playerlist        = playerlistframe:WaitForChild("playerlist")
local playertemplateBtn = playerlist:WaitForChild("TemplatenameBtn")

local actionframe       = mainframe:WaitForChild("ActionFrame")
local actionheaderframe = actionframe:WaitForChild("ActionHeaderFrame")
local roleBtn           = actionheaderframe:WaitForChild("RoleBtn")
local titleBtn          = actionheaderframe:WaitForChild("TitleBtn")
local teamBtn           = actionheaderframe:WaitForChild("TeamBtn")

local roleframe          = actionframe:WaitForChild("RoleFrame")
local rolescrollingframe = roleframe:WaitForChild("RoleScrollingFrame")
local roletemplateBtn    = rolescrollingframe:WaitForChild("RoleTemplateBtn")
local roleBtnFrame       = roleframe:WaitForChild("RoleBtnFrame")
local roleconfirmBtn     = roleBtnFrame:WaitForChild("RoleConfirmBtn")
local rolecancelBtn      = roleBtnFrame:WaitForChild("RoleCancelBtn")

local titleframe             = actionframe:WaitForChild("TitleFrame")
local donaturframe           = titleframe:WaitForChild("DonaturFrame")
local topdonaturtemplateBtn  = donaturframe:WaitForChild("TopdonaturTemplateBtn")
local effectframe            = titleframe:WaitForChild("EffectFrame")
local titleeffecttemplateBtn = effectframe:WaitForChild("TitleEffectTemplate")
local colorpickframe         = titleframe:WaitForChild("ColorPickFrame")
local colorresult            = colorpickframe:WaitForChild("ColorResult")
local bluebox                = colorpickframe:WaitForChild("Blue")
local greenbox               = colorpickframe:WaitForChild("Green")
local redbox                 = colorpickframe:WaitForChild("Red")
local titleBtnFrame          = titleframe:WaitForChild("TitleBtnFrame")
local titlecancelBtn         = titleBtnFrame:WaitForChild("TitleCancelBtn")
local titleconfirmBtn        = titleBtnFrame:WaitForChild("TitleConfirmBtn")
local entrytitlebox          = titleframe:WaitForChild("EntryTitle")

local teamframe          = actionframe:WaitForChild("TeamFrame")
local teamcolorpickframe = teamframe:WaitForChild("ColorPickFrame")
local colortemplateBtn   = teamcolorpickframe:WaitForChild("ColorTemplateBtn")
local teamBtnFrame       = teamframe:WaitForChild("TeamBtnFrame")
local moveplayerBtn      = teamBtnFrame:WaitForChild("MovePlayerBtn")
local deleteteamBtn      = teamBtnFrame:WaitForChild("DeleteTeamBtn")
local teamlistframe      = teamframe:WaitForChild("teamlist")
local teamtemplateBtn    = teamlistframe:WaitForChild("TeamTemplateBtn")
local teamnamebox        = teamframe:WaitForChild("TeamName")
local teamcreateBtn      = teamframe:WaitForChild("TeamCreateBtn")

-- ====================================
-- REMOTES
-- ====================================
local titleRemotes        = ReplicatedStorage:WaitForChild("TitleRemotes")
local UpdateTitleRemote   = titleRemotes:WaitForChild("UpdateTitle")
local CheckAccessRemote   = titleRemotes:WaitForChild("CheckAccess")
local GetPlayerDataRemote = titleRemotes:WaitForChild("GetPlayerData")
local AssignDonaturRemote = titleRemotes:WaitForChild("AssignDonaturRank")

local giveRoleRemote = ReplicatedStorage:WaitForChild("GiveRoleRemote", 30)

local adminPanelRemotes       = ReplicatedStorage:WaitForChild("AdminPanelRemotes")
local GetTeamListRemote       = adminPanelRemotes:WaitForChild("GetTeamList")
local GetColorTemplatesRemote = adminPanelRemotes:WaitForChild("GetColorTemplates")
local TeamActionRemote        = adminPanelRemotes:WaitForChild("TeamAction")
local TeamActionResultRemote  = adminPanelRemotes:WaitForChild("TeamActionResult")

-- ====================================
-- STATE
-- ====================================
local playerButtons   = {}
local allPlayers      = {}
local selectedUserId  = nil

local currentDonaturRank    = nil
local isLoadingPlayerData   = false

local selectedRole = nil
local roleButtons  = {}

local teamButtons        = {}
local selectedTeamName   = nil
local selectedColorName  = nil
local colorTemplateBtns  = {}

local hasAccess  = false
local playerRole = "Player"

local isRefreshing = false
local currentTab   = "Role"

local effectBtns = {}
local topBtns    = {}

-- ====================================
-- INITIAL VISIBILITY
-- ====================================
mainframe.Visible             = false
notificationframe.Visible     = false
playertemplateBtn.Visible     = false
roletemplateBtn.Visible       = false
teamtemplateBtn.Visible       = false
topdonaturtemplateBtn.Visible = false
titleeffecttemplateBtn.Visible= false
colortemplateBtn.Visible      = false 

-- ====================================
-- TOPBAR PLUS ADMIN ICON
-- ====================================
local Icon = require(ReplicatedStorage:WaitForChild("Icon"))

local gradientRotation    = 0
local registeredGradients = {}

if CONFIG.UseStroke and CONFIG.UseGradient then
	RunService.Heartbeat:Connect(function(dt)
		gradientRotation = (gradientRotation + CONFIG.GradientSpeed * dt) % 180
		for _, g in pairs(registeredGradients) do g.Rotation = gradientRotation end
	end)
end

local function getIconWidget(icon)
	for _, name in ipairs({"IconFrame","IconContainer","Widget","ClickRegion"}) do
		local inst = icon:getInstance(name)
		if inst then return inst end
	end
	return icon.widget
end

local function applyStroke(icon)
	if not CONFIG.UseStroke then return end
	local widget = getIconWidget(icon)
	if not widget then return end
	local stroke = Instance.new("UIStroke")
	stroke.Name            = "AdminStroke"
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Thickness       = CONFIG.StrokeThickness
	stroke.Color           = CONFIG.StrokeColor
	stroke.Parent          = widget
	if CONFIG.UseGradient then
		local gradient = Instance.new("UIGradient")
		gradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0,   CONFIG.GradientColor0),
			ColorSequenceKeypoint.new(0.5, CONFIG.GradientColor1),
			ColorSequenceKeypoint.new(1,   CONFIG.GradientColor2),
		})
		gradient.Rotation = gradientRotation
		gradient.Parent   = stroke
		local uid = icon.UID
		registeredGradients[uid] = gradient
		icon:addToJanitor(function()
			registeredGradients[uid] = nil
			if stroke and stroke.Parent then stroke:Destroy() end
		end)
	else
		icon:addToJanitor(function()
			if stroke and stroke.Parent then stroke:Destroy() end
		end)
	end
end

local adminIcon = Icon.new()
adminIcon:setLabel(CONFIG.ADMIN_ICON_LABEL)
adminIcon:setOrder(CONFIG.ADMIN_ICON_SETORDER)
if CONFIG.ADMIN_ICON_IMAGE then adminIcon:setImage(CONFIG.ADMIN_ICON_IMAGE) end
if     CONFIG.ADMIN_ICON_ALIGNMENT == "mid"   then adminIcon:setMid()
elseif CONFIG.ADMIN_ICON_ALIGNMENT == "right" then adminIcon:setRight()
else                                               adminIcon:setLeft()
end
applyStroke(adminIcon)
adminIcon:setEnabled(false)

-- ====================================
-- NOTIFICATION
-- ====================================
local function showNotification(message, isSuccess)
	if not message or type(message) ~= "string" or message == "" then
		message = isSuccess and "Operasi berhasil" or "Operasi gagal"
	end
	notificationtext.Text       = message
	notificationtext.TextColor3 = isSuccess and Color3.fromRGB(85,255,127) or Color3.fromRGB(255,85,85)
	notificationframe.Visible                = true
	notificationframe.BackgroundTransparency = 0
	local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	task.delay(3, function()
		local fadeOut = TweenService:Create(notificationframe, tweenInfo, { BackgroundTransparency = 1 })
		fadeOut:Play()
		fadeOut.Completed:Connect(function() notificationframe.Visible = false end)
	end)
end

-- ====================================
-- TAB SWITCHING
-- ====================================
local function switchTab(tab)
	currentTab         = tab
	roleframe.Visible  = (tab == "Role")
	titleframe.Visible = (tab == "Title")
	teamframe.Visible  = (tab == "Team")
	for name, btn in pairs({ Role=roleBtn, Title=titleBtn, Team=teamBtn }) do
		btn.BackgroundColor3 = (name == tab) and Color3.fromRGB(255,200,50) or Color3.fromRGB(60,60,60)
	end
end

-- ====================================
-- PLAYER INFO
-- ====================================
local function updatePlayerInfoDisplay(userId)
	local target = Players:GetPlayerByUserId(userId)
	if not target then return end
	playername.Text = target.DisplayName
	local ok, thumbUrl = pcall(function()
		return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
	end)
	if ok and thumbUrl then playerimage.Image = thumbUrl end
	local roleVal = target:FindFirstChild("Role")
	rolelabel.Text = roleVal and ("Role: "..roleVal.Value) or "Role: -"
	teamlabel.Text = "Team: "..(target.Team and target.Team.Name or "-")
	titlelabel.Text = "Title: Loading..."
	task.spawn(function()
		local ok2, data = pcall(function() return GetPlayerDataRemote:InvokeServer(target) end)
		titlelabel.Text = (ok2 and data) and "Title: "..(data.Title ~= "" and data.Title or "-") or "Title: -"
	end)
end

-- ====================================
-- PLAYER LIST (OPTIMIZED SMART REFRESH)
-- ====================================
local function clearPlayerList()
	for _, btn in pairs(playerButtons) do 
		if btn and btn.Parent then btn:Destroy() end 
	end
	playerButtons = {}
end

local function refreshPlayerList()
	if isRefreshing then return end
	isRefreshing = true

	local filterText = searchbox.Text:lower()
	local yOffset    = 0

	local currentPlayersInServer = {}

	for _, plr in ipairs(Players:GetPlayers()) do
		currentPlayersInServer[plr.UserId] = true

		local existingBtn = playerButtons[plr.UserId]
		local isVisible = (filterText == "" or plr.DisplayName:lower():find(filterText, 1, true))

		if existingBtn then
			if isVisible then
				existingBtn.Position = UDim2.new(0, 0, 0, yOffset)
				existingBtn.Visible  = true
				existingBtn.Text = (plr == LocalPlayer) and (plr.DisplayName.." (Saya)") or plr.DisplayName
				yOffset = yOffset + existingBtn.Size.Y.Offset + 5
			else
				existingBtn.Visible = false
			end
		else
			if isVisible then
				local newBtn    = playertemplateBtn:Clone()
				newBtn.Name     = "Player_"..plr.UserId
				newBtn.Text     = (plr == LocalPlayer) and (plr.DisplayName.." (Saya)") or plr.DisplayName
				newBtn.Position = UDim2.new(0, 0, 0, yOffset)
				newBtn.Visible  = true
				newBtn.Parent   = playerlist

				newBtn.MouseButton1Click:Connect(function()
					selectedUserId = plr.UserId
					updatePlayerInfoDisplay(plr.UserId)
					loadTitleData(plr.UserId)
				end)

				playerButtons[plr.UserId] = newBtn
				yOffset = yOffset + newBtn.Size.Y.Offset + 5
			end
		end
	end

	for userId, btn in pairs(playerButtons) do
		if not currentPlayersInServer[userId] then
			if btn and btn.Parent then btn:Destroy() end
			playerButtons[userId] = nil
		end
	end

	playerlist.CanvasSize = UDim2.new(0, 0, 0, yOffset)
	isRefreshing = false
end

-- ====================================
-- ROLE SYSTEM
-- ====================================
local ROLE_TYPES = { "VIP", "VVIP", "Moderator", "Admin", "Player" }

local function buildRoleButtons()
	for _, btn in pairs(roleButtons) do if btn and btn.Parent then btn:Destroy() end end
	roleButtons = {}
	local myRole  = (LocalPlayer:FindFirstChild("Role") and LocalPlayer.Role.Value) or "Player"
	local yOffset = 0
	for _, roleName in ipairs(ROLE_TYPES) do
		local canShow = false
		if myRole == "Owner" then
			canShow = true
		elseif myRole == "Admin" then
			canShow = (roleName=="VIP" or roleName=="VVIP" or roleName=="Moderator" or roleName=="Player")
		elseif myRole == "Moderator" then
			canShow = (roleName=="VIP" or roleName=="Player")
		end
		if canShow then
			local newBtn    = roletemplateBtn:Clone()
			newBtn.Name     = "RoleBtn_"..roleName
			newBtn.Text     = roleName
			newBtn.Position = UDim2.new(0, 0, 0, yOffset)
			newBtn.Visible  = true
			newBtn.BackgroundColor3 = CONFIG.ROLE_BTN_INACTIVE_COLOR
			newBtn.Parent   = rolescrollingframe
			newBtn.MouseButton1Click:Connect(function()
				selectedRole = roleName
				for _, rb in pairs(roleButtons) do rb.BackgroundColor3 = CONFIG.ROLE_BTN_INACTIVE_COLOR end
				newBtn.BackgroundColor3 = CONFIG.ROLE_BTN_ACTIVE_COLOR
			end)
			roleButtons[roleName] = newBtn
			yOffset = yOffset + newBtn.Size.Y.Offset + 5
		end
	end
	rolescrollingframe.CanvasSize = UDim2.new(0, 0, 0, yOffset)
end

local function resetRoleForm()
	selectedRole = nil
	for _, btn in pairs(roleButtons) do btn.BackgroundColor3 = CONFIG.ROLE_BTN_INACTIVE_COLOR end
end

roleconfirmBtn.MouseButton1Click:Connect(function()
	if not selectedUserId then showNotification("Pilih player terlebih dahulu!", false); return end
	if not selectedRole   then showNotification("Pilih role terlebih dahulu!", false);   return end
	local targetPlayer = Players:GetPlayerByUserId(selectedUserId)
	if not targetPlayer then showNotification("Player tidak ditemukan!", false); return end
	showNotification("Memproses...", true)
	giveRoleRemote:FireServer({
		source="AdminPanel", action="GiveRole",
		targetUserId=targetPlayer.UserId, roleType=selectedRole,
	})
	resetRoleForm()
end)

rolecancelBtn.MouseButton1Click:Connect(function()
	resetRoleForm()
	showNotification("Dibatalkan", false)
end)

-- ====================================
-- TITLE SYSTEM
-- ====================================


local function updateDonaturButtonStates()
	for i, btn in ipairs(topBtns) do
		if i == currentDonaturRank then
			btn.BackgroundColor3 = CONFIG.BTN_ACTIVE_COLOR
			btn.BorderSizePixel  = 2
		else
			btn.BackgroundColor3 = CONFIG.BTN_INACTIVE_COLOR
			btn.BorderSizePixel  = 0
		end
	end
end


local function assignDonaturRank(rank)
	if not selectedUserId then showNotification("Pilih player terlebih dahulu!", false); return end
	local targetPlayer = Players:GetPlayerByUserId(selectedUserId)
	if not targetPlayer then showNotification("Player tidak online!", false); return end

	if currentDonaturRank == rank then
		currentDonaturRank = nil
		AssignDonaturRemote:FireServer(targetPlayer, 0)
		showNotification("Label Top Donatur #"..rank.." dihapus dari "..targetPlayer.DisplayName, true)
	else
		currentDonaturRank = rank
		AssignDonaturRemote:FireServer(targetPlayer, rank)
		showNotification("Top Donatur #"..rank.." diberikan ke "..targetPlayer.DisplayName, true)
	end
	updateDonaturButtonStates()
end

local function validateRGB(value)
	local num = tonumber(value)
	return (num and num >= 0 and num <= 255) and math.floor(num) or 0
end

local function updateColorPreview()
	colorresult.BackgroundColor3 = Color3.fromRGB(
		validateRGB(redbox.Text), validateRGB(greenbox.Text), validateRGB(bluebox.Text))
end

-- ====================================
-- COLOR PRESET SYSTEM (PENGGANTI EFEK)
-- ====================================
local function buildEffectButtons()
	for _, btn in ipairs(effectBtns) do if btn and btn.Parent then btn:Destroy() end end
	effectBtns = {}
	local xOffset = 0

	for i, preset in ipairs(CONFIG.COLOR_PRESETS) do
		local newBtn    = titleeffecttemplateBtn:Clone()
		newBtn.Name     = "Preset_" .. i
		newBtn.Text     = preset.name
		newBtn.Position = UDim2.new(0, xOffset, 0, 0)
		newBtn.Visible  = true
		newBtn.Parent   = effectframe

		-- Buat warna tombol sesuai warnanya langsung!
		newBtn.BackgroundColor3 = preset.color

		-- Buat teks jadi hitam/putih agar kontras dan mudah dibaca
		local brightness = (preset.color.R + preset.color.G + preset.color.B)
		newBtn.TextColor3 = brightness < 1.5 and Color3.new(1, 1, 1) or Color3.new(0, 0, 0)

		-- Jika diklik, langsung masukkan angkanya ke kotak RGB
		newBtn.MouseButton1Click:Connect(function()
			redbox.Text   = tostring(math.floor(preset.color.R * 255))
			greenbox.Text = tostring(math.floor(preset.color.G * 255))
			bluebox.Text  = tostring(math.floor(preset.color.B * 255))
			updateColorPreview()
		end)

		table.insert(effectBtns, newBtn)
		xOffset = xOffset + newBtn.Size.X.Offset + 5
	end
end

local function buildDonaturButtons()
	for _, btn in ipairs(topBtns) do if btn and btn.Parent then btn:Destroy() end end
	topBtns = {}
	local xOffset = 0
	for i = 1, 10 do
		local newBtn    = topdonaturtemplateBtn:Clone()
		newBtn.Name     = "Top"..i
		newBtn.Text     = "Top "..i
		newBtn.Position = UDim2.new(0, xOffset, 0, 0)
		newBtn.Visible  = true
		newBtn.BackgroundColor3 = CONFIG.BTN_INACTIVE_COLOR
		newBtn.Parent   = donaturframe
		local rankNum = i
		newBtn.MouseButton1Click:Connect(function() assignDonaturRank(rankNum) end)
		table.insert(topBtns, newBtn)
		xOffset = xOffset + newBtn.Size.X.Offset + 5
	end
end



function loadTitleData(userId)
	if isLoadingPlayerData then return end
	isLoadingPlayerData = true
	local targetPlayer = Players:GetPlayerByUserId(userId)
	if not targetPlayer then isLoadingPlayerData = false; return end

	titleconfirmBtn.Text = "Loading..."
	task.spawn(function()
		local ok, data = pcall(function() return GetPlayerDataRemote:InvokeServer(targetPlayer) end)
		isLoadingPlayerData  = false
		titleconfirmBtn.Text = "Confirm"
		if not ok or not data then return end

		entrytitlebox.Text = data.Title or ""
		local color = data.Color or { R=255, G=255, B=255 }
		redbox.Text   = tostring(color.R)
		greenbox.Text = tostring(color.G)
		bluebox.Text  = tostring(color.B)

		updateColorPreview()

		-- Gradient sudah musnah dari sini!
		currentDonaturRank = data.DonaturRank
		updateDonaturButtonStates()
	end)
end

local function resetTitleForm()
	entrytitlebox.Text    = ""
	redbox.Text           = "255"
	greenbox.Text         = "255"
	bluebox.Text          = "255"
	currentDonaturRank    = nil

	updateColorPreview()
	updateDonaturButtonStates()
	-- Gradient & EffectButtonState sudah musnah dari sini!
end

redbox:GetPropertyChangedSignal("Text"):Connect(updateColorPreview)
greenbox:GetPropertyChangedSignal("Text"):Connect(updateColorPreview)
bluebox:GetPropertyChangedSignal("Text"):Connect(updateColorPreview)

titleconfirmBtn.MouseButton1Click:Connect(function()
	if not selectedUserId then showNotification("Pilih player terlebih dahulu!", false); return end
	local titleText = entrytitlebox.Text:match("^%s*(.-)%s*$")
	if titleText ~= "" then
		local len = utf8.len(titleText)
		if len and len > CONFIG.MAX_TITLE_LENGTH then
			showNotification("Title terlalu panjang! Maksimal "..CONFIG.MAX_TITLE_LENGTH.." karakter", false)
			return
		end
	end
	local targetPlayer = Players:GetPlayerByUserId(selectedUserId)
	if not targetPlayer then showNotification("Player tidak ditemukan!", false); return end
	UpdateTitleRemote:FireServer(targetPlayer, {
		Title          = titleText,
		Color          = Color3.fromRGB(validateRGB(redbox.Text), validateRGB(greenbox.Text), validateRGB(bluebox.Text)),
		-- Kita hapus Gradient = true dan GradientEffect = ... di sini
	})
	titleconfirmBtn.Text = "Processing..."
	task.wait(0.5)
	titleconfirmBtn.Text = "Confirm"
	showNotification("Title berhasil diupdate!", true)
	titlelabel.Text = "Title: "..(titleText ~= "" and titleText or "-")
end)

titlecancelBtn.MouseButton1Click:Connect(function() resetTitleForm() end)

-- ====================================
-- TEAM SYSTEM
-- ====================================

local function updateColorTemplateBtnStates()
	for _, btn in ipairs(colorTemplateBtns) do
		if btn:GetAttribute("ColorName") == selectedColorName then
			btn.BorderSizePixel  = 3
			btn.BorderColor3     = Color3.fromRGB(255, 255, 255)
		else
			btn.BorderSizePixel  = 0
		end
	end
end

-- [PERBAIKAN] Mencegah warna jadi putih. Kita baca dari fallback atau nama yang dikirim.
local function buildColorTemplates(templates)
	for _, btn in ipairs(colorTemplateBtns) do
		if btn and btn.Parent then btn:Destroy() end
	end
	colorTemplateBtns = {}
	selectedColorName = nil

	for _, tmpl in ipairs(templates) do
		local newBtn = colortemplateBtn:Clone()
		newBtn.Name             = "ColorBtn_"..tmpl.name

		local finalColorName = tmpl.brickColorName or COLOR_FALLBACKS[tmpl.name]
		if finalColorName then
			newBtn.BackgroundColor3 = BrickColor.new(finalColorName).Color
		elseif tmpl.r then
			newBtn.BackgroundColor3 = Color3.fromRGB(tmpl.r, tmpl.g, tmpl.b)
		else
			newBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		end

		newBtn.Visible          = true
		newBtn.Parent           = teamcolorpickframe
		newBtn:SetAttribute("ColorName", tmpl.name)

		local cName = tmpl.name
		newBtn.MouseButton1Click:Connect(function()
			selectedColorName = cName
			updateColorTemplateBtnStates()
			debug("Color selected:", cName)
		end)

		table.insert(colorTemplateBtns, newBtn)
	end

	if #templates > 0 then
		selectedColorName = templates[1].name
		updateColorTemplateBtnStates()
	end

	debug("Color templates built:", #templates, "colors")
end

local colorTemplatesLoaded = false
local function loadColorTemplates()
	if colorTemplatesLoaded then return end
	colorTemplatesLoaded = true
	task.spawn(function()
		local ok, templates = pcall(function()
			return GetColorTemplatesRemote:InvokeServer()
		end)
		if ok and type(templates) == "table" and #templates > 0 then
			buildColorTemplates(templates)
		else
			debugWarn("Failed to load color templates")
		end
	end)
end

-- [PERBAIKAN] Langsung baca dari folder Teams di game agar warnanya PASTI akurat
local function buildTeamList()
	for _, btn in pairs(teamButtons) do if btn and btn.Parent then btn:Destroy() end end
	teamButtons      = {}
	selectedTeamName = nil

	task.spawn(function()
		local ok, teamList = pcall(function() return GetTeamListRemote:InvokeServer() end)
		if not ok or type(teamList) ~= "table" then return end
		local yOffset = 0
		for _, teamData in ipairs(teamList) do
			local newBtn    = teamtemplateBtn:Clone()
			newBtn.Name     = "TeamBtn_"..teamData.name
			newBtn.Text     = teamData.isCustom and ("[Custom] "..teamData.name) or teamData.name
			newBtn.Position = UDim2.new(0, 0, 0, yOffset)
			newBtn.Visible  = true

			-- Pintas cerdas: Cek langsung ke folder Teams di workspace
			local realTeamObj = Teams:FindFirstChild(teamData.name)
			if realTeamObj then
				newBtn.BackgroundColor3 = realTeamObj.TeamColor.Color
			else
				local fallbackStr = teamData.brickColorName or COLOR_FALLBACKS[teamData.name]
				if fallbackStr then
					newBtn.BackgroundColor3 = BrickColor.new(fallbackStr).Color
				else
					newBtn.BackgroundColor3 = Color3.fromRGB(teamData.r or 200, teamData.g or 200, teamData.b or 200)
				end
			end

			newBtn.Parent   = teamlistframe
			local tName = teamData.name
			newBtn.MouseButton1Click:Connect(function()
				selectedTeamName = tName
				for _, tb in pairs(teamButtons) do tb.BorderSizePixel = 0 end
				newBtn.BorderSizePixel = 2
			end)
			teamButtons[teamData.name] = newBtn
			yOffset = yOffset + newBtn.Size.Y.Offset + 5
		end
		teamlistframe.CanvasSize = UDim2.new(0, 0, 0, yOffset)
	end)
end

moveplayerBtn.MouseButton1Click:Connect(function()
	if not selectedUserId   then showNotification("Pilih player terlebih dahulu!", false); return end
	if not selectedTeamName then showNotification("Pilih team terlebih dahulu!", false);   return end
	local targetPlayer = Players:GetPlayerByUserId(selectedUserId)
	if not targetPlayer then showNotification("Player tidak ditemukan!", false); return end
	TeamActionRemote:FireServer({ action="MovePlayer", targetUserId=selectedUserId, teamName=selectedTeamName })
	showNotification("Memindahkan "..targetPlayer.DisplayName.." ke "..selectedTeamName.."...", true)
end)

deleteteamBtn.MouseButton1Click:Connect(function()
	if not selectedTeamName then showNotification("Pilih team yang akan dihapus!", false); return end
	TeamActionRemote:FireServer({ action="DeleteTeam", teamName=selectedTeamName })
	showNotification("Menghapus team "..selectedTeamName.."...", true)
end)

teamcreateBtn.MouseButton1Click:Connect(function()
	local newTeamName = teamnamebox.Text:match("^%s*(.-)%s*$")
	if newTeamName == "" then showNotification("Masukkan nama team!", false); return end
	if not selectedColorName then showNotification("Pilih warna team terlebih dahulu!", false); return end

	TeamActionRemote:FireServer({
		action     = "CreateTeam",
		teamName   = newTeamName,
		colorName  = selectedColorName, 
	})

	showNotification("Membuat team "..newTeamName.." ("..selectedColorName..")...", true)
	teamnamebox.Text = ""
	debug("CreateTeam:", newTeamName, "warna:", selectedColorName)
end)

TeamActionResultRemote.OnClientEvent:Connect(function(data)
	if not data then return end
	showNotification(data.message or "Operasi selesai", data.success or false)
	if data.success then
		task.delay(0.3, buildTeamList)
		if selectedUserId then
			local tp = Players:GetPlayerByUserId(selectedUserId)
			if tp then
				task.delay(0.5, function()
					teamlabel.Text = "Team: "..(tp.Team and tp.Team.Name or "-")
				end)
			end
		end
	end
end)

-- ====================================
-- ACCESS CHECK
-- ====================================
local function checkAccess()
	local roleVal = LocalPlayer:FindFirstChild("Role")
	playerRole    = roleVal and roleVal.Value or "Player"
	local adminRoles = { Owner=true, Admin=true, Moderator=true }
	if adminRoles[playerRole] then
		hasAccess = true
		adminIcon:setEnabled(true)
		buildRoleButtons()
		buildEffectButtons()
		buildDonaturButtons()
	else
		hasAccess = false
		adminIcon:setEnabled(false)
		if mainframe.Visible then
			mainframe.Visible = false
			selectedUserId    = nil
			adminIcon:deselect()
		end
	end
end

-- ====================================
-- OPEN / CLOSE
-- ====================================
local function openPanel()
	if not hasAccess then return end
	mainframe.Visible = true
	refreshPlayerList()
	buildTeamList()
	loadColorTemplates() 
	switchTab("Role")
	playerimage.Image = ""
	playername.Text   = "Pilih Player"
	rolelabel.Text    = "Role: -"
	teamlabel.Text    = "Team: -"
	titlelabel.Text   = "Title: -"
	selectedUserId    = nil
end

local function closePanel()
	mainframe.Visible = false
	selectedUserId    = nil
	resetTitleForm()
	resetRoleForm()
	adminIcon:deselect()
end

adminIcon:bindEvent("selected", function()
	if not hasAccess then adminIcon:deselect(); return end
	openPanel()
end)
adminIcon:bindEvent("deselected", function()
	mainframe.Visible = false
	selectedUserId    = nil
	resetTitleForm()
	resetRoleForm()
end)
closeBtn.MouseButton1Click:Connect(function() closePanel() end)
roleBtn.MouseButton1Click:Connect(function()  switchTab("Role")  end)
titleBtn.MouseButton1Click:Connect(function() switchTab("Title") end)
teamBtn.MouseButton1Click:Connect(function()
	switchTab("Team")
	buildTeamList()
	loadColorTemplates()
end)
searchbox:GetPropertyChangedSignal("Text"):Connect(function()
	if not isRefreshing then refreshPlayerList() end
end)

-- ====================================
-- ROLE REMOTE RESPONSE
-- ====================================
if giveRoleRemote then
	giveRoleRemote.OnClientEvent:Connect(function(responseData)
		if not responseData or responseData.source ~= "AdminPanel" then return end
		if responseData.success then
			showNotification(responseData.message or "Role berhasil diberikan", true)
			if selectedUserId then
				local tp = Players:GetPlayerByUserId(selectedUserId)
				if tp then
					local rv = tp:FindFirstChild("Role")
					rolelabel.Text = rv and ("Role: "..rv.Value) or "Role: -"
				end
			end
			task.wait(1.5)
			mainframe.Visible = false
		else
			showNotification(responseData.message or "Operasi gagal", false)
		end
	end)
else
	debugWarn("GiveRoleRemote not found!")
end

-- ====================================
-- PLAYER JOIN / LEAVE
-- ====================================
Players.PlayerAdded:Connect(function()
	if mainframe.Visible then 
		task.wait(0.5) 
		refreshPlayerList() 
	end
end)

Players.PlayerRemoving:Connect(function(removingPlayer)
	if mainframe.Visible then 
		refreshPlayerList() 
	end
	if selectedUserId == removingPlayer.UserId then
		selectedUserId     = nil
		currentDonaturRank = nil
		updateDonaturButtonStates()
		playerimage.Image  = ""
		playername.Text    = "Pilih Player"
		rolelabel.Text     = "Role: -"
		teamlabel.Text     = "Team: -"
		titlelabel.Text    = "Title: -"
	end
end)

-- ====================================
-- ROLE VALUE WATCHER
-- ====================================
local function watchRoleValue()
	local roleVal = LocalPlayer:WaitForChild("Role", 10)
	if roleVal then
		checkAccess()
		roleVal:GetPropertyChangedSignal("Value"):Connect(function()
			checkAccess()
			buildRoleButtons()
		end)
	end
end

-- ====================================
-- INITIALIZATION
-- ====================================
updateColorPreview()
updateDonaturButtonStates()
switchTab("Role")
task.wait(2)
task.spawn(watchRoleValue)
task.spawn(function() while task.wait(60) do checkAccess() end end)

debug("Admin Panel Client initialized")

-- CarryHandler.lua (LocalScript)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

repeat task.wait() until player.Character
task.wait(1)

local CarryConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("CarryConfig"))

local remoteFolder = ReplicatedStorage:WaitForChild(CarryConfig.REMOTE_FOLDER, 10)
if not remoteFolder then
	warn("[CARRY UI] Remote folder not found!")
	return
end

local RequestRemote  = remoteFolder:WaitForChild("CarryRequest", 10)
local ResponseRemote = remoteFolder:WaitForChild("CarryResponse", 10)
local EndRemote      = remoteFolder:WaitForChild("CarryEnd", 10)

local gui = playerGui:WaitForChild("CarryGui", 10)
if not gui then
	warn("[CARRY UI] CarryGUI not found!")
	return
end

-- UI Elements
local mainFrame        = gui:WaitForChild("MainFrame")
local notificationFrame = gui:WaitForChild("NotificationFrame")
local getDownBtn       = gui:WaitForChild("GetDownBtn")

local bridalBtn        = mainFrame:WaitForChild("BridalStyle")
local coupleHugBtn     = mainFrame:WaitForChild("CoupleHugStyle")
local pasakalBtn       = mainFrame:WaitForChild("PasakalStyle")
local piggyBackBtn     = mainFrame:WaitForChild("PiggyBackStyle")
local piggyUpperBackBtn = mainFrame:WaitForChild("PiggyUpperBackStyle")

local notiLabel  = notificationFrame:WaitForChild("NotifLabel")
local acceptBtn  = notificationFrame:WaitForChild("AcceptBtn")
local rejectBtn  = notificationFrame:WaitForChild("RejectBtn")

CarryConfig.debugPrint("UI", "All UI elements loaded")

-- ============================================
-- STATE
-- ============================================

local currentState      = "idle"
local selectedTarget    = nil
local pendingCarrier    = nil
local pendingStyle      = nil
local styleTimeoutToken = 0
local currentAnimTracks = {}
local jumpBlockConn     = nil

-- Store original sizes
local mainFrameOriginalSize  = mainFrame.Size
local notifFrameOriginalSize = notificationFrame.Size
local getDownBtnOriginalSize = getDownBtn.Size

-- ============================================
-- ANIMATION
-- ============================================

local function getHumanoid()
	return player.Character and player.Character:FindFirstChildOfClass("Humanoid")
end


local function stopAllAnimations()
	for role, track in pairs(currentAnimTracks) do
		if track and track.IsPlaying then
			track:Stop(0.2)
		end
		currentAnimTracks[role] = nil
	end
end

-- Tambahkan tabel cache ini di atas fungsi playAnimation
local loadedAnimationsCache = {}

local function playAnimation(style, role)
	local hum = getHumanoid()
	if not hum then return end

	local animator = hum:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = hum
	end

	-- Hentikan animasi yang sedang berjalan
	if currentAnimTracks[role] then
		currentAnimTracks[role]:Stop(0.15)
	end

	local animId = CarryConfig.getAnimationId(style, role)
	if animId == 0 then
		CarryConfig.debugPrint("ANIM", "No animation for", style, role)
		return
	end

	-- [SISTEM CACHE ANTI-MACET]
	local track = loadedAnimationsCache[animId]

	-- Jika belum pernah di-load, buat dan load sekali saja!
	if not track then
		local anim = Instance.new("Animation")
		anim.AnimationId = "rbxassetid://" .. tostring(animId)

		local success, newTrack = pcall(function()
			return animator:LoadAnimation(anim)
		end)

		if success and newTrack then
			track = newTrack
			loadedAnimationsCache[animId] = track -- Simpan ke ingatan memori
		else
			warn("[CARRY UI] Failed to load animation:", animId)
			return
		end
	end

	-- Mainkan animasi dari cache
	if track then
		track.Priority = Enum.AnimationPriority.Action
		track.Looped = true
		track:Play(0.2)
		currentAnimTracks[role] = track
		CarryConfig.debugPrint("ANIM", "Playing", style, role, animId)
	end
end

-- ============================================
-- UI ANIMATIONS
-- ============================================

local function fadeInMainFrame(duration)
	mainFrame.Visible = true
	mainFrame.Size = UDim2.new(0, 0, mainFrameOriginalSize.Y.Scale, mainFrameOriginalSize.Y.Offset)

	TweenService:Create(mainFrame,
		TweenInfo.new(duration or 0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Size = mainFrameOriginalSize }
	):Play()
end

local function fadeOutMainFrame(duration, callback)
	local tween = TweenService:Create(mainFrame,
		TweenInfo.new(duration or 0.25, Enum.EasingStyle.Back, Enum.EasingDirection.In),
		{ Size = UDim2.new(0, 0, mainFrameOriginalSize.Y.Scale, mainFrameOriginalSize.Y.Offset) }
	)
	tween.Completed:Connect(function()
		mainFrame.Visible = false
		mainFrame.Size = mainFrameOriginalSize
		if callback then callback() end
	end)
	tween:Play()
end

local function fadeInNotificationFrame(duration)
	notificationFrame.Visible = true
	notificationFrame.Size = UDim2.new(
		notifFrameOriginalSize.X.Scale * 0.95, notifFrameOriginalSize.X.Offset * 0.95,
		notifFrameOriginalSize.Y.Scale * 0.95, notifFrameOriginalSize.Y.Offset * 0.95
	)
	TweenService:Create(notificationFrame,
		TweenInfo.new(duration or 0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = notifFrameOriginalSize }
	):Play()
end

local function fadeOutNotificationFrame(duration, callback)
	local shrunk = UDim2.new(
		notifFrameOriginalSize.X.Scale * 0.95, notifFrameOriginalSize.X.Offset * 0.95,
		notifFrameOriginalSize.Y.Scale * 0.95, notifFrameOriginalSize.Y.Offset * 0.95
	)
	local tween = TweenService:Create(notificationFrame,
		TweenInfo.new(duration or 0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ Size = shrunk }
	)
	tween.Completed:Connect(function()
		notificationFrame.Visible = false
		notificationFrame.Size = notifFrameOriginalSize
		if callback then callback() end
	end)
	tween:Play()
end

local function fadeInGetDownBtn(duration)
	getDownBtn.Visible = true
	getDownBtn.Size = UDim2.new(
		getDownBtnOriginalSize.X.Scale * 0.8, getDownBtnOriginalSize.X.Offset * 0.8,
		getDownBtnOriginalSize.Y.Scale * 0.8, getDownBtnOriginalSize.Y.Offset * 0.8
	)
	TweenService:Create(getDownBtn,
		TweenInfo.new(duration or 0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Size = getDownBtnOriginalSize }
	):Play()
end

local function fadeOutGetDownBtn(duration, callback)
	local shrunk = UDim2.new(
		getDownBtnOriginalSize.X.Scale * 0.8, getDownBtnOriginalSize.X.Offset * 0.8,
		getDownBtnOriginalSize.Y.Scale * 0.8, getDownBtnOriginalSize.Y.Offset * 0.8
	)
	local tween = TweenService:Create(getDownBtn,
		TweenInfo.new(duration or 0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ Size = shrunk }
	)
	tween.Completed:Connect(function()
		getDownBtn.Visible = false
		getDownBtn.Size = getDownBtnOriginalSize
		if callback then callback() end
	end)
	tween:Play()
end

-- ============================================
-- UI STATE FUNCTIONS
-- ============================================

local function hideAllFrames()
	mainFrame.Visible = false
	notificationFrame.Visible = false
	getDownBtn.Visible = false

	mainFrame.Size = mainFrameOriginalSize
	notificationFrame.Size = notifFrameOriginalSize
	getDownBtn.Size = getDownBtnOriginalSize
end

local function cleanupState()
	selectedTarget = nil
	pendingCarrier = nil
	pendingStyle   = nil
	styleTimeoutToken = styleTimeoutToken + 1
	stopAllAnimations()
end

local function showStyleSelection(target)
	if not target or not target:IsA("Player") then
		warn("[CARRY UI] Invalid target for style selection")
		return
	end

	if not mainFrame or not mainFrame.Parent then
		warn("[CARRY UI] MainFrame not found or destroyed!")
		return
	end

	currentState  = "selecting_style"
	selectedTarget = target

	hideAllFrames()
	task.wait(0.05)
	fadeInMainFrame(0.35)

	local myToken = styleTimeoutToken + 1
	styleTimeoutToken = myToken

	task.delay(CarryConfig.REQUEST_TIMEOUT, function()
		if styleTimeoutToken == myToken and currentState == "selecting_style" then
			fadeOutMainFrame(0.25, function()
				cleanupState()
				currentState = "idle"
			end)
		end
	end)
end

local function showCarryNotification(carrierId, carrierName, style)
	currentState   = "pending_response"
	pendingCarrier = carrierId
	pendingStyle   = style

	hideAllFrames()

	local styleData = CarryConfig.getStyle(style)
	notiLabel.Text = string.format(
		"%s wants to carry you with %s style",
		carrierName,
		styleData and styleData.displayName or style
	)

	task.wait(0.05)
	fadeInNotificationFrame(0.2)
end

local function showGetDownButton()
	currentState = "being_carried"

	hideAllFrames()
	task.wait(0.05)
	fadeInGetDownBtn(0.3)

	if not jumpBlockConn then
		jumpBlockConn = UserInputService.JumpRequest:Connect(function()
			local hum = getHumanoid()
			if hum then hum.Jump = false end
		end)
	end
end

local function hideGetDownButton()
	fadeOutGetDownBtn(0.2)

	if jumpBlockConn then
		jumpBlockConn:Disconnect()
		jumpBlockConn = nil
	end
end

-- ============================================
-- STYLE BUTTON HANDLERS
-- ============================================

local function handleStyleSelection(styleName)
	if currentState ~= "selecting_style" or not selectedTarget then
		CarryConfig.debugPrint("UI", "Cannot select style - wrong state or no target")
		return
	end

	if not CarryConfig.isValidStyle(styleName) then
		warn("[CARRY UI] Invalid style:", styleName)
		return
	end

	fadeOutMainFrame(0.25)

	RequestRemote:FireServer({
		cmd      = "RequestCarry",
		targetId = selectedTarget.UserId,
		style    = styleName
	})

	currentState = "waiting"
end

bridalBtn.MouseButton1Click:Connect(function()        handleStyleSelection("bridal") end)
coupleHugBtn.MouseButton1Click:Connect(function()     handleStyleSelection("couplehug") end)
pasakalBtn.MouseButton1Click:Connect(function()       handleStyleSelection("pasakal") end)
piggyBackBtn.MouseButton1Click:Connect(function()     handleStyleSelection("piggyback") end)
piggyUpperBackBtn.MouseButton1Click:Connect(function() handleStyleSelection("piggyupperback") end)

-- ============================================
-- NOTIFICATION BUTTON HANDLERS
-- ============================================

acceptBtn.MouseButton1Click:Connect(function()
	if currentState ~= "pending_response" or not pendingCarrier then return end

	fadeOutNotificationFrame(0.2)
	ResponseRemote:FireServer({ cmd = "AcceptCarry" })
	currentState = "waiting"
end)

rejectBtn.MouseButton1Click:Connect(function()
	if currentState ~= "pending_response" or not pendingCarrier then return end

	fadeOutNotificationFrame(0.2, function()
		cleanupState()
		currentState = "idle"
	end)
	ResponseRemote:FireServer({ cmd = "RejectCarry" })
end)

-- ============================================
-- GET DOWN BUTTON HANDLER
-- ============================================

getDownBtn.MouseButton1Click:Connect(function()
	if currentState ~= "being_carried" and currentState ~= "carrying" then return end

	hideGetDownButton()
	EndRemote:FireServer({})
	cleanupState()
	currentState = "idle"
end)

-- ============================================
-- REMOTE EVENT HANDLERS
-- ============================================

RequestRemote.OnClientEvent:Connect(function(data)
	if not data or type(data) ~= "table" then return end

	local cmd = data.cmd
	CarryConfig.debugPrint("UI", "Received:", cmd)

	if cmd == "CarryStarted" then
		currentState = "carrying"
		fadeInGetDownBtn(0.3)
		playAnimation(data.style, "carrier")

	elseif cmd == "BeingCarried" then
		showGetDownButton()
		playAnimation(data.style, "carried")

	elseif cmd == "RequestExpired" or cmd == "RequestFailed" then
		fadeOutMainFrame(0.25, function()
			cleanupState()
			currentState = "idle"
		end)

	elseif cmd == "RequestRejected" then
		cleanupState()
		currentState = "idle"
	end
end)

ResponseRemote.OnClientEvent:Connect(function(data)
	if not data or type(data) ~= "table" then return end

	local cmd = data.cmd
	CarryConfig.debugPrint("UI", "Received:", cmd)

	if cmd == "ShowRequest" then
		showCarryNotification(data.carrierId, data.carrierName, data.style)

	elseif cmd == "RequestExpired" or cmd == "CarryFailed" then
		fadeOutNotificationFrame(0.2, function()
			cleanupState()
			currentState = "idle"
		end)
	end
end)

EndRemote.OnClientEvent:Connect(function(data)
	if not data or type(data) ~= "table" then return end

	if data.cmd == "CarryEnded" then
		hideGetDownButton()
		hideAllFrames()
		cleanupState()
		currentState = "idle"
	end
end)

-- ============================================
-- CONTEXT MENU INTEGRATION
-- ============================================

local carryEventConnection = nil

local function setupCarryEventListener()
	local eventsFolder = ReplicatedStorage:FindFirstChild("CarryEvents")
	if not eventsFolder then
		eventsFolder = Instance.new("Folder")
		eventsFolder.Name = "CarryEvents"
		eventsFolder.Parent = ReplicatedStorage
	end

	local showUIEvent = eventsFolder:FindFirstChild("ShowStyleUI")
	if not showUIEvent then
		showUIEvent = Instance.new("BindableEvent")
		showUIEvent.Name = "ShowStyleUI"
		showUIEvent.Parent = eventsFolder
	end

	return showUIEvent.Event:Connect(function(target)
		if not target or not target:IsA("Player") then
			warn("[CARRY UI] Invalid target received:", target)
			return
		end

		if not player.Character or not target.Character then
			warn("[CARRY UI] Character not ready")
			return
		end

		local myHRP     = player.Character:FindFirstChild("HumanoidRootPart")
		local targetHRP = target.Character:FindFirstChild("HumanoidRootPart")

		if not myHRP or not targetHRP then
			warn("[CARRY UI] HumanoidRootPart not found")
			return
		end

		if (myHRP.Position - targetHRP.Position).Magnitude > CarryConfig.MAX_DISTANCE then
			warn("[CARRY UI] Target too far!")
			return
		end

		if currentState == "idle" or currentState == "selecting_style" then
			showStyleSelection(target)
		elseif currentState == "waiting" then
			-- Reset stuck state and retry
			cleanupState()
			currentState = "idle"
			task.wait(0.1)
			showStyleSelection(target)
		else
			CarryConfig.debugPrint("UI", "Cannot show - current state:", currentState)
		end
	end)
end

carryEventConnection = setupCarryEventListener()

-- ============================================
-- DEBUG: Test button (only when debug enabled)
-- ============================================

if CarryConfig.DEBUG_ENABLED then
	local testBtn = Instance.new("TextButton")
	testBtn.Size = UDim2.new(0, 100, 0, 30)
	testBtn.Position = UDim2.new(0.5, -50, 0, 100)
	testBtn.Text = "TEST CARRY UI"
	testBtn.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
	testBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	testBtn.Parent = gui

	testBtn.MouseButton1Click:Connect(function()
		mainFrame.Visible = true
		fadeInMainFrame(0.35)
	end)
end

-- ============================================
-- RESPAWN HANDLING
-- ============================================

player.CharacterAdded:Connect(function()
	hideAllFrames()
	cleanupState()
	currentState = "idle"

	if carryEventConnection then
		carryEventConnection:Disconnect()
	end

	task.wait(1)
	carryEventConnection = setupCarryEventListener()
end)

-- ============================================
-- CLEANUP ON LEAVE
-- ============================================

Players.PlayerRemoving:Connect(function(leavingPlayer)
	if leavingPlayer == player then
		if carryEventConnection then carryEventConnection:Disconnect() end
		if jumpBlockConn then jumpBlockConn:Disconnect() end
		stopAllAnimations()
		cleanupState()
	end
end)

-- ============================================
-- INITIALIZATION
-- ============================================

hideAllFrames()
CarryConfig.debugPrint("UI", "Carry UI Initialized")

local Players            = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")

local ClientConfig = require(script.ClientConfig)
local ClientUI     = require(script.ClientUI)

-- TopbarPlus (pastikan tersedia di ReplicatedStorage)
local Icon = require(ReplicatedStorage:WaitForChild("Icon"))

-- ============================================
-- REFERENCES
-- ============================================
local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local gui       = playerGui:WaitForChild("DonationBoard")  -- Sesuaikan nama ScreenGui

local UI = {
	mainFrame         = gui:WaitForChild("MainFrame"),
	messageFrame      = gui:WaitForChild("MessageFrame"),
	notificationFrame = gui:WaitForChild("NotificationFrame"),
	container         = gui:WaitForChild("MainFrame"):WaitForChild("Container"),
	templateFrame     = gui:WaitForChild("MainFrame"):WaitForChild("Container"):WaitForChild("TemplateFrame"),
}

-- ============================================
-- STATE
-- ============================================
local State = {
	productsLoaded       = false,
	isLoading            = false,
	isSending            = false,  -- Mencegah double-send broadcast
	currentButtons       = {},
	lastPurchasedAmount  = 0,
	canSendMessage       = false,
	lastMessageTime      = 0,
}

-- ============================================
-- DEBUG
-- ============================================
local function debugLog(...)
	if ClientConfig.DEBUG.ENABLED and ClientConfig.DEBUG.SHOW_EVENTS then
		print("[CLIENT]", ...)
	end
end

-- ============================================
-- PRODUCT UI
-- ============================================

local loadProducts
local createProductButton
local clearProducts

createProductButton = function(productData, index)
	local frame = UI.templateFrame:Clone()
	frame.Name    = "Product_" .. productData.Id
	frame.Visible = true
	frame.Parent  = UI.container

	local btn = frame:WaitForChild("TemplateBtn")
	btn.Text  = "R$ " .. ClientUI.formatNumber(productData.Price)

	local yPos = (index - 1) * (frame.Size.Y.Offset + ClientConfig.UI.BUTTON_SPACING)
	frame.Position = UDim2.new(0, 0, 0, yPos)

	-- Click handler dengan anti double-click
	local isProcessing = false
	btn.MouseButton1Click:Connect(function()
		if isProcessing then return end
		isProcessing = true

		local originalText = btn.Text
		btn.Text = ClientConfig.UI.PROCESSING_TEXT

		State.lastPurchasedAmount = productData.Price

		local ok, err = pcall(function()
			MarketplaceService:PromptProductPurchase(player, productData.Id)
		end)

		task.wait(0.5)
		btn.Text     = originalText
		isProcessing = false

		if not ok then
			debugLog("Purchase error:", err)
			ClientUI.notify("Error", ClientConfig.MESSAGES.PURCHASE_FAILED, 3)
		end
	end)

	btn.MouseEnter:Connect(function()
		btn.BackgroundTransparency = 0.3
	end)
	btn.MouseLeave:Connect(function()
		btn.BackgroundTransparency = 1
	end)

	table.insert(State.currentButtons, frame)
	return frame
end

clearProducts = function()
	for _, btn in ipairs(State.currentButtons) do
		if btn and btn.Parent then btn:Destroy() end
	end
	State.currentButtons = {}
	ClientUI.hideError(UI.container)
end

loadProducts = function()
	if State.isLoading or State.productsLoaded then return end
	State.isLoading = true

	ClientUI.setLoading(UI.container, true)
	clearProducts()

	debugLog("Requesting products...")

	local remote = ReplicatedStorage:WaitForChild("GetDeveloperProducts", 10)
	if not remote then
		ClientUI.setLoading(UI.container, false)
		ClientUI.showError(UI.container, ClientConfig.MESSAGES.SERVER_UNAVAILABLE)
		ClientUI.notify("Error", "Server tidak siap", 3)
		State.isLoading = false
		return
	end

	local ok, products = pcall(function()
		return remote:InvokeServer()
	end)

	ClientUI.setLoading(UI.container, false)

	if ok and products and #products > 0 then
		debugLog("Loaded", #products, "products")
		for i, product in ipairs(products) do
			createProductButton(product, i)
			task.wait(ClientConfig.UI.BUTTON_CREATE_DELAY)
		end

		local totalH = #products * (UI.templateFrame.Size.Y.Offset + ClientConfig.UI.BUTTON_SPACING)
		UI.container.CanvasSize = UDim2.new(0, 0, 0, totalH)
		State.productsLoaded = true
		ClientUI.notify("Berhasil", #products .. " produk tersedia", 2)
	else
		local msg = ok and ClientConfig.MESSAGES.NO_PRODUCTS
			or ("Error: " .. tostring(products))
		ClientUI.showError(UI.container, msg)
		ClientUI.notify("Error", ClientConfig.MESSAGES.LOAD_FAILED, 3)
	end

	State.isLoading = false
end

-- ============================================
-- TOPBAR PLUS
-- ============================================

local donationIcon = Icon.new()
	:setLabel("")
	:setImage("rbxassetid://11560341824")
	:setOrder(3)
	:setRight()
	:bindEvent("selected", function()
		UI.mainFrame.Visible = true
		debugLog("Donation UI dibuka via TopbarPlus")
		if not State.productsLoaded and not State.isLoading then
			task.spawn(loadProducts)
		end
	end)
	:bindEvent("deselected", function()
		UI.mainFrame.Visible = false
		debugLog("Donation UI ditutup via TopbarPlus")
	end)

UI.mainFrame:GetPropertyChangedSignal("Visible"):Connect(function()
	if not UI.mainFrame.Visible then
		donationIcon:deselect()
	end
end)

-- ============================================
-- MESSAGE UI
-- ============================================

local function showMessageFrame(amount)
	State.lastPurchasedAmount = amount
	State.canSendMessage      = true

	UI.mainFrame.Visible    = false
	UI.messageFrame.Visible = true

	local textbox = UI.messageFrame:WaitForChild("TextBox")
	textbox.Text = ""
	textbox:CaptureFocus()

	debugLog("Message frame dibuka, amount:", amount)
end

local function hideMessageFrame(shouldSendDefault)
	-- Auto-kirim dengan pesan default jika donor menutup frame tanpa send
	if shouldSendDefault and State.lastPurchasedAmount > 0 then
		debugLog("Auto-send broadcast dengan pesan default")
		local remote = ReplicatedStorage:WaitForChild("BroadcastDonationMessage", 5)
		if remote then
			pcall(function()
				remote:InvokeServer(ClientConfig.MESSAGE.DEFAULT_MESSAGE, State.lastPurchasedAmount)
			end)
		end
		State.lastPurchasedAmount = 0
	end

	UI.messageFrame.Visible = false
	State.canSendMessage    = false

	local textbox = UI.messageFrame:WaitForChild("TextBox")
	textbox.Text  = ""

	debugLog("Message frame ditutup")
end

local function sendMessage()
	if State.isSending then return end

	local textbox = UI.messageFrame:WaitForChild("TextBox")
	local message = textbox.Text:match("^%s*(.-)%s*$")

	if #message < 1 then
		ClientUI.notify("Error", ClientConfig.MESSAGES.MESSAGE_TOO_SHORT, 3)
		return
	end
	if #message > ClientConfig.MESSAGE.MAX_LENGTH then
		ClientUI.notify("Error", ClientConfig.MESSAGES.MESSAGE_TOO_LONG, 3)
		return
	end

	-- Cooldown client-side (anti double send)
	local now       = tick()
	local remaining = ClientConfig.MESSAGE.COOLDOWN - (now - State.lastMessageTime)
	if remaining > 0 then
		ClientUI.notify("Cooldown", "Tunggu " .. math.ceil(remaining) .. " detik.", 2)
		return
	end

	local remote = ReplicatedStorage:WaitForChild("BroadcastDonationMessage", 5)
	if not remote then
		ClientUI.notify("Error", "Server tidak tersedia.", 3)
		return
	end

	State.isSending = true
	local ok, result = pcall(function()
		return remote:InvokeServer(message, State.lastPurchasedAmount)
	end)
	State.isSending = false

	if ok and result then
		ClientUI.notify("Berhasil", ClientConfig.MESSAGES.MESSAGE_SENT, 3)
		State.lastMessageTime     = tick()
		State.lastPurchasedAmount = 0
		hideMessageFrame(false)
		debugLog("Pesan berhasil dikirim")
	else
		ClientUI.notify("Error", "Gagal mengirim: " .. tostring(result), 3)
	end
end

-- ============================================
-- BROADCAST LISTENER
-- ============================================

local function setupBroadcastListener()
	local receiveRemote = ReplicatedStorage:WaitForChild("ReceiveDonationBroadcast", 10)
	if not receiveRemote then
		warn("[CLIENT] ReceiveDonationBroadcast remote tidak ditemukan!")
		return
	end

	receiveRemote.OnClientEvent:Connect(function(displayName, amount, message)
		debugLog("Broadcast diterima:", displayName, amount)

		-- Tampilkan di chat (sudah dicek CanUserChatAsync di dalam ClientUI)
		ClientUI.sendDonationChatMessage(displayName, amount)

		-- Tampilkan notifikasi UI jika memenuhi minimum
		if amount >= ClientConfig.NOTIFICATION.MIN_DONATION then
			ClientUI.updateNotificationContent(displayName, amount, message)
			ClientUI.showNotification()
			task.delay(5, function()
				ClientUI.hideNotification()
			end)
		else
			debugLog("Skip notifikasi UI (amount < MIN_DONATION)")
		end
	end)

	debugLog("Broadcast listener aktif")
end

-- ============================================
-- PURCHASE HANDLER
-- ============================================

MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId, productId, isPurchased)
	if userId ~= player.UserId or not isPurchased then return end
	debugLog("Purchase selesai:", productId)

	if State.lastPurchasedAmount >= ClientConfig.MESSAGE.MIN_DONATION then
		task.wait(1)
		showMessageFrame(State.lastPurchasedAmount)
	else
		UI.mainFrame.Visible = false
		debugLog("Auto-closed (donasi kecil, tanpa message frame)")
	end
end)

-- ============================================
-- UI SETUP
-- ============================================

UI.mainFrame.Visible         = false
UI.templateFrame.Visible     = false
UI.messageFrame.Visible      = false
UI.notificationFrame.Visible = false

-- Main frame close button
UI.mainFrame:WaitForChild("Header"):WaitForChild("CloseBtn").MouseButton1Click:Connect(function()
	UI.mainFrame.Visible = false
	donationIcon:deselect()
	debugLog("Main frame ditutup")
end)

-- Message frame buttons
local messageHeader = UI.messageFrame:WaitForChild("Header")
local sendBtn       = UI.messageFrame:WaitForChild("SendBtn")
local cancelBtn     = UI.messageFrame:WaitForChild("CancelBtn")
local textbox       = UI.messageFrame:WaitForChild("TextBox")

messageHeader:WaitForChild("CloseBtn").MouseButton1Click:Connect(function()
	hideMessageFrame(true)
end)
cancelBtn.MouseButton1Click:Connect(function()
	hideMessageFrame(true)
end)
sendBtn.MouseButton1Click:Connect(sendMessage)

textbox.FocusLost:Connect(function(enterPressed)
	if enterPressed and State.canSendMessage then
		sendMessage()
	end
end)

-- ============================================
-- INITIALIZATION
-- ============================================

ClientUI.initNotification(UI.notificationFrame)
setupBroadcastListener()

-- Cleanup icon saat player keluar
Players.PlayerRemoving:Connect(function(leavingPlayer)
	if leavingPlayer == player then
		if donationIcon then donationIcon:destroy() end
		debugLog("Cleanup icon selesai")
	end
end)

debugLog("DonationClientHandler initialized")
debugLog("MIN_DONATION notifikasi:", ClientConfig.NOTIFICATION.MIN_DONATION)

local ClientConfig = {}

-- ============================================
-- DEBUG
-- ============================================
ClientConfig.DEBUG = {
	ENABLED      = false,
	SHOW_EVENTS  = true,
	SHOW_ERRORS  = true,
}

-- ============================================
-- UI SETTINGS
-- ============================================
ClientConfig.UI = {
	BUTTON_SPACING      = 5,
	BUTTON_CREATE_DELAY = 0.03,
	LOADING_TEXT        = "Memuat produk...",
	PROCESSING_TEXT     = "Processing...",
}

-- ============================================
-- MESSAGE SETTINGS
-- ============================================
ClientConfig.MESSAGE = {
	MIN_DONATION    = 13,
	MAX_LENGTH      = 200,
	COOLDOWN        = 10,
	DEFAULT_MESSAGE = "Welcome to NIGHTBEAT PARTY",
}

-- ============================================
-- NOTIFICATION SETTINGS
-- ============================================
ClientConfig.NOTIFICATION = {
	ENABLED          = true,
	MIN_DONATION     = 13,
	SOUND_ID         = "rbxassetid://82038059105956",
	SOUND_VOLUME     = 0.5,
	SLIDE_TIME       = 0.4,
	FADE_TIME        = 0.3,
	SHAKE_ENABLED    = true,
	SHAKE_INTENSITY  = 5,
	SHAKE_DURATION   = 0.15,
}

-- ============================================
-- DONATION COLORS (by tier, descending)
-- ============================================
ClientConfig.DONATION_COLORS = {
	{min = 2000, color = Color3.fromRGB(230, 33,  23),  name = "Legendary"}, -- Untuk Steak Sapi (2000)
	{min = 1000, color = Color3.fromRGB(233, 30,  99),  name = "Epic"},      -- Untuk Pizza (1000)
	{min = 500,  color = Color3.fromRGB(156, 39,  176), name = "Rare"},      -- Untuk Ayam Goreng (500)
	{min = 250,  color = Color3.fromRGB(63,  81,  181), name = "Super"},     -- Untuk Burger (250)
	{min = 100,  color = Color3.fromRGB(33,  150, 243), name = "Great"},     -- Untuk Kentang Goreng (100)
	{min = 50,   color = Color3.fromRGB(0,   188, 212), name = "Good"},      -- Untuk Donat (50)
	{min = 30,   color = Color3.fromRGB(0,   150, 136), name = "Nice"},      -- Untuk Es Krim (30)
	{min = 0,    color = Color3.fromRGB(76,  175, 80),  name = "Thanks"},    -- Untuk Permen (15) ke bawah
}

-- ============================================
-- CHAT MESSAGES (variasi berdasarkan tier)
-- Gunakan %s untuk nama donor dan %s untuk jumlah.
-- ============================================
ClientConfig.CHAT_MESSAGES = {
	{min = 10000, messages = {
		"WOAHH! %s has donated %s Robux!",
		"LEGENDARY! %s donated %s Robux!",
		"AMAZING! %s just donated %s Robux!",
		"INSANE! %s donated %s Robux!",
	}},
	{min = 5000, messages = {
		"WOW! %s has donated %s Robux!",
		"EPIC! %s donated %s Robux!",
		"INCREDIBLE! %s just donated %s Robux!",
		"AWESOME! %s donated %s Robux!",
	}},
	{min = 2000, messages = {
		"Woahh! %s has donated %s Robux!",
		"Amazing! %s donated %s Robux!",
		"Fantastic! %s just donated %s Robux!",
	}},
	{min = 1000, messages = {
		"Woahh! %s has donated %s Robux!",
		"Great! %s donated %s Robux!",
		"Awesome! %s just donated %s Robux!",
	}},
	{min = 500, messages = {
		"Woahh! %s has donated %s Robux!",
		"Nice! %s donated %s Robux!",
		"Thanks! %s just donated %s Robux!",
	}},
	{min = 200, messages = {
		"Woahh! %s has donated %s Robux!",
		"Thanks! %s donated %s Robux!",
	}},
	{min = 100, messages = {
		"Woahh! %s has donated %s Robux!",
		"Thank you! %s donated %s Robux!",
	}},
	{min = 0, messages = {
		"Thank you! %s has donated %s Robux!",
		"Thanks! %s donated %s Robux!",
	}},
}

-- ============================================
-- MESSAGES (UI strings)
-- ============================================
ClientConfig.MESSAGES = {
	NO_PRODUCTS         = "Tidak ada produk donasi\n\nHubungi developer untuk bantuan.",
	SERVER_UNAVAILABLE  = "Server tidak tersedia!\n\nSilakan coba lagi.",
	PURCHASE_FAILED     = "Gagal membuka pembelian.",
	LOAD_FAILED         = "Gagal memuat produk.",
	MESSAGE_TOO_SHORT   = "Pesan terlalu pendek!",
	MESSAGE_TOO_LONG    = "Pesan terlalu panjang! (Maks 200 karakter)",
	MESSAGE_SENT        = "Pesan Terkirim!",
}

return ClientConfig

local TweenService    = game:GetService("TweenService")
local StarterGui      = game:GetService("StarterGui")
local TextChatService = game:GetService("TextChatService")
local Players         = game:GetService("Players")

local ClientConfig = require(script.Parent.ClientConfig)

local ClientUI = {}

-- ============================================
-- DEBUG
-- ============================================
local function debugLog(category, ...)
	if not ClientConfig.DEBUG.ENABLED then return end
	local show = (category == "UI"    and ClientConfig.DEBUG.SHOW_EVENTS)
		or (category == "ERROR" and ClientConfig.DEBUG.SHOW_ERRORS)
	if not show then return end
	if category == "ERROR" then
		warn("[CLIENT ERROR]", ...)
	else
		print("[CLIENT]", ...)
	end
end

-- ============================================
-- UTILITY
-- ============================================

function ClientUI.notify(title, text, duration)
	pcall(function()
		StarterGui:SetCore("SendNotification", {
			Title    = title,
			Text     = text,
			Duration = duration or 3
		})
	end)
end

function ClientUI.formatNumber(num)
	num = tonumber(num) or 0
	local formatted = tostring(num)
	while true do
		local k
		formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
		if k == 0 then break end
	end
	return formatted
end

-- ============================================
-- LOADING INDICATOR
-- ============================================

function ClientUI.setLoading(container, show, text)
	local loading = container:FindFirstChild("LoadingLabel")
	if show then
		if not loading then
			loading = Instance.new("TextLabel")
			loading.Name               = "LoadingLabel"
			loading.Size               = UDim2.new(1, -20, 0, 60)
			loading.Position           = UDim2.new(0, 10, 0, 20)
			loading.BackgroundTransparency = 1
			loading.TextColor3         = Color3.fromRGB(255, 255, 255)
			loading.TextSize           = 16
			loading.Font               = Enum.Font.GothamSemibold
			loading.TextWrapped        = true
			loading.Parent             = container
		end
		loading.Text    = text or ClientConfig.UI.LOADING_TEXT
		loading.Visible = true
	elseif loading then
		loading.Visible = false
	end
end

function ClientUI.showError(container, message)
	local errorLabel = container:FindFirstChild("ErrorLabel")
	if not errorLabel then
		errorLabel = Instance.new("TextLabel")
		errorLabel.Name               = "ErrorLabel"
		errorLabel.Size               = UDim2.new(1, -20, 0, 100)
		errorLabel.Position           = UDim2.new(0, 10, 0, 50)
		errorLabel.BackgroundTransparency = 1
		errorLabel.TextColor3         = Color3.fromRGB(255, 100, 100)
		errorLabel.TextSize           = 14
		errorLabel.Font               = Enum.Font.Gotham
		errorLabel.TextWrapped        = true
		errorLabel.Parent             = container
	end
	errorLabel.Text    = message
	errorLabel.Visible = true
end

function ClientUI.hideError(container)
	local errorLabel = container:FindFirstChild("ErrorLabel")
	if errorLabel then
		errorLabel.Visible = false
	end
end

-- ============================================
-- DONATION COLORS
-- ============================================

function ClientUI.getDonationColor(amount)
	for _, tier in ipairs(ClientConfig.DONATION_COLORS) do
		if amount >= tier.min then
			return tier.color, tier.name
		end
	end
	local default = ClientConfig.DONATION_COLORS[#ClientConfig.DONATION_COLORS]
	return default.color, default.name
end

-- ============================================
-- CHAT MESSAGE SYSTEM
-- [WAJIB Roblox] Menggunakan TextChannel:DisplaySystemMessage()
-- bukan SetCore("ChatMakeSystemMessage") yang sudah deprecated.
-- ============================================

local function colorToHex(color)
	if not color then return "FFFFFF" end
	return string.format("%02X%02X%02X",
		math.floor(color.R * 255),
		math.floor(color.G * 255),
		math.floor(color.B * 255)
	)
end

local function getChatMessageTemplate(amount)
	for _, tier in ipairs(ClientConfig.CHAT_MESSAGES) do
		if amount >= tier.min then
			local msgs = tier.messages
			return msgs[math.random(1, #msgs)]
		end
	end
	return "Thank you! %s has donated %s Robux!"
end

--[[
    Kirim pesan sistem berwarna ke chat Roblox.
    
    PENTING (Roblox compliance):
    - Hanya bisa dipanggil dari LocalScript (client side).
    - Cek CanUserChatAsync() terlebih dahulu sebelum display.
    - Gunakan DisplaySystemMessage() — ini system message, bukan player message,
      sehingga tidak memerlukan filtering konten (sudah built-in).
    - RBXGeneral digunakan sebagai channel default.
--]]
function ClientUI.sendDonationChatMessage(displayName, amount)
	-- Cek apakah player lokal bisa melihat chat
	local localPlayer = Players.LocalPlayer
	local canChat = false
	local ok, err = pcall(function()
		canChat = TextChatService:CanUserChatAsync(localPlayer.UserId)
	end)

	if not ok then
		debugLog("ERROR", "CanUserChatAsync gagal:", err)
		return
	end

	if not canChat then
		debugLog("UI", "Player tidak bisa melihat chat, skip system message")
		return
	end

	pcall(function()
		-- Tunggu TextChannels tersedia (seharusnya sudah ada saat game berjalan)
		local textChannels = TextChatService:FindFirstChild("TextChannels")
		if not textChannels then
			debugLog("ERROR", "TextChannels tidak ditemukan")
			return
		end

		local generalChannel = textChannels:FindFirstChild("RBXGeneral")
		if not generalChannel then
			debugLog("ERROR", "RBXGeneral channel tidak ditemukan")
			return
		end

		local color    = ClientUI.getDonationColor(amount)
		local hexColor = colorToHex(color)
		local template = getChatMessageTemplate(amount)
		local message  = string.format(template, displayName, ClientUI.formatNumber(amount))

		-- Rich text untuk warna (TextChatService mendukung rich text di system messages)
		local richMessage = string.format(
			'<font color="#%s"><b>%s</b></font>',
			hexColor, message
		)

		-- [WAJIB] Gunakan DisplaySystemMessage, bukan cara legacy
		generalChannel:DisplaySystemMessage(richMessage)
		debugLog("UI", "System chat message ditampilkan:", message)
	end)
end

-- ============================================
-- NOTIFICATION SYSTEM
-- ============================================

local NotificationState = {
	frame                 = nil,
	sound                 = nil,
	originalPos           = nil,
	isShowing             = false,
	currentTweens         = {},
	playerNameLabel       = nil,
	robuxAmountLabel      = nil,
	notificationTextLabel = nil,
}

function ClientUI.initNotification(notificationFrame)
	NotificationState.frame       = notificationFrame
	NotificationState.originalPos = notificationFrame.Position
	notificationFrame.Visible     = false

	local headerFrame = notificationFrame:WaitForChild("HeaderFrame", 5)
	if headerFrame then
		NotificationState.playerNameLabel  = headerFrame:WaitForChild("PlayerName",  5)
		NotificationState.robuxAmountLabel = headerFrame:WaitForChild("RobuxAmount", 5)
	end
	NotificationState.notificationTextLabel = notificationFrame:WaitForChild("NotificationText", 5)

	-- Buat sound sekali saja
	if not NotificationState.sound then
		local sound              = Instance.new("Sound")
		sound.SoundId            = ClientConfig.NOTIFICATION.SOUND_ID
		sound.Volume             = ClientConfig.NOTIFICATION.SOUND_VOLUME
		sound.RollOffMaxDistance = 0
		sound.Parent             = notificationFrame
		NotificationState.sound  = sound
	end

	debugLog("UI", "Notification initialized")
end

local function cancelTweens()
	for _, tween in ipairs(NotificationState.currentTweens) do
		if tween then tween:Cancel() end
	end
	NotificationState.currentTweens = {}
end

local function shakeNotification()
	if not ClientConfig.NOTIFICATION.SHAKE_ENABLED then return end

	local frame     = NotificationState.frame
	local intensity = ClientConfig.NOTIFICATION.SHAKE_INTENSITY
	local duration  = ClientConfig.NOTIFICATION.SHAKE_DURATION

	for _ = 1, 3 do
		local offsetX = math.random(-intensity, intensity)
		local offsetY = math.random(-intensity, intensity)
		frame.Position = UDim2.new(
			NotificationState.originalPos.X.Scale,
			NotificationState.originalPos.X.Offset + offsetX,
			NotificationState.originalPos.Y.Scale,
			NotificationState.originalPos.Y.Offset + offsetY
		)
		task.wait(duration / 3)
	end
	frame.Position = NotificationState.originalPos
end

function ClientUI.updateNotificationContent(displayName, amount, message)
	if NotificationState.playerNameLabel then
		NotificationState.playerNameLabel.Text = displayName
	end
	if NotificationState.robuxAmountLabel then
		NotificationState.robuxAmountLabel.Text = ClientUI.formatNumber(amount)
	end
	if NotificationState.notificationTextLabel then
		NotificationState.notificationTextLabel.Text = message or ""
	end
	debugLog("UI", "Notification content updated:", displayName, amount)
end

function ClientUI.showNotification()
	local frame = NotificationState.frame
	if not frame then return end

	if NotificationState.isShowing then
		ClientUI.hideNotification()
		task.wait(0.15)
	end

	NotificationState.isShowing = true
	cancelTweens()

	if NotificationState.sound then
		NotificationState.sound:Play()
	end

	-- Mulai dari luar layar (kanan)
	local startPos = UDim2.new(
		1.5,
		NotificationState.originalPos.X.Offset,
		NotificationState.originalPos.Y.Scale,
		NotificationState.originalPos.Y.Offset
	)
	frame.Position = startPos
	frame.Visible  = true

	local slideIn = TweenService:Create(
		frame,
		TweenInfo.new(ClientConfig.NOTIFICATION.SLIDE_TIME, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{Position = NotificationState.originalPos}
	)
	table.insert(NotificationState.currentTweens, slideIn)
	slideIn:Play()

	slideIn.Completed:Connect(function()
		task.spawn(shakeNotification)
	end)

	debugLog("UI", "Notification shown")
end

function ClientUI.hideNotification()
	local frame = NotificationState.frame
	if not frame or not NotificationState.isShowing then return end

	cancelTweens()

	local endPos = UDim2.new(
		1.5,
		NotificationState.originalPos.X.Offset,
		NotificationState.originalPos.Y.Scale,
		NotificationState.originalPos.Y.Offset
	)

	local slideOut = TweenService:Create(
		frame,
		TweenInfo.new(ClientConfig.NOTIFICATION.SLIDE_TIME, Enum.EasingStyle.Back, Enum.EasingDirection.In),
		{Position = endPos}
	)
	slideOut:Play()

	slideOut.Completed:Once(function()
		frame.Visible           = false
		NotificationState.isShowing = false
		debugLog("UI", "Notification hidden")
	end)
end

return ClientUI

-- ====================================
-- MAIN CLIENT SCRIPT (SIMPLIFIED)
-- ====================================
-- Removed: Give gamepass UI and handlers
-- Kept: Shop UI for self-purchase only
-- ====================================

local Config = require(script.Config)
local Logger = require(script.Logger)
local NotificationManager = require(script.NotificationManager)
local UIManager = require(script.UIManager)
local ShopHandler = require(script.ShopHandler)

-- ====================================
-- SERVICES
-- ====================================
local Player = game.Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ====================================
-- GUI ELEMENTS (SHOP ONLY)
-- ====================================
local gui = script.Parent
local mainframe = gui:WaitForChild("MainFrame")
local ShopBtn = gui:WaitForChild("Shop")
local content = mainframe:WaitForChild("Content")
local VVIPFrame = content:WaitForChild("VVIP Pass")
local VVIPBuyBtn = VVIPFrame:WaitForChild("BuyBtn")
local VIPFrame = content:WaitForChild("VIP Pass")
local VIPBuyBtn = VIPFrame:WaitForChild("BuyBtn")
local closeBtn = mainframe:WaitForChild("Header"):WaitForChild("CloseBtn")

-- Notification GUI
local notificationframe = gui:WaitForChild("NotificationFrame")
local notificationtext = notificationframe:WaitForChild("NotificationText")

-- ====================================
-- REMOTES
-- ====================================
local GamepassFolder = ReplicatedStorage:WaitForChild("Gamepass")
local remotes = {
	shopRequest = GamepassFolder:WaitForChild("ShopRequest", Config.RemoteTimeout),
	playerDataUpdated = GamepassFolder:WaitForChild("PlayerDataUpdated", Config.RemoteTimeout),
	refreshRole = GamepassFolder:WaitForChild("RefreshRole", Config.RemoteTimeout)
}

Logger:Success("Connected to remotes")

-- ====================================
-- INITIALIZE MODULES
-- ====================================
NotificationManager:Init(notificationframe, notificationtext)
ShopHandler:Init(remotes, UIManager, NotificationManager)

-- Setup gamepass data
local GamepassData = {
	VVIP = {
		Frame = VVIPFrame,
		Button = VVIPBuyBtn,
		IDs = {},
		Owned = false,
		Name = "VVIP Pass",
		Price = 0
	},
	VIP = {
		Frame = VIPFrame,
		Button = VIPBuyBtn,
		IDs = {},
		Owned = false,
		Name = "VIP Pass",
		Price = 0
	}
}

ShopHandler:SetGamepassData(GamepassData)

-- ====================================
-- EVENT HANDLERS - SHOP
-- ====================================
ShopBtn.MouseButton1Click:Connect(function()
	mainframe.Visible = not mainframe.Visible

	if mainframe.Visible then
		if not ShopHandler.shopDataLoaded then
			ShopHandler:LoadShopData()
		end
	end
end)

closeBtn.MouseButton1Click:Connect(function()
	mainframe.Visible = false
end)

VVIPBuyBtn.MouseButton1Click:Connect(function()
	ShopHandler:PromptPurchase("VVIP")
end)

VIPBuyBtn.MouseButton1Click:Connect(function()
	ShopHandler:PromptPurchase("VIP")
end)

-- ====================================
-- UPDATE HANDLER
-- ====================================
remotes.playerDataUpdated.OnClientEvent:Connect(function(updateData)
	local updateType = updateData.type

	Logger:Debug("Received update: " .. updateType)

	if updateType == "ownership_updated" then
		local gamepassType = updateData.gamepassType
		ShopHandler:HandleOwnershipUpdate(gamepassType, true)

	elseif updateType == "role_updated" then
		Logger:Info("Role updated: " .. updateData.role)

	elseif updateType == "purchase_complete" then
		local gamepassType = updateData.gamepassType
		ShopHandler:HandleOwnershipUpdate(gamepassType, true)
		NotificationManager:ShowVisual(updateData.message, true)

	else
		Logger:Warn("Unknown update type: " .. tostring(updateType))
	end
end)

-- ====================================
-- INITIALIZATION
-- ====================================
mainframe.Visible = Config.StartVisible
notificationframe.Visible = false

Logger:Info("Initializing...")

task.spawn(function()
	Player.CharacterAdded:Wait()
	task.wait(2)
	ShopHandler:LoadShopData()
	Logger:Success("Initialization complete - Simplified Version (Self-Purchase Only)")
end)

-- ====================================
-- CLIENT CONFIGURATION (SIMPLIFIED)
-- ====================================
-- Removed: Give gamepass notifications
-- Kept: Shop notifications only
-- ====================================

local Config = {
	Debug = false, -- Set false untuk production

	StartVisible = false,

	ButtonStates = {
		Buy = {
			Text = "Buy",
			BackgroundColor = Color3.fromRGB(46, 204, 113),
			TextColor = Color3.fromRGB(255, 255, 255),
			Enabled = true
		},
		Owned = {
			Text = "Owned",
			BackgroundColor = Color3.fromRGB(149, 165, 166),
			TextColor = Color3.fromRGB(255, 255, 255),
			Enabled = false
		},
		Loading = {
			Text = "Loading...",
			BackgroundColor = Color3.fromRGB(52, 152, 219),
			TextColor = Color3.fromRGB(255, 255, 255),
			Enabled = false
		},
		Error = {
			Text = "Error",
			BackgroundColor = Color3.fromRGB(231, 76, 60),
			TextColor = Color3.fromRGB(255, 255, 255),
			Enabled = false
		}
	},

	Notifications = {
		ErrorServer = {
			Title = "Error",
			Text = "Gagal menghubungi server!",
			Duration = 3
		},
		ErrorPurchase = {
			Title = "Error",
			Text = "Gagal membuka menu pembelian!",
			Duration = 3
		},
		AlreadyOwned = {
			Title = "Sudah Dimiliki",
			Text = "Kamu sudah memiliki gamepass ini!",
			Duration = 3
		},
		PurchaseSuccess = {
			Title = "Pembelian Berhasil",
			Text = "Terima kasih atas pembelianmu!",
			Duration = 5
		},
		TooManyRequests = {
			Title = "Peringatan",
			Text = "Terlalu banyak request, tunggu sebentar!",
			Duration = 3
		}
	},

	RemoteTimeout = 10,
	RoleRefreshDelay = 1
}

return Config

-- ====================================
-- CLIENT LOGGER MODULE
-- ====================================
local Config = require(script.Parent.Config)

local Logger = {}

function Logger:Debug(message)
	if Config.Debug then
		print("[GamepassClient] 🔍", message)
	end
end

function Logger:Info(message)
	if Config.Debug then
		print("[GamepassClient] ℹ️", message)
	end
end

function Logger:Success(message)
	if Config.Debug then
		print("[GamepassClient] ✅", message)
	end
end

function Logger:Warn(message)
	warn("[GamepassClient] ⚠️", message)
end

function Logger:Error(message)
	warn("[GamepassClient] ❌", message)
end

return Logger

-- ====================================
-- NOTIFICATION MANAGER
-- ====================================
local Config = require(script.Parent.Config)
local Logger = require(script.Parent.Logger)

local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")

local NotificationManager = {}

function NotificationManager:Init(notificationFrame, notificationText)
	self.frame = notificationFrame
	self.text = notificationText
	self.frame.Visible = false
	Logger:Debug("NotificationManager initialized")
end

function NotificationManager:ShowVisual(message, isSuccess)
	self.text.Text = message

	if isSuccess then
		self.text.TextColor3 = Color3.fromRGB(85, 255, 127)
		self.frame.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
	else
		self.text.TextColor3 = Color3.fromRGB(255, 85, 85)
		self.frame.BackgroundColor3 = Color3.fromRGB(231, 76, 60)
	end

	self.frame.Visible = true
	self.frame.BackgroundTransparency = 1

	local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local fadeIn = TweenService:Create(self.frame, tweenInfo, {
		BackgroundTransparency = 0.2
	})

	fadeIn:Play()

	task.delay(4, function()
		local fadeOut = TweenService:Create(self.frame, tweenInfo, {
			BackgroundTransparency = 1
		})

		fadeOut:Play()
		fadeOut.Completed:Connect(function()
			self.frame.Visible = false
		end)
	end)
end

function NotificationManager:Send(notifConfig, customText)
	pcall(function()
		StarterGui:SetCore("SendNotification", {
			Title = notifConfig.Title,
			Text = customText or notifConfig.Text,
			Duration = notifConfig.Duration
		})
	end)
end

return NotificationManager

-- ====================================
-- CLIENT SHOP HANDLER (SIMPLIFIED)
-- ====================================
-- Removed: Give gamepass handling
-- Kept: Self-purchase only
-- ====================================

local Config = require(script.Parent.Config)
local Logger = require(script.Parent.Logger)

local ShopHandler = {}
ShopHandler.GamepassData = {}
ShopHandler.shopDataLoaded = false
ShopHandler.isRefreshing = false

function ShopHandler:Init(remotes, uiManager, notificationManager)
	self.remotes = remotes
	self.uiManager = uiManager
	self.notificationManager = notificationManager
	Logger:Debug("ShopHandler initialized (Self-purchase only)")
end

function ShopHandler:SetGamepassData(data)
	self.GamepassData = data
end

function ShopHandler:LoadShopData()
	if self.isRefreshing then return end
	if self.shopDataLoaded then return end

	self.isRefreshing = true

	for _, data in pairs(self.GamepassData) do
		self.uiManager:SetButtonState(data.Button, "Loading")
	end

	local success, shopData = pcall(function()
		return self.remotes.shopRequest:InvokeServer({
			action = "GetShopData"
		})
	end)

	if success and shopData and shopData.success then
		for gamepassType, data in pairs(self.GamepassData) do
			if shopData.gamepasses[gamepassType] then
				local passData = shopData.gamepasses[gamepassType]
				data.IDs = passData.ids
				data.Owned = passData.owned
				data.Name = passData.name

				if passData.owned then
					self.uiManager:SetButtonState(data.Button, "Owned")
				else
					self.uiManager:SetButtonState(data.Button, "Buy")
				end
			else
				self.uiManager:SetButtonState(data.Button, "Error")
			end
		end

		self.shopDataLoaded = true
		Logger:Success("Shop data loaded successfully")
	else
		for _, data in pairs(self.GamepassData) do
			self.uiManager:SetButtonState(data.Button, "Error")
		end

		if shopData and shopData.error == "Too many requests" then
			self.notificationManager:Send(Config.Notifications.TooManyRequests)
		else
			self.notificationManager:Send(Config.Notifications.ErrorServer)
		end

		Logger:Error("Failed to load shop data: " .. tostring(shopData))
	end

	self.isRefreshing = false
end

function ShopHandler:PromptPurchase(gamepassType)
	local data = self.GamepassData[gamepassType]
	if not data then return end

	if data.Owned then
		self.notificationManager:Send(
			Config.Notifications.AlreadyOwned, 
			"Kamu sudah memiliki " .. data.Name .. "!"
		)
		return
	end

	local success, result = pcall(function()
		return self.remotes.shopRequest:InvokeServer({
			action = "PromptPurchase",
			gamepassType = gamepassType
		})
	end)

	if success and result then
		if not result.success then
			if result.error == "Already owned" then
				self.notificationManager:Send(Config.Notifications.AlreadyOwned)
				data.Owned = true
				self.uiManager:SetButtonState(data.Button, "Owned")
			elseif result.error == "Too many requests" then
				self.notificationManager:Send(Config.Notifications.TooManyRequests)
			else
				self.notificationManager:Send(Config.Notifications.ErrorPurchase)
			end
		end
	else
		self.notificationManager:Send(Config.Notifications.ErrorPurchase)
	end
end

function ShopHandler:RefreshPlayerRole()
	task.wait(Config.RoleRefreshDelay)
	pcall(function()
		self.remotes.refreshRole:FireServer()
	end)
end

function ShopHandler:HandleOwnershipUpdate(gamepassType, owned)
	Logger:Info(string.format("Ownership updated: %s = %s", gamepassType, tostring(owned)))

	local data = self.GamepassData[gamepassType]
	if data then
		data.Owned = owned
		if owned then
			self.uiManager:SetButtonState(data.Button, "Owned")

			self.notificationManager:ShowVisual(
				"Kamu telah menerima " .. data.Name .. "!",
				true
			)

			self.notificationManager:Send(
				Config.Notifications.PurchaseSuccess, 
				"Kamu telah menerima " .. data.Name .. "!"
			)

			self:RefreshPlayerRole()
		end
	end
end

return ShopHandler

-- ====================================
-- UI MANAGER
-- ====================================
local Config = require(script.Parent.Config)
local Logger = require(script.Parent.Logger)

local UIManager = {}

function UIManager:SetButtonState(button, state)
	local stateConfig = Config.ButtonStates[state]
	if not stateConfig then return end

	button.Text = stateConfig.Text
	button.BackgroundColor3 = stateConfig.BackgroundColor
	button.TextColor3 = stateConfig.TextColor
	button.Active = stateConfig.Enabled

	if stateConfig.Enabled then
		button.AutoButtonColor = true
	else
		button.AutoButtonColor = false
	end
end

function UIManager:ShowConfirmDialog(confirmDialog, confirmText, text, onYes, onNo)
	if not confirmDialog then
		Logger:Warn("ConfirmDialog tidak tersedia!")
		if onNo then onNo() end
		return {}
	end

	confirmText.Text = text
	confirmDialog.Visible = true

	-- Return empty connections table that will be populated
	return {
		yesConnection = nil,
		noConnection = nil,
		dialog = confirmDialog
	}
end

function UIManager:SetupConfirmButtons(confirmYesBtn, confirmNoBtn, onYes, onNo)
	local connections = {
		yesConnection = nil,
		noConnection = nil,
		dialog = nil
	}

	-- Function to cleanup connections
	local function cleanup()
		if connections.yesConnection then
			connections.yesConnection:Disconnect()
			connections.yesConnection = nil
		end
		if connections.noConnection then
			connections.noConnection:Disconnect()
			connections.noConnection = nil
		end
	end

	connections.yesConnection = confirmYesBtn.MouseButton1Click:Connect(function()
		Logger:Debug("Confirm Yes clicked")

		-- Cleanup first
		cleanup()

		-- Execute callback
		if onYes then 
			pcall(onYes)
		end
	end)

	connections.noConnection = confirmNoBtn.MouseButton1Click:Connect(function()
		Logger:Debug("Confirm No clicked")

		-- Cleanup first
		cleanup()

		-- Execute callback
		if onNo then 
			pcall(onNo)
		end
	end)

	return connections
end

return UIManager

-- ====================================
-- HELP GUI CONTROLLER
-- Place in ScreenGui sebagai LocalScript
-- ====================================
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Player = Players.LocalPlayer

-- Wait for Icon Module
local IconModule = ReplicatedStorage:WaitForChild("Icon")
local Icon = require(IconModule)

-- Wait for GUI
local gui = script.Parent
local mainframe = gui:WaitForChild("MainFrame")
local header = mainframe:WaitForChild("Header")
local closeBtn = header:WaitForChild("CloseBtn")
local container = mainframe:WaitForChild("Content")
local textbox2 = container:WaitForChild("TextBox2")
local textbox3 = container:FindFirstChild("TextBox3")
local copy2 = container:WaitForChild("TextBox2"):WaitForChild("copytext2")
local copy3 = container:WaitForChild("TextBox3"):WaitForChild("copytext3")


-- ====================================
-- CONFIGURATION
-- ====================================
local Config = {
	IconOrder = 2,
	IconName = "Support",
	-- Teks yang akan disalin (edit sesuai kebutuhan)
	CopyText2 = "https://www.roblox.com/id/communities/192828493",
	CopyText3 = "https://saweria.co/JeksAl",

	-- PENGATURAN TEKS UNTUK TEXTBOX
	TextBoxTextSize = 14, -- Ukuran teks link
	TextBoxTextColor = Color3.fromRGB(255, 255, 255), -- Warna teks link (Putih)
	TextBoxFont = Enum.Font.GothamSemibold, -- Jenis font link

	-- PENGATURAN TEKS UNTUK TOMBOL COPY
	BtnTextSize = 14, -- Ukuran teks tombol
	BtnTextColor = Color3.fromRGB(255, 255, 255), -- Warna teks tombol (Putih)
	BtnFont = Enum.Font.GothamBold -- Jenis font tombol
}

-- ====================================
-- GUI STATE
-- ====================================
local isGUIVisible = false
mainframe.Visible = false

-- ====================================
-- SETUP TEXTBOX UNTUK COPY
-- ====================================
local function setupTextBoxForCopy(textBox, text)
	-- Set properties dasar
	textBox.Text = text
	textBox.ClearTextOnFocus = false
	textBox.TextEditable = false
	textBox.TextXAlignment = Enum.TextXAlignment.Left

	-- Set ukuran, warna, dan font teks dari Config
	textBox.TextSize = Config.TextBoxTextSize
	textBox.TextColor3 = Config.TextBoxTextColor
	textBox.Font = Config.TextBoxFont
	textBox.TextScaled = false -- Pastikan false agar TextSize berfungsi manual

	-- Auto select semua text saat diklik
	textBox.Focused:Connect(function()
		textBox.SelectionStart = 1
		task.spawn(function()
			task.wait(0.05)
			if textBox:IsFocused() then
				textBox.CursorPosition = #textBox.Text + 1
				textBox.SelectionStart = 1
			end
		end)
	end)
end

-- ====================================
-- FUNCTIONS
-- ====================================
local function toggleGUI()
	isGUIVisible = not isGUIVisible
	mainframe.Visible = isGUIVisible
end

local function closeGUI()
	isGUIVisible = false
	mainframe.Visible = false
end

-- Fungsi untuk setup copy button
local function setupCopyButton(button, textBox)
	local originalText = button.Text
	local originalColor = button.BackgroundColor3

	-- Set ukuran, warna, dan font tombol dari Config
	button.TextSize = Config.BtnTextSize
	button.TextColor3 = Config.BtnTextColor
	button.Font = Config.BtnFont

	button.MouseButton1Click:Connect(function()
		-- 1. Fokus dan blok teks otomatis
		textBox:CaptureFocus()

		-- 2. Cek apakah pemain menggunakan HP (Touch screen) atau PC (Keyboard)
		local hasKeyboard = UserInputService.KeyboardEnabled
		local hasTouch = UserInputService.TouchEnabled

		if hasTouch and not hasKeyboard then
			-- Pemain di HP / Tablet
			button.Text = "Tap 'Copy'!" 
		else
			-- Pemain di PC / Laptop
			button.Text = "Press Ctrl+C!" 
		end

		button.BackgroundColor3 = Color3.fromRGB(0, 170, 255)

		-- Kasih jeda waktu sedikit lebih lama agar pemain sempat baca & salin
		task.wait(3)

		-- Kembalikan ke semula
		button.Text = originalText
		button.BackgroundColor3 = originalColor
	end)

	-- Hover effect
	button.MouseEnter:Connect(function()
		if button.Text == originalText then
			local r, g, b = originalColor.R, originalColor.G, originalColor.B
			button.BackgroundColor3 = Color3.new(
				math.min(r * 1.2, 1), 
				math.min(g * 1.2, 1), 
				math.min(b * 1.2, 1)
			)
		end
	end)

	button.MouseLeave:Connect(function()
		if button.Text == originalText then
			button.BackgroundColor3 = originalColor
		end
	end)
end

-- ====================================
-- CREATE TOPBAR ICON
-- ====================================
local helpIcon = Icon.new()
	:setLabel(Config.IconName)
	:setOrder(Config.IconOrder)
	:setRight()
	:bindEvent("selected", function()
		toggleGUI()
	end)
	:bindEvent("deselected", function()
		closeGUI()
	end)

-- ====================================
-- BUTTON CONNECTIONS
-- ====================================
closeBtn.MouseButton1Click:Connect(function()
	closeGUI()
	helpIcon:deselect()
end)

-- Setup TextBox dengan properties yang benar
setupTextBoxForCopy(textbox2, Config.CopyText2)
setupTextBoxForCopy(textbox3, Config.CopyText3)

-- Setup copy buttons 
setupCopyButton(copy2, textbox2)
setupCopyButton(copy3, textbox3)

-- LocalScript: CinematicHandler
-- Lokasi: StarterPlayerScripts

local Players      = game:GetService("Players")
local RunService   = game:GetService("RunService")
local RS           = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local camera    = workspace.CurrentCamera

local CinematicRemote      = RS:WaitForChild("CinematicRemote")
local RequestDonationState = RS:WaitForChild("RequestDonationState")

-- ============================================================
-- REFERENSI GUI — semua dari 1 ScreenGui
-- ============================================================
local donationGUI = script.Parent

-- Cinematic
local cinematicContainer = donationGUI:WaitForChild("CinematicContainer")
local topBar             = cinematicContainer:WaitForChild("TopBar")
local bottomBar          = cinematicContainer:WaitForChild("BottomBar")
local vignette           = cinematicContainer:WaitForChild("Vignette")
local impactFlash        = cinematicContainer:WaitForChild("ImpactFlash")
local mainFrame          = cinematicContainer:WaitForChild("MainFrame")
local glowCircle         = mainFrame:WaitForChild("GlowCircle")
local titleLabel         = mainFrame:WaitForChild("Title")
local titleStroke        = titleLabel:WaitForChild("TitleStroke")
local shadow1            = mainFrame:WaitForChild("Shadow1")
local shadow2            = mainFrame:WaitForChild("Shadow2")
local subtitleLabel      = mainFrame:WaitForChild("Subtitle")
local leftLine           = mainFrame:WaitForChild("LeftLine")
local rightLine          = mainFrame:WaitForChild("RightLine")

-- Skip
local skipFrame   = donationGUI:WaitForChild("SkipFrame")
local progressBar = skipFrame:WaitForChild("ProgressBg"):WaitForChild("ProgressBar")
local skipButton  = skipFrame:WaitForChild("SkipButton")

-- ============================================================
-- STATE
-- ============================================================
local isOrbiting      = false
local orbitConnection = nil
local skipRequested   = false
local originalCamType = nil

-- ============================================================
-- SOUND
-- ============================================================
local SOUND_ID = "rbxassetid://122331425639589"

local function playSound()
	local sound   = Instance.new("Sound")
	sound.SoundId = SOUND_ID
	sound.Volume  = 1
	sound.RollOffMaxDistance = 0
	sound.Parent  = workspace
	sound:Play()
	sound.Ended:Connect(function()
		if sound and sound.Parent then sound:Destroy() end
	end)
	task.delay(30, function()
		if sound and sound.Parent then sound:Destroy() end
	end)
end

-- ============================================================
-- UTILITY
-- ============================================================
local function toColor3(ct)
	if not ct then return Color3.fromRGB(255, 215, 0) end
	return Color3.fromRGB(ct.r or 255, ct.g or 215, ct.b or 0)
end

local function formatRupiah(amount)
	local formatted = tostring(math.floor(tonumber(amount) or 0))
	local k
	while true do  
		formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1.%2')
		if k == 0 then break end
	end
	return "Rp " .. formatted
end

local function resetCinematic()
	cinematicContainer.Visible         = false
	topBar.Size                        = UDim2.new(1, 0, 0, 0)
	topBar.Position                    = UDim2.new(0, 0, 0, 0)
	bottomBar.Size                     = UDim2.new(1, 0, 0, 0)
	bottomBar.Position                 = UDim2.new(0, 0, 1, 0)
	vignette.ImageTransparency         = 1
	impactFlash.Visible                = false
	impactFlash.BackgroundTransparency = 1
	mainFrame.Position                 = UDim2.new(0.5, 0, 1, -85)
	glowCircle.Size                    = UDim2.new(0, 0, 0, 0)
	glowCircle.BackgroundTransparency  = 0.5
	titleLabel.Size                    = UDim2.new(1, 0, 0, 60)
	titleLabel.TextSize                = 36
	titleLabel.TextTransparency        = 1
	titleLabel.Rotation                = 0
	titleStroke.Transparency           = 1
	shadow1.Size                       = UDim2.new(1, 0, 0, 60)
	shadow1.TextSize                   = 36
	shadow1.TextTransparency           = 1
	shadow1.Rotation                   = 0
	shadow2.Size                       = UDim2.new(1, 0, 0, 60)
	shadow2.TextSize                   = 36
	shadow2.TextTransparency           = 1
	shadow2.Rotation                   = 0
	subtitleLabel.TextTransparency     = 1
	leftLine.Size                      = UDim2.new(0, 0, 0, 2)
	leftLine.BackgroundTransparency    = 0
	rightLine.Size                     = UDim2.new(0, 0, 0, 2)
	rightLine.BackgroundTransparency   = 0
end

-- ============================================================
-- SKIP BUTTON LOGIC
-- ============================================================
local function resetSkip()
	skipFrame.Visible    = false
	skipFrame.Position   = UDim2.new(1, 20, 0.5, 0)
	progressBar.Size     = UDim2.new(0, 0, 1, 0)
	progressBar.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
end

-- ============================================================
-- SKIP BUTTON LOGIC
-- ============================================================
local isHolding      = false
local holdElapsed    = 0
local holdRequired   = 1.2
local holdConn       = nil
local onSkipCallback = nil

local function showSkip(onSkip)
	onSkipCallback = onSkip
	resetSkip()
	skipFrame.Visible = true
	TweenService:Create(skipFrame,
		TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Position = UDim2.new(1, -175, 0.5, 0) }
	):Play()
end

local function hideSkip()
	if holdConn then holdConn:Disconnect() holdConn = nil end
	isHolding = false
	local t = TweenService:Create(skipFrame,
		TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ Position = UDim2.new(1, 20, 0.5, 0) }
	)
	t:Play()
	t.Completed:Wait()
	resetSkip()
end

skipButton.MouseButton1Down:Connect(function()
	isHolding   = true
	holdElapsed = 0
	holdConn = RunService.RenderStepped:Connect(function(dt)
		if not isHolding then
			if holdConn then holdConn:Disconnect() holdConn = nil end
			TweenService:Create(progressBar, TweenInfo.new(0.2), {Size = UDim2.new(0, 0, 1, 0)}):Play()
			progressBar.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
			return
		end
		holdElapsed += dt
		local progress = math.min(holdElapsed / holdRequired, 1)
		progressBar.Size = UDim2.new(progress, 0, 1, 0)
		progressBar.BackgroundColor3 = progress > 0.7
			and Color3.fromRGB(255, 100, 50)
			or  Color3.fromRGB(255, 215, 0)
		if progress >= 1 then
			holdConn:Disconnect()
			holdConn  = nil
			isHolding = false
			if onSkipCallback then onSkipCallback() end
			task.spawn(hideSkip)
		end
	end)
end)

skipButton.MouseButton1Up:Connect(function() isHolding = false end)
skipButton.MouseEnter:Connect(function()
	TweenService:Create(skipFrame, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(30, 30, 30)}):Play()
end)
skipButton.MouseLeave:Connect(function()
	isHolding = false
	TweenService:Create(skipFrame, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(15, 15, 15)}):Play()
end)

-- ============================================================
-- CAMERA ORBIT
-- ============================================================
local function stopOrbit()
	if orbitConnection then orbitConnection:Disconnect() orbitConnection = nil end
	if originalCamType then camera.CameraType = originalCamType originalCamType = nil end
	isOrbiting    = false
	skipRequested = false
end

local function startOrbitCamera(targetCharacter, duration, onDone)
	stopOrbit()
	local hrp = targetCharacter:FindFirstChild("HumanoidRootPart")
	if not hrp then if onDone then onDone() end return end

	isOrbiting      = true
	skipRequested   = false
	originalCamType = camera.CameraType
	camera.CameraType = Enum.CameraType.Scriptable

	local radius     = 12
	local height     = 5
	local speed      = 0.6
	local smoothCF   = camera.CFrame
	local elapsed    = 0
	local diff       = camera.CFrame.Position - hrp.Position
	local startAngle = math.atan2(diff.Z, diff.X)

	orbitConnection = RunService.RenderStepped:Connect(function(dt)
		if skipRequested or elapsed >= duration then
			stopOrbit()
			if onDone then task.spawn(onDone) end
			return
		end
		if not hrp or not hrp.Parent then
			stopOrbit()
			if onDone then task.spawn(onDone) end
			return
		end
		elapsed += dt
		local angle    = startAngle + (elapsed * speed)
		local targetPos    = hrp.Position + Vector3.new(math.cos(angle) * radius, height, math.sin(angle) * radius)
		local targetCFrame = CFrame.new(targetPos, hrp.Position)
		smoothCF      = smoothCF:Lerp(targetCFrame, math.min(dt * 6, 1))
		camera.CFrame = smoothCF
	end)
end

-- ============================================================
-- CINEMATIC CONTROLLER
-- ============================================================
local function showCinematic(donationData)
	local color    = toColor3(donationData.cinematicColor)
	local duration = donationData.cinematicDuration or 8

	resetCinematic()

	-- Update konten
	local priceText = ""
	if donationData.currencyType == "Rupiah" then
		priceText = formatRupiah(donationData.price)
	else
		priceText = tostring(donationData.price) .. " Robux"
	end

	titleLabel.Text    = priceText .. " dari " .. donationData.donorName
	shadow1.Text       = titleLabel.Text
	shadow2.Text       = titleLabel.Text
	subtitleLabel.Text = "Terima kasih atas supportmu yang luar biasa!"
	
	-- Update warna
	glowCircle.BackgroundColor3 = color
	leftLine.BackgroundColor3   = color
	rightLine.BackgroundColor3  = color
	titleStroke.Color           = color

	cinematicContainer.Visible = true

	-- Bars masuk
	local barsIn = TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(topBar,    barsIn, {Size = UDim2.new(1, 0, 0, 60)}):Play()
	TweenService:Create(bottomBar, barsIn, {Size = UDim2.new(1, 0, 0, 60), Position = UDim2.new(0, 0, 1, -60)}):Play()
	TweenService:Create(vignette,  TweenInfo.new(0.8), {ImageTransparency = 0.3}):Play()

	task.wait(0.5)

	-- Glow expand
	TweenService:Create(glowCircle, TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.new(0, 200, 0, 200), BackgroundTransparency = 1
	}):Play()

	task.wait(0.3)

	-- Light rays (sementara)
	local rays = {}
	for i = 1, 5 do
		local ray = Instance.new("Frame", mainFrame)
		ray.Size                   = UDim2.new(0, 2, 0, 300)
		ray.Position               = UDim2.new(0.5, -200 + (i * 80), 0.5, -150)
		ray.AnchorPoint            = Vector2.new(0.5, 0.5)
		ray.BackgroundColor3       = color
		ray.BorderSizePixel        = 0
		ray.Rotation               = 15
		ray.BackgroundTransparency = 0.85
		ray.ZIndex                 = 12
		local rg = Instance.new("UIGradient", ray)
		rg.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.5),
			NumberSequenceKeypoint.new(0.7, 0.5), NumberSequenceKeypoint.new(1, 1),
		})
		rg.Rotation = 90
		table.insert(rays, ray)
		local ip = UDim2.new(0.5, -200 + (i * 80), 0.5, -150)
		local ep = UDim2.new(0.5, -200 + (i * 80), 0.5,  150)
		task.spawn(function()
			while ray and ray.Parent do
				local mt = TweenService:Create(ray, TweenInfo.new(2, Enum.EasingStyle.Linear), {Position = ep})
				mt:Play() mt.Completed:Wait()
				if ray and ray.Parent then ray.Position = ip end
				task.wait(0.05)
			end
		end)
	end

	-- Title zoom in
	titleLabel.Size          = UDim2.new(0, 10, 0, 10)
	titleLabel.TextSize      = 8
	titleLabel.TextTransparency = 0
	titleStroke.Transparency = 0
	shadow1.Size             = UDim2.new(0, 10, 0, 10)
	shadow1.TextSize         = 8
	shadow1.TextTransparency = 0.5
	shadow2.Size             = UDim2.new(0, 10, 0, 10)
	shadow2.TextSize         = 8
	shadow2.TextTransparency = 0.7

	local zoomInfo = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	local zoomIn   = TweenService:Create(titleLabel, zoomInfo, {Size = UDim2.new(1.5, 0, 0, 90), TextSize = 44})
	TweenService:Create(shadow1, zoomInfo, {Size = UDim2.new(1.5, 0, 0, 90), TextSize = 44, Position = UDim2.new(0.5, 2, 0, 2)}):Play()
	TweenService:Create(shadow2, zoomInfo, {Size = UDim2.new(1.5, 0, 0, 90), TextSize = 44, Position = UDim2.new(0.5, 4, 0, 4)}):Play()
	zoomIn:Play()
	zoomIn.Completed:Wait()

	-- Impact flash
	impactFlash.Visible                = true
	impactFlash.BackgroundTransparency = 0
	TweenService:Create(impactFlash, TweenInfo.new(0.4), {BackgroundTransparency = 1}):Play()

	-- Screen shake
	task.spawn(function()
		local orig = mainFrame.Position
		for i = 1, 10 do
			local v = math.max(18 - (i * 2), 1)  -- minimum 1 agar random tidak error
			mainFrame.Position = UDim2.new(0.5, math.random(-v, v), 1, -85 + math.random(-v, v))
			task.wait(0.025)
		end
		mainFrame.Position = orig
	end)

	-- Impact rings (sementara)
	for ring = 1, 4 do
		task.spawn(function()
			local ir = Instance.new("Frame", mainFrame)
			ir.Size = UDim2.new(0,0,0,0) ir.Position = UDim2.new(0.5,0,0.5,0)
			ir.AnchorPoint = Vector2.new(0.5,0.5) ir.BackgroundTransparency = 1
			ir.BorderSizePixel = 0 ir.ZIndex = 14
			local rs = Instance.new("UIStroke", ir)
			rs.Color = color rs.Thickness = math.max(8-(ring*1.5),1)
			Instance.new("UICorner", ir).CornerRadius = UDim.new(1,0)
			task.wait(ring * 0.05)
			TweenService:Create(ir, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.new(0,500,0,500)}):Play()
			TweenService:Create(rs, TweenInfo.new(0.8), {Transparency = 1, Thickness = 1}):Play()
			task.wait(0.85)
			if ir and ir.Parent then ir:Destroy() end
		end)
	end

	-- Bounce back
	local bounceInfo = TweenInfo.new(0.25, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out)
	local bb = TweenService:Create(titleLabel, bounceInfo, {Size = UDim2.new(1,0,0,60), TextSize = 36})
	TweenService:Create(shadow1, bounceInfo, {Size = UDim2.new(1,0,0,60), TextSize = 36, Position = UDim2.new(0.5,2,0,2)}):Play()
	TweenService:Create(shadow2, bounceInfo, {Size = UDim2.new(1,0,0,60), TextSize = 36, Position = UDim2.new(0.5,4,0,4)}):Play()
	bb:Play() bb.Completed:Wait()

	-- Chromatic aberration (sementara)
	local redChrome  = titleLabel:Clone()
	redChrome.TextColor3 = Color3.fromRGB(255,50,50) redChrome.TextTransparency = 0.6
	redChrome.ZIndex = 19
	local s1 = redChrome:FindFirstChildOfClass("UIStroke") if s1 then s1:Destroy() end
	redChrome.Parent = mainFrame

	local blueChrome = titleLabel:Clone()
	blueChrome.TextColor3 = Color3.fromRGB(50,150,255) blueChrome.TextTransparency = 0.6
	blueChrome.ZIndex = 19
	local s2 = blueChrome:FindFirstChildOfClass("UIStroke") if s2 then s2:Destroy() end
	blueChrome.Parent = mainFrame

	for i = 1, 4 do
		local o = 10 - (i*2)
		redChrome.Position  = UDim2.new(0.5,-o,0,0) blueChrome.Position = UDim2.new(0.5,o,0,0)
		task.wait(0.04)
		redChrome.Position  = UDim2.new(0.5,o,0,0)  blueChrome.Position = UDim2.new(0.5,-o,0,0)
		task.wait(0.04)
	end
	TweenService:Create(redChrome,  TweenInfo.new(0.3), {TextTransparency = 1}):Play()
	TweenService:Create(blueChrome, TweenInfo.new(0.3), {TextTransparency = 1}):Play()

	-- Shake residual
	for i = 1, 5 do
		local v = 8 - i
		TweenService:Create(titleLabel, TweenInfo.new(0.035), {Rotation =  v}):Play()
		TweenService:Create(shadow1,    TweenInfo.new(0.035), {Rotation =  v}):Play()
		TweenService:Create(shadow2,    TweenInfo.new(0.035), {Rotation =  v}):Play()
		task.wait(0.035)
		TweenService:Create(titleLabel, TweenInfo.new(0.035), {Rotation = -v}):Play()
		TweenService:Create(shadow1,    TweenInfo.new(0.035), {Rotation = -v}):Play()
		TweenService:Create(shadow2,    TweenInfo.new(0.035), {Rotation = -v}):Play()
		task.wait(0.035)
	end
	TweenService:Create(titleLabel, TweenInfo.new(0.1), {Rotation = 0}):Play()
	TweenService:Create(shadow1,    TweenInfo.new(0.1), {Rotation = 0}):Play()
	TweenService:Create(shadow2,    TweenInfo.new(0.1), {Rotation = 0}):Play()

	task.wait(0.2)
	if redChrome  and redChrome.Parent  then redChrome:Destroy()  end
	if blueChrome and blueChrome.Parent then blueChrome:Destroy() end
	impactFlash.Visible = false
	task.wait(0.2)

	-- Subtitle + lines muncul
	TweenService:Create(subtitleLabel, TweenInfo.new(0.5), {TextTransparency = 0}):Play()
	local lineInfo = TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(leftLine,  lineInfo, {Size = UDim2.new(0, 120, 0, 2)}):Play()
	TweenService:Create(rightLine, lineInfo, {Size = UDim2.new(0, 120, 0, 2)}):Play()

	-- Particles (sementara)
	for i = 1, 15 do
		task.spawn(function()
			local p = Instance.new("Frame", mainFrame)
			p.Size = UDim2.new(0, math.random(2,5), 0, math.random(2,5))
			p.Position = UDim2.new(math.random(0,100)/100, 0, 1.2, 0)
			p.BackgroundColor3 = color p.BorderSizePixel = 0
			p.BackgroundTransparency = 0.3 p.ZIndex = 18
			Instance.new("UICorner", p).CornerRadius = UDim.new(1, 0)
			local pt = TweenService:Create(p, TweenInfo.new(math.random(12,22)/10, Enum.EasingStyle.Linear), {
				Position = UDim2.new(math.random(0,100)/100, 0, -0.5, 0), BackgroundTransparency = 1
			})
			pt:Play() pt.Completed:Wait()
			if p and p.Parent then p:Destroy() end
		end)
	end

	task.wait(duration)

	-- Fade out
	local fadeOut = TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	TweenService:Create(titleLabel,    fadeOut, {TextTransparency = 1}):Play()
	TweenService:Create(titleStroke,   fadeOut, {Transparency = 1}):Play()
	TweenService:Create(shadow1,       fadeOut, {TextTransparency = 1}):Play()
	TweenService:Create(shadow2,       fadeOut, {TextTransparency = 1}):Play()
	TweenService:Create(subtitleLabel, fadeOut, {TextTransparency = 1}):Play()
	TweenService:Create(leftLine,      fadeOut, {BackgroundTransparency = 1}):Play()
	TweenService:Create(rightLine,     fadeOut, {BackgroundTransparency = 1}):Play()
	TweenService:Create(vignette,      fadeOut, {ImageTransparency = 1}):Play()

	task.wait(0.3)

	local barsOut = TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	local botOut  = TweenService:Create(bottomBar, barsOut, {Size = UDim2.new(1,0,0,0), Position = UDim2.new(0,0,1,0)})
	TweenService:Create(topBar, barsOut, {Size = UDim2.new(1,0,0,0)}):Play()
	botOut:Play()
	botOut.Completed:Wait()

	for _, ray in ipairs(rays) do
		if ray and ray.Parent then ray:Destroy() end
	end

	resetCinematic()
end

-- ============================================================
-- TERIMA EVENT DARI SERVER
-- ============================================================
CinematicRemote.OnClientEvent:Connect(function(donationData)
	if not donationData or not donationData.donorName then return end

	if donationData.useCinematic then
		task.spawn(playSound)

		local donorPlayer = Players:GetPlayerByUserId(donationData.donorUserId)
		if donorPlayer then
			local character = donorPlayer.Character
			if character and character:FindFirstChild("HumanoidRootPart") then
				showSkip(function() skipRequested = true end)
				startOrbitCamera(character, donationData.cinematicDuration or 8, function()
					task.spawn(hideSkip)
				end)
			end
		end

		task.spawn(function()
			showCinematic(donationData)
		end)
	end
end)

task.wait(2)
RequestDonationState:FireServer()

------------------------------------------------------------------------
-- Freecam
-- Cinematic free camera for spectating and video production.
------------------------------------------------------------------------

local pi    = math.pi
local abs   = math.abs
local clamp = math.clamp
local exp   = math.exp
local rad   = math.rad
local sign  = math.sign
local sqrt  = math.sqrt
local tan   = math.tan

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local UIS = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
	Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
	LocalPlayer = Players.LocalPlayer
end

local Camera = Workspace.CurrentCamera
Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	local newCamera = Workspace.CurrentCamera
	if newCamera then
		Camera = newCamera
	end
end)

------------------------------------------------------------------------

local TOGGLE_INPUT_PRIORITY = Enum.ContextActionPriority.Low.Value
local INPUT_PRIORITY = Enum.ContextActionPriority.High.Value
local FREECAM_MACRO_KB = {Enum.KeyCode.LeftShift, Enum.KeyCode.P}

local NAV_GAIN = Vector3.new(1, 1, 1)*64
local PAN_GAIN = Vector2.new(0.75, 1)*8
local FOV_GAIN = 300

local PITCH_LIMIT = rad(90)

local VEL_STIFFNESS = 1.5
local PAN_STIFFNESS = 1.0
local FOV_STIFFNESS = 4.0

------------------------------------------------------------------------

local Spring = {} do
	Spring.__index = Spring

	function Spring.new(freq, pos)
		local self = setmetatable({}, Spring)
		self.f = freq
		self.p = pos
		self.v = pos*0
		return self
	end

	function Spring:Update(dt, goal)
		local f = self.f*2*pi
		local p0 = self.p
		local v0 = self.v

		local offset = goal - p0
		local decay = exp(-f*dt)

		local p1 = goal + (v0*dt - offset*(f*dt + 1))*decay
		local v1 = (f*dt*(offset*f - v0) + v0)*decay

		self.p = p1
		self.v = v1

		return p1
	end

	function Spring:Reset(pos)
		self.p = pos
		self.v = pos*0
	end
end

------------------------------------------------------------------------

local cameraPos = Vector3.new()
local cameraRot = Vector2.new()
local cameraFov = 0

local velSpring = Spring.new(VEL_STIFFNESS, Vector3.new())
local panSpring = Spring.new(PAN_STIFFNESS, Vector2.new())
local fovSpring = Spring.new(FOV_STIFFNESS, 0)

------------------------------------------------------------------------

local Input = {} do
	local thumbstickCurve do
		local K_CURVATURE = 2.0
		local K_DEADZONE = 0.15

		local function fCurve(x)
			return (exp(K_CURVATURE*x) - 1)/(exp(K_CURVATURE) - 1)
		end

		local function fDeadzone(x)
			return fCurve((x - K_DEADZONE)/(1 - K_DEADZONE))
		end

		function thumbstickCurve(x)
			return sign(x)*clamp(fDeadzone(abs(x)), 0, 1)
		end
	end

	local gamepad = {
		ButtonX = 0,
		ButtonY = 0,
		DPadDown = 0,
		DPadUp = 0,
		ButtonL2 = 0,
		ButtonR2 = 0,
		Thumbstick1 = Vector2.new(),
		Thumbstick2 = Vector2.new(),
	}

	local keyboard = {
		W = 0,
		A = 0,
		S = 0,
		D = 0,
		E = 0,
		Q = 0,
		U = 0,
		H = 0,
		J = 0,
		K = 0,
		I = 0,
		Y = 0,
		Up = 0,
		Down = 0,
		LeftShift = 0,
		RightShift = 0,
	}

	-- Mobile Controls Bindings
	local MobileControls = script.Parent:WaitForChild("MobileControls")

	MobileControls.Movement.forward.TextButton.MouseButton1Down:Connect(function() keyboard["W"] = 1 end)
	MobileControls.Movement.forward.TextButton.MouseLeave:Connect(function() keyboard["W"] = 0 end)
	MobileControls.Movement.forward.TextButton.MouseButton1Up:Connect(function() keyboard["W"] = 0 end)

	MobileControls.Movement.back.TextButton.MouseButton1Down:Connect(function() keyboard["S"] = 1 end)
	MobileControls.Movement.back.TextButton.MouseLeave:Connect(function() keyboard["S"] = 0 end)
	MobileControls.Movement.back.TextButton.MouseButton1Up:Connect(function() keyboard["S"] = 0 end)

	MobileControls.Movement.right.TextButton.MouseButton1Down:Connect(function() keyboard["D"] = 1 end)
	MobileControls.Movement.right.TextButton.MouseLeave:Connect(function() keyboard["D"] = 0 end)
	MobileControls.Movement.right.TextButton.MouseButton1Up:Connect(function() keyboard["D"] = 0 end)

	MobileControls.Movement.left.TextButton.MouseButton1Down:Connect(function() keyboard["A"] = 1 end)
	MobileControls.Movement.left.TextButton.MouseLeave:Connect(function() keyboard["A"] = 0 end)
	MobileControls.Movement.left.TextButton.MouseButton1Up:Connect(function() keyboard["A"] = 0 end)

	local mouse = {
		Delta = Vector2.new(),
		MouseWheel = 0,
	}

	local zoomingOut = false
	local zoomingIn = false

	MobileControls.zoomIn.TextButton.MouseButton1Down:Connect(function()
		zoomingIn = true
		while zoomingIn do
			task.wait()
			mouse.MouseWheel -= 0.5
		end
	end)
	MobileControls.zoomIn.TextButton.MouseLeave:Connect(function() zoomingIn = false end)
	MobileControls.zoomIn.TextButton.MouseButton1Up:Connect(function() zoomingIn = false end)

	MobileControls.zoomOut.TextButton.MouseButton1Down:Connect(function()
		zoomingOut = true
		while zoomingOut do
			task.wait()
			mouse.MouseWheel += 0.5
		end
	end)
	MobileControls.zoomOut.TextButton.MouseLeave:Connect(function() zoomingOut = false end)
	MobileControls.zoomOut.TextButton.MouseButton1Up:Connect(function() zoomingOut = false end)

	local NAV_GAMEPAD_SPEED  = Vector3.new(1, 1, 1)
	local NAV_KEYBOARD_SPEED = Vector3.new(1, 1, 1)
	local PAN_MOUSE_SPEED    = Vector2.new(1, 1)*(pi/64)
	local PAN_GAMEPAD_SPEED  = Vector2.new(1, 1)*(pi/8)
	local FOV_WHEEL_SPEED    = 1.0
	local FOV_GAMEPAD_SPEED  = 0.25
	local NAV_ADJ_SPEED      = 0.75
	local NAV_SHIFT_MUL      = 0.25

	local navSpeed = 1

	function Input.Vel(dt)
		navSpeed = clamp(navSpeed + dt*(keyboard.Up - keyboard.Down)*NAV_ADJ_SPEED, 0.01, 4)

		local kGamepad = Vector3.new(
			thumbstickCurve(gamepad.Thumbstick1.X),
			thumbstickCurve(gamepad.ButtonR2) - thumbstickCurve(gamepad.ButtonL2),
			thumbstickCurve(-gamepad.Thumbstick1.Y)
		)*NAV_GAMEPAD_SPEED

		local kKeyboard = Vector3.new(
			keyboard.D - keyboard.A + keyboard.K - keyboard.H,
			keyboard.E - keyboard.Q + keyboard.I - keyboard.Y,
			keyboard.S - keyboard.W + keyboard.J - keyboard.U
		)*NAV_KEYBOARD_SPEED

		local shift = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)

		return (kGamepad + kKeyboard)*(navSpeed*(shift and NAV_SHIFT_MUL or 1))
	end

	function Input.Pan(dt)
		if UIS.TouchEnabled and not UIS.KeyboardEnabled and not UIS.MouseEnabled
			and not UIS.GamepadEnabled and not GuiService:IsTenFootInterface() then
			local x = -UserInputService:GetMouseDelta().X
			local y = -UserInputService:GetMouseDelta().Y
			local delta = Vector2.new(y, x)
			mouse.Delta = delta
		end
		local kGamepad = Vector2.new(
			thumbstickCurve(gamepad.Thumbstick2.Y),
			thumbstickCurve(-gamepad.Thumbstick2.X)
		)*PAN_GAMEPAD_SPEED
		local kMouse = mouse.Delta*PAN_MOUSE_SPEED
		mouse.Delta = Vector2.new()
		return kGamepad + kMouse
	end

	function Input.Fov(dt)
		local kGamepad = (gamepad.ButtonX - gamepad.ButtonY)*FOV_GAMEPAD_SPEED
		local kMouse = mouse.MouseWheel*FOV_WHEEL_SPEED
		mouse.MouseWheel = 0
		return kGamepad + kMouse
	end

	do
		local function Keypress(action, state, input)
			keyboard[input.KeyCode.Name] = state == Enum.UserInputState.Begin and 1 or 0
			return Enum.ContextActionResult.Sink
		end

		local function GpButton(action, state, input)
			gamepad[input.KeyCode.Name] = state == Enum.UserInputState.Begin and 1 or 0
			return Enum.ContextActionResult.Sink
		end

		local function MousePan(action, state, input)
			local delta = input.Delta
			mouse.Delta = Vector2.new(-delta.y, -delta.x)
			return Enum.ContextActionResult.Sink
		end

		local function Thumb(action, state, input)
			gamepad[input.KeyCode.Name] = input.Position
			return Enum.ContextActionResult.Sink
		end

		local function Trigger(action, state, input)
			gamepad[input.KeyCode.Name] = input.Position.z
			return Enum.ContextActionResult.Sink
		end

		local function MouseWheel(action, state, input)
			mouse[input.UserInputType.Name] = -input.Position.z
			return Enum.ContextActionResult.Sink
		end

		local function Zero(t)
			for k, v in pairs(t) do
				t[k] = v*0
			end
		end

		function Input.StartCapture()
			ContextActionService:BindActionAtPriority("FreecamKeyboard", Keypress, false, INPUT_PRIORITY,
				Enum.KeyCode.W, Enum.KeyCode.U,
				Enum.KeyCode.A, Enum.KeyCode.H,
				Enum.KeyCode.S, Enum.KeyCode.J,
				Enum.KeyCode.D, Enum.KeyCode.K,
				Enum.KeyCode.E, Enum.KeyCode.I,
				Enum.KeyCode.Q, Enum.KeyCode.Y,
				Enum.KeyCode.Up, Enum.KeyCode.Down
			)
			ContextActionService:BindActionAtPriority("FreecamMousePan",          MousePan,    false, INPUT_PRIORITY, Enum.UserInputType.MouseMovement)
			ContextActionService:BindActionAtPriority("FreecamMouseWheel",        MouseWheel, false, INPUT_PRIORITY, Enum.UserInputType.MouseWheel)
			ContextActionService:BindActionAtPriority("FreecamGamepadButton",     GpButton,    false, INPUT_PRIORITY, Enum.KeyCode.ButtonX, Enum.KeyCode.ButtonY)
			ContextActionService:BindActionAtPriority("FreecamGamepadTrigger",    Trigger,     false, INPUT_PRIORITY, Enum.KeyCode.ButtonR2, Enum.KeyCode.ButtonL2)
			ContextActionService:BindActionAtPriority("FreecamGamepadThumbstick", Thumb,       false, INPUT_PRIORITY, Enum.KeyCode.Thumbstick1, Enum.KeyCode.Thumbstick2)
		end

		function Input.StopCapture()
			navSpeed = 1
			Zero(gamepad)
			Zero(keyboard)
			Zero(mouse)
			ContextActionService:UnbindAction("FreecamKeyboard")
			ContextActionService:UnbindAction("FreecamMousePan")
			ContextActionService:UnbindAction("FreecamMouseWheel")
			ContextActionService:UnbindAction("FreecamGamepadButton")
			ContextActionService:UnbindAction("FreecamGamepadTrigger")
			ContextActionService:UnbindAction("FreecamGamepadThumbstick")
		end
	end
end

local function GetFocusDistance(cameraFrame)
	local znear = 0.1
	local viewport = Camera.ViewportSize
	local projy = 2*tan(cameraFov/2)
	local projx = viewport.x/viewport.y*projy
	local fx = cameraFrame.rightVector
	local fy = cameraFrame.upVector
	local fz = cameraFrame.lookVector

	local minVect = Vector3.new()
	local minDist = 512

	for x = 0, 1, 0.5 do
		for y = 0, 1, 0.5 do
			local cx = (x - 0.5)*projx
			local cy = (y - 0.5)*projy
			local offset = fx*cx - fy*cy + fz
			local origin = cameraFrame.Position + offset*znear
			local rayDirection = offset.unit*minDist
			local rayResult = Workspace:Raycast(origin, rayDirection)
			local hit = rayResult and rayResult.Position or (origin + rayDirection)
			local dist = (hit - origin).magnitude
			if minDist > dist then
				minDist = dist
				minVect = offset.unit
			end
		end
	end

	return fz:Dot(minVect)*minDist
end

------------------------------------------------------------------------

local function StepFreecam(dt)
	local vel = velSpring:Update(dt, Input.Vel(dt))
	local pan = panSpring:Update(dt, Input.Pan(dt))
	local fov = fovSpring:Update(dt, Input.Fov(dt))

	local zoomFactor = sqrt(tan(rad(70/2))/tan(rad(cameraFov/2)))

	cameraFov = clamp(cameraFov + fov*FOV_GAIN*(dt/zoomFactor), 1, 120)
	cameraRot = cameraRot + pan*PAN_GAIN*(dt/zoomFactor)
	cameraRot = Vector2.new(clamp(cameraRot.x, -PITCH_LIMIT, PITCH_LIMIT), cameraRot.y%(2*pi))

	local cameraCFrame = CFrame.new(cameraPos)*CFrame.fromOrientation(cameraRot.x, cameraRot.y, 0)*CFrame.new(vel*NAV_GAIN*dt)
	cameraPos = cameraCFrame.Position

	Camera.CFrame = cameraCFrame
	Camera.Focus = cameraCFrame*CFrame.new(0, 0, -GetFocusDistance(cameraCFrame))
	Camera.FieldOfView = cameraFov
end

------------------------------------------------------------------------

local PlayerState = {} do
	local mouseBehavior
	local mouseIconEnabled
	local cameraType
	local cameraFocus
	local cameraCFrame
	local cameraFieldOfView
	local screenGuis = {}
	local coreGuis = {
		Backpack = true,
		Chat = true,
		Health = true,
		PlayerList = true,
	}
	local setCores = {
		BadgesNotificationsActive = true,
		PointsNotificationsActive = true,
	}

	-- Save state and set up for freecam
	function PlayerState.Push()
		for name in pairs(coreGuis) do
			coreGuis[name] = StarterGui:GetCoreGuiEnabled(Enum.CoreGuiType[name])
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType[name], false)
		end
		for name in pairs(setCores) do
			setCores[name] = StarterGui:GetCore(name)
			StarterGui:SetCore(name, false)
		end
		local playergui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
		if playergui then
			for _, gui in pairs(playergui:GetChildren()) do
				if gui:IsA("ScreenGui") and gui.Enabled then
					-- HANYA SELAMATKAN GUI FREECAM INI, BIARKAN TOPBAR HILANG
					if gui.Name ~= "MobileFreecam" and gui ~= script.Parent then
						screenGuis[#screenGuis + 1] = gui
						gui.Enabled = false
					end
				end
			end
		end

		cameraFieldOfView = Camera.FieldOfView
		Camera.FieldOfView = 70

		cameraType = Camera.CameraType
		Camera.CameraType = Enum.CameraType.Custom

		cameraCFrame = Camera.CFrame
		cameraFocus = Camera.Focus

		mouseIconEnabled = UserInputService.MouseIconEnabled
		UserInputService.MouseIconEnabled = true

		mouseBehavior = UserInputService.MouseBehavior
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	end

	-- Restore state
	function PlayerState.Pop()
		for name, isEnabled in pairs(coreGuis) do
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType[name], isEnabled)
		end
		for name, isEnabled in pairs(setCores) do
			StarterGui:SetCore(name, isEnabled)
		end
		for _, gui in pairs(screenGuis) do
			if gui.Parent then
				gui.Enabled = true
			end
		end

		Camera.FieldOfView = cameraFieldOfView
		cameraFieldOfView = nil

		Camera.CameraType = cameraType
		cameraType = nil

		Camera.CFrame = cameraCFrame
		cameraCFrame = nil

		Camera.Focus = cameraFocus
		cameraFocus = nil

		UserInputService.MouseIconEnabled = mouseIconEnabled
		mouseIconEnabled = nil

		UserInputService.MouseBehavior = mouseBehavior
		mouseBehavior = nil
	end
end

local function StartFreecam()
	local cameraCFrame = Camera.CFrame
	cameraRot = Vector2.new(cameraCFrame:toEulerAnglesYXZ())
	cameraPos = cameraCFrame.Position
	cameraFov = Camera.FieldOfView

	velSpring:Reset(Vector3.new())
	panSpring:Reset(Vector2.new())
	fovSpring:Reset(0)

	PlayerState.Push()
	RunService:BindToRenderStep("Freecam", Enum.RenderPriority.Camera.Value, StepFreecam)
	Input.StartCapture()
end

local function StopFreecam()
	Input.StopCapture()
	RunService:UnbindFromRenderStep("Freecam")
	PlayerState.Pop()
end

------------------------------------------------------------------------
-- KONEKSI DARI TOPBAR PLUS V3 (DALAM MENU) + TOMBOL CLOSE BAWAAN GUI
------------------------------------------------------------------------
local UserInputService = game:GetService("UserInputService")
local enabled = false
local PlayerModule = require(game.Players.LocalPlayer.PlayerScripts:WaitForChild("PlayerModule"))
local Controls = PlayerModule:GetControls()

-- 💡 PERBAIKAN DETEKSI DEVICE: HP vs PC
local isMobile = UserInputService.TouchEnabled and not UserInputService.MouseEnabled

-- 1. TOMBOL CLOSE BAWAAN GUI KAMU (CloseFreecamBtn)
local closeBtn = script.Parent:WaitForChild("CloseFreecamBtn")
closeBtn.Visible = false

-- FUNGSI MEMATIKAN FREECAM
local function TurnOffFreecam()
	if enabled then
		StopFreecam()
		enabled = false
		Controls:Enable()

		-- Sembunyikan tombol Close bawaan GUI
		closeBtn.Visible = false 

		-- Sembunyikan Mobile Controls
		if script.Parent:FindFirstChild("MobileControls") then
			script.Parent.MobileControls.Visible = false
		end
	end
end

-- 2. DIPANGGIL OLEH TOPBAR PLUS SAAT TOMBOL 'FreeCam' DI MENU DIKLIK (NYALA)
_G.__Freecam_Enable = function()
	if not enabled then
		StartFreecam()
		enabled = true
		Controls:Disable()

		-- MUNCULKAN TOMBOL CLOSE BAWAAN GUI-MU!
		closeBtn.Visible = true 

		-- 💡 HANYA MUNCULKAN MOBILE CONTROLS JIKA PLAYER PAKAI HP!
		if isMobile and script.Parent:FindFirstChild("MobileControls") then
			script.Parent.MobileControls.Visible = true
		end
	end
end

-- 3. DIPANGGIL OLEH TOPBAR PLUS SAAT DIMATIKAN
_G.__Freecam_Disable = function()
	TurnOffFreecam()
end

-- 4. SAAT TOMBOL CLOSE GUI-MU DIKLIK (MATI SECARA MANUAL DARI LAYAR)
closeBtn.MouseButton1Click:Connect(function()
	TurnOffFreecam()
end)

-- ====================================
-- ACCESSORY GUI CONTROLLER
-- Place in StarterPlayer > StarterPlayerScripts
-- ====================================
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Player = Players.LocalPlayer

-- Wait for Remote Event
local AccessoryRemotes = ReplicatedStorage:WaitForChild("AccessoryRemotes")
local AccessoryEvent = AccessoryRemotes:WaitForChild("ToggleAccessory")

-- Wait for GUI
local PlayerGui = Player:WaitForChild("PlayerGui")
local gui = script.Parent -- Gui name MyHat
local mainframe = gui:WaitForChild("Mainframe")
local equipBtn = mainframe:WaitForChild("EquipBtn")
local unequipBtn = mainframe:WaitForChild("UnequipBtn")

-- ====================================
-- FUNCTIONS
-- ====================================
local function equipAccessory()
	AccessoryEvent:FireServer("equip")
end

local function unequipAccessory()
	AccessoryEvent:FireServer("unequip")
end

-- ====================================
-- BUTTON CONNECTIONS
-- ====================================
equipBtn.MouseButton1Click:Connect(function()
	equipAccessory()
end)

unequipBtn.MouseButton1Click:Connect(function()
	unequipAccessory()
end)

-- ====================================
-- INITIALIZE
-- ====================================
mainframe.Visible = false

-- ============================================
-- PlayerMenuClient
-- Letakkan di: StarterGui > [ScreenGui] > LocalScript
-- ============================================

local Players              = game:GetService("Players")
local ReplicatedStorage    = game:GetService("ReplicatedStorage")
local GuiService           = game:GetService("GuiService")
local TextChatService      = game:GetService("TextChatService")
local ContextActionService = game:GetService("ContextActionService")
local TweenService         = game:GetService("TweenService")

local localPlayer = Players.LocalPlayer
local camera      = workspace.CurrentCamera

-- ============================================
-- CONSTANTS
-- ============================================
local RAYCAST_DISTANCE         = 500
local CLICK_ACTION_NAME        = "PlayerMenuClick"
local MAX_INTERACTION_DISTANCE = 500
local CLICK_COOLDOWN           = 0.3
local ANIMATION_TIME           = 0.4
local ANIMATION_STYLE          = Enum.EasingStyle.Back
local ANIMATION_DIRECTION      = Enum.EasingDirection.Out

-- Jumlah item outfit per halaman (tombol Back / Forward)
local ITEMS_PER_PAGE = 18

local DEFAULT_BIO = "This user has no bio."

-- Default items (bacon hair set) jika player tidak punya aksesoris
local DEFAULT_BACON_ITEMS = {
	139607718, 139607770, 139607673, 139607725, 139607625,
	507766388, 507767714, 507767968, 507765000, 144080495,
}

-- ============================================
-- REMOTES
-- ============================================
local remotes     = ReplicatedStorage:WaitForChild("Remotes")
local startSyncRE = remotes:WaitForChild("startSync")
local CarryConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("CarryConfig"))

-- ============================================
-- GUI ELEMENTS
-- ============================================
local gui       = script.Parent
local mainframe = gui:WaitForChild("MainFrame")
local container = mainframe:WaitForChild("Container")

local TemplateFrame = container:WaitForChild("TemplateFrame")

local OutfitFrame    = container:WaitForChild("OutfitFrame")
local outfitView     = OutfitFrame:WaitForChild("OutfitView")
local templateOutfit = outfitView:WaitForChild("TemplateOutfit")
local backBtn        = OutfitFrame:WaitForChild("Back")
local fowardBtn      = OutfitFrame:WaitForChild("Forward")

local StatusFrame = container:WaitForChild("StatusFrame")
local Playerbio   = StatusFrame:WaitForChild("PlayerStatus")

local ProfileFrame    = container:WaitForChild("ProfileFrame")
local playerinfo      = ProfileFrame:WaitForChild("PlayerInfo")
local Connectionlabel = playerinfo:WaitForChild("Connections")
local FollowersLabel  = playerinfo:WaitForChild("Followers")
local FollowingLabel  = playerinfo:WaitForChild("Following")
local playerAvatar    = ProfileFrame:WaitForChild("PlayerAvatar")
local namelabel       = ProfileFrame:WaitForChild("NameLabel")
local usernamelabel   = ProfileFrame:WaitForChild("UsernameLabel")

local CloseBtn = mainframe:WaitForChild("CloseBtn")

-- ============================================
-- STATE
-- ============================================
local currentTargetPlayer   = nil
local isSyncing             = false
local inputLock             = false
local lastClickTime         = 0
local createdButtons        = {}
local hiddenPlayers         = {}
local monitoringConnections = {}
local isLoadingMenu         = false  -- cegah spam klik saat data masih di-fetch

-- Outfit pagination
local outfitItemIds = {}  -- semua asset id player saat ini
local outfitPage    = 1   -- halaman aktif (1-based)
local outfitTiles   = {}  -- ImageLabel yang sedang ditampilkan

_G.GetClickedPlayer = function() return nil end

-- ============================================
-- MENU ANIMATION POSITIONS
-- ============================================
local MENU_FINAL_POSITION = mainframe.Position
local MENU_START_POSITION = UDim2.new(
	MENU_FINAL_POSITION.X.Scale,
	MENU_FINAL_POSITION.X.Offset,
	1.2,
	MENU_FINAL_POSITION.Y.Offset
)

-- ============================================
-- FORWARD DECLARATIONS
-- ============================================
local playClickSound
local closeMenu
local updateSyncButtonState
local updateHideButtonState

-- ============================================
-- HIDE PLAYER — UTILITY
-- ============================================
local HideUtils = {}

function HideUtils:HideBasePart(part, shouldHide)
	if part:IsA("BasePart") or part:IsA("MeshPart") or part:IsA("Decal") or part:IsA("Texture") then
		part.LocalTransparencyModifier = shouldHide and 1 or 0
		return true
	end
	return false
end

function HideUtils:HideEffect(effect, shouldHide)
	if effect:IsA("ParticleEmitter") or effect:IsA("Fire") or
		effect:IsA("Smoke") or effect:IsA("Sparkles") or
		effect:IsA("Trail") or effect:IsA("Beam") then
		effect.Enabled = not shouldHide
		return true
	end
	return false
end

function HideUtils:HideLight(light, shouldHide)
	if light:IsA("PointLight") or light:IsA("SpotLight") or light:IsA("SurfaceLight") then
		light.Enabled = not shouldHide
		return true
	end
	return false
end

function HideUtils:HideGui(guiObj, shouldHide)
	if guiObj:IsA("BillboardGui") or guiObj:IsA("SurfaceGui") then
		guiObj.Enabled = not shouldHide
		return true
	end
	return false
end

function HideUtils:IsAuraModel(model)
	local auraKeywords = { "aura", "effect", "vfx", "particle", "donation" }
	local modelName    = model.Name:lower()
	for _, keyword in ipairs(auraKeywords) do
		if modelName:find(keyword) then return true end
	end
	return false
end

-- ============================================
-- HIDE PLAYER — SYSTEM
-- ============================================
local PlayerHideSystem = {}

function PlayerHideSystem:HideObject(object, shouldHide)
	for _, descendant in ipairs(object:GetDescendants()) do
		HideUtils:HideBasePart(descendant, shouldHide)
		HideUtils:HideEffect(descendant, shouldHide)
		HideUtils:HideLight(descendant, shouldHide)
		HideUtils:HideGui(descendant, shouldHide)
	end
end

function PlayerHideSystem:HideAttachmentEffects(character, shouldHide)
	for _, attachment in ipairs(character:GetDescendants()) do
		if attachment:IsA("Attachment") then
			for _, effect in ipairs(attachment:GetChildren()) do
				HideUtils:HideEffect(effect, shouldHide)
				HideUtils:HideLight(effect, shouldHide)
			end
		end
	end
end

function PlayerHideSystem:HideTools(targetPlayer, character, shouldHide)
	if targetPlayer.Backpack then
		for _, tool in ipairs(targetPlayer.Backpack:GetChildren()) do
			if tool:IsA("Tool") then self:HideObject(tool, shouldHide) end
		end
	end
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Tool") then self:HideObject(child, shouldHide) end
	end
end

function PlayerHideSystem:HideAuraModels(character, shouldHide)
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Model") and HideUtils:IsAuraModel(child) then
			self:HideObject(child, shouldHide)
		end
	end
end

function PlayerHideSystem:HideOverheadGui(character, shouldHide)
	local head = character:FindFirstChild("Head")
	if not head then return end
	local overheadGui = head:FindFirstChild("OverheadGui")
	if overheadGui and overheadGui:IsA("BillboardGui") then
		overheadGui.Enabled = not shouldHide
	end
end

function PlayerHideSystem:ApplyHideState(targetPlayer, character, shouldHide)
	self:HideObject(character, shouldHide)
	self:HideAttachmentEffects(character, shouldHide)
	self:HideTools(targetPlayer, character, shouldHide)
	self:HideAuraModels(character, shouldHide)
	self:HideOverheadGui(character, shouldHide)
end

function PlayerHideSystem:TogglePlayer(targetPlayer)
	if not targetPlayer or not targetPlayer.Character then
		warn("[HIDE SYSTEM] Player atau character tidak valid")
		return
	end
	local shouldHide            = not hiddenPlayers[targetPlayer]
	hiddenPlayers[targetPlayer] = shouldHide
	self:ApplyHideState(targetPlayer, targetPlayer.Character, shouldHide)
	return shouldHide
end

function PlayerHideSystem:IsPlayerHidden(targetPlayer)
	return hiddenPlayers[targetPlayer] == true
end

function PlayerHideSystem:SetupPlayerMonitoring(targetPlayer)
	if monitoringConnections[targetPlayer] then
		for _, conn in ipairs(monitoringConnections[targetPlayer]) do
			conn:Disconnect()
		end
	end
	monitoringConnections[targetPlayer] = {}

	local function trackConnection(conn)
		table.insert(monitoringConnections[targetPlayer], conn)
	end

	trackConnection(targetPlayer.CharacterAdded:Connect(function(character)
		task.wait(0.5)
		if hiddenPlayers[targetPlayer] then
			self:ApplyHideState(targetPlayer, character, true)
		end

		trackConnection(character.ChildAdded:Connect(function(child)
			if not hiddenPlayers[targetPlayer] then return end
			task.wait(0.1)
			if child:IsA("Tool") or (child:IsA("Model") and HideUtils:IsAuraModel(child)) then
				self:HideObject(child, true)
			end
		end))

		if targetPlayer.Backpack then
			trackConnection(targetPlayer.Backpack.ChildAdded:Connect(function(child)
				if child:IsA("Tool") and hiddenPlayers[targetPlayer] then
					task.wait(0.1)
					self:HideObject(child, true)
				end
			end))
		end

		local head = character:FindFirstChild("Head")
		if head then
			trackConnection(head.ChildAdded:Connect(function(child)
				if child.Name == "OverheadGui" and child:IsA("BillboardGui") then
					if hiddenPlayers[targetPlayer] then
						task.wait(0.1)
						child.Enabled = false
					end
				end
			end))
		end
	end))
end

-- ============================================
-- UTILITY
-- ============================================
playClickSound = function()
	local sounds     = ReplicatedStorage:FindFirstChild("Sounds")
	if not sounds then return end
	local clickSound = sounds:FindFirstChild("minimal-pop-click-ui")
	if clickSound then clickSound:Play() end
end

local function isPointInsideFrame(frame, point)
	local pos  = frame.AbsolutePosition
	local size = frame.AbsoluteSize
	return point.X >= pos.X and point.X <= pos.X + size.X
		and point.Y >= pos.Y and point.Y <= pos.Y + size.Y
end

-- ============================================
-- ANIMATION
-- ============================================
local currentTween = nil

local function showMenuWithAnimation()
	if currentTween then currentTween:Cancel() end
	mainframe.Position = MENU_START_POSITION
	mainframe.Visible  = true
	local tweenInfo    = TweenInfo.new(ANIMATION_TIME, ANIMATION_STYLE, ANIMATION_DIRECTION)
	currentTween       = TweenService:Create(mainframe, tweenInfo, { Position = MENU_FINAL_POSITION })
	currentTween:Play()
	currentTween.Completed:Once(function() currentTween = nil end)
end

local function hideMenuWithAnimation(callback)
	if currentTween then currentTween:Cancel() end
	local tweenInfo = TweenInfo.new(ANIMATION_TIME * 0.7, Enum.EasingStyle.Back, Enum.EasingDirection.In)
	currentTween    = TweenService:Create(mainframe, tweenInfo, { Position = MENU_START_POSITION })
	currentTween:Play()
	currentTween.Completed:Once(function()
		mainframe.Visible = false
		currentTween      = nil
		if callback then callback() end
	end)
end

closeMenu = function()
	currentTargetPlayer = nil
	_G.GetClickedPlayer = function() return nil end
	playClickSound()
	hideMenuWithAnimation()
end


-- ============================================
-- WHISPER
-- ============================================
local function openWhisperChannel(targetPlayer)
	local textChannels   = TextChatService:FindFirstChild("TextChannels")
	if not textChannels then return end
	local generalChannel = textChannels:FindFirstChild("RBXGeneral")
	if not generalChannel then return end
	pcall(function()
		generalChannel:SendAsync("/w " .. targetPlayer.DisplayName .. " ")
	end)
end

-- ============================================
-- OUTFIT PAGINATION
-- ============================================

local function clearOutfitTiles()
	for _, tile in ipairs(outfitTiles) do
		if tile and tile.Parent then tile:Destroy() end
	end
	outfitTiles = {}
end

local function getTotalPages()
	if #outfitItemIds == 0 then return 1 end
	return math.ceil(#outfitItemIds / ITEMS_PER_PAGE)
end

local function updatePaginationButtons()
	local activeColor   = Color3.fromRGB(255, 255, 255)
	local inactiveColor = Color3.fromRGB(100, 100, 100)

	backBtn.Active       = outfitPage > 1
	fowardBtn.Active     = outfitPage < getTotalPages()
	backBtn.TextColor3   = backBtn.Active   and activeColor or inactiveColor
	fowardBtn.TextColor3 = fowardBtn.Active and activeColor or inactiveColor
end

--[[
	Render halaman outfit saat ini.
	Pakai rbxthumb://type=Asset — tidak butuh HttpService,
	langsung dari CDN Roblox, aman sesuai ToS Roblox.
]]
local function renderOutfitPage()
	clearOutfitTiles()

	local startIdx = (outfitPage - 1) * ITEMS_PER_PAGE + 1
	local endIdx   = math.min(startIdx + ITEMS_PER_PAGE - 1, #outfitItemIds)

	for i = startIdx, endIdx do
		local assetId = outfitItemIds[i]
		local tile    = templateOutfit:Clone()
		tile.Name     = "Item_" .. assetId
		tile.Image    = "rbxthumb://type=Asset&id=" .. assetId .. "&w=150&h=150"
		tile.Visible  = true
		tile.Parent   = outfitView
		table.insert(outfitTiles, tile)
	end

	updatePaginationButtons()
end

--[[
	Ambil daftar aksesoris player via GetCharacterAppearanceInfoAsync,
	lalu render halaman pertama. Berjalan async di background.
]]
local function loadAccessoriesForPlayer(targetPlayer)
	clearOutfitTiles()
	outfitItemIds = {}
	outfitPage    = 1

	task.spawn(function()
		local ok, info = pcall(function()
			return Players:GetCharacterAppearanceInfoAsync(targetPlayer.UserId)
		end)

		local ids = {}
		if ok and info and info.assets then
			for _, asset in ipairs(info.assets) do
				table.insert(ids, asset.id)
			end
		end

		outfitItemIds = (#ids > 0) and ids or DEFAULT_BACON_ITEMS
		renderOutfitPage()
	end)
end

-- Tombol Back & Forward
backBtn.Visible   = true
fowardBtn.Visible = true

backBtn.MouseButton1Click:Connect(function()
	if outfitPage <= 1 then return end
	outfitPage = outfitPage - 1
	playClickSound()
	renderOutfitPage()
end)

fowardBtn.MouseButton1Click:Connect(function()
	if outfitPage >= getTotalPages() then return end
	outfitPage = outfitPage + 1
	playClickSound()
	renderOutfitPage()
end)

-- ============================================
-- MENU CONFIGURATION
-- ============================================
local lastSyncTime = 0  -- ← TAMBAH DI SINI, sebelum MENU_CONFIG

local MENU_CONFIG = {
	-- ... tombol lain ...
	{
		name = "SyncBtn",
		text = "Coordinate Dance",
		callback = function(targetPlayer)
			local now = tick()
			if now - lastSyncTime < 0.5 then return end  -- ← TAMBAH INI
			lastSyncTime = now                            -- ← TAMBAH INI

			if isSyncing or inputLock or not targetPlayer then 
				warn("[DEBUG-CLIENT] DIBLOKIR: isSyncing/inputLock aktif, atau target kosong!")
				return 
			end

			-- Validasi ekstra: Pastikan target belum left game
			if not targetPlayer.Parent then 
				warn("[DEBUG-CLIENT] DIBLOKIR: Target sudah keluar dari game (Parent nil).")
				return 
			end 

			print("[DEBUG-CLIENT] Lolos validasi lokal! Menembak RemoteEvent ke Server...")
			inputLock = true
			startSyncRE:FireServer(targetPlayer, true)
			playClickSound()
			task.wait(0.2)
			updateSyncButtonState()
			inputLock = false
			closeMenu()
		end,
		updateState = function(button)
			if not localPlayer.Character then return end
			local syncTarget = localPlayer.Character:GetAttribute("Syncing")
			if syncTarget and syncTarget ~= "" then
				isSyncing              = true
				button.Text            = "Already Syncing"
				button.AutoButtonColor = false
				button.Active          = false
				local stroke = button:FindFirstChild("UIStroke")
				if stroke then stroke.Color = Color3.fromRGB(85, 85, 127) end
			else
				isSyncing              = false
				button.Text            = "Coordinate Dance"
				button.AutoButtonColor = true
				button.Active          = true
				local stroke = button:FindFirstChild("UIStroke")
				if stroke then stroke.Color = Color3.fromRGB(255, 255, 255) end
			end
		end,
	},
	{
		name = "HidePlayer",
		text = "Hide Player",
		callback = function(targetPlayer)
			if not targetPlayer then return end
			PlayerHideSystem:TogglePlayer(targetPlayer)
			playClickSound()
			updateHideButtonState()
		end,
		updateState = function(button)
			if not currentTargetPlayer then return end
			local isHidden = PlayerHideSystem:IsPlayerHidden(currentTargetPlayer)
			button.Text    = isHidden and "Show Player" or "Hide Player"
			local stroke   = button:FindFirstChild("UIStroke")
			if stroke then
				stroke.Color = isHidden
					and Color3.fromRGB(85, 85, 127)
					or  Color3.fromRGB(255, 255, 255)
			end
		end,
	},
	{
		name = "Carry",
		text = "Carry Player",
		callback = function(targetPlayer)
			if not targetPlayer then return end

			local myHRP     = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")
			local targetHRP = targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart")

			if not myHRP or not targetHRP then closeMenu() return end

			if (myHRP.Position - targetHRP.Position).Magnitude > CarryConfig.MAX_DISTANCE then
				warn("[PLAYER MENU] Target terlalu jauh untuk di-carry")
				closeMenu()
				return
			end

			local carryEvents = ReplicatedStorage:FindFirstChild("CarryEvents")
				or (function()
					local f = Instance.new("Folder")
					f.Name   = "CarryEvents"
					f.Parent = ReplicatedStorage
					return f
				end)()

			local showStyleUI = carryEvents:FindFirstChild("ShowStyleUI")
				or (function()
					local e = Instance.new("BindableEvent")
					e.Name   = "ShowStyleUI"
					e.Parent = carryEvents
					return e
				end)()

			pcall(function() showStyleUI:Fire(targetPlayer) end)
			closeMenu()
		end,
	},
	{
		name = "GiftVIP",
		text = "Gift VIP", 
		callback = function(targetPlayer)
			if not targetPlayer then return end
			game.ReplicatedStorage.Remotes.PromptGift:FireServer(targetPlayer, "VIP")
			closeMenu()
		end,
		updateState = function(button)
			if not currentTargetPlayer then return end
			-- Cek apakah target sudah punya role VIP ke atas
			local role = currentTargetPlayer:FindFirstChild("Role")
			local hasRole = role and (role.Value == "VIP" or role.Value == "VVIP" or role.Value == "Admin" or role.Value == "Owner")

			button.Active = not hasRole
			button.Text = hasRole and "Target is already VIP" or "Gift VIP"
			button.AutoButtonColor = not hasRole
			local stroke = button:FindFirstChild("UIStroke")
			if stroke then stroke.Color = hasRole and Color3.fromRGB(100, 100, 100) or Color3.fromRGB(255, 255, 255) end
		end,
	},
	{
		name = "GiftVVIP",
		text = "Gift VVIP", 
		callback = function(targetPlayer)
			if not targetPlayer then return end
			game.ReplicatedStorage.Remotes.PromptGift:FireServer(targetPlayer, "VVIP")
			closeMenu()
		end,
		updateState = function(button)
			if not currentTargetPlayer then return end
			local role = currentTargetPlayer:FindFirstChild("Role")
			local hasRole = role and (role.Value == "VVIP" or role.Value == "Admin" or role.Value == "Owner")

			button.Active = not hasRole
			button.Text = hasRole and "Target is already VVIP" or "Gift VVIP"
			button.AutoButtonColor = not hasRole
			local stroke = button:FindFirstChild("UIStroke")
			if stroke then stroke.Color = hasRole and Color3.fromRGB(100, 100, 100) or Color3.fromRGB(255, 255, 255) end
		end,
	},
	{
		name = "WhisperBtn",
		text = "Whisper",
		callback = function(targetPlayer)
			if not targetPlayer then return end
			pcall(function() openWhisperChannel(targetPlayer) end)
			playClickSound()
			closeMenu()
		end,
	},
	{
		name = "Inspect",
		text = "Inspect Profile",
		callback = function(targetPlayer)
			if not targetPlayer then return end
			pcall(function()
				GuiService:InspectPlayerFromUserId(targetPlayer.UserId)
			end)
			closeMenu()
		end,
	},
	{
		name = "Addfriend",
		text = "Add Friend",
		callback = function(targetPlayer)
			if not targetPlayer then return end
			pcall(function()
				localPlayer:RequestFriendship(targetPlayer)
			end)
			playClickSound()
			closeMenu()
		end,
	},
}

CloseBtn.MouseButton1Click:Connect(closeMenu)

-- ============================================
-- BUTTON STATE UPDATERS
-- ============================================
updateSyncButtonState = function()
	local btn = createdButtons["SyncBtn"]
	if btn and MENU_CONFIG[1].updateState then
		MENU_CONFIG[1].updateState(btn)
	end
end

updateHideButtonState = function()
	local btn = createdButtons["HidePlayer"]
	if btn and MENU_CONFIG[2].updateState then
		MENU_CONFIG[2].updateState(btn)
	end
end

-- ============================================
-- CREATE MENU BUTTONS
-- ============================================
local function createMenuButtons()
	for _, btn in pairs(createdButtons) do
		if btn and btn.Parent then btn:Destroy() end
	end
	createdButtons = {}

	for _, config in ipairs(MENU_CONFIG) do
		local newFrame = TemplateFrame:Clone()
		newFrame.Name    = config.name .. "Frame"
		newFrame.Visible = true
		newFrame.Parent  = container

		local newBtn = newFrame:FindFirstChild("TemplateBtn")
		if newBtn then
			newBtn.Name = config.name
			newBtn.Text = config.text
			createdButtons[config.name] = newBtn

			newBtn.MouseButton1Click:Connect(function()
				if config.callback then
					config.callback(currentTargetPlayer)
				end
			end)
		end
	end
end

-- ============================================
-- SYNC MONITORING
-- ============================================
local syncConnection = nil

local function setupSyncMonitoring()
	if syncConnection then
		syncConnection:Disconnect()
		syncConnection = nil
	end
	local character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
	updateSyncButtonState()
	syncConnection = character:GetAttributeChangedSignal("Syncing"):Connect(updateSyncButtonState)
end

if localPlayer.Character then setupSyncMonitoring() end
localPlayer.CharacterAdded:Connect(function()
	task.wait(0.5)
	setupSyncMonitoring()
end)

-- ============================================
-- UPDATE PLAYER INFO
-- ============================================
--[[
	Alur "load dulu, baru tampil":

	1. Set nama, username, dan avatar LANGSUNG — ketiganya tidak perlu fetch.
	   Avatar pakai rbxthumb://type=Avatar yang dihandle Roblox secara internal,
	   tidak butuh HttpService, tidak butuh cache manual, sesuai ToS Roblox.

	2. Set label bio & social ke "Loading..." sebagai placeholder.

	3. Fetch bio + social counts via RemoteFunction ke server.
	   Server yang menjalankan HttpService ke roproxy + cache + TextService filter.

	4. Setelah server balas → update semua label sekaligus, panggil onReady().

	5. onReady() membuka animasi menu — menu baru tampil setelah data siap.

	6. loadAccessoriesForPlayer berjalan paralel di background —
	   outfit muncul setelah menu terbuka, tidak menghambat.
]]
local function updatePlayerInfo(targetPlayer, onReady)
	-- Nama & username tersedia langsung dari object Player
	namelabel.Text     = targetPlayer.DisplayName
	usernamelabel.Text = "@" .. targetPlayer.Name

	-- Avatar: rbxthumb:// tidak butuh pcall, tidak butuh cache
	playerAvatar.Image                  = "rbxthumb://type=Avatar&id=" .. targetPlayer.UserId .. "&w=352&h=352"
	playerAvatar.BackgroundColor3       = Color3.fromRGB(0, 0, 0)
	playerAvatar.BackgroundTransparency = 1

	-- Placeholder sementara server diquery
	Playerbio.Text       = "Loading..."
	Connectionlabel.Text = "Connections ..."
	FollowersLabel.Text  = "Followers ..."
	FollowingLabel.Text  = "Following ..."

	-- Outfit load di background
	loadAccessoriesForPlayer(targetPlayer)

	-- [PERBAIKAN UTAMA]: Buka menu SEKARANG JUGA! Jangan tunggu server membalas.
	if onReady then onReady() end

	-- Fetch bio + social dari server di background
	task.spawn(function()
		local getPlayerInfoRF = remotes:FindFirstChild("GetPlayerInfo")
		local profileData     = nil

		if getPlayerInfoRF then
			local ok, data = pcall(function()
				return getPlayerInfoRF:InvokeServer(targetPlayer.UserId)
			end)
			if ok and data then
				profileData = data
			else
				warn("[CLIENT] InvokeServer gagal untuk:", targetPlayer.Name)
			end
		else
			warn("[CLIENT] RemoteFunction 'GetPlayerInfo' tidak ditemukan di Remotes")
		end

		-- [CEK KEAMANAN]: Pastikan pemain belum menutup menu atau mengklik orang lain
		if currentTargetPlayer ~= targetPlayer then return end

		-- Update label jika data tiba
		if profileData then
			Playerbio.Text       = (profileData.description ~= "" and profileData.description) or DEFAULT_BIO
			Connectionlabel.Text = "Connections " .. tostring(profileData.friendsCount   or 0)
			FollowersLabel.Text  = "Followers "   .. tostring(profileData.followersCount or 0)
			FollowingLabel.Text  = "Following "   .. tostring(profileData.followingCount or 0)
		else
			Playerbio.Text       = DEFAULT_BIO
			Connectionlabel.Text = "Connections N/A"
			FollowersLabel.Text  = "Followers N/A"
			FollowingLabel.Text  = "Following N/A"
		end
	end)
end

-- ============================================
-- RAYCAST
-- ============================================
local function raycastFromScreen(screenPosition)
	local unitRay = camera:ViewportPointToRay(screenPosition.X, screenPosition.Y)
	local params  = RaycastParams.new()
	params.FilterType                 = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { localPlayer.Character, camera }
	params.IgnoreWater                = true

	local result = workspace:Raycast(unitRay.Origin, unitRay.Direction * RAYCAST_DISTANCE, params)
	if result and result.Instance then
		local character = result.Instance:FindFirstAncestorOfClass("Model")
		if character then
			local player = Players:GetPlayerFromCharacter(character)
			if player and player ~= localPlayer then return player end
		end
	end
	return nil
end

local function isPlayerInRange(targetPlayer, maxDistance)
	local myChar     = localPlayer.Character
	local targetChar = targetPlayer.Character
	if not myChar or not targetChar then return false, 0 end

	local myHRP     = myChar:FindFirstChild("HumanoidRootPart")
	local targetHRP = targetChar:FindFirstChild("HumanoidRootPart")
	if not myHRP or not targetHRP then return false, 0 end

	local distance = (myHRP.Position - targetHRP.Position).Magnitude
	return distance <= maxDistance, distance
end

-- ============================================
-- SET TARGET PLAYER
-- ============================================
--[[
	Fetch profil dulu → menu terbuka hanya setelah data siap via onReady.
	isLoadingMenu mencegah klik berulang saat fetch masih berlangsung.
]]
local function setTargetPlayer(player)
	if player == localPlayer then return end
	if isLoadingMenu then return end

	isLoadingMenu       = true
	currentTargetPlayer = player

	_G.GetClickedPlayer = function() return currentTargetPlayer end

	updateSyncButtonState()
	updateHideButtonState()

	updatePlayerInfo(player, function()
		isLoadingMenu = false
		playClickSound()
		showMenuWithAnimation()
	end)
end

-- ============================================
-- INPUT HANDLER
-- ============================================
local function handlePlayerClick(actionName, inputState, inputObject)
	if inputState ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end

	local currentTime = tick()
	if currentTime - lastClickTime < CLICK_COOLDOWN then
		return Enum.ContextActionResult.Pass
	end

	local inputPosition = inputObject.Position

	if mainframe.Visible and isPointInsideFrame(mainframe, inputPosition) then
		return Enum.ContextActionResult.Pass
	end

	if mainframe.Visible then
		closeMenu()
		return Enum.ContextActionResult.Sink
	end

	if isLoadingMenu then
		return Enum.ContextActionResult.Pass
	end

	local targetPlayer = raycastFromScreen(inputPosition)
	if targetPlayer then
		local inRange, distance = isPlayerInRange(targetPlayer, MAX_INTERACTION_DISTANCE)
		if not inRange then
			warn("[PLAYER MENU] Player terlalu jauh:", math.floor(distance), "studs")
			return Enum.ContextActionResult.Pass
		end
		lastClickTime = currentTime
		setTargetPlayer(targetPlayer)
		return Enum.ContextActionResult.Sink
	end

	return Enum.ContextActionResult.Pass
end

-- ============================================
-- INITIALIZE
-- ============================================
for _, player in ipairs(Players:GetPlayers()) do
	if player ~= localPlayer then
		PlayerHideSystem:SetupPlayerMonitoring(player)
	end
end

Players.PlayerAdded:Connect(function(player)
	if player ~= localPlayer then
		PlayerHideSystem:SetupPlayerMonitoring(player)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	hiddenPlayers[player] = nil
	if monitoringConnections[player] then
		for _, conn in ipairs(monitoringConnections[player]) do
			conn:Disconnect()
		end
		monitoringConnections[player] = nil
	end
end)

createMenuButtons()
updatePaginationButtons()

ContextActionService:BindAction(
	CLICK_ACTION_NAME,
	handlePlayerClick,
	false,
	Enum.UserInputType.MouseButton1,
	Enum.UserInputType.Touch
)

-- ============================================
-- CLEANUP
-- ============================================
script.Destroying:Connect(function()
	if syncConnection then syncConnection:Disconnect() end
	if currentTween   then currentTween:Cancel() end

	ContextActionService:UnbindAction(CLICK_ACTION_NAME)

	for _, connections in pairs(monitoringConnections) do
		for _, conn in ipairs(connections) do conn:Disconnect() end
	end
	monitoringConnections = {}

	for _, btn in pairs(createdButtons) do
		if btn and btn.Parent then btn:Destroy() end
	end
	createdButtons = {}
	clearOutfitTiles()
end)

-- ============================================
-- CONFIGURATION
-- ============================================
local CONFIG = {
	DEBUG_MODE = false, 
	DEBUG_DETAILED = false, 

	ANIMATION_DURATION = 0.3,
	ANIMATION_STYLE = Enum.EasingStyle.Quad,
	ANIMATION_DIRECTION = Enum.EasingDirection.Out,

	WAIT_FOR_ACCESSORIES = 0.5, 
	WAIT_FOR_TOOLS = 0.1, 
	WAIT_FOR_OVERHEAD = 0.3, 
	WAIT_FOR_EFFECTS = 0.2, 

	DETECT_AURA_NAMES = true, 
	AURA_KEYWORDS = {"aura", "effect", "vfx", "particle", "donation"}, 

	BUTTON_POS_ON = UDim2.new(1, -20, 0, 0), 
	BUTTON_POS_OFF = UDim2.new(0, 0, 0, 0), 

	BG_COLOR_ON = Color3.fromRGB(46, 204, 113),
	BG_COLOR_OFF = Color3.fromRGB(20, 20, 20), 
}

-- ============================================
-- SERVICES
-- ============================================
local player = game:GetService("Players")
local replicatedstorage = game:GetService("ReplicatedStorage")
local tweenservice = game:GetService("TweenService")
local lighting = game:GetService("Lighting")
local textChatService = game:GetService("TextChatService")
local collectionService = game:GetService("CollectionService") -- [BARU] Untuk melacak tag

local localPlayer = player.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

-- ============================================
-- UI REFERENCES
-- ============================================
local gui = script.Parent
local mainframe = gui:WaitForChild("Mainframe")
local settingBtn = gui:FindFirstChild("SettingBtn")
local headerframe = mainframe:WaitForChild("HeaderFrame")
local closeBtn = headerframe:WaitForChild("CloseBtn")

local unhideBtn = gui:WaitForChild("Unhide")
unhideBtn.Visible = false 

local containerframe = mainframe:WaitForChild("ContainerFrame")
local templateframe = containerframe:WaitForChild("TemplateFrame")
templateframe.Visible = false

-- ============================================
-- UTILITY FUNCTIONS
-- ============================================
local Utils = {}

function Utils:IsAura(object)
	if not CONFIG.DETECT_AURA_NAMES then return false end
	local name = object.Name:lower()
	for _, keyword in ipairs(CONFIG.AURA_KEYWORDS) do
		if name:find(keyword:lower()) then return true end
	end
	return false
end

function Utils:AnimateButton(button, bg, isActive)
	local tweenInfo = TweenInfo.new(CONFIG.ANIMATION_DURATION, CONFIG.ANIMATION_STYLE, CONFIG.ANIMATION_DIRECTION)
	local newPosition = isActive and CONFIG.BUTTON_POS_ON or CONFIG.BUTTON_POS_OFF
	local newColor = isActive and CONFIG.BG_COLOR_ON or CONFIG.BG_COLOR_OFF

	tweenservice:Create(button, tweenInfo, {Position = newPosition}):Play()
	tweenservice:Create(bg, tweenInfo, {BackgroundColor3 = newColor}):Play()
end

function Utils:HideBasePart(part, shouldHide)
	if part:IsA("BasePart") or part:IsA("MeshPart") or part:IsA("Decal") or part:IsA("Texture") then
		part.LocalTransparencyModifier = shouldHide and 1 or 0
		return true
	end
	return false
end

function Utils:HideEffect(effect, shouldHide)
	if effect:IsA("ParticleEmitter") or effect:IsA("Fire") or 
		effect:IsA("Smoke") or effect:IsA("Sparkles") or 
		effect:IsA("Trail") or effect:IsA("Beam") then
		effect.Enabled = not shouldHide
		return true
	end
	return false
end

function Utils:HideLight(light, shouldHide)
	if light:IsA("Light") or light:IsA("PointLight") or 
		light:IsA("SpotLight") or light:IsA("SurfaceLight") then
		light.Enabled = not shouldHide
		return true
	end
	return false
end

function Utils:HideGui(gui, shouldHide)
	if gui:IsA("BillboardGui") or gui:IsA("SurfaceGui") then
		gui.Enabled = not shouldHide
		return true
	end
	return false
end

-- ============================================
-- SYSTEM DECLARATIONS
-- ============================================
local OverheadSystem = {}
local BubbleChatSystem = {}
local ShadowSystem = {}
local PlayerHideSystem = {}
local EffectsSystem = {}
local HideUISystem = { hiddenGuis = {} }

-- ============================================
-- FEATURES CONFIGURATION
-- ============================================
local FEATURES = {
	{
		id = "overhead",
		name = "Hide Player Name",
		defaultState = false,
		onToggle = function(self, isActive) OverheadSystem:SetVisible(not isActive) end,
		onCharacterAdded = function(self, character, player) OverheadSystem:OnCharacterAdded(character) end
	},
	{
		id = "bubblechat",
		name = "Hide Bubble Chat",
		defaultState = false,
		onToggle = function(self, isActive) BubbleChatSystem:SetVisible(not isActive) end
	},
	{
		id = "shadow",
		name = "Hide All Shadow",
		defaultState = false,
		onToggle = function(self, isActive) ShadowSystem:SetVisible(not isActive) end
	},
	{
		id = "players",
		name = "Hide All Players",
		defaultState = false,
		onToggle = function(self, isActive) PlayerHideSystem:SetPlayersVisible(not isActive) end,
		onCharacterAdded = function(self, character, player) PlayerHideSystem:OnCharacterAdded(character, player) end
	},
	{
		id = "effects",
		name = "Hide Players Effects",
		defaultState = false,
		onToggle = function(self, isActive) EffectsSystem:SetEffectsVisible(not isActive) end,
		onCharacterAdded = function(self, character, player) EffectsSystem:OnCharacterAdded(character, player) end
	},
	{
		id = "hideui",
		name = "Hide All UI",
		defaultState = false,
		onToggle = function(self, isActive) HideUISystem:SetVisible(isActive) end
	}
}

-- ============================================
-- FEATURE MANAGER
-- ============================================
local FeatureManager = {
	features = {},
	featureStates = {}
}

function FeatureManager:RegisterFeature(featureConfig)
	if not featureConfig.id or not featureConfig.name then return false end

	local featureFrame = templateframe:Clone()
	featureFrame.Name = featureConfig.id .. "Frame"
	featureFrame.Visible = true

	local label = featureFrame:FindFirstChild("TemplateLabel")
	if label then label.Text = featureConfig.name end

	local bg = featureFrame:FindFirstChild("Templatebg")
	if not bg then return false end

	local button = bg:FindFirstChild("OnBtn") or bg:FindFirstChild("TemplateBtn")
	if not button then return false end

	self.featureStates[featureConfig.id] = featureConfig.defaultState or false

	button.MouseButton1Click:Connect(function()
		self:ToggleFeature(featureConfig.id)
	end)

	self.features[featureConfig.id] = {
		config = featureConfig, frame = featureFrame,
		button = button, bg = bg, label = label
	}

	if self.featureStates[featureConfig.id] then
		button.Position = CONFIG.BUTTON_POS_ON
		bg.BackgroundColor3 = CONFIG.BG_COLOR_ON
	else
		button.Position = CONFIG.BUTTON_POS_OFF
		bg.BackgroundColor3 = CONFIG.BG_COLOR_OFF
	end

	featureFrame.Parent = containerframe
	return true
end

function FeatureManager:ToggleFeature(featureId)
	local feature = self.features[featureId]
	if not feature or not feature.button then return end

	local newState = not self.featureStates[featureId]
	self.featureStates[featureId] = newState

	Utils:AnimateButton(feature.button, feature.bg, newState)

	if feature.config.onToggle then
		feature.config.onToggle(feature.config, newState)
	end
end

function FeatureManager:GetFeatureState(featureId)
	return self.featureStates[featureId] or false
end

function FeatureManager:OnCharacterAdded(character, playerObj)
	for featureId, feature in pairs(self.features) do
		if feature.config.onCharacterAdded then
			feature.config.onCharacterAdded(feature.config, character, playerObj)
		end
	end
end

-- ============================================
-- HIDE ALL UI SYSTEM
-- ============================================
function HideUISystem:SetVisible(isHiding)
	if isHiding then
		self.hiddenGuis = {}
		for _, childGui in ipairs(playerGui:GetChildren()) do
			if childGui:IsA("ScreenGui") and childGui ~= gui and childGui.Enabled then
				self.hiddenGuis[childGui] = true
				childGui.Enabled = false
			end
		end
		mainframe.Visible = false
		unhideBtn.Visible = true
	else
		for hiddenGui, _ in pairs(self.hiddenGuis) do
			if hiddenGui and hiddenGui.Parent then hiddenGui.Enabled = true end
		end
		self.hiddenGuis = {} 
		unhideBtn.Visible = false
	end
end

-- ============================================
-- MAINFRAME & UNHIDE TOGGLE
-- ============================================
if settingBtn then
	settingBtn.MouseButton1Click:Connect(function()
		mainframe.Visible = not mainframe.Visible
	end)
end

closeBtn.MouseButton1Click:Connect(function() mainframe.Visible = false end)
unhideBtn.MouseButton1Click:Connect(function()
	if FeatureManager:GetFeatureState("hideui") then FeatureManager:ToggleFeature("hideui") end
end)

-- ============================================
-- OTHER SYSTEMS
-- ============================================
function BubbleChatSystem:SetVisible(visible)
	pcall(function()
		local bubbleChatConfig = textChatService:FindFirstChild("BubbleChatConfiguration")
		if bubbleChatConfig then bubbleChatConfig.Enabled = visible end
	end)
end

function OverheadSystem:HideOverheadGui(head, shouldHide)
	local overheadGui = head:FindFirstChild("OverheadGui")
	if overheadGui and overheadGui:IsA("BillboardGui") then
		overheadGui.Enabled = not shouldHide
	end
end

function OverheadSystem:SetVisible(visible)
	for _, otherPlayer in pairs(player:GetPlayers()) do
		if otherPlayer.Character then
			local head = otherPlayer.Character:FindFirstChild("Head")
			if head then self:HideOverheadGui(head, not visible) end
		end
	end
end

function OverheadSystem:OnCharacterAdded(character)
	task.wait(CONFIG.WAIT_FOR_OVERHEAD)
	if FeatureManager:GetFeatureState("overhead") then
		local head = character:FindFirstChild("Head")
		if head then self:HideOverheadGui(head, true) end
	end

	character.ChildAdded:Connect(function(child)
		if child.Name == "Head" then
			child.ChildAdded:Connect(function(grandChild)
				if grandChild.Name == "OverheadGui" and FeatureManager:GetFeatureState("overhead") then
					task.wait(0.1)
					grandChild.Enabled = false
				end
			end)
		end
	end)
end

function ShadowSystem:SetVisible(visible)
	lighting.GlobalShadows = visible
end

-- ============================================
-- EFFECTS HIDE SYSTEM (DISEMPURNAKAN DGN TAG)
-- ============================================
function EffectsSystem:HideCharacterEffects(character, shouldHide)
	for _, descendant in pairs(character:GetDescendants()) do
		Utils:HideEffect(descendant, shouldHide)
	end
end

function EffectsSystem:HideLights(character, shouldHide)
	for _, descendant in pairs(character:GetDescendants()) do
		Utils:HideLight(descendant, shouldHide)
	end
end

function EffectsSystem:HideAuraEffects(character, shouldHide)
	for _, child in pairs(character:GetChildren()) do
		if Utils:IsAura(child) then
			Utils:HideBasePart(child, shouldHide)
			for _, descendant in pairs(child:GetDescendants()) do
				Utils:HideEffect(descendant, shouldHide) 
				Utils:HideLight(descendant, shouldHide) 
				Utils:HideBasePart(descendant, shouldHide)
			end
		end
	end
end

function EffectsSystem:SetEffectsVisible(visible)
	-- Sembunyikan efek di semua karakter
	for _, otherPlayer in pairs(player:GetPlayers()) do
		if otherPlayer ~= localPlayer and otherPlayer.Character then
			local character = otherPlayer.Character
			self:HideCharacterEffects(character, not visible)
			self:HideLights(character, not visible)
			self:HideAuraEffects(character, not visible)
		end
	end

	-- [SANGAT PENTING] Sembunyikan objek donasi di Workspace berdasarkan TAG!
	local shouldHide = not visible
	for _, effect in ipairs(collectionService:GetTagged("DonationEffect")) do
		Utils:HideBasePart(effect, shouldHide)
		for _, desc in ipairs(effect:GetDescendants()) do
			Utils:HideEffect(desc, shouldHide)
			Utils:HideLight(desc, shouldHide)
			Utils:HideBasePart(desc, shouldHide)
		end
	end
end

function EffectsSystem:OnCharacterAdded(character, otherPlayer)
	if otherPlayer ~= localPlayer then
		task.wait(CONFIG.WAIT_FOR_EFFECTS)
		if FeatureManager:GetFeatureState("effects") then
			self:HideCharacterEffects(character, true)
			self:HideLights(character, true)
			self:HideAuraEffects(character, true)
		end

		character.DescendantAdded:Connect(function(descendant)
			if FeatureManager:GetFeatureState("effects") then
				task.wait(0.1)
				Utils:HideEffect(descendant, true)
				Utils:HideLight(descendant, true)
			end
		end)

		character.ChildAdded:Connect(function(child)
			if Utils:IsAura(child) and FeatureManager:GetFeatureState("effects") then
				task.wait(CONFIG.WAIT_FOR_EFFECTS)
				Utils:HideBasePart(child, true)
				for _, descendant in pairs(child:GetDescendants()) do
					Utils:HideEffect(descendant, true)
					Utils:HideLight(descendant, true)
					Utils:HideBasePart(descendant, true)
				end
			end
		end)
	end
end

-- ============================================
-- EVENT: DETEKSI DONASI BARU DI WORKSPACE
-- ============================================
collectionService:GetInstanceAddedSignal("DonationEffect"):Connect(function(effect)
	-- Jika tombol Hide Effects sedang aktif, langsung lenyapkan!
	if FeatureManager:GetFeatureState("effects") then
		task.wait(0.1) -- Tunggu partikelnya menetas
		Utils:HideBasePart(effect, true)
		for _, desc in ipairs(effect:GetDescendants()) do
			Utils:HideEffect(desc, true)
			Utils:HideLight(desc, true)
			Utils:HideBasePart(desc, true)
		end
	end
end)

-- ============================================
-- PLAYER HIDE SYSTEM
-- ============================================
function PlayerHideSystem:HideObject(object, shouldHide)
	for _, descendant in pairs(object:GetDescendants()) do
		Utils:HideBasePart(descendant, shouldHide)
		Utils:HideEffect(descendant, shouldHide)
		Utils:HideLight(descendant, shouldHide)
		Utils:HideGui(descendant, shouldHide)
	end
end

function PlayerHideSystem:HideTools(otherPlayer, character, shouldHide)
	if otherPlayer.Backpack then
		for _, tool in pairs(otherPlayer.Backpack:GetChildren()) do
			if tool:IsA("Tool") then self:HideObject(tool, shouldHide) end
		end
	end
	for _, child in pairs(character:GetChildren()) do
		if child:IsA("Tool") then self:HideObject(child, shouldHide) end
	end
end

function PlayerHideSystem:SetPlayersVisible(visible)
	for _, otherPlayer in pairs(player:GetPlayers()) do
		if otherPlayer ~= localPlayer and otherPlayer.Character then
			local character = otherPlayer.Character
			self:HideObject(character, not visible)
			self:HideTools(otherPlayer, character, not visible)
			local head = character:FindFirstChild("Head")
			if head then OverheadSystem:HideOverheadGui(head, not visible) end
		end
	end
end

function PlayerHideSystem:OnCharacterAdded(character, otherPlayer)
	if otherPlayer ~= localPlayer then
		task.wait(CONFIG.WAIT_FOR_ACCESSORIES)
		if FeatureManager:GetFeatureState("players") then
			self:HideObject(character, true)
			self:HideTools(otherPlayer, character, true)
			local head = character:FindFirstChild("Head")
			if head then OverheadSystem:HideOverheadGui(head, true) end
		end

		character.ChildAdded:Connect(function(child)
			if FeatureManager:GetFeatureState("players") then
				task.wait(CONFIG.WAIT_FOR_TOOLS)
				if child:IsA("Tool") or Utils:IsAura(child) then self:HideObject(child, true) end
			end
		end)

		if otherPlayer.Backpack then
			otherPlayer.Backpack.ChildAdded:Connect(function(child)
				if child:IsA("Tool") and FeatureManager:GetFeatureState("players") then
					task.wait(CONFIG.WAIT_FOR_TOOLS)
					self:HideObject(child, true)
				end
			end)
		end
	end
end

-- ============================================
-- INITIALIZE
-- ============================================
for _, featureConfig in ipairs(FEATURES) do
	FeatureManager:RegisterFeature(featureConfig)
end

for _, otherPlayer in pairs(player:GetPlayers()) do
	if otherPlayer.Character then FeatureManager:OnCharacterAdded(otherPlayer.Character, otherPlayer) end
	otherPlayer.CharacterAdded:Connect(function(character)
		FeatureManager:OnCharacterAdded(character, otherPlayer)
	end)
end

player.PlayerAdded:Connect(function(otherPlayer)
	otherPlayer.CharacterAdded:Connect(function(character)
		FeatureManager:OnCharacterAdded(character, otherPlayer)
	end)
end)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

-- ====================================
-- ⚙️ PENGATURAN DEBUG (ANTI-SPAM LOG)
-- ====================================
local DEBUG_ENABLED = false -- 🟢 UBAH KE 'true' JIKA INGIN MELIHAT LOG DI CONSOLE

local function debugLog(...)
	if DEBUG_ENABLED then
		print("[DEBUG UI CLIENT]", ...)
	end
end

-- ====================================
-- INISIALISASI UI
-- ====================================
local frame = script.Parent
local avatarImg = frame:WaitForChild("Avatar")
local nameLbl = frame:WaitForChild("NameLabel")
local descLbl = frame:WaitForChild("DescLabel")
local stroke = frame:FindFirstChildOfClass("UIStroke")

-- 1. SIMPAN TRANSPARANSI ASLI DARI STUDIO
local targets = {
	Frame = frame.BackgroundTransparency,
	Avatar = avatarImg.ImageTransparency,
	Name = nameLbl.TextTransparency,
	Desc = descLbl.TextTransparency,
	Stroke = stroke and stroke.Transparency or 0
}

-- 2. SEMBUNYIKAN GUI SAAT AWAL GAME DIMULAI
frame.BackgroundTransparency = 1
avatarImg.ImageTransparency = 1
nameLbl.TextTransparency = 1
descLbl.TextTransparency = 1
if stroke then stroke.Transparency = 1 end
frame.Visible = false

local NotifEvent = ReplicatedStorage:WaitForChild("SultanJoinNotifEvent")
local isPlaying = false
local queue = {}

local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-- FUNGSI UNTUK FADE IN / FADE OUT SEMUA ELEMEN
local function fade(isIn)
	local tweens = {}
	table.insert(tweens, TweenService:Create(frame, tweenInfo, {BackgroundTransparency = isIn and targets.Frame or 1}))
	table.insert(tweens, TweenService:Create(avatarImg, tweenInfo, {ImageTransparency = isIn and targets.Avatar or 1}))
	table.insert(tweens, TweenService:Create(nameLbl, tweenInfo, {TextTransparency = isIn and targets.Name or 1}))
	table.insert(tweens, TweenService:Create(descLbl, tweenInfo, {TextTransparency = isIn and targets.Desc or 1}))
	if stroke then
		table.insert(tweens, TweenService:Create(stroke, tweenInfo, {Transparency = isIn and targets.Stroke or 1}))
	end

	for _, t in ipairs(tweens) do t:Play() end
	return tweens[1] -- Mengembalikan satu tween untuk ditunggu selesai
end

local function playNextNotif()
	if #queue == 0 then
		isPlaying = false
		return
	end

	isPlaying = true
	local data = table.remove(queue, 1)

	-- Set Teks
	nameLbl.Text = data.PlayerName
	descLbl.Text = data.Message

	-- Coba ambil foto avatar (Headshot)
	task.spawn(function()
		local success, result = pcall(function()
			-- Langsung pakai UserId dari server, nggak perlu nyari pakai nama lagi! Jauh lebih cepat & aman.
			return Players:GetUserThumbnailAsync(data.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
		end)

		if success and result then
			avatarImg.Image = result
		else
			avatarImg.Image = "rbxasset://textures/ui/GuiImagePlaceholder.png"
		end
	end)

	-- FADE IN (MUNCUL)
	frame.Visible = true
	local tShow = fade(true)
	tShow.Completed:Wait()

	-- Tunggu 5 detik di layar
	task.wait(5)

	-- FADE OUT (HILANG)
	local tHide = fade(false)
	tHide.Completed:Wait()
	frame.Visible = false

	-- Lanjut ke antrean berikutnya (jika ada 2 sultan join)
	task.wait(0.5)
	playNextNotif()
end

NotifEvent.OnClientEvent:Connect(function(data)
	debugLog("📥 Sinyal notifikasi diterima untuk:", data.PlayerName)
	table.insert(queue, data)
	if not isPlaying then
		playNextNotif()
	end
end)

aman semua ini?, ini semua script ini ada di dalam stater gui