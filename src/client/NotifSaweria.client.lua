-- ========================================
-- DONATION UI CLIENT (LOGIC ONLY)
-- Versi FADE IN/OUT (Tidak Geser/Ubah Posisi) - FIX FORMAT ANGKA
-- Taruh di StarterPlayer > StarterPlayerScripts
-- ========================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

-- ========================================
-- CONFIG & DEBUG SETTINGS
-- ========================================
local DEBUG_ENABLED = false -- Ubah ke 'true' untuk melihat proses animasi, 'false' untuk rilis
local DEBUG_PREFIX = "[SaweriaClientUI]"

local function debugPrint(...)
	if DEBUG_ENABLED then print(DEBUG_PREFIX, ...) end
end

local function debugWarn(...)
	if DEBUG_ENABLED then warn(DEBUG_PREFIX, ...) end
end

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Tunggu GUI dari StarterGui ter-load
local notifGui = playerGui:WaitForChild("NotifSaweriaGui", 15)
if not notifGui then
	debugWarn("❌ NotifSaweriaGui tidak ditemukan di PlayerGui!")
	return
end

local notifFrame = notifGui:WaitForChild("NotifFrame")
local usernameLabel = notifFrame:WaitForChild("UsernameLabel")
local amountLabel = notifFrame:WaitForChild("AmountLabel")
local messageLabel = notifFrame:WaitForChild("MessageLabel")
local profilAvaLabel = notifFrame:WaitForChild("ProfilAvaLabel")

-- Kumpulkan semua elemen GUI yang perlu di-fade
local guiObjectsToFade = {}
local uiStrokesToFade = {}

for _, obj in ipairs(notifFrame:GetDescendants()) do
	if obj:IsA("GuiObject") then
		table.insert(guiObjectsToFade, obj)
	elseif obj:IsA("UIStroke") then
		table.insert(uiStrokesToFade, obj)
	end
end
table.insert(guiObjectsToFade, notifFrame)

-- Simpan transparansi asli hasil desain dari Studio
local originalTransparencies = {}
for _, obj in ipairs(guiObjectsToFade) do
	if obj:IsA("ImageLabel") then
		originalTransparencies[obj] = obj.ImageTransparency
	elseif obj:IsA("TextLabel") or obj:IsA("Frame") then
		originalTransparencies[obj] = {
			bg = obj.BackgroundTransparency,
			text = obj:IsA("TextLabel") and obj.TextTransparency or nil
		}
	end
end
for _, stroke in ipairs(uiStrokesToFade) do
	originalTransparencies[stroke] = stroke.Transparency
end

-- Tunggu RemoteEvent
local donationEvent = ReplicatedStorage:WaitForChild("DonationNotification", 10)
if not donationEvent then
	debugWarn("❌ DonationNotification event not found di ReplicatedStorage!")
	return
end

debugPrint("✅ Donation UI Client Ready! (Versi Pure Fade)")

-- ========================================
-- FUNGSI FORMAT RUPIAH MANUAL (FIX ERROR %d)
-- ========================================
local function formatIDR(amount)
	local formatted = tostring(math.floor(amount))
	local k
	while true do  
		formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1.%2')
		if k == 0 then break end
	end
	return "IDR " .. formatted
end

-- ========================================
-- SISTEM ANIMASI FADE
-- ========================================
local currentNotifId = 0
local ANIMATION_TIME = 0.5
local DISPLAY_TIME = 6

