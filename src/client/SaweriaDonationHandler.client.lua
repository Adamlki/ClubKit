--!native
--!optimize 2
-- ==============================================================================
-- SAWERIA DONATION CLIENT HANDLER
-- Menggunakan StarterGui.SaweriaDonationGui fisik yang ada di Roblox Studio
-- ==============================================================================

if _G.__SaweriaDonationHandlerLoaded then return end
_G.__SaweriaDonationHandlerLoaded = true

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- TopbarPlus
local Icon = require(ReplicatedStorage:WaitForChild("Icon"))

-- ==============================================================================
-- UI REFERENCES (Membaca GUI Fisik dari StarterGui / PlayerGui)
-- ==============================================================================
local gui = playerGui:WaitForChild("SaweriaDonationGui")
local backdrop = gui:WaitForChild("Backdrop")
local mainCard = gui:WaitForChild("MainCard")

local headerBar = mainCard:WaitForChild("HeaderBar")
local closeBtn = headerBar:WaitForChild("CloseBtn")

local contentFrame = mainCard:WaitForChild("ContentFrame")

-- Kolom Kiri
local leftCol = contentFrame:WaitForChild("LeftCol")
local avatarRing = leftCol:WaitForChild("AvatarRing")
local avatarImage = avatarRing:WaitForChild("AvatarImage")
local displayNameLabel = leftCol:WaitForChild("DisplayNameLabel")
local usernameLabel = leftCol:WaitForChild("UsernameLabel")
local totalDonatedValue = leftCol:WaitForChild("TotalDonatedValue")

-- Kolom Kanan
local rightCol = contentFrame:WaitForChild("RightCol")
local linkBoxContainer = rightCol:WaitForChild("LinkBoxContainer")
local linkTextBox = linkBoxContainer:WaitForChild("LinkTextBox")
local copyLinkBtn = rightCol:WaitForChild("CopyLinkBtn")
local instructionsLabel = rightCol:WaitForChild("InstructionsLabel")
local usernameHighlight = rightCol:WaitForChild("UsernameHighlight")

-- ==============================================================================
-- STATE & FORMATTING
-- ==============================================================================
local isOpen = false
local saweriaIcon = nil

local function formatNumber(num)
	num = tonumber(num) or 0
	local formatted = tostring(math.floor(num))
	local k
	while true do
		formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1.%2")
		if k == 0 then break end
	end
	return formatted
end

-- ==============================================================================
-- UPDATE STATS & DATA PEMAIN
-- ==============================================================================
local function updateStats()
	avatarImage.Image = string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150", player.UserId)
	displayNameLabel.Text = player.DisplayName
	usernameLabel.Text = "@" .. player.Name

	-- Perbarui instruksi dengan username pemain asli berwarna merah
	instructionsLabel.Text = string.format(
		"1. Tekan <b>COPY LINK</b> lalu buka link donasinya.\n" ..
		"2. Masukkan nominal donasi (CASH).\n" ..
		"3. Di kolom <b>Nama / Dari</b>, isi <b>username Roblox</b> kamu:\n" ..
		"   <font color=\"rgb(235, 50, 50)\"><b>%s</b></font>\n" ..
		"4. Selesaikan pembayaran — CASH masuk otomatis.",
		player.Name
	)

	usernameHighlight.Text = string.format("Username : <font color=\"rgb(235, 50, 50)\"><b>%s</b></font>", player.Name)

	-- Ambil total donasi riil pemain dari server
	local getStatsRemote = ReplicatedStorage:FindFirstChild("GetPlayerDonationStats")
	if getStatsRemote and getStatsRemote:IsA("RemoteFunction") then
		task.spawn(function()
			local ok, stats = pcall(function() return getStatsRemote:InvokeServer() end)
			if ok and type(stats) == "table" then
				local rupiah = tonumber(stats.rupiah) or 0
				if rupiah > 0 then
					totalDonatedValue.Text = string.format("%s CASH", formatNumber(rupiah))
				else
					totalDonatedValue.Text = "0 CASH"
				end
			end
		end)
	end
