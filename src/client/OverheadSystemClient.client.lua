local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local OverheadShared = ReplicatedStorage:WaitForChild("OverheadShared")
local Config = require(OverheadShared:WaitForChild("Config"))
local TitleEffects = require(OverheadShared:WaitForChild("TitleEffects"))

local UI = ReplicatedStorage:WaitForChild("UI")
local overheadTemplate = UI:WaitForChild("OverheadGui")

local localPlayer = Players.LocalPlayer

-- ====================================
-- HELPERS
-- ====================================
local function safeFind(parent, name)
	if not parent then return nil end
	local cleanName = string.gsub(string.lower(name), "%s+", "")
	for _, child in ipairs(parent:GetChildren()) do
		local childClean = string.gsub(string.lower(child.Name), "%s+", "")
		if childClean == cleanName then
			return child
		end
	end
	return nil
end

local function getDisplayText(role, player)
	if player and player.Team then
		local teamName = player.Team.Name
		if teamName == "Tamu" then
			return ""
		end
		return teamName
	end
	return Config.CUSTOM_DISPLAY_TEXT[role] or role
end

local function getRoleColor(role, player)
	if player and player.Team then
		local team = player.Team
		local attrR = team:GetAttribute("ExactColorR")
		local attrG = team:GetAttribute("ExactColorG")
		local attrB = team:GetAttribute("ExactColorB")
		if attrR and attrG and attrB then
			return Color3.fromRGB(attrR, attrG, attrB)
		end
		local tc = team.TeamColor
		if tc then return tc.Color end
	end
	return Config.ROLE_COLORS[role] or Config.ROLE_COLORS.Player
end

local function checkPremium(player)
	local ok, v = pcall(function() return player.MembershipType == Enum.MembershipType.Premium end)
	return ok and v or false
end

local groupCache = {}
local function checkGroupMember(player)
	if groupCache[player.UserId] ~= nil then
		return groupCache[player.UserId]
	end
	
	local ok, v = pcall(function() return player:IsInGroup(Config.GROUP_ID) end)
	local isMember = ok and v or false
	groupCache[player.UserId] = isMember
	return isMember
end

local function setupTextSizeConstraint(textLabel)
	local c = textLabel:FindFirstChildOfClass("UITextSizeConstraint")
	if not c then
		c = Instance.new("UITextSizeConstraint")
		c.Parent = textLabel
	end
	c.MinTextSize = Config.NAME_TEXT_SIZE_MIN or 10
	c.MaxTextSize = Config.NAME_TEXT_SIZE_MAX or 16
	return c
end

local EUROPEAN_COUNTRIES = {
	["AL"] = true, ["AD"] = true, ["AT"] = true, ["BY"] = true, ["BE"] = true,
	["BA"] = true, ["BG"] = true, ["HR"] = true, ["CY"] = true, ["CZ"] = true,
	["DK"] = true, ["EE"] = true, ["FI"] = true, ["FR"] = true, ["DE"] = true,
	["GR"] = true, ["HU"] = true, ["IS"] = true, ["IE"] = true, ["IT"] = true,
	["LV"] = true, ["LI"] = true, ["LT"] = true, ["LU"] = true, ["MT"] = true,
	["MD"] = true, ["MC"] = true, ["ME"] = true, ["NL"] = true, ["MK"] = true,
	["NO"] = true, ["PL"] = true, ["PT"] = true, ["RO"] = true, ["RU"] = true,
	["SM"] = true, ["RS"] = true, ["SK"] = true, ["SI"] = true, ["ES"] = true,
	["SE"] = true, ["CH"] = true, ["UA"] = true, ["GB"] = true, ["VA"] = true,
	["XK"] = true, ["EU"] = true,
}

local function getFlagEmoji(countryCode)
	if not countryCode or #countryCode ~= 2 then return "🇮🇩" end
	countryCode = string.upper(countryCode)

	-- Jika pemain berasal dari negara Eropa dan fitur bendera Eropa aktif, tampilkan bendera Uni Eropa (🇪🇺)
	local useEU = Config.USE_EU_FLAG_FOR_EUROPE
	if useEU == nil then useEU = true end

	if useEU and EUROPEAN_COUNTRIES[countryCode] then
		return utf8.char(0x1F1EA, 0x1F1FA) -- 🇪🇺 European Union
	end

	local b1 = string.byte(countryCode, 1)
	local b2 = string.byte(countryCode, 2)
	if b1 >= 65 and b1 <= 90 and b2 >= 65 and b2 <= 90 then
		return utf8.char(0x1F1E6 + (b1 - 65), 0x1F1E6 + (b2 - 65))
	end
	return "🇮🇩"
