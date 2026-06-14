local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage     = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local TextService       = game:GetService("TextService")

local RemoteEventManager = require(ServerScriptService:WaitForChild("Modules"):WaitForChild("RemoteEventManager"))

-- ====================================
-- MODULES
-- ====================================
local Config             = require(script.Config)
local DebugSystem        = require(script.DebugSystem)
local OverheadManager    = require(script.OverheadManager)
local NametagDisabler    = require(script.NametagDisabler)
local DonaturRankSystem  = require(script.DonaturRankSystem)

local RoleSystem         = require(ServerStorage.Modules.RoleSystem)
local LevelSystem        = require(ServerStorage.Modules.LevelSystem)
local TitleDataManager   = require(script.TitleDataManager)

-- ====================================
-- INITIALIZATION
-- ====================================
DebugSystem:Init(Config.DEBUG_ENABLED)
TitleDataManager:Init(Config)

DonaturRankSystem:Init(Config)

OverheadManager:Init(
	Config,
	RoleSystem,
	LevelSystem,
	TitleDataManager,
	nil, -- Old DonationRankSystem removed
	DonaturRankSystem
)

NametagDisabler:Init()

-- ====================================
-- CHARACTER EVENTS
-- ====================================
local function onCharacterAdded(player, character)
	-- 🔥 FIX MAGIC NUMBER: Tunggu komponen krusial dimuat oleh Roblox dengan Timeout 10 detik
	local head = character:WaitForChild("Head", 10)
	local hrp = character:WaitForChild("HumanoidRootPart", 10)
	local humanoid = character:WaitForChild("Humanoid", 10)
	
	if not head or not hrp or not humanoid then 
		DebugSystem:Warn("Character load timeout for", player.Name)
		return 
	end

	-- Pastikan player masih online dan character masih valid
	if not player or not player.Parent then return end
	if not character or not character.Parent then return end

	NametagDisabler:DisableNametag(player, character)
	OverheadManager:CreateOverhead(player, character)

	-- FIX: Setelah overhead dibuat, force update label team sekali lagi.
	-- Ini safety net untuk kasus di mana player.Team baru settled
	-- setelah CreateOverhead sudah jalan (terutama di Studio dan server penuh).
	-- task.wait(0.5) memberi waktu overhead selesai dibangun sebelum di-update.
	task.spawn(function()
		task.wait(0.5)
		if player and player.Parent and character and character.Parent then
			OverheadManager:UpdateTeam(player)
		end
	end)

	character.AncestryChanged:Connect(function(_, parent)
		if not parent then
			OverheadManager:RemoveOverhead(character)
		end
	end)
end

local function onPlayerAdded(player)
	-- Init level player
	LevelSystem:InitializePlayer(player)
	LevelSystem:SetupCommands(player, RoleSystem)

	-- Preload donatur rank di background agar siap saat overhead dibuat
	task.spawn(function()
		DonaturRankSystem:PreloadRank(player.UserId)
	end)

	if player.Character then
		onCharacterAdded(player, player.Character)
	end

	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)

	-- ====================================
	-- FIX UTAMA: Update overhead label saat team berubah
	--
	-- Masalah sebelumnya: task.wait(0.1) terlalu pendek.
	-- Saat player.Team berubah, Roblox butuh beberapa frame untuk
	-- menyelesaikan assignment secara internal. Jika overhead di-update
	-- terlalu cepat, player.Team mungkin masih nilai lama.
	--
	-- Solusi: task.wait(0.3) + verifikasi ulang player.Team sudah benar
	-- sebelum update label.
	-- ====================================
	player:GetPropertyChangedSignal("Team"):Connect(function()
		task.wait(0.3)
		if player and player.Parent then
			OverheadManager:UpdateTeam(player)
			DebugSystem:Log("Team updated for", player.Name,
				"-> Team:", player.Team and player.Team.Name or "nil")
		end
	end)

	player:GetPropertyChangedSignal("MembershipType"):Connect(function()
		OverheadManager:UpdatePremiumBadge(player)
	end)
end

