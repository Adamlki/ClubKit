local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local favoritedAnimationsStore = DataStoreService:GetDataStore("FavoritedAnimations")
local replicatedStorage = game:GetService("ReplicatedStorage")
local Events = replicatedStorage:WaitForChild("Remotes")
local updateFavoritedAnimationsEvent = Events:WaitForChild("updateFavoritedAnimationsEvent")

-- ============================================
-- HELPER: Save data player ke DataStore
-- ============================================
local function savePlayerData(player)
	local savedData = player:GetAttribute("SavedFavoritedAnimations")
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
			-- FIX: Set attribute SETELAH data berhasil di-decode
			-- Client akan menunggu attribute ini sebelum membaca favorites
			player:SetAttribute("SavedFavoritedAnimations", savedData)
		else
			warn("[PersistentAnimations] Data korup untuk", player.Name, "- reset ke kosong")
			-- Set attribute kosong agar client tidak menunggu selamanya
			player:SetAttribute("SavedFavoritedAnimations", "[]")
		end
	else
		if not success then
			warn("[PersistentAnimations] GetAsync gagal untuk", player.Name, ":", savedData)
		end
		-- FIX: Tetap set attribute meski tidak ada data, agar client tidak stuck menunggu
		player:SetAttribute("SavedFavoritedAnimations", "[]")
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
	local saveTasks = {}
	for _, player in ipairs(Players:GetPlayers()) do
		table.insert(saveTasks, task.spawn(function()
			savePlayerData(player)
		end))
	end
	-- Tunggu semua task selesai (max 10 detik)
	local elapsed = 0
	while elapsed < 10 do
		local allDone = true
		for _, t in ipairs(saveTasks) do
			if coroutine.status(t) ~= "dead" then
				allDone = false
				break
			end
		end
		if allDone then break end
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
		player:SetAttribute("SavedFavoritedAnimations", jsonData)
	else
		warn("[PersistentAnimations] Data JSON tidak valid dari", player.Name)
	end
end)
