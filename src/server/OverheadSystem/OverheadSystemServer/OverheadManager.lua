local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService       = game:GetService("HttpService")

local OverheadManager = {}

-- ====================================
-- PENGATURAN DEBUG (ANTI-SPAM LOG)
-- ====================================
local DEBUG_ENABLED = false

local function debugLog(...)
	if DEBUG_ENABLED then
		print("[DEBUG OVERHEAD SERVER]", ...)
	end
end

local function debugWarn(...)
	if DEBUG_ENABLED then
		warn("[DEBUG OVERHEAD SERVER]", ...)
	end
end

-- Module references (diisi via Init)
local CONFIG              = nil
local RoleSystem          = nil
local LevelSystem         = nil
local DonationRankSystem  = nil
local DonaturRankSystem   = nil
local TitleDataManager    = nil
local DebugSystem         = nil

-- ====================================
-- INIT
-- ====================================
function OverheadManager:Init(config, roleSystem, levelSystem, titleDataManager, donationRankSystem, donaturRankSystem)
	CONFIG             = config
	RoleSystem         = roleSystem
	LevelSystem        = levelSystem
	DonationRankSystem = donationRankSystem
	DonaturRankSystem  = donaturRankSystem
	TitleDataManager   = titleDataManager
	DebugSystem        = require(script.Parent.DebugSystem)
end

-- ====================================
-- FUNGSI GET SAWERIA
-- ====================================
local function getSaweriaRank(player)
	local ServerStorage = game:GetService("ServerStorage")
	local func = ServerStorage:FindFirstChild("GetTopSaweriaFunc")

	if not func then return nil end

	local success, topList = pcall(function() return func:Invoke() end)
	if success and type(topList) == "table" then
		for rank, donor in ipairs(topList) do
			local dName = string.lower(donor.name)
			local pName = string.lower(player.Name)
			local pDisplay = string.lower(player.DisplayName)

			if dName == pName or dName == pDisplay then
				return rank
			end
		end
	end
	return nil
end

-- ====================================
-- UPDATE ATTRIBUTES
-- ====================================

-- Memperbarui semua Atribut data Overhead ke Player agar Client (LocalScript) bisa membacanya
function OverheadManager:UpdateAllAttributes(player)
	if not player then return end

	-- 1. Role
	local role = RoleSystem and RoleSystem:GetPlayerRole(player) or "Player"
	player:SetAttribute("Overhead_Role", role)
	
	-- 2. Level
	if LevelSystem then
		local level = LevelSystem:GetPlayerLevel(player) or 1
		player:SetAttribute("Overhead_Level", level)
	end

	-- 3. Title Data
	if TitleDataManager then
		local titleData = TitleDataManager:LoadTitleData(player.UserId)
		if titleData then
			player:SetAttribute("Overhead_TitleText", titleData.Title or "")
			if titleData.Color then
				player:SetAttribute("Overhead_TitleColorR", titleData.Color.R)
				player:SetAttribute("Overhead_TitleColorG", titleData.Color.G)
				player:SetAttribute("Overhead_TitleColorB", titleData.Color.B)
			else
				player:SetAttribute("Overhead_TitleColorR", 1)
				player:SetAttribute("Overhead_TitleColorG", 1)
				player:SetAttribute("Overhead_TitleColorB", 1)
			end
			player:SetAttribute("Overhead_TitleGradient", titleData.GradientEnabled or false)
			player:SetAttribute("Overhead_TitleEffect", titleData.GradientEffect or "wave")
		else
			player:SetAttribute("Overhead_TitleText", "")
		end
	end

	-- 4. Saweria Rank
	local saweriaRank = getSaweriaRank(player)
	if saweriaRank then
		player:SetAttribute("Overhead_SaweriaRank", saweriaRank)
	else
		player:SetAttribute("Overhead_SaweriaRank", 0) -- 0 artinya tidak masuk rank
	end

	-- 5. Robux Rank (LeaderboardControl)
	local robuxRank = 0
	if _G.LeaderboardControl then
		local success, topDonors = pcall(function() return _G.LeaderboardControl.GetData() end)
		if success and type(topDonors) == "table" then
			for _, donor in ipairs(topDonors) do
				if donor.UserId == player.UserId then
					robuxRank = donor.Rank
					break
				end
			end
		end
	end
	player:SetAttribute("Overhead_RobuxRank", robuxRank)

	-- 6. Likes Rank
	local likesRank = 0
	if _G.LikesLeaderboardData then
		local success, topLikes = pcall(function() return _G.LikesLeaderboardData end)
		if success and type(topLikes) == "table" then
			for _, donor in ipairs(topLikes) do
				if donor.UserId == player.UserId then
					likesRank = donor.Rank
					break
				end
			end
		end
	end
	player:SetAttribute("Overhead_LikesRank", likesRank)
	
	-- 7. Donatur Rank (Manual Admin)
	if DonaturRankSystem then
		local donaturRank = DonaturRankSystem:GetRank(player.UserId)
		player:SetAttribute("Overhead_DonaturRank", donaturRank or 0)
	end
end

-- ====================================
-- EXPOSED UPDATE METHODS FOR INIT.SERVER.LUA
-- ====================================

function OverheadManager:CreateOverhead(player, character)
	-- Dulu ini nge-clone UI ke karakter. Sekarang hanya pastikan Attributes up-to-date.
	self:UpdateAllAttributes(player)
end

function OverheadManager:RemoveOverhead(character)
	-- Tidak perlu melakukan apa-apa di Server, karena LocalScript yang me-manage UI.
end

function OverheadManager:UpdatePremiumBadge(player)
	-- Premium badge logic akan ditangani oleh LocalScript, Server cukup trigger pembaruan data
	self:UpdateAllAttributes(player)
end

function OverheadManager:UpdateRole(player, newRole)
	player:SetAttribute("Overhead_Role", newRole)
end

function OverheadManager:UpdateTeam(player)
	-- Trigger ke client untuk cek ulang tim (karena Team sudah ada propertinya sendiri)
	-- LocalScript akan membaca player.Team
	player:SetAttribute("Overhead_TeamUpdate", tick()) -- Memaksa event fired
end

function OverheadManager:UpdateLevel(player, newLevel)
	player:SetAttribute("Overhead_Level", newLevel)
end

function OverheadManager:UpdateDonationRank(player, oldRank, newRank)
	self:UpdateAllAttributes(player)
end

function OverheadManager:UpdateDonaturRank(player)
	self:UpdateAllAttributes(player)
end

function OverheadManager:CleanupPlayer(player)
	-- Tidak ada tabel activeOverheads lagi, karena tidak nge-spawn GUI di server
end

return OverheadManager