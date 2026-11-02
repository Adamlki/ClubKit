--!optimize 2
--!native

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local MusicModule = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("MusicModule"))

local UIAlbumManager = require(script.Parent.UIAlbumManager)
local UIPlaylistManager = require(script.Parent.UIPlaylistManager)
local UIControlManager = require(script.Parent.UIControlManager)
local UINotificationManager = require(script.Parent.UINotificationManager)

local UIManager = {}
UIManager.__index = UIManager

local DEFAULT_COVER = "rbxassetid://100874885625675"
local HIERARCHY = { Owner = 5, Admin = 4, Moderator = 3, VIP = 2, Player = 1 }

local function bindDebouncedClick(btn, delay, callback)
	if not btn then return end
	local lastClick = 0
	btn.MouseButton1Click:Connect(function()
		local now = os.clock()
		if now - lastClick < delay then return end
		lastClick = now
		callback()
	end)
end

-- ====================================
-- OBJECT POOL FOR QUEUE ITEMS
-- ====================================
local QueueItemPool = {}
QueueItemPool.__index = QueueItemPool

function QueueItemPool.new(template)
	local self = setmetatable({}, QueueItemPool)
	self.template = template
	self.activeItems = {}
	self.inactiveItems = {}
	self.connections = {}
	return self
end

function QueueItemPool:Get()
	local item = table.remove(self.inactiveItems) or self.template:Clone()
	item.Visible = true
	table.insert(self.activeItems, item)
	return item
end

function QueueItemPool:Return(item)
	local idx = table.find(self.activeItems, item)
	if idx then table.remove(self.activeItems, idx) end
	item.Visible = false
	if self.connections[item] then
		self.connections[item]:Disconnect()
		self.connections[item] = nil
	end
	table.insert(self.inactiveItems, item)
end

function QueueItemPool:ReturnAll()
	for _, item in ipairs(self.activeItems) do
		item.Visible = false
		if self.connections[item] then
			self.connections[item]:Disconnect()
			self.connections[item] = nil
		end
		table.insert(self.inactiveItems, item)
	end
	table.clear(self.activeItems)
end

function QueueItemPool:Clear()
	for _, item in ipairs(self.activeItems) do
		if self.connections[item] then self.connections[item]:Disconnect() end
		item:Destroy()
	end
	for _, item in ipairs(self.inactiveItems) do
		if self.connections[item] then self.connections[item]:Disconnect() end
		item:Destroy()
	end
	self.connections = {}
	self.activeItems = {}
	self.inactiveItems = {}
end

