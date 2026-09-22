--!native
--!optimize 2
-- ==============================================================================
-- SAWERIA DONATION CLIENT HANDLER
-- UI Donasi Saweria Terpisah (Modern Dark Aesthetic dengan Aksen Oranye)
-- ==============================================================================

if _G.__SaweriaDonationHandlerLoaded then return end
_G.__SaweriaDonationHandlerLoaded = true

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local RunService        = game:GetService("RunService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- TopbarPlus
local Icon = require(ReplicatedStorage:WaitForChild("Icon"))

-- ==============================================================================
-- CONFIGURATION
-- ==============================================================================
local CONFIG = {
	TITLE         = "RASA NADA", -- Nama club / game pada header (sesuaikan bila perlu)
	DONATION_LINK = "https://saweria.co/JeksAl", -- Link donasi Saweria / Sociabuzz kamu
	CURRENCY_NAME = "CASH", -- Nama mata uang (misal: "CASH" atau "RUPIAH")
}

-- ==============================================================================
-- BUILD SCREEN GUI
-- ==============================================================================
local existingGui = playerGui:FindFirstChild("SaweriaDonationGui")
if existingGui then existingGui:Destroy() end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "SaweriaDonationGui"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 25
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.IgnoreGuiInset = true
screenGui.Parent = playerGui

-- Dimmed Backdrop
local backdrop = Instance.new("TextButton")
backdrop.Name = "Backdrop"
backdrop.Size = UDim2.new(1, 0, 1, 0)
backdrop.Position = UDim2.new(0, 0, 0, 0)
backdrop.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
backdrop.BackgroundTransparency = 0.5
backdrop.Text = ""
backdrop.AutoButtonColor = false
backdrop.Visible = false
backdrop.Parent = screenGui

-- Main Card (Window)
local mainCard = Instance.new("Frame")
mainCard.Name = "MainCard"
mainCard.AnchorPoint = Vector2.new(0.5, 0.5)
mainCard.Position = UDim2.new(0.5, 0, 0.5, 0)
mainCard.Size = UDim2.new(0, 760, 0, 480)
mainCard.BackgroundColor3 = Color3.fromRGB(16, 16, 20)
mainCard.BorderSizePixel = 0
mainCard.Visible = false
mainCard.ClipsDescendants = false
mainCard.Parent = screenGui

local cardSizeConstraint = Instance.new("UISizeConstraint")
cardSizeConstraint.MinSize = Vector2.new(620, 420)
cardSizeConstraint.MaxSize = Vector2.new(840, 520)
cardSizeConstraint.Parent = mainCard

local cardCorner = Instance.new("UICorner")
cardCorner.CornerRadius = UDim.new(0, 18)
cardCorner.Parent = mainCard

local cardStroke = Instance.new("UIStroke")
cardStroke.Color = Color3.fromRGB(245, 75, 15) -- Vibrant Neon Orange
cardStroke.Thickness = 2.5
cardStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
cardStroke.Parent = mainCard

-- ==============================================================================
-- HEADER BAR
-- ==============================================================================
local headerBar = Instance.new("Frame")
headerBar.Name = "HeaderBar"
headerBar.Size = UDim2.new(1, 0, 0, 65)
headerBar.Position = UDim2.new(0, 0, 0, 0)
headerBar.BackgroundTransparency = 1
headerBar.Parent = mainCard

local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "TitleLabel"
titleLabel.AnchorPoint = Vector2.new(0, 0.5)
titleLabel.Position = UDim2.new(0, 26, 0.5, 0)
titleLabel.Size = UDim2.new(0.6, 0, 0, 32)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = CONFIG.TITLE
titleLabel.Font = Enum.Font.GothamBlack
titleLabel.TextSize = 22
titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = headerBar

local closeBtn = Instance.new("TextButton")
closeBtn.Name = "CloseBtn"
closeBtn.AnchorPoint = Vector2.new(1, 0.5)
closeBtn.Position = UDim2.new(1, -24, 0.5, 0)
closeBtn.Size = UDim2.new(0, 38, 0, 38)
closeBtn.BackgroundColor3 = Color3.fromRGB(220, 55, 55)
closeBtn.Text = "X"
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 18
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.AutoButtonColor = false
closeBtn.Parent = headerBar

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 10)
closeCorner.Parent = closeBtn

