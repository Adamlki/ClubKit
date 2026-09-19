local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local UIControlManager = {}
UIControlManager.__index = UIControlManager

function UIControlManager.new(components)
	local self = setmetatable({}, UIControlManager)

	self.skipBtn = components.skipBtn
	self.reloadBtn = components.reloadBtn
	self.adminBtn = components.adminBtn
	self.volumeFrameBg = components.volumeFrameBg
	self.volumeBar = components.volumeBar
	self.volumeBtn = components.volumeBtn
	self.volumeLabel = components.volumelabel
	self.trackFrameBg = components.trackFrameBg
	self.trackBar = components.trackBar
	self.thumbKnob = components.thumbKnob
	self.currentTimeLabel = components.currentTimeLabel
	self.timeLabel = components.timeLabel

	self.onNextCallback = nil
	self.onReloadCallback = nil
	self.onVolumeChangeCallback = nil
	self.onAdminToggleBlockCallback = nil

	self.isDraggingVolume = false
	self.volumeValue = 1.0

	self.currentTime = 0
	self.totalTime = 0
	self.targetProgress = 0
	self.currentDuration = 0
	self.lastCurrentSec = -1

	self:SetupConnections()
	self:SetupVolumeSlider()

	return self
end

-- ====================================
-- SETUP CONNECTIONS
-- ====================================
function UIControlManager:SetupConnections()
	-- Skip button
	if self.skipBtn then
		self.skipBtn.MouseButton1Click:Connect(function()
			if self.onNextCallback then
				self.onNextCallback()
			end
		end)
	end

	-- Reload button
	if self.reloadBtn then
		self.reloadBtn.MouseButton1Click:Connect(function()
			if self.onReloadCallback then
				self.onReloadCallback()
			end
		end)
	end

	-- Admin button
	if self.adminBtn then
		self.adminBtn.MouseButton1Click:Connect(function()
			if self.onAdminToggleBlockCallback then
				self.onAdminToggleBlockCallback()
			end
		end)
	end
end

-- ====================================
-- VOLUME SLIDER SYSTEM
-- ====================================
function UIControlManager:SetupVolumeSlider()
	local dragging = false
	local volumeBg = self.volumeFrameBg
	local volumeBar = self.volumeBar
	local volumeBtn = self.volumeBtn
	local volumeLabel = self.volumeLabel

	if not volumeBg or not volumeBar then return end

	local function updateVolume(percent)
		percent = math.clamp(percent, 0, 1)

		if volumeBtn then
			volumeBtn.Position = UDim2.new(1, 0, 0.5, 0)
		end

		volumeBar.Size = UDim2.new(percent, 0, 1, 0)

		if volumeLabel then
			local volumePercent = math.floor(percent * 100)
			volumeLabel.Text = string.format("%d%%", volumePercent)
		end

		self.volumeValue = percent

		if self.onVolumeChangeCallback then
			self.onVolumeChangeCallback(percent)
		end
	end

	local function getPercentFromPosition(mouseX)
		local bgPosition = volumeBg.AbsolutePosition.X
		local bgSize = volumeBg.AbsoluteSize.X
		if bgSize <= 0 then return 1 end
		local relativeX = mouseX - bgPosition
		return math.clamp(relativeX / bgSize, 0, 1)
	end

	-- Dragging via volumeBtn
	if volumeBtn then
		volumeBtn.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging = true
				self.isDraggingVolume = true
			end
		end)

		volumeBtn.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging = false
				self.isDraggingVolume = false
			end
		end)
	end

	-- Click on background bar
	volumeBg.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			self.isDraggingVolume = true
			updateVolume(getPercentFromPosition(input.Position.X))
		end
	end)

	volumeBg.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
			self.isDraggingVolume = false
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			updateVolume(getPercentFromPosition(input.Position.X))
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
			self.isDraggingVolume = false
		end
	end)
end

function UIControlManager:SetVolume(volumePercent)
	local percent = math.clamp(volumePercent / 100, 0, 1)
	if self.volumeBar then
		self.volumeBar.Size = UDim2.new(percent, 0, 1, 0)
	end
	if self.volumeLabel then
		self.volumeLabel.Text = string.format("%d%%", math.floor(volumePercent))
	end
	self.volumeValue = percent
end

-- ====================================
-- TIME FORMATTER (MM:SS)
-- ====================================
local function formatTime(seconds)
	if not seconds or seconds < 0 or seconds ~= seconds then
		return "00:00"
	end
	local mins = math.floor(seconds / 60)
	local secs = math.floor(seconds % 60)
	return string.format("%02d:%02d", mins, secs)
end

-- ====================================
-- UPDATE PROGRESS
-- ====================================
function UIControlManager:UpdateProgress(progress, currentTime, totalTime)
	progress = math.clamp(progress or 0, 0, 1)
	self.targetProgress = progress
	self.currentTime = currentTime or 0
	self.totalTime = totalTime or 0

	if self.trackBar then
		self.trackBar.Size = UDim2.new(progress, 0, 1, 0)
	end

	local curSec = math.floor(self.currentTime)
	if curSec ~= self.lastCurrentSec then
		self.lastCurrentSec = curSec
		if self.currentTimeLabel then
			self.currentTimeLabel.Text = formatTime(self.currentTime)
		end
		if self.timeLabel then
			self.timeLabel.Text = formatTime(self.totalTime)
		end
	end
end

function UIControlManager:UpdateSongDuration(duration)
	self.currentDuration = duration or 0
	if self.timeLabel then
		self.timeLabel.Text = formatTime(self.currentDuration)
	end
end

-- ====================================
-- ADMIN CONTROLS
-- ====================================
function UIControlManager:UpdateAdminButtonState(isModerator)
	if self.adminBtn then
		self.adminBtn.Visible = isModerator
	end
end

function UIControlManager:UpdateAdminButtonText(text)
	if self.adminBtn then
		self.adminBtn.Text = text
		local stroke = self.adminBtn:FindFirstChildOfClass("UIStroke")
		if string.find(text, "Unblock") then
			self.adminBtn.BackgroundColor3 = Color3.fromRGB(55, 25, 35)
			self.adminBtn.TextColor3 = Color3.fromRGB(255, 120, 140)
			if stroke then stroke.Color = Color3.fromRGB(200, 60, 80) end
		else
			self.adminBtn.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
			self.adminBtn.TextColor3 = Color3.fromRGB(240, 240, 240)
			if stroke then stroke.Color = Color3.fromRGB(46, 46, 46) end
		end
	end
end

-- ====================================
-- CALLBACKS
-- ====================================
function UIControlManager:OnNext(callback)
	self.onNextCallback = callback
end

function UIControlManager:OnReload(callback)
	self.onReloadCallback = callback
end

function UIControlManager:OnVolumeChange(callback)
	self.onVolumeChangeCallback = callback
end

function UIControlManager:OnAdminToggleBlock(callback)
	self.onAdminToggleBlockCallback = callback
end

return UIControlManager