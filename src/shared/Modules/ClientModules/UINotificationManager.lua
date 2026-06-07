local TweenService = game:GetService("TweenService")

local UINotificationManager = {}
UINotificationManager.__index = UINotificationManager

function UINotificationManager.new(components)
	local self = setmetatable({}, UINotificationManager)

	self.notificationFrame = components.notificationFrame
	self.notificationText = components.notificationText
	self.nowPlayingFrame = components.nowPlayingFrame
	self.npImage = components.npImage
	self.npSongTitle = components.npSongTitle
	self.npRequester = components.npRequester
	self.skipFrame = components.skipFrame
	self.sfAcceptBtn = components.sfAcceptBtn
	self.sfRejectBtn = components.sfRejectBtn
	self.sfProgress = components.sfProgress
	self.sfSkipText = components.sfSkipText

	self.nowPlayingTween = nil
	self.nowPlayingAutoHideTask = nil -- NEW: Track auto-hide task
	self.onSkipVoteResponseCallback = nil

	-- Store original position for animation
	self.originalPosition = self.nowPlayingFrame.Position
	self.hiddenPosition = UDim2.new(
		1.1,
		self.originalPosition.X.Offset,
		self.originalPosition.Y.Scale,
		self.originalPosition.Y.Offset
	)

	self:SetupSkipVoteButtons()

	return self
end

-- ====================================
-- CLEANUP TWEEN
-- ====================================
function UINotificationManager:CleanupTween()
	if self.nowPlayingTween then
		self.nowPlayingTween:Cancel()
		-- Properly destroy tween to prevent memory leak
		pcall(function()
			self.nowPlayingTween:Destroy()
		end)
		self.nowPlayingTween = nil
	end

	-- Cancel auto-hide task if exists
	if self.nowPlayingAutoHideTask then
		task.cancel(self.nowPlayingAutoHideTask)
		self.nowPlayingAutoHideTask = nil
	end
end

-- ====================================
-- NOTIFICATIONS
-- ====================================
function UINotificationManager:ShowNotification(message)
	self.notificationText.Text = message
	self.notificationFrame.Visible = true

	-- Auto hide after 5 seconds
	task.delay(5, function()
		self.notificationFrame.Visible = false
	end)
end

-- ====================================
-- NOW PLAYING POPUP (WITH PROPER CLEANUP)
-- ====================================
function UINotificationManager:ShowNowPlayingPopup(musicData, uploaderName)
	-- Update now playing popup
	self.npSongTitle.Text = musicData.judul or "Unknown"
	self.npRequester.Text = uploaderName or "Unknown"
	self.npImage.Image = musicData.sampul or ""

	-- Cleanup previous animation
	self:CleanupTween()

	-- Set to hidden position (off-screen right)
	self.nowPlayingFrame.Position = self.hiddenPosition
	self.nowPlayingFrame.Visible = true

	-- Slide in from right to left with Back easing
	local tweenInfo = TweenInfo.new(
		0.4,
		Enum.EasingStyle.Back,
		Enum.EasingDirection.Out
	)

	local tweenIn = TweenService:Create(
		self.nowPlayingFrame,
		tweenInfo,
		{Position = self.originalPosition}
	)

	tweenIn:Play()
	self.nowPlayingTween = tweenIn

	tweenIn.Completed:Connect(function()
		-- Only clear if this is still the current tween
		if self.nowPlayingTween == tweenIn then
			pcall(function()
				tweenIn:Destroy()
			end)
			self.nowPlayingTween = nil
		end
	end)

	-- Schedule auto-hide with cancellable task
	self.nowPlayingAutoHideTask = task.delay(5, function()
		-- Check if task wasn't cancelled
		if not self.nowPlayingAutoHideTask then
			return
		end

		local tweenOutInfo = TweenInfo.new(
			0.3,
			Enum.EasingStyle.Back,
			Enum.EasingDirection.In
		)

		local tweenOut = TweenService:Create(
			self.nowPlayingFrame,
			tweenOutInfo,
			{Position = self.hiddenPosition}
		)

		tweenOut:Play()
		self.nowPlayingTween = tweenOut

		tweenOut.Completed:Connect(function()
			self.nowPlayingFrame.Visible = false

			-- Cleanup tween
			if self.nowPlayingTween == tweenOut then
				pcall(function()
					tweenOut:Destroy()
				end)
				self.nowPlayingTween = nil
			end
		end)

		self.nowPlayingAutoHideTask = nil
	end)
end

-- ====================================
-- SKIP VOTE UI
-- ====================================
function UINotificationManager:SetupSkipVoteButtons()
	self.sfAcceptBtn.MouseButton1Click:Connect(function()
		if self.onSkipVoteResponseCallback then
			self.onSkipVoteResponseCallback("yes")
			self.sfAcceptBtn.Active = false
			self.sfRejectBtn.Active = false
		end
	end)

	self.sfRejectBtn.MouseButton1Click:Connect(function()
		if self.onSkipVoteResponseCallback then
			self.onSkipVoteResponseCallback("no")
			self.sfAcceptBtn.Active = false
			self.sfRejectBtn.Active = false
		end
	end)
end

function UINotificationManager:ShowSkipVote(initiatorName, songTitle, totalVoters)
	self.sfSkipText.Text = string.format("%s wants to skip: %s", initiatorName, songTitle)
	self.sfProgress.Text = string.format("0/%d votes", totalVoters)
	self.skipFrame.Visible = true
	self.sfAcceptBtn.Active = true
	self.sfRejectBtn.Active = true

	-- Auto hide after 30 seconds
	task.delay(30, function()
		self:HideSkipVote()
	end)
end

function UINotificationManager:UpdateSkipVote(yesVotes, noVotes, totalVoters)
	self.sfProgress.Text = string.format("%d/%d (Yes: %d, No: %d)", 
		yesVotes + noVotes, totalVoters, yesVotes, noVotes)
end

function UINotificationManager:HideSkipVote()
	self.skipFrame.Visible = false
end

function UINotificationManager:ShowSkipVoteResult(passed)
	local message = passed and "Skip vote passed! Skipping..." or "Skip vote failed."
	self:ShowNotification(message)
end

-- ====================================
-- CLEANUP
-- ====================================
function UINotificationManager:Cleanup()
	self:CleanupTween()
end

-- ====================================
-- CALLBACK SETTER
-- ====================================
function UINotificationManager:OnSkipVoteResponse(callback)
	self.onSkipVoteResponseCallback = callback
end

return UINotificationManager