local headerDivider = Instance.new("Frame")
headerDivider.Name = "HeaderDivider"
headerDivider.Position = UDim2.new(0, 24, 1, 0)
headerDivider.Size = UDim2.new(1, -48, 0, 1)
headerDivider.BackgroundColor3 = Color3.fromRGB(45, 45, 52)
headerDivider.BorderSizePixel = 0
headerDivider.Parent = headerBar

-- ==============================================================================
-- CONTENT CONTAINER (Two Columns)
-- ==============================================================================
local contentFrame = Instance.new("Frame")
contentFrame.Name = "ContentFrame"
contentFrame.Position = UDim2.new(0, 24, 0, 72)
contentFrame.Size = UDim2.new(1, -48, 1, -86)
contentFrame.BackgroundTransparency = 1
contentFrame.Parent = mainCard

-- LEFT COLUMN (Profile & Total Donated)
local leftCol = Instance.new("Frame")
leftCol.Name = "LeftCol"
leftCol.Position = UDim2.new(0, 0, 0, 0)
leftCol.Size = UDim2.new(0.36, 0, 1, 0)
leftCol.BackgroundTransparency = 1
leftCol.Parent = contentFrame

local leftLayout = Instance.new("UIListLayout")
leftLayout.FillDirection = Enum.FillDirection.Vertical
leftLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
leftLayout.VerticalAlignment = Enum.VerticalAlignment.Center
leftLayout.Padding = UDim.new(0, 8)
leftLayout.Parent = leftCol

-- Avatar Ring
local avatarRing = Instance.new("Frame")
avatarRing.Name = "AvatarRing"
avatarRing.Size = UDim2.new(0, 145, 0, 145)
avatarRing.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
avatarRing.BorderSizePixel = 0
avatarRing.ClipsDescendants = true
avatarRing.Parent = leftCol

local avatarRingCorner = Instance.new("UICorner")
avatarRingCorner.CornerRadius = UDim.new(1, 0)
avatarRingCorner.Parent = avatarRing

local avatarRingStroke = Instance.new("UIStroke")
avatarRingStroke.Color = Color3.fromRGB(245, 75, 15)
avatarRingStroke.Thickness = 3.5
avatarRingStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
avatarRingStroke.Parent = avatarRing

local avatarImage = Instance.new("ImageLabel")
avatarImage.Name = "AvatarImage"
avatarImage.Size = UDim2.new(1, 0, 1, 0)
avatarImage.BackgroundTransparency = 1
avatarImage.Image = string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150", player.UserId)
avatarImage.Parent = avatarRing

-- Display Name
local displayNameLabel = Instance.new("TextLabel")
displayNameLabel.Name = "DisplayNameLabel"
displayNameLabel.Size = UDim2.new(1, 0, 0, 24)
displayNameLabel.BackgroundTransparency = 1
displayNameLabel.Text = player.DisplayName
displayNameLabel.Font = Enum.Font.GothamBold
displayNameLabel.TextSize = 19
displayNameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
displayNameLabel.TextTruncate = Enum.TextTruncate.AtEnd
displayNameLabel.TextXAlignment = Enum.TextXAlignment.Center
displayNameLabel.Parent = leftCol

-- Username
local usernameLabel = Instance.new("TextLabel")
usernameLabel.Name = "UsernameLabel"
usernameLabel.Size = UDim2.new(1, 0, 0, 18)
usernameLabel.BackgroundTransparency = 1
usernameLabel.Text = "@" .. player.Name
usernameLabel.Font = Enum.Font.Gotham
usernameLabel.TextSize = 14
usernameLabel.TextColor3 = Color3.fromRGB(150, 150, 160)
usernameLabel.TextTruncate = Enum.TextTruncate.AtEnd
usernameLabel.TextXAlignment = Enum.TextXAlignment.Center
usernameLabel.Parent = leftCol

-- Total Donated Subtitle
local totalDonatedTitle = Instance.new("TextLabel")
totalDonatedTitle.Name = "TotalDonatedTitle"
totalDonatedTitle.Size = UDim2.new(1, 0, 0, 18)
totalDonatedTitle.BackgroundTransparency = 1
totalDonatedTitle.Text = "TOTAL DONATED"
totalDonatedTitle.Font = Enum.Font.GothamMedium
totalDonatedTitle.TextSize = 12
totalDonatedTitle.TextColor3 = Color3.fromRGB(190, 190, 200)
totalDonatedTitle.TextXAlignment = Enum.TextXAlignment.Center
totalDonatedTitle.Parent = leftCol

