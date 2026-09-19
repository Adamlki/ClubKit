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
local NOTIF_DISPLAY_TIME = 5.0

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
		sound.SoundId = "rbxassetid://120816380864913"
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
		local headerFrame = notifFrame:FindFirstChild("HeaderFrame") or notifFrame
		local nameLabel = headerFrame:FindFirstChild("UsernameLabel") or headerFrame:FindFirstChild("PlayerName")
		local amountLabel = headerFrame:FindFirstChild("AmountLabel")
		local messageLabel = notifFrame:FindFirstChild("MessageLabel") or notifFrame:FindFirstChild("NotificationText")

		if nameLabel then
			nameLabel.Text = tostring(current.donator or "Anonymous")
		end

		if amountLabel then
			amountLabel.Text = "Rp " .. formatIDR(current.amount)
		end

		if messageLabel then
			local clean = current.message and current.message:match("^%s*(.-)%s*$") or ""
			if clean ~= "" and clean ~= "N/A" and clean ~= "nil" and clean ~= "default" then
				messageLabel.Text = '"' .. clean .. '"'
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

		-- Tahan selama 5 detik lalu Slide Out
		task.delay(NOTIF_DISPLAY_TIME, function()
			if not notifFrame or not notifFrame.Visible then
				_G.__ActiveDonationNotification = false
				isDisplayingNotif = false
				processQueue()
				return
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
	local message = tostring(data.message or "")

	debugPrint("🔔 Donasi Saweria masuk antrean:", donatorName, "| Rp", amount)

	table.insert(donationQueue, {
		donator = donatorName,
		amount = amount,
		message = message,
	})

	processQueue()
end)

debugPrint("✅ Saweria Client Notification ready (Driving manual NotifFrame - Gold Theme)!")