-- ====================================
-- UI MANAGER INITIALIZATION
-- ====================================
function UIManager.new(gui)
	local self = setmetatable({}, UIManager)

	self.gui = gui
	local MF = gui:WaitForChild("MainFrame")
	local NF = gui:WaitForChild("NotificationFrame")
	local NP = gui:WaitForChild("Nowplayingframe")
	local SF = gui:WaitForChild("SkipFrame")

	self.mainFrame = MF
	self.header = MF:WaitForChild("Header")
	self.closeBtn = self.header:WaitForChild("CloseBtn")

	local tabSwitcher = self.header:WaitForChild("TabSwitcher")
	self.homeTabBtn = tabSwitcher:WaitForChild("HomeTabBtn")
	self.libraryTabBtn = tabSwitcher:WaitForChild("LibraryTabBtn")

	self.homeView = MF:WaitForChild("HomeView")
	self.libraryView = MF:WaitForChild("LibraryView")

	local leftCol = self.homeView:WaitForChild("LeftColumn")
	local nowPlayingTop = leftCol:WaitForChild("NowPlayingTop")
	local metaInfo = nowPlayingTop:WaitForChild("MetaInfo")

	self.songPicture = nowPlayingTop:WaitForChild("Songpicture")
	self.songTitle = metaInfo:WaitForChild("SongTitle")
	self.songSubtitle = metaInfo:FindFirstChild("SongSubtitle")
	if self.songSubtitle then
		self.songSubtitle.Visible = false
		self.songSubtitle.Text = ""
	end
	self.likeBtn = metaInfo:WaitForChild("LikeBtn")

	self.visualizerFrame = leftCol:WaitForChild("VisualizerFrame")
	self.visualizerBars = {}
	for _, child in ipairs(self.visualizerFrame:GetChildren()) do
		if child:IsA("Frame") and child.Name:match("^Bar_") then
			table.insert(self.visualizerBars, child)
		end
	end
	table.sort(self.visualizerBars, function(a, b) return a.Name < b.Name end)

	local metaCards = leftCol:WaitForChild("MetadataCards")
	self.playlistLabel = metaCards:WaitForChild("PlaylistCard"):WaitForChild("ValueLabel")
	self.requesterName = metaCards:WaitForChild("QueuedByCard"):WaitForChild("Requestername")

	local progressSec = leftCol:WaitForChild("ProgressSection")
	local trackBg = progressSec:WaitForChild("trackframebg")
	local trackFill = trackBg:WaitForChild("track")
	self.currentTimeLabel = progressSec:WaitForChild("CurrentTimeLabel")
	self.timeLabel = progressSec:WaitForChild("timelabel")

	local volumeSec = leftCol:WaitForChild("VolumeSection")
	local volumeBg = volumeSec:WaitForChild("Volumeframebg")
	local volumeFill = volumeBg:WaitForChild("Volume")
	self.volumeLabel = volumeSec:WaitForChild("Volumelabel")

	local actionBtns = leftCol:WaitForChild("ActionButtons")
	self.reloadBtn = actionBtns:WaitForChild("ReloadBtn")
	self.skipBtn = actionBtns:WaitForChild("SkipBtn")
	self.adminBtn = self.header:FindFirstChild("AdminBtn") or MF:FindFirstChild("AdminBtn", true)

	local rightCol = self.homeView:WaitForChild("RightColumn")
	self.queueBadge = rightCol:WaitForChild("QueueHeader"):WaitForChild("BadgeFrame"):WaitForChild("BadgeCount")
	self.queueList = rightCol:WaitForChild("Queuelist")
	self.queueTemplate = self.queueList:WaitForChild("QueueTemplate")
	self.queueTemplate.Visible = false
	self.emptyQueueLabel = self.queueList:FindFirstChild("EmptyQueueLabel")

	self.queuePool = QueueItemPool.new(self.queueTemplate)

	self.playlistDetailFrame = self.libraryView:WaitForChild("PlaylistDetailFrame")
	self.albumsSelectionFrame = self.libraryView:WaitForChild("AlbumsSelectionFrame")

	local banner = self.playlistDetailFrame:WaitForChild("Banner")
	self.libBackBtn = banner:WaitForChild("BackBtn")
	self.libCover = banner:WaitForChild("PlaylistCover")
	self.libTitle = banner:WaitForChild("PlaylistMeta"):WaitForChild("PlaylistTitle")
	self.libCount = banner:WaitForChild("PlaylistMeta"):WaitForChild("SongCountLabel")
	self.searchBox = banner:WaitForChild("SearchBoxContainer"):WaitForChild("SearchBox")

	self.playlistScroll = self.playlistDetailFrame:WaitForChild("Playlist")
	self.playlistTemplate = self.playlistScroll:WaitForChild("TemplateFrame")
	self.playlistTemplate.Visible = false

	self.albumScroll = self.albumsSelectionFrame:WaitForChild("Albumlist")
	self.albumTemplate = self.albumScroll:WaitForChild("TemplateBtn")
	self.albumTemplate.Visible = false

	self.albumManager = UIAlbumManager.new(self.albumScroll, self.albumTemplate)
	self.playlistManager = UIPlaylistManager.new(self.playlistScroll, self.playlistTemplate)

	self.controlManager = UIControlManager.new({
		skipBtn = self.skipBtn,
		reloadBtn = self.reloadBtn,
		adminBtn = self.adminBtn,
		volumeFrameBg = volumeBg,
		volumeBar = volumeFill,
		volumeBtn = volumeFill:WaitForChild("volumeBtn"),
		volumelabel = self.volumeLabel,
		trackFrameBg = trackBg,
		trackBar = trackFill,
		thumbKnob = trackFill:FindFirstChild("ThumbKnob"),
		currentTimeLabel = self.currentTimeLabel,
		timeLabel = self.timeLabel,
	})

	self.notificationManager = UINotificationManager.new({
		notificationFrame = NF,
		notificationText = NF:WaitForChild("NotificationText"),
		nowPlayingFrame = NP,
		npImage = NP:WaitForChild("ImageLabel"),
		npSongTitle = NP:WaitForChild("SongTitle"),
		npRequester = NP:WaitForChild("requester"),
		skipFrame = SF,
		sfAcceptBtn = SF:WaitForChild("AcceptBtn"),
		sfRejectBtn = SF:WaitForChild("RejectBtn"),
		sfProgress = SF:WaitForChild("Progress"),
		sfSkipText = SF:WaitForChild("Skipnotif"),
	})

	self.adminFrame = MF:WaitForChild("AdminFrame")
	self.adminInfoText = self.adminFrame:WaitForChild("AdminNotif")

	self.playerRole = "Player"
	self.currentSongId = nil
	self.isPlaying = false
	self.favoriteSongs = {}
	self.activeTab = "Home"

	self.callbacks = {
		onMusicSubmit = nil,
		onNext = nil,
		onReload = nil,
		onVolumeChange = nil,
		onSkipVoteResponse = nil,
		onAdminToggleBlock = nil,
		onToggleFavorite = nil,
	}

	self:SetupConnections()
	self:SetupTabSwitcher()
	self:SetupCloseButton()
	self:SetupResponsiveScale()
	self:SetupVisualizer()
	self:SetupRoleWatcher()
	self:ResetUI()

	self:LoadAlbums({})

	self.mainFrame.Visible = false
	NF.Visible = false
	NP.Visible = false
	SF.Visible = false
	self.adminFrame.Visible = false

	self.hasActiveAlbumOpen = false
	self.albumsSelectionFrame.Visible = true
	self.playlistDetailFrame.Visible = false

	return self