-- Total Donated Value
local totalDonatedValue = Instance.new("TextLabel")
totalDonatedValue.Name = "TotalDonatedValue"
totalDonatedValue.Size = UDim2.new(1, 0, 0, 32)
totalDonatedValue.BackgroundTransparency = 1
totalDonatedValue.Text = "0 " .. CONFIG.CURRENCY_NAME
totalDonatedValue.Font = Enum.Font.GothamBlack
totalDonatedValue.TextSize = 25
totalDonatedValue.TextColor3 = Color3.fromRGB(255, 95, 15) -- Orange text
totalDonatedValue.TextXAlignment = Enum.TextXAlignment.Center
totalDonatedValue.Parent = leftCol

-- VERTICAL DIVIDER LINE
local verticalDivider = Instance.new("Frame")
verticalDivider.Name = "VerticalDivider"
verticalDivider.Position = UDim2.new(0.38, 0, 0.04, 0)
verticalDivider.Size = UDim2.new(0, 2, 0.92, 0)
verticalDivider.BackgroundColor3 = Color3.fromRGB(245, 75, 15)
verticalDivider.BorderSizePixel = 0
verticalDivider.Parent = contentFrame

-- RIGHT COLUMN (Donation Link & Instructions)
local rightCol = Instance.new("Frame")
rightCol.Name = "RightCol"
rightCol.Position = UDim2.new(0.38, 24, 0, 0)
rightCol.Size = UDim2.new(0.62, -24, 1, 0)
rightCol.BackgroundTransparency = 1
rightCol.Parent = contentFrame

local rightLayout = Instance.new("UIListLayout")
rightLayout.FillDirection = Enum.FillDirection.Vertical
rightLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
rightLayout.VerticalAlignment = Enum.VerticalAlignment.Top
rightLayout.Padding = UDim.new(0, 8)
rightLayout.Parent = rightCol

-- 1. "DONATION LINK" Header
local linkHeader = Instance.new("TextLabel")
linkHeader.Name = "LinkHeader"
linkHeader.Size = UDim2.new(1, 0, 0, 16)
linkHeader.BackgroundTransparency = 1
linkHeader.Text = "DONATION LINK"
linkHeader.Font = Enum.Font.GothamBold
linkHeader.TextSize = 12
linkHeader.TextColor3 = Color3.fromRGB(150, 150, 160)
linkHeader.TextXAlignment = Enum.TextXAlignment.Left
linkHeader.Parent = rightCol

-- 2. Link Box
local linkBoxContainer = Instance.new("Frame")
linkBoxContainer.Name = "LinkBoxContainer"
linkBoxContainer.Size = UDim2.new(1, 0, 0, 42)
linkBoxContainer.BackgroundColor3 = Color3.fromRGB(36, 36, 46)
linkBoxContainer.BorderSizePixel = 0
linkBoxContainer.Parent = rightCol

local linkBoxCorner = Instance.new("UICorner")
linkBoxCorner.CornerRadius = UDim.new(0, 8)
linkBoxCorner.Parent = linkBoxContainer

local linkTextBox = Instance.new("TextBox")
linkTextBox.Name = "LinkTextBox"
linkTextBox.Position = UDim2.new(0, 14, 0, 0)
linkTextBox.Size = UDim2.new(1, -28, 1, 0)
linkTextBox.BackgroundTransparency = 1
linkTextBox.Text = CONFIG.DONATION_LINK
linkTextBox.TextColor3 = Color3.fromRGB(255, 125, 45)
linkTextBox.Font = Enum.Font.GothamBold
linkTextBox.TextSize = 14.5
linkTextBox.TextXAlignment = Enum.TextXAlignment.Left
linkTextBox.ClearTextOnFocus = false
linkTextBox.TextEditable = false
linkTextBox.Parent = linkBoxContainer

-- 3. "COPY LINK" Button
local copyLinkBtn = Instance.new("TextButton")
copyLinkBtn.Name = "CopyLinkBtn"
copyLinkBtn.Size = UDim2.new(1, 0, 0, 42)
copyLinkBtn.BackgroundColor3 = Color3.fromRGB(50, 48, 60)
copyLinkBtn.BorderSizePixel = 0
copyLinkBtn.Text = "COPY LINK"
copyLinkBtn.Font = Enum.Font.GothamBold
copyLinkBtn.TextSize = 15
copyLinkBtn.TextColor3 = Color3.fromRGB(240, 240, 240)
copyLinkBtn.AutoButtonColor = false
copyLinkBtn.Parent = rightCol

