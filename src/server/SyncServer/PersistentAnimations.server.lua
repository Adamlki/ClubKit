local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local favoritedAnimationsStore = DataStoreService:GetDataStore("FavoritedAnimations")
local replicatedStorage = game:GetService("ReplicatedStorage")
local Events = replicatedStorage:WaitForChild("Remotes")
local updateFavoritedAnimationsEvent = Events:WaitForChild("updateFavoritedAnimationsEvent")

-- ============================================
-- HELPER: set/get data StringValue
local function getSavedData(player)
	local stringVal = player:FindFirstChild("SavedFavoritedAnimations")
	return stringVal and stringVal.Value or nil
end

local function setSavedData(player, data)
	local stringVal = player:FindFirstChild("SavedFavoritedAnimations")
	if not stringVal then
		stringVal = Instance.new("StringValue")
		stringVal.Name = "SavedFavoritedAnimations"
		stringVal.Parent = player
	end
	stringVal.Value = data
end

-- ============================================
-- HELPER: Save data player ke DataStore
-- ============================================
local function savePlayerData(player)
	local savedData = getSavedData(player)
	if savedData then
		local success, errorMessage = pcall(function()
			favoritedAnimationsStore:SetAsync("Player_" .. player.UserId, savedData)
		end)
		if not success then
			warn("[PersistentAnimations] Gagal save data untuk", player.Name, ":", errorMessage)
		end
	end
end

-- ============================================
-- PLAYER ADDED: Load data dari DataStore
-- Setelah selesai, set attribute agar client bisa baca
-- ============================================
Players.PlayerAdded:Connect(function(player)
	local success, savedData = pcall(function()
		return favoritedAnimationsStore:GetAsync("Player_" .. player.UserId)
	end)

	if success and type(savedData) == "string" then
		local ok, decodedData = pcall(function()
			return HttpService:JSONDecode(savedData)
		end)
		if ok and type(decodedData) == "table" then
			-- FIX: Set data SETELAH data berhasil di-decode
			-- Client akan menunggu StringValue ini sebelum membaca favorites
			setSavedData(player, savedData)
		else
			warn("[PersistentAnimations] Data korup untuk", player.Name, "- reset ke kosong")
			-- Set data kosong agar client tidak menunggu selamanya
			setSavedData(player, "[]")
		end
	else
		if not success then
			warn("[PersistentAnimations] GetAsync gagal untuk", player.Name, ":", savedData)
		end
		-- FIX: Tetap set data meski tidak ada data, agar client tidak stuck menunggu
		setSavedData(player, "[]")
	end
end)

-- ============================================
-- PLAYER REMOVING: Save data ke DataStore
-- ============================================
Players.PlayerRemoving:Connect(function(player)
	savePlayerData(player)
end)

-- ============================================
-- FIX BUG #3: BindToClose sebagai backup
-- Memastikan data tersimpan saat server shutdown / map change
-- PlayerRemoving saja tidak reliable di situasi ini
-- ============================================
game:BindToClose(function()
	local playerList = Players:GetPlayers()
	local totalPlayers = #playerList
	local completed = 0

	for _, player in ipairs(playerList) do
		task.spawn(function()
			savePlayerData(player)
			completed += 1
		end)
	end

	-- Tunggu semua task selesai (max 10 detik)
	local elapsed = 0
	while completed < totalPlayers and elapsed < 10 do
		task.wait(0.1)
		elapsed += 0.1
	end
end)

-- ============================================
-- UPDATE FAVORITES dari client
-- ============================================
updateFavoritedAnimationsEvent.OnServerEvent:Connect(function(player, jsonData)
	local success, decodedData = pcall(function()
		return HttpService:JSONDecode(jsonData)
	end)

	if success and type(decodedData) == "table" then
		setSavedData(player, jsonData)
	else
		warn("[PersistentAnimations] Data JSON tidak valid dari", player.Name)
	end
end)
