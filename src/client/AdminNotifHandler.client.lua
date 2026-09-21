-- ====================================
-- SINGLETON PROTECTION
-- ====================================
if _G.__AdminNotifHandlerLoaded then return end
_G.__AdminNotifHandlerLoaded = true

local Players      = game:GetService("Players")
local RS           = game:GetService("ReplicatedStorage")
local TS           = game:GetService("TweenService")
local SG           = game:GetService("StarterGui")

local player       = Players.LocalPlayer
local playerGui    = player:WaitForChild("PlayerGui")

-- ====================================
-- REMOTE REFERENCES
-- ====================================
local RemoteFolder         = RS:WaitForChild("Message")
local SendMessageRemote    = RemoteFolder:WaitForChild("SendMessage")
local ReceiveMessageRemote = RemoteFolder:WaitForChild("ReceiveMessage")
local CheckTimerRemote     = RemoteFolder:WaitForChild("CheckTimer")

-- ====================================
-- UI REFERENCES
-- ====================================
local gui          = script.Parent:IsA("ScreenGui") and script.Parent or playerGui:WaitForChild("AdminNotif")
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

-- Sembunyikan template asli di GUI
messageFrame.Visible = false

-- ====================================
-- CONFIG
-- ====================================
local Config = {
	Notification = {
		Duration   = 8, -- 8 detik display time
		MaxVisible = 2, -- Maksimal notifikasi bersamaan agar tidak menutupi seluruh layar
	},
	Timer = {
		ShowNotification = true
	}
}

-- ====================================
-- STATE
-- ====================================
local activeNotifications   = {}
local notificationContainer = nil
local notificationListFrame = nil
local notifCounter          = 0
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
-- NOTIFICATION CONTAINER WITH UILISTLAYOUT
-- ====================================
local function setupNotificationContainer()
	if notificationContainer and notificationContainer.Parent and notificationListFrame and notificationListFrame.Parent then
		return
	end

	notificationContainer = playerGui:FindFirstChild("MessageNotifications")
	if not notificationContainer then
		notificationContainer = Instance.new("ScreenGui")
		notificationContainer.Name           = "MessageNotifications"
		notificationContainer.ResetOnSpawn   = false
		notificationContainer.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		notificationContainer.DisplayOrder   = 100
		notificationContainer.Parent         = playerGui
	end

	notificationListFrame = notificationContainer:FindFirstChild("NotificationList")
	if not notificationListFrame then
		notificationListFrame = Instance.new("Frame")
		notificationListFrame.Name                   = "NotificationList"
		notificationListFrame.Size                   = UDim2.new(0, 600, 0.85, 0)
		notificationListFrame.Position               = UDim2.new(0.5, 0, 0.04, 0)
		notificationListFrame.AnchorPoint            = Vector2.new(0.5, 0)
		notificationListFrame.BackgroundTransparency = 1
		notificationListFrame.BorderSizePixel        = 0
		notificationListFrame.ClipsDescendants       = false
		notificationListFrame.Parent                 = notificationContainer

		local listLayout = Instance.new("UIListLayout")
		listLayout.Name                 = "ListLayout"
		listLayout.FillDirection        = Enum.FillDirection.Vertical
		listLayout.HorizontalAlignment  = Enum.HorizontalAlignment.Center
		listLayout.VerticalAlignment    = Enum.VerticalAlignment.Top
		listLayout.SortOrder            = Enum.SortOrder.LayoutOrder
		listLayout.Padding              = UDim.new(0, 8) -- Jarak 8px rapi antar notifikasi ke bawah
		listLayout.Parent               = notificationListFrame
	end
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

