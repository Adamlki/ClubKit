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
	return self
end

function QueueItemPool:Get()
	local item
	if #self.inactiveItems > 0 then
		item = table.remove(self.inactiveItems)
		item.Visible = true
	else
		item = self.template:Clone()
	end
	table.insert(self.activeItems, item)
	return item
end

function QueueItemPool:Return(item)
	for i, activeItem in ipairs(self.activeItems) do
		if activeItem == item then
			table.remove(self.activeItems, i)
			break
		end
	end
	item.Visible = false
	table.insert(self.inactiveItems, item)
end

function QueueItemPool:ReturnAll()
	while #self.activeItems > 0 do
		self:Return(self.activeItems[1])
	end
end

function QueueItemPool:Clear()
	for _, item in ipairs(self.activeItems) do item:Destroy() end
	for _, item in ipairs(self.inactiveItems) do item:Destroy() end
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

	-- Header Tab Switcher
	local tabSwitcher = self.header:WaitForChild("TabSwitcher")
	self.homeTabBtn = tabSwitcher:WaitForChild("HomeTabBtn")
	self.libraryTabBtn = tabSwitcher:WaitForChild("LibraryTabBtn")

	-- Views
	self.homeView = MF:WaitForChild("HomeView")
	self.libraryView = MF:WaitForChild("LibraryView")

	-- --- HOME VIEW COMPONENTS ---
	local leftCol = self.homeView:WaitForChild("LeftColumn")
	local nowPlayingTop = leftCol:WaitForChild("NowPlayingTop")
	local metaInfo = nowPlayingTop:WaitForChild("MetaInfo")

	self.songPicture = nowPlayingTop:WaitForChild("Songpicture")
	self.songTitle = metaInfo:WaitForChild("SongTitle")
	self.songSubtitle = metaInfo:FindFirstChild("SongSubtitle") or metaInfo:WaitForChild("SongSubtitle", 3)
	if self.songSubtitle then
		self.songSubtitle.Visible = false
		self.songSubtitle.Text = ""
	end
	self.likeBtn = metaInfo:WaitForChild("LikeBtn")

	-- Visualizer bars
	self.visualizerFrame = leftCol:WaitForChild("VisualizerFrame")
	self.visualizerBars = {}
	for _, child in ipairs(self.visualizerFrame:GetChildren()) do
		if child:IsA("Frame") and child.Name:match("^Bar_") then
			table.insert(self.visualizerBars, child)
		end
	end
	table.sort(self.visualizerBars, function(a, b) return a.Name < b.Name end)

	-- Metadata Cards
	local metaCards = leftCol:WaitForChild("MetadataCards")
	local playlistCard = metaCards:WaitForChild("PlaylistCard")
	local queuedByCard = metaCards:WaitForChild("QueuedByCard")
	self.playlistLabel = playlistCard:WaitForChild("ValueLabel")
	self.requesterName = queuedByCard:WaitForChild("Requestername")

	-- Progress Section
	local progressSec = leftCol:WaitForChild("ProgressSection")
	local trackBg = progressSec:WaitForChild("trackframebg")
	local trackFill = trackBg:WaitForChild("track")
	local thumbKnob = trackFill:FindFirstChild("ThumbKnob")
	self.currentTimeLabel = progressSec:WaitForChild("CurrentTimeLabel")
	self.timeLabel = progressSec:WaitForChild("timelabel")

	-- Volume Section
	local volumeSec = leftCol:WaitForChild("VolumeSection")
	local volumeBg = volumeSec:WaitForChild("Volumeframebg")
	local volumeFill = volumeBg:WaitForChild("Volume")
	local volumeBtn = volumeFill:WaitForChild("volumeBtn")
	self.volumeLabel = volumeSec:WaitForChild("Volumelabel")

	-- Action Buttons
	local actionBtns = leftCol:WaitForChild("ActionButtons")
	self.reloadBtn = actionBtns:WaitForChild("ReloadBtn")
	self.skipBtn = actionBtns:WaitForChild("SkipBtn")
	self.adminBtn = self.header:FindFirstChild("AdminBtn") or MF:FindFirstChild("AdminBtn", true)

	-- --- RIGHT COLUMN: QUEUE ---
	local rightCol = self.homeView:WaitForChild("RightColumn")
	local queueHeader = rightCol:WaitForChild("QueueHeader")
	self.queueBadge = queueHeader:WaitForChild("BadgeFrame"):WaitForChild("BadgeCount")
	self.queueList = rightCol:WaitForChild("Queuelist")
	self.queueTemplate = self.queueList:WaitForChild("QueueTemplate")
	self.queueTemplate.Visible = false
	self.emptyQueueLabel = self.queueList:FindFirstChild("EmptyQueueLabel")

	self.queuePool = QueueItemPool.new(self.queueTemplate)

	-- --- LIBRARY VIEW COMPONENTS ---
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

	-- Sub-managers
	self.albumManager = UIAlbumManager.new(self.albumScroll, self.albumTemplate)
	self.playlistManager = UIPlaylistManager.new(self.playlistScroll, self.playlistTemplate)

	self.controlManager = UIControlManager.new({
		skipBtn = self.skipBtn,
		reloadBtn = self.reloadBtn,
		adminBtn = self.adminBtn,
		volumeFrameBg = volumeBg,
		volumeBar = volumeFill,
		volumeBtn = volumeBtn,
		volumelabel = self.volumeLabel,
		trackFrameBg = trackBg,
		trackBar = trackFill,
		thumbKnob = thumbKnob,
		currentTimeLabel = self.currentTimeLabel,
		timeLabel = self.timeLabel
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
		sfSkipText = SF:WaitForChild("Skipnotif")
	})

	-- Admin Frame
	self.adminFrame = MF:WaitForChild("AdminFrame")
	self.adminInfoText = self.adminFrame:WaitForChild("AdminNotif")

	-- State
	self.playerRole = "Player"
	self.currentSongId = nil
	self.isPlaying = false
	self.favoriteSongs = {}
	self.activeTab = "Home"

	-- Callbacks
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

	-- Load albums
	self:LoadAlbums({})

	-- Initially hidden
	self.mainFrame.Visible = false
	NF.Visible = false
	NP.Visible = false
	SF.Visible = false
	self.adminFrame.Visible = false

	-- Library starts on Album / Playlist selection view
	self.hasActiveAlbumOpen = false
	self.albumsSelectionFrame.Visible = true
	self.playlistDetailFrame.Visible = false

	return self
