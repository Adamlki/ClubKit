local Config = require(script:WaitForChild("Config"))
local Logger = require(script:WaitForChild("Logger"))
local NotificationManager = require(script:WaitForChild("NotificationManager"))
local UIManager = require(script:WaitForChild("UIManager"))
local ShopHandler = require(script:WaitForChild("ShopHandler"))

local Player = game.Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- 🔥 INTEGRASI MODULE ANIMASI
local UIAnimator = require(ReplicatedStorage:WaitForChild("UIAnimator"))

local gui = script.Parent
local mainframe = gui:WaitForChild("MainFrame")
local content = mainframe:WaitForChild("Content")
local VIPFrame = content:WaitForChild("VIP Pass")
local VIPBuyBtn = VIPFrame:WaitForChild("BuyBtn")
local closeBtn = mainframe:WaitForChild("Header"):WaitForChild("CloseBtn")

local notificationframe = gui:WaitForChild("NotificationFrame")
local notificationtext = notificationframe:WaitForChild("NotificationText")

local GamepassFolder = ReplicatedStorage:WaitForChild("Gamepass")
local remotes = {
	shopRequest = GamepassFolder:WaitForChild("ShopRequest", Config.RemoteTimeout),
	playerDataUpdated = GamepassFolder:WaitForChild("PlayerDataUpdated", Config.RemoteTimeout),
	refreshRole = GamepassFolder:WaitForChild("RefreshRole", Config.RemoteTimeout)
}

Logger:Success("Connected to remotes")

NotificationManager:Init(notificationframe, notificationtext)
ShopHandler:Init(remotes, UIManager, NotificationManager)

local GamepassData = {
	VIP = { Frame = VIPFrame, Button = VIPBuyBtn, IDs = {}, Owned = false, Name = "VIP Pass", Price = 0 }
}

ShopHandler:SetGamepassData(GamepassData)

mainframe:GetPropertyChangedSignal("Visible"):Connect(function()
	if mainframe.Visible and not ShopHandler.shopDataLoaded then
		ShopHandler:LoadShopData()
	end
end)


closeBtn.MouseButton1Click:Connect(function()
	UIAnimator.Close(mainframe)
end)

VIPBuyBtn.MouseButton1Click:Connect(function() ShopHandler:PromptPurchase("VIP") end)

remotes.playerDataUpdated.OnClientEvent:Connect(function(updateData)
	local updateType = updateData.type
	Logger:Debug("Received update: " .. updateType)

	if updateType == "ownership_updated" then
		ShopHandler:HandleOwnershipUpdate(updateData.gamepassType, true)
	elseif updateType == "role_updated" then
		Logger:Info("Role updated: " .. updateData.role)
	elseif updateType == "purchase_complete" then
		ShopHandler:HandleOwnershipUpdate(updateData.gamepassType, true)
		NotificationManager:ShowVisual(updateData.message, true)
	else
		Logger:Warn("Unknown update type: " .. tostring(updateType))
	end
end)

mainframe.Visible = Config.StartVisible
notificationframe.Visible = false

Logger:Info("Initializing...")

task.spawn(function()
	if not Player.Character then Player.CharacterAdded:Wait() end
	task.wait(2)
	ShopHandler:LoadShopData()
	Logger:Success("Initialization complete - Simplified Version (Self-Purchase Only)")
end)
