-- GlowstickColorUI.lua
-- UI menu Glowstick: tetap ada saat respawn, support HP, ada tombol ≡ dan X

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- UI utama
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "GlowstickGui"
screenGui.IgnoreGuiInset = true
screenGui.ResetOnSpawn = false -- jangan hilang saat respawn
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Enabled = false
screenGui.Parent = playerGui

-- ===== BUTTON MENU (≡) =====
local menuBtn = Instance.new("TextButton")
menuBtn.Name = "MenuButton"
menuBtn.Size = UDim2.new(0,42,0,42)
menuBtn.Position = UDim2.new(1, -52, 0, 100)
menuBtn.BackgroundColor3 = Color3.fromRGB(30,30,30)
menuBtn.Text = "≡"
menuBtn.TextColor3 = Color3.fromRGB(255,255,255)
menuBtn.Font = Enum.Font.GothamBold
menuBtn.TextSize = 22
menuBtn.Visible = false
menuBtn.Parent = screenGui
Instance.new("UICorner", menuBtn).CornerRadius = UDim.new(0,8)

-- ===== MENU WRAPPER =====
local menu = Instance.new("Frame")
menu.Name = "GlowstickMenu"
menu.Size = UDim2.new(0, 240, 0, 140)
menu.Position = UDim2.new(1, -250, 0, 150)
menu.BackgroundColor3 = Color3.fromRGB(20,20,20)
menu.BackgroundTransparency = 1
menu.BorderSizePixel = 0
menu.Visible = false
menu.Parent = screenGui
Instance.new("UICorner", menu).CornerRadius = UDim.new(0,10)
Instance.new("UIStroke", menu).Transparency = 0.5

-- ===== TITLE BAR =====
local bar = Instance.new("Frame")
bar.Size = UDim2.new(1,0,0,4)
bar.BackgroundColor3 = Color3.fromRGB(200,0,0)
bar.BorderSizePixel = 0
bar.Parent = menu
Instance.new("UICorner", bar).CornerRadius = UDim.new(0,2)

-- ===== CLOSE BUTTON =====
local closeBtn = Instance.new("TextButton")
closeBtn.Name = "Close"
closeBtn.Size = UDim2.new(0,24,0,24)
closeBtn.Position = UDim2.new(1,-28,0,6)
closeBtn.BackgroundColor3 = Color3.fromRGB(40,40,40)
closeBtn.Text = "×"
closeBtn.TextColor3 = Color3.fromRGB(255,255,255)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 16
closeBtn.Parent = menu
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(1,0)

-- ===== CONTENT PANEL =====
local panel = Instance.new("Frame")
panel.Size = UDim2.new(1,-16,1,-30)
panel.Position = UDim2.new(0,8,0,30)
panel.BackgroundTransparency = 1
panel.Parent = menu

local grid = Instance.new("UIGridLayout", panel)
grid.CellSize = UDim2.new(0,34,0,34) -- lebih besar untuk HP
grid.CellPadding = UDim2.new(0,8,0,8)
grid.FillDirectionMaxCells = 5
grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
grid.VerticalAlignment   = Enum.VerticalAlignment.Top

-- ===== PALET WARNA =====
local palette = {
	Color3.fromRGB(255,0,0),    -- Merah
	Color3.fromRGB(255,140,0),  -- Oranye
	Color3.fromRGB(255,255,0),  -- Kuning
	Color3.fromRGB(0,255,0),    -- Hijau
	Color3.fromRGB(0,170,255),  -- Biru muda
	Color3.fromRGB(0,0,255),    -- Biru
	Color3.fromRGB(180,0,255),  -- Ungu
	Color3.fromRGB(255,0,110),  -- Pink
	Color3.fromRGB(0,0,0),      -- Hitam
	Color3.fromRGB(255,255,255) -- Putih
}

local currentRemote = nil

-- tombol warna bulat
for _, col in ipairs(palette) do
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0,34,0,34)
	btn.Text = ""
	btn.BackgroundColor3 = col
	btn.Parent = panel

	Instance.new("UICorner", btn).CornerRadius = UDim.new(1,0)
	local stroke = Instance.new("UIStroke", btn)
	stroke.Thickness = 1
	stroke.Color = Color3.fromRGB(255,255,255)
	stroke.Transparency = 0.3

	btn.MouseButton1Click:Connect(function()
		if currentRemote then
			currentRemote:FireServer("setColor", col)
		end
	end)
end

-- ===== Animasi Fade =====
local function showMenu()
	menu.Visible = true
	TweenService:Create(menu, TweenInfo.new(0.25), {BackgroundTransparency = 0.1}):Play()
end

local function hideMenu()
	TweenService:Create(menu, TweenInfo.new(0.25), {BackgroundTransparency = 1}):Play()
	task.delay(0.25, function() menu.Visible = false end)
end

menuBtn.MouseButton1Click:Connect(function()
	if menu.Visible then
		hideMenu()
	else
		showMenu()
	end
end)

closeBtn.MouseButton1Click:Connect(function()
	hideMenu()
end)

-- ===== TOOL BINDING =====
local function bindTool(tool)
	if tool:IsA("Tool") and string.find(string.lower(tool.Name), "glowstick") then
		local remote = tool:WaitForChild("GlowRemote", 2)
		if remote then
			tool.Equipped:Connect(function()
				currentRemote = remote
				screenGui.Enabled = true
				menuBtn.Visible = true
			end)
			tool.Unequipped:Connect(function()
				currentRemote = nil
				screenGui.Enabled = false
				menu.Visible = false
				menuBtn.Visible = false
			end)
		end
	end
end

local function scanTools()
	for _, t in ipairs(player.Backpack:GetChildren()) do
		bindTool(t)
	end
end

-- jalankan sekali saat pertama
scanTools()
player.Backpack.ChildAdded:Connect(bindTool)

-- jalankan ulang setiap respawn
player.CharacterAdded:Connect(function(char)
	char.ChildAdded:Connect(bindTool)
	scanTools()
end)
