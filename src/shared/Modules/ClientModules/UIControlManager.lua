local UIControlManager = {}
UIControlManager.__index = UIControlManager

function UIControlManager.new(components)
	local self = setmetatable({}, UIControlManager)

	self.skipBtn = components.skipBtn
	self.adminBtn = components.adminBtn
	self.volumeFrameBg = components.volumeFrameBg
	self.volumeBar = components.volumeBar
	self.volumeBtn = components.volumeBtn
	self.volumeLabel = components.volumelabel
	self.trackFrameBg = components.trackFrameBg
	self.trackBar = components.trackBar
	self.timeLabel = components.timeLabel

	self.onNextCallback = nil
	self.onVolumeChangeCallback = nil
	self.onAdminToggleBlockCallback = nil

	self.isDraggingVolume = false
	self.volumeValue = 0.5

	-- ✅ NEW: Duration tracking
	self.currentDuration = 0
	self.metadataDuration = nil
	self.wasDetected = false

	self:SetupConnections()
	self:SetupVolumeSlider()

	return self
end

-- ====================================
-- SETUP CONNECTIONS
-- ====================================
function UIControlManager:SetupConnections()
	-- Skip button
	self.skipBtn.MouseButton1Click:Connect(function()
		if self.onNextCallback then
			self.onNextCallback()
		end
	end)

	-- Admin button
	self.adminBtn.MouseButton1Click:Connect(function()
		if self.onAdminToggleBlockCallback then
			self.onAdminToggleBlockCallback()
		end
	end)
end

-- ====================================
-- VOLUME SNAPPING UTILITY
-- ====================================
local function snapVolume(percent, snapPoints)
	local snapThreshold = 0.05 -- 5% threshold for snapping

	for _, snapPoint in ipairs(snapPoints) do
		if math.abs(percent - snapPoint) < snapThreshold then
			return snapPoint
		end
	end

	return percent
end

-- ====================================
-- VOLUME SLIDER SYSTEM (WITH SNAPPING)
-- ====================================
function UIControlManager:SetupVolumeSlider()
	local dragging = false
	local volumeBg = self.volumeFrameBg
	local volumeBar = self.volumeBar
	local volumeBtn = self.volumeBtn
	local volumeLabel = self.volumeLabel

	-- Snap points: 0%, 25%, 50%, 75%, 100%
	local snapPoints = {0, 0.25, 0.5, 0.75, 1}

	-- Set initial position (50%)
	volumeBtn.Position = UDim2.new(0.5, 0, 0.5, 0)
	volumeBar.Size = UDim2.new(0.5, 0, 1, 0)

	if volumeLabel then
		volumeLabel.Text = "50%"
	end

	-- Helper function to update volume
	local function updateVolume(percent, applySnap)
		percent = math.clamp(percent, 0, 1)

		-- Apply snapping if requested
		if applySnap then
			percent = snapVolume(percent, snapPoints)
		end

		-- Update button position
		volumeBtn.Position = UDim2.new(percent, 0, 0.5, 0)

		-- Update bar width
		volumeBar.Size = UDim2.new(percent, 0, 1, 0)

		-- Update volume label
		if volumeLabel then
			local volumePercent = math.floor(percent * 100)
			volumeLabel.Text = string.format("%d%%", volumePercent)
		end

		-- Store volume value
		self.volumeValue = percent

		-- Callback
		if self.onVolumeChangeCallback then
			self.onVolumeChangeCallback(percent)
		end
	end

	-- Helper function to get percent from mouse position
	local function getPercentFromPosition(mouseX)
		local bgPosition = volumeBg.AbsolutePosition.X
		local bgSize = volumeBg.AbsoluteSize.X
		local relativeX = mouseX - bgPosition
		return math.clamp(relativeX / bgSize, 0, 1)
	end

	-- Button drag events
	volumeBtn.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or 
			input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			self.isDraggingVolume = true
		end
	end)

	volumeBtn.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or 
			input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
			self.isDraggingVolume = false

			-- Apply snapping when releasing
			updateVolume(self.volumeValue, true)
		end
	end)

	-- Mouse/touch movement
	game:GetService("UserInputService").InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or 
			input.UserInputType == Enum.UserInputType.Touch) then

			local percent = getPercentFromPosition(input.Position.X)
			updateVolume(percent, false) -- Don't snap while dragging
		end
	end)

	-- Click on bar to jump (with snap)
	volumeBg.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or 
			input.UserInputType == Enum.UserInputType.Touch then

			local percent = getPercentFromPosition(input.Position.X)
			updateVolume(percent, true) -- Apply snap on click
		end
	end)

	-- Bar drag
	volumeBar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or 
			input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			self.isDraggingVolume = true

			local percent = getPercentFromPosition(input.Position.X)
			updateVolume(percent, false)
		end
	end)

	volumeBar.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or 
			input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
			self.isDraggingVolume = false

			-- Apply snapping when releasing
			updateVolume(self.volumeValue, true)
		end
	end)
