local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Player = Players.LocalPlayer

local AccessoryRemotes = ReplicatedStorage:WaitForChild("AccessoryRemotes")
local AccessoryEvent = AccessoryRemotes:WaitForChild("ToggleAccessory")

local PlayerGui = Player:WaitForChild("PlayerGui")

local gui = PlayerGui:WaitForChild("MyHat") 
local mainframe = gui:WaitForChild("Mainframe")
local equipBtn = mainframe:WaitForChild("EquipBtn")
local unequipBtn = mainframe:WaitForChild("UnequipBtn")

local isProcessing = false
local COOLDOWN_TIME = 0.5

local function equipAccessory()
	if isProcessing then return end
	isProcessing = true

	AccessoryEvent:FireServer("equip")

	task.wait(COOLDOWN_TIME)
	isProcessing = false
end

local function unequipAccessory()
	if isProcessing then return end
	isProcessing = true

	AccessoryEvent:FireServer("unequip")

	task.wait(COOLDOWN_TIME)
	isProcessing = false
end

equipBtn.MouseButton1Click:Connect(function()
	equipAccessory()
end)

unequipBtn.MouseButton1Click:Connect(function()
	unequipAccessory()
end)

mainframe.Visible = false