local copyBtnCorner = Instance.new("UICorner")
copyBtnCorner.CornerRadius = UDim.new(0, 8)
copyBtnCorner.Parent = copyLinkBtn

-- Spacer
local spacer1 = Instance.new("Frame")
spacer1.Name = "Spacer1"
spacer1.Size = UDim2.new(1, 0, 0, 4)
spacer1.BackgroundTransparency = 1
spacer1.Parent = rightCol

-- 4. "CARA DONATE" Header
local caraHeader = Instance.new("TextLabel")
caraHeader.Name = "CaraHeader"
caraHeader.Size = UDim2.new(1, 0, 0, 16)
caraHeader.BackgroundTransparency = 1
caraHeader.Text = "CARA DONATE"
caraHeader.Font = Enum.Font.GothamBold
caraHeader.TextSize = 12
caraHeader.TextColor3 = Color3.fromRGB(150, 150, 160)
caraHeader.TextXAlignment = Enum.TextXAlignment.Left
caraHeader.Parent = rightCol

-- 5. Steps Instructions
local instructionsLabel = Instance.new("TextLabel")
instructionsLabel.Name = "InstructionsLabel"
instructionsLabel.Size = UDim2.new(1, 0, 0, 82)
instructionsLabel.BackgroundTransparency = 1
instructionsLabel.RichText = true
instructionsLabel.Font = Enum.Font.Gotham
instructionsLabel.TextSize = 12.5
instructionsLabel.TextColor3 = Color3.fromRGB(205, 205, 215)
instructionsLabel.TextXAlignment = Enum.TextXAlignment.Left
instructionsLabel.TextYAlignment = Enum.TextYAlignment.Top
instructionsLabel.TextWrapped = true
instructionsLabel.Text = string.format(
	"1. Tekan <b>COPY LINK</b> lalu buka link donasinya.\n" ..
	"2. Masukkan nominal donasi (%s).\n" ..
	"3. Di kolom <b>Nama / Dari</b>, isi <b>username Roblox</b> kamu:\n" ..
	"   <font color=\"rgb(255, 100, 20)\"><b>%s</b></font>\n" ..
	"4. Selesaikan pembayaran — %s masuk otomatis.",
	CONFIG.CURRENCY_NAME,
	player.Name,
	CONFIG.CURRENCY_NAME
)
instructionsLabel.Parent = rightCol

-- 6. Warning Note
local warningLabel = Instance.new("TextLabel")
warningLabel.Name = "WarningLabel"
warningLabel.Size = UDim2.new(1, 0, 0, 32)
warningLabel.BackgroundTransparency = 1
warningLabel.RichText = true
warningLabel.Font = Enum.Font.Gotham
warningLabel.TextSize = 11.5
warningLabel.TextColor3 = Color3.fromRGB(175, 170, 180)
warningLabel.TextXAlignment = Enum.TextXAlignment.Left
warningLabel.TextYAlignment = Enum.TextYAlignment.Top
warningLabel.TextWrapped = true
warningLabel.Text = "<font color=\"rgb(255, 90, 20)\"><b>PENTING:</b></font> nama pengirim <b>wajib sama persis</b> dengan username Roblox. Kalau beda, donasi tidak terdeteksi."
warningLabel.Parent = rightCol

-- 7. Bottom Username Highlight
local usernameHighlight = Instance.new("TextLabel")
usernameHighlight.Name = "UsernameHighlight"
usernameHighlight.Size = UDim2.new(1, 0, 0, 28)
usernameHighlight.BackgroundTransparency = 1
usernameHighlight.RichText = true
usernameHighlight.Font = Enum.Font.GothamBold
usernameHighlight.TextSize = 17
usernameHighlight.TextColor3 = Color3.fromRGB(255, 255, 255)
usernameHighlight.TextXAlignment = Enum.TextXAlignment.Left
usernameHighlight.Text = string.format("Username : <font color=\"rgb(255, 100, 20)\"><b>%s</b></font>", player.Name)
usernameHighlight.Parent = rightCol

-- ==============================================================================
-- LOGIC & TWEEN ANIMATIONS
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