end

-- ====================================
-- RESPONSIVE SCALE LOGIC
-- ====================================
function UIManager:SetupResponsiveScale()
	local uiScale = self.gui:FindFirstChild("UIScale")
	if not uiScale then return end

	local baseX, baseY = 1366, 768
	local function updateScale()
		local cam = workspace.CurrentCamera
		if not cam then return end
		local screenSize = cam.ViewportSize
		if screenSize.X == 0 or screenSize.Y == 0 then return end

		local scaleX = screenSize.X / baseX
		local scaleY = screenSize.Y / baseY
		local baseScale = math.min(scaleX, scaleY)
		local finalScale = baseScale

		if baseScale < 0.5 then
			finalScale = baseScale * 1.2
		elseif baseScale < 0.8 then
			finalScale = baseScale * 1
		elseif baseScale > 1.2 then
			finalScale = baseScale * 0.85
		end

		uiScale.Scale = math.clamp(finalScale, 0.65, 1.4)
	end

	updateScale()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
	end
end

-- ====================================
-- CLOSE BUTTON LOGIC
-- ====================================
function UIManager:SetupCloseButton()
	if self.closeBtn then
		self.closeBtn.MouseButton1Click:Connect(function()
			self:HideMainFrame()
		end)
	end
end

-- ====================================
-- TAB SWITCHER LOGIC
-- ====================================
function UIManager:SetupTabSwitcher()
	local function setTab(tabName)
		self.activeTab = tabName

		local isHome = (tabName == "Home")
		self.homeView.Visible = isHome
		self.libraryView.Visible = not isHome

		-- Home Tab Styling
		local homeStroke = self.homeTabBtn:FindFirstChild("TabStroke")
		if isHome then
			self.homeTabBtn.BackgroundColor3 = Color3.fromRGB(24, 90, 50)
			self.homeTabBtn.BackgroundTransparency = 0
			self.homeTabBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
			self.homeTabBtn.Font = Enum.Font.GothamBold
			if homeStroke then
				homeStroke.Transparency = 0
				homeStroke.Color = Color3.fromRGB(46, 210, 115)
			end
		else
			self.homeTabBtn.BackgroundTransparency = 1
			self.homeTabBtn.TextColor3 = Color3.fromRGB(160, 160, 160)
			self.homeTabBtn.Font = Enum.Font.GothamMedium
			if homeStroke then homeStroke.Transparency = 1 end
		end

		-- Library Tab Styling
		local libStroke = self.libraryTabBtn:FindFirstChild("TabStroke")
		if not isHome then
			self.libraryTabBtn.BackgroundColor3 = Color3.fromRGB(24, 90, 50)
			self.libraryTabBtn.BackgroundTransparency = 0
			self.libraryTabBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
			self.libraryTabBtn.Font = Enum.Font.GothamBold
			if libStroke then
				libStroke.Transparency = 0
				libStroke.Color = Color3.fromRGB(46, 210, 115)
			end

			-- Reset view to Album/Playlist selection if user hasn't chosen one
			if not self.hasActiveAlbumOpen then
				self.playlistDetailFrame.Visible = false
				self.albumsSelectionFrame.Visible = true
			end
		else
			self.libraryTabBtn.BackgroundTransparency = 1
			self.libraryTabBtn.TextColor3 = Color3.fromRGB(160, 160, 160)
			self.libraryTabBtn.Font = Enum.Font.GothamMedium
			if libStroke then libStroke.Transparency = 1 end
		end
	end

	self.homeTabBtn.MouseButton1Click:Connect(function()
		setTab("Home")
	end)

	self.libraryTabBtn.MouseButton1Click:Connect(function()
		setTab("Library")
	end)

	-- Back button in Library (toggles between Album Selector and Playlist Detail)
	self.libBackBtn.MouseButton1Click:Connect(function()
		self.hasActiveAlbumOpen = false
		self.playlistDetailFrame.Visible = false
		self.albumsSelectionFrame.Visible = true
	end)