end

function UIManager:SetupResponsiveScale()
	local uiScale = self.gui:FindFirstChild("UIScale")
	if not uiScale then return end

	local baseX, baseY = 1366, 768
	local function updateScale()
		local cam = workspace.CurrentCamera
		if not cam then return end
		local screenSize = cam.ViewportSize
		if screenSize.X == 0 or screenSize.Y == 0 then return end

		local baseScale = math.min(screenSize.X / baseX, screenSize.Y / baseY)
		local finalScale = baseScale

		if baseScale < 0.5 then
			finalScale = baseScale * 1.2
		elseif baseScale > 1.2 then
			finalScale = baseScale * 0.85
		end

		uiScale.Scale = math.clamp(finalScale, 0.5, 1.0)
	end

	updateScale()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
	end
end

function UIManager:SetupCloseButton()
	bindDebouncedClick(self.closeBtn, 0.3, function()
		self:HideMainFrame()
	end)
end

function UIManager:SetupTabSwitcher()
	local function styleTab(btn, selected)
		local stroke = btn:FindFirstChild("TabStroke")
		btn.BackgroundColor3 = Color3.fromRGB(24, 90, 50)
		btn.BackgroundTransparency = selected and 0 or 1
		btn.TextColor3 = selected and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(160, 160, 160)
		btn.Font = selected and Enum.Font.GothamBold or Enum.Font.GothamMedium
		if stroke then
			stroke.Transparency = selected and 0 or 1
			stroke.Color = Color3.fromRGB(46, 210, 115)
		end
	end

	local function setTab(tabName)
		self.activeTab = tabName
		local isHome = (tabName == "Home")
		self.homeView.Visible = isHome
		self.libraryView.Visible = not isHome

		styleTab(self.homeTabBtn, isHome)
		styleTab(self.libraryTabBtn, not isHome)

		if not isHome and not self.hasActiveAlbumOpen then
			self.playlistDetailFrame.Visible = false
			self.albumsSelectionFrame.Visible = true
		end
	end

	bindDebouncedClick(self.homeTabBtn, 0.3, function() setTab("Home") end)
	bindDebouncedClick(self.libraryTabBtn, 0.3, function() setTab("Library") end)

	bindDebouncedClick(self.libBackBtn, 0.3, function()
		self.hasActiveAlbumOpen = false
		self.playlistDetailFrame.Visible = false
		self.albumsSelectionFrame.Visible = true
	end)
end