end

local function isStaffMember(role, player)
	if role == "Owner" or role == "Admin" or role == "Moderator" then
		return true
	end
	if player and player.Team then
		local tn = string.lower(player.Team.Name)
		if tn:find("owner") or tn:find("admin") or tn:find("staff") or tn:find("mod") or tn:find("dev") or tn:find("co%-owner") then
			return true
		end
	end
	return false
end

local function checkVIP(player, role)
	if role == "VIP" or player:GetAttribute("Overhead_HasVIP") == true then
		return true
	end
	if player and player.Team and string.lower(player.Team.Name):find("vip") then
		return true
	end
	return false
end

local function applyTitleEffect(titleFrame, titleLabel, player, character)
	local r = player:GetAttribute("Overhead_TitleColorR") or 1
	local g = player:GetAttribute("Overhead_TitleColorG") or 1
	local b = player:GetAttribute("Overhead_TitleColorB") or 1
	local base = Color3.new(r, g, b)
	
	titleFrame.BackgroundColor3 = base
	if titleLabel then
		titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	end
	if not gradientEnabled then return end

	local effectType = player:GetAttribute("Overhead_TitleEffect") or "wave"
	local effectConfig = Config.EFFECTS[effectType:upper()] or Config.EFFECTS.WAVE

	if effectType == "none"      then TitleEffects:CreateNoneEffect(titleLabel, base, character, effectConfig, Config.TEXT_BRIGHTEN_FACTOR)
	elseif effectType == "wave"      then TitleEffects:CreateWaveEffect(titleLabel, base, character, effectConfig, Config.TEXT_BRIGHTEN_FACTOR)
	elseif effectType == "pulse"     then TitleEffects:CreatePulseEffect(titleLabel, base, character, effectConfig, Config.TEXT_BRIGHTEN_FACTOR)
	elseif effectType == "rainbow"   then TitleEffects:CreateRainbowEffect(titleLabel, base, character, effectConfig, Config.TEXT_BRIGHTEN_FACTOR)
	elseif effectType == "shimmer"   then TitleEffects:CreateShimmerEffect(titleLabel, base, character, effectConfig, Config.TEXT_BRIGHTEN_FACTOR)
	elseif effectType == "palette"   then TitleEffects:CreatePaletteEffect(titleLabel, base, character, effectConfig, Config.TEXT_BRIGHTEN_FACTOR)
	elseif effectType == "sunset"    then TitleEffects:CreateSunsetEffect(titleLabel, base, character, effectConfig, Config.TEXT_BRIGHTEN_FACTOR)
	elseif effectType == "ocean"     then TitleEffects:CreateOceanEffect(titleLabel, base, character, effectConfig, Config.TEXT_BRIGHTEN_FACTOR)
	elseif effectType == "galaxy"    then TitleEffects:CreateGalaxyEffect(titleLabel, base, character, effectConfig, Config.TEXT_BRIGHTEN_FACTOR)
	elseif effectType == "emerald"   then TitleEffects:CreateEmeraldEffect(titleLabel, base, character, effectConfig, Config.TEXT_BRIGHTEN_FACTOR)
	elseif effectType == "pinkwhite" then TitleEffects:CreatePinkWhiteEffect(titleLabel, base, character, effectConfig, Config.TEXT_BRIGHTEN_FACTOR)
	end
end

-- ====================================
-- MAIN RENDER LOOP
-- ====================================