end

-- ====================================
-- DYNAMIC SOUND VISUALIZER
-- ====================================
function UIManager:SetupVisualizer()
	local barCount = #self.visualizerBars
	if barCount == 0 then return end

	RunService.Heartbeat:Connect(function()
		local t = os.clock()

		for i, bar in ipairs(self.visualizerBars) do
			local targetH = 6
			if self.isPlaying then
				-- Multi-frequency waveform simulation
				local wave1 = math.sin(t * 9 + i * 0.45) * 14
				local wave2 = math.cos(t * 14 - i * 0.7) * 10
				local wave3 = math.sin(t * 5 + i * 1.2) * 8
				local wave4 = math.sin(t * 18 + i * 0.2) * 6
				targetH = math.clamp(18 + wave1 + wave2 + wave3 + wave4, 6, 48)
			end

			local currentH = bar.Size.Y.Offset
			local newH = currentH + (targetH - currentH) * 0.25
			bar.Size = UDim2.new(0, 4, 0, math.floor(newH))
		end
	end)
end

-- ====================================
-- CONNECTIONS
-- ====================================
function UIManager:SetupConnections()
	-- Close Button
	self.closeBtn.MouseButton1Click:Connect(function()
		self.mainFrame.Visible = false
	end)

	-- Like Button on Now Playing
	self.likeBtn.MouseButton1Click:Connect(function()
		if self.currentSongId and self.callbacks.onToggleFavorite then
			self.callbacks.onToggleFavorite(self.currentSongId)
		end
	end)

	-- Search Box in Playlist
	self.searchBox.Changed:Connect(function(property)
		if property == "Text" then
			local currentAlbum = self.albumManager:GetCurrentAlbum()
			self.playlistManager:SearchInAlbum(currentAlbum, self.searchBox.Text)
		end
	end)

	-- Album Selection
	self.albumManager:OnAlbumSelected(function(albumName, songCount, cover)
		self.hasActiveAlbumOpen = true
		self.libTitle.Text = albumName
		self.libCount.Text = string.format("%d songs", songCount)
		local finalCover = cover or MusicModule:GetAlbumCover(albumName)
		self.libCover.Image = finalCover
		self.searchBox.Text = ""

		local songs = MusicModule:GetAlbumSongs(albumName, self.albumManager:GetFavoriteSongs())
		self.playlistManager:UpdatePlaylist(songs, albumName)

		-- Show playlist detail, hide album grid
		self.albumsSelectionFrame.Visible = false
		self.playlistDetailFrame.Visible = true
	end)

	-- Playlist song click (Queue song)
	self.playlistManager:OnPlay(function(musicId)
		if self.callbacks.onMusicSubmit then
			self.callbacks.onMusicSubmit(musicId)
		end
	end)

	-- Playlist song favorite toggle
	self.playlistManager:OnToggleFavorite(function(musicId)
		if self.callbacks.onToggleFavorite then
			self.callbacks.onToggleFavorite(musicId)
		end
	end)

	-- Controls
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

