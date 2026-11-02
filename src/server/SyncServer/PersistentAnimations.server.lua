local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ServerStorage = game:GetService("ServerStorage")
local DataStoreEnv = require(ServerStorage:WaitForChild("Modules"):WaitForChild("DataStoreEnv"))

local favoritedAnimationsStore, favoritedAnimationsWriteStore = DataStoreEnv.Get("FavoritedAnimations")
local replicatedStorage = game:GetService("ReplicatedStorage")
local Events = replicatedStorage:WaitForChild("Remotes")
local updateFavoritedAnimationsEvent = Events:WaitForChild("updateFavoritedAnimationsEvent")

-- ============================================
-- HELPER: set/get data StringValue
-- ============================================
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
-- DIRTY TRACKING & ACTIVE SAVES LOCK (ANTI-RACE CONDITION KELUAR-MASUK)
-- ============================================
local isDirty = {}
local activeSaves = {}

local function savePlayerData(player, snapshotData)
	local userId = player.UserId
	if not isDirty[userId] then return end

	local savedData = snapshotData or getSavedData(player)
	if not savedData then return end

	activeSaves[userId] = true
	local success = false
	local errorMessage = nil

	for attempt = 1, 3 do
		success, errorMessage = pcall(function()
			favoritedAnimationsWriteStore:UpdateAsync("Player_" .. userId, function()
				return savedData
			end)
		end)
		if success then break end
		if attempt < 3 then task.wait(1) end
	end

	activeSaves[userId] = nil
	if success then
		isDirty[userId] = nil
	else
		-- Keep dirty so BindToClose / another save attempt can retry.
		warn("[PersistentAnimations] Gagal save data untuk", player.Name, ":", errorMessage)
	end
end

-- ============================================
-- PLAYER ADDED: Staggered Load agar 100 pemain masuk barengan tidak membebani DataStore detik ke-0
-- ============================================
Players.PlayerAdded:Connect(function(player)
	-- Beri jeda acak 2-6 detik agar kuota detik pertama fokus ke Role & Level
	task.wait(math.random(20, 60) / 10)
	if not player:IsDescendantOf(Players) then return end

	-- Tunggu jika sesi sebelumnya masih menyimpan (keluar-masuk cepat)
	local waited = 0
	while activeSaves[player.UserId] and waited < 10 do
		waited += task.wait(0.1)
	end
	if not player:IsDescendantOf(Players) then return end

	local success, savedData = pcall(function()
		return favoritedAnimationsStore:GetAsync("Player_" .. player.UserId)
	end)

	if not player:IsDescendantOf(Players) then return end

	-- Jangan timpa jika pemain sudah keburu klik favorit baru sebelum GetAsync selesai
	if isDirty[player.UserId] then return end

	if success and type(savedData) == "string" then
		local ok, decodedData = pcall(function()
			return HttpService:JSONDecode(savedData)
		end)
		if ok and type(decodedData) == "table" then
			setSavedData(player, savedData)
		else
			warn("[PersistentAnimations] Data korup untuk", player.Name, "- reset ke kosong")
			setSavedData(player, "[]")
		end
	else
		if not success then
			warn("[PersistentAnimations] GetAsync gagal untuk", player.Name, ":", savedData)
		end
		setSavedData(player, "[]")
	end
end)

-- ============================================
-- PLAYER REMOVING: Save data ke DataStore
-- ============================================
local lastUpdate = {}

Players.PlayerRemoving:Connect(function(player)
	lastUpdate[player] = nil
	local snapshot = getSavedData(player)
	savePlayerData(player, snapshot)
end)

-- ============================================
-- BindToClose sebagai backup saat Server Shutdown
-- ============================================
game:BindToClose(function()
	local playerList = Players:GetPlayers()
	local totalPlayers = #playerList
	local completed = 0

	for i, player in ipairs(playerList) do
		task.spawn(function()
			savePlayerData(player, getSavedData(player))
			completed += 1
		end)
		
		if i % 10 == 0 then
			task.wait(0.2)
		end
	end

	local elapsed = 0
	while completed < totalPlayers and elapsed < 15 do
		task.wait(1)
		elapsed += 1
	end
end)

-- ============================================
-- UPDATE FAVORITES dari client
-- ============================================
updateFavoritedAnimationsEvent.OnServerEvent:Connect(function(player, jsonData)
	local now = os.clock()
	if lastUpdate[player] and (now - lastUpdate[player]) < 2 then
		return
	end
	lastUpdate[player] = now

	if type(jsonData) ~= "string" then return end
	if string.len(jsonData) > 10000 then
		warn("[Security] " .. player.Name .. " mencoba mengirim data animasi terlalu besar!")
		return 
	end

	local success, decodedData = pcall(function()
		return HttpService:JSONDecode(jsonData)
	end)

	if success and type(decodedData) == "table" then
		setSavedData(player, jsonData)
		isDirty[player.UserId] = true
	else
		warn("[PersistentAnimations] Data JSON tidak valid dari", player.Name)
	end
end)