local function onPlayerRemoving(player)
	NametagDisabler:Cleanup(player)
	OverheadManager:CleanupPlayer(player)
	LevelSystem:CleanupPlayer(player)
	TitleDataManager:ClearCache(player.UserId)
	DonaturRankSystem:ClearCache(player.UserId)
	DebugSystem:Log("Player left:", player.Name)
end

-- ====================================
-- ROLE & LEVEL LISTENERS
-- ====================================
RoleSystem.RoleChanged:Connect(function(player, oldRole, newRole)
	OverheadManager:UpdateRole(player, newRole)
end)

LevelSystem.LevelUp:Connect(function(player, oldLevel, newLevel)
	OverheadManager:UpdateLevel(player, newLevel)
end)

-- Auto donation rank changes now handled by _G.LeaderboardControl checks in OverheadManager

-- ====================================
-- REMOTE EVENTS SETUP
-- ====================================
local titleRemotes = ReplicatedStorage:FindFirstChild("TitleRemotes")
if not titleRemotes then
	titleRemotes        = Instance.new("Folder")
	titleRemotes.Name   = "TitleRemotes"
	titleRemotes.Parent = ReplicatedStorage
end

local function ensureRemoteEvent(name)
	local remote = titleRemotes:FindFirstChild(name)
	if not remote then
		remote        = Instance.new("RemoteEvent")
		remote.Name   = name
		remote.Parent = titleRemotes
	end
	return remote
end

local function ensureRemoteFunction(name)
	local remote = titleRemotes:FindFirstChild(name)
	if not remote then
		remote        = Instance.new("RemoteFunction")
		remote.Name   = name
		remote.Parent = titleRemotes
	end
	return remote
end

local updateTitleRemote   = ensureRemoteEvent("UpdateTitle")
local assignDonaturRemote = ensureRemoteEvent("AssignDonaturRank")
local checkAccessRemote   = ensureRemoteFunction("CheckAccess")
local getPlayerDataRemote = ensureRemoteFunction("GetPlayerData")

-- ====================================
-- CHECK ACCESS
-- ====================================
checkAccessRemote.OnServerInvoke = function(sender)
	if not sender then return false end
	local role = RoleSystem:GetPlayerRole(sender)
	return role == "Owner" or role == "Admin"
end

-- ====================================
-- GET PLAYER DATA
-- ====================================
getPlayerDataRemote.OnServerInvoke = function(sender, targetPlayer)
	if not sender then return nil end

	local senderRole = RoleSystem:GetPlayerRole(sender)
	if senderRole ~= "Owner" and senderRole ~= "Admin" then
		DebugSystem:Warn("GetPlayerData: Access denied for", sender.Name)
		return nil
	end

	if not targetPlayer then return nil end

	local titleData   = TitleDataManager:LoadTitleData(targetPlayer.UserId)
	local donaturRank = DonaturRankSystem:GetRank(targetPlayer.UserId)

	local colorData = nil
	if titleData and titleData.Color then
		colorData = {
			R = math.floor(titleData.Color.R * 255),
			G = math.floor(titleData.Color.G * 255),
			B = math.floor(titleData.Color.B * 255),
		}
	end

	DebugSystem:Log("GetPlayerData for", targetPlayer.Name,
		"- Title:", titleData and titleData.Title or "none",
		"- DonaturRank:", donaturRank or "none"
	)

	return {
		Title           = titleData and titleData.Title or "",
		Color           = colorData or { R = 255, G = 255, B = 255 },
		GradientEnabled = titleData and titleData.GradientEnabled or false,
		GradientEffect  = titleData and titleData.GradientEffect or "wave",
		DonaturRank     = donaturRank,
	}
end

