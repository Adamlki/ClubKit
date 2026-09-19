local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")

local isMobile = UserInputService.TouchEnabled and not UserInputService.MouseEnabled

local function disableBackpack()
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	end)
end

disableBackpack()

local CONFIG = {
	ClickSoundId = "rbxassetid://4499400560",

	SlotSize = isMobile and 30 or 50,
	Padding = 4,
	SectionPadding = 6,
	CornerRadius = 14,
	MaxHotbarSlots = 9,

	AnimSpeed = 0.3,

	BorderSpeed = 30,
	BorderSequence = ColorSequence.new({
		ColorSequenceKeypoint.new(0.00, Color3.fromRGB(30, 20, 40)),
		ColorSequenceKeypoint.new(0.25, Color3.fromRGB(15, 15, 15)),
		ColorSequenceKeypoint.new(0.50, Color3.fromRGB(60, 60, 65)),
		ColorSequenceKeypoint.new(0.75, Color3.fromRGB(15, 15, 15)),
		ColorSequenceKeypoint.new(1.00, Color3.fromRGB(30, 20, 40))
	}),

	Colors = {
		Container = Color3.fromRGB(15, 15, 15),
		Background = Color3.fromRGB(5, 5, 5),
		Text = Color3.fromRGB(220, 220, 220),
		SubText = Color3.fromRGB(140, 140, 140),
		Border = Color3.fromRGB(25, 25, 25),
	},

	EyeOpenId = "rbxassetid://125603824847579", 
	EyeClosedId = "rbxassetid://70802654569830", 
}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Deteksi jumlah tool yang dimiliki pemain saat ini (di Backpack + Karakter)
local function getTotalTools()
	local count = 0
	local backpack = player:FindFirstChild("Backpack")
	if backpack then
		for _, item in ipairs(backpack:GetChildren()) do
			if item:IsA("Tool") then
				count += 1
			end
		end
	end
	local char = player.Character
	if char then
		for _, item in ipairs(char:GetChildren()) do
			if item:IsA("Tool") then
				count += 1
			end
		end
	end
	return count
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "Backpack"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Parent = playerGui

local function playSound()
	local sound = Instance.new("Sound")
	sound.SoundId = CONFIG.ClickSoundId
	sound.Volume = 0.4
	sound.Parent = screenGui
	sound:Play()
	Debris:AddItem(sound, 1)
end

local mainContainer = Instance.new("Frame")
mainContainer.Name = "MainContainer"
mainContainer.BackgroundTransparency = 1
mainContainer.AnchorPoint = Vector2.new(0.5, 1)
mainContainer.Position = UDim2.new(0.5, 0, 1, -10)
mainContainer.AutomaticSize = Enum.AutomaticSize.XY
mainContainer.Visible = false -- Sembunyikan jika belum ada tool
mainContainer.Parent = screenGui

local hotbarFrame = Instance.new("Frame")
hotbarFrame.Name = "HotbarSlots"
hotbarFrame.BackgroundColor3 = CONFIG.Colors.Background
hotbarFrame.BackgroundTransparency = 0.1
hotbarFrame.Size = UDim2.new(0, 0, 0, CONFIG.SlotSize + (CONFIG.Padding * 2))
hotbarFrame.AutomaticSize = Enum.AutomaticSize.X
hotbarFrame.Parent = mainContainer

local hbStroke = Instance.new("UIStroke")
hbStroke.Color = Color3.new(1, 1, 1)
hbStroke.Thickness = 1.5
hbStroke.Transparency = 0.4
hbStroke.Parent = hotbarFrame

local hbGrad = Instance.new("UIGradient")
hbGrad.Name = "BorderAnim"
hbGrad.Color = CONFIG.BorderSequence
hbGrad.Parent = hbStroke

local hbCorner = Instance.new("UICorner")
hbCorner.CornerRadius = UDim.new(0, CONFIG.CornerRadius)
hbCorner.Parent = hotbarFrame

local hbList = Instance.new("UIListLayout")
hbList.FillDirection = Enum.FillDirection.Horizontal
hbList.HorizontalAlignment = Enum.HorizontalAlignment.Center
hbList.VerticalAlignment = Enum.VerticalAlignment.Center
hbList.Padding = UDim.new(0, CONFIG.Padding)
hbList.Parent = hotbarFrame