function UIManager:SetupVisualizer()
	if #self.visualizerBars == 0 then return end
	local visualizerConnection

	local function updateVisualizer()
		local t = os.clock()
		for i, bar in ipairs(self.visualizerBars) do
			local targetH = 6
			if self.isPlaying then
				local wave1 = math.sin(t * 9 + i * 0.45) * 14
				local wave2 = math.cos(t * 14 - i * 0.7) * 10
				local wave3 = math.sin(t * 5 + i * 1.2) * 8
				local wave4 = math.sin(t * 18 + i * 0.2) * 6
				targetH = math.clamp(18 + wave1 + wave2 + wave3 + wave4, 6, 48)
			end
			local currentH = bar.Size.Y.Offset
			bar.Size = UDim2.new(0, 4, 0, math.floor(currentH + (targetH - currentH) * 0.25))
		end
	end

	self.mainFrame:GetPropertyChangedSignal("Visible"):Connect(function()
		if self.mainFrame.Visible then
			if not visualizerConnection then
				visualizerConnection = RunService.Heartbeat:Connect(updateVisualizer)
			end
		elseif visualizerConnection then
			visualizerConnection:Disconnect()
			visualizerConnection = nil
		end
	end)

	if self.mainFrame.Visible then
		visualizerConnection = RunService.Heartbeat:Connect(updateVisualizer)
	end
end

function UIManager:SetupConnections()
	bindDebouncedClick(self.likeBtn, 0.3, function()
		if self.currentSongId and self.callbacks.onToggleFavorite then
			self.callbacks.onToggleFavorite(self.currentSongId)
		end
	end)

	self.searchBox.Changed:Connect(function(property)
		if property == "Text" then
			local currentAlbum = self.albumManager:GetCurrentAlbum()
			self.playlistManager:SearchInAlbum(currentAlbum, self.searchBox.Text)
		end
	end)

	self.albumManager:OnAlbumSelected(function(albumName, songCount, cover)
		self.hasActiveAlbumOpen = true
		self.libTitle.Text = albumName
		self.libCount.Text = string.format("%d songs", songCount)
		self.libCover.Image = cover or MusicModule:GetAlbumCover(albumName)
		self.searchBox.Text = ""

		local songs = MusicModule:GetAlbumSongs(albumName, self.albumManager:GetFavoriteSongs())
		self.playlistManager:UpdatePlaylist(songs, albumName)

		self.albumsSelectionFrame.Visible = false
		self.playlistDetailFrame.Visible = true
	end)

	self.playlistManager:OnPlay(function(musicId)
		if self.callbacks.onMusicSubmit then self.callbacks.onMusicSubmit(musicId) end
	end)

	self.playlistManager:OnToggleFavorite(function(musicId)
		if self.callbacks.onToggleFavorite then self.callbacks.onToggleFavorite(musicId) end
	end)

	self.controlManager:OnNext(function()
		if self.callbacks.onNext then self.callbacks.onNext() end
	end)

	self.controlManager:OnReload(function()
		if self.callbacks.onReload then self.callbacks.onReload() end
	end)

	self.controlManager:OnVolumeChange(function(percent)
		if self.callbacks.onVolumeChange then self.callbacks.onVolumeChange(percent) end
	end)

	self.controlManager:OnAdminToggleBlock(function()
		if self.callbacks.onAdminToggleBlock then self.callbacks.onAdminToggleBlock() end
	end)

	self.notificationManager:OnSkipVoteResponse(function(voteType)
		if self.callbacks.onSkipVoteResponse then self.callbacks.onSkipVoteResponse(voteType) end
	end)
end

