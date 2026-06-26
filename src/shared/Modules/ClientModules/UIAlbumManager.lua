local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MusicModule = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("MusicModule"))

local UIAlbumManager = {}
UIAlbumManager.__index = UIAlbumManager

function UIAlbumManager.new(albumList, albumTemplateBtn)
	local self = setmetatable({}, UIAlbumManager)

	self.albumList = albumList
	self.albumTemplateBtn = albumTemplateBtn
	self.currentAlbum = "All Songs"
	self.favoriteSongs = {}
	self.onAlbumSelectedCallback = nil
	self.albumButtons = {} -- Track album buttons for highlighting

	return self
end

-- ====================================
-- HIGHLIGHT SELECTED ALBUM
-- ====================================
function UIAlbumManager:HighlightAlbum(albumName)
	-- Remove highlight from all buttons
	for name, button in pairs(self.albumButtons) do
		button.BackgroundColor3 = Color3.fromRGB(45, 45, 45) -- Default color
		button.TextColor3 = Color3.fromRGB(200, 200, 200)
	end

	-- Highlight selected album
	local selectedButton = self.albumButtons[albumName]
	if selectedButton then
		selectedButton.BackgroundColor3 = Color3.fromRGB(70, 130, 180) -- Highlight color
		selectedButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	end
end

-- ====================================
-- LOAD ALBUMS
-- ====================================
function UIAlbumManager:LoadAlbums(favoriteSongs, silent)
	self.favoriteSongs = favoriteSongs or {}

	-- Clear existing albums
	for _, child in ipairs(self.albumList:GetChildren()) do
		if child:IsA("TextButton") and child ~= self.albumTemplateBtn then
			child:Destroy()
		end
	end

	self.albumButtons = {}

	-- Get all albums
	local albums = MusicModule:GetAllAlbums(self.favoriteSongs)

	-- Create album buttons
	for index, albumData in ipairs(albums) do
		local albumBtn = self.albumTemplateBtn:Clone()
		albumBtn.Name = "Album_" .. albumData.name
		albumBtn.Visible = true
		albumBtn.Text = string.format("%s (%d)", albumData.name, albumData.songCount)
		albumBtn.Parent = self.albumList

		-- Store button reference
		self.albumButtons[albumData.name] = albumBtn

		albumBtn.MouseButton1Click:Connect(function()
			self:SelectAlbum(albumData.name)
		end)
		
		-- 🔥 ANTI-FREEZE: Cicil pembuatan UI Album
		if index % 3 == 0 then
			task.wait()
		end
	end

	-- Restore previous selection or default to "All Songs"
	if self.albumButtons[self.currentAlbum] then
		self:SelectAlbum(self.currentAlbum, silent)
	else
		self:SelectAlbum("All Songs", silent)
	end
end

-- ====================================
-- SELECT ALBUM
-- ====================================
function UIAlbumManager:SelectAlbum(albumName, silent)
	-- Update current album
	self.currentAlbum = albumName

	-- Highlight selected album
	self:HighlightAlbum(albumName)

	-- Callback to update playlist
	if not silent and self.onAlbumSelectedCallback then
		self.onAlbumSelectedCallback(albumName)
	end
end

-- ====================================
-- UPDATE FAVORITES (PRESERVE SELECTION)
-- ====================================
function UIAlbumManager:UpdateFavorites(favoriteSongs)
	self.favoriteSongs = favoriteSongs

	-- Store current selection
	local previousAlbum = self.currentAlbum

	-- Reload albums to update "My Favorites" count silently
	self:LoadAlbums(favoriteSongs, true)
	
	-- Note: LoadAlbums will restore the previous selection silently due to the true flag
end

-- ====================================
-- GETTERS
-- ====================================
function UIAlbumManager:GetCurrentAlbum()
	return self.currentAlbum
end

function UIAlbumManager:GetFavoriteSongs()
	return self.favoriteSongs
end

-- ====================================
-- CALLBACK SETTER
-- ====================================
function UIAlbumManager:OnAlbumSelected(callback)
	self.onAlbumSelectedCallback = callback
end

return UIAlbumManager