local function updateOverhead(player, character, overhead)
	if not player or not character or not overhead then return end
	
	local mainFrame = overhead:FindFirstChild("MainFrame")
	if not mainFrame then return end

	-- Elements from hierarchy
	local titleFrame      = mainFrame:FindFirstChild("TitleFrame")
	local topTags         = mainFrame:FindFirstChild("TopTagsContainer") or safeFind(mainFrame, "BorderFrame")
	local nameContainer   = mainFrame:FindFirstChild("NameContainer") or mainFrame:FindFirstChild("TextContainer")
	local roleLevelLabel  = mainFrame:FindFirstChild("RoleLevelLabel") or mainFrame:FindFirstChild("PlayerRole") or (nameContainer and nameContainer:FindFirstChild("PlayerRole"))
	local legacyLevel     = mainFrame:FindFirstChild("LevelLabel") or (nameContainer and nameContainer:FindFirstChild("LevelLabel"))

	if legacyLevel and legacyLevel ~= roleLevelLabel then
		legacyLevel.Visible = false
	end

	local playerName      = nameContainer and (nameContainer:FindFirstChild("PlayerName") or safeFind(nameContainer, "PlayerName"))
	local leftGroup       = nameContainer and nameContainer:FindFirstChild("LeftGroup")
	local countryLabel    = (leftGroup and leftGroup:FindFirstChild("CountryFlag")) or (playerName and playerName:FindFirstChild("CountryFlag")) or (nameContainer and nameContainer:FindFirstChild("CountryFlag"))
	local rightGroup      = nameContainer and nameContainer:FindFirstChild("RightGroup")
	local badgesContainer = rightGroup or (playerName and playerName:FindFirstChild("BadgesContainer")) or (nameContainer and (nameContainer:FindFirstChild("BadgesContainer") or nameContainer:FindFirstChild("labelFrame")))

	local verifiedBadge = badgesContainer and badgesContainer:FindFirstChild("VerifiedBadge")
	local vipLogo       = badgesContainer and badgesContainer:FindFirstChild("VipLogo")
	local premiumBadge  = badgesContainer and badgesContainer:FindFirstChild("PremiumBadge")

	-- 1. TITLE DI PALING ATAS SENDIRI (LayoutOrder = 1)
	if not titleFrame and topTags then
		titleFrame = safeFind(topTags, "TitleFrame")
	end
	local titleText = player:GetAttribute("Overhead_TitleText") or ""
	if titleFrame then
		if titleText ~= "" then
			titleFrame.Visible = true
			local label = titleFrame:FindFirstChild("TitleLabel") or safeFind(titleFrame, "TitleLabel")
			if label then
				label.Text = titleText
				label.TextColor3 = Color3.fromRGB(255, 255, 255)
				task.spawn(function() applyTitleEffect(titleFrame, label, player, character) end)
			end
		else
			titleFrame.Visible = false
		end
	end

	-- 2. TOP DONATUR TAGS MENYAMPING / HORIZONTAL (LayoutOrder = 2)
	if topTags then
		local topRupiahFrame = safeFind(topTags, "TopRupiahFrame")
		local topRobuxFrame  = safeFind(topTags, "TopRobuxFrame")
		local topLikesFrame  = safeFind(topTags, "TopLikesFrame")

		local anyTagVisible = false

		-- Top Rupiah (Saweria)
		local saweriaRank = player:GetAttribute("Overhead_SaweriaRank") or 0
		if topRupiahFrame then
			if saweriaRank > 0 and saweriaRank <= (Config.SAWERIA_TOP_RANKS or 10) then
				topRupiahFrame.Visible = true
				anyTagVisible = true
				local label = topRupiahFrame:FindFirstChild("TopRupiahLabel") or safeFind(topRupiahFrame, "TopRupiahLabel")
				if label then label.Text = "👑 DONATUR #" .. saweriaRank end
			else
				topRupiahFrame.Visible = false
			end
		end

		-- Top Robux
		local robuxRank = player:GetAttribute("Overhead_RobuxRank") or 0
		if topRobuxFrame then
			if robuxRank > 0 and robuxRank <= (Config.DONATION_TOP_RANKS or 10) then
				topRobuxFrame.Visible = true
				anyTagVisible = true
				local label = topRobuxFrame:FindFirstChild("TopRobuxLabel") or safeFind(topRobuxFrame, "TopRobuxLabel")
				if label then label.Text = "💎 TOP ROBUX #" .. robuxRank end
			else
				topRobuxFrame.Visible = false
			end
		end

		-- Top Likes
		local likesRank = player:GetAttribute("Overhead_LikesRank") or 0
		if topLikesFrame then
			if likesRank > 0 and likesRank <= 10 then
				topLikesFrame.Visible = true
				anyTagVisible = true
				local label = topLikesFrame:FindFirstChild("TopLikesLabel") or safeFind(topLikesFrame, "TopLikesLabel")
				if label then label.Text = "❤️ TOP LIKE #" .. likesRank end
			else
				topLikesFrame.Visible = false
			end
		end

		topTags.Visible = anyTagVisible
	end

	-- 3. COUNTRY FLAG & PLAYER NAME (LayoutOrder = 3)
	if countryLabel then
		local countryCode = player:GetAttribute("Overhead_CountryCode") or "ID"
		countryLabel.Text = getFlagEmoji(countryCode)
		countryLabel.Visible = true
	end

	if playerName then
		playerName.Text = player.DisplayName
		playerName.Visible = true
	end

	-- 4. BADGES FILTER
	local role = player:GetAttribute("Overhead_Role") or "Player"
	local isStaff = isStaffMember(role, player)
	local hasVIP = checkVIP(player, role)

	if verifiedBadge then
		verifiedBadge.Visible = isStaff
	end
	if vipLogo then
		vipLogo.Visible = hasVIP
	end
	if premiumBadge then
		premiumBadge.Visible = checkPremium(player)
	end

	-- 5. COMBINED ROLE & LEVEL (LayoutOrder = 4)
	-- Format: OWNER | Level 100, ADMIN | Level 100, VIP | Level 100, PLAYER | Level 100
	local level = player:GetAttribute("Overhead_Level") or 1
	local roleText = ""
	local roleColor = Color3.fromRGB(215, 220, 230)

	if isStaff then
		local rawText = getDisplayText(role, player)
		if rawText == "" or rawText == "Player" or rawText == "Tamu" then
			rawText = role
		end
		roleText = string.upper(rawText)
		roleColor = getRoleColor(role, player)
	elseif hasVIP then
		roleText = "VIP"
		roleColor = Color3.fromRGB(255, 215, 0)
	else
		roleText = "PLAYER"
		roleColor = Color3.fromRGB(215, 220, 230)
	end

	if roleLevelLabel then
		roleLevelLabel.Text = string.format("%s | Level %s", roleText, tostring(level))
		roleLevelLabel.TextColor3 = roleColor
		roleLevelLabel.Visible = true
	end