-- ====================================
-- UPDATE TITLE REMOTE
-- ====================================
updateTitleRemote.OnServerEvent:Connect(function(sender, targetPlayer, titleData)
	-- 🔥 ARCHITECT FIX: Rate Limiting
	if not RemoteEventManager.checkRateLimit(sender, "updateTitle") then return end

	DebugSystem:Log("UpdateTitle Request from", sender and sender.Name or "nil")

	if not sender or not targetPlayer or not titleData then
		DebugSystem:Warn("UpdateTitle: Invalid parameters")
		return
	end

	local senderRole = RoleSystem:GetPlayerRole(sender)
	if senderRole ~= "Owner" and senderRole ~= "Admin" then
		DebugSystem:Warn("UpdateTitle: Access denied for", sender.Name)
		return
	end

	if type(titleData) ~= "table" then return end

	-- 🔥 SECURITY FIX: Dekonstruksi & Validasi ketat (Table Injection Protection)
	local rawTitle = titleData.Title
	if type(rawTitle) ~= "string" then rawTitle = "" end
	rawTitle = string.sub(rawTitle, 1, 50) -- Batasi panjang string

	local rawColor = titleData.Color
	if typeof(rawColor) ~= "Color3" then rawColor = Color3.fromRGB(255, 255, 255) end

	local isGradient = titleData.Gradient or titleData.GradientEnabled
	if type(isGradient) ~= "boolean" then isGradient = false end

	local gradEffect = titleData.GradientEffect
	if type(gradEffect) ~= "string" then gradEffect = "wave" end

	if rawTitle == "" then
		TitleDataManager:UpdateCache(targetPlayer.UserId, {
			Title = "", Color = Color3.fromRGB(255, 255, 255),
			GradientEnabled = false, GradientEffect = "wave",
		})
		DebugSystem:Log("Title removed for", targetPlayer.Name)
	else
		-- 🔥 COMPLIANCE FIX: Roblox Text Filtering (Bypass Mencegah Ban)
		local filteredTitle = rawTitle
		pcall(function()
			local filterResult = TextService:FilterStringAsync(rawTitle, sender.UserId)
			filteredTitle = filterResult:GetNonChatStringForBroadcastAsync()
		end)

		TitleDataManager:UpdateCache(targetPlayer.UserId, {
			Title           = filteredTitle,
			Color           = rawColor,
			GradientEnabled = isGradient,
			GradientEffect  = gradEffect,
		})
		DebugSystem:Log("Title updated for", targetPlayer.Name, "->", filteredTitle)
	end

	-- FIX: Rebuild overhead hanya jika character valid
	if targetPlayer.Character and targetPlayer.Character.Parent then
		OverheadManager:CreateOverhead(targetPlayer, targetPlayer.Character)
	end
end)

-- ====================================
-- ASSIGN DONATUR RANK REMOTE
-- ====================================
assignDonaturRemote.OnServerEvent:Connect(function(sender, targetPlayer, rank)
	-- 🔥 ARCHITECT FIX: Rate Limiting
	if not RemoteEventManager.checkRateLimit(sender, "assignDonatur") then return end

	DebugSystem:Log("AssignDonaturRank Request from", sender and sender.Name or "nil")

	if not sender or not targetPlayer then
		DebugSystem:Warn("AssignDonaturRank: Invalid parameters")
		return
	end

	local senderRole = RoleSystem:GetPlayerRole(sender)
	if senderRole ~= "Owner" and senderRole ~= "Admin" then
		DebugSystem:Warn("AssignDonaturRank: Access denied for", sender.Name)
		return
	end

	local validRank = nil
	if type(rank) == "number" and rank >= 1 and rank <= 10 then
		validRank = math.floor(rank)
	end

	local success = DonaturRankSystem:AssignRank(targetPlayer.UserId, validRank)

	if success then
		if targetPlayer.Character and targetPlayer.Character.Parent then
			OverheadManager:UpdateDonaturRank(targetPlayer)
		end
		DebugSystem:Log("Donatur rank", validRank or "removed", "for", targetPlayer.Name)
	else
		DebugSystem:Warn("Failed to assign donatur rank for", targetPlayer.Name)
	end
end)

-- ====================================
-- PLAYER INITIALIZATION
-- ====================================
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(function(player)
	-- Gunakan pcall & pengecekan agar jika modul tidak punya fitur cleanup, server tidak error merah
	pcall(function()
		if OverheadManager and OverheadManager.CleanupPlayer then
			OverheadManager:CleanupPlayer(player)
		end

		if TitleDataManager and TitleDataManager.CleanupPlayer then
			TitleDataManager:CleanupPlayer(player)
		end
	end)
end)