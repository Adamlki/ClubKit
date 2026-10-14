local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService       = game:GetService("HttpService")
local LocalizationService = game:GetService("LocalizationService")

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
local DonaturRankSystem   = nil
local TitleDataManager    = nil
local DebugSystem         = nil

-- ====================================
-- 100-PLAYER OPTIMIZATION: DIRTY-CHECK & SHORT CACHE
-- ====================================
local function safeSetAttr(player, key, value)
	if player and player.Parent and player:GetAttribute(key) ~= value then
		player:SetAttribute(key, value)
	end
end

local cachedSaweriaTop = nil
local lastSaweriaFetch = 0
local cachedRobuxTop = nil
local lastRobuxFetch = 0
local RANK_CACHE_TTL = 2 -- Detik (mencegah 100x Invoke beruntun saat refresh massal)

local function getTopSaweriaList()
	local now = os.clock()
	if cachedSaweriaTop and (now - lastSaweriaFetch) < RANK_CACHE_TTL then
		return cachedSaweriaTop
	end
	local ServerStorage = game:GetService("ServerStorage")
	local func = ServerStorage:FindFirstChild("GetTopSaweriaFunc")
	if not func then return nil end

	local success, topList = pcall(function() return func:Invoke() end)
	if success and type(topList) == "table" then
		cachedSaweriaTop = topList
		lastSaweriaFetch = now
		return topList
	end
	return cachedSaweriaTop
end

local function getTopRobuxList()
	local now = os.clock()
	if cachedRobuxTop and (now - lastRobuxFetch) < RANK_CACHE_TTL then
		return cachedRobuxTop
	end
	if _G.LeaderboardControl then
		local success, topDonors = pcall(function() return _G.LeaderboardControl.GetData() end)
		if success and type(topDonors) == "table" then
			cachedRobuxTop = topDonors
			lastRobuxFetch = now
			return topDonors
		end
	end
	return cachedRobuxTop
end

-- ====================================
-- INIT
-- ====================================
function OverheadManager:Init(config, roleSystem, levelSystem, titleDataManager, donaturRankSystem)
	CONFIG             = config
	RoleSystem         = roleSystem
	LevelSystem        = levelSystem
	DonaturRankSystem  = donaturRankSystem
	TitleDataManager   = titleDataManager
	DebugSystem        = require(script.Parent.DebugSystem)
end

-- ====================================
-- FUNGSI GET SAWERIA
-- ====================================
local function getSaweriaRank(player)
	local topList = getTopSaweriaList()
	if type(topList) == "table" then
		local pName = string.lower(player.Name)
		for rank, donor in ipairs(topList) do
			local dName = string.lower(tostring(donor.name or ""))
			-- KEAMANAN: Cocokkan hanya dengan Username unik (player.Name), bukan DisplayName
			if dName == pName then
				return rank
			end
		end
	end
	return nil
end