local function updateStats()
	avatarImage.Image = string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150", player.UserId)
	displayNameLabel.Text = player.DisplayName
	usernameLabel.Text = "@" .. player.Name
	usernameHighlight.Text = string.format("Username : <font color=\"rgb(255, 100, 20)\"><b>%s</b></font>", player.Name)

	local getStatsRemote = ReplicatedStorage:FindFirstChild("GetPlayerDonationStats")
	if getStatsRemote and getStatsRemote:IsA("RemoteFunction") then
		task.spawn(function()
			local ok, stats = pcall(function() return getStatsRemote:InvokeServer() end)
			if ok and type(stats) == "table" then
				local rupiah = tonumber(stats.rupiah) or 0
				if rupiah > 0 then
					totalDonatedValue.Text = string.format("%s %s", formatNumber(rupiah), CONFIG.CURRENCY_NAME)
				else
					totalDonatedValue.Text = "0 " .. CONFIG.CURRENCY_NAME
				end
			end
		end)
	end
end

local function openSaweria()
	if isOpen then return end
	isOpen = true

	-- Tutup Robux Donation Board jika sedang terbuka agar tidak tumpang tindih
	if _G.CloseRobuxDonation then
		pcall(_G.CloseRobuxDonation)
	end

	updateStats()

	backdrop.Visible = true
	backdrop.BackgroundTransparency = 1
	mainCard.Visible = true
	mainCard.Size = UDim2.new(0, 640, 0, 400)
	mainCard.BackgroundTransparency = 0.5

	TweenService:Create(backdrop, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 0.5
	}):Play()

	TweenService:Create(mainCard, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.new(0, 760, 0, 480),
		BackgroundTransparency = 0
	}):Play()

	if saweriaIcon and not saweriaIcon.isSelected then
		pcall(function() saweriaIcon:select() end)
	end
end

local function closeSaweria()
	if not isOpen then return end
	isOpen = false

	TweenService:Create(backdrop, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		BackgroundTransparency = 1
	}):Play()

	local tween = TweenService:Create(mainCard, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Size = UDim2.new(0, 640, 0, 400),
		BackgroundTransparency = 1
	})
	tween:Play()

	task.delay(0.2, function()
		if not isOpen then
			backdrop.Visible = false
			mainCard.Visible = false
		end
	end)

	if saweriaIcon and saweriaIcon.isSelected then
		pcall(function() saweriaIcon:deselect() end)
	end
end

_G.OpenSaweria = openSaweria
_G.CloseSaweria = closeSaweria

-- Close Events
closeBtn.MouseButton1Click:Connect(closeSaweria)
backdrop.MouseButton1Click:Connect(closeSaweria)

-- Close Button Hover Effect
closeBtn.MouseEnter:Connect(function()
	TweenService:Create(closeBtn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(245, 70, 70)}):Play()
end)
closeBtn.MouseLeave:Connect(function()
	TweenService:Create(closeBtn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(220, 55, 55)}):Play()
end)

-- Copy Link Button Effect
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
		pcall(function() setclipboard(CONFIG.DONATION_LINK) end)
	end

	copyLinkBtn.Text = "✓ LINK COPIED!"
	copyLinkBtn.TextColor3 = Color3.fromRGB(76, 217, 100)
	copyLinkBtn.BackgroundColor3 = Color3.fromRGB(35, 60, 45)

	task.delay(2, function()
		if copyLinkBtn and copyLinkBtn.Parent then
			copyLinkBtn.Text = "COPY LINK"
			copyLinkBtn.TextColor3 = Color3.fromRGB(240, 240, 240)
			copyLinkBtn.BackgroundColor3 = Color3.fromRGB(50, 48, 60)
		end
	end)
end)

-- ==============================================================================
-- TOPBAR PLUS INTEGRATION (Dedicated Saweria Icon)
-- ==============================================================================
pcall(function()
	if Icon.getIcon and Icon.getIcon("SaweriaDonationIcon") then
		return
	end

	saweriaIcon = Icon.new()
		:setName("SaweriaDonationIcon")
		:setLabel("Saweria")
		:setOrder(3) -- Berdampingan di sebelah Robux Donate (Order 2)

	saweriaIcon.selected:Connect(function()
		openSaweria()
	end)

	saweriaIcon.deselected:Connect(function()
		closeSaweria()
	end)
end)

print("[SaweriaDonationHandler] ✅ Separate Saweria Donation UI initialized successfully!")