end

function UIControlManager:SetVolume(volumePercent)
	local percent = math.clamp(volumePercent / 100, 0, 1)
	self.volumeValue = percent

	self.volumeBtn.Position = UDim2.new(percent, 0, 0.5, 0)
	self.volumeBar.Size = UDim2.new(percent, 0, 1, 0)

	if self.volumeLabel then
		self.volumeLabel.Text = string.format("%d%%", math.floor(volumePercent))
	end
end

-- ====================================
-- PROGRESS UPDATE (ENHANCED WITH DURATION INFO)
-- ====================================
function UIControlManager:UpdateProgress(progress, currentTime, totalTime)
	-- Update track bar (read-only)
	self.trackBar.Size = UDim2.new(progress, 0, 1, 0)

	-- ✅ ENHANCED: Format time label with duration info
	local timeText = self:FormatTimeWithInfo(currentTime, totalTime)
	self.timeLabel.Text = timeText
end

function UIControlManager:UpdateSongDuration(duration, metadataDuration, wasDetected)
	-- ✅ NEW: Store duration info
	self.currentDuration = duration
	self.metadataDuration = metadataDuration
	self.wasDetected = wasDetected

	-- Display initial time
	local timeText = self:FormatTimeWithInfo(0, duration)
	self.timeLabel.Text = timeText
end

-- ====================================
-- FORMAT TIME WITH DETECTION INFO
-- ====================================
function UIControlManager:FormatTimeWithInfo(currentTime, totalTime)
	if not totalTime or totalTime ~= totalTime then
		return "0:00 / 0:00"
	end

	local currentStr = self:FormatTime(currentTime)
	local totalStr = self:FormatTime(totalTime)

	-- Base format
	local baseText = string.format("%s / %s", currentStr, totalStr)

	-- ✅ ENHANCED: Add duration info if available
	if self.metadataDuration and self.wasDetected then
		local metadataStr = self:FormatTime(self.metadataDuration)
		local difference = math.abs(totalTime - self.metadataDuration)

		-- Show warning if difference > 10 seconds
		if difference > 10 then
			-- Color indicator (you can customize this)
			-- Red = mismatch, Green = detected
			return string.format("%s / %s ✓ (DB: %s)", currentStr, totalStr, metadataStr)
		else
			-- Small difference, just show detected mark
			return string.format("%s / %s ✓", currentStr, totalStr)
		end
	elseif self.wasDetected then
		-- Was detected but no metadata to compare
		return string.format("%s / %s ✓", currentStr, totalStr)
	else
		-- Not detected (using metadata or fallback)
		return baseText
	end
end

function UIControlManager:FormatTime(seconds)
	if not seconds or seconds ~= seconds then
		return "0:00"
	end
	local mins = math.floor(seconds / 60)
	local secs = math.floor(seconds % 60)
	return string.format("%d:%02d", mins, secs)
end

-- ====================================
-- ADMIN BUTTON
-- ====================================
function UIControlManager:UpdateAdminButtonState(isModeratorPlus)
	self.adminBtn.Visible = isModeratorPlus

	if isModeratorPlus then
		self.adminBtn.Text = "Block"
	end
end

function UIControlManager:UpdateAdminButtonText(newText)
	self.adminBtn.Text = newText
end

-- ====================================
-- CALLBACK SETTERS
-- ====================================
function UIControlManager:OnNext(callback)
	self.onNextCallback = callback
end

function UIControlManager:OnVolumeChange(callback)
	self.onVolumeChangeCallback = callback
end

function UIControlManager:OnAdminToggleBlock(callback)
	self.onAdminToggleBlockCallback = callback
end

return UIControlManager