-- ====================================
-- UPDATE ATTRIBUTES
-- ====================================
function OverheadManager:UpdateAllAttributes(player)
	if not player or not player.Parent then return end

	-- 1. Role
	local role = RoleSystem and RoleSystem:GetPlayerRole(player) or "Player"
	safeSetAttr(player, "Overhead_Role", role)

	-- 2. Level
	if LevelSystem then
		local level = LevelSystem:GetPlayerLevel(player) or 1
		safeSetAttr(player, "Overhead_Level", level)
	end

	-- 3. Title Data
	if TitleDataManager then
		local titleData = TitleDataManager:LoadTitleData(player.UserId)
		if titleData then
			safeSetAttr(player, "Overhead_TitleText", titleData.Title or "")
			if titleData.Color then
				safeSetAttr(player, "Overhead_TitleColorR", titleData.Color.R)
				safeSetAttr(player, "Overhead_TitleColorG", titleData.Color.G)
				safeSetAttr(player, "Overhead_TitleColorB", titleData.Color.B)
			else
				safeSetAttr(player, "Overhead_TitleColorR", 1)
				safeSetAttr(player, "Overhead_TitleColorG", 1)
				safeSetAttr(player, "Overhead_TitleColorB", 1)
			end
			safeSetAttr(player, "Overhead_TitleGradient", titleData.GradientEnabled or false)
			safeSetAttr(player, "Overhead_TitleEffect", titleData.GradientEffect or "wave")
		else
			safeSetAttr(player, "Overhead_TitleText", "")
		end
	end

	-- 4. Saweria Rank
	local saweriaRank = getSaweriaRank(player) or 0
	safeSetAttr(player, "Overhead_SaweriaRank", saweriaRank)

	-- 5. Robux Rank (LeaderboardControl)
	local robuxRank = 0
	local topDonors = getTopRobuxList()
	if type(topDonors) == "table" then
		for _, donor in ipairs(topDonors) do
			if donor.UserId == player.UserId then
				robuxRank = donor.Rank
				break
			end
		end
	end
	safeSetAttr(player, "Overhead_RobuxRank", robuxRank)

	-- 6. Likes Rank
	local likesRank = 0
	local topLikes = _G.LikesLeaderboardData
	if type(topLikes) == "table" then
		for _, donor in ipairs(topLikes) do
			if donor.UserId == player.UserId then
				likesRank = donor.Rank
				break
			end
		end
	end
	safeSetAttr(player, "Overhead_LikesRank", likesRank)

	-- 7. Donatur Rank (Manual Admin)
	if DonaturRankSystem then
		local donaturRank = DonaturRankSystem:GetRank(player.UserId)
		safeSetAttr(player, "Overhead_DonaturRank", donaturRank or 0)
	end

	-- 8. Country Code (Regional Detection)
	if not player:GetAttribute("Overhead_CountryCode") then
		task.spawn(function()
			local ok, code = pcall(function()
				return LocalizationService:GetCountryRegionForPlayerAsync(player)
			end)
			if ok and type(code) == "string" and #code == 2 then
				safeSetAttr(player, "Overhead_CountryCode", string.upper(code))
			else
				safeSetAttr(player, "Overhead_CountryCode", "ID")
			end
		end)
	end

	-- 9. VIP Status Check (Baca dari cache RoleSystem tanpa memicu ulang Marketplace call berat)
	local hasVIP = false
	if RoleSystem then
		if role == "VIP" then
			hasVIP = true
		elseif RoleSystem.GetPlayerOwnership then
			local ownership = RoleSystem:GetPlayerOwnership(player)
			if ownership and (ownership.VIP == true or ownership.GivenPass == "VIP") then
				hasVIP = true
			end
		end
	end
	safeSetAttr(player, "Overhead_HasVIP", hasVIP)
end

-- ====================================
-- EXPOSED UPDATE METHODS FOR INIT.SERVER.LUA
-- ====================================
function OverheadManager:CreateOverhead(player, character)
	self:UpdateAllAttributes(player)
end

function OverheadManager:RemoveOverhead(character)
end

function OverheadManager:UpdatePremiumBadge(player)
	self:UpdateAllAttributes(player)
end

function OverheadManager:UpdateRole(player, newRole)
	safeSetAttr(player, "Overhead_Role", newRole)
end

function OverheadManager:UpdateTeam(player)
	safeSetAttr(player, "Overhead_TeamUpdate", math.floor(os.clock() * 100))
end

function OverheadManager:UpdateLevel(player, newLevel)
	safeSetAttr(player, "Overhead_Level", newLevel)
end

function OverheadManager:UpdateDonationRank(player, oldRank, newRank)
	self:UpdateAllAttributes(player)
end

function OverheadManager:UpdateDonaturRank(player)
	self:UpdateAllAttributes(player)
end

function OverheadManager:CleanupPlayer(player)
end

return OverheadManager