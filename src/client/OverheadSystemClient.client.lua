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

local function checkGroupMember(player)
	local ok, v = pcall(function() return player:IsInGroup(Config.GROUP_ID) end)
	return ok and v or false
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

local function updateLogos(labelFrame, player, role)
	local allLogoNames = {
		"StaffLogo", "DevLogo", "OwnerLogo",
		"PremiumBadge", "VipLogo", "VvipLogo", "VerifiedBadge", "SultanLogo"
	}

	local logos = {}
	for _, name in ipairs(allLogoNames) do
		logos[name] = labelFrame:FindFirstChild(name)
	end

	for _, logo in pairs(logos) do
		if logo then logo.Visible = false end
	end

	local roleConfig = Config.LOGO_DISPLAY[role]
	if roleConfig then
		if roleConfig.ShowAll and roleConfig.Logos then
			for _, logoName in ipairs(roleConfig.Logos) do
				if logos[logoName] then
					logos[logoName].Visible = true
				end
			end
		elseif not roleConfig.ShowAll and roleConfig.RoleLogo then
			if logos[roleConfig.RoleLogo] then
				logos[roleConfig.RoleLogo].Visible = true
			end
		end
	end

	if logos.PremiumBadge and checkPremium(player) then
		logos.PremiumBadge.Visible = true
	end
	if logos.VerifiedBadge and checkGroupMember(player) then
		logos.VerifiedBadge.Visible = true
	end
end

local function applyTitleEffect(titleFrame, titleLabel, player, character)
	local r = player:GetAttribute("Overhead_TitleColorR") or 1
	local g = player:GetAttribute("Overhead_TitleColorG") or 1
	local b = player:GetAttribute("Overhead_TitleColorB") or 1
	local base = Color3.new(r, g, b)
	
	titleFrame.BackgroundColor3 = base

	local gradientEnabled = player:GetAttribute("Overhead_TitleGradient")
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
	
	local mainFrame     = overhead:FindFirstChild("MainFrame")
	if not mainFrame then return end
	
	local borderFrame   = mainFrame:FindFirstChild("BorderFrame")
	local editableFrame = borderFrame and borderFrame:FindFirstChild("EditableFrame")
	local textContainer = mainFrame:FindFirstChild("TextContainer")
	if not textContainer then return end
	
	local nameFrame     = textContainer:FindFirstChild("NameFrame")
	local playerName    = nameFrame and nameFrame:FindFirstChild("PlayerName")
	local labelFrame    = textContainer:FindFirstChild("labelFrame")
	local playerRole    = textContainer:FindFirstChild("PlayerRole")
	local levelLabel    = textContainer:FindFirstChild("LevelLabel")
	
	-- 1. Player Name & Likes
	local totalLikes = player:GetAttribute("TotalLikes") or 0
	if playerName then
		playerName.Text = player.DisplayName .. " | ❤️ " .. tostring(totalLikes)
		playerName.TextScaled = true
		playerName.AutomaticSize = Enum.AutomaticSize.X
		setupTextSizeConstraint(playerName)
	end

	-- 2. Role & Team
	local role = player:GetAttribute("Overhead_Role") or "Player"
	local roleLabel = getDisplayText(role, player)
	if playerRole then
		playerRole.Text = roleLabel
		playerRole.TextColor3 = getRoleColor(role, player)
		playerRole.Visible = roleLabel ~= ""
	end

	-- 3. Level
	if levelLabel then
		local level = player:GetAttribute("Overhead_Level") or 1
		levelLabel.Text = string.format(Config.LEVEL_FORMAT, level)
		levelLabel.Visible = true
	end

	-- 4. Logos
	if labelFrame then
		updateLogos(labelFrame, player, role)
	end

	-- 5. Editable Frame (Ranks & Titles)
	if editableFrame then
		local titleFrame      = safeFind(editableFrame, "TitleFrame") or safeFind(borderFrame, "TitleFrame")
		local topLikesFrame   = safeFind(editableFrame, "TopLikesFrame")
		local topRobuxFrame   = safeFind(editableFrame, "TopRobuxFrame")
		local topRupiahFrame  = safeFind(editableFrame, "TopRupiahFrame")

		-- Top Likes
		local likesRank = player:GetAttribute("Overhead_LikesRank") or 0
		if topLikesFrame then
			if likesRank > 0 and likesRank <= 30 then
				topLikesFrame.Visible = true
				local likesLabel = safeFind(topLikesFrame, "TopLikesLabel")
				if likesLabel then likesLabel.Text = "Likes #" .. likesRank end
				local colorIndex = math.min(likesRank, 10)
				local colors = Config.TOP_DONATUR_COLORS and Config.TOP_DONATUR_COLORS[colorIndex] or Config.TOP_DONATUR_COLORS[10]
				if colors and colors.Frame then topLikesFrame.BackgroundColor3 = colors.Frame end
			else
				topLikesFrame.Visible = false
			end
		end

		-- Top Robux
		local robuxRank = player:GetAttribute("Overhead_RobuxRank") or 0
		if topRobuxFrame then
			if robuxRank > 0 and robuxRank <= Config.DONATION_TOP_RANKS then
				topRobuxFrame.Visible = true
				local robuxLabel = safeFind(topRobuxFrame, "TopRobuxLabel")
				if robuxLabel then robuxLabel.Text = "Robux #" .. robuxRank end
				local colorIndex = math.min(robuxRank, 10)
				local colors = Config.TOP_SPENDER_COLORS and Config.TOP_SPENDER_COLORS[colorIndex] or Config.TOP_SPENDER_COLORS[10]
				if colors and colors.Frame then topRobuxFrame.BackgroundColor3 = colors.Frame end
			else
				topRobuxFrame.Visible = false
			end
		end

		-- Top Rupiah (Saweria)
		local saweriaRank = player:GetAttribute("Overhead_SaweriaRank") or 0
		if topRupiahFrame then
			if saweriaRank > 0 and saweriaRank <= Config.SAWERIA_TOP_RANKS then
				topRupiahFrame.Visible = true
				local rupiahLabel = safeFind(topRupiahFrame, "TopRupiahLabel")
				if rupiahLabel then rupiahLabel.Text = "Rupiah #" .. saweriaRank end
				local colorIndex = math.min(saweriaRank, 10)
				local colors = Config.TOP_DONATUR_COLORS and Config.TOP_DONATUR_COLORS[colorIndex] or Config.TOP_DONATUR_COLORS[10]
				if colors and colors.Frame then topRupiahFrame.BackgroundColor3 = colors.Frame end
			else
				topRupiahFrame.Visible = false
			end
		end

		-- Title Custom
		local titleText = player:GetAttribute("Overhead_TitleText") or ""
		if titleFrame then
			if titleText ~= "" then
				titleFrame.Visible = true
				local titleLabel = safeFind(titleFrame, "TitleLabel")
				if titleLabel then
					titleLabel.Text = titleText
					task.spawn(function() applyTitleEffect(titleFrame, titleLabel, player, character) end)
				end
			else
				titleFrame.Visible = false
			end
		end

		-- Auto-hide editable frame if empty
		local isAnyVisible = false
		if topLikesFrame and topLikesFrame.Visible then isAnyVisible = true end
		if topRobuxFrame and topRobuxFrame.Visible then isAnyVisible = true end
		if topRupiahFrame and topRupiahFrame.Visible then isAnyVisible = true end
		if titleFrame and titleFrame.Visible then isAnyVisible = true end
		editableFrame.Visible = isAnyVisible
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
end)
