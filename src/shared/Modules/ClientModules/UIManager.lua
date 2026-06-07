local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MusicModule = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("MusicModule"))

local UIAlbumManager = require(script.Parent.UIAlbumManager)
local UIPlaylistManager = require(script.Parent.UIPlaylistManager)
local UIControlManager = require(script.Parent.UIControlManager)
local UINotificationManager = require(script.Parent.UINotificationManager)

local UIManager = {}
UIManager.__index = UIManager

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
	item.Parent = nil

	table.insert(self.inactiveItems, item)
end

function QueueItemPool:ReturnAll()
	while #self.activeItems > 0 do
		self:Return(self.activeItems[1])
	end
end

function QueueItemPool:Clear()
	for _, item in ipairs(self.activeItems) do
		item:Destroy()
	end
	for _, item in ipairs(self.inactiveItems) do
		item:Destroy()
	end

	self.activeItems = {}
	self.inactiveItems = {}
end

-- ====================================
-- UI MANAGER
-- ====================================
function UIManager.new(gui)
	local self = setmetatable({}, UIManager)

	self.gui = gui
	local MF = gui:WaitForChild("MainFrame")
	local NF = gui:WaitForChild("NotificationFrame")
	local NP = gui:WaitForChild("Nowplayingframe")
	local SF = gui:WaitForChild("SkipFrame")

	-- Main Frame Components
	self.mainFrame = MF
	self.header = MF:WaitForChild("Header")
	self.closeBtn = self.header:WaitForChild("CloseBtn")

	-- Song Info
	self.songPicture = MF:WaitForChild("Songpicture")
	self.songTitle = MF:WaitForChild("SongTitle")
	self.requesterName = MF:WaitForChild("Requestername")

	-- Search & Input
	self.searchBox = MF:WaitForChild("SearchBox")
	self.searchByIdBox = MF:WaitForChild("Searchbyidbox")
	self.enterBtn = MF:WaitForChild("EnterBtn")

	-- Queue
	self.queueList = MF:WaitForChild("Queuelist")
	self.queueTemplateFrame = self.queueList:WaitForChild("QueueTemplate")
	self.queueTemplateFrame.Visible = false

	-- Initialize Queue Item Pool
	self.queuePool = QueueItemPool.new(self.queueTemplateFrame)

	-- Admin Frame
	self.adminFrame = MF:WaitForChild("AdminFrame")
	self.adminInfoText = self.adminFrame:WaitForChild("AdminNotif")

	-- Initialize sub-managers
	self.albumManager = UIAlbumManager.new(
		MF:WaitForChild("Albumlist"),
		MF:WaitForChild("Albumlist"):WaitForChild("TemplateBtn")
	)

	self.playlistManager = UIPlaylistManager.new(
		MF:WaitForChild("Playlist"),
		MF:WaitForChild("Playlist"):WaitForChild("TemplateFrame")
	)

	self.controlManager = UIControlManager.new({
		skipBtn = MF:WaitForChild("SkipBtn"),
		adminBtn = MF:WaitForChild("AdminBtn"),
		volumeFrameBg = MF:WaitForChild("Volumeframebg"),
		volumeBar = MF:WaitForChild("Volumeframebg"):WaitForChild("Volume"),
		volumeBtn = MF:WaitForChild("Volumeframebg"):WaitForChild("Volume"):WaitForChild("volumeBtn"),
		volumelabel = MF:WaitForChild("Volumelabel"),
		trackFrameBg = MF:WaitForChild("trackframebg"),
		trackBar = MF:WaitForChild("trackframebg"):WaitForChild("track"),
		timeLabel = MF:WaitForChild("timelabel")
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

	-- State
	self.playerRole = "Player"

	-- Callbacks
	self.callbacks = {
		onMusicSubmit = nil,
		onNext = nil,
		onVolumeChange = nil,
		onSkipVoteResponse = nil,
		onAdminToggleBlock = nil,
		onToggleFavorite = nil,
	}

	-- Setup
	self:SetupConnections()
	self:SetupRoleWatcher()
	self:ResetUI()

	-- Hide frames initially
	self.mainFrame.Visible = false
	NF.Visible = false
	NP.Visible = false
	SF.Visible = false
	self.adminFrame.Visible = false

	return self
end

-- ====================================
-- ROLE SYSTEM
-- ====================================
function UIManager:SetupRoleWatcher()
	local player = Players.LocalPlayer

	local roleValue = player:FindFirstChild("Role")
	if roleValue and roleValue:IsA("StringValue") then
		self.playerRole = roleValue.Value
		self:UpdateAdminButtonState()

		roleValue.Changed:Connect(function()
			self.playerRole = roleValue.Value
			self:UpdateAdminButtonState()
		end)
	else
		player.ChildAdded:Connect(function(child)
			if child.Name == "Role" and child:IsA("StringValue") then
				self.playerRole = child.Value
				self:UpdateAdminButtonState()

				child.Changed:Connect(function()
					self.playerRole = child.Value
					self:UpdateAdminButtonState()
				end)
			end
		end)
	end
end

function UIManager:GetPlayerRoleHierarchy()
	local roleHierarchy = {
		Owner = 6,
		Admin = 5,
		Moderator = 4,
		DJ = 3,
		VVIP = 3,
		VIP = 2,
		Player = 1
	}
	return roleHierarchy[self.playerRole] or 1
end

function UIManager:IsModeratorPlus()
	return self:GetPlayerRoleHierarchy() >= 4
end

function UIManager:UpdateAdminButtonState()
	local isMod = self:IsModeratorPlus()
	self.controlManager:UpdateAdminButtonState(isMod)
end

function UIManager:UpdateAdminButtonText(newText)
	if self:IsModeratorPlus() then
		self.controlManager:UpdateAdminButtonText(newText)
	end
end

-- ====================================
-- SETUP CONNECTIONS
-- ====================================
function UIManager:SetupConnections()
	-- Close button
	self.closeBtn.MouseButton1Click:Connect(function()
		self.mainFrame.Visible = false
	end)

	-- Search box
	self.searchBox.Focused:Connect(function()
		self.searchBox.PlaceholderText = ""
	end)

	self.searchBox.FocusLost:Connect(function()
		if self.searchBox.Text == "" then
			self.searchBox.PlaceholderText = "Search in playlist..."
		end
	end)

	self.searchBox.Changed:Connect(function(property)
		if property == "Text" then
			self:OnSearchChanged(self.searchBox.Text)
		end
	end)

	-- Enter button (Music ID)
	self.enterBtn.MouseButton1Click:Connect(function()
		self:OnMusicIdSubmit()
	end)

	self.searchByIdBox.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			self:OnMusicIdSubmit()
		end
	end)

	-- Connect sub-managers
	self.albumManager:OnAlbumSelected(function(albumName)
		-- Clear search when selecting album
		self.searchBox.Text = ""
		local songs = MusicModule:GetAlbumSongs(albumName, self.albumManager:GetFavoriteSongs())
		self.playlistManager:UpdatePlaylist(songs)
	end)

	self.playlistManager:OnPlay(function(musicId)
		if self.callbacks.onMusicSubmit then
			self.callbacks.onMusicSubmit(musicId)
		end
		-- FIXED: Tidak kembali ke "All Songs" lagi!
		-- Album tetap pada pilihan terakhir user
	end)

	self.playlistManager:OnToggleFavorite(function(musicId)
		if self.callbacks.onToggleFavorite then
			self.callbacks.onToggleFavorite(musicId)
		end
	end)

	self.controlManager:OnNext(function()
		if self.callbacks.onNext then
			self.callbacks.onNext()
		end
	end)

	self.controlManager:OnVolumeChange(function(percent)
		if self.callbacks.onVolumeChange then
			self.callbacks.onVolumeChange(percent)
		end
	end)

	self.controlManager:OnAdminToggleBlock(function()
		if self.callbacks.onAdminToggleBlock then
			self.callbacks.onAdminToggleBlock()
		end
	end)

	self.notificationManager:OnSkipVoteResponse(function(voteType)
		if self.callbacks.onSkipVoteResponse then
			self.callbacks.onSkipVoteResponse(voteType)
		end
	end)
end

-- ====================================
-- SEARCH (FIXED)
-- ====================================
function UIManager:OnSearchChanged(query)
	local currentAlbum = self.albumManager:GetCurrentAlbum()
	self.playlistManager:SearchInAlbum(currentAlbum, query)
end

-- ====================================
-- MUSIC ID SUBMIT
-- ====================================
function UIManager:OnMusicIdSubmit()
	local musicId = self.searchByIdBox.Text:gsub("%s+", "")
	if musicId ~= "" and self.callbacks.onMusicSubmit then
		self.callbacks.onMusicSubmit(musicId)
		self.searchByIdBox.Text = ""
	end
end

-- ====================================
-- LOAD ALBUMS
-- ====================================
function UIManager:LoadAlbums(favoriteSongs)
	self.albumManager:LoadAlbums(favoriteSongs)
end

-- ====================================
-- UPDATE QUEUE (WITH OBJECT POOLING)
-- ====================================
function UIManager:UpdateQueue(queueData)
	self.queuePool:ReturnAll()

	if #queueData == 0 then
		return
	end

	for index, songData in ipairs(queueData) do
		local queueFrame = self.queuePool:Get()
		queueFrame.Parent = self.queueList

		local positionLabel = queueFrame:WaitForChild("PositionLabel")
		local requesterLabel = queueFrame:WaitForChild("RequesterLabel")
		local songTitleLabel = queueFrame:WaitForChild("SongTitleLabel")

		positionLabel.Text = tostring(index)
		requesterLabel.Text = songData.uploader or "Unknown"
		songTitleLabel.Text = songData.musicData.judul or "Unknown"

		if index % 10 == 0 then
			task.wait()
		end
	end
end

-- ====================================
-- UPDATE METHODS
-- ====================================
function UIManager:UpdateNowPlaying(musicData, uploaderName, showPopup)
	self.songTitle.Text = musicData.judul or "Unknown"
	self.requesterName.Text = "Added by: " .. (uploaderName or "Unknown")
	self.songPicture.Image = musicData.sampul or ""

	-- Only show popup if explicitly requested (when song actually starts playing)
	if showPopup ~= false then
		self.notificationManager:ShowNowPlayingPopup(musicData, uploaderName)
	end
end

function UIManager:UpdateProgress(progress, currentTime, totalTime)
	self.controlManager:UpdateProgress(progress, currentTime, totalTime)
end

function UIManager:UpdateSongDuration(duration)
	self.controlManager:UpdateSongDuration(duration)
end

function UIManager:UpdateFavorites(favoriteSongs)
	self.albumManager:UpdateFavorites(favoriteSongs)
	self.playlistManager:UpdateFavorites(favoriteSongs)
end

-- ====================================
-- NOTIFICATIONS
-- ====================================
function UIManager:ShowNotification(message)
	self.notificationManager:ShowNotification(message)
end

-- ====================================
-- SKIP VOTE UI
-- ====================================
function UIManager:ShowSkipVote(initiatorName, songTitle, totalVoters)
	self.notificationManager:ShowSkipVote(initiatorName, songTitle, totalVoters)
end

function UIManager:UpdateSkipVote(yesVotes, noVotes, totalVoters)
	self.notificationManager:UpdateSkipVote(yesVotes, noVotes, totalVoters)
end

function UIManager:HideSkipVote()
	self.notificationManager:HideSkipVote()
end

function UIManager:ShowSkipVoteResult(passed)
	self.notificationManager:ShowSkipVoteResult(passed)
end

-- ====================================
-- ADMIN BLOCK UI
-- ====================================
function UIManager:ShowBlockFrame()
	if not self:IsModeratorPlus() then
		self.adminFrame.Visible = true
		self.adminInfoText.Text = "Music access is currently restricted by Admin"
	end
end

function UIManager:HideBlockFrame()
	self.adminFrame.Visible = false
end

-- ====================================
-- UI RESET
-- ====================================
function UIManager:ResetUI()
	self.songTitle.Text = "No music playing"
	self.requesterName.Text = ""
	self.songPicture.Image = ""
	self.controlManager:UpdateProgress(0, 0, 0)
end

-- ====================================
-- VOLUME
-- ====================================
function UIManager:SetVolume(volumePercent)
	self.controlManager:SetVolume(volumePercent)
end

-- ====================================
-- CLEANUP
-- ====================================
function UIManager:Cleanup()
	self.queuePool:Clear()
	self.notificationManager:Cleanup()
end

-- ====================================
-- CALLBACK SETTERS
-- ====================================
function UIManager:OnMusicSubmit(callback)
	self.callbacks.onMusicSubmit = callback
end

function UIManager:OnNext(callback)
	self.callbacks.onNext = callback
end

function UIManager:OnVolumeChange(callback)
	self.callbacks.onVolumeChange = callback
end

function UIManager:OnSkipVoteResponse(callback)
	self.callbacks.onSkipVoteResponse = callback
end

function UIManager:OnAdminToggleBlock(callback)
	self.callbacks.onAdminToggleBlock = callback
end

function UIManager:OnToggleFavorite(callback)
	self.callbacks.onToggleFavorite = callback
end

-- ====================================
-- TOGGLE MAIN FRAME
-- ====================================
function UIManager:ToggleMainFrame()
	self.mainFrame.Visible = not self.mainFrame.Visible
end

function UIManager:ShowMainFrame()
	self.mainFrame.Visible = true
end

function UIManager:HideMainFrame()
	self.mainFrame.Visible = false
end

return UIManager    