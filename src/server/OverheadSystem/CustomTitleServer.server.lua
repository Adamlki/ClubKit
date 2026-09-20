-- ============================================================
-- CUSTOM TITLE SERVER (PLAYER SELF-CUSTOMIZATION)
-- ============================================================
-- Allows any player to customize their overhead title with
-- text, colors, and gradient effects.
-- Features:
--   - 3x chance quota per player (DataStore saved)
--   - 5-second live preview ("Cek Dulu") without consuming quota
--   - TextService filtering for Roblox safety compliance
--   - Real-time overhead updates
-- ============================================================

local Players           = game:GetService("Players")
local DataStoreService  = game:GetService("DataStoreService")
local TextService       = game:GetService("TextService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage     = game:GetService("ServerStorage")
local RunService        = game:GetService("RunService")

-- Module references
local TitleDataManager = require(script.Parent.OverheadSystemServer.TitleDataManager)
local OverheadManager  = require(script.Parent.OverheadSystemServer.OverheadManager)

local LevelSystem = nil
pcall(function()
	LevelSystem = require(ServerStorage.Modules.LevelSystem)
end)

-- ====================================
-- CONFIGURATION
-- ====================================
local CONFIG = {
	MAX_CHANCES                = 3,
	MAX_TITLE_LENGTH           = 50,
	PREVIEW_DURATION           = 5,
	CHANCES_DATASTORE          = "CustomTitleChances_V1",
	CHANCES_PREFIX             = "Chances_",
	UNLIMITED_LEVEL_THRESHOLD  = 50, -- Level 50+ mendapat custom title unlimited
}

-- ====================================
-- LEVEL CHECK HELPER
-- ====================================
local function getPlayerLevel(player)
	if not player then return 1 end
	if LevelSystem and LevelSystem.GetPlayerLevel then
		local ok, lvl = pcall(function() return LevelSystem:GetPlayerLevel(player) end)
		if ok and type(lvl) == "number" then return lvl end
	end
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local levelVal = leaderstats:FindFirstChild("Level")
		if levelVal and type(levelVal.Value) == "number" then
			return levelVal.Value
		end
	end
	return 1
end

local function hasUnlimitedTitle(player)
	return getPlayerLevel(player) >= CONFIG.UNLIMITED_LEVEL_THRESHOLD
end

-- ====================================
-- DATASTORE & CACHE
-- ====================================
local chancesStore = DataStoreService:GetDataStore(CONFIG.CHANCES_DATASTORE)
local playerChancesCache = {}
local activePreviews = {} -- [userId] = previewToken

local function getPlayerChances(userId)
	if playerChancesCache[userId] ~= nil then
		return playerChancesCache[userId]
	end

	local success, val = pcall(function()
		return chancesStore:GetAsync(CONFIG.CHANCES_PREFIX .. tostring(userId))
	end)

	if success and val ~= nil then
		local chances = math.clamp(tonumber(val) or CONFIG.MAX_CHANCES, 0, CONFIG.MAX_CHANCES)
		playerChancesCache[userId] = chances
		return chances
	end

	-- Default for new players
	playerChancesCache[userId] = CONFIG.MAX_CHANCES
	return CONFIG.MAX_CHANCES
end

local function setPlayerChances(userId, newChances)
	newChances = math.clamp(math.floor(newChances), 0, CONFIG.MAX_CHANCES)
	playerChancesCache[userId] = newChances

	local success, err = pcall(function()
		chancesStore:SetAsync(CONFIG.CHANCES_PREFIX .. tostring(userId), newChances)
	end)

	if not success then
		warn("[CustomTitle] Failed to save chances for", userId, ":", err)
	end

	return newChances
end

-- ====================================
-- REMOTE SETUP
-- ====================================
local titleRemotes = ReplicatedStorage:FindFirstChild("TitleRemotes")
if not titleRemotes then
	titleRemotes = Instance.new("Folder")
	titleRemotes.Name = "TitleRemotes"
	titleRemotes.Parent = ReplicatedStorage
end

local function getOrCreateRemote(className, name)
	local rem = titleRemotes:FindFirstChild(name)
	if not rem then
		rem = Instance.new(className)
		rem.Name = name
		rem.Parent = titleRemotes
	end
	return rem
end

local getCustomTitleDataRemote = getOrCreateRemote("RemoteFunction", "GetCustomTitleData")
local previewCustomTitleRemote = getOrCreateRemote("RemoteEvent", "PreviewCustomTitle")
local previewEndedRemote       = getOrCreateRemote("RemoteEvent", "PreviewEnded")
local applyCustomTitleRemote   = getOrCreateRemote("RemoteFunction", "ApplyCustomTitle")

-- ====================================
-- REMOTE: GET DATA (CHANCES & CURRENT TITLE)
-- ====================================
getCustomTitleDataRemote.OnServerInvoke = function(player)
	if not player then return nil end
	local userId = player.UserId

	local chances = getPlayerChances(userId)
	local currentTitle = TitleDataManager:LoadTitleData(userId)
	local isUnlimited = hasUnlimitedTitle(player)
	local currentLevel = getPlayerLevel(player)

	return {
		Chances = chances,
		MaxChances = CONFIG.MAX_CHANCES,
		IsUnlimited = isUnlimited,
		Level = currentLevel,
		UnlimitedThreshold = CONFIG.UNLIMITED_LEVEL_THRESHOLD,
		CurrentTitle = currentTitle or {
			Title = "",
			Color = Color3.fromRGB(255, 255, 255),
			GradientEnabled = false,
			GradientEffect = "wave",
		}
	}
end

-- ====================================
-- REMOTE: PREVIEW TITLE (CEK DULU - 5 DETIK)
-- ====================================
previewCustomTitleRemote.OnServerEvent:Connect(function(player, titleData)
	if not player or not player.Parent then return end
	if type(titleData) ~= "table" then return end

	local rawTitle = tostring(titleData.Title or "")
	rawTitle = rawTitle:match("^%s*(.-)%s*$") or ""
	if #rawTitle > CONFIG.MAX_TITLE_LENGTH then
		rawTitle = rawTitle:sub(1, CONFIG.MAX_TITLE_LENGTH)
	end

	if rawTitle == "" then return end

	-- Roblox Text Filtering for safety
	local filteredTitle = rawTitle
	pcall(function()
		local filterResult = TextService:FilterStringAsync(rawTitle, player.UserId)
		filteredTitle = filterResult:GetNonChatStringForBroadcastAsync()
	end)

	local rawColor = titleData.Color
	if typeof(rawColor) ~= "Color3" then
		rawColor = Color3.fromRGB(255, 255, 255)
	end

	local previewData = {
		Title           = filteredTitle,
		Color           = rawColor,
		GradientEnabled = false,
		GradientEffect  = "none",
	}

	-- Save original title before previewing so we can accurately revert
	local originalTitle = TitleDataManager:GetCache(player.UserId)
	if not originalTitle then
		originalTitle = TitleDataManager:LoadTitleData(player.UserId)
	end
	local revertTitle = nil
	if originalTitle then
		revertTitle = {
			Title           = originalTitle.Title or "",
			Color           = originalTitle.Color or Color3.fromRGB(255, 255, 255),
			GradientEnabled = originalTitle.GradientEnabled or false,
			GradientEffect  = originalTitle.GradientEffect or "none",
		}
	end

	-- Temporarily update cache and rebuild overhead
	TitleDataManager:UpdateCache(player.UserId, previewData)
	if player.Character and player.Character.Parent then
		OverheadManager:CreateOverhead(player, player.Character)
	end

	-- Start 5-second timer with cancellation token
	local token = os.clock()
	activePreviews[player.UserId] = token

	task.delay(CONFIG.PREVIEW_DURATION, function()
		if activePreviews[player.UserId] == token then
			activePreviews[player.UserId] = nil

			if player and player.Parent then
				-- Revert back to original title
				TitleDataManager:UpdateCache(player.UserId, revertTitle or {
					Title           = "",
					Color           = Color3.fromRGB(255, 255, 255),
					GradientEnabled = false,
					GradientEffect  = "none",
				})

				if player.Character and player.Character.Parent then
					OverheadManager:CreateOverhead(player, player.Character)
				end

				-- Notify client that 5 seconds preview has ended
				previewEndedRemote:FireClient(player)
			end
		end
	end)
end)

-- ====================================
-- REMOTE: APPLY TITLE (MEMOTONG 1 KESEMPATAN)
-- ====================================
applyCustomTitleRemote.OnServerInvoke = function(player, titleData)
	if not player or not player.Parent then
		return false, "Player tidak valid."
	end
	if type(titleData) ~= "table" then
		return false, "Format data tidak valid."
	end

	local userId = player.UserId
	local chances = getPlayerChances(userId)
	local isUnlimited = hasUnlimitedTitle(player)
	local currentLvl = getPlayerLevel(player)

	if not isUnlimited and chances <= 0 then
		return false, string.format("Kesempatan custom title kamu sudah habis (0/%d)! Capai Level %d untuk Custom Title Unlimited!", CONFIG.MAX_CHANCES, CONFIG.UNLIMITED_LEVEL_THRESHOLD), 0, false
	end

	local rawTitle = tostring(titleData.Title or "")
	rawTitle = rawTitle:match("^%s*(.-)%s*$") or ""
	if #rawTitle > CONFIG.MAX_TITLE_LENGTH then
		rawTitle = rawTitle:sub(1, CONFIG.MAX_TITLE_LENGTH)
	end

	if rawTitle == "" then
		return false, "Title tidak boleh kosong!", chances, isUnlimited
	end

	-- Cancel any ongoing preview timer
	activePreviews[userId] = nil

	-- Roblox Text Filtering
	local filteredTitle = rawTitle
	pcall(function()
		local filterResult = TextService:FilterStringAsync(rawTitle, userId)
		filteredTitle = filterResult:GetNonChatStringForBroadcastAsync()
	end)

	local rawColor = titleData.Color
	if typeof(rawColor) ~= "Color3" then
		rawColor = Color3.fromRGB(255, 255, 255)
	end

	local finalTitleData = {
		Title           = filteredTitle,
		Color           = rawColor,
		GradientEnabled = false,
		GradientEffect  = "none",
	}

	-- Deduct 1 chance only if player is not unlimited (level < 50)
	local remaining = chances
	if not isUnlimited then
		remaining = setPlayerChances(userId, chances - 1)
	end

	-- Save permanently to DataStore
	TitleDataManager:SaveTitleData(userId, finalTitleData)
	TitleDataManager:UpdateCache(userId, finalTitleData)

	-- Rebuild overhead in real-time
	if player.Character and player.Character.Parent then
		OverheadManager:CreateOverhead(player, player.Character)
	end

	local successMsg = isUnlimited
		and string.format("Title berhasil dipasang! (👑 Unlimited - Level %d)", currentLvl)
		or string.format("Title berhasil dipasang! (Sisa kesempatan: %d/%d)", remaining, CONFIG.MAX_CHANCES)

	print(string.format("[CustomTitle] Player %s (Level: %d, Unlimited: %s) applied title '%s'. Sisa kesempatan: %d/%d", 
		player.Name, currentLvl, tostring(isUnlimited), filteredTitle, remaining, CONFIG.MAX_CHANCES))

	return true, successMsg, remaining, isUnlimited
end

-- ====================================
-- CLEANUP
-- ====================================
Players.PlayerRemoving:Connect(function(player)
	playerChancesCache[player.UserId] = nil
	activePreviews[player.UserId] = nil
end)

print("[CustomTitle] ✅ CustomTitleServer initialized successfully.")
