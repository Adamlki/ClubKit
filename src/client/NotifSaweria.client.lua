--!native
--!optimize 2
-- ==============================================================================
-- SAWERIA NOTIFICATION CLIENT (GOLD THEME - MANUAL GUI)
-- Menggunakan StarterGui.NotifSaweriaGui.NotifFrame manual di Roblox Studio
-- ==============================================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")

local DEBUG_ENABLED = RunService:IsStudio()
local DEBUG_PREFIX = "[SaweriaClientUI]"

local function debugPrint(...)
	if DEBUG_ENABLED then print(DEBUG_PREFIX, ...) end
end

local function debugWarn(...)
	if DEBUG_ENABLED then warn(DEBUG_PREFIX, ...) end
end

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Pastikan NotifSaweriaGui aktif di PlayerGui
local notifGui = playerGui:WaitForChild("NotifSaweriaGui")
notifGui.Enabled = true

local notifFrame = notifGui:WaitForChild("NotifFrame")
local NOTIF_TARGET_POS = UDim2.new(0.5, 0, 0.05, 0)
local NOTIF_HIDDEN_POS = UDim2.new(0.5, 0, -0.2, 0)
local NOTIF_DISPLAY_TIME = 10

notifFrame.Position = NOTIF_HIDDEN_POS
notifFrame.Visible = false

-- Format Rupiah dengan titik ribuan
local function formatIDR(amount)
	local formatted = tostring(math.floor(math.abs(amount)))
	local k
	while true do
		formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1.%2")
		if k == 0 then break end
	end
	return formatted
end

local function parseClientAmount(val)
	if type(val) == "number" then return math.floor(val) end
	if type(val) ~= "string" then return 0 end
	local clean = val:gsub("%D", "")
	return tonumber(clean) or 0
end

local function playSaweriaSound()
	pcall(function()
		local sound = Instance.new("Sound")
		sound.SoundId = "rbxassetid://79392333090964"
		sound.Volume = 0.7
		sound.Parent = workspace
		sound:Play()
		Debris:AddItem(sound, 4)
	end)
end

-- ==============================================================================
-- QUEUE SYSTEM
-- ==============================================================================
local donationQueue = {}
local isDisplayingNotif = false
local activeTween = nil

local function processQueue()
	if isDisplayingNotif or #donationQueue == 0 then return end
	isDisplayingNotif = true

	local current = table.remove(donationQueue, 1)

	task.spawn(function()
		-- Tunggu jika notifikasi Robux sedang aktif di layar
		while _G.__ActiveDonationNotification do
			task.wait(0.3)
		end
		_G.__ActiveDonationNotification = true

		-- Isi data ke GUI manual Roblox Studio
		local nameLabel = notifFrame:FindFirstChild("NameLabel") or notifFrame:FindFirstChild("UsernameLabel") or notifFrame:FindFirstChild("PlayerName")
		local messageBox = notifFrame:FindFirstChild("MessageBox")
		local messageLabel = (messageBox and messageBox:FindFirstChild("MessageLabel")) or notifFrame:FindFirstChild("MessageLabel") or notifFrame:FindFirstChild("NotificationText")
		local footerFrame = notifFrame:FindFirstChild("FooterFrame") or notifFrame
		local donateLabel = footerFrame:FindFirstChild("DonateLabel") or notifFrame:FindFirstChild("AmountLabel")
		local totalLabel = footerFrame:FindFirstChild("TotalLabel")
		local avatarImg = notifFrame:FindFirstChild("Avatar")
		local closeBtn = notifFrame:FindFirstChild("CloseBtn")

		if nameLabel then
			nameLabel.Text = tostring(current.donator or "Anonymous")
		end

		if avatarImg and avatarImg:IsA("ImageLabel") then
			if current.userId and tonumber(current.userId) and tonumber(current.userId) > 0 then
				avatarImg.Image = string.format("rbxthumb://type=AvatarBust&id=%d&w=150&h=150", tonumber(current.userId))
			else
				avatarImg.Image = "rbxasset://textures/ui/GuiImagePlaceholder.png"
			end
		end

		if donateLabel then
			donateLabel.Text = "Donate: Rp " .. formatIDR(current.amount)
		end

		if totalLabel then
			local tot = current.total or current.amount
			totalLabel.Text = "Total : Rp " .. formatIDR(tot)
		end

		if messageLabel then
			local clean = current.message and current.message:match("^%s*(.-)%s*$") or ""
			if clean ~= "" and clean ~= "N/A" and clean ~= "nil" and clean ~= "default" then
				messageLabel.Text = clean
			else
				messageLabel.Text = "Terima kasih banyak atas donasinya!"
			end
		end

		-- Putar SFX Saweria
		playSaweriaSound()

		-- Animasi Slide In
		if activeTween then
			activeTween:Cancel()
			activeTween = nil
		end

		notifFrame.Position = NOTIF_HIDDEN_POS
		notifFrame.Visible = true

		local slideIn = TweenService:Create(
			notifFrame,
			TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Position = NOTIF_TARGET_POS }
		)
		activeTween = slideIn
		slideIn:Play()

		-- Dismiss Handler (Otomatis 5 detik atau saat tombol Close diklik)
		local isClosed = false
		local closeConn = nil

		local function dismissNotif()
			if isClosed then return end
			isClosed = true

			if closeConn then
				closeConn:Disconnect()
				closeConn = nil
			end

			if activeTween then
				activeTween:Cancel()
				activeTween = nil
			end

			local slideOut = TweenService:Create(
				notifFrame,
				TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{ Position = NOTIF_HIDDEN_POS }
			)
			activeTween = slideOut
			slideOut:Play()

			slideOut.Completed:Connect(function()
				notifFrame.Visible = false
				activeTween = nil
				_G.__ActiveDonationNotification = false
				isDisplayingNotif = false
				processQueue()
			end)
		end

		if closeBtn and closeBtn:IsA("GuiButton") then
			closeConn = closeBtn.MouseButton1Click:Once(dismissNotif)
		end

		task.delay(NOTIF_DISPLAY_TIME, function()
			if not isClosed then
				dismissNotif()
			end
		end)
	end)
end

-- ==============================================================================
-- LISTEN EVENT DARI SERVER
-- ==============================================================================
local donationEvent = ReplicatedStorage:WaitForChild("DonationNotification", 15)
if not donationEvent then
	debugWarn("❌ DonationNotification event not found di ReplicatedStorage!")
	return
end

donationEvent.OnClientEvent:Connect(function(data)
	if not data or not data.donator then return end

	local donatorName = tostring(data.donator or "Anonymous")
	local amount = parseClientAmount(data.amount)
	local total = parseClientAmount(data.total)
	if total <= 0 then total = amount end
	local message = tostring(data.message or "")
	local userId = data.userId

	debugPrint("🔔 Donasi Saweria masuk antrean:", donatorName, "| Rp", amount, "| Total: Rp", total)

	table.insert(donationQueue, {
		donator = donatorName,
		userId = userId,
		amount = amount,
		total = total,
		message = message,
	})

	processQueue()
end)

debugPrint("✅ Saweria Client Notification ready (Driving manual NotifFrame - Gold Theme)!")