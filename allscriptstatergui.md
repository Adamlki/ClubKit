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
local frame        = mainframe:WaitForChild("Frame") 
local textbox      = mainframe:WaitForChild("TextBox") 
local serverBtn    = frame:WaitForChild("ServerBtn")
local globalBtn    = frame:WaitForChild("GlobalBtn")
local closeBtn     = mainframe:WaitForChild("CloseBtn") 
local messageFrame = gui:WaitForChild("MessageFrame")

local templateNotif = messageFrame:Clone()
templateNotif.Parent  = nil
templateNotif.Visible = false

-- ====================================
-- CONFIG (dari ModuleScript)
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
local isSending = false  

-- ====================================
-- SAFE INVOKE UTILITY (ANTI-FREEZE)
-- ====================================
local function SafeInvoke(remote, timeout, ...)
	local args = {...}
	local finished = false
	local success = false
	local data = nil

	task.spawn(function()
		local ok, result = pcall(function()
			return remote:InvokeServer(unpack(args))
		end)
		success = ok
		data = result
		finished = true
	end)

	local elapsed = 0
	while not finished and elapsed < timeout do
		elapsed = elapsed + task.wait()
	end

	return finished and success, data
end

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

-- 🔥 SECURITY FIX: Fungsi untuk membersihkan teks HTML berbahaya
local function sanitizeHtml(text)
	text = tostring(text)
	text = text:gsub("&", "&amp;")
	text = text:gsub("<", "&lt;")
	text = text:gsub(">", "&gt;")
	text = text:gsub('"', "&quot;")
	text = text:gsub("'", "&apos;")
	return text
end