local hbPadding = Instance.new("UIPadding")
local p = CONFIG.Padding
hbPadding.PaddingLeft, hbPadding.PaddingRight = UDim.new(0, p), UDim.new(0, p)
hbPadding.PaddingTop, hbPadding.PaddingBottom = UDim.new(0, p), UDim.new(0, p)
hbPadding.Parent = hotbarFrame

local isHotbarCollapsed = false

local eyeBtn = Instance.new("ImageButton")
eyeBtn.Name = "EyeBtn"
eyeBtn.Size = UDim2.new(0, CONFIG.SlotSize, 0, CONFIG.SlotSize)
eyeBtn.LayoutOrder = -1 
eyeBtn.BackgroundColor3 = CONFIG.Colors.Container
eyeBtn.BackgroundTransparency = 0.1
eyeBtn.AutoButtonColor = true
eyeBtn.Visible = true
eyeBtn.Parent = hotbarFrame

local eyeIcon = Instance.new("ImageLabel")
eyeIcon.Name = "Icon"
eyeIcon.Size = UDim2.new(0.4, 0, 0.4, 0) 
eyeIcon.Position = UDim2.new(0.5, 0, 0.5, 0)
eyeIcon.AnchorPoint = Vector2.new(0.5, 0.5)
eyeIcon.BackgroundTransparency = 1
eyeIcon.Image = CONFIG.EyeOpenId
eyeIcon.ScaleType = Enum.ScaleType.Fit
eyeIcon.Parent = eyeBtn

local eyeCorner = Instance.new("UICorner")
eyeCorner.CornerRadius = UDim.new(0, CONFIG.CornerRadius - 4)
eyeCorner.Parent = eyeBtn

local eyeStroke = Instance.new("UIStroke")
eyeStroke.Color = CONFIG.Colors.Border
eyeStroke.Thickness = 1
eyeStroke.Parent = eyeBtn

local function setHotbarCollapsed(collapsed)
	isHotbarCollapsed = collapsed
	eyeIcon.Image = collapsed and CONFIG.EyeClosedId or CONFIG.EyeOpenId

	local targetPadding = collapsed and UDim.new(0, 0) or UDim.new(0, CONFIG.Padding)
	TweenService:Create(hbList, TweenInfo.new(CONFIG.AnimSpeed, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Padding = targetPadding}):Play()

	for _, v in pairs(hotbarFrame:GetChildren()) do
		if v:IsA("GuiButton") and v.Name ~= "EyeBtn" then
			if not collapsed then
				v.Visible = true
			end

			local targetSize = collapsed and UDim2.new(0, 0, 0, CONFIG.SlotSize) or UDim2.new(0, CONFIG.SlotSize, 0, CONFIG.SlotSize)
			local targetBgTrans = 0.1

			if not collapsed then
				if v.BackgroundColor3 == Color3.fromRGB(25, 25, 25) then
					targetBgTrans = 0
				end
			else
				targetBgTrans = 1
			end

			local twParams = {
				Size = targetSize,
				BackgroundTransparency = targetBgTrans
			}

			if v:IsA("ImageButton") then twParams.ImageTransparency = collapsed and 1 or 0 end
			if v:IsA("TextButton") then twParams.TextTransparency = collapsed and 1 or 0 end

			local tw = TweenService:Create(v, TweenInfo.new(CONFIG.AnimSpeed, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), twParams)
			tw:Play()

			for _, child in pairs(v:GetChildren()) do
				if child:IsA("ImageLabel") then
					TweenService:Create(child, TweenInfo.new(CONFIG.AnimSpeed), {ImageTransparency = collapsed and 1 or 0}):Play()
				elseif child:IsA("TextLabel") then
					TweenService:Create(child, TweenInfo.new(CONFIG.AnimSpeed), {TextTransparency = collapsed and 1 or 0}):Play()
				elseif child:IsA("UIStroke") then
					TweenService:Create(child, TweenInfo.new(CONFIG.AnimSpeed), {Transparency = collapsed and 1 or 0}):Play()
				end
			end

			if collapsed then
				tw.Completed:Connect(function()
					if isHotbarCollapsed then
						v.Visible = false
					end
				end)
			end
		end
	end
end

eyeBtn.MouseButton1Click:Connect(function()
	playSound()
	setHotbarCollapsed(not isHotbarCollapsed)
end)

if not isMobile then
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then return end
		-- Tekan 'B' untuk menyembunyikan/menampilkan hotbar (sama seperti tombol mata)
		if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Enum.KeyCode.B then
			if getTotalTools() > 0 then
				playSound()
				setHotbarCollapsed(not isHotbarCollapsed)
			end
		end
	end)