function UIManager:UpdateQueue(queueData)
	queueData = queueData or {}
	self.queuePool:ReturnAll()

	local count = #queueData
	self.queueBadge.Text = tostring(count)

	if self.emptyQueueLabel then
		self.emptyQueueLabel.Visible = (count == 0)
	end
	if count == 0 then return end

	for index, songData in ipairs(queueData) do
		local item = self.queuePool:Get()
		item.Visible = true
		if item.Parent ~= self.queueList then
			item.Parent = self.queueList
		end

		item.LayoutOrder = index
		item.Name = string.format("QueueItem_%03d", index)

		local posLabel = item:FindFirstChild("PositionLabel")
		local thumb = item:FindFirstChild("SongThumbnail")
		local info = item:FindFirstChild("InfoContainer")
		local favBtn = item:FindFirstChild("FavouriteBtn")

		local musicData = songData.musicData or songData
		if posLabel then posLabel.Text = tostring(index) end

		local albCover = musicData.album and MusicModule:GetAlbumCover(musicData.album)
		if thumb then thumb.Image = albCover or musicData.sampul or DEFAULT_COVER end

		if info then
			local titleLabel = info:FindFirstChild("SongTitleLabel")
			local playlistLabel = info:FindFirstChild("PlaylistSubtitle")
			local requesterLabel = info:FindFirstChild("RequesterLabel")

			if titleLabel then titleLabel.Text = musicData.judul or "Unknown" end
			if playlistLabel then playlistLabel.Text = "Playlist " .. (musicData.album or "Unknown") end
			if requesterLabel then requesterLabel.Text = "Queued by " .. (songData.uploader or "Unknown") end
		end

		if favBtn then
			local isFav = self:IsFavorite(musicData.id)
			favBtn.Text = isFav and "❤️" or "♡"
			favBtn.TextColor3 = isFav and Color3.fromRGB(255, 90, 120) or Color3.fromRGB(140, 140, 140)

			if self.queuePool.connections[item] then
				self.queuePool.connections[item]:Disconnect()
				self.queuePool.connections[item] = nil
			end

			local lastFavClick = 0
			self.queuePool.connections[item] = favBtn.MouseButton1Click:Connect(function()
				local now = os.clock()
				if now - lastFavClick < 0.3 then return end
				lastFavClick = now
				if musicData.id and self.callbacks.onToggleFavorite then
					self.callbacks.onToggleFavorite(musicData.id)
				end
			end)
		end
	end
end

function UIManager:UpdateNowPlaying(musicData, uploaderName, showPopup)
	musicData = musicData or {}
	self.currentSongId = musicData.id
	self.isPlaying = true

	local albumName = musicData.album
	if (not albumName or albumName == "") and musicData.id then
		local songObj = MusicModule:GetMusicById(musicData.id)
		if songObj and songObj.album then albumName = songObj.album end
	end

	self.songTitle.Text = musicData.judul or "No music playing"
	local albumCover = albumName and MusicModule:GetAlbumCover(albumName)
	local finalCover = albumCover or musicData.sampul or DEFAULT_COVER
	self.songPicture.Image = finalCover

	local requesterDisplay = (uploaderName and uploaderName ~= "" and uploaderName ~= "System" and uploaderName ~= "Unknown" and uploaderName ~= "None") and uploaderName or "Server"
	local playlistDisplay = (albumName and albumName ~= "") and albumName or "All Songs"

	self.playlistLabel.Text = playlistDisplay
	self.requesterName.Text = requesterDisplay

	if self.songSubtitle then
		self.songSubtitle.Visible = false
		self.songSubtitle.Text = ""
	end

	self:UpdateLikeButtonState()

	if self.notificationManager then
		if self.notificationManager.npImage then self.notificationManager.npImage.Image = finalCover end
		if self.notificationManager.npSongTitle then self.notificationManager.npSongTitle.Text = musicData.judul or "Unknown" end
		if self.notificationManager.npRequester then self.notificationManager.npRequester.Text = requesterDisplay end
	end

	if showPopup ~= false then
		musicData.sampul = finalCover
		musicData.album = albumName
		self.notificationManager:ShowNowPlayingPopup(musicData, requesterDisplay)
	end
end

function UIManager:UpdateProgress(progress, currentTime, totalTime)
	self.controlManager:UpdateProgress(progress, currentTime, totalTime)
end

function UIManager:UpdateSongDuration(duration)
	self.controlManager:UpdateSongDuration(duration)
end

function UIManager:IsFavorite(musicId)
	return not not (musicId and table.find(self.favoriteSongs, musicId))
end

function UIManager:UpdateLikeButtonState()
	local isFav = self:IsFavorite(self.currentSongId)
	local likeStroke = self.likeBtn:FindFirstChild("LikeStroke")

	self.likeBtn.Text = isFav and "❤️ Liked" or "♡ Like"
	self.likeBtn.BackgroundColor3 = isFav and Color3.fromRGB(44, 24, 34) or Color3.fromRGB(24, 24, 24)
	self.likeBtn.TextColor3 = isFav and Color3.fromRGB(255, 110, 140) or Color3.fromRGB(220, 220, 220)
	if likeStroke then
		likeStroke.Color = isFav and Color3.fromRGB(140, 40, 65) or Color3.fromRGB(44, 44, 44)
	end
end

function UIManager:UpdateFavorites(favoriteSongs)
	self.favoriteSongs = favoriteSongs or {}
	self:UpdateLikeButtonState()
	self.albumManager:UpdateFavorites(favoriteSongs)
	self.playlistManager:UpdateFavorites(favoriteSongs)
