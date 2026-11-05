local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local MusicModule = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("MusicModule"))

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
	self.nowPlayingAutoHideTask = nil
	self.onSkipVoteResponseCallback = nil

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

function UINotificationManager:CleanupTween()
	if self.nowPlayingTween then
		self.nowPlayingTween:Cancel()
		pcall(function()
			self.nowPlayingTween:Destroy()
		end)
		self.nowPlayingTween = nil
	end

	if self.nowPlayingAutoHideTask then
		task.cancel(self.nowPlayingAutoHideTask)
		self.nowPlayingAutoHideTask = nil
	end
end

function UINotificationManager:ShowNotification(message)
	self.notificationText.Text = message
	self.notificationFrame.Visible = true

	task.delay(5, function()
		self.notificationFrame.Visible = false
	end)
end

local lastPopupSongId = nil
local lastPopupTime = 0

function UINotificationManager:ShowNowPlayingPopup(musicData, uploaderName)
	local currentSongId = musicData.id or musicData.judul
	if lastPopupSongId == currentSongId and (os.clock() - lastPopupTime) < 3 then
		return
	end
	
	lastPopupSongId = currentSongId
	lastPopupTime = os.clock()
	local albumName = musicData.album
	if (not albumName or albumName == "") and musicData.id then
		local songObj = MusicModule:GetMusicById(musicData.id)
		if songObj and songObj.album then
			albumName = songObj.album
		end
	end

	local playlistCover = (albumName and MusicModule:GetAlbumCover(albumName))
		or (musicData.sampul and musicData.sampul ~= "" and musicData.sampul)
		or MusicModule:GetAlbumCover("All Songs")

	self.npSongTitle.Text = musicData.judul or "Unknown"
	self.npRequester.Text = uploaderName or "Unknown"
	self.npImage.Image = playlistCover

	self:CleanupTween()

	self.nowPlayingFrame.Position = self.hiddenPosition
	self.nowPlayingFrame.Visible = true

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
		if self.nowPlayingTween == tweenIn then
			pcall(function()
				tweenIn:Destroy()
			end)
			self.nowPlayingTween = nil
		end
	end)

	self.nowPlayingAutoHideTask = task.delay(5, function()
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

function UINotificationManager:SetupSkipVoteButtons()
	local lastVoteClick = 0
	self.sfAcceptBtn.MouseButton1Click:Connect(function()
		local now = os.clock()
		if now - lastVoteClick < 0.3 then return end
		lastVoteClick = now

		if self.onSkipVoteResponseCallback then
			self.onSkipVoteResponseCallback("yes")
			self.sfAcceptBtn.Active = false
			self.sfRejectBtn.Active = false
		end
	end)

	self.sfRejectBtn.MouseButton1Click:Connect(function()
		local now = os.clock()
		if now - lastVoteClick < 0.3 then return end
		lastVoteClick = now

		if self.onSkipVoteResponseCallback then
			self.onSkipVoteResponseCallback("no")
			self.sfAcceptBtn.Active = false
			self.sfRejectBtn.Active = false
		end
	end)
end

function UINotificationManager:ShowSkipVote(initiatorName, songTitle, totalVoters, requiredVotes, yesVotes, noVotes, isInitiator)
	self.sfSkipText.Text = string.format("%s ingin skip: %s", initiatorName, songTitle)
	local yVotes = yesVotes or 0
	local req = requiredVotes or math.max(1, math.ceil((totalVoters or 1) * 0.8))
	self.sfProgress.Text = string.format("Suara: %d/%d (Butuh %d - 80%%)", yVotes, totalVoters or 1, req)
	self.skipFrame.Visible = true

	if isInitiator then
		self.sfAcceptBtn.Active = false
		self.sfRejectBtn.Active = false
	else
		self.sfAcceptBtn.Active = true
		self.sfRejectBtn.Active = true
	end

	task.delay(30, function()
		self:HideSkipVote()
	end)
end

function UINotificationManager:UpdateSkipVote(yesVotes, noVotes, totalVoters, requiredVotes)
	local req = requiredVotes or math.max(1, math.ceil((totalVoters or 1) * 0.8))
	self.sfProgress.Text = string.format("Suara: %d/%d (Yes: %d, No: %d | Butuh %d)", 
		yesVotes + noVotes, totalVoters or 1, yesVotes, noVotes, req)
end

function UINotificationManager:HideSkipVote()
	self.skipFrame.Visible = false
end

function UINotificationManager:ShowSkipVoteResult(passed)
	local message = passed and "⏭️ Vote skip lolos (80% tercapai)! Melewati lagu..." or "❌ Vote skip gagal (tidak mencapai 80%)."
	self:ShowNotification(message)
end

function UINotificationManager:Cleanup()
	self:CleanupTween()
end

function UINotificationManager:OnSkipVoteResponse(callback)
	self.onSkipVoteResponseCallback = callback
end

return UINotificationManager
