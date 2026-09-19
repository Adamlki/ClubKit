local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MusicModule = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("MusicModule"))

local UIAlbumManager = {}
UIAlbumManager.__index = UIAlbumManager

local DEFAULT_COVER = "rbxassetid://100874885625675"

function UIAlbumManager.new(albumList, albumTemplateBtn)
	local self = setmetatable({}, UIAlbumManager)

	self.albumList = albumList
	self.albumTemplateBtn = albumTemplateBtn
	self.currentAlbum = "All Songs"
	self.favoriteSongs = {}
	self.onAlbumSelectedCallback = nil
	self.albumButtons = {}

	return self
end

-- ====================================
-- LOAD ALBUMS
-- ====================================
function UIAlbumManager:LoadAlbums(favoriteSongs, silent)
	self.favoriteSongs = favoriteSongs or {}

	for _, child in ipairs(self.albumList:GetChildren()) do
		if child:IsA("TextButton") and child ~= self.albumTemplateBtn then
			child:Destroy()
		end
	end

	self.albumButtons = {}

	local albums = MusicModule:GetAllAlbums(self.favoriteSongs)

	for index, albumData in ipairs(albums) do
		local albumBtn = self.albumTemplateBtn:Clone()
		albumBtn.Name = "Album_" .. albumData.name
		albumBtn.LayoutOrder = index
		albumBtn.Visible = true
		albumBtn.Parent = self.albumList

		local textWrap = albumBtn:FindFirstChild("TextWrap")
		local titleLabel = textWrap and textWrap:FindFirstChild("AlbumTitle")
		local countLabel = textWrap and textWrap:FindFirstChild("SongCount")
		local thumbImg = albumBtn:FindFirstChild("AlbumThumb")

		if titleLabel then
			titleLabel.Text = albumData.name
		end
		if countLabel then
			countLabel.Text = string.format("%d songs", albumData.songCount)
		end
		if thumbImg then
			thumbImg.Image = albumData.cover or (MusicModule.GetAlbumCover and MusicModule:GetAlbumCover(albumData.name)) or "rbxassetid://100874885625675"
		end

		self.albumButtons[albumData.name] = albumBtn

		albumBtn.MouseButton1Click:Connect(function()
			self:SelectAlbum(albumData.name, false, albumData.songCount)
		end)
	end

	-- Restore selection or default to "All Songs"
	if not silent then
		self:SelectAlbum(self.currentAlbum or "All Songs", true)
	end
end

-- ====================================
-- SELECT ALBUM
-- ====================================
function UIAlbumManager:SelectAlbum(albumName, silent, songCount)
	self.currentAlbum = albumName

	-- Highlight active card
	for name, btn in pairs(self.albumButtons) do
		local stroke = btn:FindFirstChild("UIStroke")
		if stroke then
			stroke.Color = (name == albumName) and Color3.fromRGB(46, 210, 115) or Color3.fromRGB(40, 40, 40)
			stroke.Thickness = (name == albumName) and 1.5 or 1
		end
		btn.BackgroundColor3 = (name == albumName) and Color3.fromRGB(32, 32, 32) or Color3.fromRGB(22, 22, 22)
	end

	if not silent and self.onAlbumSelectedCallback then
		local songs = MusicModule:GetAlbumSongs(albumName, self.favoriteSongs)
		local count = songCount or (songs and #songs) or 0
		local cover = (MusicModule.GetAlbumCover and MusicModule:GetAlbumCover(albumName)) or "rbxassetid://100874885625675"
		self.onAlbumSelectedCallback(albumName, count, cover)
	end
end

function UIAlbumManager:GetCurrentAlbum()
	return self.currentAlbum
end

function UIAlbumManager:GetFavoriteSongs()
	return self.favoriteSongs
end

function UIAlbumManager:UpdateFavorites(favoriteSongs)
	self.favoriteSongs = favoriteSongs or {}
	self:LoadAlbums(self.favoriteSongs, true)
end

function UIAlbumManager:OnAlbumSelected(callback)
	self.onAlbumSelectedCallback = callback
end

return UIAlbumManager