end

function UIManager:LoadAlbums(favoriteSongs)
	self.albumManager:LoadAlbums(favoriteSongs)
end

function UIManager:SetupRoleWatcher()
	local player = Players.LocalPlayer
	local function updateRole(val)
		self.playerRole = val or "Player"
		self:UpdateAdminButtonState()
	end

	local roleValue = player:FindFirstChild("Role")
	if roleValue and roleValue:IsA("StringValue") then
		updateRole(roleValue.Value)
		roleValue.Changed:Connect(updateRole)
	else
		updateRole("Player")
		local conn
		conn = player.ChildAdded:Connect(function(child)
			if child.Name == "Role" and child:IsA("StringValue") then
				if conn then conn:Disconnect() conn = nil end
				updateRole(child.Value)
				child.Changed:Connect(updateRole)
			end
		end)
		task.spawn(function()
			local found = player:WaitForChild("Role", 10)
			if found and found:IsA("StringValue") and conn then
				conn:Disconnect()
				conn = nil
				updateRole(found.Value)
				found.Changed:Connect(updateRole)
			end
		end)
	end
end

function UIManager:IsModeratorPlus()
	return (HIERARCHY[self.playerRole] or 1) >= 3
end

function UIManager:UpdateAdminButtonState()
	local isMod = self:IsModeratorPlus()
	if self.adminBtn then self.adminBtn.Visible = isMod end
	self.controlManager:UpdateAdminButtonState(isMod)
end

function UIManager:UpdateAdminButtonText(text)
	self.controlManager:UpdateAdminButtonText(text)
end

function UIManager:ShowNotification(message)
	self.notificationManager:ShowNotification(message)
end

function UIManager:ShowSkipVote(initiatorName, songTitle, totalVoters, requiredVotes, yesVotes, noVotes, isInitiator)
	self.notificationManager:ShowSkipVote(initiatorName, songTitle, totalVoters, requiredVotes, yesVotes, noVotes, isInitiator)
end

function UIManager:UpdateSkipVote(yesVotes, noVotes, totalVoters, requiredVotes)
	self.notificationManager:UpdateSkipVote(yesVotes, noVotes, totalVoters, requiredVotes)
end

function UIManager:HideSkipVote()
	self.notificationManager:HideSkipVote()
end

function UIManager:ShowSkipVoteResult(passed)
	self.notificationManager:ShowSkipVoteResult(passed)
end

function UIManager:ShowBlockFrame()
	if not self:IsModeratorPlus() then
		self.adminFrame.Visible = true
		self.adminInfoText.Text = "🔒 Music access is currently restricted by Admin"
	end
end

function UIManager:HideBlockFrame()
	self.adminFrame.Visible = false
end

function UIManager:ResetUI()
	self.isPlaying = false
	self.currentSongId = nil
	self.songTitle.Text = "No music playing"
	if self.songSubtitle then
		self.songSubtitle.Visible = false
		self.songSubtitle.Text = ""
	end
	self.playlistLabel.Text = "None"
	self.requesterName.Text = "None"
	self.songPicture.Image = DEFAULT_COVER
	self.controlManager:UpdateProgress(0, 0, 0)
	self:UpdateLikeButtonState()
end

function UIManager:SetVolume(volumePercent)
	self.controlManager:SetVolume(volumePercent)
end

function UIManager:ToggleMainFrame()
	self.mainFrame.Visible = not self.mainFrame.Visible
end

function UIManager:ShowMainFrame()
	self.mainFrame.Visible = true
end

function UIManager:HideMainFrame()
	self.mainFrame.Visible = false
end

function UIManager:OnMusicSubmit(callback) self.callbacks.onMusicSubmit = callback end
function UIManager:OnNext(callback) self.callbacks.onNext = callback end
function UIManager:OnReload(callback) self.callbacks.onReload = callback end
function UIManager:OnVolumeChange(callback) self.callbacks.onVolumeChange = callback end
function UIManager:OnSkipVoteResponse(callback) self.callbacks.onSkipVoteResponse = callback end
function UIManager:OnAdminToggleBlock(callback) self.callbacks.onAdminToggleBlock = callback end
function UIManager:OnToggleFavorite(callback) self.callbacks.onToggleFavorite = callback end

return UIManager