end

local BoundSlots = {}

local function getNextFreeSlot()
	for i = 1, CONFIG.MaxHotbarSlots do
		if BoundSlots[i] == nil then return i end
	end
	return nil
end

local function isToolInHotbar(tool)
	for _, t in pairs(BoundSlots) do
		if t == tool then return true end
	end
	return false
end

local function cleanSlots()
	local backpack = player:FindFirstChild("Backpack")
	local char = player.Character
	for i, tool in pairs(BoundSlots) do
		if not tool or (tool.Parent ~= backpack and tool.Parent ~= char) then
			BoundSlots[i] = nil
		end
	end
end

local function autoBindTool(tool)
	if not tool or not tool:IsA("Tool") then return end
	if isToolInHotbar(tool) then return end
	local slot = getNextFreeSlot()
	if slot then BoundSlots[slot] = tool end
end

local function autoBindInitial()
	local backpack = player:FindFirstChild("Backpack")
	if backpack then
		for _, tool in ipairs(backpack:GetChildren()) do
			if tool:IsA("Tool") then
				autoBindTool(tool)
			end
		end
	end
	local char = player.Character
	if char then
		for _, tool in ipairs(char:GetChildren()) do
			if tool:IsA("Tool") then
				autoBindTool(tool)
			end
		end
	end
end

local function makeSlotButton(parent, slotIndex, tool, isEquipped, layoutOrder)
	local btn = Instance.new("ImageButton")
	btn.Name = "Slot" .. slotIndex
	btn.Size = UDim2.new(0, CONFIG.SlotSize, 0, CONFIG.SlotSize)
	btn.LayoutOrder = layoutOrder or slotIndex
	btn.ClipsDescendants = true
	btn.AutoButtonColor = true
	btn.BackgroundColor3 = CONFIG.Colors.Container
	btn.BackgroundTransparency = 0.1
	btn.Parent = parent

	local corn = Instance.new("UICorner")
	corn.CornerRadius = UDim.new(0, CONFIG.CornerRadius - 4)
	corn.Parent = btn

	local num = Instance.new("TextLabel")
	num.Text = slotIndex <= CONFIG.MaxHotbarSlots and tostring(slotIndex) or ""
	num.Size = UDim2.new(0, 8, 0, 8)
	num.Position = UDim2.new(0, 2, 0, 1)
	num.BackgroundTransparency = 1
	num.TextColor3 = CONFIG.Colors.SubText
	num.Font = Enum.Font.Gotham
	num.TextSize = 8
	num.Parent = btn

	if tool then
		if isEquipped then
			local stroke = Instance.new("UIStroke")
			stroke.Color = Color3.new(1, 1, 1)
			stroke.Thickness = 1.5
			stroke.Parent = btn
			local grad = Instance.new("UIGradient")
			grad.Name = "BorderAnim"
			grad.Color = CONFIG.BorderSequence
			grad.Rotation = 0
			grad.Parent = stroke
			btn.BackgroundTransparency = 0
			btn.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
		else
			local stroke = Instance.new("UIStroke")
			stroke.Color = CONFIG.Colors.Border
			stroke.Thickness = 1
			stroke.Parent = btn
			btn.BackgroundTransparency = 0.2
			btn.BackgroundColor3 = CONFIG.Colors.Container
		end

		if tool.TextureId ~= "" then
			local icon = Instance.new("ImageLabel")
			icon.Size = UDim2.new(0.65, 0, 0.65, 0)
			icon.Position = UDim2.new(0.5, 0, 0.5, 0)
			icon.AnchorPoint = Vector2.new(0.5, 0.5)
			icon.BackgroundTransparency = 1
			icon.Image = tool.TextureId
			icon.ScaleType = Enum.ScaleType.Fit
			icon.Parent = btn
		else
			local txt = Instance.new("TextLabel")
			txt.Size = UDim2.new(1, 0, 1, 0)
			txt.BackgroundTransparency = 1
			txt.Text = string.sub(tool.Name, 1, 3)
			txt.TextColor3 = CONFIG.Colors.Text
			txt.Font = Enum.Font.GothamBold
			txt.TextSize = 9
			txt.Parent = btn
		end

		local char = player.Character
		btn.MouseButton1Click:Connect(function()
			playSound()
			if not char then return end
			local humanoid = char:FindFirstChildOfClass("Humanoid")
			if not humanoid then return end
			if tool.Parent == char then
				humanoid:UnequipTools()
			else
				humanoid:EquipTool(tool)
			end
		end)
	else
		btn.BackgroundTransparency = 0.9
		btn.ImageTransparency = 1
	end

	return btn
