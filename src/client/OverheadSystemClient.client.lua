local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OverheadShared = ReplicatedStorage:WaitForChild("OverheadShared")
local Config = require(OverheadShared:WaitForChild("Config"))
local TitleEffects = require(OverheadShared:WaitForChild("TitleEffects"))

local UI = ReplicatedStorage:WaitForChild("UI")
local overheadTemplate = UI:WaitForChild("OverheadGui")

local localPlayer = Players.LocalPlayer

local function safeFind(parent, name)
	if not parent then return nil end
	local cleanName = string.gsub(string.lower(name), "%s+", "")
	for _, child in ipairs(parent:GetChildren()) do
		if string.gsub(string.lower(child.Name), "%s+", "") == cleanName then
			return child
		end
	end
	return nil
end

local function getDisplayText(role, player)
	if player and player.Team then
		local teamName = player.Team.Name
		return if teamName ~= "Tamu" then teamName else ""
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

	local useEU = Config.USE_EU_FLAG_FOR_EUROPE
	if useEU == nil then useEU = true end

	if useEU and EUROPEAN_COUNTRIES[countryCode] then
		return utf8.char(0x1F1EA, 0x1F1FA)
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

local EFFECT_METHOD_MAP = {
	none      = "CreateNoneEffect",
	wave      = "CreateWaveEffect",
	pulse     = "CreatePulseEffect",
	rainbow   = "CreateRainbowEffect",
	shimmer   = "CreateShimmerEffect",
	palette   = "CreatePaletteEffect",
	sunset    = "CreateSunsetEffect",
	ocean     = "CreateOceanEffect",
	galaxy    = "CreateGalaxyEffect",
	emerald   = "CreateEmeraldEffect",
	pinkwhite = "CreatePinkWhiteEffect",
}

local function applyTitleEffect(titleFrame, titleLabel, player, character)
	local r = player:GetAttribute("Overhead_TitleColorR") or 1
	local g = player:GetAttribute("Overhead_TitleColorG") or 1
	local b = player:GetAttribute("Overhead_TitleColorB") or 1
	local base = Color3.new(r, g, b)

	titleFrame.BackgroundColor3 = base
	if titleLabel then
		titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	end
	if player:GetAttribute("Overhead_TitleGradient") ~= true then return end

	local effectType = player:GetAttribute("Overhead_TitleEffect") or "wave"
	local effectConfig = Config.EFFECTS[effectType:upper()] or Config.EFFECTS.WAVE

	local methodName = EFFECT_METHOD_MAP[effectType]
	if methodName and TitleEffects[methodName] then
		TitleEffects[methodName](TitleEffects, titleLabel, base, character, effectConfig, Config.TEXT_BRIGHTEN_FACTOR)
	end
end