end

-- ====================================
-- EVENT LISTENERS
-- ====================================
local playerConnections = {}

local function setupCharacter(player, character)
	-- Bersihkan koneksi lama terlebih dahulu untuk mencegah memory leak
	if playerConnections[player.UserId] then
		for _, conn in ipairs(playerConnections[player.UserId]) do
			if conn.Connected then conn:Disconnect() end
		end
		playerConnections[player.UserId] = nil
	end
	
	local conns = {}
	local currentOverhead = nil

	-- Fungsi internal untuk attach GUI secara aman
	local function attachAndRender()
		local head = character:FindFirstChild("Head")
		if not head then return end
		
		-- Hapus overhead lama jika ada
		if character:FindFirstChild("PlayerOverhead") then
			character.PlayerOverhead:Destroy()
		end
		
		-- Parent ke Character, bukan Head! Menghindari GUI hancur saat Head diganti oleh Roblox (R15 bug)
		currentOverhead = overheadTemplate:Clone()
		currentOverhead.Name = "PlayerOverhead"
		currentOverhead.Adornee = head
		currentOverhead.Parent = character
		
		updateOverhead(player, character, currentOverhead)
	end

	-- Eksekusi awal
	task.spawn(function()
		if not character:FindFirstChild("Head") then
			character:WaitForChild("Head", 10)
		end
		attachAndRender()
	end)
	
	-- Pantau jika Head diganti oleh sistem bundle Roblox
	table.insert(conns, character.ChildAdded:Connect(function(child)
		if child.Name == "Head" then
			task.wait() -- Tunggu properti termuat
			attachAndRender()
		end
	end))
	
	-- Dengarkan perubahan attribute untuk langsung update UI
	table.insert(conns, player.AttributeChanged:Connect(function(attr)
		if string.sub(attr, 1, 9) == "Overhead_" or attr == "TotalLikes" then
			if currentOverhead and currentOverhead.Parent then
				updateOverhead(player, character, currentOverhead)
			end
		end
	end))
	
	table.insert(conns, player:GetPropertyChangedSignal("Team"):Connect(function()
		if currentOverhead and currentOverhead.Parent then
			updateOverhead(player, character, currentOverhead)
		end
	end))

	-- Bersihkan koneksi secara otomatis jika karakter hancur
	table.insert(conns, character.AncestryChanged:Connect(function(_, parent)
		if not parent then
			if playerConnections[player.UserId] then
				for _, conn in ipairs(playerConnections[player.UserId]) do
					if conn.Connected then conn:Disconnect() end
				end
				playerConnections[player.UserId] = nil
			end
		end
	end))
	
	playerConnections[player.UserId] = conns
end

local function onPlayerAdded(player)
	if player.Character then
		task.spawn(setupCharacter, player, player.Character)
	end
	player.CharacterAdded:Connect(function(char)
		task.spawn(setupCharacter, player, char)
	end)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, p in ipairs(Players:GetPlayers()) do
	onPlayerAdded(p)
end

Players.PlayerRemoving:Connect(function(player)
	if playerConnections[player.UserId] then
		for _, conn in ipairs(playerConnections[player.UserId]) do
			conn:Disconnect()
		end
		playerConnections[player.UserId] = nil
	end
	groupCache[player.UserId] = nil
end)
