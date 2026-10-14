local Config = require(script.Parent:WaitForChild("Config"))
local Logger = require(script.Parent:WaitForChild("Logger"))

local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UIAnimator = require(ReplicatedStorage:WaitForChild("UIAnimator"))

local NotificationManager = {}

function NotificationManager:Init(notificationFrame, notificationText)
	self.frame = notificationFrame
	self.text = notificationText
	self.frame.Visible = false
	self.currentNotificationTicket = 0 
	Logger:Debug("NotificationManager initialized")
end

function NotificationManager:ShowVisual(message, isSuccess)
	self.currentNotificationTicket = self.currentNotificationTicket + 1
	local myTicket = self.currentNotificationTicket

	self.text.Text = message

	if isSuccess then
		self.text.TextColor3 = Color3.fromRGB(85, 255, 127)
		self.frame.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
	else
		self.text.TextColor3 = Color3.fromRGB(255, 85, 85)
		self.frame.BackgroundColor3 = Color3.fromRGB(231, 76, 60)
	end

	self.frame.BackgroundTransparency = 0.2

	UIAnimator.Open(self.frame)

	task.delay(4, function()
		if self.currentNotificationTicket ~= myTicket then return end
		UIAnimator.Close(self.frame)
	end)
end

function NotificationManager:Send(notifConfig, customText)
	pcall(function()
		StarterGui:SetCore("SendNotification", {
			Title = notifConfig.Title,
			Text = customText or notifConfig.Text,
			Duration = notifConfig.Duration
		})
	end)
end

return NotificationManager