local function updateOverhead(player, character, overhead)
	if not player or not character or not overhead then return end

	local mainFrame = overhead:FindFirstChild("MainFrame")
	if not mainFrame then return end

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

	if not titleFrame and topTags then
		titleFrame = safeFind(topTags, "TitleFrame")
	end
	local titleText = player:GetAttribute("Overhead_TitleText") or ""
	if titleFrame then
		local hasTitle = (titleText ~= "")
		titleFrame.Visible = hasTitle
		if hasTitle then
			local label = titleFrame:FindFirstChild("TitleLabel") or safeFind(titleFrame, "TitleLabel")
			if label then
				label.Text = titleText
				label.TextColor3 = Color3.fromRGB(255, 255, 255)
				task.spawn(function() applyTitleEffect(titleFrame, label, player, character) end)
			end
		end
	end

	if topTags then
		local tagsConfig = {
			{ frame = "TopRupiahFrame", label = "TopRupiahLabel", rank = player:GetAttribute("Overhead_SaweriaRank") or 0, max = Config.SAWERIA_TOP_RANKS or 10, text = "👑 DONATUR #" },
			{ frame = "TopRobuxFrame",  label = "TopRobuxLabel",  rank = player:GetAttribute("Overhead_RobuxRank") or 0,   max = Config.DONATION_TOP_RANKS or 10, text = "💎 TOP ROBUX #" },
			{ frame = "TopLikesFrame",  label = "TopLikesLabel",  rank = player:GetAttribute("Overhead_LikesRank") or 0,   max = 10,                             text = "❤️ TOP LIKE #" },
		}

		local anyTagVisible = false
		for _, tag in ipairs(tagsConfig) do
			local frame = safeFind(topTags, tag.frame)
			if frame then
				local isVisible = tag.rank > 0 and tag.rank <= tag.max
				frame.Visible = isVisible
				if isVisible then
					anyTagVisible = true
					local lbl = frame:FindFirstChild(tag.label) or safeFind(frame, tag.label)
					if lbl then lbl.Text = tag.text .. tag.rank end
				end
			end
		end
		topTags.Visible = anyTagVisible
	end

	if countryLabel then
		local countryCode = player:GetAttribute("Overhead_CountryCode") or "ID"
		countryLabel.Text = getFlagEmoji(countryCode)
		countryLabel.Visible = true
	end

	if playerName then
		playerName.Text = player.DisplayName
		playerName.Visible = true
	end

	local role = player:GetAttribute("Overhead_Role") or "Player"
	local isStaff = isStaffMember(role, player)
	local hasVIP = checkVIP(player, role)

	if verifiedBadge then verifiedBadge.Visible = isStaff end
	if vipLogo then vipLogo.Visible = hasVIP end
	if premiumBadge then premiumBadge.Visible = checkPremium(player) end

	local level = player:GetAttribute("Overhead_Level") or 1
	local roleText = "PLAYER"
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
	end

	if roleLevelLabel then
		roleLevelLabel.Text = string.format("%s | Level %s", roleText, tostring(level))
		roleLevelLabel.TextColor3 = roleColor
		roleLevelLabel.Visible = true
	end
end

local playerConnections = {}

local function cleanupPlayerConns(userId)
	if playerConnections[userId] then
		for _, conn in ipairs(playerConnections[userId]) do
			if conn.Connected then conn:Disconnect() end
		end
		playerConnections[userId] = nil
	end
end

local function setupCharacter(player, character)
	cleanupPlayerConns(player.UserId)

	local conns = {}
	local currentOverhead = nil

	local function attachAndRender()
		local head = character:FindFirstChild("Head")
		if not head then return end

		if character:FindFirstChild("PlayerOverhead") then
			character.PlayerOverhead:Destroy()
		end

		currentOverhead = overheadTemplate:Clone()
		currentOverhead.Name = "PlayerOverhead"
		currentOverhead.Adornee = head
		currentOverhead.MaxDistance = Config.MAX_DISTANCE or 65
		currentOverhead.Parent = character

		updateOverhead(player, character, currentOverhead)
	end

	task.spawn(function()
		if not character:FindFirstChild("Head") then
			character:WaitForChild("Head", 10)
		end
		attachAndRender()
	end)

	local function onAttributeOrTeamChange()
		if currentOverhead and currentOverhead.Parent then
			updateOverhead(player, character, currentOverhead)
		end
	end

	table.insert(conns, character.ChildAdded:Connect(function(child)
		if child.Name == "Head" then
			task.wait()
			attachAndRender()
		end
	end))

	table.insert(conns, player.AttributeChanged:Connect(function(attr)
		if string.sub(attr, 1, 9) == "Overhead_" or attr == "TotalLikes" then
			onAttributeOrTeamChange()
		end
	end))

	table.insert(conns, player:GetPropertyChangedSignal("Team"):Connect(onAttributeOrTeamChange))

	table.insert(conns, character.AncestryChanged:Connect(function(_, parent)
		if not parent then
			cleanupPlayerConns(player.UserId)
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
	cleanupPlayerConns(player.UserId)
	groupCache[player.UserId] = nil
end)