end

local function updateVisuals()
	cleanSlots()

	local totalTools = getTotalTools()
	-- 🛡️ Jika player belum punya tools/barang, sembunyikan seluruh GUI
	if totalTools == 0 then
		mainContainer.Visible = false
		return
	end

	mainContainer.Visible = true

	for _, v in pairs(hotbarFrame:GetChildren()) do
		if v:IsA("GuiButton") and v.Name ~= "EyeBtn" then
			v:Destroy()
		end
	end

	local char = player.Character
	local equippedTool = char and char:FindFirstChildOfClass("Tool")

	local highestSlot = 0
	for i = 1, CONFIG.MaxHotbarSlots do
		if BoundSlots[i] ~= nil then highestSlot = i end
	end

	for i = 1, highestSlot do
		local tool = BoundSlots[i]
		local isEquipped = tool and (tool == equippedTool)
		local btn = makeSlotButton(hotbarFrame, i, tool, isEquipped, i)

		if isHotbarCollapsed then
			btn.Size = UDim2.new(0, 0, 0, CONFIG.SlotSize)
			btn.BackgroundTransparency = 1
			btn.Visible = false
			for _, child in pairs(btn:GetChildren()) do
				if child:IsA("ImageLabel") then child.ImageTransparency = 1 end
				if child:IsA("TextLabel") then child.TextTransparency = 1 end
				if child:IsA("UIStroke") then child.Transparency = 1 end
			end
		end
	end
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.UserInputType == Enum.UserInputType.Keyboard then
		local map = {
			[Enum.KeyCode.One]=1,[Enum.KeyCode.Two]=2,[Enum.KeyCode.Three]=3,
			[Enum.KeyCode.Four]=4,[Enum.KeyCode.Five]=5,[Enum.KeyCode.Six]=6,
			[Enum.KeyCode.Seven]=7,[Enum.KeyCode.Eight]=8,[Enum.KeyCode.Nine]=9
		}
		local slotNum = map[input.KeyCode]
		if slotNum and not isHotbarCollapsed and getTotalTools() > 0 then
			local tool = BoundSlots[slotNum]
			if tool then
				playSound()
				local char = player.Character
				if char and char:FindFirstChild("Humanoid") then
					if tool.Parent == char then char.Humanoid:UnequipTools() else char.Humanoid:EquipTool(tool) end
				end
			end
			task.wait()
			updateVisuals()
		end
	end
end)

local function hookEvents()
	local backpack = player:WaitForChild("Backpack")
	local char = player.Character or player.CharacterAdded:Wait()

	backpack.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			task.defer(function() cleanSlots() autoBindTool(child) updateVisuals() end)
		end
	end)
	backpack.ChildRemoved:Connect(function(child)
		if child:IsA("Tool") then
			task.defer(function() cleanSlots() updateVisuals() end)
		end
	end)
	char.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			task.defer(function() cleanSlots() autoBindTool(child) updateVisuals() end)
		end
	end)
	char.ChildRemoved:Connect(function(child)
		if child:IsA("Tool") then
			task.defer(function() cleanSlots() updateVisuals() end)
		end
	end)
end

if player.Character then
	autoBindInitial()
	hookEvents()
	updateVisuals()
end

player.CharacterAdded:Connect(function()
	BoundSlots = {}
	task.wait(0.5)
	autoBindInitial()
	hookEvents()
	updateVisuals()
end)

player.CharacterRemoving:Connect(function()
	mainContainer.Visible = false
end)

RunService.RenderStepped:Connect(function(dt)
	if mainContainer.Visible and not isHotbarCollapsed then
		hbGrad.Rotation = (hbGrad.Rotation + CONFIG.BorderSpeed * dt) % 360
		for _, v in pairs(hotbarFrame:GetChildren()) do
			if v:IsA("GuiButton") and v:FindFirstChild("UIStroke") and v.UIStroke:FindFirstChild("BorderAnim") then
				v.UIStroke.BorderAnim.Rotation = (v.UIStroke.BorderAnim.Rotation + CONFIG.BorderSpeed * dt) % 360
			end
		end
	end
end)