local function sanitizeHtml(text)
	text = tostring(text or "")
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
-- NOTIFICATION CREATION & STACKING
-- ====================================
local function createNotification(messageData)
	setupNotificationContainer()
	if not notificationListFrame then return end

	local notif = templateNotif:Clone()
	notif.Name = "AdminNotif_" .. tostring(os.clock())
	
	-- LayoutOrder dinaikkan agar notifikasi baru otomatis tersusun di BAWAH notifikasi lama
	notifCounter = notifCounter + 1
	notif.LayoutOrder = notifCounter

	-- Setup Avatar Bust/Headshot Admin
	local avatarImg = notif:FindFirstChild("Avatar")
	if avatarImg and avatarImg:IsA("ImageLabel") then
		local sId = tonumber(messageData.SenderId)
		if sId and sId > 0 then
			avatarImg.Image = string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150", sId)
		else
			avatarImg.Image = "rbxasset://textures/ui/GuiImagePlaceholder.png"
		end
	end

	-- Setup Pesan Text: SenderName 📢 : Message
	local messageLabel = notif:FindFirstChild("Message")
	if messageLabel and messageLabel:IsA("TextLabel") then
		messageLabel.RichText = true
		
		local rawMessage = messageData.Message or ""
		local isGlobal = rawMessage:find("%[GLOBAL%]") ~= nil
		local cleanMessage = rawMessage:gsub("%[[Gg][Ll][Oo][Bb][Aa][Ll]%]%s*:?%s*", "")

		-- SenderName di-sanitize di client karena belum di-escape oleh server
		local safeSender = sanitizeHtml(messageData.SenderName or "Admin")
		-- cleanMessage SUDAH di-sanitize oleh server, jangan di-sanitize ulang agar tidak double escape (&amp;amp;)
		local safeMsg = cleanMessage

		local prefixTag = isGlobal and "[GLOBAL] " or ""
		messageLabel.Text = string.format('<font color="#FFCC00"><b>%s%s</b></font> 📢 : <b>%s</b>', prefixTag, safeSender, safeMsg)
	end

	-- Setup Dismiss Handler (8 Detik atau Tombol Close)
	local isDismissed = false
	local notifData = {
		Frame = notif,
		CreatedAt = os.clock()
	}

	local function dismissThisNotif()
		if isDismissed then return end
		isDismissed = true

		for i, entry in ipairs(activeNotifications) do
			if entry == notifData then
				table.remove(activeNotifications, i)
				break
			end
		end

		if notif and notif.Parent then
			-- Animasi keluar halus: shrink height dan fade out
			local fadeInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			local shrinkTween = TS:Create(notif, fadeInfo, {
				Size = UDim2.new(0, 580, 0, 0),
				BackgroundTransparency = 1
			})

			for _, desc in ipairs(notif:GetDescendants()) do
				if desc:IsA("TextLabel") or desc:IsA("TextButton") then
					TS:Create(desc, fadeInfo, { TextTransparency = 1, BackgroundTransparency = 1 }):Play()
				elseif desc:IsA("ImageLabel") or desc:IsA("ImageButton") then
					TS:Create(desc, fadeInfo, { ImageTransparency = 1, BackgroundTransparency = 1 }):Play()
				elseif desc:IsA("UIStroke") then
					TS:Create(desc, fadeInfo, { Transparency = 1 }):Play()
				end
			end

			shrinkTween:Play()
			shrinkTween.Completed:Connect(function()
				if notif and notif.Parent then
					notif:Destroy()
				end
			end)
		end
	end

	local notifCloseBtn = notif:FindFirstChild("CloseBtn")
	if notifCloseBtn and notifCloseBtn:IsA("GuiButton") then
		notifCloseBtn.MouseButton1Click:Once(dismissThisNotif)
	end

	-- Batasi maksimal notifikasi visible di layar
	table.insert(activeNotifications, notifData)
	if #activeNotifications > Config.Notification.MaxVisible then
		local oldest = activeNotifications[1]
		if oldest and oldest.Frame then
			table.remove(activeNotifications, 1)
			pcall(function() oldest.Frame:Destroy() end)
		end
	end

	-- Animasi Masuk: Muncul dari height 0 ke ukuran penuh 46px
	notif.Size = UDim2.new(0, 580, 0, 0)
	notif.BackgroundTransparency = 1
	notif.Visible = true
	notif.Parent = notificationListFrame

	local enterInfo = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	TS:Create(notif, enterInfo, {
		Size = UDim2.new(0, 580, 0, 46),
		BackgroundTransparency = 0.05
	}):Play()

	-- Durasi tampil tepat 8 detik sesuai permintaan
	task.delay(Config.Notification.Duration, function()
		if not isDismissed then
			dismissThisNotif()
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
			if _G.HideAdminNotif then
				return
			end
			createNotification(messageData)
		end
	end
end)

-- ====================================
-- INITIALIZE
-- ====================================
refreshTimerData()