-- ====================================
-- UPDATE QUEUE
-- ====================================
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
		if item.Parent ~= self.queueList then
			item.Parent = self.queueList
		end

		item.LayoutOrder = index
		item.Name = "QueueItem_" .. string.format("%03d", index)

		local posLabel = item:FindFirstChild("PositionLabel")
		local thumb = item:FindFirstChild("SongThumbnail")
		local info = item:FindFirstChild("InfoContainer")
		local favBtn = item:FindFirstChild("FavouriteBtn")

		local musicData = songData.musicData or {}

		if posLabel then posLabel.Text = tostring(index) end
		local albCover = musicData.album and MusicModule:GetAlbumCover(musicData.album)
		local queueCover = albCover or musicData.sampul or DEFAULT_COVER
		if thumb then thumb.Image = queueCover end

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

			favBtn.MouseButton1Click:Connect(function()
				if musicData.id and self.callbacks.onToggleFavorite then
					self.callbacks.onToggleFavorite(musicData.id)
				end
			end)
		end
	end
end

-- ====================================
-- NOW PLAYING UPDATE
-- ====================================
function UIManager:UpdateNowPlaying(musicData, uploaderName, showPopup)
	musicData = musicData or {}
	self.currentSongId = musicData.id
	self.isPlaying = true

	-- Find album if not directly provided in musicData
	local albumName = musicData.album
	if (not albumName or albumName == "") and musicData.id then
		local songObj = MusicModule:GetMusicById(musicData.id)
		if songObj and songObj.album then
			albumName = songObj.album
		end
	end

	self.songTitle.Text = musicData.judul or "No music playing"
	local albumCover = albumName and MusicModule:GetAlbumCover(albumName)
	local finalCover = albumCover or musicData.sampul or DEFAULT_COVER
	self.songPicture.Image = finalCover

	-- Format requester accurately (Server if by system/server, player name if requested by player)
	local requesterDisplay = "Server"
	if uploaderName and uploaderName ~= "" and uploaderName ~= "System" and uploaderName ~= "Unknown" and uploaderName ~= "None" then
		requesterDisplay = uploaderName
	else
		requesterDisplay = "Server"
	end

	local playlistDisplay = (albumName and albumName ~= "") and albumName or "All Songs"

	self.playlistLabel.Text = playlistDisplay
	self.requesterName.Text = requesterDisplay

	-- Subtitle under song title (dihilangkan sesuai request karena sudah ada kartu terpisah di bawah)
	if self.songSubtitle then
		self.songSubtitle.Visible = false
		self.songSubtitle.Text = ""
	end

	self:UpdateLikeButtonState()

	-- Selalu sinkronkan data & gambar cover playlist di Nowplayingframe
	if self.notificationManager then
		if self.notificationManager.npImage then
			self.notificationManager.npImage.Image = finalCover
		end
		if self.notificationManager.npSongTitle then
			self.notificationManager.npSongTitle.Text = musicData.judul or "Unknown"
		end
		if self.notificationManager.npRequester then
			self.notificationManager.npRequester.Text = requesterDisplay
		end
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

