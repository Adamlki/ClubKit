-- ====================================
-- RANK ITEM GIVER SYSTEM (SERVER-GRADE OPTIMIZED)
-- Opsi A: Event-Driven (Tanpa Loop, Bebas Lag)
-- Place in ServerScriptService
-- ====================================

local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")

-- ====================================
-- LOAD ROLE SYSTEM MODULE
-- ====================================
local RoleSystem = require(ServerStorage.Modules.RoleSystem)

-- ====================================
-- CONFIGURATION
-- ====================================
local Config = {
	-- Debug mode (set false untuk disable semua debug message)
	DebugMode = false,

	-- Daftar item berdasarkan rank
	RankItems = {
		{
			Name = "AFK",
			Path = ServerStorage.Items.AFK,
			MinimumHierarchy = 2 -- VIP ke atas
		},
		{
			Name = "Glowstick",
			Path = ServerStorage.Items.Glowstick,
			MinimumHierarchy = 2 -- VIP ke atas
		},
		{
			Name = "Sharky",
			Path = ServerStorage.Items.Sharky,
			MinimumHierarchy = 3 -- VIP ke atas
		},
		{
			Name = "WaterGun",
			Path = ServerStorage.Items.WaterGun,
			MinimumHierarchy = 3 -- VVIP ke atas
		},
		{
			Name = "Heart",
			Path = ServerStorage.Items.Heart,
			MinimumHierarchy = 2 -- VIP ke atas
		},
		{
			Name = "Mawar",
			Path = ServerStorage.Items.Mawar,
			MinimumHierarchy = 2 -- VIP ke atas
		},
		{
			Name = "Megaphone",
			Path = ServerStorage.Items.Megaphone,
			MinimumHierarchy = 3 -- VIP ke atas
		},
	}
}

-- ====================================
-- UTILITY FUNCTIONS
-- ====================================

local function debugPrint(...)
	if Config.DebugMode then
		print("[ItemGiver]", ...)
	end
end

-- Mengecek apakah player memiliki rank minimum
local function hasMinimumRank(player, minimumHierarchy)
	local playerRole = RoleSystem:GetPlayerRole(player)
	local playerHierarchy = RoleSystem.Config.RoleHierarchy[playerRole] or 0
	return playerHierarchy >= minimumHierarchy
end

-- Membersihkan SEMUA item ganda/duplikat dari Backpack & Tangan pemain
local function cleanAllDuplicates(player, itemName)
	local removed = 0

	-- Hapus dari backpack
	if player.Backpack then
		for _, item in ipairs(player.Backpack:GetChildren()) do
			if item.Name == itemName and item:IsA("Tool") then
				item:Destroy()
				removed = removed + 1
			end
		end
	end

	-- Hapus dari character (tangan / sedang di-equip)
	if player.Character then
		for _, item in ipairs(player.Character:GetChildren()) do
			if item.Name == itemName and item:IsA("Tool") then
				item:Destroy()
				removed = removed + 1
			end
		end
	end

	if removed > 0 then
		debugPrint(string.format("Cleaned %d duplicate(s) of %s from %s", removed, itemName, player.Name))
	end
end

-- Fungsi utama memberikan item ke player (DIJAMIN TIDAK GANDA)
local function giveItemToPlayer(player, itemConfig)
	if not player or not player.Backpack then return end
	if not itemConfig.Path or not itemConfig.Path.Parent then return end

	-- 1. MUSNAHKAN SEMUA ITEM LAMA TERLEBIH DAHULU (Anti-Ganda)
	cleanAllDuplicates(player, itemConfig.Name)

	-- 2. BERIKAN 1 ITEM BARU
	local itemClone = itemConfig.Path:Clone()
	itemClone.Parent = player.Backpack

	debugPrint(string.format("Gave %s to %s (Rank: %s)", itemConfig.Name, player.Name, RoleSystem:GetPlayerRole(player)))
end

-- Mengecek dan membagikan semua item sesuai hak pemain
local function checkAndGiveItems(player)
	if not player or not player.Parent then return end

	for _, itemConfig in ipairs(Config.RankItems) do
		if hasMinimumRank(player, itemConfig.MinimumHierarchy) then
			-- Jika rank cukup, berikan itemnya
			giveItemToPlayer(player, itemConfig)
		else
			-- Jika rank tidak cukup (misal VIPnya dicabut), tarik/musnahkan itemnya
			cleanAllDuplicates(player, itemConfig.Name)
		end
	end
end

-- ====================================
-- PLAYER MANAGEMENT
-- ====================================

local function onPlayerAdded(player)
	-- Initialize role
	RoleSystem:InitializePlayer(player)

	-- Setiap kali pemain Spawn / Respawn / Mati lalu hidup lagi
	player.CharacterAdded:Connect(function(character)
		-- WAJIB: Tunggu sampai Roblox selesai meload penampilan asli (baju, dll)
		if not player:HasAppearanceLoaded() then
			player.CharacterAppearanceLoaded:Wait()
		end
		
		-- Beri jeda sedikit tambahan agar Backpack & UI selesai loading sepenuhnya
		task.wait(0.5) 
		checkAndGiveItems(player)
	end)
end

-- ====================================
-- ROLE CHANGE HANDLER
-- ====================================

-- Jika pemain tiba-tiba beli role / diubah rolenya oleh Admin di tengah permainan
RoleSystem.RoleChanged:Connect(function(player, oldRole, newRole)
	debugPrint(string.format("Role changed: %s (%s -> %s)", player.Name, oldRole, newRole))

	task.spawn(function()
		task.wait(0.5)
		checkAndGiveItems(player)
	end)
end)

-- ====================================
-- INITIALIZATION
-- ====================================

-- Daftarkan pemain yang baru masuk
Players.PlayerAdded:Connect(onPlayerAdded)

-- Jika script ini baru di-save/update saat game sedang berjalan (Testing di Studio)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(function()
		onPlayerAdded(player)
		-- Paksa berikan item jika karakter pemain sudah terlanjur spawn
		if player.Character then
			task.spawn(function()
				task.wait(0.5)
				checkAndGiveItems(player)
			end)
		end
	end)
end

debugPrint("Rank Item Giver System (Option A) initialized successfully!")