end

-- ==============================================================================
-- OPEN & CLOSE CONTROLLER (Instan Tanpa Animasi Sesuai Permintaan)
-- ==============================================================================
local function openSaweria()
	if isOpen then return end
	isOpen = true

	-- Tutup Robux Donation Board jika sedang terbuka agar tidak tumpang tindih
	if _G.CloseRobuxDonation then
		pcall(_G.CloseRobuxDonation)
	end

	updateStats()

	backdrop.BackgroundTransparency = 0.5
	backdrop.Visible = true
	mainCard.BackgroundTransparency = 0
	mainCard.Size = UDim2.new(0, 760, 0, 480)
	mainCard.Visible = true

	if saweriaIcon and not saweriaIcon.isSelected then
		pcall(function() saweriaIcon:select() end)
	end
end

local function closeSaweria()
	if not isOpen then return end
	isOpen = false

	backdrop.Visible = false
	mainCard.Visible = false

	if saweriaIcon and saweriaIcon.isSelected then
		pcall(function() saweriaIcon:deselect() end)
	end
end

_G.OpenSaweria = openSaweria
_G.CloseSaweria = closeSaweria

-- ==============================================================================
-- EVENT BINDINGS
-- ==============================================================================
-- Inisialisasi awal: pastikan tertutup saat pertama join
backdrop.Visible = false
mainCard.Visible = false

closeBtn.MouseButton1Click:Connect(closeSaweria)
backdrop.MouseButton1Click:Connect(closeSaweria)

-- Animasi Tombol Close
closeBtn.MouseEnter:Connect(function()
	TweenService:Create(closeBtn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(245, 70, 70)}):Play()
end)
closeBtn.MouseLeave:Connect(function()
	TweenService:Create(closeBtn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(220, 55, 55)}):Play()
end)

-- Tombol Copy Link
copyLinkBtn.MouseEnter:Connect(function()
	TweenService:Create(copyLinkBtn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(68, 64, 80)}):Play()
end)
copyLinkBtn.MouseLeave:Connect(function()
	TweenService:Create(copyLinkBtn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(50, 48, 60)}):Play()
end)

copyLinkBtn.MouseButton1Click:Connect(function()
	linkTextBox:CaptureFocus()
	linkTextBox.SelectionStart = 1
	linkTextBox.CursorPosition = #linkTextBox.Text + 1

	if setclipboard then
		pcall(function() setclipboard(linkTextBox.Text) end)
	end

	local originalText = copyLinkBtn.Text
	copyLinkBtn.Text = "✓ LINK COPIED!"
	copyLinkBtn.TextColor3 = Color3.fromRGB(76, 217, 100)
	copyLinkBtn.BackgroundColor3 = Color3.fromRGB(35, 60, 45)

	task.delay(2, function()
		if copyLinkBtn and copyLinkBtn.Parent then
			copyLinkBtn.Text = originalText
			copyLinkBtn.TextColor3 = Color3.fromRGB(240, 240, 240)
			copyLinkBtn.BackgroundColor3 = Color3.fromRGB(50, 48, 60)
		end
	end)
end)

-- ==============================================================================
-- TOPBAR PLUS INTEGRATION (Icon Saweria Mandiri)
-- ==============================================================================
pcall(function()
	if Icon.getIcon and Icon.getIcon("SaweriaDonationIcon") then
		return
	end

	saweriaIcon = Icon.new()
		:setName("SaweriaDonationIcon")
		:setImage("rbxassetid://15040641378")
		:setLabel("")
		:setOrder(3) -- Berdampingan di sebelah Robux Donate (Order 2)

	saweriaIcon.selected:Connect(function()
		openSaweria()
	end)

	saweriaIcon.deselected:Connect(function()
		closeSaweria()
	end)
end)

print("[SaweriaDonationHandler] ✅ Connected to StarterGui.SaweriaDonationGui successfully!")