-- ====================================
-- FAVORITES
-- ====================================
function UIManager:IsFavorite(musicId)
	if not musicId then return false end
	for _, favId in ipairs(self.favoriteSongs) do
		if favId == musicId then return true end
	end
	return false
end

function UIManager:UpdateLikeButtonState()
	local isFav = self:IsFavorite(self.currentSongId)
	local likeStroke = self.likeBtn:FindFirstChild("LikeStroke")

	if isFav then
		self.likeBtn.Text = "❤️ Liked"
		self.likeBtn.BackgroundColor3 = Color3.fromRGB(44, 24, 34)
		self.likeBtn.TextColor3 = Color3.fromRGB(255, 110, 140)
		if likeStroke then likeStroke.Color = Color3.fromRGB(140, 40, 65) end
	else
		self.likeBtn.Text = "♡ Like"
		self.likeBtn.BackgroundColor3 = Color3.fromRGB(24, 24, 24)
		self.likeBtn.TextColor3 = Color3.fromRGB(220, 220, 220)
		if likeStroke then likeStroke.Color = Color3.fromRGB(44, 44, 44) end
	end
end

function UIManager:UpdateFavorites(favoriteSongs)
	self.favoriteSongs = favoriteSongs or {}
	self:UpdateLikeButtonState()
	self.albumManager:UpdateFavorites(favoriteSongs)
	self.playlistManager:UpdateFavorites(favoriteSongs)
end

-- ====================================
-- ALBUMS
-- ====================================
function UIManager:LoadAlbums(favoriteSongs)
	self.albumManager:LoadAlbums(favoriteSongs)
end

-- ====================================
-- ROLE SYSTEM
-- ====================================
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
		player.ChildAdded:Connect(function(child)
			if child.Name == "Role" and child:IsA("StringValue") then
				updateRole(child.Value)
				child.Changed:Connect(updateRole)
			end
		end)
		task.spawn(function()
			local foundRole = player:WaitForChild("Role", 10)
			if foundRole and foundRole:IsA("StringValue") then
				updateRole(foundRole.Value)
				foundRole.Changed:Connect(updateRole)
			end
		end)
	end
end

function UIManager:IsModeratorPlus()
	local hierarchy = {
		Owner = 5, Admin = 4, Moderator = 3, VIP = 2, Player = 1
	}
	return (hierarchy[self.playerRole] or 1) >= 3
end

function UIManager:UpdateAdminButtonState()
	local isMod = self:IsModeratorPlus()
	if self.adminBtn then
		self.adminBtn.Visible = isMod
	end
	self.controlManager:UpdateAdminButtonState(isMod)
end

function UIManager:UpdateAdminButtonText(text)
	self.controlManager:UpdateAdminButtonText(text)
end

-- ====================================
-- NOTIFICATIONS
-- ====================================
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

-- ====================================
-- RESET & VOLUME
-- ====================================
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

-- ====================================
-- CALLBACK REGISTRATION
-- ====================================
function UIManager:OnMusicSubmit(callback) self.callbacks.onMusicSubmit = callback end
function UIManager:OnNext(callback) self.callbacks.onNext = callback end
function UIManager:OnReload(callback) self.callbacks.onReload = callback end
function UIManager:OnVolumeChange(callback) self.callbacks.onVolumeChange = callback end
function UIManager:OnSkipVoteResponse(callback) self.callbacks.onSkipVoteResponse = callback end
function UIManager:OnAdminToggleBlock(callback) self.callbacks.onAdminToggleBlock = callback end
function UIManager:OnToggleFavorite(callback) self.callbacks.onToggleFavorite = callback end

return UIManager