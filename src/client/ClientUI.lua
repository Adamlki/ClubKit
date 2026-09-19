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
	return "%s telah mendonasikan %s Robux!"
end

function ClientUI.sendDonationChatMessage(displayName, amount)
	local template = getChatMessageTemplate(amount)
	local formattedAmount = ClientUI.formatNumber(amount)
	local tierColor = ClientUI.getDonationColor(amount)
	local hexColor  = colorToHex(tierColor)

	local rawText = string.format(template, displayName, formattedAmount)
	local richText = string.format(
		"<font color=\"#%s\"><b>[DONATION]</b> %s</font>",
		hexColor,
		sanitizeHtml(rawText)
	)

	pcall(function()
		local generalChannel = TextChatService:WaitForChild("TextChannels", 2)
			and TextChatService.TextChannels:FindFirstChild("RBXGeneral")
		if generalChannel then
			generalChannel:DisplaySystemMessage(richText)
			return
		end

		StarterGui:SetCore("ChatMakeSystemMessage", {
			Text  = rawText,
			Color = tierColor,
			Font  = Enum.Font.GothamBold,
		})
	end)
end

local Debris = game:GetService("Debris")

-- ============================================
-- NOTIFICATION BANNER (ROBUX - ORANGE THEME)
-- ============================================

local activeNotificationTween = nil
local NOTIF_DISPLAY_TIME = 5.0
local NOTIF_TARGET_POS = UDim2.new(0.5, 0, 0.05, 0)
local NOTIF_HIDDEN_POS = UDim2.new(0.5, 0, -0.2, 0)

local function playRobuxDonationSound()
	pcall(function()
		local soundId = (ClientConfig.NOTIFICATION and ClientConfig.NOTIFICATION.SOUND_ID) or "rbxassetid://82038059105956"
		local sound = Instance.new("Sound")
		sound.SoundId = soundId
		sound.Volume = (ClientConfig.NOTIFICATION and ClientConfig.NOTIFICATION.SOUND_VOLUME) or 0.6
		sound.Parent = workspace
		sound:Play()
		Debris:AddItem(sound, 4)
	end)
end

function ClientUI.initNotification(notificationFrame)
	if notificationFrame then
		notificationFrame.Visible = false
		notificationFrame.Position = NOTIF_HIDDEN_POS
	end
end

function ClientUI.showNotification(notificationFrame, displayName, amount, message, onComplete)
	if not ClientConfig.NOTIFICATION.ENABLED then
		if onComplete then onComplete() end
		return
	end

	if not notificationFrame then
		if onComplete then onComplete() end
		return
	end

	task.spawn(function()
		-- Tunggu giliran jika ada notifikasi lain (misal Saweria) yang sedang tampil
		while _G.__ActiveDonationNotification do
			task.wait(0.3)
		end
		_G.__ActiveDonationNotification = true

		-- 1. Isi data langsung ke GUI manual Roblox Studio
		local headerFrame = notificationFrame:FindFirstChild("HeaderFrame") or notificationFrame
		local nameLabel = headerFrame:FindFirstChild("PlayerName") or headerFrame:FindFirstChild("UsernameLabel")
		local amountLabel = headerFrame:FindFirstChild("RobuxAmount") or headerFrame:FindFirstChild("AmountLabel")
		local messageLabel = notificationFrame:FindFirstChild("NotificationText") or notificationFrame:FindFirstChild("MessageLabel")

		if nameLabel then
			nameLabel.Text = tostring(displayName or "Player")
		end

		if amountLabel then
			amountLabel.Text = ClientUI.formatNumber(amount) .. " Robux"
		end

		if messageLabel then
			local clean = message and message:match("^%s*(.-)%s*$") or ""
			if clean ~= "" and clean ~= "N/A" and clean ~= "nil" and clean ~= "default" then
				messageLabel.Text = '"' .. clean .. '"'
			else
				messageLabel.Text = "Terima kasih banyak atas donasinya!"
			end
		end

		-- 2. Putar SFX
		playRobuxDonationSound()

		-- 3. Animasi Muncul (Slide In dari atas dengan Back easing)
		if activeNotificationTween then
			activeNotificationTween:Cancel()
			activeNotificationTween = nil
		end

		notificationFrame.Position = NOTIF_HIDDEN_POS
		notificationFrame.Visible = true

		local slideIn = TweenService:Create(
			notificationFrame,
			TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Position = NOTIF_TARGET_POS }
		)
		activeNotificationTween = slideIn
		slideIn:Play()

		-- 4. Tahan selama 5 detik lalu keluar (Slide Out ke atas)
		task.delay(NOTIF_DISPLAY_TIME, function()
			if not notificationFrame or not notificationFrame.Visible then
				_G.__ActiveDonationNotification = false
				if onComplete then onComplete() end
				return
			end

			local slideOut = TweenService:Create(
				notificationFrame,
				TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{ Position = NOTIF_HIDDEN_POS }
			)
			activeNotificationTween = slideOut
			slideOut:Play()

			slideOut.Completed:Connect(function()
				notificationFrame.Visible = false
				activeNotificationTween = nil
				_G.__ActiveDonationNotification = false
				if onComplete then
					onComplete()
				end
			end)
		end)
	end)
end

return ClientUI