local function setAllTransparency(targetTransparency)
	for _, obj in ipairs(guiObjectsToFade) do
		if targetTransparency == 1 then
			-- Fade Out
			TweenService:Create(obj, TweenInfo.new(ANIMATION_TIME), {BackgroundTransparency = 1}):Play()
			if obj:IsA("TextLabel") then
				TweenService:Create(obj, TweenInfo.new(ANIMATION_TIME), {TextTransparency = 1}):Play()
			elseif obj:IsA("ImageLabel") then
				TweenService:Create(obj, TweenInfo.new(ANIMATION_TIME), {ImageTransparency = 1}):Play()
			end
		else
			-- Fade In (kembali ke settingan Studio)
			local orig = originalTransparencies[obj]
			if orig then
				if obj:IsA("ImageLabel") then
					TweenService:Create(obj, TweenInfo.new(ANIMATION_TIME), {ImageTransparency = orig}):Play()
				else
					TweenService:Create(obj, TweenInfo.new(ANIMATION_TIME), {BackgroundTransparency = orig.bg}):Play()
					if orig.text then
						TweenService:Create(obj, TweenInfo.new(ANIMATION_TIME), {TextTransparency = orig.text}):Play()
					end
				end
			end
		end
	end

	for _, stroke in ipairs(uiStrokesToFade) do
		local orig = originalTransparencies[stroke] or 0
		local target = targetTransparency == 1 and 1 or orig
		TweenService:Create(stroke, TweenInfo.new(ANIMATION_TIME), {Transparency = target}):Play()
	end
end

-- Persiapan Awal (Sembunyikan GUI tanpa mengubah posisi/ukuran)
for _, obj in ipairs(guiObjectsToFade) do
	obj.BackgroundTransparency = 1
	if obj:IsA("TextLabel") then obj.TextTransparency = 1
	elseif obj:IsA("ImageLabel") then obj.ImageTransparency = 1 end
end
for _, stroke in ipairs(uiStrokesToFade) do stroke.Transparency = 1 end
notifFrame.Visible = false

local function playDonationSound()
	debugPrint("🎵 Memutar suara notifikasi...")
	local sound = Instance.new("Sound")
	sound.SoundId = "rbxassetid://120816380864913"
	sound.Volume = 0.7
	sound.Parent = workspace
	sound:Play()
	game:GetService("Debris"):AddItem(sound, 3)
end

-- ========================================
-- LISTEN EVENT DARI SERVER
-- ========================================
donationEvent.OnClientEvent:Connect(function(data)
	if not data or not data.donator then return end

	currentNotifId = currentNotifId + 1
	local thisNotifId = currentNotifId

	debugPrint("🔔 Menerima sinyal donasi dari:", data.donator, "| Rp", data.amount)

	-- Update Data
	usernameLabel.Text = "@" .. data.donator
	amountLabel.Text = "Saweria : " .. formatIDR(tonumber(data.amount) or 0) .. " | Total : " .. formatIDR(tonumber(data.total) or tonumber(data.amount) or 0)

	if data.message and data.message ~= "" and data.message ~= "N/A" then
		messageLabel.Text = "Mssg : " .. data.message
		messageLabel.Visible = true
	else
		messageLabel.Visible = false
	end

	-- Avatar Fetching
	profilAvaLabel.Image = "rbxthumb://type=AvatarHeadShot&id=156&w=150&h=150"
	task.spawn(function()
		local success, userId = pcall(function()
			return Players:GetUserIdFromNameAsync(data.donator)
		end)
		if success and userId then
			if currentNotifId == thisNotifId then
				profilAvaLabel.Image = "rbxthumb://type=AvatarHeadShot&id=" .. userId .. "&w=150&h=150"
			end
		end
	end)

	notifFrame.Visible = true
	pcall(playDonationSound)

	debugPrint("Mulai animasi Fade-In...")
	setAllTransparency(0)

	-- Timer untuk Fade Out
	task.delay(DISPLAY_TIME, function()
		if currentNotifId == thisNotifId then
			debugPrint("Mulai animasi Fade-Out...")
			setAllTransparency(1)

			task.wait(ANIMATION_TIME)

			if currentNotifId == thisNotifId then
				notifFrame.Visible = false
				debugPrint("UI Donasi kembali disembunyikan.")
			end
		else
			debugPrint("Fade-Out dibatalkan karena ada notifikasi donasi baru yang masuk.")
		end
	end)
end)