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
-- NOW PLAYING POPUP (WITH PROPER CLEANUP & DEBOUNCE)
-- ====================================
local lastPopupSongId = nil
local lastPopupTime = 0

function UINotificationManager:ShowNowPlayingPopup(musicData, uploaderName)
	-- Anti-Double Trigger (Debounce 3 detik untuk lagu yang sama)
	local currentSongId = musicData.id or musicData.judul
	if lastPopupSongId == currentSongId and (os.clock() - lastPopupTime) < 3 then
		return -- Abaikan jika lagu yang sama dipanggil beruntun (bug double popup)
	end
	
	lastPopupSongId = currentSongId
	lastPopupTime = os.clock()
	-- Update now playing popup dengan cover playlist tersinkronisasi
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

function UINotificationManager:ShowSkipVote(initiatorName, songTitle, totalVoters, requiredVotes, yesVotes, noVotes, isInitiator)
	self.sfSkipText.Text = string.format("%s ingin skip: %s", initiatorName, songTitle)
	local yVotes = yesVotes or 0
	local req = requiredVotes or math.max(1, math.ceil((totalVoters or 1) * 0.8))
	self.sfProgress.Text = string.format("Suara: %d/%d (Butuh %d - 80%%)", yVotes, totalVoters or 1, req)
	self.skipFrame.Visible = true

	if isInitiator then
		-- Inisiator sudah otomatis terhitung vote YES
		self.sfAcceptBtn.Active = false
		self.sfRejectBtn.Active = false
	else
		self.sfAcceptBtn.Active = true
		self.sfRejectBtn.Active = true
	end

	-- Auto hide after 30 seconds
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