-- ====================================
-- TIMER FUNCTIONS
-- ====================================
local function showTimerNotification(remainingTime)
	if not Config.Timer.ShowNotification then return end

	-- 🔥 ARCHITECT FIX: Ganti tick() ke os.clock()
	local now = os.clock()
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
	task.spawn(function()
		local ok, result = SafeInvoke(CheckTimerRemote, 3) 
		if ok and result then
			timerData.HasTimer      = result.HasTimer
			timerData.RemainingTime = result.RemainingTime
			timerData.TimerDuration = result.TimerDuration
		end
	end)
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
	for i, data in ipairs(activeNotifications) do
		if data == notifData then
			table.remove(activeNotifications, i)
			break
		end
	end

	local fadeInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

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
	-- 🔥 ARCHITECT FIX: Iterasi mundur (backward) agar table.remove tidak menyebabkan skip
	for i = #activeNotifications, 1, -1 do
		local notifData = activeNotifications[i]

		if i > Config.Notification.MaxVisible then
			if notifData.Frame and notifData.Frame.Parent then
				notifData.Frame:Destroy()
			end
			table.remove(activeNotifications, i)
		elseif i > 1 then
			local orig    = notifData.OriginalPosition
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
-- NOTIFICATION CREATION
-- ====================================
local function createNotification(messageData)
	setupNotificationContainer()

	local notif = templateNotif:Clone()
	notif.Parent  = notificationContainer

	local originalPos = notif.Position
	notif.Position = UDim2.new(2, 0, 2, 0)
	notif.Visible = true 

	local messageLabel = notif:FindFirstChild("Message")
	local verifIcon = messageLabel and messageLabel:FindFirstChild("VerifiedBadge")

	if messageLabel and verifIcon then
		messageLabel.RichText = true

		local rawMessage = messageData.Message or ""
		local cleanMessage = string.gsub(rawMessage, "%[[Gg][Ll][Oo][Bb][Aa][Ll]%]%s*:?%s*", "")

		-- 🔥 SECURITY FIX: Proteksi RichText dari injeksi `<>`
		local safeSenderName = sanitizeHtml(messageData.SenderName or "Unknown")
		local safeMessage = sanitizeHtml(cleanMessage)

		messageLabel.Text = "<b>" .. safeSenderName .. "</b>"
		task.wait()

		local nameWidth = messageLabel.TextBounds.X
		local lineHeight = messageLabel.TextBounds.Y

		local iconWidth = 15
		verifIcon.BackgroundTransparency = 1
		verifIcon.Size = UDim2.new(0, iconWidth, 0, iconWidth)
		verifIcon.AnchorPoint = Vector2.new(0, 0)

		local yOffset = (lineHeight - iconWidth) / 2

		verifIcon.Position = UDim2.new(0, nameWidth + 4, 0, yOffset)
		verifIcon.Visible = true

		local emptySpaces = "     " 
		messageLabel.Text = string.format('<font color="#FFD700"><b>%s</b></font>%s: %s', safeSenderName, emptySpaces, safeMessage)
	end

	notif.Position = UDim2.new(originalPos.X.Scale, originalPos.X.Offset, -0.25, 0)

	local notifData = {
		Frame           = notif,
		OriginalPosition = originalPos,
		-- 🔥 ARCHITECT FIX: Ganti tick() ke os.clock()
		Timestamp       = os.clock(),
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

	SendMessageRemote:FireServer(message, isGlobal)

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
mainframe.Visible = false  

serverBtn.MouseButton1Click:Connect(function()
	sendMessage(false)
end)

globalBtn.MouseButton1Click:Connect(function()
	sendMessage(true)
end)

textbox.FocusLost:Connect(function(enterPressed)
	if enterPressed then
		sendMessage(false)
	end
end)

-- 🔥 FUNCTION FIX: Hidupkan Tombol Close agar UI bisa ditutup
if closeBtn then
	closeBtn.MouseButton1Click:Connect(function()
		mainframe.Visible = false
	end)
end

-- ====================================
-- RECEIVE MESSAGE FROM SERVER
-- ====================================
ReceiveMessageRemote.OnClientEvent:Connect(function(messageData)
	if type(messageData) ~= "table" then return end

	if messageData.Type == "Error" then
		pcall(function()
			SG:SetCore("SendNotification", {
				Title    = "Broadcast Error",
				Text     = messageData.Message or "An unknown error occurred.",
				Duration = 4
			})
		end)

		local msg = messageData.Message or ""
		if msg:find("wait") or msg:find("broadcast") or msg:find("minute") or msg:find("second") then
			refreshTimerData()
		end

	elseif messageData.Type == "Message" then
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

	ADMIN_ICON_IMAGE     = "rbxassetid://87144040887420",
	ADMIN_ICON_LABEL     = "",
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
local Teams             = game:GetService("Teams")

local LocalPlayer = Players.LocalPlayer

-- ====================================
-- MODULE ANIMASI UI
-- ====================================
local UIAnimator = require(ReplicatedStorage:WaitForChild("UIAnimator"))

-- ====================================
-- SAFE INVOKE UTILITY (ANTI-FREEZE)
-- ====================================
local function SafeInvoke(remote, timeout, ...)
	local args = {...}
	local finished = false
	local success = false
	local data = nil

	task.spawn(function()
		local ok, result = pcall(function()
			return remote:InvokeServer(unpack(args))
		end)
		success = ok
		data = result
		finished = true
	end)

	local elapsed = 0
	while not finished and elapsed < timeout do
		elapsed = elapsed + task.wait()
	end

	return finished and success, data
end

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

	-- Membuka Notification Frame dengan Animasi
	UIAnimator.Open(notificationframe)

	task.delay(3, function()
		if notificationframe.Visible then
			UIAnimator.Close(notificationframe)
		end
	end)
end

-- ====================================
-- TAB SWITCHING
-- ====================================
local function switchTab(tab)
	currentTab = tab

	-- Tutup semua frame tab secara instan agar tidak tumpang tindih
	roleframe.Visible  = false
	titleframe.Visible = false
	teamframe.Visible  = false

	-- Buka frame tab yang dipilih dengan animasi pop-up
	if tab == "Role" then
		UIAnimator.Open(roleframe)
	elseif tab == "Title" then
		UIAnimator.Open(titleframe)
	elseif tab == "Team" then
		UIAnimator.Open(teamframe)
	end

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

	local roleVal = target:FindFirstChild("Role")
	local roleName = roleVal and roleVal.Value or "Player"

	if roleName ~= "Player" and target.Team then
		playername.TextColor3 = target.Team.TeamColor.Color
	else
		playername.TextColor3 = Color3.fromRGB(255, 255, 255) 
	end

	-- 🔥 FIX UI FREEZE: Download gambar secara Asynchronous (Latar Belakang)
	task.spawn(function()
		local ok, thumbUrl = pcall(function()
			return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
		end)

		-- Pastikan admin tidak keburu klik player lain saat gambar sedang loading
		if selectedUserId == userId and ok and thumbUrl then 
			playerimage.Image = thumbUrl 
		end
	end)

	rolelabel.Text = "Role: " .. roleName
	teamlabel.Text = "Team: "..(target.Team and target.Team.Name or "-")
	titlelabel.Text = "Title: Loading..."

	task.spawn(function()
		local ok2, data = SafeInvoke(GetPlayerDataRemote, 3, target)
		if selectedUserId ~= userId then return end
		titlelabel.Text = (ok2 and data) and "Title: "..(data.Title ~= "" and data.Title or "-") or "Title: -"
	end)
end


-- ====================================
-- PLAYER LIST
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

		local nameColor = Color3.fromRGB(255, 255, 255) 
		local roleVal = plr:FindFirstChild("Role")
		local roleName = roleVal and roleVal.Value or "Player"

		if roleName ~= "Player" and plr.Team then
			nameColor = plr.Team.TeamColor.Color
		end

		if existingBtn then
			if isVisible then
				existingBtn.Position = UDim2.new(0, 0, 0, yOffset)
				existingBtn.Visible  = true
				existingBtn.Text = (plr == LocalPlayer) and (plr.DisplayName.." (Saya)") or plr.DisplayName
				existingBtn.TextColor3 = nameColor 
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
				newBtn.TextColor3 = nameColor 
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
-- COLOR PRESET SYSTEM
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

		newBtn.BackgroundColor3 = preset.color
		local brightness = (preset.color.R + preset.color.G + preset.color.B)
		newBtn.TextColor3 = brightness < 1.5 and Color3.new(1, 1, 1) or Color3.new(0, 0, 0)

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
	local targetPlayer = Players:GetPlayerByUserId(userId)
	if not targetPlayer then return end

	titleconfirmBtn.Text = "Loading..."
	task.spawn(function()
		local ok, data = SafeInvoke(GetPlayerDataRemote, 3, targetPlayer)
		if selectedUserId ~= userId then return end

		titleconfirmBtn.Text = "Confirm"
		if not ok or not data then return end

		entrytitlebox.Text = data.Title or ""
		local color = data.Color or { R=255, G=255, B=255 }
		redbox.Text   = tostring(color.R)
		greenbox.Text = tostring(color.G)
		bluebox.Text  = tostring(color.B)

		updateColorPreview()
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
end

redbox:GetPropertyChangedSignal("Text"):Connect(updateColorPreview)
greenbox:GetPropertyChangedSignal("Text"):Connect(updateColorPreview)
bluebox:GetPropertyChangedSignal("Text"):Connect(updateColorPreview)

local isProcessingTitle = false

titleconfirmBtn.MouseButton1Click:Connect(function()
	if not selectedUserId then showNotification("Pilih player terlebih dahulu!", false); return end
	if isProcessingTitle then return end 

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

	isProcessingTitle = true
	UpdateTitleRemote:FireServer(targetPlayer, {
		Title          = titleText,
		Color          = Color3.fromRGB(validateRGB(redbox.Text), validateRGB(greenbox.Text), validateRGB(bluebox.Text)),
	})

	titleconfirmBtn.Text = "Processing..."
	task.wait(0.5)
	titleconfirmBtn.Text = "Confirm"
	isProcessingTitle = false

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
		local ok, templates = SafeInvoke(GetColorTemplatesRemote, 3)
		if ok and type(templates) == "table" and #templates > 0 then
			buildColorTemplates(templates)
		else
			colorTemplatesLoaded = false 
			debugWarn("Failed to load color templates")
		end
	end)
end

local function buildTeamList()
	task.spawn(function()
		local ok, teamList = SafeInvoke(GetTeamListRemote, 3)
		if not ok or type(teamList) ~= "table" then return end

		for _, btn in pairs(teamButtons) do if btn and btn.Parent then btn:Destroy() end end
		teamButtons      = {}
		selectedTeamName = nil

		local yOffset = 0
		for _, teamData in ipairs(teamList) do
			local newBtn    = teamtemplateBtn:Clone()
			newBtn.Name     = "TeamBtn_"..teamData.name
			newBtn.Text     = teamData.isCustom and ("[Custom] "..teamData.name) or teamData.name
			newBtn.Position = UDim2.new(0, 0, 0, yOffset)
			newBtn.Visible  = true

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
			-- Panggil deselect otomatis menutup dan memainkan animasi
			adminIcon:deselect()
		end
	end
end

-- ====================================
-- OPEN / CLOSE (MENGGUNAKAN UIANIMATOR)
-- ====================================
local function openPanel()
	if not hasAccess then return end
	UIAnimator.Open(mainframe) -- Animasi Buka
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

adminIcon:bindEvent("selected", function()
	if not hasAccess then adminIcon:deselect(); return end
	openPanel()
end)

adminIcon:bindEvent("deselected", function()
	UIAnimator.Close(mainframe) -- Animasi Tutup
	selectedUserId    = nil
	resetTitleForm()
	resetRoleForm()
end)

-- Mengklik CloseBtn akan mendeselect Topbar, yang otomatis memicu animasi tutup di atas
closeBtn.MouseButton1Click:Connect(function() 
	adminIcon:deselect() 
end)

roleBtn.MouseButton1Click:Connect(function()  switchTab("Role")  end)
titleBtn.MouseButton1Click:Connect(function() switchTab("Title") end)
teamBtn.MouseButton1Click:Connect(function()
	switchTab("Team")
	buildTeamList()
	loadColorTemplates()
end)

local searchDebounce = nil

searchbox:GetPropertyChangedSignal("Text"):Connect(function()
	if searchDebounce then
		task.cancel(searchDebounce)
	end
	searchDebounce = task.delay(0.3, function()
		if not isRefreshing then 
			refreshPlayerList() 
		end
	end)
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
			adminIcon:deselect() -- Tutup dengan animasi setelah sukses
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

-- 🔥 FIX: Hindari Busy Waiting! Gunakan event bawaan Roblox
if not player.Character then
	player.CharacterAdded:Wait()
end

local CarryConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("CarryConfig"))

-- 🔥 INTEGRASI MODULE ANIMASI
local UIAnimator  = require(ReplicatedStorage:WaitForChild("UIAnimator"))

local remoteFolder = ReplicatedStorage:WaitForChild(CarryConfig.REMOTE_FOLDER, 10)
if not remoteFolder then
	warn("[CARRY UI] Remote folder not found!")
	return
end

local RequestRemote  = remoteFolder:WaitForChild("CarryRequest", 10)
local ResponseRemote = remoteFolder:WaitForChild("CarryResponse", 10)
local EndRemote      = remoteFolder:WaitForChild("CarryEnd", 10)

if not RequestRemote or not ResponseRemote or not EndRemote then
	warn("[CARRY UI] Gagal memuat Remote! Sinyal terlalu lambat atau folder tidak ada.")
	return
end

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
local loadedAnimationsCache = {} 
local jumpBlockConn     = nil

-- ============================================
-- ANIMATION
-- ============================================

local function getHumanoid()
	return player.Character and player.Character:FindFirstChildOfClass("Humanoid")
end

local function stopAllAnimations()
	for role, track in pairs(currentAnimTracks) do
		if track then
			if track.IsPlaying then
				track:Stop(0.2)
			end
			-- Hancurkan track setelah berhenti agar memori selalu fresh
			task.delay(0.25, function() pcall(function() track:Destroy() end) end)
		end
		currentAnimTracks[role] = nil
	end
	-- Kosongkan juga cache agar dibuat ulang setiap kali digendong (opsional)
	loadedAnimationsCache = {}
end


local function playAnimation(style, role)
	local hum = getHumanoid()
	if not hum then return end

	local animator = hum:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = hum
	end

	if currentAnimTracks[role] then
		currentAnimTracks[role]:Stop(0.15)
	end

	local animId = CarryConfig.getAnimationId(style, role)
	if animId == 0 then
		CarryConfig.debugPrint("ANIM", "No animation for", style, role)
		return
	end

	local track = loadedAnimationsCache[animId]

	if not track then
		local anim = Instance.new("Animation")
		anim.AnimationId = "rbxassetid://" .. tostring(animId)

		local success, newTrack = pcall(function()
			return animator:LoadAnimation(anim)
		end)

		if success and newTrack then
			track = newTrack
			loadedAnimationsCache[animId] = track 
		else
			warn("[CARRY UI] Failed to load animation:", animId)
			return
		end
	end

	if track then
		track.Priority = Enum.AnimationPriority.Action
		track.Looped = true
		track:Play(0.2)
		currentAnimTracks[role] = track
		CarryConfig.debugPrint("ANIM", "Playing", style, role, animId)
	end
end

-- ============================================
-- UI STATE FUNCTIONS
-- ============================================

local function hideAllFrames()
	-- Fitur reset instan tanpa perlu memutar animasi mengecil
	mainFrame.Visible = false
	notificationFrame.Visible = false
	getDownBtn.Visible = false
end

local function cleanupState()
	selectedTarget = nil
	pendingCarrier = nil
	pendingStyle   = nil
	styleTimeoutToken = styleTimeoutToken + 1
	stopAllAnimations()
end

local function showStyleSelection(target)
	if not target or not target:IsA("Player") then return end
	if not mainFrame or not mainFrame.Parent then return end

	currentState  = "selecting_style"
	selectedTarget = target

	hideAllFrames()
	task.wait(0.05)
	UIAnimator.Open(mainFrame)

	local myToken = styleTimeoutToken + 1
	styleTimeoutToken = myToken

	task.delay(CarryConfig.REQUEST_TIMEOUT, function()
		if styleTimeoutToken == myToken and currentState == "selecting_style" then
			UIAnimator.Close(mainFrame, function()
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
	UIAnimator.Open(notificationFrame)
end

local function showGetDownButton()
	currentState = "being_carried"

	hideAllFrames()
	task.wait(0.05)
	UIAnimator.Open(getDownBtn)

	if not jumpBlockConn then
		jumpBlockConn = UserInputService.JumpRequest:Connect(function()
			local hum = getHumanoid()
			if hum then hum.Jump = false end
		end)
	end
end

local function hideGetDownButton()
	UIAnimator.Close(getDownBtn)

	if jumpBlockConn then
		jumpBlockConn:Disconnect()
		jumpBlockConn = nil
	end
end

-- ============================================
-- STYLE BUTTON HANDLERS
-- ============================================

local function handleStyleSelection(styleName)
	if currentState ~= "selecting_style" or not selectedTarget then return end
	if not CarryConfig.isValidStyle(styleName) then return end

	UIAnimator.Close(mainFrame)

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

	UIAnimator.Close(notificationFrame)
	ResponseRemote:FireServer({ cmd = "AcceptCarry" })
	currentState = "waiting"
end)

rejectBtn.MouseButton1Click:Connect(function()
	if currentState ~= "pending_response" or not pendingCarrier then return end

	UIAnimator.Close(notificationFrame, function()
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
		UIAnimator.Open(getDownBtn)
		playAnimation(data.style, "carrier")

	elseif cmd == "BeingCarried" then
		showGetDownButton()
		playAnimation(data.style, "carried")

	elseif cmd == "RequestExpired" or cmd == "RequestFailed" then
		UIAnimator.Close(mainFrame, function()
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
		UIAnimator.Close(notificationFrame, function()
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
		if not target or not target:IsA("Player") then return end
		if not player.Character or not target.Character then return end

		local myHRP     = player.Character:FindFirstChild("HumanoidRootPart")
		local targetHRP = target.Character:FindFirstChild("HumanoidRootPart")

		if not myHRP or not targetHRP then return end
		if (myHRP.Position - targetHRP.Position).Magnitude > CarryConfig.MAX_DISTANCE then return end

		if currentState == "idle" or currentState == "selecting_style" then
			showStyleSelection(target)
		elseif currentState == "waiting" then
			cleanupState()
			currentState = "idle"
			task.wait(0.1)
			showStyleSelection(target)
		end
	end)
end

carryEventConnection = setupCarryEventListener()

-- ============================================
-- DEBUG: Test button
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
		UIAnimator.Open(mainFrame)
	end)
end

-- ============================================
-- RESPAWN HANDLING (OPTIMIZED & MEMORY LEAK FIXED)
-- ============================================

player.CharacterAdded:Connect(function()
	hideAllFrames()
	cleanupState()
	currentState = "idle"

	-- 🔥 FIX MEMORY LEAK: Hancurkan sisa animasi lama dari Engine Roblox
	if loadedAnimationsCache then
		for _, track in pairs(loadedAnimationsCache) do
			pcall(function() track:Destroy() end)
		end
	end

	loadedAnimationsCache = {}
	currentAnimTracks = {}

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
	else
		if leavingPlayer == selectedTarget or leavingPlayer.UserId == pendingCarrier then
			hideAllFrames()
			cleanupState()
			currentState = "idle"

			pcall(function()
				game.StarterGui:SetCore("SendNotification", {
					Title = "Carry Cancelled",
					Text  = (leavingPlayer.Name .. " has left the game."),
					Duration = 3,
				})
			end)
		end
	end
end)

-- ============================================
-- INITIALIZATION
-- ============================================

hideAllFrames()
CarryConfig.debugPrint("UI", "Carry UI Initialized")


-- services
local StarterGui = game:GetService("StarterGui")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")

-- references
local player = game:GetService("Players").LocalPlayer
local backpack = player:WaitForChild("Backpack")
local camera = workspace.CurrentCamera

-- DISABLE BASIC ROBLOX HOTBAR
StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)

local CustomInventoryGUI = script.Parent
local hotBar = CustomInventoryGUI.hotBar
local Inventory = CustomInventoryGUI.Inventory
local toolButton = script.toolButton

local inventoryHandler = require(script.SETTINGS)

local function showSlots()
	for index = 1, inventoryHandler.slotAmount do
		local toolObject = inventoryHandler.OBJECTS.HotBar[index]
		if not toolObject and not hotBar:FindFirstChild(index) and index <= inventoryHandler.slotAmount then
			local frame = toolButton:Clone()
			frame.toolName.Text = ""
			frame.toolAmount.Text = ""
			frame.toolNumber.Text = index
			frame.Name = index
			frame.Parent = hotBar
		end
	end
end

local function removeEmptySlots()
	for index = 1, 9 do
		local toolObject = inventoryHandler.OBJECTS.HotBar[index]
		local toolFrame = hotBar:FindFirstChild(index)

		-- 🔥 Cukup gunakan Destroy tanpa memanggil fungsi berulang
		if not toolObject and toolFrame then
			toolFrame:Destroy()
		end
	end

	-- Pastikan slot backpack selalu ada setelah pembersihan
	if not hotBar:FindFirstChild("backpackSlot") then
		local frame = toolButton:Clone()
		frame.Name = "backpackSlot"
		frame.toolName.Text = ""
		frame.toolAmount.Text = ""
		frame.toolNumber.Text = ""
		frame.toolIcon.Image = "rbxassetid://135273755533681"
		frame.toolIcon.Visible = true
		frame.toolName.Visible = false
		frame.LayoutOrder = 0
		frame.Parent = hotBar
	end
end


-- Fungsi untuk membuat slot backpack permanen di hotbar
local function createBackpackSlot()
	-- Hapus jika sudah ada agar tidak duplikat
	local existing = hotBar:FindFirstChild("backpackSlot")
	if existing then existing:Destroy() end

	local frame = toolButton:Clone()
	frame.Name = "backpackSlot"
	frame.toolName.Text = ""
	frame.toolAmount.Text = ""
	frame.toolNumber.Text = "" -- tidak tampilkan nomor slot
	frame.toolIcon.Image = "rbxassetid://135273755533681"
	frame.toolIcon.Visible = true
	frame.toolName.Visible = false
	frame.LayoutOrder = 0 -- selalu paling pertama/kiri
	frame.Parent = hotBar

	-- Klik = toggle buka/tutup inventory (sama seperti tekan `)
	frame.MouseButton1Down:Connect(function()
		Inventory.Visible = not Inventory.Visible
		local currentState = Inventory.Visible

		inventoryHandler:removeCurrentDescription()
		if currentState then
			showSlots()
			CustomInventoryGUI.openButton.Position = UDim2.fromScale(0.5, 0.5)
			CustomInventoryGUI.openButton.info.Text = " "
		else
			if not inventoryHandler.SETTINGS.SHOW_EMPTY_TOOL_FRAMES_IN_HOTBAR then
				removeEmptySlots()
			end
			CustomInventoryGUI.openButton.Position = UDim2.fromScale(0.5, 0.909)
			CustomInventoryGUI.openButton.info.Text = " "
		end
	end)
end

local function manageInventory (_, inputState)
	if inputState == Enum.UserInputState.Begin then
		Inventory.Visible = not Inventory.Visible
		local currentState = Inventory.Visible

		inventoryHandler:removeCurrentDescription()
		if currentState then
			showSlots()
			CustomInventoryGUI.openButton.Position = UDim2.fromScale(0.5,0.5)
			CustomInventoryGUI.openButton.info.Text = " "
		else
			if not inventoryHandler.SETTINGS.SHOW_EMPTY_TOOL_FRAMES_IN_HOTBAR then
				removeEmptySlots()
			end
			CustomInventoryGUI.openButton.Position = UDim2.fromScale(0.5,0.909)
			CustomInventoryGUI.openButton.info.Text = " "
		end
	elseif not inputState then
		for index = inventoryHandler.slotAmount + 1, inventoryHandler.slotAmount do
			local toolObject = inventoryHandler.OBJECTS.HotBar[index]
			local toolFrame = hotBar:FindFirstChild(index)
			if toolObject then
				local tool = toolObject.Tool
				toolObject:DisconnectAll()
				tool:SetAttribute("toolAdded", nil)
				inventoryHandler:newTool(tool)
			elseif toolFrame then
				toolFrame:Destroy()
			end
		end
	end
end

local function searchTool()
	inventoryHandler:searchTool()
end
local function newTool(tool)
	if tool:IsA("Tool") then
		inventoryHandler:newTool(tool)
	end
end

local function reloadInventory(character)
	inventoryHandler.currentlyEquipped = nil
	backpack = player:WaitForChild("Backpack")

	for _, tool in pairs(backpack:GetChildren()) do
		if tool:IsA("Tool") then
			newTool(tool)
		end
	end
	backpack.ChildAdded:Connect(newTool)
	character.ChildAdded:Connect(newTool)
end

local function updateHudPosition()
	local viewPortSize = camera.ViewportSize
	local slotSize = UDim2.fromOffset(hotBar.AbsoluteSize.Y, hotBar.AbsoluteSize.Y)

	Inventory.Frame.Grid.CellSize = slotSize
	hotBar.Grid.CellSize = slotSize

	manageInventory()
end

updateHudPosition(); updateHudPosition()
createBackpackSlot() -- buat slot backpack permanen
reloadInventory(player.Character or player.CharacterAdded:task.wait())
camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateHudPosition)
player.CharacterAdded:Connect(reloadInventory)
Inventory.SearchBox:GetPropertyChangedSignal("Text"):Connect(searchTool)
if inventoryHandler.SETTINGS.SHOW_EMPTY_TOOL_FRAMES_IN_HOTBAR then showSlots() end
if inventoryHandler.SETTINGS.INVENTORY_KEYBIND then ContextActionService:BindAction("manageInventory", manageInventory, false, inventoryHandler.SETTINGS.INVENTORY_KEYBIND) end
if inventoryHandler.SETTINGS.OPEN_BUTTON then
	CustomInventoryGUI.openButton.MouseButton1Down:Connect(function()
		Inventory.Visible = not Inventory.Visible
		local currentState = Inventory.Visible

		inventoryHandler:removeCurrentDescription()
		if currentState then
			showSlots()
			CustomInventoryGUI.openButton.Position = UDim2.fromScale(0.5,0.5)
			CustomInventoryGUI.openButton.info.Text = " "
		else
			if not inventoryHandler.SETTINGS.SHOW_EMPTY_TOOL_FRAMES_IN_HOTBAR then
				removeEmptySlots()
			end
			CustomInventoryGUI.openButton.Position = UDim2.fromScale(0.5,0.909)
			CustomInventoryGUI.openButton.info.Text = " "
		end
	end)
else
	CustomInventoryGUI.openButton.Visible = false
end

local function getToolEquipped()
	local character = player.Character
	return character and character:FindFirstChildOfClass("Tool")
end

UserInputService.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseWheel and inventoryHandler.SETTINGS.SCROLL_HOTBAR_WITH_WHEEL then
		local direction = input.Position.Z
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")

		local toolEquipped = getToolEquipped()
		local toolPosition = inventoryHandler:getToolPosition(toolEquipped) or 0

		for i=toolPosition + direction, direction < 0 and 1 or inventoryHandler.slotAmount, direction do
			local toolObject = inventoryHandler.OBJECTS.HotBar[i]
			if toolObject and humanoid then
				humanoid:EquipTool(toolObject.Tool)
				break
			end
		end
	end
end)

local module = {OBJECTS = {}, SETTINGS = {}, slotAmount = 5}
module.OBJECTS.HotBar = {}
module.OBJECTS.Inventory = {}

-- SETTINGS
local SETTINGS = module.SETTINGS
SETTINGS.DEFAULT_COLOR = Color3.fromRGB(0, 0, 0)
SETTINGS.EQUIPPED_COLOR = Color3.fromRGB(128, 128, 128)
SETTINGS.DISABLED_COLOR = Color3.fromRGB(128, 64, 65)
SETTINGS.DEFAULT_IMAGEID = ""
SETTINGS.EQUIPPED_IMAGEID = ""
SETTINGS.DISABLED_IMAGEID = ""
SETTINGS.BACKPACK_BUTTON_IMAGEID = "rbxassetid://135273755533681"
SETTINGS.INVENTORY_KEYBIND = Enum.KeyCode.Backquote
SETTINGS.DRAG_OUTSIDE_TO_DROP = false
SETTINGS.SHOW_EMPTY_TOOL_FRAMES_IN_HOTBAR = false
SETTINGS.SCROLL_HOTBAR_WITH_WHEEL = false
SETTINGS.EQUIP_TOUCH_SENSITIVITY = 60
SETTINGS.OPEN_BUTTON = true
SETTINGS.ALWAYS_SHOW_TOOL_NAME = true

-- services
local ContextActionService = game:GetService("ContextActionService")
local TextService = game:GetService("TextService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

--// PLAYER
local player = game:GetService("Players").LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local mouse = player:GetMouse()

--// INVENTORY_SYSTEM \\--
local inventoryGui = script.Parent.Parent
local hotbar = inventoryGui.hotBar
local inventoryFrame = inventoryGui.Inventory
local toolButton = script.Parent.toolButton

local EnumKeys = {
	Enum.KeyCode.One,
	Enum.KeyCode.Two,
	Enum.KeyCode.Three,
	Enum.KeyCode.Four,
	Enum.KeyCode.Five,
	Enum.KeyCode.Six,
	Enum.KeyCode.Seven,
	Enum.KeyCode.Eight,
	Enum.KeyCode.Nine,
}

-- tool object methods
local toolObjectMetatable = {}
toolObjectMetatable.__index = toolObjectMetatable

function toolObjectMetatable:isEquipped()
	local character = player.Character
	if character then
		return self.Tool.Parent == player.Character
	else
		return false
	end
end

function toolObjectMetatable:DisconnectAll()
	for _, v in pairs(self.CONNECTIONS) do
		v:Disconnect()
	end

	self.didRemoval = true

	if (inventoryFrame.Visible or module.SETTINGS.SHOW_EMPTY_TOOL_FRAMES_IN_HOTBAR) and self.Frame.Parent ~= inventoryGui and self.Frame.Parent ~= inventoryFrame.Frame then
		local toolName   = self.Frame:FindFirstChild("toolName")
		local toolAmount = self.Frame:FindFirstChild("toolAmount")
		local toolIcon   = self.Frame:FindFirstChild("toolIcon")

		if toolName and toolAmount and toolIcon then
			toolName.Text   = ""
			toolAmount.Text = ""
			toolIcon.Image  = ""
		end
		self.Frame.BackgroundColor3 = SETTINGS.DEFAULT_COLOR
		self.Frame.Image            = SETTINGS.DEFAULT_IMAGEID
	else
		self.Frame:Destroy()
	end

	if self.Parent == "HotBar" and self.Position then
		ContextActionService:UnbindAction(self.Position .. "hotBar")
		module.OBJECTS.HotBar[self.Position] = nil
	elseif self.Parent == "Inventory" then
		module.OBJECTS.Inventory[self.Tool.Name] = nil
	end
	self = nil
end

function toolObjectMetatable:updateIcon()
	local tool      = self.Tool
	local frame     = self.Frame
	local textureId = tool.TextureId

	if textureId == "" or textureId == nil then
		frame.toolName.Visible  = true
		frame.toolIcon.Visible  = false
		frame.toolIcon.Image    = ""
	else
		frame.toolName.Visible  = SETTINGS.ALWAYS_SHOW_TOOL_NAME
		frame.toolIcon.Visible  = true
		frame.toolIcon.Image    = textureId
	end
end

function toolObjectMetatable:getParentInstance()
	return self.Parent == "Inventory" and inventoryFrame.Frame or hotbar
end

function toolObjectMetatable:showDescription()
	local toolDescription = self.Tool.ToolTip
	local frame           = self.Frame
	if toolDescription == "" then return end

	local descriptionFrame             = Instance.new("TextLabel")
	descriptionFrame.Name              = "descriptionFrame"
	descriptionFrame.AnchorPoint       = Vector2.new(0.5, 0)
	descriptionFrame.Font              = Enum.Font.SourceSansSemibold
	descriptionFrame.TextColor         = BrickColor.Black()
	descriptionFrame.TextSize          = 14
	descriptionFrame.BorderSizePixel   = 0
	descriptionFrame.BackgroundColor   = BrickColor.White()
	descriptionFrame.ZIndex            = 99
	descriptionFrame.TextWrapped       = true
	descriptionFrame.Parent            = inventoryGui

	local corner          = Instance.new("UICorner")
	corner.Parent         = descriptionFrame
	corner.CornerRadius   = UDim.new(0.12, 0)

	local textBounds      = TextService:GetTextSize(toolDescription, descriptionFrame.TextSize, descriptionFrame.Font, Vector2.new(400, 1000)) + Vector2.new(10, 4)
	descriptionFrame.Size = UDim2.new(0, textBounds.X, 0, textBounds.Y)
	descriptionFrame.Position = UDim2.new(0, frame.AbsolutePosition.X + (frame.AbsoluteSize.X / 2), 0, frame.AbsolutePosition.Y - textBounds.Y - 2 + 57)
	descriptionFrame.Text = toolDescription
	self.DescriptionFrame = descriptionFrame
	game:GetService("Debris"):AddItem(descriptionFrame, 15)
end

function toolObjectMetatable:removeDescription()
	if self.DescriptionFrame then
		self.DescriptionFrame:Destroy()
	end
end

function module:removeCurrentDescription()
	local descriptionFrame = inventoryGui:FindFirstChild("descriptionFrame")
	if descriptionFrame then
		descriptionFrame:Destroy()
	end
end

function module:getObjectFromTool(tool: Tool)
	local function searchToolObject(toolParent)
		for _, toolObject in pairs(toolParent) do
			if toolObject.Tool == tool then
				return toolObject
			end
		end
	end
	return searchToolObject(self.OBJECTS.HotBar) or searchToolObject(self.OBJECTS.Inventory)
end

function module:getToolPosition(tool: Tool)
	local toolObject = self:getObjectFromTool(tool)
	return toolObject and toolObject.Position
end

function module:searchTool()
	local toolName: string = inventoryFrame.SearchBox.Text
	if toolName == "" then
		for _, toolObject in pairs(self.OBJECTS["Inventory"]) do
			toolObject.Frame.Visible = true
		end
	elseif toolName then
		for _, toolObject in pairs(self.OBJECTS["Inventory"]) do
			toolObject.Frame.Visible = string.find(toolObject.Name:lower(), toolName:lower()) and true or false
		end
	end
end

function module:lockSlots(unequipCurrentTool: boolean)
	self.slotsLocked = true
	if unequipCurrentTool then
		local character = player.Character
		local humanoid  = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid:UnequipTools()
		end
	end
end

function module:unlockSlots()
	self.slotsLocked = false
end

function module:lockSlotsPosition()
	self.slotsPositionLocked = true
end

function module:unlockSlotsPosition()
	self.slotsPositionLocked = false
end

function module:newTool(tool: Tool)
	if tool:GetAttribute("toolAdded") or not tool:IsA("Tool") then return end

	local length = 0
	for _, _ in pairs(module.OBJECTS.HotBar) do
		length += 1
	end

	module:addTool(tool, length == self.slotAmount and "Inventory" or "HotBar", tool:GetAttribute("position"))
end

function module:addTool(tool: Tool, parent: string, position: number)
	tool:SetAttribute("position", nil)
	if position == -1 then
		parent   = "Inventory"
		position = nil
	end

	if not position and parent == "HotBar" then
		for index = 1, self.slotAmount do
			if self.OBJECTS.HotBar[index] == nil then
				position = index
				break
			end
		end
	end

	if position and hotbar:FindFirstChild(position) then
		hotbar:FindFirstChild(position):Destroy()
	end

	local frame  = toolButton:Clone()
	local amount = tool:GetAttribute("amount") or 1
	if amount > 1 then
		frame.toolAmount.Text = "x" .. amount
	end
	frame.toolName.Text = tool.Name
	frame.Parent        = parent == "Inventory" and inventoryFrame.Frame or hotbar
	frame.Name          = parent == "Inventory" and tool.Name or position
	frame.toolNumber.Text = parent == "Inventory" and "" or position

	local object = {}
	setmetatable(object, toolObjectMetatable)

	object.Tool     = tool
	object.Frame    = frame
	object.Parent   = parent
	object.Position = position
	object.Name     = tool.Name
	self.OBJECTS[parent][position == nil and frame.Name or position] = object

	local function manageTool(_, inputState, inputObject)
		if inputObject and inputObject.UserInputType ~= Enum.UserInputType.Keyboard and inputObject.UserInputType ~= Enum.UserInputType.Touch then
			return
		end

		local character = player.Character
		local humanoid  = character and character:FindFirstChildOfClass("Humanoid")
		if
			not humanoid
			or humanoid.Health <= 0
			or not tool.Parent
			or inputState == Enum.UserInputState.End
			or self.slotsLocked
		then
			return
		end

		if object:isEquipped() then
			humanoid:UnequipTools()
			frame.BackgroundColor3 = SETTINGS.DEFAULT_COLOR
			frame.Image            = SETTINGS.DEFAULT_IMAGEID
			module.currentlyEquipped = nil
		elseif tool.Enabled then
			humanoid:EquipTool(tool)
			if module.currentlyEquipped and module.currentlyEquipped.Parent then
				module.currentlyEquipped.BackgroundColor3 = SETTINGS.DEFAULT_COLOR
				module.currentlyEquipped.Image            = SETTINGS.DEFAULT_IMAGEID
			end
			module.currentlyEquipped  = frame
			frame.BackgroundColor3    = SETTINGS.EQUIPPED_COLOR
			frame.Image               = SETTINGS.EQUIPPED_IMAGEID
		end
	end

	local function updateEquipped()
		if object:isEquipped() and tool.Enabled then
			if module.currentlyEquipped and module.currentlyEquipped.Parent then
				module.currentlyEquipped.BackgroundColor3 = SETTINGS.DEFAULT_COLOR
				module.currentlyEquipped.Image            = SETTINGS.DEFAULT_IMAGEID
			end
			module.currentlyEquipped  = frame
			frame.BackgroundColor3    = SETTINGS.EQUIPPED_COLOR
			frame.Image               = SETTINGS.EQUIPPED_IMAGEID
		else
			frame.BackgroundColor3    = SETTINGS.DEFAULT_COLOR
			frame.Image               = SETTINGS.DEFAULT_IMAGEID
			module.currentlyEquipped  = nil
		end
	end

	-- UIStroke dihapus, dihandle manual di toolButton template
	local function updateEnabled()
		if tool.Enabled then
			frame.Image                    = SETTINGS.DEFAULT_IMAGEID
			frame.BackgroundColor3         = SETTINGS.DEFAULT_COLOR
			frame.ImageTransparency        = 0
			frame.toolIcon.ImageTransparency = 0
			frame.toolName.TextTransparency = 0
			frame.toolNumber.TextTransparency = 0
			frame.toolAmount.TextTransparency = 0
		else
			frame.Image                    = SETTINGS.DISABLED_IMAGEID
			frame.BackgroundColor3         = SETTINGS.DISABLED_COLOR
			frame.ImageTransparency        = 0.35
			frame.toolIcon.ImageTransparency = 0.5
			frame.toolName.TextTransparency = 0.6
			frame.toolNumber.TextTransparency = 0.6
			frame.toolAmount.TextTransparency = 0.6
		end
	end

	updateEnabled()
	updateEquipped()
	object:updateIcon()

	--// CONNECTIONS
	object.CONNECTIONS = {}
	object.CONNECTIONS.EnabledConn    = tool:GetPropertyChangedSignal("Enabled"):Connect(updateEnabled)
	object.CONNECTIONS.ToolRemoved    = tool.AncestryChanged:Connect(function(_, newParent)
		if player and (newParent == nil or (newParent ~= player.Backpack and newParent ~= player.Character)) then
			object:DisconnectAll()
			tool:SetAttribute("toolAdded", false)
		end
		updateEquipped()
	end)
	object.CONNECTIONS.NameChanged    = tool:GetPropertyChangedSignal("Name"):Connect(function()
		frame.toolName.Text = tool.Name
		object.Name         = tool.Name
	end)
	object.CONNECTIONS.TextureIdChanged = tool:GetPropertyChangedSignal("TextureId"):Connect(function()
		object:updateIcon()
	end)
	object.CONNECTIONS.AmountChanged  = tool:GetAttributeChangedSignal("amount"):Connect(function()
		amount = tool:GetAttribute("amount") or 1
		if amount > 1 then
			frame.toolAmount.Text = "x" .. amount
		else
			frame.toolAmount.Text = ""
		end
	end)
	object.CONNECTIONS.MouseEnter     = frame.MouseEnter:Connect(function()
		if object.isGrabbed then return end
		object:showDescription()
	end)
	object.CONNECTIONS.MouseLeave     = frame.MouseLeave:Connect(function()
		object:removeDescription()
	end)
	object.CONNECTIONS.GrabConn       = frame.MouseButton1Down:Connect(function()
		if self.slotsPositionLocked then return end

		local mouseEnd
		local mouseConn
		local newFrame
		local CellSize         = inventoryFrame.Frame.Grid.CellSize
		local frameStartPosition = frame.AbsolutePosition
		object:removeDescription()

		local function endGrab()
			mouseEnd:Disconnect()
			mouseConn:Disconnect()
			object.isGrabbed = false

			local droppedGuis = playerGui:GetGuiObjectsAtPosition(mouse.X, mouse.Y)
			local wasSwapped  = false
			local dropTool    = true

			for _, newSlot in pairs(droppedGuis) do
				if newSlot:IsA("ImageButton") and (newSlot.Parent == hotbar or newSlot.Parent == inventoryFrame.Frame) then
					-- Abaikan slot backpackSlot agar tidak bisa di-swap
					if newSlot.Name == "backpackSlot" then continue end

					local newSlotObject = self.OBJECTS[newSlot.Parent == hotbar and "HotBar" or "Inventory"][newSlot.Parent == hotbar and tonumber(newSlot.Name) or newSlot.Name]
					if newSlotObject == object then
						dropTool = false
						if newFrame then newFrame:Destroy() end
						continue
					end

					if newSlotObject then
						wasSwapped = true
						object:DisconnectAll()
						newSlotObject:DisconnectAll()
						self:addTool(newSlotObject.Tool, parent, position)
						self:addTool(tool, newSlotObject.Parent, newSlotObject.Position)
						if newFrame then newFrame:Destroy() end
					elseif newSlot.Parent == hotbar then
						wasSwapped = true
						object:DisconnectAll()
						self:addTool(tool, "HotBar", tonumber(newSlot.Name))
						if parent == "Inventory" and newFrame then newFrame:Destroy() end
						newSlot:Destroy()
					end

					if newSlotObject then newSlotObject:removeDescription() end
					if object then object:removeDescription() end

				elseif newSlot:IsA("ImageLabel") and newSlot == inventoryFrame and not wasSwapped and parent == "HotBar" then
					wasSwapped = true
					object:DisconnectAll()
					self:addTool(tool, "Inventory")
					self:searchTool()
					break
				end
			end

			if not wasSwapped then
				if newFrame then newFrame:Destroy() end
				frame.Parent = object:getParentInstance()

				if SETTINGS.DRAG_OUTSIDE_TO_DROP and dropTool and tool.CanBeDropped then
					local character = player.Character
					if character then
						tool.Parent = character
						RunService.RenderStepped:task.wait()
						tool.Parent = workspace
					end
				end

				if (frameStartPosition - Vector2.new(mouse.X, mouse.Y)).Magnitude <= SETTINGS.EQUIP_TOUCH_SENSITIVITY then
					manageTool()
				end
			end
		end

		mouseEnd = UserInputService.InputEnded:Connect(function(inputObject)
			if
				inputObject.UserInputType == Enum.UserInputType.MouseButton1
				or inputObject.UserInputType == Enum.UserInputType.Touch
			then
				endGrab()
			end
		end)

		local function updateFramePos()
			if not object.isGrabbed then
				object.isGrabbed = true
				newFrame              = toolButton:Clone()
				newFrame.toolName.Text  = ""
				newFrame.toolAmount.Text = ""
				newFrame.toolNumber.Text = position or ""
				newFrame.Name         = frame.Name
				newFrame.Size         = frame.Size
				newFrame.Parent       = object:getParentInstance()

				frame.Size   = CellSize
				frame.Parent = inventoryGui
			end

			local mousePos  = Vector2.new(mouse.X, mouse.Y)
			frame.Position  = UDim2.new(0, mousePos.X - (CellSize.X.Offset / 2), 0, mousePos.Y - (CellSize.Y.Offset / 2) + 57)
		end
		mouseConn = mouse.Move:Connect(updateFramePos)
	end)

	tool:SetAttribute("toolAdded", true)
	if parent == "HotBar" and position then
		ContextActionService:BindAction(position .. "hotBar", manageTool, false, EnumKeys[position])
	end
end

return module

local Players            = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local TweenService       = game:GetService("TweenService")

local ClientConfig = require(script:WaitForChild("ClientConfig"))
local ClientUI     = require(script:WaitForChild("ClientUI"))

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
	templateBtn       = gui:WaitForChild("MainFrame"):WaitForChild("Container"):WaitForChild("RobuxBtn"),
	saweriaFrame      = gui:WaitForChild("MainFrame"):WaitForChild("SawriaFrame"),
}

local saweriaTextBox = UI.saweriaFrame:WaitForChild("SaweriaTextBox")
local copyBtn        = UI.saweriaFrame:WaitForChild("CopyBtn")

-- ============================================
-- STATE
-- ============================================
local State = {
	productsLoaded       = false,
	isLoading            = false,
	isSending            = false,  
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
-- ANIMASI POP-UP
-- ============================================
local function openFrame(frame)
	frame.Visible = true

	-- Menggunakan UIScale untuk efek zoom
	local uiScale = frame:FindFirstChild("PopUpScale")
	if not uiScale then
		uiScale = Instance.new("UIScale")
		uiScale.Name = "PopUpScale"
		uiScale.Parent = frame
	end

	uiScale.Scale = 0
	-- EasingStyle.Back memberikan efek memantul sedikit saat muncul
	local tween = TweenService:Create(uiScale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1})
	tween:Play()
end

local function closeFrame(frame)
	local uiScale = frame:FindFirstChild("PopUpScale")
	if not uiScale then
		uiScale = Instance.new("UIScale")
		uiScale.Name = "PopUpScale"
		uiScale.Parent = frame
		uiScale.Scale = 1
	end

	local tween = TweenService:Create(uiScale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.In), {Scale = 0})
	tween:Play()

	tween.Completed:Once(function()
		frame.Visible = false
	end)
end

-- ============================================
-- PRODUCT UI
-- ============================================

local loadProducts
local createProductButton
local clearProducts

createProductButton = function(productData)
	local btn = UI.templateBtn:Clone()
	btn.Name    = "Product_" .. productData.Id
	btn.Visible = true
	btn.Parent  = UI.container

	btn.Text  = "R$ " .. ClientUI.formatNumber(productData.Price)

	-- Hover effect sengaja tidak pakai Transparency agar tidak jadi hitam 
	-- (Bisa pakai properti AutoButtonColor bawaan Studio)

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

	table.insert(State.currentButtons, btn)
	return btn
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
		for _, product in ipairs(products) do
			createProductButton(product)
			task.wait(ClientConfig.UI.BUTTON_CREATE_DELAY)
		end

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
	:setImage("rbxassetid://83429307848166")
	:setOrder(3)
	:setRight()
	:bindEvent("selected", function()
		openFrame(UI.mainFrame) -- Menggunakan animasi pop up
		debugLog("Donation UI dibuka via TopbarPlus")
		if not State.productsLoaded and not State.isLoading then
			task.spawn(loadProducts)
		end
	end)
	:bindEvent("deselected", function()
		closeFrame(UI.mainFrame) -- Menggunakan animasi pop up
		debugLog("Donation UI ditutup via TopbarPlus")
	end)

-- ============================================
-- MESSAGE UI
-- ============================================

local function showMessageFrame(amount)
	State.lastPurchasedAmount = amount
	State.canSendMessage      = true

	donationIcon:deselect() -- Tutup MainFrame secara otomatis
	openFrame(UI.messageFrame) -- Buka MessageFrame dengan animasi pop up

	local textbox = UI.messageFrame:WaitForChild("TextBox")
	textbox.Text = ""
	textbox:CaptureFocus()

	debugLog("Message frame dibuka, amount:", amount)
end

local function hideMessageFrame(shouldSendDefault)
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

	closeFrame(UI.messageFrame) -- Tutup dengan animasi
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

	local now       = os.clock()
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
		State.lastMessageTime     = os.clock()
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

local donationQueue = {}
local isProcessingDonation = false

local function processDonationQueue()
	if isProcessingDonation then return end
	isProcessingDonation = true

	while #donationQueue > 0 do
		local data = table.remove(donationQueue, 1)

		ClientUI.updateNotificationContent(data.displayName, data.amount, data.message)
		ClientUI.showNotification()
		
		task.wait(5)
		ClientUI.hideNotification()
		task.wait(0.5)
	end

	isProcessingDonation = false
end

local function setupBroadcastListener()
	local receiveRemote = ReplicatedStorage:WaitForChild("ReceiveDonationBroadcast", 10)
	if not receiveRemote then
		warn("[CLIENT] ReceiveDonationBroadcast remote tidak ditemukan!")
		return
	end

	receiveRemote.OnClientEvent:Connect(function(displayName, amount, message)
		debugLog("Broadcast diterima:", displayName, amount)

		ClientUI.sendDonationChatMessage(displayName, amount)

		if amount >= ClientConfig.NOTIFICATION.MIN_DONATION then
			table.insert(donationQueue, {
				displayName = displayName,
				amount = amount,
				message = message
			})
			processDonationQueue()
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
		donationIcon:deselect()
		debugLog("Auto-closed (donasi kecil, tanpa message frame)")
	end
end)

-- ============================================
-- UI SETUP
-- ============================================

UI.mainFrame.Visible         = false
UI.templateBtn.Visible       = false
UI.messageFrame.Visible      = false
UI.notificationFrame.Visible = false

-- Auto Resize ScrollingFrame (Container)
local listLayout = UI.container:WaitForChild("UIListLayout")
listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	UI.container.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 10)
end)

-- Saweria Setup
saweriaTextBox.Text             = "https://saweria.co/JeksAl"
saweriaTextBox.TextEditable     = false
saweriaTextBox.ClearTextOnFocus = false

copyBtn.MouseButton1Click:Connect(function()
	saweriaTextBox:CaptureFocus()
	saweriaTextBox.SelectionStart = 1
	saweriaTextBox.CursorPosition = #saweriaTextBox.Text + 1
	ClientUI.notify("Link Siap Disalin!", "Teks dipilih, tekan Ctrl+C untuk menyalin.", 3)
end)

-- CLOSE BUTTON MAIN FRAME
task.spawn(function()
	-- Mencari CloseBtn langsung di dalam MainFrame
	local btnClose = UI.mainFrame:WaitForChild("CloseBtn", 3)

	-- Jika tidak ketemu, coba cari di dalam Header (berjaga-jaga)
	if not btnClose then
		local mainHeader = UI.mainFrame:FindFirstChild("Header")
		if mainHeader then
			btnClose = mainHeader:FindFirstChild("CloseBtn")
		end
	end

	if btnClose then
		btnClose.MouseButton1Click:Connect(function()
			donationIcon:deselect() -- Ini akan otomatis menutup frame & menjalankan animasi
			debugLog("Donation UI ditutup via CloseBtn")
		end)
	else
		warn("[DonationUI] CloseBtn tidak ditemukan di dalam MainFrame!")
	end
end)


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

Players.PlayerRemoving:Connect(function(leavingPlayer)
	if leavingPlayer == player then
		if donationIcon then donationIcon:Destroy() end
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
	{min = 2000, color = Color3.fromRGB(230, 33,  23),  name = "Legendary"}, 
	{min = 1000, color = Color3.fromRGB(233, 30,  99),  name = "Epic"},      
	{min = 500,  color = Color3.fromRGB(156, 39,  176), name = "Rare"},      
	{min = 250,  color = Color3.fromRGB(63,  81,  181), name = "Super"},     
	{min = 100,  color = Color3.fromRGB(33,  150, 243), name = "Great"},     
	{min = 50,   color = Color3.fromRGB(0,   188, 212), name = "Good"},      
	{min = 30,   color = Color3.fromRGB(0,   150, 136), name = "Nice"},      
	{min = 0,    color = Color3.fromRGB(76,  175, 80),  name = "Thanks"},    
}

-- ============================================
-- CHAT MESSAGES
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

local ClientConfig = require(script.Parent:WaitForChild("ClientConfig"))

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

-- 🔥 SECURITY FIX 2: Fungsi proteksi teks agar RichText tidak hilang
local function sanitizeHtml(text)
	if not text then return "" end
	text = tostring(text)
	text = text:gsub("&", "&amp;")
	text = text:gsub("<", "&lt;")
	text = text:gsub(">", "&gt;")
	text = text:gsub('"', "&quot;")
	text = text:gsub("'", "&apos;")
	return text
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

function ClientUI.sendDonationChatMessage(displayName, amount)
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
		local textChannels = TextChatService:FindFirstChild("TextChannels")
		if not textChannels then return end

		local generalChannel = textChannels:FindFirstChild("RBXGeneral")
		if not generalChannel then return end

		local color    = ClientUI.getDonationColor(amount)
		local hexColor = colorToHex(color)
		local template = getChatMessageTemplate(amount)
		local message  = string.format(template, displayName, ClientUI.formatNumber(amount))

		local richMessage = string.format(
			'<font color="#%s"><b>%s</b></font>',
			hexColor, message
		)

		generalChannel:DisplaySystemMessage(richMessage)
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
		-- 🔥 SECURITY FIX 2: Terapkan sanitizeHtml agar Teks RichText tidak error
		NotificationState.notificationTextLabel.Text = sanitizeHtml(message)
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

	-- 🔥 ARCHITECT FIX 3: Timpa tabel ketimbang meng-insert
	NotificationState.currentTweens = { slideIn }
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

	slideOut.Completed:Once(function(playbackState)
		-- 🔥 ARCHITECT FIX 1: Pastikan status isShowing & Visible hanya diset False JIKA animasi tidak di-Cancel paksa!
		if playbackState == Enum.PlaybackState.Completed then
			frame.Visible               = false
			NotificationState.isShowing = false
			debugLog("UI", "Notification hidden")
		end
	end)
end

return ClientUI


local Players = game:GetService("Players")
local player = Players.LocalPlayer
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local updateFavoritedAnimationsEventRE = remotes:WaitForChild("updateFavoritedAnimationsEvent")
local startSyncRE = remotes:WaitForChild("startSync")
local changeSpeedRE = remotes:WaitForChild("changeSpeed")
local syncNotificationRE = remotes:WaitForChild("SyncNotification")
local animationStartRE = remotes:WaitForChild("animationStart")

local emotesFolder = ReplicatedStorage:WaitForChild("Emotes")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local AnimationPreloader = require(Modules:WaitForChild("AnimationPreloader"))
local AnimatorUtils = require(Modules:WaitForChild("AnimatorUtils"))
AnimatorUtils.AnimationPreloader = AnimationPreloader

-- 🔥 INTEGRASI MODULE ANIMASI
local UIAnimator = require(ReplicatedStorage:WaitForChild("UIAnimator"))

-- ============================================
-- GUI ELEMENTS
-- ============================================
local gui = script.Parent
local mainframe = gui:WaitForChild("MainFrame")
local preloadLabel = Instance.new("TextLabel")
preloadLabel.Name = "PreloadStatus"
preloadLabel.Size = UDim2.new(1, 0, 1, 0)
preloadLabel.Position = UDim2.new(0, 0, 0, 0)
preloadLabel.AnchorPoint = Vector2.new(0, 0)
preloadLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
preloadLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
preloadLabel.Text = "Preloading animations..."
preloadLabel.TextSize = 14
preloadLabel.Font = Enum.Font.Montserrat
preloadLabel.Visible = false
preloadLabel.Parent = mainframe

local containerframe = mainframe:WaitForChild("Container")
local controlframe = mainframe:WaitForChild("Control")
local unsyncframe = mainframe:WaitForChild("UnsyncFrame")
local containerlist = containerframe:WaitForChild("ContainerList")
local templateframe = containerlist:WaitForChild("Template")
local danceBtn = controlframe:WaitForChild("Dance")
local favoriteBtn = controlframe:WaitForChild("Favorite")
local poseBtn = controlframe:WaitForChild("Pose")
local unsyncBtn = unsyncframe:WaitForChild("UnsyncBtn")
local dancelabel = unsyncframe:WaitForChild("DanceLabel")
local searchBox = mainframe:WaitForChild("SearchBox")
local notifframe = gui:WaitForChild("NotificationFrame")
local notiflabel = notifframe:WaitForChild("NotificationText")

local speedFrame = mainframe:FindFirstChild("SpeedFrame")
local speedBar = speedFrame and speedFrame:FindFirstChild("speedBar")
local speedSlider = speedBar and speedBar:FindFirstChild("speedPosition")
local speedButton = speedSlider and speedSlider:FindFirstChild("Button")
local speedtext = speedFrame and speedFrame:FindFirstChild("TextLabel")

-- ============================================
-- VARIABLES & CONSTANTS
-- ============================================
local SPEED_MIN = 0.5
local SPEED_MAX = 3.0
local SPEED_DEFAULT = 1.0
local FADE_TIME = 0.5

local notificationQueue = {}
local isShowingNotification = false

local allButtons = {}
local emoteIdCache = {}
local favoritedAnimations = {}

local currentAnimation = nil
local currentCategory = "Dance"
local searchQuery = ""
local currentSpeed = SPEED_DEFAULT

local inputLock = false
local pendingRequest = false
local isSyncing = false
local currentLeaderName = nil
local localSyncTrack = nil
local localAnimTrack = nil
local syncUpdateConnection = nil

local savedLocalEmoteData = nil
local animationStarted -- Forward Declaration

local lastEmoteClickTime = 0 

-- ============================================
-- CORE ANIMATION & STATE CONTROL
-- ============================================

local function setAnimateEnabled(character, enabled)
	if not character then return end
	character:SetAttribute("AnimateDisabled", not enabled)
end

local function killGhostAnimation(animator, fade)
	local f = fade or FADE_TIME
	pcall(function()
		if not animator or not animator.Parent then return end
		if animator.Parent.Parent ~= player.Character then return end 

		for _, t in ipairs(animator:GetPlayingAnimationTracks()) do
			if t.Animation and emoteIdCache[t.Animation.AnimationId] then
				t:AdjustSpeed(1) 
				t:Stop(f)
			end
		end
	end)
end

local function suppressNativeAnimations(animator, fade)
end

local function freezeHumanoidForPose(character, freeze)
	if not character then return end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	if freeze then
		humanoid:ChangeState(Enum.HumanoidStateType.None)
	else
		if humanoid:GetState() == Enum.HumanoidStateType.None then
			humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
	end
end

local function isCurrentAnimPose()
	if not currentAnimation then return false end
	for _, data in ipairs(allButtons) do
		if data.button == currentAnimation and data.category == "Pose" then
			return true
		end
	end
	return false
end

local function restoreCharacterAnimations(character)
	if character ~= player.Character then return end

	if not character then return end
	setAnimateEnabled(character, true)
	freezeHumanoidForPose(character, false)

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")

	if animator then
		pcall(function()
			for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
				if track.Animation and not emoteIdCache[track.Animation.AnimationId] then
					track:AdjustSpeed(1)
					track:AdjustWeight(1)
				end
			end
		end)
	end

	if humanoid then
		task.defer(function()
			if character:GetAttribute("AnimateDisabled") then return end
			pcall(function()
				local state = humanoid:GetState()
				if state == Enum.HumanoidStateType.None then return end
				humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
				task.defer(function()
					pcall(function() humanoid:ChangeState(state) end)
				end)
			end)
		end)
	end
end

-- ============================================
-- GUI HELPER FUNCTIONS
-- ============================================

local function showNotification(message, duration, bgColor)
	table.insert(notificationQueue, { message = message, duration = duration or 3, bgColor = bgColor or Color3.fromRGB(50, 150, 255) })

	if not isShowingNotification then
		task.spawn(function()
			while #notificationQueue > 0 do
				isShowingNotification = true
				local notif = table.remove(notificationQueue, 1)
				notiflabel.Text = notif.message
				notifframe.BackgroundColor3 = notif.bgColor

				-- Set posisinya di tempat yang benar karena UIAnimator akan men-scale pop-up di lokasi tersebut
				notifframe.Position = UDim2.new(0.5, 0, 0.1, 0)

				-- Buka notifikasi pakai UIAnimator
				UIAnimator.Open(notifframe)

				task.wait(notif.duration)

				-- Tutup notifikasi pakai UIAnimator
				UIAnimator.Close(notifframe)

				task.wait(0.3) -- Jeda kecil sebelum menampilkan antrean berikutnya
			end
			isShowingNotification = false
		end)
	end
end

syncNotificationRE.OnClientEvent:Connect(function(notifType, leaderName)
	if notifType == "sync_success" then
		local leaderPlayer = Players:FindFirstChild(leaderName)
		local displayName = leaderPlayer and leaderPlayer.DisplayName or leaderName
		showNotification("Coordinate dance are apply to " .. displayName, 2.5, Color3.fromRGB(0, 0, 0))
	elseif notifType == "unsync_success" then
		showNotification("Unsynced", 2, Color3.fromRGB(0, 0, 0))
	elseif notifType == "leader_left" then
		showNotification("LEAD " .. leaderName .. " meninggalkan server", 4, Color3.fromRGB(200, 30, 30))
		if player.Character then
			restoreCharacterAnimations(player.Character)
			if localSyncTrack then 
				localSyncTrack:Stop(0.5) 
				localSyncTrack = nil 
			end
		end
	elseif notifType == "leader_blocked" then
		showNotification("You are a Dance Leader!\nCannot sync to followers", 3, Color3.fromRGB(0, 0, 0))
	elseif notifType == "circular_blocked" then
		showNotification("Cannot create circular coordinate dance", 2.5, Color3.fromRGB(0, 0, 0))
	end
end)

local function updateButtonVisuals()
	for _, data in ipairs(allButtons) do
		local templateBtn = data.button:FindFirstChild("TemplateBtn")
		if templateBtn then
			templateBtn.TextColor3 = (currentAnimation == data.button) and Color3.fromRGB(255, 0, 0) or Color3.fromRGB(255, 255, 255)
		end
	end
end

local function loadSavedFavorites()
	local stringVal = player:WaitForChild("SavedFavoritedAnimations", 15)
	local savedData = stringVal and stringVal.Value or nil

	if savedData and typeof(savedData) == "string" then
		local ok, decoded = pcall(HttpService.JSONDecode, HttpService, savedData)
		favoritedAnimations = (ok and typeof(decoded) == "table") and decoded or {}
	else
		favoritedAnimations = {}
	end
end

local favoritesLoaded = false
task.spawn(function() loadSavedFavorites() favoritesLoaded = true end)

local function saveFavoritedAnimations() 
	updateFavoritedAnimationsEventRE:FireServer(HttpService:JSONEncode(favoritedAnimations)) 
end

local function findAnimById(danceId)
	for _, anim in ipairs(emotesFolder:GetChildren()) do
		if anim:IsA("Animation") and anim.AnimationId == danceId then return anim end
	end
	local poseFolder = emotesFolder:FindFirstChild("Pose")
	if poseFolder then
		for _, anim in ipairs(poseFolder:GetChildren()) do
			if anim:IsA("Animation") and anim.AnimationId == danceId then return anim end
		end
	end
	return nil
end

-- ============================================
-- THE UNIVERSAL HIVE MIND (Observer Tunggal)
-- ============================================
local globalSyncListeners = setmetatable({}, { __mode = "k" })

local function applyDance(char, danceId, speed, startTime, leaderName, isSpam)
	if char ~= player.Character then return end 

	local animator = char:FindFirstChild("Humanoid") and char.Humanoid:FindFirstChild("Animator")
	if not animator then return end

	local applyTicket = (char:GetAttribute("ApplyTicket") or 0) + 1
	char:SetAttribute("ApplyTicket", applyTicket)
	local actualFade = isSpam and 0 or FADE_TIME

	if dancelabel then
		if danceId and emoteIdCache[danceId] then
			dancelabel.Text = " " .. emoteIdCache[danceId]
		else
			local displayName = leaderName or "Leader"
			local lp = Players:FindFirstChild(leaderName or "")
			if lp then displayName = lp.DisplayName end
			dancelabel.Text = " " .. displayName .. "'s Dance"
		end
	end

	if not danceId then
		if localSyncTrack then
			localSyncTrack:Stop(actualFade)
			localSyncTrack = nil
		end

		killGhostAnimation(animator, actualFade)
		restoreCharacterAnimations(char)

		if not isSyncing then
			if savedLocalEmoteData then
				local saved = savedLocalEmoteData
				savedLocalEmoteData = nil
				task.delay(0.1, function()
					animationStarted(saved.animation, saved.button)
				end)
			end
		end
		return
	end

	local targetAnim = findAnimById(danceId)
	if not targetAnim then return end

	if localAnimTrack then
		localAnimTrack:Stop(actualFade)
		localAnimTrack = nil
	end

	setAnimateEnabled(char, false)
	killGhostAnimation(animator, actualFade)

	local track = AnimatorUtils.getOrCreateTrack(animator, targetAnim)
	if not track then setAnimateEnabled(char, true) return end

	if localSyncTrack then localSyncTrack:Stop(actualFade) end
	localSyncTrack = track

	track.Priority = Enum.AnimationPriority.Action3
	track:Play(actualFade, 1, 0)

	local capturedTicket = applyTicket
	task.spawn(function()
		local timeout = os.clock() + 5
		while track and track.Length == 0 and os.clock() < timeout do RunService.RenderStepped:task.wait() end
		if char:GetAttribute("ApplyTicket") ~= capturedTicket then return end

		if startTime and track.Length > 0 then
			local finalTime = workspace:GetServerTimeNow()
			local exactPos = ((finalTime - startTime) * speed) % track.Length
			track.TimePosition = exactPos
		end

		track:AdjustSpeed(speed) 

		task.delay(actualFade + 0.05, function()
			if char:GetAttribute("ApplyTicket") ~= capturedTicket then return end
			suppressNativeAnimations(animator, 0)
		end)
	end)
end

local function monitorPlayerCharacter(targetPlayer)
	local function onCharacterAdded(char)
		if globalSyncListeners[char] then return end
		globalSyncListeners[char] = true

		local humanoid = char:WaitForChild("Humanoid", 10)
		if not humanoid then return end

		local animator = humanoid:WaitForChild("Animator", 10)
		if not animator then return end

		local function forceSnapCharacterDance(track)
			if not track or track.Length == 0 then return end

			local startTime = char:GetAttribute("DanceStartTime")
			local speed = char:GetAttribute("DanceSpeed") or 1
			local currentDanceId = char:GetAttribute("CurrentDanceID")
			local syncingTo = char:GetAttribute("Syncing")

			if syncingTo == player.Name then return end 

			if currentDanceId and track.Animation and track.Animation.AnimationId ~= currentDanceId then return end

			if syncingTo and syncingTo ~= "" then
				local leader = Players:FindFirstChild(syncingTo)
				if leader and leader.Character then
					startTime = leader.Character:GetAttribute("DanceStartTime") or startTime
					speed = leader.Character:GetAttribute("DanceSpeed") or speed
				end
			end

			if startTime then
				local elapsed = workspace:GetServerTimeNow() - startTime
				local exactPos = (elapsed * speed) % track.Length
				if exactPos > 0 and math.abs(track.TimePosition - exactPos) > 0.03 then
					pcall(function() track.TimePosition = exactPos end)
				end
			end
		end

		animator.AnimationPlayed:Connect(function(track)
			if char:GetAttribute("AnimateDisabled") then
				if not (track.Animation and emoteIdCache[track.Animation.AnimationId]) then
					local prio = track.Priority
					if prio == Enum.AnimationPriority.Core or prio == Enum.AnimationPriority.Idle or prio == Enum.AnimationPriority.Movement or prio == Enum.AnimationPriority.Action3 then
						track:AdjustWeight(0.001)
					end
				end
			end

			if char ~= player.Character and track.Animation and emoteIdCache[track.Animation.AnimationId] then
				task.spawn(function()
					local timeout = os.clock() + 5
					while track and track.Length == 0 and os.clock() < timeout do RunService.RenderStepped:task.wait() end
					forceSnapCharacterDance(track)
				end)
			end
		end)

		local function onAttributeChanged()
			if char == player.Character then return end
			for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
				if track.Animation and emoteIdCache[track.Animation.AnimationId] then
					forceSnapCharacterDance(track)
				end
			end
		end

		char:GetAttributeChangedSignal("DanceStartTime"):Connect(onAttributeChanged)
		char:GetAttributeChangedSignal("CurrentDanceID"):Connect(onAttributeChanged)
		char:GetAttributeChangedSignal("DanceSpeed"):Connect(onAttributeChanged)
		char:GetAttributeChangedSignal("Syncing"):Connect(onAttributeChanged)

		char:GetAttributeChangedSignal("AnimateDisabled"):Connect(function()
			if char:GetAttribute("AnimateDisabled") then
				for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
					if track.Animation and emoteIdCache[track.Animation.AnimationId] then continue end
					local prio = track.Priority
					if prio == Enum.AnimationPriority.Core or prio == Enum.AnimationPriority.Idle or prio == Enum.AnimationPriority.Movement or prio == Enum.AnimationPriority.Action3 then
						if track.WeightCurrent > 0.01 then track:AdjustWeight(0.001) end
					end
				end
			end
		end)

		local function syncToLeader()
			local leaderName = char:GetAttribute("Syncing")
			if leaderName and leaderName ~= "" then
				local leaderPlayer = Players:FindFirstChild(leaderName)
				local leaderChar = leaderPlayer and leaderPlayer.Character
				if leaderChar then
					local danceId = leaderChar:GetAttribute("CurrentDanceID")
					local speed = leaderChar:GetAttribute("DanceSpeed") or 1
					local startTime = leaderChar:GetAttribute("DanceStartTime")
					applyDance(char, danceId, speed, startTime, leaderName, false)
				else
					applyDance(char, nil, 1, nil, leaderName, false)
				end
			else
				applyDance(char, nil, 1, nil, nil, false)
			end
		end

		local function broadcastLeaderState(isSpamTrigger)
			local danceId = char:GetAttribute("CurrentDanceID")
			local speed = char:GetAttribute("DanceSpeed") or 1
			local startTime = char:GetAttribute("DanceStartTime")

			if char == player.Character then return end
			for _, p in ipairs(Players:GetPlayers()) do
				if p.Character and p.Character:GetAttribute("Syncing") == char.Name then
					applyDance(p.Character, danceId, speed, startTime, char.Name, isSpamTrigger)
				end
			end
		end

		char:GetAttributeChangedSignal("Syncing"):Connect(syncToLeader)
		char:GetAttributeChangedSignal("CurrentDanceID"):Connect(function() broadcastLeaderState(false) end)
		char:GetAttributeChangedSignal("DanceSpeed"):Connect(function() broadcastLeaderState(false) end)
		char:GetAttributeChangedSignal("SpamNonce"):Connect(function() broadcastLeaderState(true) end)

		task.spawn(function()
			if char:GetAttribute("Syncing") and char:GetAttribute("Syncing") ~= "" then
				syncToLeader()
			elseif char:GetAttribute("CurrentDanceID") then
				broadcastLeaderState(false)
			end
		end)
	end
	if targetPlayer.Character then onCharacterAdded(targetPlayer.Character) end
	targetPlayer.CharacterAdded:Connect(onCharacterAdded)
end

for _, p in ipairs(Players:GetPlayers()) do monitorPlayerCharacter(p) end
Players.PlayerAdded:Connect(monitorPlayerCharacter)

-- ============================================
-- GUI & SYNC MANAGEMENT
-- ============================================
local function updateUnsyncFrame()
	if not player.Character then 
		if unsyncframe.Visible then UIAnimator.Close(unsyncframe) end
		return 
	end

	local syncTarget = player.Character:GetAttribute("Syncing")
	if syncTarget and syncTarget ~= "" then
		isSyncing = true
		currentLeaderName = syncTarget
		local leaderPlayer = Players:FindFirstChild(syncTarget)
		unsyncBtn.Text = "Synced to " .. (leaderPlayer and leaderPlayer.DisplayName or syncTarget) .. "\nTap to Unsync"

		if not unsyncframe.Visible then
			UIAnimator.Open(unsyncframe)
		end
	else
		if unsyncframe.Visible then
			UIAnimator.Close(unsyncframe)
		end

		isSyncing = false
		currentLeaderName = nil
		if localSyncTrack then 
			localSyncTrack:Stop(FADE_TIME) 
			localSyncTrack = nil 
		end
		if player.Character then
			restoreCharacterAnimations(player.Character)
		end
	end
end

unsyncBtn.MouseButton1Click:Connect(function()
	if inputLock or pendingRequest or not isSyncing or not currentLeaderName then return end
	inputLock = true
	local leaderPlayer = Players:FindFirstChild(currentLeaderName)
	if not leaderPlayer then
		if player.Character then player.Character:SetAttribute("Syncing", nil) end
		updateUnsyncFrame() inputLock = false return
	end
	if localSyncTrack then 
		localSyncTrack:Stop(FADE_TIME) 
		localSyncTrack = nil 
	end
	startSyncRE:FireServer(leaderPlayer, false)
	local clickSound = ReplicatedStorage:FindFirstChild("Sounds") and ReplicatedStorage.Sounds:FindFirstChild("minimal-pop-click-ui")
	if clickSound then clickSound:Play() end
	task.wait(0.1)
	updateUnsyncFrame()
	task.delay(0.3, function() inputLock = false end)
end)

local function setupSyncMonitoring()
	if syncUpdateConnection then syncUpdateConnection:Disconnect() syncUpdateConnection = nil end
	if not player.Character then player.CharacterAdded:task.wait() end
	updateUnsyncFrame()

	syncUpdateConnection = player.Character:GetAttributeChangedSignal("Syncing"):Connect(function()
		updateUnsyncFrame()
		if isSyncing then
			if not savedLocalEmoteData and currentAnimation and localAnimTrack then
				local savedAnim = nil
				for _, data in ipairs(allButtons) do
					if data.button == currentAnimation then
						savedAnim = data.animation
						break
					end
				end
				if savedAnim then
					savedLocalEmoteData = {
						animation = savedAnim,
						button = currentAnimation,
						speed = currentSpeed,
					}
				end
			end
		end
	end)
end
setupSyncMonitoring()
player.CharacterAdded:Connect(function() task.wait(1) setupSyncMonitoring() end)

-- ============================================
-- ANIMATION STARTED (Leader / Solo)
-- ============================================
function animationStarted(animation, button)
	if inputLock or pendingRequest then return end
	inputLock = true
	task.delay(0.01, function() inputLock = false end)

	local currentTime = os.clock()
	local character = player.Character
	local animator = character and character:FindFirstChild("Humanoid") and character.Humanoid:FindFirstChild("Animator")

	if currentAnimation == button then
		local timeSinceLastClick = currentTime - lastEmoteClickTime
		if timeSinceLastClick < 0.7 then
			lastEmoteClickTime = os.clock()
			if animator then
				local isPose = isCurrentAnimPose()
				local char = character
				setAnimateEnabled(character, false)
				if localAnimTrack then 
					localAnimTrack:Stop(0) 
				end
				localAnimTrack = AnimatorUtils.getOrCreateTrack(animator, animation)
				if localAnimTrack then
					localAnimTrack.Priority = Enum.AnimationPriority.Action3
					localAnimTrack:Play(0, 1, currentSpeed)
					local capturedTicket = (char:GetAttribute("ApplyTicket") or 0)
					task.spawn(function()
						task.wait(0.05)
						if char:GetAttribute("ApplyTicket") ~= capturedTicket then return end
						freezeHumanoidForPose(char, isPose)
					end)
				end
			end
			animationStartRE:FireServer(animation.AnimationId, true, currentSpeed, 0, true, workspace:GetServerTimeNow())
		else
			currentAnimation = nil
			lastEmoteClickTime = 0
			updateButtonVisuals()
			savedLocalEmoteData = nil
			if animator and localAnimTrack then
				localAnimTrack:Stop(FADE_TIME)
				localAnimTrack = nil
			end
			restoreCharacterAnimations(character)
			animationStartRE:FireServer(animation.AnimationId, false, currentSpeed, 0, false, workspace:GetServerTimeNow())
		end
	else
		if character then
			restoreCharacterAnimations(character)
		end
		savedLocalEmoteData = nil
		currentAnimation = button
		lastEmoteClickTime = os.clock()
		updateButtonVisuals()
		if animator then
			local isPose = isCurrentAnimPose()
			local char = character
			setAnimateEnabled(character, false)
			if localAnimTrack then 
				localAnimTrack:Stop(FADE_TIME) 
			end
			localAnimTrack = AnimatorUtils.getOrCreateTrack(animator, animation)
			if localAnimTrack then
				localAnimTrack.Priority = Enum.AnimationPriority.Action3
				localAnimTrack:Play(FADE_TIME, 1, currentSpeed)
				local capturedTicket = (char:GetAttribute("ApplyTicket") or 0)
				task.spawn(function()
					task.wait(FADE_TIME + 0.05)
					if char:GetAttribute("ApplyTicket") ~= capturedTicket then return end
					freezeHumanoidForPose(char, isPose)
				end)
			end
		end
		animationStartRE:FireServer(animation.AnimationId, true, currentSpeed, FADE_TIME, false, workspace:GetServerTimeNow())
	end
end

-- ============================================
-- GUI & BUTTON BUILDER
-- ============================================

local updateDisplay 

local function toggleFavorite(animation, button, favoriteIcon)
	favoritedAnimations[animation.Name] = not favoritedAnimations[animation.Name]
	favoriteIcon.TextColor3 = favoritedAnimations[animation.Name] and Color3.fromRGB(255, 215, 0) or Color3.fromRGB(100, 100, 100)
	saveFavoritedAnimations()
	if currentCategory == "Favorite" then updateDisplay() end
end

local function createEmoteButton(animation, category)
	local newButton = templateframe:Clone()
	newButton.Name = animation.Name
	newButton.Visible = true
	local templateBtn = newButton:FindFirstChild("TemplateBtn")
	local favoriteIcon = newButton:FindFirstChild("FavoriteBtn")
	local originalColor = Color3.fromRGB(255, 255, 255)

	if templateBtn then
		originalColor = templateBtn.BackgroundColor3
		templateBtn.Text = animation.Name
	end

	if favoriteIcon then
		favoriteIcon.TextColor3 = favoritedAnimations[animation.Name] and Color3.fromRGB(255, 215, 0) or Color3.fromRGB(100, 100, 100)
		favoriteIcon.MouseButton1Click:Connect(function()
			if inputLock then return end
			inputLock = true
			toggleFavorite(animation, newButton, favoriteIcon)
			task.delay(0.2, function() inputLock = false end)
		end)
	end

	if templateBtn then
		templateBtn.MouseButton1Click:Connect(function()
			animationStarted(animation, newButton)
			local clickSound = ReplicatedStorage:FindFirstChild("Sounds") and ReplicatedStorage.Sounds:FindFirstChild("minimal-pop-click-ui")
			if clickSound then clickSound:Play() end
		end)
	end

	newButton.Parent = containerlist
	table.insert(allButtons, { button = newButton, animation = animation, category = category, name = animation.Name, originalColor = originalColor })
	return newButton
end

function updateDisplay()
	pcall(function()
		containerlist.CanvasPosition = Vector2.new(0, 0)
		for _, data in ipairs(allButtons) do
			local shouldShow = (currentCategory == "Favorite") and (favoritedAnimations[data.name] == true) or (currentCategory == data.category)
			if shouldShow and searchQuery ~= "" then 
				shouldShow = string.find(string.lower(data.name), string.lower(searchQuery)) ~= nil 
			end
			data.button.Visible = shouldShow
		end
		updateButtonVisuals()
	end)
end

local function setActiveCategory(category)
	currentCategory = category
	danceBtn.BackgroundColor3 = (category == "Dance") and Color3.fromRGB(50, 150, 255) or Color3.fromRGB(70, 70, 70)
	poseBtn.BackgroundColor3 = (category == "Pose") and Color3.fromRGB(50, 150, 255) or Color3.fromRGB(70, 70, 70)
	favoriteBtn.BackgroundColor3 = (category == "Favorite") and Color3.fromRGB(255, 215, 0) or Color3.fromRGB(70, 70, 70)
	updateDisplay()
end

danceBtn.MouseButton1Click:Connect(function() setActiveCategory("Dance") end)
poseBtn.MouseButton1Click:Connect(function() setActiveCategory("Pose") end)
favoriteBtn.MouseButton1Click:Connect(function() setActiveCategory("Favorite") end)
searchBox:GetPropertyChangedSignal("Text"):Connect(function() searchQuery = searchBox.Text updateDisplay() end)

-- ============================================
-- SPEED SLIDER
-- ============================================
if speedSlider and speedBar and speedtext and speedButton then
	local isDraggingSpeed = false
	local speedSendDebounce = false
	local lastSentSpeed = SPEED_DEFAULT
	speedSlider.AnchorPoint = Vector2.new(0.5, 0.5)

	local function scaleToSpeed(scale) return math.floor((SPEED_MIN + scale * (SPEED_MAX - SPEED_MIN)) * 100 + 0.5) / 100 end
	local function speedToScale(speed) return (speed - SPEED_MIN) / (SPEED_MAX - SPEED_MIN) end

	local function sendSpeedToServer(speed)
		if speed == lastSentSpeed or speedSendDebounce then return end
		speedSendDebounce = true
		lastSentSpeed = speed
		changeSpeedRE:FireServer(speed)
		task.delay(0.05, function()
			speedSendDebounce = false
			if currentSpeed ~= lastSentSpeed then changeSpeedRE:FireServer(currentSpeed) lastSentSpeed = currentSpeed end
		end)
	end

	local targetScale = speedToScale(SPEED_DEFAULT)
	local currentScale = targetScale

	speedBar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			if isSyncing then showNotification("Cannot change speed while syncing", 2, Color3.fromRGB(0, 0, 0)) return end
			isDraggingSpeed = true
			targetScale = math.clamp((UserInputService:GetMouseLocation().X - speedBar.AbsolutePosition.X) / speedBar.AbsoluteSize.X, 0, 1)
		end
	end)

	speedButton.MouseButton1Down:Connect(function()
		if isSyncing then showNotification("Cannot change speed while syncing", 2, Color3.fromRGB(0, 0, 0)) return end
		isDraggingSpeed = true
	end)

	UserInputService.InputEnded:Connect(function(input) 
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then isDraggingSpeed = false end 
	end)
	UserInputService.TouchEnded:Connect(function() isDraggingSpeed = false end)

	RunService.RenderStepped:Connect(function(dt)
		if isDraggingSpeed then 
			targetScale = math.clamp((UserInputService:GetMouseLocation().X - speedBar.AbsolutePosition.X) / speedBar.AbsoluteSize.X, 0, 1) 
		end
		if math.abs(currentScale - targetScale) > 0.001 then
			currentScale = currentScale + (targetScale - currentScale) * (12 * dt)
			speedSlider.Position = UDim2.fromScale(currentScale, 0.5)
			local newSpeed = scaleToSpeed(currentScale)
			if newSpeed ~= currentSpeed then
				currentSpeed = newSpeed
				speedtext.Text = string.format("%.1fx", math.floor(currentSpeed * 10 + 0.5) / 10)
				if not isSyncing then
					sendSpeedToServer(currentSpeed)
					if localAnimTrack then
						localAnimTrack:AdjustSpeed(currentSpeed)
					end
				end
			end
		else
			currentScale = targetScale
		end
	end)
	speedSlider.Position = UDim2.fromScale(targetScale, 0.5)
	speedtext.Text = string.format("%.1fx", SPEED_DEFAULT)
end


-- ============================================
-- PRELOAD & LOAD ANIMATIONS
-- ============================================
task.spawn(function()
	repeat task.wait() until #emotesFolder:GetChildren() > 0
	preloadLabel.Visible = true
	if not player.Character then player.CharacterAdded:task.wait() end
	task.wait(2)
	local success = AnimationPreloader.preloadAnimations(emotesFolder)
	preloadLabel.Text = success and "Animations ready!" or "Preload failed"
	preloadLabel.BackgroundTransparency = 0
	task.wait(success and 1.5 or 3)
	preloadLabel.Visible = false
end)

task.spawn(function()
	repeat task.wait() until #emotesFolder:GetChildren() > 0
	repeat task.wait(0.1) until favoritesLoaded
	for _, anim in ipairs(emotesFolder:GetChildren()) do
		if anim:IsA("Animation") then createEmoteButton(anim, "Dance") emoteIdCache[anim.AnimationId] = anim.Name end
	end
	local poseFolder = emotesFolder:FindFirstChild("Pose")
	if poseFolder then
		for _, anim in ipairs(poseFolder:GetChildren()) do
			if anim:IsA("Animation") then createEmoteButton(anim, "Pose") emoteIdCache[anim.AnimationId] = anim.Name end
		end
	end
	table.sort(allButtons, function(a, b) return a.name < b.name end)
	for i, data in ipairs(allButtons) do data.button.LayoutOrder = i end
	setActiveCategory("Dance")
end)

-- ============================================
-- ANTI-DRIFT BACKGROUND SYNC (OPTIMIZED + SMOOTH LERP)
-- ============================================
task.spawn(function()
	while task.wait(0.2) do
		local myChar = player.Character
		local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
		if not myHrp then continue end

		local myReferenceTrack = localSyncTrack or localAnimTrack

		for _, p in ipairs(Players:GetPlayers()) do
			local char = p.Character
			if char and char ~= myChar then
				local targetHrp = char:FindFirstChild("HumanoidRootPart")

				if not targetHrp or (myHrp.Position - targetHrp.Position).Magnitude > 100 then 
					continue 
				end

				local animator = char:FindFirstChild("Humanoid") and char.Humanoid:FindFirstChild("Animator")
				if animator then
					local syncingTo = char:GetAttribute("Syncing")

					if syncingTo == player.Name then
						if myReferenceTrack and myReferenceTrack.IsPlaying then
							for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
								if track.Animation and track.Animation.AnimationId == myReferenceTrack.Animation.AnimationId then
									local exactPos = myReferenceTrack.TimePosition
									local diff = exactPos - track.TimePosition

									if track.Length > 0 then
										if diff > track.Length / 2 then diff = diff - track.Length end
										if diff < -track.Length / 2 then diff = diff + track.Length end

										-- 🔥 Menghapus pcall, performa meningkat secara drastis
										if math.abs(diff) > 0.4 then
											track.TimePosition = exactPos
										elseif math.abs(diff) > 0.03 then
											local catchUpSpeed = currentSpeed + (diff * 2.5)
											track:AdjustSpeed(catchUpSpeed)
										else
											track:AdjustSpeed(currentSpeed)
										end
									end
								end
							end
						end
						continue 
					end

					local startTime = char:GetAttribute("DanceStartTime")
					local speed = char:GetAttribute("DanceSpeed") or 1
					local currentDanceId = char:GetAttribute("CurrentDanceID")

					if syncingTo and syncingTo ~= "" then
						local leader = Players:FindFirstChild(syncingTo)
						if leader and leader.Character then
							startTime = leader.Character:GetAttribute("DanceStartTime") or startTime
							speed = leader.Character:GetAttribute("DanceSpeed") or speed
							currentDanceId = leader.Character:GetAttribute("CurrentDanceID") or currentDanceId
						end
					end

					if startTime and currentDanceId then
						for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
							if track.Animation and track.Animation.AnimationId == currentDanceId then
								local elapsed = workspace:GetServerTimeNow() - startTime
								local exactPos = (elapsed * speed) % track.Length

								if exactPos > 0 and track.Length > 0 then
									local diff = exactPos - track.TimePosition

									if diff > track.Length / 2 then diff = diff - track.Length end
									if diff < -track.Length / 2 then diff = diff + track.Length end

									-- 🔥 Menghapus pcall di loop ini juga
									if math.abs(diff) > 0.4 then
										track.TimePosition = exactPos
									elseif math.abs(diff) > 0.03 then
										local catchUpSpeed = speed + (diff * 2.5)
										track:AdjustSpeed(catchUpSpeed)
									else
										track:AdjustSpeed(speed)
									end
								end
							end
						end
					end
				end
			end
		end
	end
end)


-- ============================================
-- THE ZOMBIE CLEANER
-- ============================================
player.CharacterAdded:Connect(function(newCharacter)
	task.spawn(function()
		local animScript = newCharacter:WaitForChild("Animate", 2)
		if animScript and animScript:IsA("LocalScript") then
			animScript.Disabled = false
		end
	end)

	if localSyncTrack then
		local oldTrack = localSyncTrack
		pcall(function() oldTrack:Stop() oldTrack:Destroy() end)
		localSyncTrack = nil
	end

	if localAnimTrack then
		local oldTrack = localAnimTrack
		pcall(function() oldTrack:Stop() oldTrack:Destroy() end)
		localAnimTrack = nil
	end

	isSyncing = false
	currentLeaderName = nil
	currentSpeed = 1
	currentAnimation = nil
	lastEmoteClickTime = 0
	savedLocalEmoteData = nil
	updateButtonVisuals()
end)

script.Destroying:Connect(function()
	if syncUpdateConnection then syncUpdateConnection:Disconnect() end
	if localSyncTrack then localSyncTrack:Stop(0) end
	if localAnimTrack then localAnimTrack:Stop(0) end
	if player.Character then
		restoreCharacterAnimations(player.Character)
	end
end)


local Config = require(script:WaitForChild("Config"))
local Logger = require(script:WaitForChild("Logger"))
local NotificationManager = require(script:WaitForChild("NotificationManager"))
local UIManager = require(script:WaitForChild("UIManager"))
local ShopHandler = require(script:WaitForChild("ShopHandler"))

local Player = game.Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- 🔥 INTEGRASI MODULE ANIMASI
local UIAnimator = require(ReplicatedStorage:WaitForChild("UIAnimator"))

local gui = script.Parent
local mainframe = gui:WaitForChild("MainFrame")
local content = mainframe:WaitForChild("Content")
local VVIPFrame = content:WaitForChild("VVIP Pass")
local VVIPBuyBtn = VVIPFrame:WaitForChild("BuyBtn")
local VIPFrame = content:WaitForChild("VIP Pass")
local VIPBuyBtn = VIPFrame:WaitForChild("BuyBtn")
local closeBtn = mainframe:WaitForChild("Header"):WaitForChild("CloseBtn")

local notificationframe = gui:WaitForChild("NotificationFrame")
local notificationtext = notificationframe:WaitForChild("NotificationText")

local GamepassFolder = ReplicatedStorage:WaitForChild("Gamepass")
local remotes = {
	shopRequest = GamepassFolder:WaitForChild("ShopRequest", Config.RemoteTimeout),
	playerDataUpdated = GamepassFolder:WaitForChild("PlayerDataUpdated", Config.RemoteTimeout),
	refreshRole = GamepassFolder:WaitForChild("RefreshRole", Config.RemoteTimeout)
}

Logger:Success("Connected to remotes")

NotificationManager:Init(notificationframe, notificationtext)
ShopHandler:Init(remotes, UIManager, NotificationManager)

local GamepassData = {
	VVIP = { Frame = VVIPFrame, Button = VVIPBuyBtn, IDs = {}, Owned = false, Name = "VVIP Pass", Price = 0 },
	VIP = { Frame = VIPFrame, Button = VIPBuyBtn, IDs = {}, Owned = false, Name = "VIP Pass", Price = 0 }
}

ShopHandler:SetGamepassData(GamepassData)

mainframe:GetPropertyChangedSignal("Visible"):Connect(function()
	if mainframe.Visible and not ShopHandler.shopDataLoaded then
		ShopHandler:LoadShopData()
	end
end)


closeBtn.MouseButton1Click:Connect(function()
	UIAnimator.Close(mainframe)
end)

VVIPBuyBtn.MouseButton1Click:Connect(function() ShopHandler:PromptPurchase("VVIP") end)
VIPBuyBtn.MouseButton1Click:Connect(function() ShopHandler:PromptPurchase("VIP") end)

remotes.playerDataUpdated.OnClientEvent:Connect(function(updateData)
	local updateType = updateData.type
	Logger:Debug("Received update: " .. updateType)

	if updateType == "ownership_updated" then
		ShopHandler:HandleOwnershipUpdate(updateData.gamepassType, true)
	elseif updateType == "role_updated" then
		Logger:Info("Role updated: " .. updateData.role)
	elseif updateType == "purchase_complete" then
		ShopHandler:HandleOwnershipUpdate(updateData.gamepassType, true)
		NotificationManager:ShowVisual(updateData.message, true)
	else
		Logger:Warn("Unknown update type: " .. tostring(updateType))
	end
end)

mainframe.Visible = Config.StartVisible
notificationframe.Visible = false

Logger:Info("Initializing...")

task.spawn(function()
	if not Player.Character then Player.CharacterAdded:task.wait() end
	task.wait(2)
	ShopHandler:LoadShopData()
	Logger:Success("Initialization complete - Simplified Version (Self-Purchase Only)")
end)

-- ====================================
-- CLIENT CONFIGURATION (SIMPLIFIED)
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
local Config = require(script.Parent:WaitForChild("Config"))

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


local Config = require(script.Parent:WaitForChild("Config"))
local Logger = require(script.Parent:WaitForChild("Logger"))

local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UIAnimator = require(ReplicatedStorage:WaitForChild("UIAnimator"))

local NotificationManager = {}

function NotificationManager:Init(notificationFrame, notificationText)
	self.frame = notificationFrame
	self.text = notificationText
	self.frame.Visible = false
	self.currentNotificationTicket = 0 
	Logger:Debug("NotificationManager initialized")
end

function NotificationManager:ShowVisual(message, isSuccess)
	self.currentNotificationTicket = self.currentNotificationTicket + 1
	local myTicket = self.currentNotificationTicket

	self.text.Text = message

	if isSuccess then
		self.text.TextColor3 = Color3.fromRGB(85, 255, 127)
		self.frame.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
	else
		self.text.TextColor3 = Color3.fromRGB(255, 85, 85)
		self.frame.BackgroundColor3 = Color3.fromRGB(231, 76, 60)
	end

	self.frame.BackgroundTransparency = 0.2

	UIAnimator.Open(self.frame)

	task.delay(4, function()
		if self.currentNotificationTicket ~= myTicket then return end
		UIAnimator.Close(self.frame)
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

local Config = require(script.Parent:WaitForChild("Config"))
local Logger = require(script.Parent:WaitForChild("Logger"))

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


local Config = require(script.Parent:WaitForChild("Config"))
local Logger = require(script.Parent:WaitForChild("Logger"))

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UIAnimator = require(ReplicatedStorage:WaitForChild("UIAnimator"))

local UIManager = {}

UIManager.activeConfirmConnections = nil 

function UIManager:SetButtonState(button, state)
	local stateConfig = Config.ButtonStates[state]
	if not stateConfig then return end

	button.Text = stateConfig.Text
	button.BackgroundColor3 = stateConfig.BackgroundColor
	button.TextColor3 = stateConfig.TextColor
	button.Active = stateConfig.Enabled
	button.AutoButtonColor = stateConfig.Enabled
end

function UIManager:ShowConfirmDialog(confirmDialog, confirmText, text, onYes, onNo)
	if not confirmDialog then
		Logger:Warn("ConfirmDialog tidak tersedia!")
		if onNo then onNo() end
		return {}
	end

	confirmText.Text = text

	-- Munculkan dialog konfirmasi pakai animasi
	UIAnimator.Open(confirmDialog)

	return {
		yesConnection = nil,
		noConnection = nil,
		dialog = confirmDialog
	}
end

function UIManager:SetupConfirmButtons(confirmYesBtn, confirmNoBtn, onYes, onNo)
	if self.activeConfirmConnections and self.activeConfirmConnections.cleanup then
		self.activeConfirmConnections.cleanup()
	end

	local connections = {
		yesConnection = nil,
		noConnection = nil,
		dialog = nil
	}

	local function cleanup()
		if connections.yesConnection then
			connections.yesConnection:Disconnect()
			connections.yesConnection = nil
		end
		if connections.noConnection then
			connections.noConnection:Disconnect()
			connections.noConnection = nil
		end

		-- Tutup dialog pakai animasi jika direferensikan
		if connections.dialog then
			UIAnimator.Close(connections.dialog)
		end

		if self.activeConfirmConnections == connections then
			self.activeConfirmConnections = nil
		end
	end

	connections.cleanup = cleanup

	connections.yesConnection = confirmYesBtn.MouseButton1Click:Connect(function()
		Logger:Debug("Confirm Yes clicked")
		cleanup()
		if onYes then pcall(onYes) end
	end)

	connections.noConnection = confirmNoBtn.MouseButton1Click:Connect(function()
		Logger:Debug("Confirm No clicked")
		cleanup()
		if onNo then pcall(onNo) end
	end)

	self.activeConfirmConnections = connections

	return connections
end

return UIManager


-- LocalScript: CinematicHandler
-- Lokasi: Di dalam ScreenGui (StarterGui)

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
-- REFERENSI GUI (Pastikan script ini ada di dalam ScreenGui-nya)
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
local isHolding      = false
local isHidingSkip   = false -- 🔥 FIX 3: Pelindung Animasi Hiding
local holdElapsed    = 0
local holdRequired   = 1.2
local holdConn       = nil
local onSkipCallback = nil

local function resetSkip()
	skipFrame.Visible    = false
	skipFrame.Position   = UDim2.new(1, 20, 0.5, 0)
	progressBar.Size     = UDim2.new(0, 0, 1, 0)
	progressBar.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
end

local function showSkip(onSkip)
	onSkipCallback = onSkip
	isHidingSkip = false
	resetSkip()
	skipFrame.Visible = true
	TweenService:Create(skipFrame,
		TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Position = UDim2.new(1, -175, 0.5, 0) }
	):Play()
end

local function hideSkip()
	if isHidingSkip then return end
	isHidingSkip = true

	if holdConn then holdConn:Disconnect() holdConn = nil end
	isHolding = false

	local t = TweenService:Create(skipFrame,
		TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ Position = UDim2.new(1, 20, 0.5, 0) }
	)
	t:Play()
	t.Completed:Wait()
	resetSkip()

	isHidingSkip = false
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
	isOrbiting = false
	-- Perhatian: skipRequested tidak di-reset di sini agar showCinematic mendeteksinya.
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
			-- Batas waktu 10 detik agar thread mati jika frame error
			local startTime = os.clock()
			while ray and ray.Parent and (os.clock() - startTime < 10) do
				local mt = TweenService:Create(ray, TweenInfo.new(2, Enum.EasingStyle.Linear), {Position = ep})
				mt:Play() 
				mt.Completed:Wait()

				if ray and ray.Parent then 
					ray.Position = ip 
				end
				task.wait(0.05)
			end

			-- Garbage Collection Paksa jika animasi selesai / stuck
			if ray and ray.Parent then
				ray:Destroy()
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

	if skipRequested then resetCinematic() return end

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

	if skipRequested then resetCinematic() return end

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

	-- 🔥 FIX 1: Jeda menunggu durasi Cinematic ATAU di-skip
	local elapsedCinematic = 0
	while elapsedCinematic < duration and not skipRequested do
		elapsedCinematic += task.wait(0.1)
	end

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
-- QUEUE SYSTEM (SISTEM ANTREAN DONASI)
-- ============================================================
local isPlayingCinematic = false
local cinematicQueue = {}

local function processCinematicQueue()
	-- Jika masih ada cinematic yang main, atau antrean kosong, batalkan
	if isPlayingCinematic or #cinematicQueue == 0 then return end
	isPlayingCinematic = true

	local donationData = table.remove(cinematicQueue, 1)

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

	-- Tunggu durasi cinematic selesai sebelum lanjut ke antrean berikutnya
	task.delay(donationData.cinematicDuration or 8, function()
		isPlayingCinematic = false
		processCinematicQueue() -- Lanjut panggil antrean berikutnya
	end)
end

CinematicRemote.OnClientEvent:Connect(function(donationData)
	if not donationData or not donationData.donorName then return end

	if donationData.useCinematic then
		-- Masukkan ke antrean
		table.insert(cinematicQueue, donationData)
		processCinematicQueue()
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
	Players:GetPropertyChangedSignal("LocalPlayer"):task.wait()
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

-- ðŸ’¡ PERBAIKAN DETEKSI DEVICE: HP vs PC
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

		-- ðŸ’¡ HANYA MUNCULKAN MOBILE CONTROLS JIKA PLAYER PAKAI HP!
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

-- 🔥 FIX 1: Menyesuaikan referensi. Karena skrip ditaruh di StarterPlayerScripts,
-- kita memanggil GUI melalui PlayerGui, bukan menggunakan script.Parent.
-- Pastikan nama GUI-mu benar-benar "MyHat"
local gui = PlayerGui:WaitForChild("MyHat") 
local mainframe = gui:WaitForChild("Mainframe")
local equipBtn = mainframe:WaitForChild("EquipBtn")
local unequipBtn = mainframe:WaitForChild("UnequipBtn")

-- 🔥 FIX 2: Sistem Pelindung Anti-Spam (Debounce / Cooldown)
local isProcessing = false
local COOLDOWN_TIME = 0.5 -- Beri jeda 0.5 detik antar klik agar server tidak lag

-- ====================================
-- FUNCTIONS
-- ====================================
local function equipAccessory()
	-- Cegah proses berlanjut jika sedang masa cooldown (anti-spam klik)
	if isProcessing then return end
	isProcessing = true

	AccessoryEvent:FireServer("equip")

	-- Tunggu masa cooldown selesai lalu buka gemboknya lagi
	task.wait(COOLDOWN_TIME)
	isProcessing = false
end

local function unequipAccessory()
	-- Cegah proses berlanjut jika sedang masa cooldown
	if isProcessing then return end
	isProcessing = true

	AccessoryEvent:FireServer("unequip")

	-- Tunggu masa cooldown selesai lalu buka gemboknya lagi
	task.wait(COOLDOWN_TIME)
	isProcessing = false
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
-- PlayerMenuClient (UPDATED DENGAN FITUR LIKE)
-- Letakkan di: StarterGui > [ScreenGui] > LocalScript
-- ============================================

local Players              = game:GetService("Players")
local ReplicatedStorage    = game:GetService("ReplicatedStorage")
local GuiService           = game:GetService("GuiService")
local TextChatService      = game:GetService("TextChatService")
local UserInputService     = game:GetService("UserInputService")
local TweenService         = game:GetService("TweenService")
local RunService           = game:GetService("RunService")
local StarterGui           = game:GetService("StarterGui")

local localPlayer = Players.LocalPlayer
local camera      = workspace.CurrentCamera

-- ============================================
-- CONSTANTS
-- ============================================
local RAYCAST_DISTANCE         = 500
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

-- Remotes untuk fitur Like
local LikePlayerRemote = remotes:WaitForChild("LikePlayer")
local CheckLikeCooldownRemote = remotes:WaitForChild("CheckLikeCooldown")

-- ============================================
-- GUI ELEMENTS
-- ============================================
local gui       = script.Parent
local mainframe = gui:WaitForChild("MainFrame")
local container = mainframe:WaitForChild("Container")

local TemplateFrame = container:WaitForChild("TemplateFrame")
TemplateFrame.Visible = false


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

-- GUI Elements untuk fitur Like (Menyesuaikan dengan struktur Screenshot Anda)
local LikeBtn         = ProfileFrame:WaitForChild("LikeBtn")
-- Menggunakan FindFirstChild untuk mengatasi typo (LovelImage / LoveImage)
local LoveImage       = LikeBtn:WaitForChild("LoveImage", 3) or LikeBtn:WaitForChild("LovelImage", 3)

-- CooldownLabel dan NumberLoveLabel sekarang sejajar dengan PlayerAvatar di dalam ProfileFrame
local CooldownLabel   = ProfileFrame:WaitForChild("CooldownLabel")
local NumberLoveLabel = ProfileFrame:WaitForChild("NumberLoveLabel")

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

-- State untuk Like
local currentCooldownEnd = 0
local isLiking = false

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
-- LIKE SYSTEM HANDLERS
-- ============================================
local function formatTime(seconds)
	if seconds <= 0 then return "00:00:00" end
	local hours = math.floor(seconds / 3600)
	local mins = math.floor((seconds % 3600) / 60)
	local secs = math.floor(seconds % 60)
	return string.format("%02d:%02d:%02d", hours, mins, secs)
end

-- Update total like secara real-time dari Attribute "TotalLikes"
local function setupLikeListener(player)
	player:GetAttributeChangedSignal("TotalLikes"):Connect(function()
		if currentTargetPlayer == player then
			NumberLoveLabel.Text = tostring(player:GetAttribute("TotalLikes") or 0)
		end
	end)
end

for _, player in ipairs(Players:GetPlayers()) do
	setupLikeListener(player)
end
Players.PlayerAdded:Connect(setupLikeListener)

-- Logika Countdown yang terus berjalan
RunService.Heartbeat:Connect(function()
	if currentTargetPlayer and CooldownLabel.Visible then
		local remaining = currentCooldownEnd - os.time()
		if remaining > 0 then
			CooldownLabel.Text = "Cooldown " .. formatTime(remaining)
		else
			CooldownLabel.Visible = false
			LoveImage.ImageColor3 = Color3.fromRGB(255, 255, 255)
		end
	end
end)

-- Tombol Like Diklik
LikeBtn.MouseButton1Click:Connect(function()
	if isLiking or not currentTargetPlayer then return end
	if currentCooldownEnd > os.time() then return end

	isLiking = true
	LoveImage.ImageColor3 = Color3.fromRGB(255, 50, 50)
	playClickSound()

	-- Animasi kecil untuk merespon klik
	local originalSize = LoveImage.Size
	local tweenClick = TweenService:Create(LoveImage, TweenInfo.new(0.1, Enum.EasingStyle.Sine), {Size = UDim2.new(originalSize.X.Scale * 0.8, originalSize.X.Offset, originalSize.Y.Scale * 0.8, originalSize.Y.Offset)})
	tweenClick:Play()
	tweenClick.Completed:Connect(function()
		TweenService:Create(LoveImage, TweenInfo.new(0.2, Enum.EasingStyle.Bounce), {Size = originalSize}):Play()
	end)

	-- Kirim remote ke server
	local success, result = LikePlayerRemote:InvokeServer(currentTargetPlayer.UserId)
	if success and currentTargetPlayer then
		currentCooldownEnd = result
		CooldownLabel.Visible = true
		StarterGui:SetCore("SendNotification", {
			Title = "Like Sent! ❤️",
			Text = "You sent a like to " .. currentTargetPlayer.Name,
			Duration = 3,
		})
		
		-- 🔥 FIX: Lepaskan kuncian tombol agar bisa dipakai lagi nanti!
		isLiking = false
	else
		-- Jika gagal atau target tidak valid, kembalikan UI ke semula
		LoveImage.ImageColor3 = Color3.fromRGB(255, 255, 255)
		if result then
			warn("[LIKE] Failed:", result)
		end
		isLiking = false
	end
end)


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

	-- ✨ OPTIMASI: Hanya pantau Player yang sedang di-hide!
	if shouldHide then
		self:SetupPlayerMonitoring(targetPlayer)
	else
		self:StopPlayerMonitoring(targetPlayer)
	end

	return shouldHide
end

function PlayerHideSystem:IsPlayerHidden(targetPlayer)
	return hiddenPlayers[targetPlayer] == true
end

function PlayerHideSystem:StopPlayerMonitoring(targetPlayer)
	if monitoringConnections[targetPlayer] then
		for _, conn in ipairs(monitoringConnections[targetPlayer]) do
			conn:Disconnect()
		end
		monitoringConnections[targetPlayer] = nil
	end
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

	currentTween.Completed:Once(function(playbackState)
		if playbackState == Enum.PlaybackState.Cancelled then return end

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

-- ====================================
-- OUTFIT CACHE
-- ====================================
local OutfitCache = {}

local function loadAccessoriesForPlayer(targetPlayer)
	clearOutfitTiles()
	outfitItemIds = {}
	outfitPage    = 1

	if OutfitCache[targetPlayer.UserId] then
		outfitItemIds = OutfitCache[targetPlayer.UserId]
		renderOutfitPage()
		return
	end

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
		OutfitCache[targetPlayer.UserId] = outfitItemIds
		renderOutfitPage()
	end)
end


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
local lastSyncTime = 0

local MENU_CONFIG = {
	{
		name = "SyncBtn",
		text = "Coordinate Dance",
		callback = function(targetPlayer)
			local now = os.clock()
			if now - lastSyncTime < 0.5 then return end 
			lastSyncTime = now

			if inputLock or not targetPlayer then 
				return 
			end

			if not targetPlayer.Parent then 
				return 
			end 

			inputLock = true

			local syncTarget = localPlayer.Character and localPlayer.Character:GetAttribute("Syncing")

			if isSyncing and syncTarget == targetPlayer.Name then
				startSyncRE:FireServer(targetPlayer, false)
			else
				startSyncRE:FireServer(targetPlayer, true)
			end

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
				isSyncing = true

				if currentTargetPlayer and currentTargetPlayer.Name == syncTarget then
					button.Text            = "Unsync Dance"
					button.AutoButtonColor = true  
					button.Active          = true  
					local stroke = button:FindFirstChild("UIStroke")
					if stroke then stroke.Color = Color3.fromRGB(255, 100, 100) end 
				else
					button.Text            = "Switch Dance"
					button.AutoButtonColor = true
					button.Active          = true  
					local stroke = button:FindFirstChild("UIStroke")
					if stroke then stroke.Color = Color3.fromRGB(255, 255, 255) end
				end
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
	local character = localPlayer.Character or localPlayer.CharacterAdded:task.wait()
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
local function updatePlayerInfo(targetPlayer, onReady)
	namelabel.Text     = targetPlayer.DisplayName
	usernamelabel.Text = "@" .. targetPlayer.Name

	playerAvatar.Image                  = "rbxthumb://type=Avatar&id=" .. targetPlayer.UserId .. "&w=352&h=352"
	playerAvatar.BackgroundColor3       = Color3.fromRGB(0, 0, 0)
	playerAvatar.BackgroundTransparency = 1

	Playerbio.Text       = "Loading..."
	Connectionlabel.Text = "Connections ..."
	FollowersLabel.Text  = "Followers ..."
	FollowingLabel.Text  = "Following ..."

	-- Reset UI Like System
	CooldownLabel.Visible = false
	LoveImage.ImageColor3 = Color3.fromRGB(255, 255, 255)
	NumberLoveLabel.Text  = tostring(targetPlayer:GetAttribute("TotalLikes") or 0)

	loadAccessoriesForPlayer(targetPlayer)

	if onReady then onReady() end

	task.spawn(function()
		-- Fetch Data Player
		local getPlayerInfoRF = remotes:FindFirstChild("GetPlayerInfo")
		local profileData     = nil

		if getPlayerInfoRF then
			local ok, data = pcall(function()
				return getPlayerInfoRF:InvokeServer(targetPlayer.UserId)
			end)
			if ok and data then
				profileData = data
			end
		end

		-- Fetch Cooldown Data
		local cdOk, cdData = pcall(function()
			return CheckLikeCooldownRemote:InvokeServer(targetPlayer.UserId)
		end)

		if currentTargetPlayer ~= targetPlayer then return end

		-- Update Social Stats
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

		-- Update Like Status
		if cdOk and cdData then
			currentCooldownEnd = cdData.cooldownTime or 0
			if currentCooldownEnd > os.time() then
				LoveImage.ImageColor3 = Color3.fromRGB(255, 50, 50)
				CooldownLabel.Visible = true
			else
				LoveImage.ImageColor3 = Color3.fromRGB(255, 255, 255)
				CooldownLabel.Visible = false
			end
			NumberLoveLabel.Text = tostring(cdData.targetLikes or targetPlayer:GetAttribute("TotalLikes") or 0)
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
UserInputService.InputBegan:Connect(function(inputObject, gameProcessedEvent)
	if inputObject.UserInputType ~= Enum.UserInputType.MouseButton1 and inputObject.UserInputType ~= Enum.UserInputType.Touch then
		return
	end

	if gameProcessedEvent then return end

	local currentTime = os.clock()
	if currentTime - lastClickTime < CLICK_COOLDOWN then return end

	local inputPosition = inputObject.Position

	if mainframe.Visible and isPointInsideFrame(mainframe, inputPosition) then
		return 
	end

	if mainframe.Visible then
		closeMenu()
		return 
	end

	if isLoadingMenu then return end

	local targetPlayer = raycastFromScreen(inputPosition)
	if targetPlayer then
		local inRange, distance = isPlayerInRange(targetPlayer, MAX_INTERACTION_DISTANCE)
		if not inRange then
			warn("[PLAYER MENU] Player terlalu jauh:", math.floor(distance), "studs")
			return
		end
		lastClickTime = currentTime
		setTargetPlayer(targetPlayer)
	end
end)

-- ============================================
-- INITIALIZE
-- ============================================
Players.PlayerRemoving:Connect(function(player)
	hiddenPlayers[player] = nil
	OutfitCache[player.UserId] = nil
	if monitoringConnections[player] then
		for _, conn in ipairs(monitoringConnections[player]) do
			conn:Disconnect()
		end
		monitoringConnections[player] = nil
	end
end)

createMenuButtons()
updatePaginationButtons()

-- ============================================
-- CLEANUP
-- ============================================
script.Destroying:Connect(function()
	if syncConnection then syncConnection:Disconnect() end
	if currentTween   then currentTween:Cancel() end

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


local l__ReplicatedStorage__1 = game:GetService("ReplicatedStorage");
local l__Players__2 = game:GetService("Players");
local l__Debris__3 = game:GetService("Debris");
local l__RunService__4 = game:GetService("RunService");
local l__TweenService__1 = game:GetService("TweenService");
local l__Lighting__4 = game:GetService("Lighting");
local UserInputService = game:GetService("UserInputService")
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local u4 = Vector3.new(-136, 2.438, -443);
local doit = false
local ticking = false

-- ==========================================
-- 🔥 CONFIG: SAWERIA / ROBUX TOGGLE
-- ==========================================
local USE_RUPIAH = true -- Ubah ke 'false' jika ingin mode Robux!

function comma(p1)
	local v2 = p1;
	while true do
		local v3, v4 = string.gsub(v2, "^(-?%d+)(%d%d%d)", "%1,%2");
		local k = v4;
		v2 = v3;
		if k ~= 0 then

		else
			break;
		end;	
	end;
	return v2;
end;

local function event(donator, reciever, amount)	

	local function tweening(p3, p4, p5)
		l__TweenService__1:Create(p3, TweenInfo.new(p4, Enum.EasingStyle.Quint), p5):Play();
	end;

	local function u2(p1, p2)
		p1.Speed = NumberRange.new(p1.Speed.Min * p2, p1.Speed.Max * p2);
		p1.Acceleration = p1.Acceleration * p2;
		local l__Keypoints__5 = p1.Size.Keypoints;
		local v6 = {};
		for v7 = 1, #l__Keypoints__5 do
			table.insert(v6, NumberSequenceKeypoint.new(l__Keypoints__5[v7].Time, l__Keypoints__5[v7].Value * p2, l__Keypoints__5[v7].Envelope * p2));
		end;
		p1.Size = NumberSequence.new(v6);
	end;
	local v22 = Instance.new("ColorCorrectionEffect");
	v22.Enabled = true;
	v22.Name = "EventColorCorrection";
	v22.Parent = game.Lighting;
	local v23 = Instance.new("BloomEffect");
	v23.Enabled = true;
	v23.Name = "SmiteBloom";
	v23.Size = 20;
	v23.Threshold = 0.1;
	v23.Intensity = -1;
	v23.Parent = game.Lighting;
	local u6 = math.random(-180, 180);
	local v11 = game.ReplicatedStorage.VFX.Templates.Live:Clone()

	-- 🔥 OPTIMASI HP KENTANG
	if isMobile then
		for _, obj in pairs(v11:GetDescendants()) do
			if obj:IsA("ParticleEmitter") then
				obj.Rate = obj.Rate * 0.25 -- Kurangi partikel sisa 25%
			elseif obj:IsA("PointLight") or obj:IsA("SurfaceLight") then
				obj.Shadows = false -- Matikan bayangan
			end
		end
	end

	local v5 = v11.Objects.NPC:Clone()
	local v16 = v11.Objects.FloorAmbiance:Clone();
	local v17 = v11.Objects.Ambiance:Clone();
	local impact = v11.Objects.ImpactVisuals
	local u18 = v11.Objects.Heavenball:Clone()
	local v67 = v11.Objects.Whitehole:Clone()
	local v68 = v11.Objects.Whitehole2:Clone()
	local v69 = v11.Objects.Whitehole3:Clone()
	local v70 = v11.Objects.Whitehole4:Clone()
	local v38 = v16:Clone();
	v38.Position = u4 + Vector3.new(0, -0.5, 0);
	v38.Parent = workspace;
	local v39 = v17:Clone();
	v39.Position = u4 + Vector3.new(0, 0, 0);
	v39.Size = Vector3.new(1000, 1000, 1000);
	v39.CFrame = v39.CFrame:ToWorldSpace(CFrame.Angles(0, math.rad(u6), 0.5235987755982988));
	v39.Position = v39.Position + v39.CFrame.UpVector * 600;
	v39.Parent = workspace;
	l__TweenService__1:Create(v38, TweenInfo.new(10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0), {
		Size = Vector3.new(2048, 1, 2048)
	}):Play();
	local v19 = v11.Objects.Orb:Clone();
	local v15 = v11.Objects.Meteor:Clone();
	local u3 = require(script.CameraShaker);
	local l__Sounds__20 = v11.Sounds:Clone()
	l__Sounds__20.Parent = game.Workspace
	local v24 = u3.new(Enum.RenderPriority.Camera.Value, function(p9)
		workspace.CurrentCamera.CFrame = workspace.CurrentCamera.CFrame * p9;
	end);

	l__TweenService__1:Create(v22, TweenInfo.new(10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0), {
		TintColor = Color3.fromRGB(255, 128, 255), 
		Brightness = 0.25, 
		Saturation = 0.1, 
		Contrast = 0.25
	}):Play();

	local v25 = v19:Clone();
	v25.Parent = workspace;
	v25.Position = Vector3.new(-232, 126.381, -443)

	v24:Start();
	v24:ShakeSustain(u3.Presets.Earthquake);

	local ambiance = l__Sounds__20.Ambiance:Clone()
	ambiance.Parent = workspace
	ambiance:Play()

	for v1, v2 in pairs(v25.Attachment:GetChildren()) do
		if v2:IsA("ParticleEmitter") then
			u2(v2, 1.75);
			v2.Enabled = true;
		end;
	end;

	for v40, v41 in pairs(v38:GetChildren()) do
		if v41:IsA("ParticleEmitter") then
			u2(v41, 1.75);
			v41.Enabled = true;
		end;
	end;
	for v42, v43 in pairs(v39:GetChildren()) do
		if v43:IsA("ParticleEmitter") then
			u2(v43, 2.5);
			v43.Enabled = true;
		end;
	end;

	local u8 = true;
	local u9 = 0.5;
	task.spawn(function()
		while u8 == true do
			task.wait(u9);
			task.spawn(function()
				local v30 = math.random(100, 400) / 100;
				local v31 = math.random(250, 400) / 100;
				local v32 = math.random(500, 750);
				local v33 = v15:Clone();
				v33.Parent = workspace;
				v33.Transparency = 1;
				v33.Position = u4 + Vector3.new(math.random(-750, 750), 0, math.random(-750, 750));
				v33.Size = v33.Size * v30;
				v33.CFrame = v33.CFrame:ToWorldSpace(CFrame.Angles(math.rad(math.random(-10, 10)), math.rad(u6), 0.5235987755982988));
				v33.Position = v33.Position + v33.CFrame.UpVector * v32;
				for v34, v35 in pairs(v33:GetDescendants()) do
					if v35:IsA("ParticleEmitter") then
						u2(v35, v30);
						if string.find(v35.Name, "Meteor_") ~= nil then
							v35.Enabled = true;
						end;
					end;
				end;
				v33.Glow.Range = v33.Glow.Range * v30;
				v33.Glow.Enabled = true;
				v33.Trail0.Position = v33.Trail0.Position * (v30 / 2);
				v33.Trail1.Position = v33.Trail1.Position * (v30 / 2);
				v33.Trail.Enabled = true;
				v33.Whoosh.Volume = 0;
				v33.Whoosh.TimePosition = math.random(0, v33.Whoosh.TimeLength);
				v33.Whoosh.PlaybackSpeed = 1.5 - v30 * 0.15;
				v33.Impact.PlaybackSpeed = 1.5 - v30 * 0.15;
				v33.Whoosh.Playing = true;
				l__TweenService__1:Create(v33, TweenInfo.new(v31, Enum.EasingStyle.Sine, Enum.EasingDirection.In, 0, false, 0), {
					Position = v33.Position + v33.CFrame.UpVector * -v32, 
					Orientation = Vector3.new(math.random(-180, 180) * 3, math.random(-180, 180) * 3, math.random(-180, 180) * 3)
				}):Play();
				l__TweenService__1:Create(v33, TweenInfo.new(v31 * 0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0), {
					Transparency = 0
				}):Play();
				l__TweenService__1:Create(v33.Whoosh, TweenInfo.new(v31 * 0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0), {
					Volume = 1
				}):Play();
				task.wait(v31);
				v33.Transparency = 1;
				v33.Orientation = Vector3.new(0, 0, 0);
				v33.Glow.Range = v33.Glow.Range * 1.5;
				v33.Glow.Brightness = v33.Glow.Brightness * 3;
				l__TweenService__1:Create(v33.Glow, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0), {
					Brightness = 0, 
					Range = v33.Glow.Range / 2
				}):Play();
				for v36, v37 in pairs(v33:GetDescendants()) do
					if v37:IsA("ParticleEmitter") then
						if string.find(v37.Name, "Meteor_") ~= nil then
							v37.Enabled = false;
						end;
						if string.find(v37.Name, "Explosion_") ~= nil then
							v37:Emit(v37:GetAttribute("EmitCount"));
						end;
					end;
				end;
				v33.Trail.Enabled = false;
				v33.Whoosh.Playing = false;
				v33.Impact:Play();
				task.wait(3);
				v33:Destroy();
			end);		
		end;
	end);

	task.spawn(function()
		l__Sounds__20.Summon:Play();
		l__Sounds__20.Earthquake:Play();
		v25.PortalAmbiance.Playing = true;
		v25.PortalOpen1:Play();
		v25.PortalOpen2:Play();
		l__TweenService__1:Create(v25.PortalAmbiance, TweenInfo.new(3, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, 0, false, 0), {
			Volume = 1.5, 
			PlaybackSpeed = 1.25
		}):Play();
		l__TweenService__1:Create(v25, TweenInfo.new(7, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, 0, false, 0), {
			Size = Vector3.new(50,50,50)
		}):Play();
		l__Sounds__20.CrumbleLoop.Playing = true;
		l__TweenService__1:Create(l__Sounds__20.CrumbleLoop, TweenInfo.new(3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0), {
			Volume = 0.5
		}):Play();
		l__Sounds__20.FireLoop.Playing = true;
		l__TweenService__1:Create(l__Sounds__20.FireLoop, TweenInfo.new(5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0), {
			Volume = 0.5, 
			PlaybackSpeed = 1
		}):Play();
		v24:ShakeSustain(u3.Presets.Earthquake);
		task.wait(7);
		l__TweenService__1:Create(l__Sounds__20.CrumbleLoop, TweenInfo.new(10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0), {
			Volume = 0
		}):Play();
		v24:StopSustained(6);
		l__TweenService__1:Create(v25.PortalAmbiance, TweenInfo.new(5, Enum.EasingStyle.Sine, Enum.EasingDirection.In, 0, false, 0), {
			Volume = 0, 
			PlaybackSpeed = 0
		}):Play();
	end)

	task.wait(math.random(14, 19))
	v67.Parent = workspace
	v68.Parent = workspace
	v69.Parent = workspace
	v70.Parent = workspace
	local heavenball = u18:Clone()
	local charge = l__Sounds__20.Charge_2:Clone()
	charge.Parent = heavenball
	heavenball.Parent = workspace
	charge:Play()
	task.wait(1.25)
	doit = true
	if doit then
		tweening(heavenball, 6, {
			Transparency = 0
		});
		local ending = l__Sounds__20.ChargeEndSound:Clone()
		ending.Parent = heavenball
		ending:Play()
		task.wait(1.5)
		v67:Destroy()
		v68:Destroy()
		v69:Destroy()
		v70:Destroy()
		charge:Destroy()
		ending:Destroy()
		l__Sounds__20.Twinkle:Play()
		l__TweenService__1:Create(heavenball, TweenInfo.new(3, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, 0, false, 0), {
			Position = Vector3.new(-232, 126.381, -443) 
		}):Play();
		task.wait(1.25)

		doit = false
	end

	if not doit then
		l__TweenService__1:Create(heavenball, TweenInfo.new(3, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, 0, false, 0), {
			Size = Vector3.new(50,50,50)
		}):Play();
		l__Sounds__20.CrumbleLoop.Playing = true;
		l__TweenService__1:Create(l__Sounds__20.CrumbleLoop, TweenInfo.new(3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0), {
			Volume = 0.5
		}):Play();
		l__Sounds__20.Sparkle:Play()
		v24:ShakeSustain(u3.Presets.Earthquake);
		task.wait(3)
		ticking = true
	end

	if ticking then
		local ticksound = l__Sounds__20.Tick:Clone()
		ticksound.Parent = workspace
		ticksound.Playing = true
		l__Lighting__4.ClockTime = 10
		l__Lighting__4.FogColor = Color3.fromRGB(144, 228, 248)
		task.wait(1)
		l__Lighting__4.ClockTime = 0
		l__Lighting__4.FogColor = Color3.fromRGB(0,0,0)
		task.wait(1)
		l__Lighting__4.ClockTime = 10
		l__Lighting__4.FogColor = Color3.fromRGB(144, 228, 248)
		task.wait(1)
		l__Lighting__4.ClockTime = 0
		l__Lighting__4.FogColor = Color3.fromRGB(0,0,0)
		task.wait(1)
		l__Lighting__4.ClockTime = 10
		l__Lighting__4.FogColor = Color3.fromRGB(144, 228, 248)
		task.wait(1)
		l__Lighting__4.ClockTime = 0
		l__Lighting__4.FogColor = Color3.fromRGB(0,0,0)
		task.wait(1)
		l__Lighting__4.ClockTime = 10
		l__Lighting__4.FogColor = Color3.fromRGB(144, 228, 248)
		task.wait(1)
		l__Lighting__4.ClockTime = 0
		l__Lighting__4.FogColor = Color3.fromRGB(0,0,0)
		task.wait(1)
		l__Lighting__4.ClockTime = 10
		l__Lighting__4.FogColor = Color3.fromRGB(144, 228, 248)
		task.wait(1)
		l__Lighting__4.ClockTime = 0
		l__Lighting__4.FogColor = Color3.fromRGB(0,0,0)
		task.wait(1)
		l__Lighting__4.ClockTime = 10
		l__Lighting__4.FogColor = Color3.fromRGB(144, 228, 248)
		task.wait(1)
		l__Lighting__4.ClockTime = 0
		l__Lighting__4.FogColor = Color3.fromRGB(0,0,0)
		task.wait(1)
		l__Lighting__4.ClockTime = 10
		l__Lighting__4.FogColor = Color3.fromRGB(144, 228, 248)
		task.wait(1)
		l__Lighting__4.ClockTime = 0
		l__Lighting__4.FogColor = Color3.fromRGB(0,0,0)
		task.wait(1)
		l__Lighting__4.ClockTime = 10
		l__Lighting__4.FogColor = Color3.fromRGB(144, 228, 248)
		task.wait(1)
		l__Lighting__4.ClockTime = 0
		l__Lighting__4.FogColor = Color3.fromRGB(0,0,0)
		task.wait(1)
		ticksound:Stop()
		ticksound:Destroy()
		task.wait(5)
		ticking = false
	end

	if not ticking then
		v24:StopSustained(6);

		l__TweenService__1:Create(l__Sounds__20.CrumbleLoop, TweenInfo.new(10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0), {
			Volume = 0
		}):Play();
		task.wait(1)
		l__TweenService__1:Create(v25, TweenInfo.new(10, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, 0, false, 0), {
			Size = Vector3.new(75,75,75)
		}):Play();
		l__TweenService__1:Create(heavenball, TweenInfo.new(10, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, 0, false, 0), {
			Size = Vector3.new(74,74,74)
		}):Play();
		for l1, l2 in pairs(v25.Attachment:GetChildren()) do
			if l2:IsA("ParticleEmitter") then
				u2(l2, 2);
			end;
		end;
		task.wait(10)
		for l1, l2 in pairs(v25.Attachment:GetChildren()) do
			if l2:IsA("ParticleEmitter") then
				l2.Rate = 0
			end;
		end;
		v24:ShakeOnce(8, 20, 1, 6);
		l__TweenService__1:Create(v25.Beams.FlameEffect1, TweenInfo.new(1.7, Enum.EasingStyle.Linear), {
			Brightness = 1.57
		}):Play();
		l__TweenService__1:Create(v25.Beams.FlameEffect2, TweenInfo.new(1.7, Enum.EasingStyle.Linear), {
			Brightness = 1.57
		}):Play();
		l__TweenService__1:Create(v25.Beams.FlameEffect3, TweenInfo.new(1.7, Enum.EasingStyle.Linear), {
			Brightness = 1.57
		}):Play();
		l__TweenService__1:Create(v25.Beams.FlameEffect4, TweenInfo.new(1.7, Enum.EasingStyle.Linear), {
			Brightness = 1.57
		}):Play();
		l__TweenService__1:Create(v25.Beams.FlameEffect5, TweenInfo.new(1.7, Enum.EasingStyle.Linear), {
			Brightness = 1.57
		}):Play();
		l__TweenService__1:Create(v25.Beams.FlameEffect6, TweenInfo.new(1.7, Enum.EasingStyle.Linear), {
			Brightness = 1.57
		}):Play();
		l__TweenService__1:Create(v25.Beams.FlameEffect7, TweenInfo.new(1.7, Enum.EasingStyle.Linear), {
			Brightness = 1.57
		}):Play();
		l__TweenService__1:Create(v25.Beams.FlameEffect8, TweenInfo.new(1.7, Enum.EasingStyle.Linear), {
			Brightness = 1.57
		}):Play();
		l__TweenService__1:Create(v25.Beams.FlameEffect9, TweenInfo.new(1.7, Enum.EasingStyle.Linear), {
			Brightness = 1.57
		}):Play();
		l__TweenService__1:Create(v25.Beams.FlameEffect10, TweenInfo.new(1.7, Enum.EasingStyle.Linear), {
			Brightness = 1.57
		}):Play();
		l__TweenService__1:Create(v25.Beams.FlameEffect11, TweenInfo.new(1.7, Enum.EasingStyle.Linear), {
			Brightness = 1.57
		}):Play();
		l__TweenService__1:Create(v25.Beams.FlameEffect12, TweenInfo.new(1.7, Enum.EasingStyle.Linear), {
			Brightness = 1.57
		}):Play();
		l__TweenService__1:Create(game.Lighting, TweenInfo.new(1.7), {
			Brightness = 5
		}):Play();
		l__TweenService__1:Create(v25, TweenInfo.new(1.7, Enum.EasingStyle.Cubic, Enum.EasingDirection.In), {Position = Vector3.new(-136, 2.438, -443)}):Play() 
		l__TweenService__1:Create(heavenball, TweenInfo.new(1.7, Enum.EasingStyle.Cubic, Enum.EasingDirection.In), {Position = Vector3.new(-136, 2.438, -443)}):Play()
		v25.FlameEffect1_0.BrightFlare.Enabled = true;
		v25.Flames.Enabled = true;
		v25.FlameEffect1_0.FlameRing.Enabled = true;
		v25.FlameEffect1_0.Flames1.Enabled = true;
		v25.FlameEffect1_0.Flames2.Enabled = true;
		v25.FlameEffect1_0.Flames3.Enabled = true;
		l__Sounds__20.Drop1:Play()
		l__Sounds__20.Drop2:Play()
		v25.LaunchSound:Play();
		task.wait(1.7)
		l__Sounds__20.ExplosionSound:Play()
		l__Sounds__20.Sparkle:Stop()
		ambiance:Destroy()
		v23.Intensity = 0.75
		v23.Threshold = 0.05
		v22.Contrast = 0
		l__TweenService__1:Create(v23, TweenInfo.new(10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0), {
			Intensity = -0.9, 
			Threshold = 0.1
		}):Play()
		l__TweenService__1:Create(v22, TweenInfo.new(10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0), {
			Contrast = 0.25
		}):Play()
		v24:ShakeOnce(12, 4, 1, 6);
		v25.SelectionSphere:Destroy()
		v25.FlameEffect1_0.BrightFlare.Enabled = false;
		v25.Flames.Enabled = false;
		v25.FlameEffect1_0.FlameRing.Enabled = false;
		v25.FlameEffect1_0.Flames1.Enabled = false;
		v25.FlameEffect1_0.Flames2.Enabled = false;
		v25.FlameEffect1_0.Flames3.Enabled = false;
		l__TweenService__1:Create(v25.Beams.FlameEffect1, TweenInfo.new(0.01, Enum.EasingStyle.Linear), {
			Brightness = 0
		}):Play();
		l__TweenService__1:Create(v25.Beams.FlameEffect2, TweenInfo.new(0.01, Enum.EasingStyle.Linear), {
			Brightness = 0
		}):Play();
		l__TweenService__1:Create(v25.Beams.FlameEffect3, TweenInfo.new(0.01, Enum.EasingStyle.Linear), {
			Brightness = 0
		}):Play();
		l__TweenService__1:Create(v25.Beams.FlameEffect4, TweenInfo.new(0.01, Enum.EasingStyle.Linear), {
			Brightness = 0
		}):Play();
		l__TweenService__1:Create(v25.Beams.FlameEffect5, TweenInfo.new(0.01, Enum.EasingStyle.Linear), {
			Brightness = 0
		}):Play();
		l__TweenService__1:Create(v25.Beams.FlameEffect6, TweenInfo.new(0.01, Enum.EasingStyle.Linear), {
			Brightness = 0
		}):Play();
		l__TweenService__1:Create(v25.Beams.FlameEffect7, TweenInfo.new(0.01, Enum.EasingStyle.Linear), {
			Brightness = 0
		}):Play();
		l__TweenService__1:Create(v25.Beams.FlameEffect8, TweenInfo.new(0.01, Enum.EasingStyle.Linear), {
			Brightness = 0
		}):Play();
		l__TweenService__1:Create(v25.Beams.FlameEffect9, TweenInfo.new(0.01, Enum.EasingStyle.Linear), {
			Brightness = 0
		}):Play();
		l__TweenService__1:Create(v25.Beams.FlameEffect10, TweenInfo.new(0.01, Enum.EasingStyle.Linear), {
			Brightness = 0
		}):Play();
		l__TweenService__1:Create(v25.Beams.FlameEffect11, TweenInfo.new(0.01, Enum.EasingStyle.Linear), {
			Brightness = 0
		}):Play();
		l__TweenService__1:Create(v25.Beams.FlameEffect12, TweenInfo.new(0.01, Enum.EasingStyle.Linear), {
			Brightness = 0
		}):Play();
		l__TweenService__1:Create(game.Lighting, TweenInfo.new(0.2), {
			Brightness = 150
		}):Play();
		l__TweenService__1:Create(game.Lighting.ColorCorrection, TweenInfo.new(0.05), {
			Brightness = 1.2
		}):Play();
		task.wait(0.05);
		l__TweenService__1:Create(game.Lighting.ColorCorrection, TweenInfo.new(3), {
			Brightness = 0.05
		}):Play();
		l__TweenService__1:Create(game.Lighting, TweenInfo.new(7), {
			Brightness = 2.66
		}):Play();
		impact.Parent = game.Workspace
		impact.Position = Vector3.new(-136, 2.438, -443)
		l__TweenService__1:Create(impact, TweenInfo.new(30), {Position = Vector3.new(u4.X, 500, u4.Z)}):Play()
		impact.ApplauseLoop:Play()
		impact.CoinsLoop:Play()
		impact.ChimeLoop:Play()
		impact.EmitPoint.Impact_Spark1:Emit(45)
		impact.EmitPoint.Impact_Spark2:Emit(75)
		impact.EmitPoint.Impact_Spark3:Emit(35)
		impact.EmitPoint.Explosion_Glow:Emit(25)
		impact.EmitPoint.Explosion_Rays:Emit(45)
		impact.EmitPoint.Explosion_Ring:Emit(5)
		impact.EmitPoint.Explosion_Flare:Emit(50)
		impact.EmitPoint.Explosion_ThinRays:Emit(35)
		impact.EmitPoint.Explosion_Shockwave:Emit(15)

		local v18 = impact.BillboardGuiAnimation.Frame

		local function preserveExactCase(username)
			return username
		end

		-- 🔥 SAWERIA TOGGLE INJECTION
		local formattedAmount = tostring(amount):reverse():gsub("%d%d%d", "%1."):reverse():gsub("^%.", "")
		v18.TopText.Text = "@" .. preserveExactCase(donator) .. " DONATED"
		v18.BottomText.Text = "TO @" .. preserveExactCase(reciever)

		if USE_RUPIAH then
			-- Gunakan Non-Breaking Space
			v18.MiddleText.Text = "Rp\u{00A0}" .. formattedAmount
			v18.RobuxLogo.Visible = false
		else
			v18.MiddleText.Text = formattedAmount
			v18.RobuxLogo.Visible = true
			v18.RobuxLogo.Size = UDim2.fromScale(0,0)
			v18.RobuxLogo.Rotation = -180
		end

		v18.Star.Size = UDim2.fromScale(0,0)
		v18.BottomText.Size = UDim2.fromScale(0,0)
		v18.MiddleText.Size = UDim2.fromScale(0,0)
		v18.TopText.Size = UDim2.fromScale(0,0)
		v18.Star.Rotation = 0
		v18.Star.ImageTransparency = 0.9

		-- 🔥 Cegah animasi error jika Logo dimatikan
		if not USE_RUPIAH then
			l__TweenService__1:Create(v18.RobuxLogo, TweenInfo.new(15, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out, 0, false, 0), {Size = UDim2.fromScale(1,1)}):Play()
			l__TweenService__1:Create(v18.RobuxLogo, TweenInfo.new(10, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out, 0, false, 0), {Rotation = 0}):Play()
		end

		l__TweenService__1:Create(v18.Star, TweenInfo.new(10), {Rotation = 360}):Play()
		l__TweenService__1:Create(v18.Star, TweenInfo.new(10), {ImageTransparency = 1}):Play()

		task.wait(.25)
		l__TweenService__1:Create(v18.TopText, TweenInfo.new(5, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out, 0, false, 0), {Size = UDim2.fromScale(1.5, 0.1)}):Play()
		task.wait(.25)
		l__TweenService__1:Create(v18.MiddleText, TweenInfo.new(5, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out, 0, false, 0), {Size = UDim2.fromScale(1, 1)}):Play()
		task.wait(.25)
		l__TweenService__1:Create(v18.BottomText, TweenInfo.new(5, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out, 0, false, 0), {Size = UDim2.fromScale(1.5, 0.1)}):Play()
		l__TweenService__1:Create(v25, TweenInfo.new(0.4, Enum.EasingStyle.Cubic, Enum.EasingDirection.In), {
			Transparency = 1
		}):Play();
		l__TweenService__1:Create(heavenball, TweenInfo.new(0.4, Enum.EasingStyle.Cubic, Enum.EasingDirection.In), {
			Transparency = 1
		}):Play();
		impact.EmitPoint.Sparks.Enabled = true
		impact.EmitPoint.SparkleExplosion.Enabled = true
		task.wait(15)
		l__TweenService__1:Create(impact.ChimeLoop, TweenInfo.new(60),{Volume = 0}):Play()
		l__TweenService__1:Create(impact.ApplauseLoop, TweenInfo.new(60),{Volume = 0}):Play()
		l__TweenService__1:Create(impact.CoinsLoop, TweenInfo.new(30),{Volume = 0}):Play()
		heavenball:Remove();
		task.wait(15)
		v25:Destroy();
		l__TweenService__1:Create(v18, TweenInfo.new(14, Enum.EasingStyle.Quint, Enum.EasingDirection.In, 0, false, 0),{Size = UDim2.fromScale(0,0)}):Play()
		for i,v in pairs(impact.EmitPoint:GetChildren()) do
			if v:IsA("ParticleEmitter") then
				l__TweenService__1:Create(v, TweenInfo.new(14), {Rate = 0}):Play()
			end
		end
		task.wait(15)
		v18:Destroy()
		task.wait(45)
		impact.CoinsLoop:Stop()
		impact.ApplauseLoop:Stop()
		impact.ChimeLoop:Stop()
		u8 = false;

		l__TweenService__1:Create(l__Sounds__20.FireLoop, TweenInfo.new(7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0), {
			Volume = 0, 
			PlaybackSpeed = 0.5
		}):Play()

		for l44, l45 in pairs(v38:GetChildren()) do
			if l45:IsA("ParticleEmitter") then
				l__TweenService__1:Create(l45, TweenInfo.new(7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0), {
					Rate = 0
				}):Play()
			end
		end
		for l46, l47 in pairs(v39:GetChildren()) do
			if l47:IsA("ParticleEmitter") then
				l__TweenService__1:Create(l47, TweenInfo.new(7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0), {
					Rate = 0
				}):Play()
			end
		end

		l__TweenService__1:Create(l__Lighting__4, TweenInfo.new(7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0), {
			ClockTime = 14,
			Brightness = 2
		}):Play()

		local baseCC = l__Lighting__4:FindFirstChild("ColorCorrection")
		if baseCC then
			l__TweenService__1:Create(baseCC, TweenInfo.new(7), {Brightness = 0}):Play()
		end

		l__TweenService__1:Create(v22, TweenInfo.new(7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0), {
			TintColor = Color3.fromRGB(255, 255, 255), 
			Brightness = 0, 
			Saturation = 0, 
			Contrast = 0
		}):Play()
		l__TweenService__1:Create(v23, TweenInfo.new(7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0), {
			Intensity = -1
		}):Play()

		task.wait(7)

		if v22 then v22:Destroy() end
		if v23 then v23:Destroy() end
		if l__Sounds__20 then l__Sounds__20:Destroy() end
		if v38 then v38:Destroy() end
		if v39 then v39:Destroy() end
		if impact then impact:Destroy() end

		l__Lighting__4.FogColor = Color3.fromRGB(192, 192, 192)
		ticking = false
		doit = false
	end
end

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local FireBlackHoleEvent = ReplicatedStorage:WaitForChild("FireBlackHole", 10)

if FireBlackHoleEvent then
	FireBlackHoleEvent.OnClientEvent:Connect(function(donator, reciever, amount)
		event(donator, reciever, amount)
	end)
end

local l__ReplicatedStorage__1 = game:GetService("ReplicatedStorage")
local l__LocalPlayer__2 = game.Players.LocalPlayer
local l__Debris__3 = game:GetService("Debris")
local l__TweenService__1 = game:GetService("TweenService")
local l__PhysicsService__2 = game:GetService("PhysicsService")
local u3 = require(script.CameraShaker)
local u4 = Vector3.new(-106, 2.938, -442.5) 
local UserInputService = game:GetService("UserInputService")
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled


-- ==========================================
-- 🔥 CONFIG: SAWERIA / ROBUX TOGGLE
-- ==========================================
local USE_RUPIAH = true -- Ubah ke 'false' jika ingin mode Robux!

local function u5(p1, p2)
	p1.Speed = NumberRange.new(p1.Speed.Min * p2, p1.Speed.Max * p2)
	p1.Acceleration = p1.Acceleration * p2
	local l__Keypoints__4 = p1.Size.Keypoints
	local v5 = {}
	for v6 = 1, #l__Keypoints__4 do
		table.insert(v5, NumberSequenceKeypoint.new(l__Keypoints__4[v6].Time, l__Keypoints__4[v6].Value * p2, l__Keypoints__4[v6].Envelope * p2))
	end
	p1.Size = NumberSequence.new(v5)
end
local l__RunService__6 = game:GetService("RunService")
local function u7(p3, p4, p5, p6)
	local v7 = p3:Clone()

	-- 🔥 OPTIMASI HP KENTANG
	if isMobile then
		for _, obj in pairs(v7:GetDescendants()) do
			if obj:IsA("ParticleEmitter") then
				obj.Rate = obj.Rate * 0.25
			elseif obj:IsA("PointLight") or obj:IsA("SurfaceLight") then
				obj.Shadows = false
			end
		end
	end

	local l__NukeCFrame__8 = v7.NukeValues.NukeCFrame
	local l__Frame__9 = v7.BillboardGuiAnimation.Frame
	l__Frame__9.TextLabels.TopText.Visible = true
	l__Frame__9.TextLabels.BottomText.Visible = true
	local l__CenterEmitPoint__10 = v7.CenterEmitPoint
	local l__ThrustEmitPoint__11 = v7.ThrustEmitPoint
	local v12 = Instance.new("BloomEffect")
	v12.Enabled = true
	v12.Name = "NukeBloom"
	v12.Size = 15
	v12.Threshold = 0.25
	v12.Intensity = -1
	v12.Parent = game.Lighting
	local l__Objects__13 = v7.Objects
	local v14 = l__Objects__13.ConfettiBox:Clone()
	l__Objects__13.ConfettiBox:Destroy()
	l__Objects__13:Destroy()
	local v15 = u3.new(Enum.RenderPriority.Camera.Value, function(p7)
		workspace.CurrentCamera.CFrame = workspace.CurrentCamera.CFrame * p7
	end)
	v15:Start()
	v7.Position = u4
	u5(l__ThrustEmitPoint__11.Flame, 5)
	u5(l__ThrustEmitPoint__11.Shockwave, 15)
	u5(l__ThrustEmitPoint__11.BigShockwave, 50)
	u5(l__ThrustEmitPoint__11.Flame2, 5)
	u5(l__ThrustEmitPoint__11.Flame3, 5)
	u5(l__ThrustEmitPoint__11.Flame4, 5)
	u5(l__ThrustEmitPoint__11.Flame5, 10)
	u5(l__ThrustEmitPoint__11.Smoke, 1.5)
	u5(l__ThrustEmitPoint__11.SmokePreLaunch, 3)
	u5(l__ThrustEmitPoint__11.SmokeLaunch, 4)
	u5(l__ThrustEmitPoint__11.SmokeRing, 4)
	u5(v7.Sparkles, 2.5)
	u5(v7.Sparks, 3)
	u5(l__CenterEmitPoint__10.Rays1, 25)
	u5(l__CenterEmitPoint__10.Rays2, 25)
	u5(l__CenterEmitPoint__10.Rays3, 25)
	u5(l__CenterEmitPoint__10.SmoothRaysBig, 7.5)
	u5(l__CenterEmitPoint__10.RaysBig, 8)
	u5(l__CenterEmitPoint__10.SparkleExplosion, 4)
	u5(l__CenterEmitPoint__10.Spark3, 25)
	-- 🔥 ARCHITECT FIX: Proteksi StreamingEnabled NukeModel
	local nukeModel = game.Workspace:WaitForChild("NukeModel", 5)
	if not nukeModel then 
		warn("[Nuke] NukeModel belum dirender! Membatalkan efek agar HP tidak crash.")
		v7:Destroy()
		if v12 then v12:Destroy() end
		if v15 then v15:Stop() end
		return 
	end
	v7.CFrame = nukeModel.CFrame.Value
	v7.AlignPosition.Position = v7.Position
	v7.AlignOrientation.CFrame = v7.CFrame
	l__NukeCFrame__8.Value = v7.CFrame
	v7.Anchored = false
	v7.Parent = workspace
	local v16 = l__RunService__6.Heartbeat:Connect(function(p8)
		v7.AlignPosition.Position = l__NukeCFrame__8.Value.Position
		v7.AlignOrientation.CFrame = l__NukeCFrame__8.Value
	end)
	task.wait(1)
	script.Alarm:Play()
	v7.Sparkles.Enabled = false
	v7.ThrustEmitPoint.SmokePreLaunch.Enabled = true
	v7.ThrustEmitPoint.SmokePreLaunch.Rate = 0
	v7.PreThruster:Play()
	v7.PreThruster.Volume = 0
	v7.PreThruster.PlaybackSpeed = 0.1
	l__TweenService__1:Create(v7.PreThruster, TweenInfo.new(5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0), {
		Volume = 1, 
		PlaybackSpeed = 0.5
	}):Play()
	l__TweenService__1:Create(v7.ThrustEmitPoint.SmokePreLaunch, TweenInfo.new(2.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0), {
		Rate = 100
	}):Play()
	task.wait(5)
	v15:ShakeSustain(u3.Presets.Earthquake)
	v7.Sparkles.Enabled = true
	v7.ThrustEmitPoint.SmokePreLaunch.Enabled = false
	l__ThrustEmitPoint__11.SmokeLaunch:Emit(50)
	v7.AlignPosition.Responsiveness = 25
	v7.AlignOrientation.Responsiveness = 25
	v7.PreLaunch:Play()
	v7.Thruster2:Play()
	l__TweenService__1:Create(v7.Thruster2, TweenInfo.new(4, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, 0, false, 0), {
		PlaybackSpeed = 1.5, 
		Volume = 3
	}):Play()
	l__TweenService__1:Create(v7.PreThruster, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0), {
		Volume = 1, 
		PlaybackSpeed = 1
	}):Play()
	for v17, v18 in pairs(l__ThrustEmitPoint__11:GetChildren()) do
		if string.find(v18.Name, "Flame") == nil then
			v18.Enabled = true
		end
	end
	l__ThrustEmitPoint__11.SmokeRing.Enabled = false
	l__ThrustEmitPoint__11.SmokeLaunch.Enabled = false
	l__ThrustEmitPoint__11.Shockwave.Enabled = false
	l__ThrustEmitPoint__11.BigShockwave.Enabled = false
	l__ThrustEmitPoint__11.Flare.Enabled = false
	l__CenterEmitPoint__10.Rays1.Enabled = true
	l__CenterEmitPoint__10.Rays2.Enabled = true
	l__CenterEmitPoint__10.Rays3.Enabled = true
	for v19 = 1, 10 do
		l__NukeCFrame__8.Value = l__NukeCFrame__8.Value:ToWorldSpace(CFrame.Angles(0, 0, 0.17453292519943295))
		l__NukeCFrame__8.Value = l__NukeCFrame__8.Value:ToWorldSpace(CFrame.new(0, 25, 0))
		task.wait(v19 * 0.2)
	end
	v7.AlignPosition.Responsiveness = 10
	v7.AlignOrientation.Responsiveness = 10
	l__NukeCFrame__8.Value = CFrame.new(l__NukeCFrame__8.Value.Position, u4):ToWorldSpace(CFrame.Angles(-1.5707963267948966, 0, 0))
	task.wait(0.5)
	v12.Intensity = 1
	v12.Size = 20
	l__TweenService__1:Create(v12, TweenInfo.new(1, Enum.EasingStyle.Circular, Enum.EasingDirection.Out, 0, false, 0), {
		Intensity = -1, 
		Size = 10
	}):Play()
	v7.AlignPosition.Responsiveness = 50
	v7.AlignOrientation.Responsiveness = 50
	l__ThrustEmitPoint__11.SmokeRing:Emit(50)
	l__ThrustEmitPoint__11.Flame:Emit(25)
	l__ThrustEmitPoint__11.Flame2:Emit(25)
	l__ThrustEmitPoint__11.Flame3:Emit(25)
	l__ThrustEmitPoint__11.Flame4:Emit(25)
	l__ThrustEmitPoint__11.Flame5:Emit(25)
	l__ThrustEmitPoint__11.Shockwave.Enabled = true
	l__ThrustEmitPoint__11.BigShockwave:Emit(1)
	v7.Launch:Play()
	v7.Thruster:Play()
	for v20, v21 in pairs(l__ThrustEmitPoint__11:GetChildren()) do
		v21.Enabled = true
	end
	l__ThrustEmitPoint__11.SmokeRing.Enabled = false
	l__ThrustEmitPoint__11.SmokeLaunch.Enabled = false
	l__ThrustEmitPoint__11.BigShockwave.Enabled = false
	l__ThrustEmitPoint__11.Flare:Emit(10)
	l__TweenService__1:Create(l__NukeCFrame__8, TweenInfo.new(2.5, Enum.EasingStyle.Back, Enum.EasingDirection.In, 0, false, 0), {
		Value = CFrame.new(u4 + Vector3.new(0, -1, 0), u4):ToWorldSpace(CFrame.Angles(1.5707963267948966, 0, 0))
	}):Play()
	task.wait(3)
	v15:StopSustained(0)
	v15:ShakeOnce(4, 6, 0.25, 4)
	script.Alarm:Stop()
	v12.Intensity = 1
	v12.Size = 30
	l__TweenService__1:Create(v12, TweenInfo.new(5, Enum.EasingStyle.Circular, Enum.EasingDirection.Out, 0, false, 0), {
		Intensity = -1, 
		Size = 10
	}):Play()
	v7.Anchored = true
	v7.Transparency = 1
	v7.Size = Vector3.new(0, 0, 0)
	v7.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
	v7.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
	v7.CFrame = l__NukeCFrame__8.Value
	v7.PreThruster:Stop()
	v7.Thruster:Stop()
	v7.Thruster2:Stop()
	v7.Explosion.TimePosition = 0.75
	v7.Explosion:Play()
	v7.ChimeLoop:Play()
	v7.ApplauseLoop:Play()
	v7.CoinsLoop:Play()

	local function preserveExactCase(username)
		return username
	end

	-- 🔥 SAWERIA TOGGLE INJECTION
	local formattedAmount = tostring(p6):reverse():gsub("%d%d%d", "%1."):reverse():gsub("^%.", "")
	l__Frame__9.TextLabels.TopText.Text = "@" .. preserveExactCase(p4) .. " DONATED"
	l__Frame__9.TextLabels.BottomText.Text = "TO @" .. preserveExactCase(p5)

	if USE_RUPIAH then
		-- Gunakan Non-Breaking Space
		l__Frame__9.TextLabels.MiddleText.Text = "Rp\u{00A0}" .. formattedAmount
		l__Frame__9.RobuxLogo.Visible = false
	else
		l__Frame__9.TextLabels.MiddleText.Text = formattedAmount
		l__Frame__9.RobuxLogo.Visible = true
		l__Frame__9.RobuxLogo.Size = UDim2.fromScale(0, 0)
		l__Frame__9.RobuxLogo.Rotation = -180
	end

	l__Frame__9.Star.Size = UDim2.fromScale(0, 0)
	l__Frame__9.TextLabels.BottomText.Size = UDim2.fromScale(0, 0)
	l__Frame__9.TextLabels.BottomText.Position = UDim2.fromScale(0.5, 0.5)
	l__Frame__9.TextLabels.MiddleText.Size = UDim2.fromScale(0, 0)
	l__Frame__9.TextLabels.TopText.Position = UDim2.fromScale(0.5, 0.5)
	l__Frame__9.TextLabels.TopText.Size = UDim2.fromScale(0, 0)
	l__Frame__9.Parent.Enabled = true

	l__TweenService__1:Create(v7, TweenInfo.new(20, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0), {
		Position = u4 + Vector3.new(0, 250, 0)
	}):Play()

	if not USE_RUPIAH then
		l__TweenService__1:Create(l__Frame__9.RobuxLogo, TweenInfo.new(10, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out, 0, false, 0), {
			Size = UDim2.fromScale(1, 1)
		}):Play()
		l__TweenService__1:Create(l__Frame__9.RobuxLogo, TweenInfo.new(15, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out, 0, false, 0), {
			Rotation = 0
		}):Play()
	end

	l__TweenService__1:Create(l__Frame__9.Star, TweenInfo.new(5, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out, 0, false, 0), {
		Size = UDim2.fromScale(1.5, 1.5)
	}):Play()
	l__TweenService__1:Create(l__Frame__9.Star, TweenInfo.new(15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0), {
		Rotation = 360
	}):Play()
	l__TweenService__1:Create(l__Frame__9.Star, TweenInfo.new(10, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 5), {
		ImageTransparency = 1, 
		ImageColor3 = Color3.fromRGB(255, 255, 0)
	}):Play()
	for v22, v23 in pairs(l__ThrustEmitPoint__11:GetChildren()) do
		v23.Enabled = false
	end
	v7.Sparkles.Enabled = false
	for v24, v25 in pairs(l__CenterEmitPoint__10:GetChildren()) do
		v25.Enabled = false
	end
	l__CenterEmitPoint__10.SparkleExplosion:Emit(100)
	l__CenterEmitPoint__10.Shockwave:Emit(15)
	l__CenterEmitPoint__10.FractalBurst:Emit(3)
	l__CenterEmitPoint__10.RaysBig:Emit(20)
	l__CenterEmitPoint__10.Spark1:Emit(100)
	l__CenterEmitPoint__10.Spark2:Emit(100)
	l__CenterEmitPoint__10.Spark3:Emit(50)
	local v26 = v14:Clone()
	v26.Position = u4 + Vector3.new(0, 250, 0)
	v26.Parent = workspace
	l__TweenService__1:Create(v26, TweenInfo.new(10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0), {
		Size = Vector3.new(1000, 100, 1000)
	}):Play()
	task.spawn(function()
		local v27 = v26:GetChildren()
		for v28, v29 in pairs(v27) do
			if v29:IsA("ParticleEmitter") then
				v29.Enabled = true
			end
		end
		task.wait(60)
		for v30, v31 in pairs(v27) do
			if v31:IsA("ParticleEmitter") then
				l__TweenService__1:Create(v31, TweenInfo.new(60, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0), {
					Rate = 0
				}):Play()
			end
		end
		task.wait(90)
		v26.Size = Vector3.new(0, 0, 0)
		task.wait(30)
		v26:Destroy()
	end)

	v7.Sparks.Enabled = true
	l__CenterEmitPoint__10.SparkleExplosion.Enabled = true
	l__TweenService__1:Create(v7.Sparks, TweenInfo.new(45, Enum.EasingStyle.Quint, Enum.EasingDirection.In, 0, false, 0), {
		Rate = 0
	}):Play()
	l__TweenService__1:Create(l__CenterEmitPoint__10.SparkleExplosion, TweenInfo.new(45, Enum.EasingStyle.Quint, Enum.EasingDirection.In, 0, false, 0), {
		Rate = 0
	}):Play()
	l__TweenService__1:Create(v7.ChimeLoop, TweenInfo.new(55, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0), {
		Volume = 0, 
		PlaybackSpeed = 0.75
	}):Play()
	l__TweenService__1:Create(v7.ApplauseLoop, TweenInfo.new(60, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0), {
		Volume = 0
	}):Play()
	l__TweenService__1:Create(v7.CoinsLoop, TweenInfo.new(50, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0), {
		Volume = 0, 
		PlaybackSpeed = 1
	}):Play()
	task.wait(30) 
	l__TweenService__1:Create(l__Frame__9.UIScale, TweenInfo.new(3, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0), {
		Scale = 0
	}):Play()
	task.wait(15) 
	l__Frame__9.Parent.Enabled = false

	task.wait(30) 
	if v15 then v15:Stop() end
	if v12 then v12:Destroy() end
	if v16 then v16:Disconnect() end
	if v7 then v7:Destroy() end
end 

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local FireNukeEvent = ReplicatedStorage:WaitForChild("FireNuke", 10)

if FireNukeEvent then
	FireNukeEvent.OnClientEvent:Connect(function(p9, p10, p11)
		if l__LocalPlayer__2:GetAttribute('GlobalEffects') ~= false then
			local nukeAsset = ReplicatedStorage:FindFirstChild("VFX") 
			if nukeAsset and nukeAsset:FindFirstChild("MoonVFXAssets") then
				u7(nukeAsset.MoonVFXAssets.Nuke, p9, p10, p11)
			else
				warn("[Nuke] Gagal memutar efek: Folder VFX/MoonVFXAssets/Nuke tidak ditemukan!")
			end
		end
	end)
end

local wait = task.wait;
local l__ReplicatedStorage__1 = game:GetService("ReplicatedStorage");
local l__Players__2 = game:GetService("Players");
local l__Debris__3 = game:GetService("Debris");
local l__RunService__4 = game:GetService("RunService");
local l__TweenService__1 = game:GetService("TweenService");
local UserInputService = game:GetService("UserInputService")
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

-- ==========================================
-- 🔥 CONFIG: SAWERIA / ROBUX TOGGLE & DEBUG
-- ==========================================
local USE_RUPIAH = true -- Ubah ke 'false' jika ingin mode Robux!
local DEBUG_ENABLED = false -- Ubah ke 'true' jika ingin memunculkan log di console/F9

local function debugPrint(...)
	if DEBUG_ENABLED then
		print(...)
	end
end

local function u2(p1, p2)
	p1.Speed = NumberRange.new(p1.Speed.Min * p2, p1.Speed.Max * p2);
	p1.Acceleration = p1.Acceleration * p2;
	local l__Keypoints__5 = p1.Size.Keypoints;
	local v6 = {};
	for v7 = 1, #l__Keypoints__5 do
		table.insert(v6, NumberSequenceKeypoint.new(l__Keypoints__5[v7].Time, l__Keypoints__5[v7].Value * p2, l__Keypoints__5[v7].Envelope * p2));
	end;
	p1.Size = NumberSequence.new(v6);
end;
local u3 = require(script.CameraShaker);
local u4 = Vector3.new(-106, 2.938, -442.5);
local function u5(p3, p4)
	local l__Humanoid__H = p4:FindFirstChildOfClass("Humanoid")
	if not l__Humanoid__H then return end

	local success, v8 = pcall(function()
		return game.Players:GetHumanoidDescriptionFromUserId(p3)
	end)

	if success and v8 then
		v8.DepthScale = 53
		v8.HeadScale = 53 
		v8.HeightScale = 53
		v8.WidthScale = 53

		l__Humanoid__H.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		l__Humanoid__H.AutomaticScalingEnabled = true

		local applySuccess = pcall(function()
			l__Humanoid__H:ApplyDescription(v8)
		end)

		if not applySuccess then
			warn("[Studio] Gagal menerapkan HumanoidDescription")
		end

		task.wait(0.5)

		-- 🔥 FIX RAKSASA TELANJANG (Hapus Baju 3D yang Buggy & Kasih Baju 2D)
		local hasShirt = p4:FindFirstChildOfClass("Shirt")
		local hasPants = p4:FindFirstChildOfClass("Pants")

		for _, obj in ipairs(p4:GetDescendants()) do
			if obj:IsA("WrapLayer") then
				-- Hapus aksesoris Baju 3D karena pasti hilang/error saat di-scale 53x
				local accessory = obj:FindFirstAncestorOfClass("Accessory")
				if accessory then
					accessory:Destroy()
				end
			end
		end

		-- Jika pemain hanya pakai baju 3D (tidak punya baju 2D), pakaikan baju default agar tidak telanjang
		if not hasShirt then
			local defaultShirt = Instance.new("Shirt")
			defaultShirt.ShirtTemplate = "rbxassetid://144075659" -- Baju Classic Hitam
			defaultShirt.Parent = p4
		end
		if not hasPants then
			local defaultPants = Instance.new("Pants")
			defaultPants.PantsTemplate = "rbxassetid://144076529" -- Celana Classic Hitam
			defaultPants.Parent = p4
		end

	else

		warn("[Studio] Gagal mengambil deskripsi avatar untuk ID:", p3)
	end

	for _, v10 in ipairs(p4:GetDescendants()) do
		if (v10:IsA("BasePart") or v10:IsA("Decal")) and v10.Name ~= "HumanoidRootPart" then
			v10.Transparency = 0.99 
		end
	end
end

local u6 = math.random(-180, 180);
local function u7(modelTemplate, p5, p6, p7, p8)
	local v11 = modelTemplate:Clone();

	-- 🔥 OPTIMASI HP KENTANG
	if isMobile then
		for _, obj in pairs(v11:GetDescendants()) do
			if obj:IsA("ParticleEmitter") then
				obj.Rate = obj.Rate * 0.25
			elseif obj:IsA("PointLight") or obj:IsA("SurfaceLight") then
				obj.Shadows = false
			end
		end
	end

	local l__DiamondHammer__12 = v11.DiamondHammer;
	for v13, v14 in pairs(v11:GetDescendants()) do
		if (v14:IsA("BasePart") or v14:IsA("Decal")) and v14.Name ~= "HumanoidRootPart" and (v14:IsDescendantOf(l__DiamondHammer__12) == false or v14:IsDescendantOf(v11.Objects) == false) then
			v14.Transparency = 1;
		end;
	end;
	u2(l__DiamondHammer__12.Handle.MainDiamondCenter.Shockwave, 60);
	u2(l__DiamondHammer__12.Handle.MainDiamondCenter.ChargeGlow, 50);
	u2(l__DiamondHammer__12.Handle.MainDiamondCenter.ChargeRays, 50);
	l__DiamondHammer__12.Handle.Transparency = 1;
	l__DiamondHammer__12.Handle.Diamonds.Transparency = 1;
	l__DiamondHammer__12.Handle.CanCollide = false;
	v11.Parent = workspace;
	u2(l__DiamondHammer__12.Handle.BaseFrontOffset.Shockwave, 10);
	local v15 = v11.Objects.Meteor:Clone();
	local v16 = v11.Objects.FloorAmbiance:Clone();
	local v17 = v11.Objects.Ambiance:Clone();
	local v18 = v11.Objects.ImpactVisuals:Clone();
	local v19 = v11.Objects.Portal:Clone();
	v11.Objects:Destroy();
	local l__Sounds__20 = v11.Sounds;
	l__Sounds__20.Parent = workspace;
	l__Sounds__20.Name = "1MDonationEffect_Sounds";
	local v21 = v11.Humanoid:LoadAnimation(v11.Animations.Giant_MainAnimation);
	local v22 = Instance.new("ColorCorrectionEffect");
	v22.Enabled = true;
	v22.Name = "SmiteColorCorrection";
	v22.Parent = game.Lighting;
	local v23 = Instance.new("BloomEffect");
	v23.Enabled = true;
	v23.Name = "SmiteBloom";
	v23.Size = 20;
	v23.Threshold = 0.1;
	v23.Intensity = -1;
	v23.Parent = game.Lighting;
	local v24 = u3.new(Enum.RenderPriority.Camera.Value, function(p9)
		workspace.CurrentCamera.CFrame = workspace.CurrentCamera.CFrame * p9;
	end);
	v24:Start();
	v11.PrimaryPart = v11.FloorLevel;
	v11:SetPrimaryPartCFrame(CFrame.new(u4.X, u4.Y, u4.Z));
	v11:SetPrimaryPartCFrame(v11.FloorLevel.CFrame:ToWorldSpace(CFrame.Angles(0, math.rad(math.random(-180, 180)), 0)));
	v11:SetPrimaryPartCFrame(v11.FloorLevel.CFrame:ToWorldSpace(CFrame.new(25, 0, 365)));
	v11.PrimaryPart = v11.HumanoidRootPart;
	local v25 = v19:Clone();
	v19.PortalAmbiance.Volume = 0;
	v19.PortalAmbiance.PlaybackSpeed = 0;
	v25.CFrame = v11.FloorLevel.CFrame;
	v25.Parent = workspace;
	v11.FloorLevel:Destroy();
	-- 🔥 ARCHITECT FIX: Proteksi Aksesoris Mata
	local l__LeftEyeAttachment__26 = v11.Head:FindFirstChild("LeftEyeAttachment")
	local l__RightEyeAttachment__27 = v11.Head:FindFirstChild("RightEyeAttachment")
	if l__LeftEyeAttachment__26 then l__LeftEyeAttachment__26.Parent = nil end
	if l__RightEyeAttachment__27 then l__RightEyeAttachment__27.Parent = nil end
	l__DiamondHammer__12.Parent = nil;
	local v28, v29 = pcall(function()
		u5(p8, v11) 
	end)
	if v28 == false then
		warn("Unable to set giant's apperance to donator (" .. p5 .. ")  (" .. v29 .. ")");
	end;
	l__DiamondHammer__12.Parent = v11;
	l__DiamondHammer__12.Weld.Attachment0 = v11.RightHand.RightGripAttachment;
	-- 🔥 ARCHITECT FIX: Return Aksesoris Mata
	if l__LeftEyeAttachment__26 then 
		l__LeftEyeAttachment__26.Parent = v11.Head
		l__LeftEyeAttachment__26.Position = Vector3.new(-6, 11, -32)
	end
	if l__RightEyeAttachment__27 then 
		l__RightEyeAttachment__27.Parent = v11.Head
		l__RightEyeAttachment__27.Position = Vector3.new(6, 11, -32)
	end
	l__Sounds__20.Summon:Play();
	v25.Transparency = 0;
	v25.Sparks.Enabled = true;
	v25.Appearance.Enabled = true;
	l__TweenService__1:Create(v25.Sparks, TweenInfo.new(3, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, 0, false, 0), {
		Rate = 40
	}):Play();
	l__TweenService__1:Create(v25.Appearance, TweenInfo.new(3, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, 0, false, 0), {
		Rate = 40
	}):Play();
	l__TweenService__1:Create(v25, TweenInfo.new(3, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, 0, false, 0), {
		Size = Vector3.new(400, 1, 400)
	}):Play();
	l__TweenService__1:Create(v25.OuterLightBeam, TweenInfo.new(3, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, 0, false, 0), {
		Width0 = 400, 
		Width1 = 600
	}):Play();
	l__TweenService__1:Create(v25.InnerLightBeam, TweenInfo.new(3, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, 0, false, 0), {
		Width0 = 200, 
		Width1 = 300
	}):Play();
	v25.PortalAmbiance.Playing = true;
	v25.PortalOpen1:Play();
	v25.PortalOpen2:Play();
	l__TweenService__1:Create(v25.PortalAmbiance, TweenInfo.new(3, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, 0, false, 0), {
		Volume = 0.5, 
		PlaybackSpeed = 1.25
	}):Play();
	local u8 = true;
	local u9 = 0.5;
	task.spawn(function()
		while u8 == true do
			task.wait(u9);
			task.spawn(function()
				local v30 = math.random(100, 400) / 100;
				local v31 = math.random(250, 400) / 100;
				local v32 = math.random(500, 750);
				local v33 = v15:Clone();
				v33.Parent = workspace;
				v33.Transparency = 1;
				v33.Position = u4 + Vector3.new(math.random(-750, 750), 0, math.random(-750, 750));
				v33.Size = v33.Size * v30;
				v33.CFrame = v33.CFrame:ToWorldSpace(CFrame.Angles(math.rad(math.random(-10, 10)), math.rad(u6), 0.5235987755982988));
				v33.Position = v33.Position + v33.CFrame.UpVector * v32;
				for v34, v35 in pairs(v33:GetDescendants()) do
					if v35:IsA("ParticleEmitter") then
						u2(v35, v30);
						if string.find(v35.Name, "Meteor_") ~= nil then
							v35.Enabled = true;
						end;
					end;
				end;
				v33.Glow.Range = v33.Glow.Range * v30;
				v33.Glow.Enabled = true;
				v33.Trail0.Position = v33.Trail0.Position * (v30 / 2);
				v33.Trail1.Position = v33.Trail1.Position * (v30 / 2);
				v33.Trail.Enabled = true;
				v33.Whoosh.Volume = 0;
				v33.Whoosh.TimePosition = math.random(0, v33.Whoosh.TimeLength);
				v33.Whoosh.PlaybackSpeed = 1.5 - v30 * 0.15;
				v33.Impact.PlaybackSpeed = 1.5 - v30 * 0.15;
				v33.Whoosh.Playing = true;
				l__TweenService__1:Create(v33, TweenInfo.new(v31, Enum.EasingStyle.Sine, Enum.EasingDirection.In, 0, false, 0), {
					Position = v33.Position + v33.CFrame.UpVector * -v32, 
					Orientation = Vector3.new(math.random(-180, 180) * 3, math.random(-180, 180) * 3, math.random(-180, 180) * 3)
				}):Play();
				l__TweenService__1:Create(v33, TweenInfo.new(v31 * 0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0), {
					Transparency = 0
				}):Play();
				l__TweenService__1:Create(v33.Whoosh, TweenInfo.new(v31 * 0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0), {
					Volume = 0.1
				}):Play();
				task.wait(v31);
				v33.Transparency = 1;
				v33.Orientation = Vector3.new(0, 0, 0);
				v33.Glow.Range = v33.Glow.Range * 1.5;
				v33.Glow.Brightness = v33.Glow.Brightness * 3;
				l__TweenService__1:Create(v33.Glow, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0), {
					Brightness = 0, 
					Range = v33.Glow.Range / 2
				}):Play();
				for v36, v37 in pairs(v33:GetDescendants()) do
					if v37:IsA("ParticleEmitter") then
						if string.find(v37.Name, "Meteor_") ~= nil then
							v37.Enabled = false;
						end;
						if string.find(v37.Name, "Explosion_") ~= nil then
							v37:Emit(v37:GetAttribute("EmitCount"));
						end;
					end;
				end;
				v33.Trail.Enabled = false;
				v33.Whoosh.Playing = false;
				v33.Impact:Play();
				task.wait(3);
				v33:Destroy();
			end);		
		end;
	end);
	local v38 = v16:Clone();
	v38.Position = u4 + Vector3.new(0, -0.5, 0);
	v38.Parent = workspace;
	l__TweenService__1:Create(v38, TweenInfo.new(10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0), {
		Size = Vector3.new(2048, 1, 2048)
	}):Play();
	local v39 = v17:Clone();
	v39.Position = u4 + Vector3.new(0, 0, 0);
	v39.Size = Vector3.new(1000, 1000, 1000);
	v39.CFrame = v39.CFrame:ToWorldSpace(CFrame.Angles(0, math.rad(u6), 0.5235987755982988));
	v39.Position = v39.Position + v39.CFrame.UpVector * 600;
	v39.Parent = workspace;
	task.spawn(function()
		for v40, v41 in pairs(v38:GetChildren()) do
			if v41:IsA("ParticleEmitter") then
				u2(v41, 1.25);
				v41.Enabled = true;
			end;
		end;
		for v42, v43 in pairs(v39:GetChildren()) do
			if v43:IsA("ParticleEmitter") then
				u2(v43, 1.75);
				v43.Enabled = true;
			end;
		end;
		task.wait(90);
		l__TweenService__1:Create(l__Sounds__20.FireLoop, TweenInfo.new(30, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0), {
			Volume = 0, 
			PlaybackSpeed = 0.5
		}):Play();
		u8 = false;
		for v44, v45 in pairs(v38:GetChildren()) do
			if v45:IsA("ParticleEmitter") then
				l__TweenService__1:Create(v45, TweenInfo.new(60, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0), {
					Rate = 0
				}):Play();
			end;
		end;
		for v46, v47 in pairs(v39:GetChildren()) do
			if v47:IsA("ParticleEmitter") then
				l__TweenService__1:Create(v47, TweenInfo.new(30, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0), {
					Rate = 0
				}):Play();
			end;
		end;
		task.wait(60);
		v38.Size = Vector3.new(0, 0, 0);
		v39.Size = Vector3.new(0, 0, 0);
		task.wait(30);
		v38:Destroy();
		v39:Destroy();
	end);
	l__TweenService__1:Create(v22, TweenInfo.new(10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0), {
		TintColor = Color3.fromRGB(255, 130, 108), 
		Brightness = 0.1, 
		Saturation = 0.1, 
		Contrast = 0.15
	}):Play();
	l__TweenService__1:Create(v23, TweenInfo.new(10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0), {
		Intensity = -0.95
	}):Play();
	local function v48(p10)
		local v49 = NumberSequence.new({ NumberSequenceKeypoint.new(0, p10), NumberSequenceKeypoint.new(1, 1) });
		for v50, v51 in pairs(l__DiamondHammer__12.Effects.Beams:GetChildren()) do
			if v51:IsA("Beam") and string.find(v51.Name, "FlameEffect") ~= nil then
				v51.Enabled = true;
				v51.Transparency = v49;
			end;
		end;
	end;
	local v52 = v11.Values.Hammer_FlameEffectTransparency.Changed:Connect(v48);
	v48(1);
	v21:GetMarkerReachedSignal("Eye lense flare"):Connect(function(p11)
		debugPrint("Animation event: Eye lense flare");
		l__Sounds__20.LenseFlareEyes:Play();
		v11.Head.LeftEyeAttachment.Flare.Enabled = true;
		v11.Head.LeftEyeAttachment.FlareFlash:Emit(1);
		v11.Head.RightEyeAttachment.Flare.Enabled = true;
		v11.Head.RightEyeAttachment.FlareFlash:Emit(1);
	end);
	v21:GetMarkerReachedSignal("HammerAppear"):Connect(function(p12)
		debugPrint("Animation event: HammerAppear " .. p12);
		l__DiamondHammer__12.Handle.AppearSound.Playing = true;
		l__DiamondHammer__12.Handle.AppearSound.Volume = 0;
		l__DiamondHammer__12.Handle.AppearSound.PlaybackSpeed = 0.75;
		l__TweenService__1:Create(l__DiamondHammer__12.Handle.AppearSound, TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true, 0), {
			Volume = 0.1
		}):Play();
		l__TweenService__1:Create(l__DiamondHammer__12.Handle.AppearSound, TweenInfo.new(3, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, 0, false, 0), {
			PlaybackSpeed = 1.5
		}):Play();
		l__DiamondHammer__12.Handle.HammerBaseOutline.Sparkles.Enabled = true;
		l__DiamondHammer__12.Handle.HammerBaseOutline.Appearance.Enabled = true;
		l__DiamondHammer__12.Handle.HammerHandleBase.Appearance.Enabled = true;
		l__TweenService__1:Create(l__DiamondHammer__12.Handle.HammerBaseOutline.Sparkles, TweenInfo.new(3, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, 0, false, 0), {
			Rate = 15
		}):Play();
		l__TweenService__1:Create(l__DiamondHammer__12.Handle.HammerBaseOutline.Appearance, TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true, 0), {
			Rate = 30
		}):Play();
		l__TweenService__1:Create(l__DiamondHammer__12.Handle.HammerHandleBase.Appearance, TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true, 0), {
			Rate = 25
		}):Play();
		l__TweenService__1:Create(l__DiamondHammer__12.Handle, TweenInfo.new(3, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, 0, false, 0), {
			Transparency = 0
		}):Play();
		l__TweenService__1:Create(l__DiamondHammer__12.Handle.Diamonds, TweenInfo.new(3, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, 0, false, 0), {
			Transparency = 0.1
		}):Play();
	end);
	v21:GetMarkerReachedSignal("ChargeSwing"):Connect(function(p13)
		debugPrint("Animation event: ChargeSwing");
		l__DiamondHammer__12.Handle.ChargeSound1:Play();
		l__DiamondHammer__12.Handle.ChargeSound2:Play();
		l__DiamondHammer__12.Handle.ChargeSound3:Play();
		l__DiamondHammer__12.Handle.MainChargeSound:Play();
		for v53, v54 in pairs(l__DiamondHammer__12.Handle:GetChildren()) do
			if v54:IsA("Attachment") and string.find(v54.Name, "DiamondCenter") ~= nil then
				v54.Flare.Enabled = true;
			end;
		end;
		l__DiamondHammer__12.Handle.MainDiamondCenter.Shockwave:Emit(1);
		l__DiamondHammer__12.Handle.MainDiamondCenter.ChargeGlow.Enabled = true;
		l__DiamondHammer__12.Handle.MainDiamondCenter.ChargeRays.Enabled = true;
		l__TweenService__1:Create(l__DiamondHammer__12.Handle.MainDiamondCenter.ChargeRays, TweenInfo.new(4, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0), {
			TimeScale = 1
		}):Play();
		l__TweenService__1:Create(l__DiamondHammer__12.Handle.MainDiamondCenter.ChargeGlow, TweenInfo.new(4, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0), {
			TimeScale = 1
		}):Play();
	end);
	v21:GetMarkerReachedSignal("SwingStart"):Connect(function(p14)
		debugPrint("Animation event: SwingStart");
		l__DiamondHammer__12.Handle.ChargeEndSound:Play();
		l__DiamondHammer__12.Handle.MainDiamondCenter.Shockwave:Emit(3);
		l__DiamondHammer__12.Handle.MainDiamondCenter.ChargeGlow.Enabled = false;
		l__DiamondHammer__12.Handle.MainDiamondCenter.ChargeRays.Enabled = false;
		l__TweenService__1:Create(l__DiamondHammer__12.Handle.MainChargeSound, TweenInfo.new(4, Enum.EasingStyle.Quart, Enum.EasingDirection.In, 0, false, 0), {
			Volume = 0.25
		}):Play();
		l__DiamondHammer__12.Handle.BaseCenter.Wind.Volume = 0;
		l__DiamondHammer__12.Handle.BaseCenter.Wind.PlaybackSpeed = 0.5;
		l__DiamondHammer__12.Handle.BaseCenter.Wind.Playing = true;
		l__TweenService__1:Create(l__DiamondHammer__12.Handle.BaseCenter.Wind, TweenInfo.new(3.5, Enum.EasingStyle.Quart, Enum.EasingDirection.In, 0, false, 0), {
			Volume = 0.25, 
			PlaybackSpeed = 2.5
		}):Play();
		l__TweenService__1:Create(v11.Values.Hammer_FlameEffectTransparency, TweenInfo.new(4, Enum.EasingStyle.Quart, Enum.EasingDirection.In, 0, false, 0), {
			Value = 0
		}):Play();
		l__DiamondHammer__12.Handle.HammerBase.Flames.Enabled = true;
		l__DiamondHammer__12.Handle.BaseFrontOffset.Shockwave.Enabled = true;
		l__TweenService__1:Create(l__DiamondHammer__12.Handle.HammerBase.Flames, TweenInfo.new(2.5, Enum.EasingStyle.Sine, Enum.EasingDirection.In, 0, false, 0), {
			Rate = 20
		}):Play();
		l__TweenService__1:Create(l__DiamondHammer__12.Handle.BaseFrontOffset.Shockwave, TweenInfo.new(3, Enum.EasingStyle.Sine, Enum.EasingDirection.In, 0, false, 0), {
			Rate = 10
		}):Play();
		for v55, v56 in pairs(l__DiamondHammer__12.Effects.Trails:GetChildren()) do
			v56.Enabled = true;
		end;
	end);
	v21:GetMarkerReachedSignal("SwingEnd"):Connect(function(p15)
		debugPrint("Animation event: SwingEnd");
		u9 = 0.25;
		l__DiamondHammer__12.Handle.MainChargeSound:Stop();
		l__Sounds__20.Rumble:Play();
		v23.Intensity = 0.75;
		v23.Threshold = 0.05;
		v22.Contrast = 0;
		l__TweenService__1:Create(v23, TweenInfo.new(10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0), {
			Intensity = -0.9, 
			Threshold = 0.1
		}):Play();
		l__TweenService__1:Create(v22, TweenInfo.new(10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0), {
			Contrast = 0.25
		}):Play();
		l__TweenService__1:Create(v11.Values.Hammer_FlameEffectTransparency, TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0), {
			Value = 1
		}):Play();
		l__DiamondHammer__12.Handle.BaseFrontOffset.Shockwave.Enabled = false;
		l__TweenService__1:Create(l__DiamondHammer__12.Handle.HammerBase.Flames, TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0), {
			Rate = 0
		}):Play();
		for v57, v58 in pairs(l__DiamondHammer__12.Effects.Trails:GetChildren()) do
			v58.Enabled = false;
		end;
		l__DiamondHammer__12.Handle.BaseCenter.Wind.Playing = false;
		for v59, v60 in pairs(l__DiamondHammer__12.Handle.BaseCenter:GetChildren()) do
			if v60:IsA("Sound") and string.find(v60.Name, "Impact_") ~= nil then
				v60:Play();
			end;
		end;
		for v61, v62 in pairs(l__DiamondHammer__12.Handle:GetChildren()) do
			if v62:IsA("Attachment") and string.find(v62.Name, "DiamondCenter") ~= nil then
				v62.Flare.Enabled = false;
			end;
		end;
		v24:ShakeOnce(6, 6, 0.25, 5);
		local v63 = v18:Clone();
		v63.Position = u4;
		v63.Parent = workspace;
		u2(v63.EmitPoint.Impact_FractalBurst, 10);
		u2(v63.EmitPoint.Impact_RaysBurst, 25);
		u2(v63.EmitPoint.Impact_Shockwave, 30);
		u2(v63.EmitPoint.Impact_Spark1, 10);
		u2(v63.EmitPoint.Impact_Spark2, 10);
		u2(v63.EmitPoint.Impact_Spark3, 10);
		u2(v63.EmitPoint.Impact_SparkleExplosion, 10);
		u2(v63.EmitPoint.SparkleExplosion, 7.5);
		u2(v63.EmitPoint.Sparks, 5);
		for v64, v65 in pairs(v63.EmitPoint:GetChildren()) do
			if v65:IsA("ParticleEmitter") and string.find(v65.Name, "Impact_") ~= nil then
				v65:Emit(v65:GetAttribute("EmitCount"));
			end;
		end;

		local function preserveExactCase(username)
			return username
		end

		v63.ApplauseLoop.Playing = true;
		v63.ChimeLoop.Playing = true;
		v63.CoinsLoop.Playing = true;
		local l__Frame__66 = v63.BillboardGuiAnimation.Frame;
		l__Frame__66.TopText.Visible = true;
		l__Frame__66.BottomText.Visible = true;

		-- 🔥 SAWERIA TOGGLE INJECTION
		local formattedAmount = tostring(p7):reverse():gsub("%d%d%d", "%1."):reverse():gsub("^%.", "")
		l__Frame__66.TopText.Text = "@" .. preserveExactCase(p5) .. " DONATED";
		l__Frame__66.BottomText.Text = "TO @" .. preserveExactCase(p6);

		if USE_RUPIAH then
			-- Gunakan Non-Breaking Space
			l__Frame__66.MiddleText.Text = "Rp\u{00A0}" .. formattedAmount
			l__Frame__66.RobuxLogo.Visible = false
		else
			l__Frame__66.MiddleText.Text = formattedAmount
			l__Frame__66.RobuxLogo.Visible = true
			l__Frame__66.RobuxLogo.Size = UDim2.fromScale(0, 0);
			l__Frame__66.RobuxLogo.Rotation = -180;
		end

		l__Frame__66.Star.Size = UDim2.fromScale(0, 0);
		l__Frame__66.BottomText.Size = UDim2.fromScale(0, 0);
		l__Frame__66.BottomText.Position = UDim2.fromScale(0.5, 0.5);
		l__Frame__66.MiddleText.Size = UDim2.fromScale(0, 0);
		l__Frame__66.TopText.Position = UDim2.fromScale(0.5, 0.5);
		l__Frame__66.TopText.Size = UDim2.fromScale(0, 0);
		l__Frame__66.Parent.Enabled = true;

		l__TweenService__1:Create(v63, TweenInfo.new(20, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0), {
			Position = u4 + Vector3.new(0, 400, 0)
		}):Play();

		if not USE_RUPIAH then
			l__TweenService__1:Create(l__Frame__66.RobuxLogo, TweenInfo.new(10, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out, 0, false, 0), {
				Size = UDim2.fromScale(1, 1)
			}):Play();
			l__TweenService__1:Create(l__Frame__66.RobuxLogo, TweenInfo.new(15, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out, 0, false, 0), {
				Rotation = 0
			}):Play();
		end

		l__TweenService__1:Create(l__Frame__66.Star, TweenInfo.new(5, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out, 0, false, 0), {
			Size = UDim2.fromScale(1.5, 1.5)
		}):Play();
		l__TweenService__1:Create(l__Frame__66.Star, TweenInfo.new(15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0), {
			Rotation = 360
		}):Play();
		l__TweenService__1:Create(l__Frame__66.BottomText, TweenInfo.new(5, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out, 0, false, 0.6), {
			Size = UDim2.fromScale(1.5, 0.1), 
			Position = UDim2.fromScale(0.5, 0.59)
		}):Play();
		l__TweenService__1:Create(l__Frame__66.MiddleText, TweenInfo.new(5, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out, 0, false, 0.4), {
			Size = UDim2.fromScale(1, 1)
		}):Play();
		l__TweenService__1:Create(l__Frame__66.TopText, TweenInfo.new(5, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out, 0, false, 0.2), {
			Size = UDim2.fromScale(1.5, 0.1), 
			Position = UDim2.fromScale(0.5, 0.41)
		}):Play();
		l__TweenService__1:Create(l__Frame__66.Star, TweenInfo.new(10, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 5), {
			ImageTransparency = 1, 
			ImageColor3 = Color3.fromRGB(0, 255, 255)
		}):Play();

		v63.EmitPoint.Sparks.Enabled = true;
		v63.EmitPoint.SparkleExplosion.Enabled = true;
		l__TweenService__1:Create(v63.EmitPoint.Sparks, TweenInfo.new(45, Enum.EasingStyle.Quint, Enum.EasingDirection.In, 0, false, 0), {
			Rate = 0
		}):Play();
		l__TweenService__1:Create(v63.EmitPoint.SparkleExplosion, TweenInfo.new(45, Enum.EasingStyle.Quint, Enum.EasingDirection.In, 0, false, 0), {
			Rate = 0
		}):Play();
		l__TweenService__1:Create(v63.ChimeLoop, TweenInfo.new(55, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0), {
			Volume = 0, 
			PlaybackSpeed = 0.75
		}):Play();
		l__TweenService__1:Create(v63.ApplauseLoop, TweenInfo.new(60, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0), {
			Volume = 0
		}):Play();
		l__TweenService__1:Create(v63.CoinsLoop, TweenInfo.new(50, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0), {
			Volume = 0, 
			PlaybackSpeed = 1
		}):Play();
		task.wait(30);
		l__TweenService__1:Create(l__Frame__66.UIScale, TweenInfo.new(15, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0), {
			Scale = 0
		}):Play();
		task.wait(30);
		v63:Destroy();
	end);
	v21:GetMarkerReachedSignal("Release"):Connect(function(p16)
		debugPrint("Animation event: Release");
		v11.Head.LeftEyeAttachment.Flare.Enabled = false;
		v11.Head.RightEyeAttachment.Flare.Enabled = false;
	end);
	local l__Appearance__10 = v11.Particles.Appearance;
	v21:GetMarkerReachedSignal("Fade"):Connect(function(p17)
		debugPrint("Animation event: Fade " .. p17);
		local v67 = l__Sounds__20.GiantFade:Clone();
		v67.Volume = 0;
		v67.PlaybackSpeed = 1.5;
		v67.Parent = v11.UpperTorso;
		v67.Playing = true;
		l__TweenService__1:Create(v67, TweenInfo.new(4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true, 0), {
			Volume = 0.7
		}):Play();
		l__TweenService__1:Create(v67, TweenInfo.new(8, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, 0, false, 0), {
			PlaybackSpeed = 0.5
		}):Play();
		for v68, v69 in pairs(v11:GetDescendants()) do
			if (v69:IsA("BasePart") or v69:IsA("Decal")) and v69.Name ~= "HumanoidRootPart" then
				if v69:IsA("Decal") == false then
					local v70 = l__Appearance__10:Clone();
					v70.Parent = v69;
					v70.Enabled = true;
					l__TweenService__1:Create(v70, TweenInfo.new(5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true, 0), {
						Rate = 30
					}):Play();
				end;
				l__TweenService__1:Create(v69, TweenInfo.new(10, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0), {
					Transparency = 1
				}):Play();
			end;
		end;
		l__TweenService__1:Create(l__DiamondHammer__12.Handle.HammerBaseOutline.Sparkles, TweenInfo.new(8, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0), {
			Rate = 0
		}):Play();
		l__TweenService__1:Create(l__DiamondHammer__12.Handle.HammerBaseOutline.Appearance, TweenInfo.new(4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true, 0), {
			Rate = 70
		}):Play();
		l__TweenService__1:Create(l__DiamondHammer__12.Handle.HammerHandleBase.Appearance, TweenInfo.new(4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true, 0), {
			Rate = 40
		}):Play();
		l__TweenService__1:Create(l__DiamondHammer__12.Handle, TweenInfo.new(8, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0), {
			Transparency = 1
		}):Play();
		l__TweenService__1:Create(l__DiamondHammer__12.Handle.Diamonds, TweenInfo.new(8, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0), {
			Transparency = 1
		}):Play();
	end);
	v21:GetMarkerReachedSignal("FadeEnd"):Connect(function(p18)
		debugPrint("Animation event: FadeEnd");
		v52:Disconnect();
		task.wait(5);
		v11:Destroy();
	end);
	task.wait(1);
	v21:Play();
	task.spawn(function()
		l__Sounds__20.Earthquake:Play();
		l__Sounds__20.CrumbleLoop.Volume = 0;
		l__Sounds__20.CrumbleLoop.Playing = true;
		l__TweenService__1:Create(l__Sounds__20.CrumbleLoop, TweenInfo.new(3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0), {
			Volume = 0.1
		}):Play();
		l__Sounds__20.FireLoop.Volume = 0;
		l__Sounds__20.FireLoop.PlaybackSpeed = 0.5;
		l__Sounds__20.FireLoop.Playing = true;
		l__TweenService__1:Create(l__Sounds__20.FireLoop, TweenInfo.new(5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0), {
			Volume = 0.1, 
			PlaybackSpeed = 1
		}):Play();
		v24:ShakeSustain(u3.Presets.Earthquake);
		for v71, v72 in pairs(v11:GetDescendants()) do
			if (v72:IsA("BasePart") or v72:IsA("Decal")) and v72.Name ~= "HumanoidRootPart" and v72:IsDescendantOf(l__DiamondHammer__12) == false then
				l__TweenService__1:Create(v72, TweenInfo.new(5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0), {
					Transparency = 0
				}):Play();
			end;
		end;
		task.wait(7);
		l__TweenService__1:Create(l__Sounds__20.CrumbleLoop, TweenInfo.new(10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0), {
			Volume = 0
		}):Play();
		v24:StopSustained(6);
		l__TweenService__1:Create(v25.Sparks, TweenInfo.new(5, Enum.EasingStyle.Sine, Enum.EasingDirection.In, 0, false, 0), {
			Rate = 0
		}):Play();
		l__TweenService__1:Create(v25.Appearance, TweenInfo.new(5, Enum.EasingStyle.Sine, Enum.EasingDirection.In, 0, false, 0), {
			Rate = 0
		}):Play();
		l__TweenService__1:Create(v25, TweenInfo.new(5, Enum.EasingStyle.Sine, Enum.EasingDirection.In, 0, false, 0), {
			Size = Vector3.new(0, 1, 0)
		}):Play();
		l__TweenService__1:Create(v25.OuterLightBeam, TweenInfo.new(5, Enum.EasingStyle.Sine, Enum.EasingDirection.In, 0, false, 0), {
			Width0 = 0, 
			Width1 = 0
		}):Play();
		l__TweenService__1:Create(v25.InnerLightBeam, TweenInfo.new(5, Enum.EasingStyle.Sine, Enum.EasingDirection.In, 0, false, 0), {
			Width0 = 0, 
			Width1 = 0
		}):Play();
		l__TweenService__1:Create(v25.PortalAmbiance, TweenInfo.new(5, Enum.EasingStyle.Sine, Enum.EasingDirection.In, 0, false, 0), {
			Volume = 0, 
			PlaybackSpeed = 0
		}):Play();
		v25.PortalClose1.PlayOnRemove = true;
		task.wait(5);
		v25:Destroy();
	end);
	task.wait(90);
	u3:Stop();
	l__TweenService__1:Create(v22, TweenInfo.new(30, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0), {
		TintColor = Color3.fromRGB(255, 255, 255), 
		Brightness = 0, 
		Saturation = 0, 
		Contrast = 0
	}):Play()
	l__TweenService__1:Create(v23, TweenInfo.new(30, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0), {
		Intensity = -1
	}):Play()

	task.wait(15) 
	if v22 then v22:Destroy() end
	if v23 then v23:Destroy() end
	if l__Sounds__20 then l__Sounds__20:Destroy() end
	if v52 then v52:Disconnect() end
end 

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local FireSmiteEvent = ReplicatedStorage:WaitForChild("FireSmite", 10)

if FireSmiteEvent then
	FireSmiteEvent.OnClientEvent:Connect(function(donator, recipient, amount, userId)
		local safeDonator = donator or "Anonymous"
		local safeRecipient = recipient or "SAWERIA"
		local safeAmount = tonumber(amount) or 0
		local safeUserId = tonumber(userId) or 156 

		local smiteModel = ReplicatedStorage:WaitForChild("VFX"):WaitForChild("Templates"):WaitForChild("UltraHammerGiant")

		debugPrint("[Layar Ultra] Memulai Animasi untuk:", safeDonator, "| UserId:", safeUserId)

		if type(u7) == "function" then
			u7(smiteModel, safeDonator, safeRecipient, safeAmount, safeUserId)
		else
			warn("?? Fungsi u7 tidak ditemukan dalam script ini!")
		end
	end)
end


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
local collectionService = game:GetService("CollectionService")

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

function Utils:HideGui(guiObj, shouldHide)
	if guiObj:IsA("BillboardGui") or guiObj:IsA("SurfaceGui") then
		guiObj.Enabled = not shouldHide
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
local HideUISystem = { hiddenGuis = {}, childAddedConn = nil }

local FeatureManager = {
	features = {},
	featureStates = {}
}

-- ============================================
-- FEATURES CONFIGURATION
-- ============================================
local FEATURES = {
	{
		id = "overhead",
		name = "Hide Player Name",
		defaultState = false,
		onToggle = function(self, isActive) OverheadSystem:SetVisible(not isActive) end,
		onCharacterAdded = function(self, character, player) OverheadSystem:OnCharacterAdded(character, player) end
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
		defaultState = true,
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
		if featureConfig.onToggle then
			task.spawn(function() featureConfig.onToggle(featureConfig, true) end)
		end
	else
		button.Position = CONFIG.BUTTON_POS_OFF
		bg.BackgroundColor3 = CONFIG.BG_COLOR_OFF
		if featureConfig.onToggle then
			task.spawn(function() featureConfig.onToggle(featureConfig, false) end)
		end
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

		-- 🔥 FIX 2: Cegah UI baru muncul saat mode Hide UI sedang menyala (Penjaga Pintu)
		if not self.childAddedConn then
			self.childAddedConn = playerGui.ChildAdded:Connect(function(childGui)
				if childGui:IsA("ScreenGui") and childGui ~= gui then
					task.wait() -- Tunggu properti terisi penuh oleh Roblox
					if childGui.Enabled then
						self.hiddenGuis[childGui] = true
						childGui.Enabled = false
					end
				end
			end)
		end
	else
		for hiddenGui, _ in pairs(self.hiddenGuis) do
			if hiddenGui and hiddenGui.Parent then hiddenGui.Enabled = true end
		end
		self.hiddenGuis = {} 
		unhideBtn.Visible = false

		if self.childAddedConn then
			self.childAddedConn:Disconnect()
			self.childAddedConn = nil
		end
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
	local isHidingNames = FeatureManager:GetFeatureState("overhead")
	local isHidingPlayers = FeatureManager:GetFeatureState("players")

	for _, otherPlayer in pairs(player:GetPlayers()) do
		if otherPlayer.Character then
			-- 🔥 FIX 1: Cross-check dengan status Hide Players
			local shouldHide = isHidingNames
			if otherPlayer ~= localPlayer and isHidingPlayers then
				shouldHide = true
			end

			local head = otherPlayer.Character:FindFirstChild("Head")
			if head then self:HideOverheadGui(head, shouldHide) end
		end
	end
end

function OverheadSystem:OnCharacterAdded(character, otherPlayer)
	character.ChildAdded:Connect(function(child)
		if child.Name == "Head" then
			child.ChildAdded:Connect(function(grandChild)
				if grandChild.Name == "OverheadGui" then
					-- 🔥 FIX 3: task.wait() SEBELUM IF, bukan SESUDAH IF
					task.wait(0.1)

					local isHidingNames = FeatureManager:GetFeatureState("overhead")
					local isHidingPlayers = FeatureManager:GetFeatureState("players")

					local shouldHide = isHidingNames
					if otherPlayer ~= localPlayer and isHidingPlayers then
						shouldHide = true
					end

					if shouldHide then
						grandChild.Enabled = false
					end
				end
			end)
		end
	end)

	task.wait(CONFIG.WAIT_FOR_OVERHEAD)

	local isHidingNames = FeatureManager:GetFeatureState("overhead")
	local isHidingPlayers = FeatureManager:GetFeatureState("players")

	local shouldHide = isHidingNames
	if otherPlayer ~= localPlayer and isHidingPlayers then
		shouldHide = true
	end

	if shouldHide then
		local head = character:FindFirstChild("Head")
		if head then self:HideOverheadGui(head, true) end
	end
end

function ShadowSystem:SetVisible(visible)
	lighting.GlobalShadows = visible
end

-- ============================================
-- EFFECTS HIDE SYSTEM
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
	local isHidingEffects = FeatureManager:GetFeatureState("effects")
	local isHidingPlayers = FeatureManager:GetFeatureState("players")

	-- Sembunyikan efek di semua karakter
	for _, otherPlayer in pairs(player:GetPlayers()) do
		if otherPlayer ~= localPlayer and otherPlayer.Character then
			local character = otherPlayer.Character

			-- 🔥 FIX 1: Jika Hide Players menyala, Efek HARUS disembunyikan
			local shouldHide = isHidingEffects or isHidingPlayers

			self:HideCharacterEffects(character, shouldHide)
			self:HideLights(character, shouldHide)
			self:HideAuraEffects(character, shouldHide)
		end
	end

	-- Sembunyikan objek donasi di Workspace berdasarkan TAG
	local shouldHideWorkspace = isHidingEffects
	for _, effect in ipairs(collectionService:GetTagged("DonationEffect")) do
		Utils:HideBasePart(effect, shouldHideWorkspace)
		for _, desc in ipairs(effect:GetDescendants()) do
			Utils:HideEffect(desc, shouldHideWorkspace)
			Utils:HideLight(desc, shouldHideWorkspace)
			Utils:HideBasePart(desc, shouldHideWorkspace)
		end
	end
end

function EffectsSystem:OnCharacterAdded(character, otherPlayer)
	if otherPlayer ~= localPlayer then
		task.wait(CONFIG.WAIT_FOR_EFFECTS)

		local isHidingEffects = FeatureManager:GetFeatureState("effects")
		local isHidingPlayers = FeatureManager:GetFeatureState("players")
		local shouldHide = isHidingEffects or isHidingPlayers

		if shouldHide then
			self:HideCharacterEffects(character, true)
			self:HideLights(character, true)
			self:HideAuraEffects(character, true)
		end

		-- Di dalam EffectsSystem:OnCharacterAdded
		character.DescendantAdded:Connect(function(descendant)
			-- 🔥 FIX MEMORY SPIKE: Langsung filter dan eksekusi TANPA task.wait()
			if descendant:IsA("ParticleEmitter") or descendant:IsA("Light") then
				if FeatureManager:GetFeatureState("effects") or FeatureManager:GetFeatureState("players") then
					Utils:HideEffect(descendant, true)
					Utils:HideLight(descendant, true)
				end
			end
		end)

		character.ChildAdded:Connect(function(child)
			task.wait(CONFIG.WAIT_FOR_EFFECTS)
			if Utils:IsAura(child) and (FeatureManager:GetFeatureState("effects") or FeatureManager:GetFeatureState("players")) then
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
	task.wait(0.1) 
	if FeatureManager:GetFeatureState("effects") then
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
	local isHidingEffects = FeatureManager:GetFeatureState("effects")

	-- Efek tidak boleh muncul ulang jika salah satu tombol (Hide Players atau Hide Effects) menyala
	local hideEffect = shouldHide or isHidingEffects

	for _, descendant in pairs(object:GetDescendants()) do
		Utils:HideBasePart(descendant, shouldHide)
		Utils:HideEffect(descendant, hideEffect)
		Utils:HideLight(descendant, hideEffect)
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
	local isHidingPlayers = FeatureManager:GetFeatureState("players")
	local isHidingNames = FeatureManager:GetFeatureState("overhead")

	for _, otherPlayer in pairs(player:GetPlayers()) do
		if otherPlayer ~= localPlayer and otherPlayer.Character then
			local character = otherPlayer.Character

			self:HideObject(character, isHidingPlayers)
			self:HideTools(otherPlayer, character, isHidingPlayers)

			local head = character:FindFirstChild("Head")
			if head then 
				-- 🔥 FIX 1: Cross-check dengan Hide Player Name
				local hideOverhead = isHidingPlayers or isHidingNames
				OverheadSystem:HideOverheadGui(head, hideOverhead) 
			end
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
			task.wait(CONFIG.WAIT_FOR_TOOLS)
			if FeatureManager:GetFeatureState("players") then
				if child:IsA("Tool") or Utils:IsAura(child) then 
					self:HideObject(child, true) 
				end
			end
		end)

		if otherPlayer.Backpack then
			otherPlayer.Backpack.ChildAdded:Connect(function(child)
				task.wait(CONFIG.WAIT_FOR_TOOLS)
				if child:IsA("Tool") and FeatureManager:GetFeatureState("players") then
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

local function processQueue()
	if isPlaying then return end
	isPlaying = true

	while #queue > 0 do
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
	end

	isPlaying = false
end

NotifEvent.OnClientEvent:Connect(function(data)
	debugLog("📥 Sinyal notifikasi diterima untuk:", data.PlayerName)
	table.insert(queue, data)
	processQueue()
end)
