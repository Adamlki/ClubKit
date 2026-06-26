local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MusicModule = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("MusicModule"))

local UIPlaylistManager = {}
UIPlaylistManager.__index = UIPlaylistManager

function UIPlaylistManager.new(playlist, playlistTemplateFrame)
	local self = setmetatable({}, UIPlaylistManager)

	self.playlist = playlist
	self.playlistTemplateFrame = playlistTemplateFrame
	self.currentPlaylist = {}
	self.favoriteSongs = {}
	self.onPlayCallback = nil
	self.onToggleFavoriteCallback = nil
	self.noResultsLabel = nil -- Track the "no results" label

	return self
end

-- ====================================
-- CLEAR PLAYLIST
-- ====================================
function UIPlaylistManager:ClearPlaylist()
	-- Clear all items including "No Results" label
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
	-- Remove old "no results" label if exists
	if self.noResultsLabel and self.noResultsLabel.Parent then
		self.noResultsLabel:Destroy()
	end

	local noResultLabel = Instance.new("TextLabel")
	noResultLabel.Name = "NoResults"
	noResultLabel.Size = UDim2.new(1, 0, 0, 40)
	noResultLabel.BackgroundTransparency = 1
	noResultLabel.Font = Enum.Font.GothamMedium
	noResultLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
	noResultLabel.TextSize = 14
	noResultLabel.Text = "No songs found"
	noResultLabel.Parent = self.playlist

	self.noResultsLabel = noResultLabel
end

-- ====================================
-- UPDATE PLAYLIST (FIXED)
-- ====================================
function UIPlaylistManager:UpdatePlaylist(musicList)
	self.currentPlaylist = musicList
	
	-- Increment render counter to cancel any ongoing renders
	self.renderCounter = (self.renderCounter or 0) + 1
	local currentRender = self.renderCounter

	-- Clear ALL existing items (including "No Results")
	self:ClearPlaylist()

	-- Check if empty
	if #musicList == 0 then
		self:ShowNoResults()
		return
	end

	-- Create playlist items
	for index, music in ipairs(musicList) do
		-- Abort if a new playlist update was requested
		if self.renderCounter ~= currentRender then
			return
		end
		
		local itemFrame = self.playlistTemplateFrame:Clone()
		itemFrame.Name = "PlaylistItem_" .. index
		itemFrame.Visible = true
		itemFrame.Parent = self.playlist

		local songTitleLabel = itemFrame:WaitForChild("SongTitle")
		local playBtn = itemFrame:WaitForChild("PlayBtn")
		local favBtn = itemFrame:WaitForChild("FavouriteBtn")

		songTitleLabel.Text = music.judul

		-- Play button
		playBtn.MouseButton1Click:Connect(function()
			if self.onPlayCallback then
				self.onPlayCallback(music.id)
			end
		end)

		-- Favorite button
		local isFavorite = self:IsMusicFavorite(music.id)
		favBtn.Text = isFavorite and "❤️" or "♡"
		favBtn.TextColor3 = isFavorite and Color3.fromRGB(255, 215, 0) or Color3.fromRGB(200, 200, 200)

		favBtn.MouseButton1Click:Connect(function()
			if self.onToggleFavoriteCallback then
				self.onToggleFavoriteCallback(music.id)
			end
		end)

		-- Prevent UI freeze if the playlist is massive
		if index % 4 == 0 then
			task.wait()
		end
	end
end

-- ====================================
-- SEARCH
-- ====================================
function UIPlaylistManager:SearchInAlbum(albumName, query)
	local results = MusicModule:SearchInAlbum(albumName, query, self.favoriteSongs)
	self:UpdatePlaylist(results)
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
	self.favoriteSongs = favoriteSongs

	-- Refresh favorite buttons WITHOUT recreating the entire playlist (prevents massive lag spike)
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
					favBtn.TextColor3 = isFavorite and Color3.fromRGB(255, 215, 0) or Color3.fromRGB(200, 200, 200)
				end
			end
		end
	end
end

-- ====================================
-- CALLBACK SETTERS
-- ====================================
function UIPlaylistManager:OnPlay(callback)
	self.onPlayCallback = callback
end

function UIPlaylistManager:OnToggleFavorite(callback)
	self.onToggleFavoriteCallback = callback
end

return UIPlaylistManager