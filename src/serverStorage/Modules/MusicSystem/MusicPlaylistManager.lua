local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MusicModule = require(ReplicatedStorage.Modules:WaitForChild("MusicModule"))

local MusicPlaylistManager = {}
MusicPlaylistManager.__index = MusicPlaylistManager

function MusicPlaylistManager.new(config)
	local self = setmetatable({}, MusicPlaylistManager)

	self.config = config
	self.playlistIndex = 1
	self.shuffleMode = false
	self.playedSongs = {}
	self.preparedNextSong = nil

	return self
end

function MusicPlaylistManager:GetNextSong()
	local playlist = MusicModule:GetAllMusic()

	if #playlist == 0 then
		warn("Playlist kosong!")
		return nil
	end

	if self.preparedNextSong then
		local song = self.preparedNextSong
		self.preparedNextSong = nil
		self.playedSongs[song.id] = true

		if not self.shuffleMode then
			self.playlistIndex = self.playlistIndex + 1
			if self.playlistIndex > #playlist then
				self.playlistIndex = 1
			end
		end

		return song
	end

	local nextSong

	if self.shuffleMode then
		local availableSongs = {}

		for i, song in ipairs(playlist) do
			if not self.playedSongs[song.id] then
				table.insert(availableSongs, song)
			end
		end

		if #availableSongs == 0 then
			self.playedSongs = {}
			availableSongs = playlist
		end

		local randomIndex = math.random(1, #availableSongs)
		nextSong = availableSongs[randomIndex]

	else
		if self.playlistIndex < 1 or self.playlistIndex > #playlist then
			self.playlistIndex = 1
		end

		nextSong = playlist[self.playlistIndex]

		self.playlistIndex = self.playlistIndex + 1
		if self.playlistIndex > #playlist then
			self.playlistIndex = 1
		end
	end

	if not nextSong and #playlist > 0 then
		nextSong = playlist[1]
		self.playlistIndex = 2
	end

	if nextSong then
		self.playedSongs[nextSong.id] = true
	end

	return nextSong
end

function MusicPlaylistManager:PeekNextSong()
	if self.preparedNextSong then
		return self.preparedNextSong
	end

	local playlist = MusicModule:GetAllMusic()

	if #playlist == 0 then
		return nil
	end

	local nextSong

	if self.shuffleMode then
		local availableSongs = {}

		for i, song in ipairs(playlist) do
			if not self.playedSongs[song.id] then
				table.insert(availableSongs, song)
			end
		end

		if #availableSongs == 0 then
			self.playedSongs = {}
			availableSongs = playlist
		end

		local randomIndex = math.random(1, #availableSongs)
		nextSong = availableSongs[randomIndex]
	else
		nextSong = playlist[self.playlistIndex]
	end

	self.preparedNextSong = nextSong
	return nextSong
end

function MusicPlaylistManager:SetShuffleMode(enabled)
	self.shuffleMode = enabled
	if enabled then
		self.playedSongs = {}
		self.preparedNextSong = nil
	end
end

function MusicPlaylistManager:ResetPlaylist()
	self.playlistIndex = 1
	self.playedSongs = {}
	self.preparedNextSong = nil
end

function MusicPlaylistManager:GetPlaylistSize()
	return #MusicModule:GetAllMusic()
end

return MusicPlaylistManager
