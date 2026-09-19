local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MusicModule = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("MusicModule"))

local UIPlaylistManager = {}
UIPlaylistManager.__index = UIPlaylistManager

local DEFAULT_COVER = "rbxassetid://100874885625675"

function UIPlaylistManager.new(playlist, playlistTemplateFrame)
	local self = setmetatable({}, UIPlaylistManager)

	self.playlist = playlist
	self.playlistTemplateFrame = playlistTemplateFrame
	self.currentPlaylist = {}
	self.favoriteSongs = {}
	self.onPlayCallback = nil
	self.onToggleFavoriteCallback = nil
	self.noResultsLabel = nil
	self.renderCounter = 0

	return self
end

-- ====================================
-- CLEAR PLAYLIST
-- ====================================
function UIPlaylistManager:ClearPlaylist()
	for _, child in ipairs(self.playlist:GetChildren()) do
		if child:IsA("Frame") and child ~= self.playlistTemplateFrame then
			child:Destroy()
		elseif child:IsA("TextLabel") and child.Name == "NoResults" then
			child:Destroy()
		end
	end
	self.noResultsLabel = nil
end

-- ====================================
-- SHOW NO RESULTS MESSAGE
-- ====================================
function UIPlaylistManager:ShowNoResults()
	if self.noResultsLabel and self.noResultsLabel.Parent then
		self.noResultsLabel:Destroy()
	end

	local noResultLabel = Instance.new("TextLabel")
	noResultLabel.Name = "NoResults"
	noResultLabel.Size = UDim2.new(1, 0, 0, 60)
	noResultLabel.BackgroundTransparency = 1
	noResultLabel.Font = Enum.Font.GothamMedium
	noResultLabel.TextColor3 = Color3.fromRGB(130, 130, 130)
	noResultLabel.TextSize = 13
	noResultLabel.Text = "No songs found in this playlist."
	noResultLabel.Parent = self.playlist

	self.noResultsLabel = noResultLabel
end

-- ====================================
-- UPDATE PLAYLIST (TABLE VIEW)
-- ====================================
function UIPlaylistManager:UpdatePlaylist(musicList, albumName)
	self.currentPlaylist = musicList or {}
	self.currentAlbumName = albumName
	self.renderCounter = (self.renderCounter or 0) + 1
	local currentRender = self.renderCounter

	self:ClearPlaylist()

	if #self.currentPlaylist == 0 then
		self:ShowNoResults()
		return
	end

	local albumCover = albumName and MusicModule:GetAlbumCover(albumName)

	for index, music in ipairs(self.currentPlaylist) do
		if self.renderCounter ~= currentRender then
			return
		end

		local itemFrame = self.playlistTemplateFrame:Clone()
		itemFrame.Name = "PlaylistItem_" .. index
		itemFrame.LayoutOrder = index
		itemFrame.Visible = true
		itemFrame.Parent = self.playlist

		local posLabel = itemFrame:FindFirstChild("PositionLabel")
		local thumbImg = itemFrame:FindFirstChild("SongThumbnail")
		local titleLabel = itemFrame:FindFirstChild("SongTitle")
		local colLabel = itemFrame:FindFirstChild("CollectionLabel")
		local addBtn = itemFrame:FindFirstChild("AddQueueBtn")
		local favBtn = itemFrame:FindFirstChild("FavouriteBtn")

		if posLabel then posLabel.Text = tostring(index) end

		-- Sync cover image with the playlist cover (e.g. Thailand cover for Thailand playlist)
		local songCover = albumCover or (music.album and MusicModule:GetAlbumCover(music.album)) or music.sampul or DEFAULT_COVER
		if thumbImg then thumbImg.Image = songCover end

		if titleLabel then titleLabel.Text = music.judul or "Unknown" end
		if colLabel then colLabel.Text = music.album or "Unknown" end

		-- Dedicated "+" Add to Queue Button
		if addBtn then
			addBtn.MouseButton1Click:Connect(function()
				-- Visual feedback: change '+' to '✓' briefly
				addBtn.Text = "✓"
				addBtn.TextColor3 = Color3.fromRGB(46, 220, 113)
				local stroke = addBtn:FindFirstChild("BtnStroke") or addBtn:FindFirstChildOfClass("UIStroke")
				if stroke then stroke.Color = Color3.fromRGB(46, 220, 113) end

				task.delay(0.7, function()
					if addBtn and addBtn.Parent then
						addBtn.Text = "+"
						addBtn.TextColor3 = Color3.fromRGB(240, 240, 240)
						if stroke then stroke.Color = Color3.fromRGB(44, 44, 44) end
					end
				end)

				if self.onPlayCallback then
					self.onPlayCallback(music.id)
				end
			end)
		end

		-- Favorite toggle
		local isFavorite = self:IsMusicFavorite(music.id)
		if favBtn then
			favBtn.Text = isFavorite and "❤️" or "♡"
			favBtn.TextColor3 = isFavorite and Color3.fromRGB(255, 90, 120) or Color3.fromRGB(160, 160, 160)

			favBtn.MouseButton1Click:Connect(function()
				if self.onToggleFavoriteCallback then
					self.onToggleFavoriteCallback(music.id)
				end
			end)
		end

		-- Yield periodically to avoid micro-stutters on huge playlists
		if index % 15 == 0 then
			task.wait()
		end
	end
end

-- ====================================
-- SEARCH IN ALBUM
-- ====================================
function UIPlaylistManager:SearchInAlbum(albumName, query)
	if not query or query:match("^%s*$") then
		local songs = MusicModule:GetAlbumSongs(albumName, self.favoriteSongs)
		self:UpdatePlaylist(songs, albumName)
		return
	end

	local results = MusicModule:SearchInAlbum(albumName, query, self.favoriteSongs)
	self:UpdatePlaylist(results, albumName)
end

-- ====================================
-- FAVORITES
-- ====================================
function UIPlaylistManager:IsMusicFavorite(musicId)
	for _, favId in ipairs(self.favoriteSongs) do
		if favId == musicId then
			return true
		end
	end
	return false
end

function UIPlaylistManager:UpdateFavorites(favoriteSongs)
	self.favoriteSongs = favoriteSongs or {}

	for _, child in ipairs(self.playlist:GetChildren()) do
		if child:IsA("Frame") and child.Name:match("^PlaylistItem_") then
			local indexStr = child.Name:match("^PlaylistItem_(%d+)$")
			local index = indexStr and tonumber(indexStr)

			if index and self.currentPlaylist[index] then
				local musicId = self.currentPlaylist[index].id
				local favBtn = child:FindFirstChild("FavouriteBtn")

				if favBtn then
					local isFavorite = self:IsMusicFavorite(musicId)
					favBtn.Text = isFavorite and "❤️" or "♡"
					favBtn.TextColor3 = isFavorite and Color3.fromRGB(255, 90, 120) or Color3.fromRGB(140, 140, 140)
				end
			end
		end
	end
end

-- ====================================
-- CALLBACKS
-- ====================================
function UIPlaylistManager:OnPlay(callback)
	self.onPlayCallback = callback
end

function UIPlaylistManager:OnToggleFavorite(callback)
	self.onToggleFavoriteCallback = callback
end

return UIPlaylistManager